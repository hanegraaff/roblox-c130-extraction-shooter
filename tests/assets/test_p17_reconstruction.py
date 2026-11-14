"""P17 A1 source reconstruction/provenance; actual engine acceptance is separate."""
import copy
import importlib.util
import json
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

SCRIPTS = Path(__file__).resolve().parents[2] / "scripts"
sys.path.insert(0, str(SCRIPTS))
SPEC = importlib.util.spec_from_file_location("p17_compile_outpost", SCRIPTS / "p17_compile_outpost.py")
compiler = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(compiler)


class P17OutpostReconstruction(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.outputs = compiler.managed_outputs()
        cls.outpost = cls.outputs[Path("assets/models/MilitaryOutpost.model.json")]

    def test_complete_actual_import_models_reconstruct_without_claiming_native_acceptance(self):
        result = compiler.verify()
        self.assertEqual(result["panels"], 26)
        self.assertEqual(result["total_runtime_panels"], 188)
        self.assertFalse(result["native_acceptance_verified"])
        self.assertEqual(len(list(compiler.iter_class(self.outpost, "MeshPart"))), 2256)

    def test_all_legacy_identity_pivots_remain_exact_with_explicit_material_bases(self):
        catalog = compiler.approved_catalog()
        panels = next(child for child in self.outpost["Children"] if child["Name"] == "Outpost_Panels")
        by_name = {panel["Name"]: panel for panel in panels["Children"]}
        self.assertEqual(len(by_name), 26)
        for source in catalog["identity_migration"]["mapping"]:
            model = by_name[source["panel_id"]]
            pivot = model["Properties"]["WorldPivotData"]["OptionalCFrame"]
            if "legacy_pivot_roblox" in source:
                self.assertEqual([pivot["position"][axis]+compiler.SITE[axis] for axis in range(3)], source["legacy_pivot_roblox"][:3])
                self.assertEqual(sum(pivot["orientation"], []), source["legacy_pivot_roblox"][3:])
                self.assertEqual(model["Properties"]["Attributes"]["IntactSize"]["Vector3"], source["legacy_size_roblox"])

    def test_cosmetic_depth_policy_never_hides_panel_visuals_or_solid_cover(self):
        classes = set()
        for mesh in compiler.iter_class(self.outpost, "MeshPart"):
            props = mesh["Properties"]
            attrs = props["Attributes"]
            classification = attrs.get("ConstructionClass", {}).get("String")
            classes.add(classification)
            hidden = attrs.get("ThermalNonCover", {}).get("Bool", False)
            self.assertEqual(props["Color"], [1,1,1], "raw gray tint persisted")
            self.assertTrue(mesh["Children"][0]["Properties"]["ColorMap"].startswith("rbxassetid://"))
            if classification in ("CosmeticProp", "PanelAttachment"):
                self.assertTrue(hidden)
                self.assertFalse(props["CanCollide"] or props["CanQuery"])
            else:
                self.assertFalse(hidden)
        self.assertTrue({"CosmeticProp", "PanelAttachment", "StableStructure", "SolidPropCover"}.issubset(classes))

    def test_missing_or_wrong_source_texture_cannot_fall_back_to_gray(self):
        textures = json.loads((compiler.ROOT / compiler.IMPORTS / "material-textures-v2.json").read_text())
        for change in ("missing", "hash", "reference"):
            value = copy.deepcopy(textures)
            if change == "missing": value["materials"].pop("teal")
            elif change == "hash": value["materials"]["teal"]["source_png_sha256"] = "0"*64
            else: value["materials"]["teal"]["color_map"] = ""
            with self.assertRaises(ValueError): compiler.material_maps(value)

    def test_managed_unintended_script_or_geometry_edits_fail_reconstruction_gate(self):
        read = Path.read_text
        target = compiler.ROOT / "assets/models/MilitaryOutpost.model.json"
        def changed(path, *args, **kwargs):
            text = read(path, *args, **kwargs)
            if path == target:
                model = json.loads(text)
                model["Children"].append(dict(ClassName="Script", Name="UnintendedImportedCode"))
                return json.dumps(model)
            return text
        with patch.object(Path, "read_text", changed):
            with self.assertRaisesRegex(ValueError, "differs from actual approved import"):
                compiler.verify()


if __name__ == "__main__":
    unittest.main()
