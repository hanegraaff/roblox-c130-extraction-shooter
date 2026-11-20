"""P17 imported assembly fit rejects drift while retaining real local mesh bases."""
import copy
import importlib.util
import json
from pathlib import Path
import sys
import unittest

SCRIPTS = Path(__file__).resolve().parents[2] / "scripts"
sys.path.insert(0, str(SCRIPTS))
SPEC = importlib.util.spec_from_file_location("p17_normalize", SCRIPTS / "p17_normalize.py")
normalizer = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(normalizer)


class P17ImportNormalization(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.receipt = json.loads((normalizer.ROOT / "assets/imports/military-outpost/assembly-fbx-receipt-v1.json").read_text())

    def test_actual_receipt_matches_all_approved_objects_without_assuming_import_scale(self):
        result = normalizer.normalize_assembly(self.receipt)
        self.assertEqual(result["mesh_count"], 2225)
        self.assertLess(result["similarity"]["maximum_center_error_studs"], 1e-4)
        self.assertLess(result["maximum_bounds_error_studs"], 1e-4)
        self.assertEqual(result["similarity"]["rotation"], [1, 0, 0, 0, 1, 0, 0, 0, 1])
        self.assertGreater(result["asymmetric_landmarks"]["Exterior_balcony_landing"][0], 16)
        self.assertGreater(result["asymmetric_landmarks"]["Garage_roller_drum"][2], 24)
        self.assertEqual(result["components"][0]["cframe"][3:], [-1, 0, 0, 0, 1, 0, 0, 0, -1])
        self.assertFalse(result["material_repair_complete"])

    def test_similarity_fits_different_rotation_translation_and_scale(self):
        source = [[-1, 2, 3], [4, 5, 6], [7, -8, 9], [-10, 11, -12]]
        rotation = [0, 0, 1, 0, 1, 0, -1, 0, 0]
        observed = [[value * 7.5 + shift for value, shift in zip(normalizer.multiply(rotation, point), [100, -50, 20])] for point in source]
        result = normalizer.fit_similarity(source, observed)
        self.assertEqual(result["rotation"], rotation)
        self.assertAlmostEqual(result["scale"], 7.5)
        self.assertLess(result["maximum_center_error_studs"], 1e-10)

    def test_missing_duplicate_or_misplaced_imported_objects_reject(self):
        missing = copy.deepcopy(self.receipt)
        missing["components"].pop()
        missing["mesh_count"] -= 1
        with self.assertRaisesRegex(ValueError, "cover every approved object"):
            normalizer.normalize_assembly(missing)
        duplicate = copy.deepcopy(self.receipt)
        duplicate["components"][1]["name"] = duplicate["components"][0]["name"]
        with self.assertRaisesRegex(ValueError, "duplicate/unknown"):
            normalizer.normalize_assembly(duplicate)
        misplaced = copy.deepcopy(self.receipt)
        misplaced["components"][0]["cframe"][0] += 10
        with self.assertRaisesRegex(ValueError, "rigid/uniform similarity"):
            normalizer.normalize_assembly(misplaced)

    def test_geometry_mesh_id_and_owner_rejections_do_not_mutate_receipt(self):
        original = copy.deepcopy(self.receipt)
        for field, value, message in (("size", [0, 1, 1], "geometry/rotation"),
                                       ("mesh_id", "", "actual imported assembly MeshId")):
            broken = copy.deepcopy(self.receipt)
            broken["components"][0][field] = value
            with self.assertRaisesRegex(ValueError, message):
                normalizer.normalize_assembly(broken)
        owner = copy.deepcopy(self.receipt)
        owner["upload_owner"]["id"] = "1"
        with self.assertRaisesRegex(ValueError, "package/owner differs"):
            normalizer.normalize_assembly(owner)
        self.assertEqual(self.receipt, original)


if __name__ == "__main__":
    unittest.main()
