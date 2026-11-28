"""Compile the saved aircraft to the Rojo model and an independently reimportable GLB.

Invoke with Blender and the saved master already open. --render also renders the
review camera using the saved stage. Native meshes use the supported stock Roblox
shapes tagged in the Blender master and inherit its dimensions, pose and colors.
"""
from pathlib import Path
from math import isfinite
import hashlib
import json
import struct
import sys

import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
MASTER = ROOT / "assets/blender/c130/c130.blend"
EXPORT = ROOT / "assets/exports/c130"
NATIVE = ROOT / "assets/models/C130.model.json"
TO_ROBLOX = Matrix(((1, 0, 0), (0, 0, 1), (0, -1, 0)))
ROTORS = ("Port1", "Port2", "Starboard1", "Starboard2")
SHAPES = {"Ball", "Block", "Cylinder", "Wedge"}
MUZZLES = ("GAU23Muzzle", "M102Muzzle")


def clean(value):
    return round(value, 6) if abs(value) >= 0.0000005 else 0


def values(source):
    return [clean(number) for number in source]


def frame(center, rotation=None):
    if rotation is None:
        rotation = Matrix.Identity(3)
    return values(center) + values(number for row in rotation for number in row)


def transform(obj):
    origin, quaternion, scale = obj.matrix_world.decompose()
    if any(not isfinite(channel) or channel <= 0 for channel in scale):
        raise ValueError(f"{obj.name} must have finite positive scale")
    reconstructed = Matrix.LocRotScale(origin, quaternion, scale)
    if any(abs(a - b) > 1e-4 for r, s in zip(reconstructed, obj.matrix_world) for a, b in zip(r, s)):
        raise ValueError(f"{obj.name} cannot use sheared or mirrored transforms")
    return TO_ROBLOX @ origin, TO_ROBLOX @ quaternion.to_matrix(), scale


def srgb(channel):
    return 1.055 * channel ** (1 / 2.4) - 0.055 if channel > 0.0031308 else 12.92 * channel


def base_part(name, size, placement, color, *, shape="Block", query=False, transparency=0):
    props = {
        "Size": size, "CFrame": placement, "Anchored": True, "CanCollide": False,
        "CanQuery": query, "CanTouch": False, "Color": color, "Material": "SmoothPlastic",
        "Transparency": transparency, "CastShadow": transparency == 0,
    }
    if shape != "Wedge":
        props["Shape"] = shape
    return {"Name": name, "ClassName": "WedgePart" if shape == "Wedge" else "Part", "Properties": props}


def export_part(obj):
    shape = obj["NativeShape"]
    if shape not in SHAPES or obj.type != "MESH" or len(obj.data.materials) != 1 or obj.modifiers:
        raise ValueError(f"{obj.name} needs one native shape, one material, and no modifiers")
    origin, rotation, scale = transform(obj)
    material = obj.data.materials[0]
    shader = material.node_tree.nodes.get("Principled BSDF")
    local_points = [vertex.co for vertex in obj.data.vertices]
    if any(abs(max(vertex[axis] for vertex in local_points) - 0.5) > 0.003 or
           abs(min(vertex[axis] for vertex in local_points) + 0.5) > 0.003 for axis in range(3)):
        raise ValueError(f"{obj.name}: native shape editing requires object-level transforms")
    return base_part(
        obj.name, values(scale), frame(origin, rotation),
        values(srgb(channel) for channel in shader.inputs["Base Color"].default_value[:3]),
        shape=shape, query=bool(obj["NativeQuery"]), transparency=obj["NativeTransparency"],
    )


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    if Path(bpy.data.filepath).resolve() != MASTER:
        raise ValueError("Open the committed aircraft master before running the exporter")
    EXPORT.mkdir(parents=True, exist_ok=True)
    objects = sorted((obj for obj in bpy.context.scene.objects if "NativeShape" in obj), key=lambda obj: obj.name)
    markers = {obj.name: obj for obj in bpy.context.scene.objects if obj.get("NativeMarker")}
    if set(markers) != set(ROTORS + MUZZLES):
        raise ValueError("Aircraft must have exactly two muzzle and four rotor markers")

    hitbox = base_part("Hitbox", [12, 10, 46], frame((0, 0, 0)), [0.24, 0.28, 0.31], transparency=1)
    hitbox["Children"] = [
        {
            "Name": name if name in MUZZLES else f"Rotor{name}",
            "ClassName": "Attachment",
            "Properties": {"CFrame": frame(*transform(markers[name])[:2])},
        }
        for name in MUZZLES + ROTORS
    ]
    rotors = {name: {"Name": name, "ClassName": "Model", "Children": [
        base_part("Hub", [0.1] * 3, frame(*transform(markers[name])[:2]), [0, 0, 0], transparency=1)
    ]} for name in ROTORS}
    visual = []
    for obj in objects:
        part = export_part(obj)
        if obj.get("Rotor"):
            if part["Properties"]["CanQuery"]:
                raise ValueError("Spinning geometry cannot participate in server queries")
            rotors[obj["Rotor"]]["Children"].append(part)
        else:
            visual.append(part)
    # The stock primitive representation is the normal Rojo model. No remote
    # IDs, mesh API, texture files or Editor-only runtime values are needed.
    model = {
        "ClassName": "Model", "Children": [
            hitbox, {"Name": "Airframe", "ClassName": "Model", "Children": visual},
            {"Name": "Propellers", "ClassName": "Folder", "Children": list(rotors.values())},
        ],
    }
    write_json(NATIVE, model)

    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    glb = EXPORT / "c130.glb"
    bpy.ops.export_scene.gltf(
        filepath=str(glb), export_format="GLB", use_selection=True, export_yup=True, export_apply=False,
        export_materials="EXPORT", export_texcoords=False, export_animations=False,
        export_extras=False, export_lights=False, export_cameras=False,
    )
    loaded = glb.read_bytes()
    json_size, kind = struct.unpack_from("<II", loaded, 12)
    if kind != 0x4E4F534A:
        raise ValueError("GLB missing JSON chunk")
    graph = json.loads(loaded[20:20 + json_size])
    if len(graph["nodes"]) != len(objects) or len(graph["meshes"]) != len(objects) or graph.get("images"):
        raise ValueError("GLB differs from the selected original airframe geometry")
    world_points = [TO_ROBLOX @ (obj.matrix_world @ vertex.co) for obj in objects for vertex in obj.data.vertices]
    minimum = [min(point[axis] for point in world_points) for axis in range(3)]
    maximum = [max(point[axis] for point in world_points) for axis in range(3)]
    for expected, low, high in zip((58, 18.5, 57.6), minimum, maximum):
        if abs(high - low - expected) > 0.18:
            raise ValueError(f"Aircraft dimensions drifted: {minimum} through {maximum}")
    triangle_count = sum(
        graph["accessors"][primitive["indices"]]["count"] // 3
        for mesh in graph["meshes"] for primitive in mesh["primitives"]
    )
    audit = {
        "schemaVersion": 1,
        "blenderVersion": bpy.app.version_string,
        "axisConvention": {"blender": "+X starboard, +Y nose, +Z up", "robloxAndGlb": "+X starboard, -Z nose, +Y up"},
        "blenderUnitsPerStud": 1,
        "blenderScaleLengthMeters": bpy.context.scene.unit_settings.scale_length,
        "externalAssetDependencies": [],
        "meshObjects": len(objects),
        "nativeQueryableObjects": sum(bool(obj["NativeQuery"]) for obj in objects),
        "triangles": triangle_count,
        "boundsStuds": {"minimum": values(minimum), "maximum": values(maximum)},
        "muzzlesStuds": {name: values(transform(markers[name])[0]) for name in MUZZLES},
        "rotorAxesStuds": {name: values(transform(markers[name])[0]) for name in ROTORS},
        "sha256": {str(path.relative_to(ROOT)): sha256(path) for path in (MASTER, glb, NATIVE)},
    }
    write_json(EXPORT / "package-audit.json", audit)
    print(json.dumps(audit, indent=2))
    if "--render" in sys.argv:
        scene = bpy.context.scene
        scene.render.filepath = str(EXPORT / "ground-approach.png")
        bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    main()
