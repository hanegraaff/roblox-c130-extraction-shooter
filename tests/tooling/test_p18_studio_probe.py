"""Exercise source-parity probe inputs, including Rojo XML spelling variants."""
import importlib.util
from pathlib import Path
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("p18_studio_probe", ROOT / "scripts/p18_studio_probe.py")
assert SPEC and SPEC.loader
PROBE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PROBE)


def fixture(source_tag: str = "string", size_name: str = "size") -> ET.Element:
    """Construct a small test build, not a substitute for native source checks."""
    root = ET.Element("roblox")

    def item(parent: ET.Element, name: str, class_name: str) -> ET.Element:
        node = ET.SubElement(parent, "Item", {"class": class_name})
        properties = ET.SubElement(node, "Properties")
        ET.SubElement(properties, "string", {"name": "Name"}).text = name
        return node

    server = item(root, "ServerScriptService", "ServerScriptService")
    runner = item(server, "ServerTests", "Script")
    ET.SubElement(runner.find("Properties"), source_tag, {"name": "Source"}).text = "-- café\nreturn 1\n"
    world = item(item(root, "Workspace", "Workspace"), "World", "Folder")
    battlefield = item(world, "Battlefield", "Model")
    anchors = item(battlefield, "Anchors", "Folder")
    for name in ("LauncherRadar", "LauncherHangar", "LauncherDepot", "LauncherSeedship", "SeedshipLauncherPlatform"):
        part = item(battlefield if name == "SeedshipLauncherPlatform" else anchors, name, "Part")
        properties = part.find("Properties")
        pose = ET.SubElement(properties, "CoordinateFrame", {"name": "CFrame"})
        for key, value in zip(("X", "Y", "Z", "R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22"),
                              (0, 3, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1)):
            ET.SubElement(pose, key).text = str(value)
        size = ET.SubElement(properties, "Vector3", {"name": size_name})
        for axis in ("X", "Y", "Z"):
            ET.SubElement(size, axis).text = "1"
    return root


class P18StudioProbeTests(unittest.TestCase):
    def test_rojo_source_and_size_spellings_preserve_utf8_and_full_pose(self) -> None:
        for source_tag, size_name in (("string", "size"), ("ProtectedString", "Size")):
            with self.subTest(source_tag=source_tag, size_name=size_name):
                scripts, geometry = PROBE.collect(fixture(source_tag, size_name))
                self.assertEqual(len(scripts), 1)
                self.assertEqual(scripts[0]["bytes"], len("-- café\nreturn 1\n".encode("utf-8")))
                self.assertEqual(scripts[0]["path"], ["ServerScriptService", "ServerTests"])
                self.assertEqual(len(geometry), 5)
                self.assertTrue(all(len(row["pose"]) == 12 for row in geometry))

    def test_missing_seedship_pickup_rejects_a_stale_build(self) -> None:
        root = fixture()
        anchors = next(node for node in root.iter("Item")
                       if node.findtext("Properties/string[@name='Name']") == "Anchors")
        pickup = next(node for node in anchors.findall("Item")
                      if node.findtext("Properties/string[@name='Name']") == "LauncherSeedship")
        anchors.remove(pickup)
        with self.assertRaisesRegex(ValueError, "four P18 pickups"):
            PROBE.collect(root)

    def test_release_mapping_cannot_be_mistaken_for_the_test_document(self) -> None:
        root = fixture()
        server = root.find("Item")
        assert server is not None
        server.remove(server.find("Item"))
        with self.assertRaisesRegex(ValueError, "nonempty test-mapped build"):
            PROBE.collect(root)


if __name__ == "__main__":
    unittest.main()
