"""R27/P28 A1 package invariants for the editable and source-managed aircraft."""
import hashlib
import json
from pathlib import Path
import struct
import unittest

ROOT = Path(__file__).resolve().parents[2]
NATIVE = ROOT / "assets/models/C130.model.json"
EXPORTS = ROOT / "assets/exports/c130"


class AircraftPackageTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.model = json.loads(NATIVE.read_text())
        cls.audit = json.loads((EXPORTS / "package-audit.json").read_text())
        cls.root, cls.airframe, cls.rotors = cls.model["Children"]

    def test_managed_export_has_bound_blender_source_and_no_remote_dependencies(self):
        self.assertEqual(self.audit["externalAssetDependencies"], [])
        for path, expected in self.audit["sha256"].items():
            self.assertEqual(hashlib.sha256((ROOT / path).read_bytes()).hexdigest(), expected, path)
        glb = (EXPORTS / "c130.glb").read_bytes()
        magic, version, length, json_size, kind = struct.unpack_from("<4s4I", glb)
        self.assertEqual((magic, version, length, kind), (b"glTF", 2, len(glb), 0x4E4F534A))
        graph = json.loads(glb[20:20 + json_size])
        self.assertNotIn("images", graph)
        self.assertFalse(any("uri" in entry for entry in graph["buffers"]))
        self.assertEqual(len(graph["nodes"]), self.audit["meshObjects"])
        self.assertEqual(len(graph["meshes"]), self.audit["meshObjects"])

    def test_flight_frame_muzzles_share_original_root_and_visible_bores(self):
        root = self.root["Properties"]
        self.assertEqual(self.root["Name"], "Hitbox")
        self.assertEqual(root["Size"], [12, 10, 46])
        self.assertEqual(root["CFrame"], [0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1])
        self.assertEqual(root["Transparency"], 1)
        self.assertFalse(root["CanQuery"])
        markers = {item["Name"]: item["Properties"]["CFrame"] for item in self.root["Children"]}
        visual = {item["Name"]: item["Properties"] for item in self.airframe["Children"]}
        for weapon, sign in (("GAU23", -1), ("M102", 1)):
            marker = markers[f"{weapon}Muzzle"]
            self.assertEqual(marker[:3], visual[f"{weapon} dark bore"]["CFrame"][:3])
            self.assertEqual(marker[:3], self.audit["muzzlesStuds"][f"{weapon}Muzzle"])
            self.assertGreater(marker[0] * sign, 6)
            self.assertLess(marker[1], 0)
            self.assertEqual(marker[3], sign)
        for span, low, high in zip((58, 18.5, 57.6), self.audit["boundsStuds"]["minimum"],
                                   self.audit["boundsStuds"]["maximum"]):
            self.assertAlmostEqual(high - low, span, delta=0.1)
        self.assertLess(self.audit["boundsStuds"]["minimum"][2], -27)

    def test_native_query_shapes_and_cosmetic_rotors_do_not_share_authority(self):
        visual = self.airframe["Children"]
        groups = self.rotors["Children"]
        self.assertEqual([group["Name"] for group in groups], ["Port1", "Port2", "Starboard1", "Starboard2"])
        for group in groups:
            rotor_name = group["Name"]
            parts = group["Children"]
            self.assertEqual(parts[0]["Name"], "Hub")
            self.assertEqual(parts[0]["Properties"]["CFrame"][:3], self.audit["rotorAxesStuds"][rotor_name])
            self.assertEqual(len(parts), 9)
            self.assertTrue(all(not part["Properties"]["CanQuery"] for part in parts))
        self.assertEqual(sum(item["Properties"]["CanQuery"] for item in visual),
                         self.audit["nativeQueryableObjects"])
        self.assertTrue(all(item["Properties"]["Transparency"] == 0 for item in visual
                            if item["Properties"]["CanQuery"]))
        managed = visual + [part for rotor in groups for part in rotor["Children"][1:]]
        self.assertEqual(len(managed), self.audit["meshObjects"])
        self.assertLessEqual(len(managed), 325)
        self.assertTrue(all(item["ClassName"] in {"Part", "WedgePart"} for item in managed))
        for item in managed:
            properties = item["Properties"]
            self.assertFalse(properties["CanTouch"])
            self.assertFalse(properties["CanCollide"])

if __name__ == "__main__":
    unittest.main()
