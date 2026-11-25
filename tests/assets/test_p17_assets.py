"""P17 preparation tests: approved source identity and generated descriptor only."""
import importlib.util
import hashlib
import json
from pathlib import Path
import re
import shutil
import tempfile
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

    def test_coordinated_export_lock_descriptor_and_manifest_refresh_cannot_replace_approval(self):
        """A valid UV edit remains unapproved even when every mutable hash agrees."""
        with tempfile.TemporaryDirectory(prefix="p17-approval-boundary-") as directory:
            root = Path(directory)
            for name in ("military-outpost.blend", "panel-catalog.json", "package-lock.json"):
                target = root / p17.SOURCE / name
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(p17.ROOT / p17.SOURCE / name, target)
            export_path = p17.EXPORT / "corrugated_wall-pristine.obj"
            export = root / export_path
            export.parent.mkdir(parents=True, exist_ok=True)
            original = (p17.ROOT / export_path).read_text()
            edited, count = re.subn(r"^vt [^\n]+$", "vt 0.25 0.75", original, count=1, flags=re.MULTILINE)
            self.assertEqual(count, 1)
            export.write_text(edited)
            before_digest = p17.sha(p17.ROOT / export_path)
            changed_digest = p17.sha(export)
            self.assertNotEqual(before_digest, changed_digest)
            lock_path = root / p17.SOURCE / "package-lock.json"
            lock = json.loads(lock_path.read_text())
            for entry in lock["files"]:
                if entry["path"] == export_path.as_posix():
                    entry.update(sha256=changed_digest, bytes=export.stat().st_size)
            lock_path.write_text(json.dumps(lock, indent=2) + "\n")
            self.assertNotEqual(p17.sha(lock_path), p17.PACKAGE_LOCK_SHA)
            generated = p17.compile_definition().replace(before_digest, changed_digest)
            output = root / p17.OUTPUT
            output.parent.mkdir(parents=True, exist_ok=True)
            output.write_text(generated)
            manifest = json.loads((p17.ROOT / "assets/manifest.json").read_text())
            for recipe in manifest["runtime_recipes"]:
                if recipe["id"] == "approved-outpost-materials":
                    recipe["sha256"] = hashlib.sha256(generated.encode()).hexdigest()
            (root / "assets/manifest.json").write_text(json.dumps(manifest))
            for operation in (p17.compile_definition, p17.verify):
                with self.assertRaisesRegex(ValueError, "approved P16 input: package-lock.json"):
                    operation(root)
            self.assertEqual(output.read_text(), generated, "rejected generation wrote runtime data")

    def test_changed_generated_values_fail_while_formatter_whitespace_is_allowed(self):
        self.assertEqual(p17.normalized("{ value = 1, }"), p17.normalized("{value=1}"))
        expected = p17.compile_definition()
        self.assertNotEqual(p17.normalized(expected.replace("{ 16, 1, 8 }", "{ 15, 1, 8 }", 1)), p17.normalized(expected))


if __name__ == "__main__":
    unittest.main()
