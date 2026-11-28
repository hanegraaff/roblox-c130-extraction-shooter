"""Independently reopen the field case master and verify the clean GLB import."""
from pathlib import Path
import json
import sys

import bpy

ROOT = Path(__file__).resolve().parents[2]
MASTER = ROOT / "assets/blender/medkit/medkit.blend"
EXPORT = ROOT / "assets/exports/medkit/field-medkit.glb"
sys.path.insert(0, str(ROOT / "scripts/c130"))
from reimport import check_outward_normals, mesh_bounds_and_materials


def main():
    bpy.ops.wm.open_mainfile(filepath=str(MASTER))
    source = [obj for obj in bpy.context.scene.objects if obj.get("NativeShape")]
    check_outward_normals(source)
    source_bounds, source_materials = mesh_bounds_and_materials(source)
    if bpy.data.libraries or bpy.data.images:
        raise ValueError("The medkit master has linked or image dependencies")
    landmark_names = ("Ivory cross upright", "right hinge knuckle")
    landmarks = {name: bpy.data.objects[name].location.copy() for name in landmark_names}
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(EXPORT))
    imported = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    check_outward_normals(imported)
    imported_bounds, imported_materials = mesh_bounds_and_materials(imported)
    if len(imported) != len(source) or imported_materials != source_materials or bpy.data.libraries or bpy.data.images:
        raise ValueError("The GLB changed the expected independent geometry or materials")
    bound_error = max(abs(a - b) for left, right in zip(source_bounds, imported_bounds) for a, b in zip(left, right))
    landmark_error = max((bpy.data.objects[name].location - location).length for name, location in landmarks.items())
    if max(bound_error, landmark_error) > .0001:
        raise ValueError("The GLB changed source axes, dimensions or landmark placement")
    if bpy.data.objects[landmark_names[0]].location.y <= 0 or bpy.data.objects[landmark_names[1]].location.y >= 0:
        raise ValueError("The marked front and hinged rear must remain on opposite sides")
    print(json.dumps({
        "case": "P30BlenderReopen", "blender": bpy.app.version_string, "passed": True,
        "masterMeshObjects": len(source), "glbMeshObjects": len(imported), "materials": sorted(imported_materials),
        "maximumBoundErrorStuds": bound_error, "maximumLandmarkErrorStuds": landmark_error,
        "externalDependencies": 0, "outwardNormals": True,
    }))


if __name__ == "__main__":
    main()
