"""Compile actual repaired import receipts into managed Rojo Outpost templates.

The approved P16 package is read-only. This compiler requires the actual FBX
assembly and material-split GLB MeshIds plus source-bound texture maps. It never
invents asset IDs, uploads models, changes combat rules or accepts gray fallbacks.
Use a build/ output directory for review before installing the two templates.
"""
from __future__ import annotations

import argparse
import copy
import json
import math
from pathlib import Path
import re
import sys

from p17_assets import ROOT, SOURCE, EXPORT, BLEND_SHA, PACKAGE_LOCK_SHA, approved_catalog, sha
from p17_library_glb import GLB_PATH, REPORT_PATH, verify as verify_derivative
from p17_normalize import normalize_assembly, fit_similarity, transpose, product, multiply, finite, rigid, ordered_sum
from p17_native_meshes import load_profiles, profile_key, BANK_PATH, RECEIPT_PATH, REQUEST_PATH

IDENTITY = [1, 0, 0, 0, 1, 0, 0, 0, 1]
SITE = [144, 0, 164]
IMPORTS = Path("assets/imports/military-outpost")


def asset_id(value):
    if not isinstance(value, str) or not re.fullmatch(r"rbxassetid://[1-9][0-9]*", value):
        raise ValueError("missing/invalid actual imported asset reference")
    return value


def attributes(**values):
    result = {}
    for name, value in values.items():
        if isinstance(value, bool):
            result[name] = {"Bool": value}
        elif isinstance(value, (int, float)):
            result[name] = {"Float64": value}
        elif isinstance(value, str):
            result[name] = {"String": value}
        elif isinstance(value, tuple) and value[0] == "CFrame":
            pose = value[1]
            result[name] = {"CFrame": dict(position=pose[:3], orientation=[pose[3:6], pose[6:9], pose[9:12]])}
        elif isinstance(value, tuple) and value[0] == "Vector3":
            result[name] = {"Vector3": value[1]}
        else:
            raise ValueError("unsupported explicit Rojo attribute")
    return result


def pivot_property(pose):
    return {"OptionalCFrame": dict(position=pose[:3], orientation=[pose[3:6], pose[6:9], pose[9:12]])}


def pose_product(a, b):
    offset = multiply(a[3:], b[:3])
    return [a[axis] + offset[axis] for axis in range(3)] + product(a[3:], b[3:])


def rotation_y(angle):
    c, s = math.cos(angle), math.sin(angle)
    return [c, 0, s, 0, 1, 0, -s, 0, c]


def rotation_x(angle):
    c, s = math.cos(angle), math.sin(angle)
    return [1, 0, 0, 0, c, -s, 0, s, c]


def material_maps(source: dict, root: Path = ROOT) -> dict:
    """Require every original PNG identity; actual references remain inspectable."""
    if source.get("schema_version") != 1 or not isinstance(source.get("materials"), dict):
        raise ValueError("missing source-bound material map receipt")
    definitions = json.loads((root / EXPORT / "material-map.json").read_text())["materials"]
    result = {}
    for material in definitions:
        name = material["material"]
        record = source["materials"].get(name)
        if not record or record.get("source_png_sha256") != sha(root / EXPORT / material["base_color"]):
            raise ValueError("missing/mismatched source texture repair: " + name)
        result[name] = dict(record, color_map=asset_id(record.get("color_map")),
                            source_roughness=material["roughness"], source_metalness=material["metalness"],
                            source_emission=material["emission_strength"])
        for key in ("normal_map", "roughness_map", "metalness_map"):
            value = record.get(key, "")
            result[name][key] = asset_id(value) if value else ""
    return result


def normalize_library(receipt: dict, root: Path = ROOT) -> tuple[list[dict], dict]:
    """Fit all 76 native nodes to decoded approved derivative component bounds."""
    verify_derivative(root)
    if receipt.get("schema_version") != 1 or receipt.get("approved_blend_sha256") != BLEND_SHA:
        raise ValueError("mismatched approved material library receipt identity")
    source_path = receipt.get("source_glb_path", receipt.get("source_path"))
    if source_path != GLB_PATH.as_posix():
        raise ValueError("material library requires the equivalent material-split GLB import")
    report = json.loads((root / REPORT_PATH).read_text())
    if receipt.get("source_glb_sha256") != report["glb_sha256"]:
        raise ValueError("native library receipt does not identify the exact equivalent GLB")
    manifest = json.loads((root / "assets/manifest.json").read_text())
    record = next(item for item in manifest["assets"] if item.get("local_path") == GLB_PATH.as_posix())
    owner = receipt.get("upload_owner", {})
    if record.get("roblox_asset_id") != receipt.get("model_asset_id") or record.get("upload_owner") != f'{owner.get("type")} {owner.get("id")}' or str(receipt.get("revision_id")) != "2":
        raise ValueError("native library package/revision/owner differs from source manifest")
    expected = {node["node"]: node for node in report["nodes"]}
    components = receipt.get("components", [])
    if receipt.get("mesh_count") != len(components):
        raise ValueError("material library count mismatch")
    actual = {}
    for component in components:
        name = component["name"]
        if name in actual or name not in expected:
            raise ValueError("unknown/duplicate native material library node")
        if not finite(component.get("cframe"), 12) or not finite(component.get("size"), 3) or not rigid(component["cframe"][3:]) or not all(value > 0 for value in component["size"]):
            raise ValueError("invalid native material library geometry")
        asset_id(component.get("mesh_id"))
        actual[name] = component
    if set(actual) != set(expected):
        raise ValueError("native material library did not retain every approved material split")
    names = sorted(expected)
    fit = fit_similarity([expected[name]["center"] for name in names], [actual[name]["cframe"][:3] for name in names])
    inverse = transpose(fit["rotation"])
    records = []
    maximum_bounds_error = 0
    for name in names:
        source, raw = expected[name], actual[name]
        rotation = product(inverse, raw["cframe"][3:])
        size = [value / fit["scale"] for value in raw["size"]]
        world_size = [ordered_sum(abs(rotation[3 * axis + column]) * size[column] for column in range(3)) for axis in range(3)]
        error = max(abs(world_size[axis] - source["size"][axis]) for axis in range(3))
        maximum_bounds_error = max(maximum_bounds_error, error)
        if error > 1e-4:
            raise ValueError("native material-split mesh bounds differ from approved source")
        records.append(dict(source, mesh_id=raw["mesh_id"], cframe=source["center"] + rotation, size=size))
    return records, dict(fit, maximum_bounds_error_studs=maximum_bounds_error)


MATERIAL_ENUM = dict(concrete="Concrete", teal="Metal", orange="Metal", steel="Metal", dark="Metal",
                     ivory="Metal", olive="Metal", wood="Wood", roof="Slate", screen="Neon", tactical="Neon", lamp="Neon")


def mesh_node(name, record, maps, solid=False, extra_attributes=None):
    material = record["materials"][0] if "materials" in record else record["material"]
    appearance = maps[material]
    attrs = attributes(SourceObject=record.get("source_object", record.get("node", "")), MaterialKey=material,
                       SourceRoughness=appearance["source_roughness"], SourceMetalness=appearance["source_metalness"],
                       SourceEmission=appearance["source_emission"])
    attrs.update(extra_attributes or {})
    surface = dict(ClassName="SurfaceAppearance", Name=name + "_Surface", Properties=dict(
        ColorMap=appearance["color_map"], NormalMap=appearance["normal_map"], RoughnessMap=appearance["roughness_map"], MetalnessMap=appearance["metalness_map"],
        Attributes=attributes(MaterialMetadataVersion=1, MaterialKey=material,
            CompiledColorMap=appearance["color_map"], CompiledNormalMap=appearance["normal_map"],
            CompiledRoughnessMap=appearance["roughness_map"], CompiledMetalnessMap=appearance["metalness_map"],
            CompiledColorPngSha256=appearance["source_png_sha256"])))
    return dict(ClassName="MeshPart", Name=name, Properties=dict(
        MeshId=asset_id(record["mesh_id"]), TextureID="", CFrame=record["cframe"], Size=record["size"],
        Color=[1, 1, 1], Material=MATERIAL_ENUM[material], Transparency=0, Reflectance=0,
        Anchored=True, CanCollide=solid, CanQuery=solid, CanTouch=False, DoubleSided=True,
        CollisionFidelity="PreciseConvexDecomposition" if solid else "Box", RenderFidelity="Automatic",
        Attributes=attrs), Children=[surface])


def library_model(records, maps, receipt_sha, root=ROOT):
    catalog = approved_catalog(root)
    families = []
    for family in catalog["families"]:
        children = []
        for appearance, state in family["states"].items():
            meshes = [record for record in records if record["family"] == family["id"] and record["appearance"] == appearance]
            children.append(dict(ClassName="Model", Name=appearance, Properties=dict(
                WorldPivotData=pivot_property([0, 0, 0] + IDENTITY),
                Attributes=attributes(SourcePath=state["mesh"], SourceSha256=sha(root / EXPORT / state["mesh"]))),
                Children=[mesh_node(record["node"], record, maps) for record in meshes]))
        fragments = []
        for index, fragment in enumerate(family["fragments"], 1):
            meshes = [record for record in records if record["family"] == family["id"] and record["fragment_index"] == index]
            if len(meshes) != 1:
                raise ValueError("approved fragment must remain a single material/rigid mesh")
            fragments.append(mesh_node(str(index), meshes[0], maps,
                                       extra_attributes=attributes(SourcePath=fragment["mesh"], SourceSha256=sha(root / EXPORT / fragment["mesh"]))))
        children.append(dict(ClassName="Folder", Name="Fragments", Children=fragments))
        families.append(dict(ClassName="Folder", Name=family["id"], Children=children))
    return dict(ClassName="Folder", Properties=dict(Attributes=attributes(
        AssetRevision="p16-v1", BlendSha256=BLEND_SHA, ImportReceiptSha256=receipt_sha)), Children=families)


STABLE_EXTERIOR = ("Exterior balcony landing", "Balcony post", "Balcony railing", "Balcony end rail", "External open tread", "External anti slip nosing", "Stair stringer", "External stair handrail", "External stair baluster")
WALL_DRESSING = ("Front window", "Wall vent", "Facade lamp", "Downpipe", "Pipe clamp", "Outpost facade stencil", "Personnel portal stencil", "Garage roller drum", "Garage track", "Electrical switchboard", "Switchboard breaker", "Workshop location stencil", "Command wall stencil")
ROOF_DRESSING = ("Rooftop HVAC", "HVAC fan", "Fan grille", "HVAC duct", "Roof conduit", "Mast leg", "Mast cross brace", "Antenna panel", "Satellite dish", "Dish pedestal", "Dish feed arm", "Dish receiver", "Command pendant", "Command utilities")
SOLID_PROPS = ("Safety bollard", "Bollard foot", "Concrete traffic barrier")
THERMAL_PANEL_DETAILS = (
    "Wall vent", "Facade lamp", "Downpipe", "Pipe clamp", "Outpost facade stencil",
    "Personnel portal stencil", "Garage roller drum", "Garage track", "Rooftop HVAC",
    "HVAC fan", "Fan grille", "HVAC duct", "Mast leg", "Mast cross brace", "Antenna panel",
    "Satellite dish", "Dish pedestal", "Dish feed arm", "Dish receiver",
)


def construction_class(record, panels):
    """Explicit source-object policy; no cosmetic part silently gains cover."""
    name = record["source_object"]
    if name in panels:
        return "PanelVisual", name
    if record["collection"].startswith("01_") or name.startswith(STABLE_EXTERIOR):
        return "StableStructure", None
    if name.startswith(SOLID_PROPS):
        return "SolidPropCover", None
    if name.startswith(WALL_DRESSING + ROOF_DRESSING):
        roof = name.startswith(ROOF_DRESSING)
        candidates = [panel for panel in panels.values() if panel["roof"] == roof]
        center = record["center"]
        owner = min(candidates, key=lambda panel: ordered_sum((center[axis] - panel["identity"] [axis]) ** 2 for axis in range(3)))
        return "PanelAttachment", owner["panel_id"]
    return "CosmeticProp", None


def panel_definitions(root=ROOT):
    catalog = approved_catalog(root)
    result = {}
    for source in catalog["identity_migration"]["mapping"]:
        if "legacy_pivot_roblox" in source:
            identity = list(source["legacy_pivot_roblox"])
            identity[:3] = [identity[axis] - SITE[axis] for axis in range(3)]
            size = source["legacy_size_roblox"]
        else:
            x, y, z = source["pivot_blender"]
            identity, size = [x, z, -y] + IDENTITY, [16, 8, 1]
        basis = product(rotation_y(source["rotation_z"]), rotation_x(math.pi / 2 if source["roof"] else 0))
        result[source["panel_id"]] = dict(source, identity=identity, identity_size=size, basis=[0, 0, 0] + basis,
            story="02" if "_S02_" in source["panel_id"] else "01")
    return result


def outpost_model(assembly, library, maps, receipt_sha, root=ROOT):
    panels = panel_definitions(root)
    catalog = approved_catalog(root)
    family_lookup = {family["id"]: family for family in catalog["families"]}
    template_families = {family["Name"]: family for family in library["Children"]}
    panel_nodes, statics, cosmetics, classifications = {}, [], [], []
    for panel_id, panel in panels.items():
        props = dict(WorldPivotData=pivot_property(panel["identity"]), Attributes=attributes(
            PanelId=panel_id, PanelAssetFamily=panel["family"], PanelAssetBasis=("CFrame", panel["basis"]),
            LocalIdentityPivot=("CFrame", panel["identity"]), IntactPivot=("CFrame", panel["identity"]),
            IntactSize=("Vector3", panel["identity_size"]), StoryId=panel["story"], InteriorPanel=panel_id == "Outpost_v2_Interior01"))
        node = dict(ClassName="Model", Name=panel_id, Properties=props, Children=[])
        geometry_pose = pose_product(panel["identity"], panel["basis"])
        pristine = next(item for item in template_families[panel["family"]]["Children"] if item["Name"] == "Pristine")
        for index, source in enumerate(pristine["Children"], 1):
            child = copy.deepcopy(source)
            child["Name"] = f"{panel_id}_Mesh{index}"
            child["Children"][0]["Name"] = child["Name"] + "_Surface"
            child["Properties"]["CFrame"] = pose_product(geometry_pose, child["Properties"]["CFrame"])
            node["Children"].append(child)
        for index, rectangle in enumerate(family_lookup[panel["family"]]["states"]["Pristine"]["rectangles"], 1):
            x0, y0, x1, y1 = rectangle
            node["Children"].append(dict(ClassName="Part", Name=f"{panel_id}_Proxy{index}", Properties=dict(
                Anchored=True, CanCollide=True, CanQuery=True, CanTouch=False, Transparency=1,
                CFrame=pose_product(geometry_pose, [(x0+x1)/2, (y0+y1)/2, 0] + IDENTITY),
                Size=[x1-x0, y1-y0, 1], Attributes=attributes(PanelId=panel_id, PanelProxy=True))))
        panel_nodes[panel_id] = node
    for index, record in enumerate(assembly["components"], 1):
        classification, owner = construction_class(record, panels)
        classifications.append(dict(source_object=record["source_object"], classification=classification, panel_id=owner))
        if classification == "PanelVisual":
            continue
        if len(record["materials"]) != 1:
            raise ValueError("non-panel FBX object lost multiple material boundaries")
        source_name = record["source_object"]
        name = f'Outpost_Imported{index:04d}'
        essential = {"Foundation": "Outpost_GroundFloor", "Upper_Main": "Outpost_UpperMain", "Upper_North_Landing": "Outpost_UpperNorthLanding"}
        if source_name in essential:
            name = essential[source_name]
        elif re.fullmatch(r"Internal stair tread [0-9]+", source_name):
            name = f'Outpost_Step{int(source_name.rsplit(" ", 1)[1]):02d}'
        solid = classification in ("StableStructure", "SolidPropCover")
        # Exterior panel detail reads against the wall/roof. Keep freestanding
        # art and attachments crossing clear apertures out of thermal depth.
        hidden_in_thermal = classification == "CosmeticProp" or (
            classification == "PanelAttachment" and not source_name.startswith(THERMAL_PANEL_DETAILS)
        )
        attrs = attributes(ConstructionClass=classification, ThermalNonCover=hidden_in_thermal)
        if owner:
            attrs.update(attributes(PanelAttachment=True, AttachmentPanelId=owner))
        child = mesh_node(name, record, maps, solid, attrs)
        if classification == "PanelAttachment":
            panel_nodes[owner]["Children"].append(child)
        elif solid:
            statics.append(child)
        else:
            cosmetics.append(child)
    world = json.loads((root / "assets/world/Battlefield.model.json").read_text())
    def find(node, name):
        if node.get("Name") == name:
            return node
        return next((found for child in node.get("Children", []) if (found := find(child, name))), None)
    navigation = copy.deepcopy(find(world, "Outpost_Navigation"))
    for marker in navigation["Children"]:
        pose = marker["Properties"]["CFrame"]
        pose[:3] = [pose[axis] - SITE[axis] for axis in range(3)]
    mesh_count = sum(1 for _ in iter_class(dict(Children=statics+cosmetics+list(panel_nodes.values())), "MeshPart"))
    model = dict(ClassName="Model", Properties=dict(WorldPivotData=pivot_property([0, 0, 0]+IDENTITY),
        Attributes=attributes(AssetRevision="p16-v1", BlendSha256=BLEND_SHA, ImportReceiptSha256=receipt_sha,
                              PanelLayoutVersion=2, SourceMeshCount=2225, ImportedPanelCount=26, PristineMeshCount=mesh_count)), Children=[
        dict(ClassName="Folder", Name="Outpost_Static", Children=statics),
        dict(ClassName="Folder", Name="Outpost_Dressing", Children=cosmetics),
        dict(ClassName="Folder", Name="Outpost_Panels", Children=list(panel_nodes.values())), navigation])
    return model, classifications


def iter_class(node, name):
    if node.get("ClassName") == name:
        yield node
    for child in node.get("Children", []):
        yield from iter_class(child, name)


def compile_models(assembly_receipt, library_receipt, texture_receipt, library_receipt_sha, root=ROOT):
    maps = material_maps(texture_receipt, root)
    assembly = normalize_assembly(assembly_receipt, root)
    records, fit = normalize_library(library_receipt, root)
    library = library_model(records, maps, library_receipt_sha, root)
    outpost, classifications = outpost_model(assembly, library, maps, library_receipt_sha, root)
    bind_native_geometry((library, outpost), load_profiles(root))
    return library, outpost, dict(schema_version=1, approved_blend_sha256=BLEND_SHA,
        approved_package_lock_sha256=PACKAGE_LOCK_SHA, assembly_similarity=assembly["similarity"], library_similarity=fit,
        material_mapping_complete=True, classifications=classifications, panel_count=26,
        total_active_panel_count=188, texture_only_materials=[name for name, value in maps.items() if not value["roughness_map"] or not value["metalness_map"]],
        missing_native_acceptance=["rendering and UV orientation", "native navigation and targeting", "demolition/openings/fragments", "replication/reset/performance", "human A6 approval"])


def bind_native_geometry(models, profiles):
    """Copy engine-authored constructor fields, never infer them from target Size.

    Every generated MeshPart must match the exact native factory fidelity policy;
    every captured profile/use must be consumed. The bank stays outside the live
    DataModel: no duplicate Instances, runtime downloads or ApplyMesh workaround.
    """
    uses = {key: 0 for key in profiles}
    for model in models:
        for mesh in iter_class(model, "MeshPart"):
            props = mesh["Properties"]
            key = profile_key(props["MeshId"], props["CollisionFidelity"], props["RenderFidelity"])
            native = profiles.get(key)
            if native is None:
                raise ValueError("missing actual native constructor profile: " + str(key))
            uses[key] += 1
            for field in ("InitialSize", "PhysicalConfigData", "PhysicsData", "AeroMeshData"):
                props[field] = copy.deepcopy(native[field])
            props["Attributes"].update(attributes(NativeGeometryVersion=1, NativeMeshId=key[0],
                NativeMeshSize=("Vector3", native["InitialSize"]), NativeCollisionFidelity=key[1], NativeRenderFidelity=key[2]))
    if any(count != profiles[key]["uses"] for key, count in uses.items()):
        raise ValueError("native profile coverage differs from generated approved geometry")


def managed_outputs(root=ROOT):
    assembly_path = root / IMPORTS / "assembly-fbx-receipt-v1.json"
    library_path = root / IMPORTS / "library-glb-receipt-v2.json"
    texture_path = root / IMPORTS / "material-textures-v2.json"
    library, outpost, report = compile_models(json.loads(assembly_path.read_text()), json.loads(library_path.read_text()), json.loads(texture_path.read_text()), sha(library_path), root)
    report.update(assembly_receipt_sha256=sha(assembly_path), library_receipt_sha256=sha(library_path), texture_receipt_sha256=sha(texture_path))
    report.update(native_mesh_bank_sha256=sha(root / BANK_PATH), native_mesh_receipt_sha256=sha(root / RECEIPT_PATH),
                  native_mesh_requests_sha256=sha(root / REQUEST_PATH), native_mesh_profiles=407, native_mesh_uses=2332)
    return {Path("assets/models/MaterialPanels.model.json"):library, Path("assets/models/MilitaryOutpost.model.json"):outpost,
            IMPORTS / "construction-v2.json":report}


def verify(root=ROOT):
    for path, expected in managed_outputs(root).items():
        if json.loads((root / path).read_text()) != expected:
            raise ValueError("managed Outpost reconstruction differs from actual approved import receipts: " + path.as_posix())
    return dict(suite="P17OutpostReconstruction", discovered=1, passed=1, failed=0, panels=26, total_runtime_panels=188,
                native_acceptance_verified=False)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write-managed", action="store_true")
    args = parser.parse_args()
    if args.write_managed:
        for path, data in managed_outputs().items():
            (ROOT / path).parent.mkdir(parents=True, exist_ok=True)
            (ROOT / path).write_text(json.dumps(data, indent=2, allow_nan=False)+"\n")
    print(json.dumps(verify(), sort_keys=True))


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, KeyError, StopIteration) as error:
        print(f"P17 reconstruction compilation failed: {error}", file=sys.stderr)
        sys.exit(1)
