"""Verify the P22 import derivatives preserve the approved Blender scene."""

from collections import Counter
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

SCRIPTS = Path(__file__).resolve().parents[2] / "scripts"
sys.path.insert(0, str(SCRIPTS / "lobby_interior"))
import native_config
import stage_import


class WaitingLobbyImport(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory(prefix="waiting-lobby-import-")
        cls.addClassCleanup(cls.temporary.cleanup)
        cls.destination = Path(cls.temporary.name)
        cls.index = stage_import.stage(cls.destination)

    def test_preserves_every_approved_mesh_use_and_triangle(self):
        records = [part for batch in self.index["batches"] for part in batch["objects"]]
        self.assertEqual(self.index["meshParts"], 2432)
        self.assertEqual(self.index["triangles"], 411534)
        self.assertEqual(len({record["managedName"] for record in records}), len(records))
        self.assertEqual(Counter(record["role"] for record in records),
                         {"Portrait": 6, "Bust": 34, "Room": 2392})
        self.assertLessEqual(max(record["triangles"] for record in records), 20_000)

    def test_pilot_preserves_fourth_canvas_coordinates_and_texture(self):
        with patch.object(native_config, "OUTPUT", self.destination):
            config = native_config.configure("lobby-pilot.glb")
        self.assertEqual(len(config["rows"]), 22)
        [canvas] = [row for row in config["rows"].values() if row["role"] == "Portrait"]
        self.assertEqual(canvas["name"], "P22_Portrait_04")
        self.assertEqual(canvas["portrait"], 4)
        self.assertAlmostEqual(canvas["size"][1], 10.2, places=4)
        self.assertAlmostEqual(canvas["size"][2], 7.65, places=4)
        self.assertAlmostEqual(canvas["center"][0] + config["siteOrigin"][0], 584.218, places=4)
        catalog = json.loads((stage_import.SOURCE / "assembly.json").read_text())
        fourth = catalog["paintings"][3]
        self.assertEqual(fourth["clockwise_degrees"], 90)
        self.assertEqual(canvas["colorSha256"], fourth["source_sha256"])

    def test_rejects_changed_staging_before_native_capture(self):
        with tempfile.TemporaryDirectory(prefix="waiting-lobby-import-changed-") as tmp:
            changed = Path(tmp)
            (changed / "import-index.json").write_bytes((self.destination / "import-index.json").read_bytes())
            (changed / "lobby-pilot.glb").write_bytes((self.destination / "lobby-pilot.glb").read_bytes() + b"x")
            with patch.object(native_config, "OUTPUT", changed):
                with self.assertRaisesRegex(ValueError, "Staging bytes changed"):
                    native_config.configure("lobby-pilot.glb")

    def test_rejects_changed_portrait_hanging_catalog(self):
        with tempfile.TemporaryDirectory(prefix="waiting-lobby-catalog-changed-") as tmp:
            changed = Path(tmp)
            (changed / "waiting-lobby.blend").write_bytes((stage_import.SOURCE / "waiting-lobby.blend").read_bytes())
            catalog = json.loads((stage_import.SOURCE / "assembly.json").read_text())
            catalog["paintings"][3]["clockwise_degrees"] = 0
            (changed / "assembly.json").write_text(json.dumps(catalog))
            with patch.object(stage_import, "SOURCE", changed):
                with self.assertRaisesRegex(ValueError, "Placement catalog must match"):
                    stage_import.stage(changed / "staging")
