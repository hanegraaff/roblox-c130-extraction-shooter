"""Reopen the P29 master and import its GLB in a fresh Blender scene."""
from pathlib import Path
import json
import sys

import bpy

ROOT = Path(__file__).resolve().parents[2]
MASTER = ROOT / "assets/blender/rocket-launcher/rocket-launcher.blend"
EXPORT = ROOT / "assets/exports/rocket-launcher/rocket-launcher.glb"
# These generic mesh checks also verify the existing P28 export.
sys.path.insert(0, str(ROOT / "scripts/c130"))
from reimport import check_outward_normals, mesh_bounds_and_materials


def main():
    bpy.ops.wm.open_mainfile(filepath=str(MASTER))
    source = [obj for obj in bpy.context.scene.objects if obj.get("NativeShape")]
    check_outward_normals(source)
    source_bounds, materials = mesh_bounds_and_materials(source)
    if bpy.data.libraries or bpy.data.images:
        raise ValueError("The master has linked or image dependencies")
    landmarks = {name: (axis, bpy.data.objects[name].location[axis])
                 for name, axis in (("Diagonal teal paint", 1), ("Offset teal plate face", 0))}
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(EXPORT))
    imported = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    check_outward_normals(imported)
    imported_bounds, imported_materials = mesh_bounds_and_materials(imported)
    if len(imported) != len(source) or imported_materials != materials or bpy.data.libraries or bpy.data.images:
        raise ValueError("The GLB changed the expected independent geometry or materials")
    bound_error = max(abs(a - b) for left, right in zip(source_bounds, imported_bounds) for a, b in zip(left, right))
    if bound_error > .0001:
        raise ValueError(f"The GLB changed the source axis convention or dimensions by {bound_error:.6f} studs")
    # The forward stripe and the asymmetric teal side plate independently check
    # axis signs as well as whole-object dimensions.
    landmark_error = 0
    for name, (axis, expect) in landmarks.items():
        seen = bpy.data.objects[name].location[axis]
        if seen <= 0 or abs(expect - seen) > .0001:
            raise ValueError(f"The GLB changed the orientation of {name}")
        landmark_error = max(landmark_error, abs(expect - seen))
    print(json.dumps({
        "case": "P29BlenderReopen", "blender": bpy.app.version_string, "passed": True,
        "masterMeshObjects": len(source), "glbMeshObjects": len(imported), "materials": sorted(materials),
        "maximumBoundErrorStuds": bound_error, "maximumLandmarkErrorStuds": landmark_error,
        "externalDependencies": 0, "outwardNormals": True,
    }))


if __name__ == "__main__":
    main()
