"""P17 A1 source reconstruction/provenance; actual engine acceptance is separate."""
import copy
import builtins
import importlib.util
import json
import math
import base64
import struct
import xml.etree.ElementTree as ET
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

SCRIPTS = Path(__file__).resolve().parents[2] / "scripts"
sys.path.insert(0, str(SCRIPTS))
SPEC = importlib.util.spec_from_file_location("p17_compile_outpost", SCRIPTS / "p17_compile_outpost.py")
compiler = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(compiler)
import p17_normalize as normalizer
import inspect_build as artifact


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

    def test_exact_generation_survives_builtin_float_summation_algorithm_changes(self):
        """Exercise the real receipts under pre/post-3.12 float-sum semantics."""
        original_sum = builtins.sum
        def compensated_sum(values, start=0):
            items = list(values)
            if isinstance(start, float) or any(isinstance(item, float) for item in items):
                return math.fsum([start] + items)
            return original_sum(items, start)
        before = compiler.managed_outputs()
        with patch.object(normalizer, "sum", compensated_sum, create=True), patch.object(compiler, "sum", compensated_sum, create=True):
            after = compiler.managed_outputs()
        for path in before:
            self.assertEqual(json.dumps(before[path], separators=(",", ":"), allow_nan=False),
                             json.dumps(after[path], separators=(",", ":"), allow_nan=False), path.as_posix())

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
        visible_details = set()
        hidden_details = set()
        for mesh in compiler.iter_class(self.outpost, "MeshPart"):
            props = mesh["Properties"]
            attrs = props["Attributes"]
            classification = attrs.get("ConstructionClass", {}).get("String")
            classes.add(classification)
            hidden = attrs.get("ThermalNonCover", {}).get("Bool", False)
            self.assertEqual(props["Color"], [1,1,1], "raw gray tint persisted")
            self.assertTrue(mesh["Children"][0]["Properties"]["ColorMap"].startswith("rbxassetid://"))
            if classification in ("CosmeticProp", "PanelAttachment"):
                self.assertFalse(props["CanCollide"] or props["CanQuery"])
            if classification == "PanelAttachment":
                name = attrs["SourceObject"]["String"]
                (hidden_details if hidden else visible_details).add(name)
                self.assertTrue(attrs["AttachmentPanelId"]["String"])
            elif classification == "CosmeticProp":
                self.assertTrue(hidden)
            else:
                self.assertFalse(hidden)
        self.assertTrue({"CosmeticProp", "PanelAttachment", "StableStructure", "SolidPropCover"}.issubset(classes))
        self.assertTrue({"Satellite dish", "Antenna panel", "Downpipe", "Garage track"}.issubset(visible_details))
        self.assertTrue({"Front window mullion", "Roof conduit", "Electrical switchboard"}.issubset(hidden_details))

    def test_readable_metadata_matches_actual_serialized_surface_maps_and_rejects_slot_drift(self):
        surface = next(compiler.iter_class(self.outpost, "SurfaceAppearance"))
        properties = surface["Properties"]
        metadata = properties["Attributes"]
        encoded = bytearray(struct.pack("<I", len(metadata)))
        def string(value):
            data = value.encode()
            return struct.pack("<I", len(data))+data
        for key, typed in metadata.items():
            encoded.extend(string(key))
            if "String" in typed: encoded.extend(b"\x02"+string(typed["String"]))
            else: encoded.extend(b"\x06"+struct.pack("<d", typed["Float64"]))
        node = ET.Element("Item", {"class":"SurfaceAppearance"})
        props = ET.SubElement(node, "Properties")
        ET.SubElement(props,"BinaryString",{"name":"AttributesSerialize"}).text=base64.b64encode(encoded).decode()
        for key in ("ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap"):
            field=ET.SubElement(props,"Content",{"name":key+"Content"})
            ET.SubElement(field,"uri" if properties[key] else "null").text=properties[key] or None
            self.assertEqual(metadata["Compiled"+key]["String"],properties[key])
        artifact.check_surface_material(node,surface,"SourceBoundMaterialFixture")
        node.find("Properties/Content[@name='ColorMapContent']/uri").text="rbxassetid://1"
        with self.assertRaisesRegex(RuntimeError,"texture/metadata reconstruction mismatch"):
            artifact.check_surface_material(node,surface,"DriftedProtectedSlot")
        node.find("Properties/Content[@name='ColorMapContent']/uri").text=properties["ColorMap"]
        node.find("Properties/BinaryString[@name='AttributesSerialize']").text=""
        with self.assertRaisesRegex(RuntimeError,"serialized compiled material metadata"):
            artifact.check_surface_material(node,surface,"MissingSerializedMetadata")

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
