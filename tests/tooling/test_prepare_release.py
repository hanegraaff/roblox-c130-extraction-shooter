"""Regression coverage for local release provenance and contamination guards."""

import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts"))

import prepare_release as release


class ReleasePreparationTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)

    def write(self, name, contents):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(contents, encoding="utf-8")

    def git(self, *arguments):
        return subprocess.check_output(["git", *arguments], cwd=self.root, text=True).strip()

    def test_clean_revision_accepts_ignored_build_but_rejects_dirty_source(self):
        self.git("init", "--quiet")
        self.write(".gitignore", "build/\n*.local.luau\n")
        self.write("src/Game.luau", "return 1\n")
        self.git("add", "--", ".gitignore", "src/Game.luau")
        self.git("-c", "user.name=Release fixture", "-c", "user.email=fixture@example.invalid",
                 "-c", "commit.gpgSign=false", "commit", "--quiet", "-m", "Fixture")
        self.write("build/game.rbxlx", "generated")
        self.assertEqual(release.clean_revision(self.root), {"commit": self.git("rev-parse", "HEAD"),
                                                            "tree": self.git("rev-parse", "HEAD^{tree}")})

        self.write("src/Extra.luau", "return 2\n")
        with self.assertRaisesRegex(RuntimeError, "clean Git checkout"):
            release.clean_revision(self.root)
        (self.root / "src/Extra.luau").unlink()
        self.write("src/Game.luau", "return 3\n")
        with self.assertRaisesRegex(RuntimeError, "clean Git checkout"):
            release.clean_revision(self.root)
        self.git("restore", "--", "src/Game.luau")
        self.write("src/Game.local.luau", "return 4\n")
        with self.assertRaisesRegex(RuntimeError, "Ignored files in Rojo runtime inputs"):
            release.clean_revision(self.root)

    def test_runtime_audit_excludes_test_fixtures_and_compares_both_builds(self):
        self.write("src/Game.luau", "return 1\n")
        sourcemap = {"children": [{"name": "ReplicatedStorage", "className": "ReplicatedStorage", "children": [
            {"name": "Game", "className": "ModuleScript", "filePaths": ["src/Game.luau"]},
            {"name": "Runner", "className": "ModuleScript", "filePaths": ["tests/Runner.luau"]},
        ]}]}
        script = ET.fromstring('<Item class="ModuleScript"><Properties><string name="Source">return 1\n'
                               '</string></Properties></Item>')
        name = "ReplicatedStorage/Game"
        artifact = {name: script}
        mapping = release.source_paths(sourcemap)
        self.assertEqual(mapping, {name: "src/Game.luau"})
        self.assertEqual(release.audit_runtime_sources(self.root, artifact, artifact, mapping), 1)

        altered = ET.fromstring('<Item class="ModuleScript"><Properties><string name="Source">return 2\n'
                                '</string></Properties></Item>')
        with self.assertRaisesRegex(RuntimeError, r"build/tests\.rbxlx script differs"):
            release.audit_runtime_sources(self.root, artifact, {name: altered}, mapping)
        with self.assertRaisesRegex(RuntimeError, r"build/game\.rbxlx script differs"):
            release.audit_runtime_sources(self.root, {name: altered}, artifact, mapping)
        with self.assertRaisesRegex(RuntimeError, "sourcemap/build mismatch"):
            release.audit_runtime_sources(self.root, {**artifact, "Extra": script}, artifact, mapping)

    def test_cloud_inventory_rejects_unrecorded_and_unused_references(self):
        self.write(release.MANIFEST, json.dumps({"schema_version": 1, "runtime_recipes": [
            {"creator_store_audio": [{"id": "30"}]},
        ]}))
        self.write(release.MESHES, json.dumps({"profiles": [{"mesh_id": "rbxassetid://5"}]}))
        self.write(release.TEXTURES, json.dumps({"materials": {"paint": {"asset_id": "23"}}}))
        asset = ET.fromstring('<Item class="MeshPart"><Properties><Content name="MeshContent">'
                              '<uri>rbxassetid://5</uri></Content></Properties></Item>')
        surface = ET.fromstring('<Item class="SurfaceAppearance"><Properties><Content name="ColorMap">'
                                '<url>rbxassetid://23</url></Content></Properties></Item>')
        script = ET.fromstring('<Item class="ModuleScript"><Properties><string name="Source">'
                               'return "rbxassetid://30"</string></Properties></Item>')
        artifact = {"Mesh": asset, "Mesh/Surface": surface, "Game": script}
        result = release.asset_inventory(self.root, artifact)
        self.assertEqual(result["mesh_ids"], ["5"])
        self.assertEqual(result["texture_ids"], ["23"])
        self.assertEqual(result["creator_store_audio_ids"], ["30"])
        self.assertFalse(result["destination_permissions_verified"])

        script.find("Properties/string").text = 'return "rbxassetid://31"'
        with self.assertRaisesRegex(RuntimeError, r"unexpected \['31'\], unused \['30'\]"):
            release.asset_inventory(self.root, artifact)


if __name__ == "__main__":
    unittest.main()
