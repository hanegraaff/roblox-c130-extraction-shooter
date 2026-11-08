"""Inspect actual Rojo XML artifacts, proving release/test DataModel isolation."""
from pathlib import Path
import xml.etree.ElementTree as ET

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


def main() -> None:
    """Assert bootstraps/spawn exist and all test-only Instances are absent from release."""
    release = paths(ROOT / "build/game.rbxlx")
    tests = paths(ROOT / "build/tests.rbxlx")
    expected = {
        "ServerScriptService/Server": "Script",
        "ServerScriptService/Server/Bootstrap": "ModuleScript",
        "StarterPlayer/StarterPlayerScripts/Client": "LocalScript",
        "StarterPlayer/StarterPlayerScripts/Client/StatusPanel": "ModuleScript",
        "Workspace/World/FoundationSpawn": "SpawnLocation",
    }
    for name, class_name in expected.items():
        if release.get(name) != class_name or tests.get(name) != class_name:
            raise RuntimeError(f"Missing mapped runtime Instance: {name}")
    # Only runtime-authored modules/scripts may occur in the release mapping.
    allowed_scripts = {name for name, kind in release.items() if kind in {"Script", "LocalScript", "ModuleScript"}}
    expected_scripts = set(expected) - {"Workspace/World/FoundationSpawn"}
    expected_scripts |= {f"ReplicatedStorage/Shared/{name}" for name in ("Config", "Validation", "RateLimit", "Lifecycle")}
    if allowed_scripts != expected_scripts:
        raise RuntimeError(f"Unexpected/missing release scripts: {allowed_scripts ^ expected_scripts}")
    for name in release:
        if any(token in name.lower() for token in ("test", "fixture", "developmentsettings", "override", "packages", ".spec")):
            raise RuntimeError(f"Test content leaked to release: {name}")
    for name in ("ServerScriptService/ServerTests", "StarterPlayer/StarterPlayerScripts/ClientTests", "ReplicatedStorage/TestPackages/TestEZ", "ServerStorage/DevelopmentSettings"):
        if name not in tests:
            raise RuntimeError(f"Test mapping missing {name}")
    print(f"Artifact isolation passed: {len(release)} release Instances, {len(tests)} test Instances; 8 runtime scripts only in release.")


if __name__ == "__main__":
    main()
