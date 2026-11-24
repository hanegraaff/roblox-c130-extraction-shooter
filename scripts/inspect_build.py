"""Inspect actual Rojo XML artifacts, proving release/test DataModel isolation."""
from pathlib import Path
import xml.etree.ElementTree as ET
import json
import math
import re
import tempfile
import copy
import base64
import struct
from functools import lru_cache
from p17_native_meshes import PAYLOAD_FIELDS, decode_payload, float32_vector
from radar_outpost.prepare_import import thermal_structure_names
from lobby_interior.prepare_collision import CATALOG as LOBBY_CATALOG, OUTPUT as LOBBY_COLLISION, collision_model
from lobby_interior.stage_import import APPROVAL as LOBBY_APPROVAL, EXPORT as LOBBY_EXPORT, decode_glb, digest, embedded_color

ROOT = Path(__file__).resolve().parent.parent
LOBBY_STATION = "Workspace/World/Battlefield/LobbyStation"
LOBBY_ART = f"{LOBBY_STATION}/LobbyArt"
LOBBY_ART_SOURCE = LOBBY_COLLISION.with_name("LobbyArt.rbxm")


def compiled_surface_attributes(item: ET.Element) -> dict:
    """Decode compiled String/Bool/Float64/Vector3 attributes from Rojo XML.

    Managed native assets use only those attribute types. Unknown or truncated
    serialized metadata rejects before the artifact is accepted.
    """
    encoded = item.findtext("Properties/BinaryString[@name='AttributesSerialize']") or item.findtext("Properties/BinaryString[@name='AttributesSerialized']")
    if not encoded:
        raise RuntimeError("missing serialized compiled material metadata")
    try:
        data = base64.b64decode(encoded, validate=True)
        offset = 0
        def number(fmt):
            nonlocal offset
            value = struct.unpack_from(fmt, data, offset)[0]
            offset += struct.calcsize(fmt)
            return value
        def string():
            nonlocal offset
            length = number("<I")
            if length > 4096 or offset + length > len(data):
                raise ValueError("invalid material attribute string")
            value = data[offset:offset+length].decode("utf-8")
            offset += length
            return value
        count = number("<I")
        if count > 32: raise ValueError("unbounded material metadata")
        values = {}
        for _ in range(count):
            key = string()
            if key in values: raise ValueError("duplicate material metadata")
            kind = number("<B")
            if kind == 2: values[key] = string()
            elif kind == 3: values[key] = bool(number("<B"))
            elif kind == 6: values[key] = number("<d")
            elif kind == 17: values[key] = [number("<f") for _ in range(3)]
            else: raise ValueError("unexpected compiled material metadata type")
        if offset != len(data): raise ValueError("trailing compiled material metadata")
        return values
    except (ValueError, struct.error, UnicodeError) as error:
        raise RuntimeError("invalid serialized compiled material metadata") from error


def check_surface_material(item: ET.Element, source: dict, full: str) -> None:
    """Bind actual protected map slots AND serialized readable metadata to source."""
    properties = source["Properties"]
    actual_metadata = compiled_surface_attributes(item)
    expected_metadata = {key: next(iter(value.values())) for key, value in properties.get("Attributes", {}).items()}
    if actual_metadata != expected_metadata or actual_metadata.get("MaterialMetadataVersion") != 1:
        raise RuntimeError(f"Compiled material metadata reconstruction mismatch: {full}")
    for key in ("ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap"):
        actual_map = item.findtext(f"Properties/Content[@name='{key}Content']/uri") or item.findtext(f"Properties/Content[@name='{key}']/url") or ""
        if actual_map != properties.get(key, "") or actual_metadata.get("Compiled"+key) != actual_map:
            raise RuntimeError(f"Imported texture/metadata reconstruction mismatch: {full}/{key}")


def paths(path: Path) -> dict[str, str]:
    """Return every Instance's full name and class; reject ambiguous duplicate sibling names."""
    result: dict[str, str] = {}

    def walk(node: ET.Element, parent: str) -> None:
        siblings: set[str] = set()
        for item in node.findall("Item"):
            name = item.findtext("Properties/string[@name='Name']")
            if not name or name in siblings:
                raise RuntimeError(f"Missing/duplicate Instance name below {parent}: {name}")
            siblings.add(name)
            full = f"{parent}/{name}" if parent else name
            result[full] = item.attrib["class"]
            walk(item, full)

    walk(ET.parse(path).getroot(), "")
    return result


CFRAME_COMPONENTS = ("X", "Y", "Z", "R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22")
PART_CLASSES = {"Part", "SpawnLocation", "MeshPart"}


def instance_nodes(path: Path) -> dict[str, ET.Element]:
    """Index serialized Instances, retaining properties for reconstruction assertions."""
    result: dict[str, ET.Element] = {}

    def walk(node: ET.Element, parent: str) -> None:
        for item in node.findall("Item"):
            name = item.findtext("Properties/string[@name='Name']")
            full = f"{parent}/{name}" if parent else str(name)
            result[full] = item
            walk(item, full)

    walk(ET.parse(path).getroot(), "")
    return result


def numeric_property(item: ET.Element, tag: str, name: str, components: tuple[str, ...], full: str) -> list[float]:
    """Require a canonical serialized numeric property with finite components."""
    value = item.find(f"Properties/{tag}[@name='{name}']")
    if value is None:
        raise RuntimeError(f"Missing canonical {name}: {full}")
    try:
        numbers = [float(value.findtext(component, "nan")) for component in components]
    except ValueError as error:
        raise RuntimeError(f"Malformed {name}: {full}") from error
    if not all(math.isfinite(number) for number in numbers):
        raise RuntimeError(f"Nonfinite {name}: {full}")
    return numbers


@lru_cache(maxsize=1)
def approved_lobby_art() -> dict[str, tuple[str, str | None]]:
    """Derive expected mesh roles and texture hashes from the approved GLB."""
    raw = LOBBY_EXPORT.read_bytes()
    approval = json.loads(LOBBY_APPROVAL.read_text())
    catalog = json.loads(LOBBY_CATALOG.read_text())
    if digest(raw) != approval["export_sha256"]:
        raise RuntimeError("P22 reconstruction must use the approved lobby GLB")
    doc, binary = decode_glb(raw)
    nodes = doc["nodes"]
    (bust_root,) = [node for node in nodes if node["name"] == "Lobby Bust · base center"]
    bust_parts = set(bust_root["children"])
    portrait_names = {painting["canvas"] for painting in catalog["paintings"]}
    expected = {}
    for index, node in enumerate(nodes):
        if "mesh" not in node:
            continue
        name = node["name"]
        (primitive,) = doc["meshes"][node["mesh"]]["primitives"]
        slot = primitive["material"]
        color = doc["materials"][slot]["pbrMetallicRoughness"].get("baseColorTexture")
        role = "Bust" if index in bust_parts else "Portrait" if name in portrait_names else "Room"
        if name in expected:
            raise RuntimeError(f"Ambiguous lobby source identity: {name}")
        expected[name] = (role, digest(embedded_color(doc, binary, slot)) if color else None)
    if len(expected) != approval["inventory"]["mesh_objects"] or len(bust_parts) != catalog["p20_meshes"]:
        raise RuntimeError("P22 lobby source inventory does not match its approval")
    return expected


def content_uri(item: ET.Element, name: str) -> str:
    """Read the content URI from the current or legacy Roblox XML property."""
    return next((value for prop in (name + "Content", name, name + "Id", name + "ID") for slot in ("uri", "url")
                 if (value := item.findtext(f"Properties/Content[@name='{prop}']/{slot}"))), "")


def check_native_lobby_art(nodes: dict[str, ET.Element], catalog: dict) -> dict[str, tuple]:
    """Check the actual compiled assembly and return its release/test parity signature."""
    if nodes[LOBBY_ART].attrib["class"] != "Folder":
        raise RuntimeError("P22 lobby art requires one managed Folder")
    if sum(path.rsplit("/", 1)[-1] == "LobbyArt" for path in nodes) != 1:
        raise RuntimeError("Duplicate managed lobby art")
    expected = approved_lobby_art()
    portraits = {painting["canvas"]: painting for painting in catalog["paintings"]}
    seen = {}
    portrait_textures = set()
    prefix = LOBBY_ART + "/"
    for full, item in nodes.items():
        if not full.startswith(prefix):
            continue
        relative = full.removeprefix(prefix)
        if "/" in relative:
            parent, child = relative.split("/", 1)
            if (
                item.attrib["class"] != "SurfaceAppearance"
                or child != f"{parent}_Surface"
                or nodes.get(prefix + parent) is None
                or nodes[prefix + parent].attrib["class"] != "MeshPart"
            ):
                raise RuntimeError(f"Unexpected lobby art descendant: {full}")
            continue
        if item.attrib["class"] != "MeshPart" or not relative.startswith("P22_"):
            raise RuntimeError(f"Unexpected lobby art object: {full}")
        settings = {"Anchored": True, "CanCollide": False, "CanQuery": False, "CanTouch": False}
        if any(item.findtext(f"Properties/bool[@name='{key}']", "true") != str(value).lower()
               for key, value in settings.items()):
            raise RuntimeError(f"Invalid lobby visual part collision settings: {full}")
        attrs = compiled_surface_attributes(item)
        source = attrs.get("LobbyArtSource")
        role = attrs.get("LobbyArtRole")
        color_sha = attrs.get("LobbyColorSourceSha256")
        if source in seen or expected.get(source) != (role, color_sha):
            raise RuntimeError(f"Wrong or duplicate lobby source identity: {full}")
        pose = numeric_property(item, "CoordinateFrame", "CFrame", CFRAME_COMPONENTS, full)
        size = numeric_property(item, "Vector3", "size", ("X", "Y", "Z"), full)
        intrinsic = numeric_property(item, "Vector3", "InitialSize", ("X", "Y", "Z"), full)
        mesh_id = content_uri(item, "Mesh")
        if (
            not re.fullmatch(r"rbxassetid://\d+", mesh_id)
            or mesh_id != attrs.get("NativeMeshId")
            or list(struct.unpack("<3f", struct.pack("<3f", *intrinsic))) != attrs.get("NativeMeshSize")
            or any(value <= 0 for value in size)
            or any(value < 0 for value in intrinsic)
            or sum(value > 0 for value in intrinsic) < 2
        ):
            raise RuntimeError(f"Missing genuine lobby mesh identity or intrinsic dimensions: {full}")
        if not attrs.get("NativeCollisionFidelity") or not attrs.get("NativeRenderFidelity"):
            raise RuntimeError(f"Missing native lobby mesh fidelity: {full}")
        surface = nodes.get(f"{full}/{relative}_Surface")
        color = (content_uri(surface, "ColorMap") if surface is not None else "") or content_uri(item, "Texture")
        if color_sha and (
            not re.fullmatch(r"rbxassetid://\d+", color) or attrs.get("LobbyNativeColor") != color
        ):
            raise RuntimeError(f"Missing native lobby color texture: {full}")
        if role == "Portrait":
            painting = portraits[source]
            number = painting["portrait"]
            x, y, z = painting["center_blender"]
            world_extent = [sum(abs(pose[3 + i * 3 + a]) * size[a] for a in range(3)) for i in range(3)]
            if (
                relative != f"P22_Portrait_{number:02}"
                or attrs.get("LobbyPortrait") != number
                or color_sha != painting["source_sha256"]
                or color in portrait_textures
                or math.dist(pose[:3], (520 + x, z, -y)) > 0.06
                or math.dist([max(world_extent[0], world_extent[2]), world_extent[1]], painting["size_studs"]) > 0.06
            ):
                raise RuntimeError(f"Portrait {number} native frame, texture or placement mismatch")
            portrait_textures.add(color)
        elif "LobbyPortrait" in attrs:
            raise RuntimeError(f"Unexpected portrait identity: {full}")
        seen[source] = (relative, tuple(pose), tuple(size), tuple(intrinsic), mesh_id, color)
    if seen.keys() != expected.keys() or len(portrait_textures) != len(portraits):
        raise RuntimeError("Compiled lobby is missing approved native meshes or portraits")
    return seen


def check_native_mesh(item: ET.Element, source: dict, shared: dict[str, bytes], full: str) -> None:
    """Require native intrinsic/payload preservation, independently of part Size.

    These opaque bytes are compared to the source-bound factory capture rather
    than synthesized or treated as collision/rendering proof in a host process.
    """
    properties = source["Properties"]
    initial = numeric_property(item, "Vector3", "InitialSize", ("X", "Y", "Z"), full)
    expected = properties.get("InitialSize")
    if not expected or any(value <= 0 for value in initial) or float32_vector(initial) != expected:
        raise RuntimeError(f"Native mesh intrinsic reconstruction mismatch: {full}")
    metadata = compiled_surface_attributes(item)
    for key in ("NativeGeometryVersion", "NativeMeshId", "NativeMeshSize", "NativeCollisionFidelity", "NativeRenderFidelity"):
        typed = properties.get("Attributes", {}).get(key, {})
        expected_value = next(iter(typed.values()), None)
        if expected_value is None or metadata.get(key) != expected_value:
            raise RuntimeError(f"Native mesh metadata reconstruction mismatch: {full}/{key}")
    for field, kind in PAYLOAD_FIELDS.items():
        node = item.find(f"Properties/{kind}[@name='{field}']")
        source_value = properties.get(field, {}).get(kind)
        if node is None or source_value is None:
            raise RuntimeError(f"Missing native mesh payload: {full}/{field}")
        if kind == "SharedString":
            actual = shared.get(node.text)
        else:
            actual = decode_payload(node.text)
        if actual != decode_payload(source_value) or (field == "PhysicalConfigData" and not actual):
            raise RuntimeError(f"Native mesh payload reconstruction mismatch: {full}/{field}")


def check_authored_geometry(path: Path) -> int:
    """Compare every authored part pose/size/shape/collision against the actual XML.

    Position/Orientation are runtime aliases, not canonical serialized properties;
    Roblox ignores them on file load. Requiring CFrame catches origin-piled maps
    before Studio. This gate verifies reconstruction, not engine navigation/rays.
    """
    nodes = instance_nodes(path)
    shared = {node.attrib["md5"]: decode_payload(node.text) for node in ET.parse(path).getroot().findall("SharedStrings/SharedString")}
    count = 0
    manifest = json.loads((ROOT / "assets/manifest.json").read_text())

    def walk(source: dict, full: str) -> None:
        nonlocal count
        item = nodes.get(full)
        if item is None or item.attrib["class"] != source["ClassName"]:
            raise RuntimeError(f"Missing authored geometry Instance: {full}")
        if source["ClassName"] in PART_CLASSES:
            properties = source["Properties"]
            if "Position" in properties or "Orientation" in properties:
                raise RuntimeError(f"Authored pose must use canonical CFrame: {full}")
            if any(prop.attrib.get("name") in {"Position", "Orientation"} for prop in item.findall("Properties/*")):
                raise RuntimeError(f"Noncanonical serialized pose alias: {full}")
            expected = properties.get("CFrame")
            if not isinstance(expected, list) or len(expected) != 12 or not all(isinstance(value, (int, float)) and math.isfinite(value) for value in expected):
                raise RuntimeError(f"Authored CFrame must have twelve finite components: {full}")
            actual = numeric_property(item, "CoordinateFrame", "CFrame", CFRAME_COMPONENTS, full)
            if any(abs(a - b) > 1e-4 for a, b in zip(actual, expected)):
                raise RuntimeError(f"Authored CFrame reconstruction mismatch: {full}")
            actual_size = numeric_property(item, "Vector3", "size", ("X", "Y", "Z"), full)
            if any(value <= 0 for value in actual_size) or any(abs(a - b) > 1e-4 for a, b in zip(actual_size, properties["Size"])):
                raise RuntimeError(f"Authored size reconstruction mismatch: {full}")
            for boolean in ("Anchored", "CanCollide", "CanQuery", "CanTouch"):
                expected_bool = properties.get(boolean, True)
                serialized = item.findtext(f"Properties/bool[@name='{boolean}']")
                actual_bool = True if serialized is None else serialized == "true"
                if actual_bool != expected_bool:
                    raise RuntimeError(f"Authored {boolean} reconstruction mismatch: {full}")
            if source["ClassName"] == "MeshPart":
                actual_mesh = item.findtext("Properties/Content[@name='MeshContent']/uri") or item.findtext("Properties/Content[@name='MeshId']/url")
                if actual_mesh != properties["MeshId"]:
                    raise RuntimeError(f"Imported MeshId reconstruction mismatch: {full}")
                check_native_mesh(item, source, shared, full)
            else:
                expected_shape = {"Block": "1", "Ball": "0", "Cylinder": "2"}[properties.get("Shape", "Block")]
                if item.findtext("Properties/token[@name='shape']", "1") != expected_shape:
                    raise RuntimeError(f"Authored shape reconstruction mismatch: {full}")
            count += 1
        if source["ClassName"] == "SurfaceAppearance":
            check_surface_material(item, source, full)
        for child in source.get("Children", []):
            walk(child, full + "/" + child["Name"])

    for asset in manifest["assets"]:
        local = asset["local_path"]
        if (
            not local
            or not local.endswith(".model.json")
            or local.startswith("assets/presentation/")
            or ROOT / local == LOBBY_COLLISION
        ):
            continue
        source = json.loads((ROOT / local).read_text())
        base = "Workspace/World" if asset["kind"] == "world" else "ServerStorage/Assets"
        name = Path(local).name.removesuffix(".model.json")
        walk(source, base + "/" + name)

    fixture = "ServerStorage/Tests/Fixtures/LobbyCollision"
    collision = json.loads(LOBBY_COLLISION.read_text())
    lobby_catalog = json.loads(LOBBY_CATALOG.read_text())
    if collision != collision_model(lobby_catalog):
        raise RuntimeError("P22 lobby collision differs from the approved footprint recipe")
    for name, position in lobby_catalog["existing_anchors_roblox"].items():
        full = "Workspace/World/Battlefield/Anchors/" + name
        pose = numeric_property(nodes[full], "CoordinateFrame", "CFrame", CFRAME_COMPONENTS, full)
        if pose != [*position, 1, 0, 0, 0, 1, 0, 0, 0, 1]:
            raise RuntimeError(f"Lobby anchor placement no longer matches the approved site: {name}")
    if path.name == "game.rbxlx" and fixture in nodes:
        raise RuntimeError("P22 collision fixture leaked into the release mapping")
    if path.name == "tests.rbxlx":
        walk(collision, fixture)
    physical = f"{LOBBY_STATION}/LobbyCollision"
    if physical in nodes:
        if LOBBY_ART not in nodes:
            raise RuntimeError("Furnished lobby collision requires its managed visual assembly")
        for name in ("LobbyDeck", "OperatorCanopy", "OperatorBack"):
            if f"{LOBBY_STATION}/{name}" in nodes:
                raise RuntimeError(f"Furnished lobby retained legacy geometry: {name}")
        walk(collision, physical)
    elif LOBBY_ART in nodes:
        raise RuntimeError("Furnished lobby visuals require the managed collision")
    if count == 0:
        raise RuntimeError("No authored parts discovered for reconstruction checks")
    return count


def check_building_surfaces(world: dict) -> int:
    """Reject overlapping, same-facing visible faces in the axis-aligned buildings.

    Ordinary edge joins and opposing contact faces are valid. A third opaque solid
    may hide a coplanar overlap (for example wall corners inside columns). Subtract
    its projected rectangle exactly, rather than sampling and missing small slivers.
    This guards authored z-fighting, not every renderer or shadow artifact.
    """
    buildings = next(item for item in world["Children"] if item["Name"] == "Buildings")
    count = 0
    for building in buildings["Children"]:
        solids = []
        for group in building["Children"]:
            for part in group.get("Children", []):
                properties = part.get("Properties", {})
                if part["ClassName"] not in PART_CLASSES or properties.get("Transparency", 0) >= 1:
                    continue
                pose, size = properties["CFrame"], properties["Size"]
                assert pose[3:] == [1, 0, 0, 0, 1, 0, 0, 0, 1], "surface guard requires axis-aligned buildings"
                low = [pose[axis] - size[axis]/2 for axis in range(3)]
                high = [pose[axis] + size[axis]/2 for axis in range(3)]
                solids.append((part["Name"], low, high))
                if part["Name"].endswith("_GroundFloor"):
                    assert high[1] >= 0.125, "building floor overlaps the Y=0 battlefield surface"
        for index, (first_name, first_low, first_high) in enumerate(solids):
            for second_index in range(index + 1, len(solids)):
                second_name, second_low, second_high = solids[second_index]
                for axis in range(3):
                    u, v = [other for other in range(3) if other != axis]
                    rectangle = (max(first_low[u], second_low[u]), max(first_low[v], second_low[v]),
                                 min(first_high[u], second_high[u]), min(first_high[v], second_high[v]))
                    if rectangle[2] - rectangle[0] <= 1e-6 or rectangle[3] - rectangle[1] <= 1e-6:
                        continue
                    for sign, first_face, second_face in ((-1, first_low[axis], second_low[axis]),
                                                         (1, first_high[axis], second_high[axis])):
                        if abs(first_face - second_face) > 1e-5:
                            continue
                        uncovered = [rectangle]
                        outside = first_face + sign * 1e-4
                        for other_index, (_, low, high) in enumerate(solids):
                            if other_index in (index, second_index) or not low[axis] < outside < high[axis]:
                                continue
                            remaining = []
                            for left, bottom, right, top in uncovered:
                                cut_left, cut_bottom = max(left, low[u]), max(bottom, low[v])
                                cut_right, cut_top = min(right, high[u]), min(top, high[v])
                                if cut_left >= cut_right or cut_bottom >= cut_top:
                                    remaining.append((left, bottom, right, top))
                                    continue
                                for piece in ((left, bottom, cut_left, top), (cut_right, bottom, right, top),
                                              (cut_left, bottom, cut_right, cut_bottom), (cut_left, cut_top, cut_right, top)):
                                    if piece[2] - piece[0] > 1e-6 and piece[3] - piece[1] > 1e-6:
                                        remaining.append(piece)
                            uncovered = remaining
                            if not uncovered:
                                break
                        assert not uncovered, f"coplanar building faces: {first_name} / {second_name}, axis {axis}"
                count += 1
    return count


def building_surface_rejection_probes(world: dict) -> None:
    """The guard must reject the reported ground/frame defects and duplicate walls."""
    for fault in ("ground", "frame", "duplicate"):
        fixture = copy.deepcopy(world)
        building = next(item for item in fixture["Children"] if item["Name"] == "Buildings")["Children"][0]
        supports = building["Children"][0]["Children"]
        if fault == "ground":
            floor = next(item["Properties"] for item in supports if item["Name"].endswith("_GroundFloor"))
            floor["CFrame"][1] = -floor["Size"][1]/2
        elif fault == "frame":
            beam = next(item["Properties"] for item in supports if item["Name"].endswith("_BeamEast9"))
            beam["Size"][2] += 2
            floor = next(item["Properties"] for item in supports if item["Name"].endswith("_UpperMain"))
            floor["Size"][0] += 1
            floor["CFrame"][0] += 0.5
        else:
            panels = next(item for item in building["Children"] if item["Name"].endswith("_Panels"))
            duplicate = copy.deepcopy(panels["Children"][1])
            duplicate["Name"] += "_Duplicate"
            panels["Children"].append(duplicate)
        try:
            check_building_surfaces(fixture)
        except AssertionError as error:
            print(f"Expected building surface rejection ({fault}): {error}")
        else:
            raise RuntimeError(f"Building surface probe accepted {fault}")


def check_starting_shelter(world: dict) -> dict:
    """Prove each tiled surface is an exact, nonoverlapping cover of its old box.

    Old boxes intentionally intersect at wall corners/roof joints. Group-wise
    coverage preserves that original union without retaining old full colliders.
    """
    children = {node["Name"]: node for node in world["Children"]}
    assert "Permanent" not in children, "old shelter collider container remains"
    root = children["SpawnShelterPanels"]
    descriptors = children["PanelRegistries"]["Children"]
    assert len(descriptors) == 1 and descriptors[0]["Name"] == "SpawnShelter" and descriptors[0]["Properties"]["Value"] == "SpawnShelterPanels", "shelter registry descriptor"
    regions = {
        "Roof": ((0,14,114),(108,2,96),42),
        "West": ((-35,7,120),(2,14,56),8),
        "East": ((35,7,120),(2,14,56),8),
        "Back": ((0,7,147),(72,14,2),10),
        "FrontCenter": ((0,7,93),(32,14,2),4),
        "FrontWest": ((-34,7,93),(4,14,2),2),
        "FrontEast": ((34,7,93),(4,14,2),2),
    }
    assert len(root["Children"]) == 76, "starting shelter panel count"
    names = set()
    for label, (center,size,count) in regions.items():
        tiles = [node for node in root["Children"] if node["Name"].startswith("Shelter_"+label+"_")]
        assert len(tiles) == count, "shelter surface panel count: "+label
        volume = 0
        boxes = []
        for tile in tiles:
            assert tile["Name"] not in names, "duplicate shelter panel ID"
            names.add(tile["Name"])
            p = tile["Properties"]
            assert tile["ClassName"] == "Part" and p["Anchored"] and p["CanCollide"] and p["CanQuery"], "shelter tile collision"
            assert p["CFrame"][3:] == [1,0,0,0,1,0,0,0,1], "shelter tile rotation"
            xyz, dimensions = p["CFrame"][:3],p["Size"]
            assert all(value>0 for value in dimensions), "shelter dimensions"
            assert all(abs(xyz[a]-center[a])+dimensions[a]/2 <= size[a]/2+1e-7 for a in range(3)), "tile escapes original shelter surface"
            volume += math.prod(dimensions)
            boxes.append((xyz,dimensions))
        assert abs(volume-math.prod(size))<1e-7, "shelter surface no longer fills original box"
        for index,(a,sa) in enumerate(boxes):
            for b,sb in boxes[index+1:]:
                assert not all(min(a[k]+sa[k]/2,b[k]+sb[k]/2)-max(a[k]-sa[k]/2,b[k]-sb[k]/2)>1e-7 for k in range(3)), "shelter tiles overlap"
    assert len(names) == 76, "unclassified shelter collider"
    return {"CFrame":[0,14,114],"Size":[108,2,96]}


def shelter_rejection_probes(world: dict) -> None:
    for fault in ("missing","overlap","old-collider","registry"):
        fixture = copy.deepcopy(world)
        children = {node["Name"]: node for node in fixture["Children"]}
        tiles = children["SpawnShelterPanels"]["Children"]
        if fault == "missing":
            tiles.pop()
        elif fault == "overlap":
            tiles[1]["Properties"]["CFrame"][0] -= .5
        elif fault == "old-collider":
            old = copy.deepcopy(tiles[0]);old["Name"]="ShelterRoof";tiles.append(old)
        else:
            children["PanelRegistries"]["Children"][0]["Properties"]["Value"]="LobbyStation"
        try:
            check_starting_shelter(fixture)
        except AssertionError as error:
            print(f"Expected shelter rejection ({fault}): {error}")
        else:
            raise RuntimeError("shelter corruption accepted: "+fault)


def check_expanded_world_contract() -> None:
    """Check deterministic terrain/source metadata and real authored floor/stair/panel poses.

    Exact source-to-artifact transforms are checked separately for every part. This
    rejects semantic layout/recipe regressions; Studio still proves actual collisions,
    terrain generation, avatar walking and network replication.
    """
    world = json.loads((ROOT / "assets/world/Battlefield.model.json").read_text())
    face_pairs = check_building_surfaces(world)
    building_surface_rejection_probes(world)
    print(f"Building surface separation passed: {face_pairs} part pairs, no exposed coplanar overlaps.")
    children = {item["Name"]: item for item in world["Children"]}
    assert children["GroundDisk"]["Properties"]["Size"] == [4, 720, 720], "ExpandedMapRules diameter"
    # The doubled radius lowers approach angles. Check that all nine protected spawn
    # rays intersect the enlarged canopy, including the old southwest/north failures.
    roof = check_starting_shelter(world)
    shelter_rejection_probes(world)
    for anchor in children["Anchors"]["Children"]:
        if not anchor["Name"].startswith("Ground"):
            continue
        ax, ay, az = anchor["Properties"]["CFrame"][:3]
        t = (roof["CFrame"][1] - roof["Size"][1]/2 - ay)/(140-ay)
        for phase in range(64):
            angle = phase * math.pi/32
            x = ax + (math.cos(angle)*360 - ax)*t
            z = az + (math.sin(angle)*360 - az)*t
            assert abs(x-roof["CFrame"][0]) < roof["Size"][0]/2 - 1, "spawn canopy misses full-orbit X protection"
            assert abs(z-roof["CFrame"][2]) < roof["Size"][2]/2 - 1, "spawn canopy misses full-orbit Z protection"
    manifest = json.loads((ROOT / "assets/manifest.json").read_text())
    recipe_contract = next(asset for asset in manifest["assets"] if asset["id"] == "battlefield-greybox")["terrain_recipe"]
    assert recipe_contract["version"] == 3 and recipe_contract["voxel_resolution_studs"] == 4
    recipe = {node["Name"]:node["Properties"] for node in children["TerrainRecipe"]["Children"]}
    assert set(recipe) == {"TerrainBounds","SurfaceRaster","ReliefRaster"} and recipe["TerrainBounds"]["Size"] == [736,144,736]
    raster = recipe["SurfaceRaster"]["Value"].splitlines()
    assert len(raster) == 180 and all(len(row)==180 and not set(row)-set("stdpglavm.") for row in raster)
    heights = recipe["ReliefRaster"]["Value"].splitlines()
    assert len(heights) == 180 and all(len(row)==180 and not set(row)-set("0123456789abcdef") for row in heights)
    assert all(height == "0" or surface != "." for materials, relief in zip(raster,heights)
               for surface,height in zip(materials,relief)), "relief must stay within terrain ownership"
    areas = []
    ids = set()
    for building in children["Buildings"]["Children"]:
        name = building["Name"]
        contents = {item["Name"]: item for item in building["Children"]}
        supports = {item["Name"]: item["Properties"] for item in contents[name+"_Static"]["Children"]}
        floor = supports[name+"_GroundFloor"]
        areas.append(floor["Size"][0] * floor["Size"][2])
        assert supports[name+"_UpperMain"]["Size"][0] >= 19, "usable upper floor inside frame"
        floor_top = floor["CFrame"][1] + floor["Size"][1]/2
        previous_top = floor_top
        previous_z = None
        for index in range(1, 17):
            step = supports[f"{name}_Step{index:02}"]
            top = step["CFrame"][1] + step["Size"][1]/2
            assert top-previous_top == 0.625 and step["Size"][0] >= 8 and step["Size"][2] == 2, "connected avatar stairs"
            if previous_z is not None:
                assert previous_z-step["CFrame"][2] == 2, "contiguous stair run"
            previous_z, previous_top = step["CFrame"][2], top
        assert previous_top == floor_top + 10, "stairs reach upper floor"
        assert len(contents[name+"_Navigation"]["Children"]) == 5, "operated navigation route"
        if floor["Size"][0] == 64:
            rooms = contents[name+"_Rooms"]["Children"]
            assert len(rooms) == 2 and all(room["Properties"]["Size"] == [32,8,48] for room in rooms), "representative two-panel-wide rooms"
        stories, roof = set(), False
        for panel in contents[name+"_Panels"]["Children"]:
            assert panel["Name"] not in ids, "stable unique panel IDs"
            ids.add(panel["Name"])
            match = __import__("re").match(r".+_S(01|02)_(North|South|West|East|Roof|Interior)_", panel["Name"])
            assert match, "building/story/panel ID contract"
            if match[2] == "Roof":
                roof = True
            else:
                stories.add(match[1])
                assert 8 in panel["Properties"]["Size"] and 16 in panel["Properties"]["Size"], "16x8 wall panels"
        assert stories == {"01", "02"} and roof, "panels on each story and roof"
    assert sorted(areas) == [1536, 3072, 3072], "two large and one smaller footprint"
    print(f"Expanded world source contract passed: 720-stud diameter, flat district terrain, 3 two-story buildings, {len(ids)} building +76 starting-shelter stable panel pivots (187 total).")


def geometry_rejection_probes() -> None:
    """Require the production geometry gate to reject the original defect and corruption."""
    with tempfile.TemporaryDirectory(prefix="c130-geometry-") as directory:
        for fault in ("alias", "pose", "size", "nonfinite", "missing"):
            document = ET.parse(ROOT / "build/game.rbxlx")
            disk = next(item for item in document.iter("Item") if item.findtext("Properties/string[@name='Name']") == "GroundDisk")
            properties = disk.find("Properties")
            assert properties is not None
            cframe = properties.find("CoordinateFrame[@name='CFrame']")
            assert cframe is not None
            if fault == "alias":
                properties.remove(cframe)
                alias = ET.SubElement(properties, "Vector3", {"name": "Position"})
                for axis in ("X", "Y", "Z"):
                    ET.SubElement(alias, axis).text = "0"
            elif fault == "pose":
                cframe.find("Y").text = "0"
            elif fault == "size":
                properties.find("Vector3[@name='size']/Y").text = "350"
            elif fault == "nonfinite":
                cframe.find("X").text = "nan"
            else:
                properties.remove(cframe)
            fixture = Path(directory) / f"{fault}.rbxlx"
            document.write(fixture)
            try:
                check_authored_geometry(fixture)
            except RuntimeError as error:
                print(f"Expected geometry rejection ({fault}): {error}")
            else:
                raise RuntimeError(f"Geometry rejection probe incorrectly accepted {fault}")


MANUAL_P06_TEST_ONLY = (
    "ServerScriptService/ServerTests/RoundHarness",
    "ServerScriptService/ServerTests/GroundCombatHarness",
    "ServerScriptService/ServerTests/LauncherHarness",
    "StarterPlayer/StarterPlayerScripts/ClientTests/LauncherHarness",
    "StarterPlayer/StarterPlayerScripts/ClientTests/GroundCombatHarness",
    "ServerStorage/DevelopmentSettings",
)
MANUAL_P05_TEST_ONLY = (
    "ServerScriptService/ServerTests/RoundHarness",
    "ServerScriptService/ServerTests/CombatHarness",
    "StarterPlayer/StarterPlayerScripts/ClientTests/CombatHarness",
    "ServerStorage/DevelopmentSettings",
)


def check_manual_p06_isolation(release: dict[str, str], tests: dict[str, str]) -> None:
    """Require manual-test dispatcher and selector in the test artifact only."""
    for name in MANUAL_P06_TEST_ONLY:
        if tests.get(name) != "ModuleScript" or name in release:
            raise RuntimeError(f"P06 manual fixture missing from tests or leaked to release: {name}")


def check_manual_p05_isolation(release: dict[str, str], tests: dict[str, str]) -> None:
    """Require the manual P05 selector and both harnesses only in the test artifact."""
    for name in MANUAL_P05_TEST_ONLY:
        if tests.get(name) != "ModuleScript" or name in release:
            raise RuntimeError(f"P05 manual fixture missing from tests or leaked to release: {name}")


MANUAL_P17_TEST_ONLY = (
    "ServerScriptService/ServerTests/P17MaterialHarness",
    "ServerScriptService/ServerTests/P17ManualRunner",
    "ServerScriptService/ServerTests/P17Metadata",
    "StarterPlayer/StarterPlayerScripts/ClientTests/P17MaterialHarness",
)


def check_manual_p17_isolation(release: dict[str, str], tests: dict[str, str]) -> None:
    """Require complete P17 native fixtures exclusively in the test artifact."""
    for name in MANUAL_P17_TEST_ONLY:
        if tests.get(name) != "ModuleScript" or name in release:
            raise RuntimeError(f"P17 fixture missing from tests or leaked to release: {name}")


P18_TEST_ONLY = (
    "ServerScriptService/ServerTests/RebalanceHarness",
    "StarterPlayer/StarterPlayerScripts/ClientTests/RebalanceHarness",
    "ReplicatedStorage/HarnessCompatibility",
)


def check_p18_isolation(release: dict[str, str], tests: dict[str, str]) -> None:
    """Require current fixtures and historical-version guard only in local tests."""
    for name in P18_TEST_ONLY:
        if tests.get(name) != "ModuleScript" or name in release:
            raise RuntimeError(f"P18 fixture missing from tests or leaked to release: {name}")


def check_vesper_import(path: Path) -> int:
    """Check the compiled native bank independently of the live Workspace."""
    root = ET.parse(path).getroot()
    nodes = instance_nodes(path)
    shared = {
        node.attrib["md5"]: decode_payload(node.text)
        for node in root.findall("SharedStrings/SharedString")
    }
    receipt = json.loads((ROOT / "assets/imports/radar-outpost/native-receipt.json").read_text())
    palette = "ReplicatedStorage/Shared/VesperThermalSurfaces/"
    texture_maps = {
        name.removeprefix(palette): item.findtext("Properties/Content[@name='ColorMapContent']/uri")
        for name, item in nodes.items()
        if name.startswith(palette) and item.attrib["class"] == "SurfaceAppearance"
    }
    if texture_maps != receipt["textureIdsByMaterial"]:
        raise RuntimeError("Vesper thermal palette must reuse the approved color maps")
    assets = "ServerStorage/Assets/"
    expected = {"VesperArray": (649, 54), "VesperPanelVariants": (814, 108)}
    counts = {name: [0, 0] for name in expected}
    visible_structure = thermal_structure_names()
    observed_structure: set[str] = set()
    for full, item in nodes.items():
        if item.attrib["class"] != "MeshPart" or not full.startswith(assets):
            continue
        relative = full.removeprefix(assets).partition("/")[0]
        if relative not in expected:
            continue
        counts[relative][0] += 1
        meta = compiled_surface_attributes(item)
        size = numeric_property(item, "Vector3", "InitialSize", ("X", "Y", "Z"), full)
        mesh = item.findtext("Properties/Content[@name='MeshContent']/uri")
        physics = item.findtext("Properties/SharedString[@name='PhysicalConfigData']")
        flags = {flag: item.findtext(f"Properties/bool[@name='{flag}']") == "true"
                 for flag in ("Anchored", "CanCollide", "CanQuery", "CanTouch")}
        if (not mesh or meta.get("NativeMeshId") != mesh or any(v <= 0 for v in size)
                or float32_vector(size) != meta.get("NativeMeshSize") or not shared.get(physics)
                or not flags["Anchored"] or flags["CanTouch"] or flags["CanCollide"] != flags["CanQuery"]):
            raise RuntimeError(f"Vesper native payload or flags differ: {full}")
        if flags["CanCollide"] and meta.get("NativeCollisionFidelity") != "PreciseConvexDecomposition":
            raise RuntimeError(f"Vesper queryable mesh lost its precise collision: {full}")
        part_name = full.rsplit("/", 1)[-1]
        render_structure = part_name in visible_structure
        if render_structure:
            observed_structure.add(part_name)
        should_hide = not flags["CanCollide"] and not render_structure
        if (meta.get("ThermalNonCover") is True) != should_hide:
            raise RuntimeError(f"Vesper thermal classification differs from its source role: {full}")
        invisible = item.findtext("Properties/float[@name='Transparency']") == "1"
        if meta.get("PanelProxy"):
            counts[relative][1] += 1
            if not flags["CanCollide"] or not invisible:
                raise RuntimeError(f"Vesper cover proxy flags differ: {full}")
        key = meta.get("ImportMaterialKey")
        texture = item.findtext("Properties/Content[@name='TextureContent']/uri")
        expected_texture = None if invisible else receipt["textureIdsByMaterial"].get(key)
        if texture != expected_texture:
            raise RuntimeError(f"Vesper texture binding changed: {full}")
    if {name: tuple(v) for name, v in counts.items()} != expected:
        raise RuntimeError(f"Vesper mapped native model counts changed: {counts}")
    if visible_structure != observed_structure:
        raise RuntimeError("Missing Vesper thermal structure meshes in the native bank")
    return sum(count[0] for count in counts.values())



def check_salt_flats_import(path: Path) -> int:
    """Require both native roots, actual panel proxy ownership and the whole wreck."""
    nodes = instance_nodes(path)
    asset_root = "ServerStorage/Assets/"
    hangar = asset_root + "SaltFlatsHangar/"
    variants = asset_root + "SaltFlatsPanelVariants/"
    receipt = json.loads((ROOT / "assets/imports/salt-flats/native-receipt.json").read_text())
    mesh_count = 0
    wreck_proxies = set()
    panel_start = hangar + "Foundry_Panels/"
    panel_ids = {name.removeprefix(panel_start) for name in nodes
                 if name.startswith(panel_start) and "/" not in name.removeprefix(panel_start)}
    if len(panel_ids) != receipt["panels"] or any(
        f"{variants}{panel}/{stage}" not in nodes for panel in panel_ids for stage in ("Light", "Heavy")
    ):
        raise RuntimeError("Salt Flats assembly is missing an authored panel or alternate state")
    for name, part in nodes.items():
        if not name.startswith((hangar, variants)):
            continue
        if part.get("class") == "MeshPart":
            mesh_count += 1
            flags = {flag: part.findtext(f"Properties/bool[@name='{flag}']") for flag in
                     ("Anchored", "CanCollide", "CanQuery", "CanTouch")}
            if flags != {"Anchored": "true", "CanCollide": "false", "CanQuery": "false", "CanTouch": "false"}:
                raise RuntimeError(f"Salt Flats visual mesh gains query or physics ownership: {name}")
            if not part.findtext("Properties/Content[@name='MeshContent']/uri", "").startswith("rbxassetid://"):
                raise RuntimeError(f"Salt Flats mesh is missing native identity: {name}")
        elif part.get("class") in {"Script", "LocalScript", "ModuleScript"}:
            raise RuntimeError(f"Unexpected executable imported with Salt Flats: {name}")
        elif part.get("class") == "Part" and name.startswith(hangar + "HerculesWreck/"):
            wreck_proxies.add(name.rsplit("/", 1)[-1])
    if mesh_count != receipt["meshes"] or not {"CargoDeck", "Ramp", "AftBulkhead"} <= wreck_proxies:
        raise RuntimeError("Incomplete Salt Flats native assembly or wreck")
    print(f"Salt Flats native bank passed: {mesh_count} mesh parts, {len(panel_ids)} panel identities, "
          f"{len(wreck_proxies)} wreck collision proxies.")
    return mesh_count


def check_sandbreak_import(path: Path) -> int:
    """Check exact managed panels and ownership of native query MeshParts."""
    receipt_path = ROOT / "assets/imports/sandbreak/native-receipt.json"
    if not receipt_path.is_file():
        return 0
    receipt = json.loads(receipt_path.read_text())
    nodes = instance_nodes(path)
    assembly = "ServerStorage/Assets/SandbreakBunker/"
    variants = "ServerStorage/Assets/SandbreakPanelVariants/"
    panel_root = assembly + "SpawnShelterPanels/"
    panels = {name.removeprefix(panel_root) for name in nodes
              if name.startswith(panel_root) and "/" not in name.removeprefix(panel_root)}
    if len(panels) != receipt["panelCount"] or any(
        f"{variants}{panel}/{stage}" not in nodes for panel in panels for stage in ("Light", "Heavy")
    ):
        raise RuntimeError("Incomplete Sandbreak panel states")
    mesh_count = 0
    proxies = 0
    for name, part in nodes.items():
        if not name.startswith((assembly, variants)):
            continue
        if part.get("class") in {"Script", "LocalScript", "ModuleScript"}:
            raise RuntimeError(f"Unexpected executable imported with Sandbreak: {name}")
        if part.get("class") != "MeshPart":
            continue
        mesh_count += 1
        is_proxy = name.endswith("_Proxy")
        proxies += int(is_proxy)
        expected = "true" if is_proxy else "false"
        flags = {flag: part.findtext(f"Properties/bool[@name='{flag}']") for flag in
                 ("Anchored", "CanCollide", "CanQuery", "CanTouch")}
        if flags != {"Anchored": "true", "CanCollide": expected, "CanQuery": expected, "CanTouch": "false"}:
            raise RuntimeError(f"Wrong Sandbreak collision ownership: {name}")
        if not part.findtext("Properties/Content[@name='MeshContent']/uri", "").startswith("rbxassetid://"):
            raise RuntimeError(f"Sandbreak mesh is missing native identity: {name}")
        if name.rsplit("/", 1)[-1].startswith(("SB_yard_", "SB_hall_dressing_")):
            if compiled_surface_attributes(part).get("ThermalNonCover") is not True:
                raise RuntimeError(f"Sandbreak dressing is missing its thermal opacity flag: {name}")
    if mesh_count != receipt["managedMeshCount"] or proxies != 3 * receipt["panelCount"]:
        raise RuntimeError(f"Unexpected Sandbreak native counts: {mesh_count} meshes and {proxies} proxies")
    print(f"Sandbreak native banks passed: {mesh_count} MeshParts, {len(panels)} panel identities.")
    return mesh_count


def main() -> None:
    """Assert bootstraps/spawn exist and all test-only Instances are absent from release."""
    release = paths(ROOT / "build/game.rbxlx")
    tests = paths(ROOT / "build/tests.rbxlx")
    expected = {
        "ServerScriptService/Server": "Script",
        "ServerScriptService/Server/Bootstrap": "ModuleScript",
        "StarterPlayer/StarterPlayerScripts/Client": "LocalScript",
        "StarterPlayer/StarterPlayerScripts/Client/StatusPanel": "ModuleScript",
        "Workspace/World/Battlefield/GroundSpawn": "SpawnLocation",
        "ServerScriptService/Server/BlastGeometry": "ModuleScript",
        "ReplicatedStorage/Shared/WeaponImpactRules": "ModuleScript",
        "StarterPlayer/StarterPlayerScripts/Client/WeaponImpactEffects": "ModuleScript",
    }
    for name, class_name in expected.items():
        if release.get(name) != class_name or tests.get(name) != class_name:
            raise RuntimeError(f"Missing mapped runtime Instance: {name}")
    # Only runtime-authored modules/scripts may occur in the release mapping.
    allowed_scripts = {name for name, kind in release.items() if kind in {"Script", "LocalScript", "ModuleScript"}}
    expected_scripts = set(expected) - {"Workspace/World/Battlefield/GroundSpawn"}
    expected_scripts.add("ServerScriptService/Server/MapService")
    expected_scripts.add("ServerScriptService/Server/LobbyGeometry")
    expected_scripts |= {f"ServerScriptService/Server/{name}" for name in ("ApprovedOutpost", "PanelAssetRules", "PanelAssetCatalog", "MaterialPanelGeometry", "OutpostReconstruction")}
    expected_scripts |= {f"ServerScriptService/Server/{name}" for name in ("VesperReconstruction", "VesperNavigation", "VesperPanelGeometry", "SaltFlatsReconstruction", "SandbreakReconstruction", "SeedshipReconstruction")}
    expected_scripts |= {f"ServerScriptService/Server/{name}" for name in ("RoleService", "RoundRules", "MatchService", "MatchRuntime", "GameRuntime", "CharacterOwner")}
    expected_scripts.add("StarterPlayer/StarterPlayerScripts/Client/RoundPanel")
    expected_scripts.add("StarterPlayer/StarterPlayerScripts/Client/ThermalCameraController")
    expected_scripts.add("StarterPlayer/StarterPlayerScripts/Client/ThermalCosmetics")
    expected_scripts.add("StarterPlayer/StarterPlayerScripts/Client/GroundCombatController")
    expected_scripts.add("StarterPlayer/StarterPlayerScripts/Client/GroundIndoorCamera")
    expected_scripts |= {f"StarterPlayer/StarterPlayerScripts/Client/{name}" for name in ("PresentationEffects", "SpectatorCamera", "WeaponAudio")}
    expected_scripts |= {f"ServerScriptService/Server/{name}" for name in ("AircraftService", "AircraftSelection", "TerrainRecipe", "BuildingGeometry", "CombatService", "CombatRuntime", "DamageRules", "CombatViewRules", "AircraftHealth", "GroundCombatService", "GroundCombatRuntime", "GroundMovementGuard", "GroundOriginGeometry", "LauncherService", "LauncherGeometry", "LauncherRuntime", "PanelDamageRules", "DestructionService", "PanelGeometry", "PanelFragments", "DestructionRuntime")}
    expected_scripts.add("ReplicatedStorage/Shared/AircraftRules")
    expected_scripts.add("ReplicatedStorage/Shared/AircraftPanRules")
    expected_scripts.add("ReplicatedStorage/Shared/GroundCameraRules")
    expected_scripts.add("ReplicatedStorage/Shared/PlayerPresentation")
    expected_scripts.add("ReplicatedStorage/Shared/WeaponSoundRules")
    expected_scripts.add("ReplicatedStorage/Shared/AssetMaterial")
    expected_scripts.add("ReplicatedStorage/Shared/AssetMesh")
    expected_scripts |= {f"ReplicatedStorage/Shared/{name}" for name in ("Config", "Validation", "RateLimit", "Lifecycle", "MapRules", "BuildingLayout")}
    if allowed_scripts != expected_scripts:
        raise RuntimeError(f"Unexpected/missing release scripts: {allowed_scripts ^ expected_scripts}")
    for name in release:
        if any(token in name.lower() for token in ("test", "fixture", "developmentsettings", "override", "packages", ".spec")):
            raise RuntimeError(f"Test content leaked to release: {name}")
    for name in ("ServerScriptService/ServerTests", "StarterPlayer/StarterPlayerScripts/ClientTests", "ReplicatedStorage/TestPackages/TestEZ", "ServerStorage/DevelopmentSettings"):
        if name not in tests:
            raise RuntimeError(f"Test mapping missing {name}")
    for name in (
        "ServerStorage/Tests/Studio/BlastGeometry.spec",
        "ReplicatedStorage/ClientSpecs/WeaponImpactEffects.spec",
    ):
        if tests.get(name) != "ModuleScript" or name in release:
            raise RuntimeError(f"P19 impact fixture missing from tests or leaked to release: {name}")
    for name in ("ServerStorage/Tests/Studio/LobbyGeometry.spec", "ReplicatedStorage/ClientSpecs/GroundIndoorCamera.spec"):
        if tests.get(name) != "ModuleScript" or name in release:
            raise RuntimeError(f"P22 camera or lobby fixture missing from tests or leaked to release: {name}")
    for name in (
        "ServerScriptService/ServerTests/DestructionHarness",
        "StarterPlayer/StarterPlayerScripts/ClientTests/DestructionHarness",
        "ServerStorage/Tests/Studio/PanelDestruction.spec",
        "ServerStorage/Tests/Studio/MaterialPanels.spec",
        "ServerStorage/Tests/Studio/VesperPanels.spec",
    ):
        if tests.get(name) != "ModuleScript" or name in release:
            raise RuntimeError(f"P07 destruction fixture missing from tests or leaked to release: {name}")
    # The P06 manual selector/runner is wholly test-mapped, never shipped.
    check_manual_p06_isolation(release, tests)
    for name in MANUAL_P06_TEST_ONLY:
        for fault in ("missing", "leaked"):
            altered_release, altered_tests = dict(release), dict(tests)
            if fault == "missing":
                del altered_tests[name]
            else:
                altered_release[name] = "ModuleScript"
            try:
                check_manual_p06_isolation(altered_release, altered_tests)
            except RuntimeError:
                pass
            else:
                raise RuntimeError(f"P06 manual isolation failed to reject {fault}: {name}")
    print("P06 manual fixture isolation passed, including eight deliberate corruption probes.")
    check_manual_p05_isolation(release, tests)
    for name in MANUAL_P05_TEST_ONLY:
        for fault in ("missing", "leaked"):
            altered_release, altered_tests = dict(release), dict(tests)
            if fault == "missing":
                del altered_tests[name]
            else:
                altered_release[name] = "ModuleScript"
            try:
                check_manual_p05_isolation(altered_release, altered_tests)
            except RuntimeError:
                pass
            else:
                raise RuntimeError(f"P05 manual isolation failed to reject {fault}: {name}")
    print("P05 manual fixture isolation passed, including eight deliberate corruption probes.")
    check_manual_p17_isolation(release, tests)
    check_p18_isolation(release, tests)
    print("P17 native fixture isolation passed: four test-only modules, no release additions.")
    for name in (
        "ServerScriptService/ServerTests/PlayerExperienceHarness",
        "StarterPlayer/StarterPlayerScripts/ClientTests/PlayerExperienceHarness",
        "ReplicatedStorage/ClientSpecs/SpectatorCamera.spec",
    ):
        if tests.get(name) != "ModuleScript" or name in release:
            raise RuntimeError(f"P10 presentation fixture missing from tests or leaked to release: {name}")
    print("P10 presentation fixture isolation passed: three test-only modules, no release additions.")
    for name in (
        "ReplicatedStorage/P11Metrics",
        "ServerScriptService/ServerTests/P11CombatFixture",
        "ServerScriptService/ServerTests/PerformanceHarness",
        "StarterPlayer/StarterPlayerScripts/ClientTests/PerformanceHarness",
    ):
        if tests.get(name) != "ModuleScript" or name in release:
            raise RuntimeError(f"P11 performance fixture missing from tests or leaked to release: {name}")
    print("P11 performance fixture isolation passed: four test-only modules, no release additions.")
    check_expanded_world_contract()
    release_parts = check_authored_geometry(ROOT / "build/game.rbxlx")
    test_parts = check_authored_geometry(ROOT / "build/tests.rbxlx")
    release_parts += check_vesper_import(ROOT / "build/game.rbxlx")
    test_parts += check_vesper_import(ROOT / "build/tests.rbxlx")
    release_parts += check_salt_flats_import(ROOT / "build/game.rbxlx")
    test_parts += check_salt_flats_import(ROOT / "build/tests.rbxlx")
    release_parts += check_sandbreak_import(ROOT / "build/game.rbxlx")
    test_parts += check_sandbreak_import(ROOT / "build/tests.rbxlx")
    if LOBBY_ART_SOURCE.exists() or LOBBY_ART in release or LOBBY_ART in tests:
        if LOBBY_ART not in release or LOBBY_ART not in tests:
            raise RuntimeError("Furnished lobby art must be mapped in both constructs")
        visual_spec = "ReplicatedStorage/ClientSpecs/LobbyArt.spec"
        if tests.get(visual_spec) != "ModuleScript" or visual_spec in release:
            raise RuntimeError("P22 native art check must be isolated to the test mapping")
        lobby_catalog = json.loads(LOBBY_CATALOG.read_text())
        release_lobby = check_native_lobby_art(instance_nodes(ROOT / "build/game.rbxlx"), lobby_catalog)
        test_lobby = check_native_lobby_art(instance_nodes(ROOT / "build/tests.rbxlx"), lobby_catalog)
        if release_lobby != test_lobby:
            raise RuntimeError("P22 native lobby differs between release and test builds")
        release_parts += len(release_lobby)
        test_parts += len(test_lobby)
        print(f"Lobby reconstruction passed: {len(release_lobby)} native meshes, one bust, six mapped portraits.")
    elif any(path.rsplit("/", 1)[-1].startswith("P22_") for place in (release, tests) for path in place):
        raise RuntimeError("Archived P22 lobby art leaked into a playable mapping")
    geometry_rejection_probes()
    print(f"Authored geometry reconstruction passed: {release_parts} release/{test_parts} test part transforms, dimensions, shape and collision flags.")
    print(f"Artifact isolation passed: {len(release)} release Instances, {len(tests)} test Instances; {len(allowed_scripts)} runtime scripts only in release.")


if __name__ == "__main__":
    main()
