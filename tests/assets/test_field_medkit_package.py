"""R27/P30 verifies the source-backed, floor-pivoted field medkit package."""
from pathlib import Path
import hashlib
import json
import math
import struct
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
EXPORTS = ROOT / "assets/exports/medkit"


class FieldMedkitPackageTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.audit = json.loads((EXPORTS / "package-audit.json").read_text())
        cls.model = ET.parse(EXPORTS / "field-medkit.rbxmx").find("Item")
        cls.parts = {
            item.findtext("Properties/string[@name='Name']"): item
            for item in cls.model.findall("Item")
        }

    def test_manifest_binds_master_native_export_and_five_site_poses(self):
        manifest = json.loads((ROOT / "assets/manifest.json").read_text())["assets"]
        records = {row["id"]: row for row in manifest if row["id"].startswith("field-medkit-")}
        self.assertEqual(set(records), {f"field-medkit-{name}" for name in (
            "master", "glb", "native", "audit", "front-review", "rear-review",
        )})
        for record in records.values():
            self.assertIsNone(record["roblox_asset_id"])
            self.assertEqual(hashlib.sha256((ROOT / record["local_path"]).read_bytes()).hexdigest(), record["sha256"])
        for path, expected in self.audit["sha256"].items():
            self.assertEqual(hashlib.sha256((ROOT / path).read_bytes()).hexdigest(), expected, path)
        anchors = json.loads((ROOT / "assets/world/MedkitAnchors.model.json").read_text())["Children"]
        self.assertEqual({item["Name"] for item in anchors}, {
            "MedkitSandbreak", "MedkitHangar", "MedkitRadar", "MedkitDepot", "MedkitSeedship",
        })
        for item in anchors:
            props = item["Properties"]
            x, _, z, *rotation = props["CFrame"]
            self.assertLess(math.hypot(x, z), 360)
            self.assertEqual(rotation[3:6], [0, 1, 0])
            self.assertTrue(props["Anchored"])
            self.assertFalse(any(props[flag] for flag in ("CanCollide", "CanQuery", "CanTouch")))

    def test_portable_and_native_geometry_have_same_inert_inventory(self):
        glb = (EXPORTS / "field-medkit.glb").read_bytes()
        magic, version, length, json_size, kind = struct.unpack_from("<4s4I", glb)
        self.assertEqual((magic, version, length, kind), (b"glTF", 2, len(glb), 0x4E4F534A))
        graph = json.loads(glb[20:20 + json_size])
        for field in ("images", "cameras", "textures"):
            self.assertNotIn(field, graph)
        self.assertFalse(any("uri" in buffer for buffer in graph["buffers"]))
        self.assertEqual(self.audit["externalAssetDependencies"], [])
        self.assertEqual({node["name"] for node in graph["nodes"]}, self.parts.keys())
        self.assertEqual({material["name"] for material in graph["materials"]}, set(self.audit["materials"]))
        self.assertEqual(len(self.parts), len(graph["meshes"]))
        self.assertEqual(len(self.parts), self.audit["meshObjects"])
        self.assertLessEqual(len(self.parts), 125)
        self.assertLessEqual(self.audit["triangles"], 1500)
        self.assertFalse(self.model.findall(".//Content"))
        for name, item in self.parts.items():
            self.assertIn(item.attrib["class"], ("Part", "WedgePart"), name)
            self.assertEqual(item.findtext("Properties/bool[@name='Anchored']"), "true", name)
            for flag in ("CanCollide", "CanQuery", "CanTouch"):
                self.assertEqual(item.findtext(f"Properties/bool[@name='{flag}']"), "false", name)

    def test_case_scale_front_marking_and_floor_pivot(self):
        pivot = self.model.find("Properties/OptionalCoordinateFrame[@name='WorldPivotData']/CFrame")
        self.assertEqual([float(pivot.findtext(axis)) for axis in "XYZ"], [0, 0, 0])
        lo, hi = (self.audit["boundsStuds"][key] for key in ("minimum", "maximum"))
        self.assertEqual(lo[1], 0)
        for actual, expected in zip((b - a for a, b in zip(lo, hi)), (2.14, 1.7185, 1.0605)):
            self.assertAlmostEqual(actual, expected, delta=.005)
        self.assertEqual(self.audit["axisConvention"]["robloxAndGlb"], "+X right, -Z front, +Y up")
        cross = self.parts["Ivory cross upright"].find("Properties/CoordinateFrame[@name='CFrame']")
        hinge = self.parts["left hinge knuckle"].find("Properties/CoordinateFrame[@name='CFrame']")
        self.assertLess(float(cross.findtext("Z")), -.45)
        self.assertGreater(float(hinge.findtext("Z")), .4)
