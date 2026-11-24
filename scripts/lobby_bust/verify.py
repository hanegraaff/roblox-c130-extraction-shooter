"""Inspect P20's saved .blend and independently imported GLB in a fresh Blender.

From the repository root:
    blender -b --python-exit-code 1 --python scripts/lobby_bust/verify.py

The checks establish the authored handoff. Artistic acceptance belongs to the
user inspecting this exact revision. Studio placement belongs to P22.
"""

from hashlib import sha256
import json
from math import asin, degrees, isfinite
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/blender/lobby-bust/lobby-bust.blend"
EXPORT = ROOT / "assets/exports/lobby-bust/lobby-bust.glb"
TOLERANCE = 0.001
PIVOT_NAME = "Lobby Bust · base center"


def fingerprint(path):
    return sha256(path.read_bytes()).hexdigest()


def inspect_shell(name, mesh, vertices):
    """Check that a collar or ear is a closed solid with an outward exterior.

    Importers may split a vertex at shading/UV seams. Weld coincident vertices
    only on a disposable BMesh for the topological check. Then test geometric
    first-hit normals directly on the actual evaluated triangles. A positive
    volume by itself would miss a locally folded shell.
    """
    solid = bmesh.new()
    try:
        solid.from_mesh(mesh)
        bmesh.ops.remove_doubles(solid, verts=list(solid.verts), dist=1e-7)
        assert all(edge.is_manifold and edge.is_contiguous for edge in solid.edges), name
        assert solid.calc_volume(signed=True) > 0, f"{name}: inward closed mesh"
    finally:
        solid.free()

    tree = BVHTree.FromPolygons(vertices, [tri.vertices[:]
                                for tri in mesh.loop_triangles], all_triangles=True)
    axes = [Vector(v).normalized() for v in (
        (0, 1, 0), (-.6, .8, -.12), (-1, 0, 0), (1, 0, 0), (0, -1, 0), (0, -.3, -1), (0, .3, 1))]
    hits = 0
    for ray in axes:
        right = ray.cross(Vector((0, 0, 1))).normalized()
        up = right.cross(ray)
        u = [v.dot(right) for v in vertices]
        v = [p.dot(up) for p in vertices]
        front = min(p.dot(ray) for p in vertices)-1
        min_u, min_v = min(u), min(v)
        span_u, span_v = max(u)-min_u, max(v)-min_v
        for i in range(27):
            for j in range(27):
                origin = (ray*front + right*(min_u+(i+.5)*span_u/27)
                          + up*(min_v+(j+.5)*span_v/27))
                _, normal, index, _ = tree.ray_cast(origin, ray)
                if index is not None:
                    assert normal.dot(ray) < .001, f"{name}: exposed reversed face {index}"
                    hits += 1
    assert hits > 200, f"{name}: inadequate external surface coverage"
    return hits


def inspect(objects):
    """Measure evaluated, world-space mesh and material data in Blender axes."""
    graph = bpy.context.evaluated_depsgraph_get()
    low = Vector((1e6, 1e6, 1e6))
    high = -low
    materials = set()
    triangles = {}
    part_bounds = {}
    exterior_hits = {}
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
            if "collar" in obj.name.lower() or obj.name.startswith("07 | Modeled ear"):
                exterior_hits[obj.name] = inspect_shell(obj.name, mesh, coords)
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
    assert len(exterior_hits) == 5
    return low, high, part_bounds, triangles, materials, exterior_hits


def inspect_expression(parts):
    """Check the modeled gaze and forward-to-back forelock geometry on both packages."""
    graph = bpy.context.evaluated_depsgraph_get()
    by_name = {obj.name: obj for obj in parts}

    def frontal_hit(tree, x, z):
        return tree.ray_cast(Vector((x, -12, z)), Vector((0, 1, 0)))

    gaze = {}
    for side in (-1, 1):
        pupil = by_name[f"06 | Pupil {side:+d}"]
        lo = pupil.bound_box[0]
        hi = pupil.bound_box[6]
        x, z = (lo[0]+hi[0])*.5, (lo[2]+hi[2])*.5
        tree = BVHTree.FromObject(pupil, graph)
        point, normal, *_ = frontal_hit(tree, x, z)
        assert point is not None and normal.y < -.9
        pitch = degrees(asin(normal.z))
        assert -20 < pitch < -13, (pupil.name, "gaze above/below the intended floor sightline", pitch)
        eye = BVHTree.FromObject(by_name[f"06 | Eye globe {side:+d}"], graph)
        visible_z = [z+step*.005 for step in range(-110, 111)
                     if frontal_hit(eye, x, z+step*.005)[0] is not None]
        upper, lower = max(visible_z)-z, z-min(visible_z)
        assert upper-lower > .2, f"{pupil.name}: upper sclera must read above the lowered iris"
        gaze[pupil.name] = [round(pitch, 2), round(upper, 3), round(lower, 3)]

    hair = BVHTree.FromObject(by_name["08 | Swept hair · crown, temples and nape"], graph)
    roll = {}
    for x in (-.65, 0, .65):
        def depth(z):
            point, *_ = frontal_hit(hair, x, z)
            assert point is not None, ("missing forelock", x, z)
            return -point.y

        hairline = depth(18.0)
        crest = max(depth(18.36+i*.06) for i in range(12))
        crown = depth(19.44)
        assert crest > hairline+.24 and crest > crown+.75, ("unrolled forelock", x, hairline, crest, crown)
        roll[x] = [round(hairline, 3), round(crest, 3), round(crown, 3)]
    return {"pupil_pitch_and_upper_lower_clearance": gaze, "root_crest_crown_depth_studs": roll}


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
assert len(cameras) == 4 and any("Hair roll" in cam.name for cam in cameras)
eye_camera = next(cam for cam in cameras if cam.name.startswith("A2"))
assert abs(eye_camera.location.z - (-2.65 + 4.5)) < TOLERANCE
assert eye_camera.location.y == -45 and eye_camera.data.type == "PERSP"
src_low, src_high, src_bounds, src_counts, src_mats, src_hits = inspect(source_parts)
src_maps = packed_maps()
source_expression = inspect_expression(source_parts)

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
glb_low, glb_high, glb_bounds, counts, mats, glb_hits = inspect(parts)
assert mats == src_mats and packed_maps() == src_maps
export_expression = inspect_expression(parts)
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
    "expression": {"source": source_expression, "export": export_expression},
    "outward_shell_hits": {"source": src_hits, "export": glb_hits},
    "stage_cameras": len(cameras),
}, indent=2))
