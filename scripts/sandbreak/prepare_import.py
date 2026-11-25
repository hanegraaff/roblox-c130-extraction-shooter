"""Stage a reviewable Sandbreak import from the approved Blender source.

Run in Blender background mode with the Sandbreak file open. Only generated
files in build/sandbreak-import are written. The Blender source is read-only.
"""
from collections import defaultdict
import hashlib
import json
from pathlib import Path

import bpy
from mathutils import Vector
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
BLEND = ROOT / "assets/blender/spawn-bunker/sandbreak-bunker.blend"
OUTPUT = ROOT / "build/sandbreak-import"
PILOT_NAMES = ("SB.W.S.01", "SB.R.07.07")
DIMENSION_TOLERANCE = 0.0001
TILE_SIZE = 256
MAX_TRIANGLES = 20_000
BATCH_SIZE = 42


def stage_objects(scene):
    """Select authored meshes by purpose, including disabled damage templates."""
    collections = {child.name[:2]: child for child in scene.collection.children}
    batches = defaultdict(list)
    for prefix in ("01", "02", "03", "04", "05", "06", "07", "08"):
        for obj in sorted(collections[prefix].all_objects, key=lambda item: item.name):
            if obj.type not in {"MESH", "FONT"}:
                continue
            group = obj.get("Appearance")
            if group in {"Solid", "Residual"}:
                kind = "query-" + group.lower()
            elif group in {"Pristine", "Light", "Heavy"}:
                kind = "panel-" + group.lower()
            elif obj.get("PanelId"):
                kind = "attached-art"
            else:
                kind = "structure" if prefix == "03" else "hall-dressing"
            batches[kind].append(obj)
    for prop in sorted(collections["11"].children, key=lambda item: item.name):
        key = prop.name.split()[0].lower()
        batches["yard-" + key] = sorted(
            (obj for obj in prop.objects if obj.type in {"MESH", "FONT"}),
            key=lambda item: item.name,
        )
    return batches


def texture_plane(scene):
    """Create a 4-stud bake tile matching the source meshes' planar UVs."""
    mesh = bpy.data.meshes.new("Sandbreak color tile")
    mesh.from_pydata([(0, 0, 0), (4, 0, 0), (4, 4, 0), (0, 4, 0)], [], [(0, 1, 2, 3)])
    mesh.uv_layers.new().data.foreach_set("uv", [0, 0, 1, 0, 1, 1, 0, 1])
    obj = bpy.data.objects.new("Sandbreak color tile", mesh)
    scene.collection.objects.link(obj)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    return obj


def color_tile(original, shader, plane):
    """Bake procedural color to a repeatable sRGB tile with paired edge pixels."""
    temporary = original.copy()
    graph = temporary.node_tree
    color = next(node for node in graph.nodes if node.type == "BSDF_PRINCIPLED").inputs["Base Color"]
    emission = graph.nodes.new("ShaderNodeEmission")
    graph.links.new(color.links[0].from_socket, emission.inputs["Color"])
    output = next(node for node in graph.nodes if node.type == "OUTPUT_MATERIAL")
    graph.links.new(emission.outputs[0], output.inputs["Surface"])
    image = bpy.data.images.new(original.name + " baked color", TILE_SIZE, TILE_SIZE, alpha=False)
    target = graph.nodes.new("ShaderNodeTexImage")
    target.image = image
    graph.nodes.active = target
    plane.data.materials.clear()
    plane.data.materials.append(temporary)
    bpy.ops.object.bake(type="EMIT", margin=0)
    pixels = np.empty(TILE_SIZE * TILE_SIZE * 4, dtype=np.float32)
    image.pixels.foreach_get(pixels)
    pixels = pixels.reshape((TILE_SIZE, TILE_SIZE, 4))
    # Preserve the procedural pattern across most of the tile and feather
    # opposing edges to a common value at the repeating UV seam.
    for axis in (0, 1):
        rows = np.moveaxis(pixels, axis, 0)
        for offset in range(14):
            a, b = rows[offset].copy(), rows[-offset - 1].copy()
            blend = 0.5 * (1 - offset / 14) ** 2
            rows[offset] = a * (1 - blend) + b * blend
            rows[-offset - 1] = b * (1 - blend) + a * blend
    image.pixels.foreach_set(pixels.ravel())
    image.pack()
    node = shader.id_data.nodes.new("ShaderNodeTexImage")
    node.image = image
    shader.id_data.links.new(node.outputs["Color"], shader.inputs["Base Color"])
    plane.data.materials.clear()
    bpy.data.materials.remove(temporary)


def export_materials(scene, objects):
    """Build portable GLB materials. The approved Blender shader graph is untouched."""
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 1
    plane = texture_plane(scene)
    originals = sorted({material for obj in objects for material in obj.data.materials if material},
                       key=lambda item: item.name)
    materials = {}
    for original in originals:
        principled = next(node for node in original.node_tree.nodes if node.type == "BSDF_PRINCIPLED")
        material = bpy.data.materials.new(original.name + " | import")
        material.use_nodes = True
        material.diffuse_color = original.diffuse_color
        material.use_backface_culling = False
        shader = material.node_tree.nodes.get("Principled BSDF")
        for key in ("Base Color", "Metallic", "Roughness", "Emission Color", "Emission Strength"):
            shader.inputs[key].default_value = principled.inputs[key].default_value
        if principled.inputs["Base Color"].is_linked:
            color_tile(original, shader, plane)
        materials[original] = material
    bpy.data.objects.remove(plane, do_unlink=True)
    return materials


def convert_position(point):
    return [point.x, point.z, -point.y]


def bounds(points):
    axes = tuple(zip(*points))
    return [[round(extreme(values), 6) for values in axes] for extreme in (min, max)]


def copy_mesh(source, scene, material_map, depsgraph, cached_meshes):
    """Make evaluated export geometry with the exact source pivot in asset space."""
    if source.type == "MESH" and not source.modifiers:
        mesh = cached_meshes.get(source.data)
        if mesh is None:
            mesh = source.data.copy()
            cached_meshes[source.data] = mesh
    else:
        mesh = bpy.data.meshes.new_from_object(source.evaluated_get(depsgraph), preserve_all_data_layers=True,
                                               depsgraph=depsgraph)
    for index, mat in enumerate(mesh.materials):
        if mat in material_map:
            mesh.materials[index] = material_map[mat]
    if not mesh.uv_layers:
        uv = mesh.uv_layers.new()
        for poly in mesh.polygons:
            axis = max(range(3), key=lambda index: abs(poly.normal[index]))
            for index in poly.loop_indices:
                point = mesh.vertices[mesh.loops[index].vertex_index].co
                uv.data[index].uv = (point[(axis + 1) % 3] / 4, point[(axis + 2) % 3] / 4)
    result = bpy.data.objects.new(source.name, mesh)
    scene.collection.objects.link(result)
    result.matrix_world = source.matrix_world
    for key in ("PanelId", "BuildingId", "StoryId", "Appearance", "SupportPanels",
                "RemoveWithPanel", "ThermalNonCover", "Surface"):
        if key in source:
            result[key] = source[key]
    return result


def write_batch(scene, copies, filename, records):
    """Write one batch and record its object identities, exact pivots and extents."""
    bpy.ops.object.select_all(action="DESELECT")
    for source, copy in copies:
        copy.select_set(True)
    bpy.context.view_layer.update()
    for source, copy in copies:
        original = records[source.name]
        original.setdefault("exports", {})[filename] = copy.name
    path = OUTPUT / filename
    bpy.ops.export_scene.gltf(
        filepath=str(path), export_format="GLB", use_selection=True, export_yup=True,
        export_materials="NONE" if filename.startswith("query-") else "EXPORT",
        export_extras=True, export_cameras=False, export_lights=False,
        export_animations=False, export_image_format="AUTO", export_texcoords=True, export_normals=True,
    )
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    if Path(bpy.data.filepath).resolve() != BLEND:
        raise RuntimeError(f"Open the approved source before staging: {BLEND}")
    OUTPUT.mkdir(parents=True, exist_ok=True)
    source_scene = bpy.context.scene
    batches = stage_objects(source_scene)
    # Enable the hidden variant bank in memory for evaluated transform access.
    for child in source_scene.collection.children:
        if child.name.startswith("08"):
            bpy.context.view_layer.layer_collection.children[child.name].exclude = False
    bpy.context.view_layer.update()
    depsgraph = bpy.context.evaluated_depsgraph_get()
    material_map = export_materials(source_scene, batches["panel-pristine"] + batches["attached-art"]
                                   + batches["structure"] + batches["hall-dressing"]
                                   + batches["panel-light"] + batches["panel-heavy"]
                                   + [obj for key in batches if key.startswith("yard-") for obj in batches[key]])
    depsgraph = bpy.context.evaluated_depsgraph_get()
    cache = {}
    records = {}
    located = {}
    panel_index = defaultdict(dict)
    for name, originals in sorted(batches.items()):
        located[name] = []
        for index, source in enumerate(originals, start=1):
            copy = copy_mesh(source, source_scene, material_map, depsgraph, cache)
            copy.name = f"SB_{name.replace('-', '_')}_{index:03d}"
            copy.data.calc_loop_triangles()
            triangles = len(copy.data.loop_triangles)
            if not 0 < triangles <= MAX_TRIANGLES:
                raise RuntimeError(f"{source.name}: {triangles} triangles")
            local = [convert_position(vert.co) for vert in copy.data.vertices]
            world = [convert_position(copy.matrix_world @ vert.co) for vert in copy.data.vertices]
            record = {
                "pivot": convert_position(copy.matrix_world.translation),
                "localBounds": bounds(local),
                "bounds": bounds(world),
                "triangles": triangles,
                "kind": name,
                **{key: copy[key] for key in copy.keys()},
            }
            records[source.name] = record
            if appearance := source.get("Appearance"):
                panel_index[source["PanelId"]][appearance] = source.name
            located[name].append((source, copy))
    expected = {"Pristine", "Light", "Heavy", "Solid", "Residual"}
    if len(panel_index) != 103 or any(set(variants) != expected for variants in panel_index.values()):
        raise RuntimeError("Unexpected Sandbreak panel inventory")
    for variants in panel_index.values():
        reference = Vector(records[variants["Pristine"]]["pivot"])
        if any((reference - Vector(records[name]["pivot"])).length > DIMENSION_TOLERANCE
               for name in variants.values()):
            raise RuntimeError(f"Misaligned panel: {variants}")
    files = {}
    for name, copies in located.items():
        for offset in range(0, len(copies), BATCH_SIZE):
            filename = f"{name}-{offset // BATCH_SIZE + 1:02d}.glb"
            files[filename] = write_batch(source_scene, copies[offset:offset + BATCH_SIZE], filename, records)
    pilot = [(source, copy) for source, copy in located["panel-pristine"] if source["PanelId"] in PILOT_NAMES]
    if len(pilot) != len(PILOT_NAMES):
        raise RuntimeError("Missing pilot panels")
    files["pilot.glb"] = write_batch(source_scene, pilot, "pilot.glb", records)
    payload = {
        "blender": bpy.app.version_string,
        "source": BLEND.relative_to(ROOT).as_posix(),
        "sourceSha256": hashlib.sha256(BLEND.read_bytes()).hexdigest(),
        "units": "1 Blender unit = 1 stud. Blender (X,Y,Z) becomes GLB (X,Z,-Y).",
        "siteOriginRoblox": [0, 0, 120],
        "sourceFloor": 0,
        "portalClearWidthStuds": 16,
        "yardLandmarks": {"tank": "SW", "patrol": "SE", "carrier": "NW", "radio": "NE"},
        "panels": panel_index,
        "objects": records,
        "files": files,
    }
    (OUTPUT / "import-index.json").write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    print(f"Staged {len(files)} GLBs and {len(panel_index)} panel identities in {OUTPUT}")


if __name__ == "__main__":
    main()
