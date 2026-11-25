"""R01/P16 provenance regression checks against disposable checkout fixtures.

Run with ``python3 -m unittest discover -s tests/tooling -v``. These tests prove
manifest rejection/coverage, not Blender geometry or Roblox import behavior.
"""
import hashlib
import importlib.util
from pathlib import Path
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location(
    "check_repository", Path(__file__).resolve().parents[2] / "scripts/check_repository.py"
)
CHECKER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CHECKER)


class AssetManifestTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="p16-manifest-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.path = self.root / "assets/blender/military-outpost/source.blend"
        self.path.parent.mkdir(parents=True)
        self.path.write_bytes(b"disposable source fixture")
        self.asset = {
            "id": "outpost-source", "kind": "source", "source": "Original local authoring",
            "author": "Project contributors", "license": "Project license",
            "local_path": self.path.relative_to(self.root).as_posix(),
            "roblox_asset_id": None, "upload_owner": None,
            "sha256": hashlib.sha256(self.path.read_bytes()).hexdigest(),
        }
        self.manifest = {"schema_version": 1, "assets": [self.asset]}

    def check(self):
        CHECKER.check_manifest(self.manifest, root=self.root)

    def test_complete_source_and_export_coverage(self):
        export = self.root / "assets/exports/military-outpost/panel.obj"
        export.parent.mkdir(parents=True)
        export.write_text("v 0 0 0\n")
        record = dict(self.asset, id="panel-mesh", kind="mesh",
                      local_path=export.relative_to(self.root).as_posix(),
                      sha256=hashlib.sha256(export.read_bytes()).hexdigest())
        self.manifest["assets"].append(record)
        (export.parent / "README.md").write_text("Documentation is checked as Markdown.")
        self.check()

    def test_missing_dependency_rejects(self):
        self.path.unlink()
        with self.assertRaisesRegex(ValueError, "missing local path"):
            self.check()

    def test_unrecorded_texture_rejects(self):
        (self.path.parent / "base.png").write_bytes(b"texture fixture")
        with self.assertRaisesRegex(ValueError, "coverage mismatch"):
            self.check()

    def test_changed_source_rejects(self):
        self.path.write_bytes(b"changed after approval")
        with self.assertRaisesRegex(ValueError, "hash mismatch"):
            self.check()

    def test_package_requires_hash(self):
        del self.asset["sha256"]
        with self.assertRaisesRegex(ValueError, "requires a lowercase SHA-256"):
            self.check()

    def test_duplicate_path_rejects(self):
        self.manifest["assets"].append(dict(self.asset, id="duplicate"))
        with self.assertRaisesRegex(ValueError, "duplicate or noncanonical"):
            self.check()

    def test_noncanonical_path_rejects(self):
        self.asset["local_path"] = "assets/blender/./military-outpost/source.blend"
        with self.assertRaisesRegex(ValueError, "noncanonical"):
            self.check()

    def test_backup_rejects_even_when_recorded(self):
        backup = self.path.with_suffix(".blend1")
        backup.write_bytes(self.path.read_bytes())
        self.manifest["assets"].append(dict(self.asset, id="backup", local_path=backup.relative_to(self.root).as_posix()))
        with self.assertRaisesRegex(ValueError, "cache/backup"):
            self.check()

    def test_large_binary_rejects(self):
        with self.path.open("wb") as stream:
            stream.truncate(CHECKER.MAX_AUTHORED_BINARY_BYTES)
        self.asset["sha256"] = hashlib.sha256(self.path.read_bytes()).hexdigest()
        with self.assertRaisesRegex(ValueError, "file budget"):
            self.check()

    def test_manifest_path_cannot_escape_checkout(self):
        self.asset["local_path"] = "../outside.blend"
        with self.assertRaisesRegex(ValueError, "escapes repository"):
            self.check()


if __name__ == "__main__":
    unittest.main()
