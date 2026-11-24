"""Inspect P20's saved .blend and independently imported GLB in a fresh Blender.

From the repository root:
    blender -b --python-exit-code 1 --python scripts/lobby_bust/verify.py

The checks establish the authored handoff. Artistic acceptance belongs to the
user inspecting this exact revision. Studio placement belongs to P22.
"""

from hashlib import sha256
import json
from math import isfinite
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/blender/lobby-bust/lobby-bust.blend"
EXPORT = ROOT / "assets/exports/lobby-bust/lobby-bust.glb"
TOLERANCE = 0.001
PIVOT_NAME = "Lobby Bust · base center"


def fingerprint(path):
    return sha256(path.read_bytes()).hexdigest()


def inspect(objects):
    """Measure evaluated, world-space mesh and material data in Blender axes."""
    graph = bpy.context.evaluated_depsgraph_get()
    low = Vector((1e6, 1e6, 1e6))
    high = -low
    materials = set()
    triangles = {}
    part_bounds = {}
    for obj in objects:
        evaluated = obj.evaluated_get(graph)
        mesh = evaluated.to_mesh()
        try:
            mesh.calc_loop_triangles()
            count = len(mesh.loop_triangles)
            assert 0 < count < 20000, (obj.name, count)
            triangles[obj.name] = count
            materials.update(mat.name for mat in mesh.materials)
            assert mesh.uv_layers.active and len(mesh.uv_layers.active.data), obj.name
            coords = [evaluated.matrix_world @ vert.co for vert in mesh.vertices]
            assert all(isfinite(v) for point in coords for v in point), obj.name
            assert all(.99 <= vert.normal.length <= 1.01 for vert in mesh.vertices), obj.name
            bounds = [
                [min(point[i] for point in coords) for i in range(3)],
                [max(point[i] for point in coords) for i in range(3)],
            ]
            part_bounds[obj.name] = bounds
            for axis in range(3):
                low[axis] = min(low[axis], bounds[0][axis])
                high[axis] = max(high[axis], bounds[1][axis])
        finally:
            evaluated.to_mesh_clear()
    assert len(objects) >= 20 and len(materials) == 6
    return low, high, part_bounds, triangles, materials


def packed_maps():
    images = {im.name for im in bpy.data.images if im.name.endswith("original grain")}
    assert len(images) == 3
    for name in images:
        im = bpy.data.images[name]
        assert tuple(im.size) == (384, 384) and im.packed_file, name
    normal_map = bpy.data.images["Combed locks · chisel normal"]
    assert tuple(normal_map.size) == (1024, 512) and normal_map.packed_file
    return images | {normal_map.name}


bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
source_scene = bpy.context.scene
sculpt = bpy.data.collections["Lobby Bust · export meshes"]
source_parts = [obj for obj in sculpt.objects if obj.type == "MESH"]
root = bpy.data.objects[PIVOT_NAME]
assert tuple(root.location) == (0., 0., 0.) and all(part.parent == root for part in source_parts)
cameras = [obj for obj in source_scene.objects if obj.type == "CAMERA"]
assert len(cameras) == 3
eye_camera = next(cam for cam in cameras if cam.name.startswith("A2"))
assert abs(eye_camera.location.z - (-2.65 + 4.5)) < TOLERANCE
assert eye_camera.location.y == -45 and eye_camera.data.type == "PERSP"
src_low, src_high, src_bounds, src_counts, src_mats = inspect(source_parts)
src_maps = packed_maps()

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(EXPORT))
imported = list(bpy.context.scene.objects)
assert all(obj.type in ("MESH", "EMPTY") for obj in imported)
export_root, = [obj for obj in imported if obj.parent is None]
assert export_root.name == PIVOT_NAME and export_root.type == 'EMPTY'
assert tuple(export_root.location) == (0., 0., 0.)
parts = [obj for obj in imported if obj.type == 'MESH']
assert {obj.name for obj in parts} == set(src_bounds)
assert all(obj.parent == export_root and not obj.animation_data for obj in parts)
glb_low, glb_high, glb_bounds, counts, mats = inspect(parts)
assert mats == src_mats and packed_maps() == src_maps
for name, bounds in glb_bounds.items():
    for a, b in zip(bounds, src_bounds[name]):
        assert max(abs(x-y) for x, y in zip(a, b)) < TOLERANCE, name

foot_low, foot_high = glb_bounds["01 | Turned socle"]
diameter = foot_high[0] - foot_low[0]
assert abs(diameter - 9.68) < TOLERANCE
assert abs((foot_high[1] - foot_low[1]) - diameter) < TOLERANCE
assert max(abs(foot_high[axis]+foot_low[axis]) for axis in (0, 1)) < TOLERANCE
assert abs(glb_low.z) < TOLERANCE
nose_low, _ = glb_bounds["05b | Dorsum, alae and nose tip"]
_, head_high = glb_bounds["05 | Portrait · face, jowls and throat"]
assert nose_low[1] < -3.8 and head_high[1] > 2.3
dimension = glb_high - glb_low
print("P20_REOPEN_AND_REIMPORT_PASS")
print(json.dumps({
    "blender": bpy.app.version_string,
    "source_sha256": fingerprint(SOURCE),
    "export_sha256": fingerprint(EXPORT),
    "size_xyz_studs": [round(v, 3) for v in dimension],
    "base_diameter_studs": round(diameter, 3),
    "mesh_count": len(parts),
    "triangles": sum(counts.values()),
    "largest_mesh_triangles": max(counts.values()),
    "materials": sorted(mats),
    "packed_maps": sorted(src_maps),
    "stage_cameras": len(cameras),
}, indent=2))
