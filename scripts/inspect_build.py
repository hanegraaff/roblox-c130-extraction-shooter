"""Inspect actual Rojo XML artifacts, proving release/test DataModel isolation."""
from pathlib import Path
import xml.etree.ElementTree as ET
import json
import math
import tempfile

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
    expected_scripts |= {f"ServerScriptService/Server/{name}" for name in ("AircraftService", "AircraftSelection")}
    expected_scripts.add("ReplicatedStorage/Shared/AircraftRules")
    expected_scripts |= {f"ReplicatedStorage/Shared/{name}" for name in ("Config", "Validation", "RateLimit", "Lifecycle", "MapRules")}
    if allowed_scripts != expected_scripts:
        raise RuntimeError(f"Unexpected/missing release scripts: {allowed_scripts ^ expected_scripts}")
    for name in release:
        if any(token in name.lower() for token in ("test", "fixture", "developmentsettings", "override", "packages", ".spec")):
            raise RuntimeError(f"Test content leaked to release: {name}")
    for name in ("ServerScriptService/ServerTests", "StarterPlayer/StarterPlayerScripts/ClientTests", "ReplicatedStorage/TestPackages/TestEZ", "ServerStorage/DevelopmentSettings"):
        if name not in tests:
            raise RuntimeError(f"Test mapping missing {name}")
    release_parts = check_authored_geometry(ROOT / "build/game.rbxlx")
    test_parts = check_authored_geometry(ROOT / "build/tests.rbxlx")
    geometry_rejection_probes()
    print(f"Authored geometry reconstruction passed: {release_parts} release/{test_parts} test part transforms, dimensions, shape and collision flags.")
    print(f"Artifact isolation passed: {len(release)} release Instances, {len(tests)} test Instances; {len(allowed_scripts)} runtime scripts only in release.")


if __name__ == "__main__":
    main()
