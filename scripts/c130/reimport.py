"""Reopen the editable master and independently import its deployed GLB export.

Use Blender background Python. Reports geometry bounds and verifies that the master
and GLB contain no external dependencies. No source or exports are modified.
"""
from pathlib import Path
import json

import bpy

ROOT = Path(__file__).resolve().parents[2]
MASTER = ROOT / "assets/blender/c130/c130.blend"
EXPORT = ROOT / "assets/exports/c130/c130.glb"


def mesh_bounds_and_materials(objects):
    points, material_names = [], set()
    for obj in objects:
        points.extend(obj.matrix_world @ vertex.co for vertex in obj.data.vertices)
        material_names.update(material.name for material in obj.data.materials)
    bounds = [[fn(point[axis] for point in points) for axis in range(3)] for fn in (min, max)]
    return bounds, material_names


def check_outward_normals(objects):
    for obj in objects:
        mesh = obj.data
        mesh.calc_loop_triangles()
        signed_volume = 0.0
        for triangle in mesh.loop_triangles:
            a, b, c = (mesh.vertices[index].co for index in triangle.vertices)
            signed_volume += a.dot(b.cross(c)) / 6
        if signed_volume <= 0:
            raise ValueError(f"{obj.name} has an inverted or empty native shape")


def main():
    bpy.ops.wm.open_mainfile(filepath=str(MASTER))
    source = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    check_outward_normals(source)
    source_bounds, source_materials = mesh_bounds_and_materials(source)
    if bpy.data.libraries or any(image.source == "FILE" and not image.packed_file for image in bpy.data.images):
        raise ValueError("Airframe master contains external sources")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(EXPORT))
    imported = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    check_outward_normals(imported)
    imported_bounds, imported_materials = mesh_bounds_and_materials(imported)
    if len(imported) != len(source) or imported_materials != source_materials:
        raise ValueError("Reimport changed aircraft geometry or material inventory")
    error = max(abs(a - b) for left, right in zip(source_bounds, imported_bounds) for a, b in zip(left, right))
    if error > 0.002:
        raise ValueError(f"Reimport changed the flight-frame size or axes by {error:.4f} studs")
    if bpy.data.images or bpy.data.libraries:
        raise ValueError("Reimport contains untracked file dependencies")
    print(json.dumps({
        "case": "P28BlenderReopen",
        "blender": bpy.app.version_string,
        "masterMeshObjects": len(source),
        "glbMeshObjects": len(imported),
        "materials": sorted(imported_materials),
        "maximumBoundErrorStuds": round(error, 7),
        "externalDependencies": 0,
        "outwardNormals": True,
        "passed": True,
    }))


if __name__ == "__main__":
    main()
