"""Proof that Roblox batch names preserve the approved Blender primitives."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
MODULE = importlib.util.spec_from_file_location(
    "vesper_import", ROOT / "scripts/radar_outpost/prepare_import.py"
)
assert MODULE is not None and MODULE.loader is not None
IMPORT = importlib.util.module_from_spec(MODULE)
MODULE.loader.exec_module(IMPORT)


def raw_view(document, binary, index):
    view = document["bufferViews"][index]
    offset = view.get("byteOffset", 0)
    return binary[offset:offset + view["byteLength"]]


def accessor(document, binary, index):
    attributes = dict(document["accessors"][index])
    return attributes, raw_view(document, binary, attributes.pop("bufferView"))


class VesperImportTests(unittest.TestCase):
    def test_batch_bindings_preserve_geometry_transforms_and_materials(self):
        seen = set()
        expected = set()
        sources = {}
        for prefix, file_name in (("A", "vesper-array.glb"), ("D", "damage-library.glb")):
            source, source_bytes = IMPORT.decode_glb((IMPORT.EXPORT / file_name).read_bytes())
            sources[prefix] = source, source_bytes
            for node in source["nodes"]:
                for index in range(len(source["meshes"][node["mesh"]]["primitives"])):
                    expected.add((prefix, node["name"], index))
        with tempfile.TemporaryDirectory() as folder:
            directory = Path(folder)
            report = IMPORT.prepare(directory)
            for batch in report["batches"]:
                converted, converted_bytes = IMPORT.decode_glb((directory / batch["file"]).read_bytes())
                for node, item in zip(converted["nodes"], batch["objects"], strict=True):
                    _, prefix, object_index, material_index, _ = item["importName"].split("_", 4)
                    source, source_bytes = sources[prefix]
                    original = source["nodes"][int(object_index)]
                    ordinal = int(material_index) - 1
                    self.assertEqual(node["name"], item["importName"])
                    self.assertEqual(original["name"], item["sourceObject"])
                    self.assertEqual(original["extras"], item["sourceProperties"])
                    self.assertEqual(node.get("translation"), original.get("translation"))
                    self.assertEqual(node.get("rotation"), original.get("rotation"))
                    key = prefix, original["name"], ordinal
                    self.assertNotIn(key, seen)
                    seen.add(key)
                    original_primitive = source["meshes"][original["mesh"]]["primitives"][ordinal]
                    mesh = converted["meshes"][node["mesh"]]
                    self.assertEqual(len(mesh["primitives"]), 1)
                    primitive = mesh["primitives"][0]
                    self.assertEqual(primitive["attributes"].keys(), original_primitive["attributes"].keys())
                    for name, original_index in original_primitive["attributes"].items():
                        self.assertEqual(
                            accessor(source, source_bytes, original_index),
                            accessor(converted, converted_bytes, primitive["attributes"][name]),
                        )
                    self.assertEqual(
                        accessor(source, source_bytes, original_primitive["indices"]),
                        accessor(converted, converted_bytes, primitive["indices"]),
                    )
                    old_material = source["materials"][original_primitive["material"]]
                    new_material = converted["materials"][primitive["material"]]
                    self.assertEqual(old_material["name"], new_material["name"])
                    self.assertEqual(old_material["name"], item["material"])
                    old_pbr = old_material["pbrMetallicRoughness"]
                    new_pbr = new_material["pbrMetallicRoughness"]
                    self.assertEqual(
                        {k: v for k, v in old_pbr.items() if k != "baseColorTexture"},
                        {k: v for k, v in new_pbr.items() if k != "baseColorTexture"},
                    )
                    if "baseColorTexture" in old_pbr:
                        old_image = source["textures"][old_pbr["baseColorTexture"]["index"]]["source"]
                        new_image = converted["textures"][new_pbr["baseColorTexture"]["index"]]["source"]
                        self.assertEqual(
                            raw_view(source, source_bytes, source["images"][old_image]["bufferView"]),
                            raw_view(converted, converted_bytes, converted["images"][new_image]["bufferView"]),
                        )
            self.assertEqual(expected, seen)
            self.assertEqual([8, 585, 824], [b["expectedMeshParts"] for b in report["batches"]])
            pilot = report["batches"][0]["objects"]
            foundation = next(p for p in pilot if p["sourceObject"].startswith("Foundation"))
            self.assertEqual(foundation["localMinimum"][::2], [-32, -24])
            self.assertEqual(foundation["localMaximum"][::2], [32, 24])
            self.assertEqual(pilot[1]["pose"]["translation"][0], 8)
            self.assertGreater(pilot[1]["pose"]["translation"][2], 22)
