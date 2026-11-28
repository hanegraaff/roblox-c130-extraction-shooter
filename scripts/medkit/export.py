"""Export the saved field case as a portable GLB and a native Rojo model."""
from pathlib import Path
import json
import struct
import sys
import xml.etree.ElementTree as ET

import bpy
from mathutils import Matrix

ROOT = Path(__file__).resolve().parents[2]
MASTER = ROOT / "assets/blender/medkit/medkit.blend"
EXPORT = ROOT / "assets/exports/medkit"
NATIVE = EXPORT / "field-medkit.rbxmx"
FRAME_COMPONENTS = ("X", "Y", "Z", "R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22")
sys.path.insert(0, str(ROOT / "scripts/rocket_launcher"))
from export import TO_ROBLOX, export_part, frame, save_json, sha, values


def prop(parent, kind, name, value):
    property_node = ET.SubElement(parent, kind, name=name)
    property_node.text = str(value)
    return property_node


def vector(parent, kind, name, components, axis_names):
    attributes = {"name": name} if name is not None else {}
    vector_node = ET.SubElement(parent, kind, attributes)
    for axis, value in zip(axis_names, components, strict=True):
        ET.SubElement(vector_node, axis).text = str(value)


def coordinate_frame(parent, name, transform):
    vector(parent, "CoordinateFrame", name, transform, FRAME_COMPONENTS)


def write_native(parts):
    document = ET.Element("roblox", version="4")
    model = ET.SubElement(document, "Item", {"class": "Model", "referent": "FieldMedkit"})
    model_props = ET.SubElement(model, "Properties")
    prop(model_props, "string", "Name", "FieldMedkit")
    prop(model_props, "bool", "NeedsPivotMigration", "false")
    pivot = ET.SubElement(model_props, "OptionalCoordinateFrame", name="WorldPivotData")
    vector(pivot, "CFrame", None, frame((0, 0, 0), Matrix.Identity(3)), FRAME_COMPONENTS)
    for index, part in enumerate(parts):
        object_node = ET.SubElement(model, "Item", {
            "class": part["ClassName"], "referent": f"CasePart{index}",
        })
        native = part["Properties"]
        properties = ET.SubElement(object_node, "Properties")
        prop(properties, "string", "Name", part["Name"])
        coordinate_frame(properties, "CFrame", native["CFrame"])
        vector(properties, "Vector3", "size", native["Size"], ("X", "Y", "Z"))
        for name in ("Anchored", "CanCollide", "CanTouch", "CanQuery", "Massless", "CastShadow"):
            prop(properties, "bool", name, str(native[name]).lower())
        red, green, blue = (round(channel * 255) for channel in native["Color"])
        prop(properties, "Color3uint8", "Color3uint8", (255 << 24) | (red << 16) | (green << 8) | blue)
        prop(properties, "token", "Material", 272)  # SmoothPlastic
        if part["ClassName"] == "Part":
            prop(properties, "token", "shape", 1)  # Block
    ET.indent(document, space="  ")
    ET.ElementTree(document).write(NATIVE, encoding="utf-8", xml_declaration=True)


def export_glb(objects):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    glb = EXPORT / "field-medkit.glb"
    bpy.ops.export_scene.gltf(filepath=str(glb), export_format="GLB", use_selection=True, export_yup=True,
                              export_texcoords=False, export_animations=False, export_cameras=False,
                              export_lights=False, export_extras=False)
    loaded = glb.read_bytes()
    length, chunk_type = struct.unpack_from("<II", loaded, 12)
    if chunk_type != 0x4E4F534A:
        raise ValueError("GLB lacks its required JSON chunk")
    graph = json.loads(loaded[20:20 + length])
    if len(graph["nodes"]) != len(objects) or len(graph["meshes"]) != len(objects) or graph.get("images"):
        raise ValueError("GLB inventory differs from the editable visual pieces")
    triangles = sum(graph["accessors"][primitive["indices"]]["count"] // 3
                    for mesh in graph["meshes"] for primitive in mesh["primitives"])
    return glb, triangles


def main():
    if Path(bpy.data.filepath).resolve() != MASTER:
        raise ValueError("Open the managed medkit master before exporting")
    if bpy.data.libraries or bpy.data.images:
        raise ValueError("The medkit master has external dependencies")
    objects = sorted((obj for obj in bpy.context.scene.objects if obj.get("NativeShape")), key=lambda obj: obj.name)
    write_native([export_part(obj) for obj in objects])
    glb, triangles = export_glb(objects)
    points = [TO_ROBLOX @ (obj.matrix_world @ vertex.co) for obj in objects for vertex in obj.data.vertices]
    bounds = {key: values(measure(point[axis] for point in points) for axis in range(3))
              for key, measure in (("minimum", min), ("maximum", max))}
    if bounds["minimum"][1] != 0:
        raise ValueError("The visible case must rest on its floor pivot")
    audit = {
        "schemaVersion": 1,
        "blenderVersion": bpy.app.version_string,
        "blenderUnitsPerStud": 1,
        "blenderUnitLengthMeters": bpy.context.scene.unit_settings.scale_length,
        "axisConvention": {"blender": "+X right, +Y front, +Z up", "robloxAndGlb": "+X right, -Z front, +Y up"},
        "externalAssetDependencies": [],
        "meshObjects": len(objects),
        "triangles": triangles,
        "materials": sorted({obj.data.materials[0].name for obj in objects}),
        "boundsStuds": bounds,
        "pivotStuds": [0, 0, 0],
        "sha256": {str(path.relative_to(ROOT)): sha(path) for path in (MASTER, glb, NATIVE)},
    }
    save_json(EXPORT / "package-audit.json", audit)
    print(json.dumps(audit))
    if "--render" in sys.argv:
        scene = bpy.context.scene
        for view in ("Front", "Rear"):
            scene.camera = bpy.data.objects[f"{view} three-quarter"]
            scene.render.filepath = str(EXPORT / f"{view.lower()}-three-quarter.png")
            bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    main()
