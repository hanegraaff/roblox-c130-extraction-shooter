"""Regression coverage for local release provenance and contamination guards."""

import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
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

    def test_clean_revision_allows_generated_dependencies_but_rejects_dirty_rojo_inputs(self):
        self.git("init", "--quiet")
        self.write(".gitignore", "build/\nPackages/\n__pycache__/\n*.local.luau\n")
        self.write("src/Game.luau", "return 1\n")
        self.write("tests/studio/server/Game.spec.luau", "return 1\n")
        self.write(release.RELEASE_PROJECT, json.dumps({"tree": {"Runtime": {"$path": "src"}}}))
        self.write(release.STUDIO_TEST_PROJECT, json.dumps({"tree": {"Server": {
            "Tests": {"$path": "tests/studio/server"}, "TestPackages": {"$path": "Packages"},
        }}}))
        self.git("add", "--", ".")
        self.git("-c", "user.name=Release fixture", "-c", "user.email=fixture@example.invalid",
                 "-c", "commit.gpgSign=false", "commit", "--quiet", "-m", "Fixture")
        self.write("build/game.rbxlx", "generated")
        self.write("Packages/TestEZ.lua", "generated")
        self.write("tests/tooling/__pycache__/fixture.pyc", "generated")
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
        for name in ("src/Game.local.luau", "tests/studio/server/Game.local.luau"):
            with self.subTest(name=name):
                self.write(name, "return 4\n")
                with self.assertRaisesRegex(RuntimeError, "Ignored files in authored Rojo inputs"):
                    release.clean_revision(self.root)
                (self.root / name).unlink()

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
        self.write(release.MANIFEST, json.dumps({"schema_version": 1, "assets": [], "runtime_recipes": [
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

        # Vesper extends the expected set through its native receipt. Extra
        # content in the release XML must still pass the exact-reference gate.
        self.write(release.VESPER_RECEIPT, json.dumps({"native": True}))
        imported = ET.fromstring('<Item class="MeshPart"><Properties><Content name="MeshContent">'
                                 '<uri>rbxassetid://7</uri></Content><Content name="TextureContent">'
                                 '<uri>rbxassetid://25</uri></Content></Properties></Item>')
        with patch.object(release, "vesper_assets", return_value=({"7"}, {"25"})) as vesper:
            extended = release.asset_inventory(self.root, {**artifact, "Vesper": imported})
            vesper.assert_called_once_with(self.root, {"native": True})
            self.assertEqual(extended["mesh_ids"], ["5", "7"])
            self.assertEqual(extended["texture_ids"], ["23", "25"])
            self.assertEqual(extended["vesper_native_receipt"]["path"], release.VESPER_RECEIPT)
            with self.assertRaisesRegex(RuntimeError, r"unused \['25', '7'\]"):
                release.asset_inventory(self.root, artifact)
        (self.root / release.VESPER_RECEIPT).unlink()

        for label, paths, receipt_path, key, counts, part_count in (
            ("Sandbreak", release.SANDBREAK_BANKS, release.SANDBREAK_RECEIPT,
             "sandbreak_native_receipt", {"managedMeshCount": 2}, 2),
            ("Prism Seedship", release.PRISM_BANKS, release.PRISM_RECEIPT,
             "prism_native_receipt", {"meshPartCount": 2972, "panelCount": 102}, 3074),
        ):
            with self.subTest(bank=label):
                fingerprints = {bank: "recorded" for bank in paths}
                self.write(receipt_path, json.dumps({"nativeModels": fingerprints, **counts}))
                with patch.object(release, "native_bank_assets", return_value=({"7"}, {"25"})) as bank_assets:
                    extended = release.asset_inventory(self.root, {**artifact, label: imported})
                    bank_assets.assert_called_once_with(self.root, label, paths, fingerprints, part_count)
                    self.assertEqual(extended["mesh_ids"], ["5", "7"])
                    self.assertEqual(extended["texture_ids"], ["23", "25"])
                    self.assertEqual(extended[key]["path"], receipt_path)
                (self.root / receipt_path).unlink()

        lobby_model, = release.LOBBY_BANKS
        lobby_receipt = {"archive": {"path": lobby_model, "sha256": "recorded"},
                         "roles": {"Room": 2392, "Bust": 34, "Portrait": 6}}
        self.write(lobby_model, "native model")
        self.write(release.LOBBY_RECEIPT, json.dumps(lobby_receipt))
        with patch.object(release, "native_bank_assets", return_value=({"7"}, {"25"})) as lobby:
            extended = release.asset_inventory(self.root, {**artifact, "Lobby": imported})
            lobby.assert_called_once_with(self.root, "Waiting lobby", release.LOBBY_BANKS,
                                          {lobby_model: "recorded"}, 2432)
            self.assertEqual(extended["mesh_ids"], ["5", "7"])
            self.assertEqual(extended["texture_ids"], ["23", "25"])
            self.assertEqual(extended["waiting_lobby_native_receipt"]["path"], release.LOBBY_RECEIPT)
            with self.assertRaisesRegex(RuntimeError, r"unused \['25', '7'\]"):
                release.asset_inventory(self.root, artifact)
        (self.root / lobby_model).unlink()

        script.find("Properties/string").text = 'return "rbxassetid://31"'
        with self.assertRaisesRegex(RuntimeError, r"unexpected \['31'\], unused \['30'\]"):
            release.asset_inventory(self.root, artifact)

    def test_vesper_inventory_rejects_changed_native_bank_before_building(self):
        for bank in release.VESPER_BANKS:
            self.write(bank, "authored native data")
        recorded = {bank: release.fingerprint(self.root, bank)["sha256"] for bank in release.VESPER_BANKS}
        self.write(release.VESPER_BANKS[0], "changed native data")
        with self.assertRaisesRegex(RuntimeError, "native banks differ from the import receipt"):
            release.vesper_assets(self.root, {"nativeModelsByPathAndSha256": recorded})

    def test_sandbreak_inventory_rejects_changed_native_bank_before_building(self):
        for bank in release.SANDBREAK_BANKS:
            self.write(bank, "authored native data")
        recorded = {bank: release.fingerprint(self.root, bank)["sha256"] for bank in release.SANDBREAK_BANKS}
        self.write(release.SANDBREAK_BANKS[0], "changed native data")
        with patch.object(release.subprocess, "run") as build:
            with self.assertRaisesRegex(RuntimeError, "Sandbreak native banks differ from the import receipt"):
                release.native_bank_assets(self.root, "Sandbreak", release.SANDBREAK_BANKS, recorded, 1)
            build.assert_not_called()


if __name__ == "__main__":
    unittest.main()
