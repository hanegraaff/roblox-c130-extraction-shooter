"""Reimport every staged file into a clean Blender scene and verify the receipt."""
import hashlib
import json
import struct
import sys
from pathlib import Path

import bpy
from mathutils.bvhtree import BVHTree

sys.path.insert(0, str(Path(__file__).resolve().parent))
from prepare_import import BLEND, OUTPUT, MAX_TRIANGLES, bounds, convert_position

TOLERANCE = 0.0002


def check_close(actual, expected, name):
    if len(actual) != len(expected) or any(abs(a - b) > TOLERANCE for a, b in zip(actual, expected)):
        raise RuntimeError(f"{name}: expected {expected}, got {actual}")


def verify_glb(path, digest):
    """Check the GLB container, importer primitive limits and embedded resources."""
    data = path.read_bytes()
    if hashlib.sha256(data).hexdigest() != digest:
        raise RuntimeError(f"Staging hash mismatch: {path}")
    magic, version, length, json_size, json_type = struct.unpack_from("<4sIIII", data)
    if (magic, version, length, json_type) != (b"glTF", 2, len(data), 0x4E4F534A):
        raise RuntimeError(f"Invalid GLB: {path}")
    content = json.loads(data[20:20 + json_size])
    if any(item.get("uri") for key in ("images", "buffers") for item in content.get(key, [])):
        raise RuntimeError(f"External dependencies: {path}")
    if not path.name.startswith("query-") and not content.get("images"):
        raise RuntimeError(f"Missing surface textures: {path}")
    if content.get("cameras") or content.get("animations") or content.get("extensions", {}).get("KHR_lights_punctual"):
        raise RuntimeError(f"Review helpers found in {path}")
    largest = 0
    for mesh in content["meshes"]:
        for primitive in mesh["primitives"]:
            accessor = content["accessors"][primitive["indices"]]
            largest = max(largest, accessor["count"] // 3)
            if accessor["count"] % 3 or not {"POSITION", "NORMAL", "TEXCOORD_0"} <= primitive["attributes"].keys():
                raise RuntimeError(f"Invalid triangle or surface data in {path}")
    if not 0 < largest <= MAX_TRIANGLES:
        raise RuntimeError(f"Import limit exceeded in {path}: {largest}")
    return largest


def ray_tree(objects):
    vertices, faces = [], []
    for obj in objects:
        offset = len(vertices)
        vertices.extend(obj.matrix_world @ vertex.co for vertex in obj.data.vertices)
        faces.extend(tuple(offset + index for index in poly.vertices) for poly in obj.data.polygons)
    return BVHTree.FromPolygons(vertices, faces)


def verify_clearance(groups):
    """Check exported roof protection and open approaches in Blender coordinates."""
    roof = ray_tree([obj for obj in groups["query-solid"] if obj.get("Surface") == "Roof"])
    shell = ray_tree(groups["query-solid"] + groups["structure"] + groups["attached-art"] +
                     groups["hall-dressing"] + [obj for group, items in groups.items()
                                                if group.startswith("yard-") for obj in items])
    for x in (-20, 0, 20):
        for y in (-12, 0, 12):
            for dx in (-2, -1, 0, 1, 2):
                for dy in (-2, -1, 0, 1, 2):
                    origin = (x + dx, y + dy)
                    if not roof.ray_cast((*origin, 24), (0, 0, -1), 24)[0]:
                        raise RuntimeError(f"Missing cover above spawn {origin}")
                    if shell.ray_cast((*origin, 0.2), (0, 0, 1), 6)[0]:
                        raise RuntimeError(f"Blocked spawn column {origin}")
                    if shell.ray_cast((*origin, 0.2), (0, 0, -1), 0.4)[0] is None:
                        raise RuntimeError(f"Missing spawn floor {origin}")
    if roof.ray_cast((14, 16, 24), (0, 0, -1), 23)[0] is not None:
        raise RuntimeError("The northeast breach is covered")
    for vx, vy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        for width in (-7.99, -6, -4, -2, 0, 2, 4, 6, 7.99):
            for height in (0.16, 1, 3, 5, 6.2, 7, 8.3):
                origin = (vx * 17 - vy * width, vy * 17 + vx * width, height)
                if shell.ray_cast(origin, (vx, vy, 0), 39)[0]:
                    raise RuntimeError(f"Blocked approach from {origin} along {(vx, vy)}")


def main():
    receipt = json.loads((OUTPUT / "import-index.json").read_text())
    if receipt["sourceSha256"] != hashlib.sha256(BLEND.read_bytes()).hexdigest():
        raise RuntimeError("Exports were staged from a different Blender source")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    by_file = {filename: {} for filename in receipt["files"]}
    for record in receipt["objects"].values():
        for filename, node in record["exports"].items():
            by_file[filename][node] = record
    imported = {record["kind"]: [] for record in receipt["objects"].values()}
    max_primitive = 0
    for filename in sorted(receipt["files"], key=lambda name: (name != "pilot.glb", name)):
        digest = receipt["files"][filename]
        path = OUTPUT / filename
        max_primitive = max(max_primitive, verify_glb(path, digest))
        before = set(bpy.context.scene.objects)
        bpy.ops.import_scene.gltf(filepath=str(path))
        bpy.context.view_layer.update()
        meshes = {item.name: item for item in set(bpy.context.scene.objects) - before if item.type == "MESH"}
        if meshes.keys() != by_file[filename].keys():
            raise RuntimeError(f"Round-trip object identity mismatch in {filename}")
        for name, obj in meshes.items():
            record = by_file[filename][name]
            check_close(convert_position(obj.matrix_world.translation), record["pivot"], name + " pivot")
            for actual, expected in zip(bounds([convert_position(obj.matrix_world @ v.co)
                                               for v in obj.data.vertices]), record["bounds"]):
                check_close(actual, expected, name + " bounds")
            obj.data.calc_loop_triangles()
            if len(obj.data.loop_triangles) != record["triangles"] or not obj.data.uv_layers:
                raise RuntimeError(f"{name} changed triangle count or lost UVs")
            if not filename.startswith("query-"):
                if not obj.data.materials or any(mat is None for mat in obj.data.materials):
                    raise RuntimeError(f"{name} lost materials")
            if filename == "pilot.glb":
                bpy.data.objects.remove(obj, do_unlink=True)
            else:
                imported[record["kind"]].append(obj)
    for prefix, sx, sz in (("yard-sw", -1, 1), ("yard-se", 1, 1), ("yard-nw", -1, -1), ("yard-ne", 1, -1)):
        for obj in imported[prefix]:
            point = convert_position(obj.matrix_world.translation)
            if not (sx * point[0] > 8 and sz * point[2] > 8):
                raise RuntimeError(f"Unexpected landmark orientation for {obj.name}")
    wall_points = [convert_position(obj.matrix_world @ v.co) for obj in imported["query-solid"]
                   if obj.get("Surface") == "Wall" for v in obj.data.vertices]
    low, high = bounds(wall_points)
    check_close([high[0] - low[0], high[2] - low[2]], [62.5, 50], "Wall width and depth in studs")
    verify_clearance(imported)
    result = {"batchCount": len(receipt["files"]), "uniqueObjects": sum(map(len, imported.values())),
              "maxPrimitiveTriangles": max_primitive, "panelCount": len(receipt["panels"]),
              "clearance": {"spawnColumns": 225, "portalRays": 252, "northeastBreachOpen": True},
              "sourceSha256": receipt["sourceSha256"]}
    (OUTPUT / "round-trip.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result))


if __name__ == "__main__":
    main()
