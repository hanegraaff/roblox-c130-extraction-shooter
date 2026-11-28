"""Produce a Rojo model and a portable GLB from the saved launcher master."""
from pathlib import Path
import hashlib
import json
import struct
import sys

import bpy
from mathutils import Matrix

ROOT = Path(__file__).resolve().parents[2]
MASTER = ROOT / "assets/blender/rocket-launcher/rocket-launcher.blend"
EXPORT = ROOT / "assets/exports/rocket-launcher"
NATIVE = ROOT / "assets/models/DepotLauncher.model.json"
TO_ROBLOX = Matrix(((1, 0, 0), (0, 0, 1), (0, -1, 0)))
ATTACHMENTS = ("CarryGrip", "Muzzle", "GroundContact")


def values(source):
    return [0 if abs(number) < 0.0000005 else round(number, 6) for number in source]


def frame(position, rotation):
    return values(position) + values(channel for row in rotation for channel in row)


def pose(obj):
    origin, quaternion, scale = obj.matrix_world.decompose()
    actual = Matrix.LocRotScale(origin, quaternion, scale)
    if any(x <= 0 for x in scale) or any(abs(a - b) > 0.0001 for row, expected in zip(actual, obj.matrix_world)
                                          for a, b in zip(row, expected)):
        raise ValueError(f"{obj.name}: negative scale or skew cannot use the matching native profile")
    return TO_ROBLOX @ origin, TO_ROBLOX @ quaternion.to_matrix(), scale


def srgb(value):
    return 1.055 * value ** (1 / 2.4) - .055 if value > .0031308 else value * 12.92


def native_part(name, kind, transform, size, color, *, transparent=False):
    return {
        "Name": name, "ClassName": kind,
        "Properties": {
            "Size": size, "CFrame": transform, "Color": color, "Anchored": True,
            "CanCollide": False, "CanQuery": False, "CanTouch": False, "Massless": True,
            "Material": "SmoothPlastic", "Transparency": 1 if transparent else 0,
            "CastShadow": not transparent,
        },
    }


def export_part(obj):
    shape = obj["NativeShape"]
    if shape not in {"Block", "Wedge"} or obj.type != "MESH" or len(obj.data.materials) != 1 or obj.modifiers:
        raise ValueError(f"{obj.name}: expected one unmodified stock profile and one material")
    # Moving only the object transforms keeps the GLB and the managed native
    # profile equivalent. Reject edits to the underlying profile vertices.
    corners = {(x, y, z) for x in (-.5, .5) for y in (-.5, .5) for z in (-.5, .5)
               if shape == "Block" or (y, z) != (.5, -.5)}
    if {tuple(values(vertex.co)) for vertex in obj.data.vertices} != corners:
        raise ValueError(f"{obj.name}: edit dimensions and orientation at the object level")
    material = obj.data.materials[0]
    shade = material.node_tree.nodes.get("Principled BSDF").inputs["Base Color"].default_value
    origin, rotation, size = pose(obj)
    return native_part(obj.name, "WedgePart" if shape == "Wedge" else "Part", frame(origin, rotation),
                       values(size), values(srgb(channel) for channel in shade[:3]))


def save_json(path, contents):
    path.write_text(json.dumps(contents, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    if Path(bpy.data.filepath).resolve() != MASTER:
        raise ValueError("Open the managed editable master before exporting")
    objects = sorted((obj for obj in bpy.context.scene.objects if "NativeShape" in obj), key=lambda obj: obj.name)
    markers = {obj.name: obj for obj in bpy.context.scene.objects if obj.get("LauncherAttachment")}
    if set(markers) != set(ATTACHMENTS):
        raise ValueError("The depot launcher requires the carry, muzzle and resting-plane attachments")
    if bpy.data.libraries or any(image.source == "FILE" and not image.packed_file for image in bpy.data.images):
        raise ValueError("The master has external dependencies")
    attachment_frames = {name: frame(*pose(markers[name])[:2]) for name in ATTACHMENTS}
    handle = native_part("Handle", "Part", frame((0, 0, 0), Matrix.Identity(3)), [.2] * 3, [0] * 3,
                         transparent=True)
    handle["Children"] = [{"Name": name, "ClassName": "Attachment", "Properties": {"CFrame": transform}}
                          for name, transform in attachment_frames.items()]
    native_parts = [export_part(obj) for obj in objects]
    save_json(NATIVE, {"ClassName": "Model", "Children": [handle, *native_parts]})

    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    glb = EXPORT / "rocket-launcher.glb"
    bpy.ops.export_scene.gltf(filepath=str(glb), export_format="GLB", use_selection=True, export_yup=True,
                              export_texcoords=False, export_animations=False, export_cameras=False,
                              export_lights=False, export_extras=False)
    loaded = glb.read_bytes()
    length, kind = struct.unpack_from("<II", loaded, 12)
    if kind != 0x4E4F534A:
        raise ValueError("GLB lacks its required JSON chunk")
    graph = json.loads(loaded[20:20 + length])
    if len(graph["nodes"]) != len(objects) or len(graph["meshes"]) != len(objects) or graph.get("images"):
        raise ValueError("GLB inventory differs from the managed pieces")
    triangle_count = sum(graph["accessors"][primitive["indices"]]["count"] // 3
                         for mesh in graph["meshes"] for primitive in mesh["primitives"])
    points = [TO_ROBLOX @ (obj.matrix_world @ vertex.co) for obj in objects for vertex in obj.data.vertices]
    bounds = {key: values(measure(point[axis] for point in points) for axis in range(3))
              for key, measure in (("minimum", min), ("maximum", max))}
    audit = {
        "schemaVersion": 1,
        "blenderVersion": bpy.app.version_string,
        "blenderUnitsPerStud": 1,
        "blenderUnitLengthMeters": bpy.context.scene.unit_settings.scale_length,
        "axisConvention": {"blender": "+X right, +Y front, +Z up", "robloxAndGlb": "+X right, -Z front, +Y up"},
        "externalAssetDependencies": [],
        "meshObjects": len(objects),
        "triangles": triangle_count,
        "materials": sorted({obj.data.materials[0].name for obj in objects}),
        "boundsStuds": bounds,
        "attachments": attachment_frames,
        "sha256": {str(path.relative_to(ROOT)): sha(path) for path in (MASTER, glb, NATIVE)},
    }
    save_json(EXPORT / "package-audit.json", audit)
    print(json.dumps(audit))
    if "--render" in sys.argv:
        scene = bpy.context.scene
        scene.render.filepath = str(EXPORT / "three-quarter.png")
        bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    main()
