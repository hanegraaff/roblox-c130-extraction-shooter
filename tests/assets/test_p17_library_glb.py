"""P17 format-repair proof: decoded GLB must retain approved faces/UVs/textures."""
import copy
import importlib.util
import json
from pathlib import Path
import struct
import sys
import unittest

SCRIPTS = Path(__file__).resolve().parents[2] / "scripts"
sys.path.insert(0, str(SCRIPTS))
SPEC = importlib.util.spec_from_file_location("p17_library_glb", SCRIPTS / "p17_library_glb.py")
glb = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(glb)


def repack(document, binary):
    encoded = json.dumps(document, separators=(",", ":")).encode()
    encoded += b" " * (-len(encoded) % 4)
    return (struct.pack("<III", 0x46546C67, 2, 28 + len(encoded) + len(binary))
            + struct.pack("<II", len(encoded), 0x4E4F534A) + encoded
            + struct.pack("<II", len(binary), 0x004E4942) + binary)


class P17MaterialDerivative(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = (glb.ROOT / glb.GLB_PATH).read_bytes()
        cls.document, cls.binary = glb.decode_glb(cls.data)

    def test_complete_managed_derivative_is_deterministic_and_equivalent(self):
        result = glb.verify()
        self.assertEqual(result["primitives"], 76)
        self.assertEqual(result["triangles"], 34144)
        self.assertEqual(result["empty_total_sources"], 6)
        self.assertEqual(result["embedded_textures"], 12)
        self.assertFalse(result["roblox_import_verified"])
        self.assertTrue(result["positions_uvs_materials_textures_equivalent"])

    def test_changed_triangle_position_or_uv_rejects_actual_glb_bytes(self):
        primitive = self.document["meshes"][0]["primitives"][0]
        for attribute in ("POSITION", "TEXCOORD_0"):
            accessor = self.document["accessors"][primitive["attributes"][attribute]]
            view = self.document["bufferViews"][accessor["bufferView"]]
            offset = view["byteOffset"] + accessor.get("byteOffset", 0)
            binary = bytearray(self.binary)
            previous = struct.unpack_from("<f", binary, offset)[0]
            struct.pack_into("<f", binary, offset, previous + 0.125)
            with self.assertRaisesRegex(ValueError, "triangle position/winding|corner UV"):
                glb.audit_geometry(repack(self.document, binary))

    def test_changed_embedded_png_rejects_even_if_container_is_valid(self):
        view = self.document["bufferViews"][self.document["images"][0]["bufferView"]]
        binary = bytearray(self.binary)
        binary[view["byteOffset"] + view["byteLength"] // 2] ^= 1
        with self.assertRaisesRegex(ValueError, "PNG differs"):
            glb.audit_geometry(repack(self.document, binary))

    def test_duplicate_or_missing_source_material_node_rejects(self):
        duplicate = copy.deepcopy(self.document)
        duplicate["nodes"][1]["name"] = duplicate["nodes"][0]["name"]
        with self.assertRaisesRegex(ValueError, "duplicate"):
            glb.audit_geometry(repack(duplicate, self.binary))
        missing = copy.deepcopy(self.document)
        missing["nodes"].pop()
        missing["scenes"][0]["nodes"].pop()
        with self.assertRaisesRegex(ValueError, "missing derivative"):
            glb.audit_geometry(repack(missing, self.binary))
        hidden = copy.deepcopy(self.document)
        hidden["scenes"][0]["nodes"].pop()
        with self.assertRaisesRegex(ValueError, "active scene"):
            glb.audit_geometry(repack(hidden, self.binary))

    def test_wrong_material_or_accessor_bounds_rejects(self):
        material = copy.deepcopy(self.document)
        material["materials"][0]["pbrMetallicRoughness"]["roughnessFactor"] = 0
        with self.assertRaisesRegex(ValueError, "PBR material"):
            glb.audit_geometry(repack(material, self.binary))
        bounds = copy.deepcopy(self.document)
        bounds["accessors"][0]["count"] = 2 ** 30
        with self.assertRaisesRegex(ValueError, "accessor range"):
            glb.audit_geometry(repack(bounds, self.binary))


if __name__ == "__main__":
    unittest.main()
