"""Preserve the Seedship artwork and panel bindings through Studio staging."""
import collections
import json
import tempfile
import unittest
from pathlib import Path

from scripts.seedship import prepare_import as ship


class SeedshipImportTests(unittest.TestCase):
    def test_staged_batches_preserve_export_counts_and_panel_bindings(self):
        report = json.loads((ship.ROOT / "docs/images/alien-spaceship/inspection.json").read_text())
        with tempfile.TemporaryDirectory() as directory:
            all_batches = []
            for filename, family in ship.FILES:
                batches = ship.stage((ship.EXPORTS / filename).read_bytes(), family, Path(directory))
                all_batches.extend(batches)
                objects = [piece for batch in batches for piece in batch["objects"]]
                self.assertEqual(len({piece["sourceObject"] for piece in objects}), report["files"][filename]["objects"])
                self.assertEqual(sum(piece["triangles"] for piece in objects), report["files"][filename]["assembledTriangles"])
                self.assertTrue(all(batch["expectedMeshParts"] <= ship.MAX_PARTS for batch in batches))
            catalog = json.loads((ship.ART / "panel-catalog.json").read_text())
            ship.validate_panels(catalog, all_batches)
            names = collections.Counter(record["importName"] for batch in all_batches for record in batch["objects"])
            self.assertEqual(max(names.values()), 1)
            self.assertEqual(all_batches[0]["file"], "seedship-p.glb")
            self.assertEqual(all_batches[0]["expectedMeshParts"], 12)
