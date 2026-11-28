"""R27/P29 A1 provenance and staged native geometry checks."""
import hashlib
import json
from pathlib import Path
import struct
import unittest

ROOT = Path(__file__).resolve().parents[2]
MODEL = ROOT / "assets/models/DepotLauncher.model.json"
EXPORTS = ROOT / "assets/exports/rocket-launcher"


class DepotLauncherPackageTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.model = json.loads(MODEL.read_text())
        cls.audit = json.loads((EXPORTS / "package-audit.json").read_text())
        cls.handle, *cls.visuals = cls.model["Children"]
        cls.markers = {item["Name"]: item["Properties"]["CFrame"] for item in cls.handle["Children"]}
        cls.parts = {item["Name"]: item["Properties"] for item in cls.visuals}

    def test_manifest_binds_original_master_and_both_geometry_exports(self):
        manifest = json.loads((ROOT / "assets/manifest.json").read_text())["assets"]
        records = {row["id"]: row for row in manifest if row["id"].startswith("depot-launcher-")}
        self.assertEqual(set(records), {f"depot-launcher-{suffix}" for suffix in (
            "master", "glb", "native", "audit", "three-quarter",
        )})
        self.assertEqual(records["depot-launcher-native"]["studio_path"], "ServerStorage.Assets.DepotLauncher")
        for record in records.values():
            data = (ROOT / record["local_path"]).read_bytes()
            self.assertEqual(hashlib.sha256(data).hexdigest(), record["sha256"])
            self.assertIsNone(record["roblox_asset_id"])
        for path, expected in self.audit["sha256"].items():
            self.assertEqual(hashlib.sha256((ROOT / path).read_bytes()).hexdigest(), expected, path)
        self.assertEqual(self.audit["externalAssetDependencies"], [])

    def test_portable_model_and_native_parts_have_identical_inventory(self):
        glb = (EXPORTS / "rocket-launcher.glb").read_bytes()
        magic, version, length, json_size, kind = struct.unpack_from("<4s4I", glb)
        self.assertEqual((magic, version, length, kind), (b"glTF", 2, len(glb), 0x4E4F534A))
        graph = json.loads(glb[20:20 + json_size])
        self.assertNotIn("images", graph)
        self.assertNotIn("cameras", graph)
        self.assertFalse(any("uri" in buffer for buffer in graph["buffers"]))
        self.assertEqual({node["name"] for node in graph["nodes"]}, self.parts.keys())
        self.assertEqual({material["name"] for material in graph["materials"]}, set(self.audit["materials"]))
        self.assertEqual(len(graph["meshes"]), len(self.visuals))
        self.assertEqual(len(self.parts), self.audit["meshObjects"])
        self.assertLessEqual(self.audit["triangles"], 1500)
        self.assertLessEqual(len(self.parts), 130)
        self.assertEqual({piece["ClassName"] for piece in self.visuals}, {"Part", "WedgePart"})
        for piece in (self.handle, *self.visuals):
            props = piece["Properties"]
            self.assertTrue(props["Anchored"])
            self.assertTrue(props["Massless"])
            self.assertFalse(any(props[flag] for flag in ("CanTouch", "CanCollide", "CanQuery")))

    def test_compact_sealed_body_and_three_presentational_frames(self):
        self.assertEqual(self.handle["Name"], "Handle")
        self.assertEqual(self.handle["Properties"]["Transparency"], 1)
        self.assertEqual(set(self.markers), {"Muzzle", "CarryGrip", "GroundContact"})
        self.assertEqual(self.markers, self.audit["attachments"])
        low, high = (self.audit["boundsStuds"][key] for key in ("minimum", "maximum"))
        for axis, measured in enumerate((1.12, 1.97, 3.68)):
            self.assertAlmostEqual(high[axis] - low[axis], measured, delta=.02)
        self.assertAlmostEqual(self.markers["GroundContact"][0], low[0], delta=.001)
        self.assertAlmostEqual(self.markers["GroundContact"][4], -1, delta=.001)
        self.assertAlmostEqual(self.markers["Muzzle"][2], low[2], delta=.02)
        self.assertLess(self.markers["Muzzle"][2], low[2])
        self.assertLess(self.parts["Diagonal teal paint"]["CFrame"][2], -1.8)
        self.assertGreater(self.parts["Offset teal plate face"]["CFrame"][0], .5)
        cap = self.parts["Recessed end face center"]
        self.assertGreater(cap["Size"][0], .7)
        self.assertGreater(cap["Size"][1], .8)
        self.assertEqual(cap["Transparency"], 0)
        grip = self.markers["CarryGrip"]
        self.assertGreater(grip[1], low[1])
        self.assertLess(grip[1], -.55)


if __name__ == "__main__":
    unittest.main()
