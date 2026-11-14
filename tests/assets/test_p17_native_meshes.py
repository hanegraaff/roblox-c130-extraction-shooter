"""P17 A1/A2: preserve genuine native intrinsics and collision bytes in Git.

Host checks prove deterministic reconstruction/rejection, not engine rendering,
contacts or replication. Ordinary server/client specs cover public properties;
native render and physical acceptance remain separate required observations.
"""
import base64
import copy
import json
from pathlib import Path
import struct
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts"))
import inspect_build as artifact
import p17_compile_outpost as compiler
import p17_native_meshes as native


def encoded_attributes(attributes):
    """Serialize test metadata independently into the actual engine wire shape."""
    def string(value):
        data = value.encode("utf-8")
        return struct.pack("<I", len(data)) + data
    data = bytearray(struct.pack("<I", len(attributes)))
    for key, typed in attributes.items():
        data.extend(string(key))
        kind, value = next(iter(typed.items()))
        if kind == "String": data.extend(b"\x02" + string(value))
        elif kind == "Bool": data.extend(b"\x03" + struct.pack("<?", value))
        elif kind == "Float64": data.extend(b"\x06" + struct.pack("<d", value))
        elif kind == "Vector3": data.extend(b"\x11" + struct.pack("<fff", *value))
        else: raise AssertionError("unexpected fixture attribute")
    return base64.b64encode(data).decode("ascii")


class P17NativeMeshReconstruction(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.xml = native.decode_bank(compiler.ROOT / native.BANK_PATH)
        cls.records = native.native_records(cls.xml)
        cls.profiles = native.load_profiles()
        cls.outputs = compiler.managed_outputs()
        outpost = cls.outputs[Path("assets/models/MilitaryOutpost.model.json")]
        cls.floor = next(mesh for mesh in compiler.iter_class(outpost, "MeshPart") if mesh["Name"] == "Outpost_GroundFloor")

    def test_all_real_profiles_and_2332_uses_keep_intrinsics_independent_of_normalized_target_size(self):
        self.assertEqual(len(self.profiles), 407)
        self.assertEqual(sum(profile["uses"] for profile in self.profiles.values()), 2332)
        self.assertEqual(sum(key[1] == "PreciseConvexDecomposition" for key in self.profiles), 87)
        count = 0
        for path, model in self.outputs.items():
            if path.suffix != ".json" or not path.name.endswith(".model.json"): continue
            for mesh in compiler.iter_class(model, "MeshPart"):
                count += 1
                props = mesh["Properties"]
                profile = self.profiles[(props["MeshId"], props["CollisionFidelity"], props["RenderFidelity"])]
                for field in ("InitialSize", *native.PAYLOAD_FIELDS): self.assertEqual(props[field], profile[field])
                self.assertEqual(props["Attributes"]["NativeMeshSize"]["Vector3"], profile["InitialSize"])
        self.assertEqual(count, 2332)
        floor = self.floor["Properties"]
        self.assertGreater(floor["InitialSize"][2] / floor["Size"][2], 42)
        for actual, expected in zip(floor["Size"], (32, 1, 48)):
            self.assertAlmostEqual(actual, expected, delta=0.0001)

    def test_missing_zero_or_unintended_native_bank_fields_reject(self):
        for change in ("initial", "zero", "physical", "unexpected-child", "duplicate"):
            xml = copy.deepcopy(self.xml)
            root = xml.find("Item")
            mesh = root.find("Item")
            props = mesh.find("Properties")
            if change == "initial": props.remove(props.find("Vector3[@name='InitialSize']"))
            elif change == "zero": props.find("Vector3[@name='InitialSize']/X").text = "0"
            elif change == "physical": props.remove(props.find("SharedString[@name='PhysicalConfigData']"))
            elif change == "unexpected-child": mesh.set("class", "Script")
            else: root.append(copy.deepcopy(mesh))
            with self.subTest(change=change), self.assertRaises(ValueError): native.native_records(xml)

    def test_capture_hash_public_intrinsics_requested_policy_and_roundtrip_cannot_drift(self):
        path = compiler.ROOT / native.RECEIPT_PATH
        original = json.loads(path.read_text())
        read = Path.read_text
        for change in ("bank-hash", "request-hash", "intrinsic", "profile", "roundtrip"):
            receipt = copy.deepcopy(original)
            if change == "bank-hash": receipt["native_rbxm_sha256"] = "0" * 64
            elif change == "request-hash": receipt["request_sha256"] = "0" * 64
            elif change == "intrinsic": receipt["profiles"][0]["mesh_size"][0] *= 2
            elif change == "profile": receipt["profiles"][0]["requested_collision_fidelity"] = "PreciseConvexDecomposition"
            else: receipt["native_roundtrip_profiles"] = 406
            def altered(target, *args, **kwargs):
                return json.dumps(receipt) if target == path else read(target, *args, **kwargs)
            with self.subTest(change=change), patch.object(Path, "read_text", altered), self.assertRaises(ValueError):
                native.load_profiles()

    def test_compiler_rejects_missing_native_profile_wrong_fidelity_or_unused_capture(self):
        properties = self.floor["Properties"]
        key = (properties["MeshId"], properties["CollisionFidelity"], properties["RenderFidelity"])
        baseline = {key: copy.deepcopy(self.profiles[key])}
        baseline[key]["uses"] = 1
        compiler.bind_native_geometry([copy.deepcopy(self.floor)], baseline)
        for change in ("missing", "fidelity", "unused"):
            model = copy.deepcopy(self.floor)
            profiles = copy.deepcopy(baseline)
            props = model["Properties"]
            if change == "missing": profiles.pop(key)
            elif change == "fidelity": props["CollisionFidelity"] = "Box"
            else:
                unused = next(other for other in self.profiles if other != key)
                profiles[unused] = copy.deepcopy(self.profiles[unused])
                profiles[unused]["uses"] = 1
            reason = "native profile coverage differs" if change == "unused" else "missing actual native constructor profile"
            with self.subTest(change=change), self.assertRaisesRegex(ValueError, reason):
                compiler.bind_native_geometry([model], profiles)

    def test_actual_artifact_gate_rejects_missing_intrinsics_payload_bytes_and_readable_metadata_drift(self):
        shared = {node.attrib["md5"]: native.decode_payload(node.text) for node in self.xml.findall("SharedStrings/SharedString")}
        source = self.floor
        expected = source["Properties"]
        raw = next(node for node in self.xml.find("Item").findall("Item") if node.findtext("Properties/Content[@name='MeshContent']/uri") == expected["MeshId"])
        baseline = copy.deepcopy(raw)
        attrs = baseline.find("Properties/BinaryString[@name='AttributesSerialize']")
        attrs.text = encoded_attributes(expected["Attributes"])
        artifact.check_native_mesh(baseline, source, shared, "GenuineNativePayload")
        for change in ("initial", "zero", "physical", "bytes", "metadata"):
            item = copy.deepcopy(baseline)
            props = item.find("Properties")
            if change == "initial": props.remove(props.find("Vector3[@name='InitialSize']"))
            elif change == "zero": props.find("Vector3[@name='InitialSize']/Z").text = "0"
            elif change == "physical": props.remove(props.find("SharedString[@name='PhysicalConfigData']"))
            elif change == "bytes":
                node = props.find("SharedString[@name='PhysicalConfigData']")
                node.text = next(key for key in shared if shared[key] != shared[node.text])
            else:
                metadata = copy.deepcopy(expected["Attributes"])
                metadata["NativeMeshSize"] = {"Vector3": [1, 1, 1]}
                props.find("BinaryString[@name='AttributesSerialize']").text = encoded_attributes(metadata)
            with self.subTest(change=change), self.assertRaises(RuntimeError):
                artifact.check_native_mesh(item, source, shared, "DamagedNativePayload")


if __name__ == "__main__": unittest.main()
