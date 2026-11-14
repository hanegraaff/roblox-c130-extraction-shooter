"""P17 preparation tests: approved source identity and generated descriptor only."""
import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[2] / "scripts/p17_assets.py"
SPEC = importlib.util.spec_from_file_location("p17_assets", SCRIPT)
p17 = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(p17)


class P17AssetDefinition(unittest.TestCase):
    def test_exact_approved_definition_is_reproducible_and_does_not_assert_cloud_access(self):
        report = p17.verify()
        self.assertEqual(report["passed"], 1)
        self.assertFalse(report["cloud_import_verified"])
        self.assertEqual(report["appearances"], 24)

    def test_changed_approval_input_rejects_before_generation(self):
        with patch.object(p17, "sha", return_value="0" * 64):
            with self.assertRaisesRegex(ValueError, "approved P16 input"):
                p17.compile_definition()

    def test_changed_export_rejects_without_writing_runtime_definition(self):
        real_sha = p17.sha
        before = (p17.ROOT / p17.OUTPUT).read_bytes()
        def corrupt_export(path):
            return "0" * 64 if path.name == "corrugated_wall-heavy.obj" else real_sha(path)
        with patch.object(p17, "sha", side_effect=corrupt_export):
            with self.assertRaisesRegex(ValueError, "differs from reviewed package lock"):
                p17.compile_definition()
        self.assertEqual((p17.ROOT / p17.OUTPUT).read_bytes(), before)

    def test_changed_generated_values_fail_while_formatter_whitespace_is_allowed(self):
        self.assertEqual(p17.normalized("{ value = 1, }"), p17.normalized("{value=1}"))
        expected = p17.compile_definition()
        self.assertNotEqual(p17.normalized(expected.replace("{ 16, 1, 8 }", "{ 15, 1, 8 }", 1)), p17.normalized(expected))


if __name__ == "__main__":
    unittest.main()
