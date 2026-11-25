"""Preserve genuine engine mesh intrinsics/collision payloads without guessing.

The private capture is an unparented AssetService factory result serialized by
Roblox, with public per-profile values verified after native deserialization.
Pinned Lune only decodes that local RBXM. InitialSize and opaque payload bytes
are copied into Rojo JSON; neither normalized Size nor source format units can
substitute for them. Ordinary runtime code checks public MeshSize/fidelities.
"""
from __future__ import annotations

import base64
import json
import math
import os
from pathlib import Path
import re
import subprocess
import struct
import tempfile
import xml.etree.ElementTree as ET

from p17_assets import ROOT, sha

IMPORTS = Path("assets/imports/military-outpost")
BANK_PATH = IMPORTS / "native-mesh-profiles-v1.rbxm"
RECEIPT_PATH = IMPORTS / "native-mesh-profiles-v1.json"
REQUEST_PATH = IMPORTS / "native-mesh-requests-v1.json"
PAYLOAD_FIELDS = {"PhysicalConfigData": "SharedString", "PhysicsData": "BinaryString", "AeroMeshData": "SharedString"}


def profile_key(mesh_id: str, collision: str, render: str) -> tuple[str, str, str]:
    """Native factory policy is explicit; one ID could have multiple profiles."""
    if not isinstance(mesh_id, str) or not re.fullmatch(r"rbxassetid://[1-9][0-9]*", mesh_id):
        raise ValueError("invalid native profile MeshId")
    if collision not in ("Box", "PreciseConvexDecomposition") or render != "Automatic":
        raise ValueError("unexpected native mesh factory policy")
    return mesh_id, collision, render


def decode_payload(value: str | None) -> bytes:
    """Canonicalize XML formatting whitespace, never reinterpret opaque bytes."""
    try:
        return base64.b64decode("".join((value or "").split()), validate=True)
    except ValueError as error:
        raise ValueError("malformed serialized native mesh payload") from error


def float32_vector(values) -> list[float]:
    """Canonicalize native Vector3 storage, including XML's short decimal form."""
    if not isinstance(values, (list, tuple)) or len(values) != 3:
        raise ValueError("invalid native mesh Vector3")
    try:
        result = [struct.unpack("<f", struct.pack("<f", value))[0] for value in values]
    except (struct.error, OverflowError, TypeError) as error:
        raise ValueError("invalid native mesh Vector3") from error
    if not all(math.isfinite(value) and value > 0 for value in result):
        raise ValueError("missing/nonpositive native mesh intrinsics")
    return result


def native_records(xml: ET.Element) -> dict[str, dict]:
    """Extract only genuine serialized native mesh fields from a single root."""
    shared = {item.attrib["md5"]: decode_payload(item.text) for item in xml.findall("SharedStrings/SharedString")}
    roots = xml.findall("Item")
    if len(roots) != 1 or roots[0].get("class") != "Folder":
        raise ValueError("native mesh capture requires one Folder root")
    records = {}
    for item in roots[0].findall("Item"):
        if item.get("class") != "MeshPart" or item.findall("Item"):
            raise ValueError("native mesh capture contains unintended content")
        props = item.find("Properties")
        name = props.findtext("string[@name='Name']")
        mesh_id = props.findtext("Content[@name='MeshContent']/uri")
        initial = props.find("Vector3[@name='InitialSize']")
        if not isinstance(name, str) or not re.fullmatch(r"Mesh[1-9][0-9]*", name) or mesh_id != "rbxassetid://" + name[4:] or name in records or initial is None:
            raise ValueError("missing/duplicate native mesh identity/intrinsics")
        size = float32_vector([float(initial.findtext(axis, "nan")) for axis in "XYZ"])
        fields = {"InitialSize": size}
        for field, kind in PAYLOAD_FIELDS.items():
            node = props.find(f"{kind}[@name='{field}']")
            if node is None:
                raise ValueError("missing genuine native mesh payload: " + field)
            if kind == "SharedString":
                if node.text not in shared:
                    raise ValueError("missing native mesh shared payload")
                data = shared[node.text]
            else:
                data = decode_payload(node.text)
            if field == "PhysicalConfigData" and not data:
                raise ValueError("missing native collision configuration")
            fields[field] = {kind: base64.b64encode(data).decode("ascii")}
        records[name] = dict(mesh_id=mesh_id, fields=fields)
    return records


def load_profiles(root: Path = ROOT) -> dict[tuple[str, str, str], dict]:
    """Require exact request/public-receipt/native-byte agreement before compile.

    This local host operation yields while pinned Lune decodes the native bank;
    it does not load cloud content or assert native rendering/physics acceptance.
    """
    receipt = json.loads((root / RECEIPT_PATH).read_text())
    requests = json.loads((root / REQUEST_PATH).read_text())
    if receipt.get("schema_version") != 1 or receipt.get("request_sha256") != sha(root / REQUEST_PATH) or receipt.get("native_rbxm_sha256") != sha(root / BANK_PATH):
        raise ValueError("native mesh receipt/request/bank hash mismatch")
    if receipt.get("native_roundtrip_profiles") != 407 or receipt.get("native_bytes") != (root / BANK_PATH).stat().st_size:
        raise ValueError("native mesh capture lacks complete engine roundtrip receipt")
    expected = {}
    for request in requests:
        key = profile_key(request["mesh_id"], request["collision_fidelity"], request["render_fidelity"])
        if key in expected or type(request.get("uses")) is not int or request["uses"] < 1:
            raise ValueError("duplicate/invalid native mesh request")
        expected[key] = request["uses"]
    if len(expected) != 407 or sum(expected.values()) != 2332:
        raise ValueError("native profile requests differ from complete approved import")
    records = native_records(decode_bank(root / BANK_PATH))
    result = {}
    for profile in receipt.get("profiles", []):
        key = profile_key(profile["mesh_id"], profile["collision_fidelity"], profile["render_fidelity"])
        record = records.get(profile["name"])
        if key in result or key not in expected or not record or record["mesh_id"] != key[0]:
            raise ValueError("missing/duplicate/mismatched native mesh profile")
        if profile["name"] != "Mesh" + key[0][13:]:
            raise ValueError("native mesh profile name differs from exact asset identity")
        if (profile.get("requested_collision_fidelity"), profile.get("requested_render_fidelity")) != key[1:]:
            raise ValueError("native mesh factory did not retain requested fidelity")
        if float32_vector(profile.get("mesh_size")) != record["fields"]["InitialSize"]:
            raise ValueError("native serialized intrinsics differ from public MeshSize receipt")
        if float32_vector(profile.get("size")) != record["fields"]["InitialSize"]:
            raise ValueError("native factory profile was scaled before capture")
        result[key] = dict(record["fields"], mesh_id=key[0], collision_fidelity=key[1], render_fidelity=key[2], uses=expected[key])
    if len(result) != len(expected) or len(records) != len(expected):
        raise ValueError("incomplete native mesh capture")
    return result


def decode_bank(path: Path) -> ET.Element:
    """Decode genuine local bytes with the pinned host tool, retaining all fields."""
    environment = dict(os.environ, PATH=str(Path.home() / ".rokit/bin") + os.pathsep + os.environ.get("PATH", ""))
    with tempfile.TemporaryDirectory(prefix="p17-native-mesh-") as directory:
        target = Path(directory) / "native.rbxmx"
        try:
            subprocess.run(["lune", "run", str(ROOT / "scripts/p17_native_mesh_xml.luau"), str(path), str(target)], env=environment, check=True, capture_output=True, text=True)
        except subprocess.CalledProcessError as error:
            raise ValueError("pinned Lune rejected native mesh bank: " + error.stderr.strip()) from error
        return ET.parse(target).getroot()
