"""Inspect actual Rojo XML artifacts, proving release/test DataModel isolation."""
from pathlib import Path
import xml.etree.ElementTree as ET
import json
import math
import tempfile
import copy

ROOT = Path(__file__).resolve().parent.parent


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
PART_CLASSES = {"Part", "SpawnLocation"}


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


def check_authored_geometry(path: Path) -> int:
    """Compare every authored part pose/size/shape/collision against the actual XML.

    Position/Orientation are runtime aliases, not canonical serialized properties;
    Roblox ignores them on file load. Requiring CFrame catches origin-piled maps
    before Studio. This gate verifies reconstruction, not engine navigation/rays.
    """
    nodes = instance_nodes(path)
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
            expected_shape = {"Block": "1", "Ball": "0", "Cylinder": "2"}[properties.get("Shape", "Block")]
            if item.findtext("Properties/token[@name='shape']", "1") != expected_shape:
                raise RuntimeError(f"Authored shape reconstruction mismatch: {full}")
            count += 1
        for child in source.get("Children", []):
            walk(child, full + "/" + child["Name"])

    for asset in manifest["assets"]:
        local = asset["local_path"]
        if not local or not local.endswith(".model.json"):
            continue
        source = json.loads((ROOT / local).read_text())
        base = "Workspace/World" if asset["kind"] == "world" else "ServerStorage/Assets"
        name = Path(local).name.removesuffix(".model.json")
        walk(source, base + "/" + name)
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
    roof = next(item["Properties"] for item in children["Permanent"]["Children"] if item["Name"] == "ShelterRoof")
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
    assert recipe_contract == {"version": 1, "seed": 0, "descriptor_path": "TerrainRecipe", "owner_module": "src/server/TerrainRecipe.luau", "voxel_resolution_studs": 4, "bounds_min": [-368, -112, -368], "bounds_max": [368, 32, 368], "hill_count": 8, "materials": ["Grass", "Rock"]}, "terrain manifest contract"
    recipe = {item["Name"]: item["Properties"] for item in children["TerrainRecipe"]["Children"]}
    assert len(recipe) == 9 and recipe["TerrainBounds"]["Size"] == [736, 144, 736], "terrain bounds/count"
    expected_hills = [(-260,-140,52),(-230,160,52),(240,-170,56),(240,150,52),(0,-260,60),(-110,-260,44),(120,260,44),(-260,0,48)]
    for index, (x, z, radius) in enumerate(expected_hills):
        hill = recipe[f"TerrainHill{index:02}"]
        assert hill["CFrame"][:3] == [x, 16-radius, z] and hill["Size"] == [radius*2]*3, "terrain deterministic elevation recipe"
        assert hill["Shape"] == "Ball" and hill["Material"] == ("Grass" if index % 2 == 0 else "Rock"), "terrain material recipe"
        assert not hill["CanCollide"] and not hill["CanQuery"] and hill["Transparency"] == 1, "terrain descriptors must be inert"
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
    print(f"Expanded world source contract passed: 720-stud diameter, 8 deterministic terrain hills, 3 two-story buildings, {len(ids)} stable panel pivots.")


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
    }
    for name, class_name in expected.items():
        if release.get(name) != class_name or tests.get(name) != class_name:
            raise RuntimeError(f"Missing mapped runtime Instance: {name}")
    # Only runtime-authored modules/scripts may occur in the release mapping.
    allowed_scripts = {name for name, kind in release.items() if kind in {"Script", "LocalScript", "ModuleScript"}}
    expected_scripts = set(expected) - {"Workspace/World/Battlefield/GroundSpawn"}
    expected_scripts.add("ServerScriptService/Server/MapService")
    expected_scripts |= {f"ServerScriptService/Server/{name}" for name in ("RoleService", "RoundRules", "MatchService", "MatchRuntime", "GameRuntime", "CharacterOwner")}
    expected_scripts.add("StarterPlayer/StarterPlayerScripts/Client/RoundPanel")
    expected_scripts.add("StarterPlayer/StarterPlayerScripts/Client/ThermalCameraController")
    expected_scripts |= {f"ServerScriptService/Server/{name}" for name in ("AircraftService", "AircraftSelection", "TerrainRecipe", "BuildingGeometry")}
    expected_scripts.add("ReplicatedStorage/Shared/AircraftRules")
    expected_scripts |= {f"ReplicatedStorage/Shared/{name}" for name in ("Config", "Validation", "RateLimit", "Lifecycle", "MapRules", "BuildingLayout")}
    if allowed_scripts != expected_scripts:
        raise RuntimeError(f"Unexpected/missing release scripts: {allowed_scripts ^ expected_scripts}")
    for name in release:
        if any(token in name.lower() for token in ("test", "fixture", "developmentsettings", "override", "packages", ".spec")):
            raise RuntimeError(f"Test content leaked to release: {name}")
    for name in ("ServerScriptService/ServerTests", "StarterPlayer/StarterPlayerScripts/ClientTests", "ReplicatedStorage/TestPackages/TestEZ", "ServerStorage/DevelopmentSettings"):
        if name not in tests:
            raise RuntimeError(f"Test mapping missing {name}")
    check_expanded_world_contract()
    release_parts = check_authored_geometry(ROOT / "build/game.rbxlx")
    test_parts = check_authored_geometry(ROOT / "build/tests.rbxlx")
    geometry_rejection_probes()
    print(f"Authored geometry reconstruction passed: {release_parts} release/{test_parts} test part transforms, dimensions, shape and collision flags.")
    print(f"Artifact isolation passed: {len(release)} release Instances, {len(tests)} test Instances; {len(allowed_scripts)} runtime scripts only in release.")


if __name__ == "__main__":
    main()
