"""Prepare name-stable GLBs for the Roblox importer from the approved Vesper exports.

Each original material primitive becomes one named import object. Vertex data,
indices, UVs, normals, material properties and authored transforms are copied
verbatim. Repacking only changes glTF container indexes and object names. The
pilot contains a foundation and the offset south portal. Import the rest as
separate batches after checking native dimensions, transforms and textures.
"""
from __future__ import annotations

import argparse
from collections import Counter
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import re
import struct

ROOT = Path(__file__).resolve().parents[2]
EXPORT = ROOT / "assets/exports/radar-outpost"
SOURCE = ROOT / "assets/blender/radar-outpost"
MANIFEST = ROOT / "assets/manifest.json"
PILOT_OBJECTS = {"Foundation • 64 x 48", "Warehouse_S01_Radar_Wall_S3_Pristine"}
EXPORT_BATCHES = (("vesper-array.glb", "A"), ("damage-library.glb", "D"))
MAX_TRIANGLES = 20_000
MAX_BYTES = 20 * 1024 * 1024


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def source_bytes(path: Path, entries: dict[str, str]) -> bytes:
    """Verify the selected review package against the repository manifest."""
    data = path.read_bytes()
    if digest(data) != entries[path.relative_to(ROOT).as_posix()]:
        raise ValueError(f"Published review package hash changed: {path.name}")
    return data


def decode_glb(data: bytes) -> tuple[dict, bytes]:
    """Read the exact Blender GLB v2 JSON and single BIN chunks."""
    magic, version, total, extent, kind = struct.unpack_from("<4sIII4s", data)
    start = 20 + extent
    byte_count, binary_kind = struct.unpack_from("<I4s", data, start)
    if (magic, version, total, kind, binary_kind) != (b"glTF", 2, len(data), b"JSON", b"BIN\0"):
        raise ValueError("Expected glTF v2 with one JSON chunk and one binary chunk")
    if start + 8 + byte_count != total:
        raise ValueError("Invalid GLB binary extent")
    return json.loads(data[20:start]), data[start + 8:]


def encode_glb(document: dict, binary: bytes) -> bytes:
    document["buffers"] = [{"byteLength": len(binary)}]
    body = json.dumps(document, separators=(",", ":"), allow_nan=False).encode()
    body += b" " * (-len(body) % 4)
    binary += b"\0" * (-len(binary) % 4)
    return (struct.pack("<4sIII4s", b"glTF", 2, 28 + len(body) + len(binary), len(body), b"JSON")
            + body + struct.pack("<I4s", len(binary), b"BIN\0") + binary)


def import_name(prefix: str, index: int, ordinal: int, material: str) -> str:
    return f"VA_{prefix}_{index:03d}_{ordinal:02d}_{material}"


def thermal_structure_names() -> set[str]:
    """Identify render meshes paired with Vesper's mechanism or panel proxies."""
    structural_roles = {"visual", "stationary-mechanism", "mechanism", "reflector-visual"}
    names: set[str] = set()
    for filename, prefix in EXPORT_BATCHES:
        doc, _ = decode_glb((EXPORT / filename).read_bytes())
        for index, node in enumerate(doc["nodes"]):
            if node["extras"]["role"] not in structural_roles:
                continue
            for ordinal, surface in enumerate(doc["meshes"][node["mesh"]]["primitives"], 1):
                material = doc["materials"][surface["material"]]["name"]
                names.add(import_name(prefix, index, ordinal, material))
    return names


class Batch:
    """Store the exact dependency closure for one batch, with compact indexes."""

    def __init__(self, source: dict, binary: bytes, prefix: str):
        if len(source["scenes"]) != 1 or source["scenes"][0]["nodes"] != list(range(len(source["nodes"]))):
            raise ValueError("Vesper imports expect one scene of individually placed mesh objects")
        self.source = source
        self.binary = binary
        self.prefix = prefix
        self.records: list[dict] = []
        self.out: dict = {
            "asset": {"version": "2.0", "generator": "Vesper Array Roblox import preparation"},
            "scene": 0,
            "scenes": [{"nodes": []}],
            **{key: [] for key in ("nodes", "meshes", "materials", "accessors", "bufferViews",
                                   "images", "textures", "samplers")},
        }
        self.blob = bytearray()
        self.remapped: dict[tuple[str, int], int] = {}
        self.meshes: dict[tuple[int, int], int] = {}

    def dependency(self, key: str, index: int) -> int:
        """Copy a still-unseen accessor, material, texture or binary view."""
        identity = key, index
        if identity in self.remapped:
            return self.remapped[identity]
        item = deepcopy(self.source[key][index])
        if key == "bufferViews":
            offset = item.get("byteOffset", 0)
            length = item["byteLength"]
            assert item["buffer"] == 0 and 0 <= offset <= len(self.binary) - length
            self.blob.extend(b"\0" * (-len(self.blob) % 4))
            item["byteOffset"] = len(self.blob)
            self.blob.extend(self.binary[offset:offset + length])
        elif key in {"accessors", "images"}:
            assert "sparse" not in item and "uri" not in item
            item["bufferView"] = self.dependency("bufferViews", item["bufferView"])
        elif key == "textures":
            item["source"] = self.dependency("images", item["source"])
            if "sampler" in item:
                item["sampler"] = self.dependency("samplers", item["sampler"])
        elif key == "materials":
            for values in (item, item["pbrMetallicRoughness"]):
                for field, value in values.items():
                    if field.endswith("Texture"):
                        value["index"] = self.dependency("textures", value["index"])
        new_index = len(self.out[key])
        self.out[key].append(item)
        self.remapped[identity] = new_index
        return new_index

    def include(self, index: int) -> None:
        """Expand one original Blender object into importer names per material."""
        node = self.source["nodes"][index]
        assert set(node) <= {"extras", "mesh", "name", "rotation", "translation"}
        mesh = self.source["meshes"][node["mesh"]]
        for ordinal, original in enumerate(mesh["primitives"], 1):
            primitive = deepcopy(original)
            position = self.source["accessors"][original["attributes"]["POSITION"]]
            index_count = self.source["accessors"][original["indices"]]["count"]
            triangles, remainder = divmod(index_count, 3)
            if remainder or not 0 < triangles <= MAX_TRIANGLES or original.get("mode", 4) != 4:
                raise ValueError(f"Unsupported Roblox mesh at {node['name']}")
            material = self.source["materials"][original["material"]]["name"]
            name = import_name(self.prefix, index, ordinal, material)
            if not re.fullmatch(r"[A-Za-z0-9_]+", name):
                raise ValueError(f"Unsafe import key: {name}")
            key = node["mesh"], ordinal
            if key not in self.meshes:
                primitive["attributes"] = {
                    attr: self.dependency("accessors", value)
                    for attr, value in primitive["attributes"].items()
                }
                primitive["indices"] = self.dependency("accessors", primitive["indices"])
                primitive["material"] = self.dependency("materials", primitive["material"])
                self.meshes[key] = len(self.out["meshes"])
                self.out["meshes"].append({"primitives": [primitive], "name": name})
            pose = {axis: node[axis] for axis in ("translation", "rotation") if axis in node}
            self.out["scenes"][0]["nodes"].append(len(self.out["nodes"]))
            self.out["nodes"].append({"name": name, "mesh": self.meshes[key], **pose})
            self.records.append({
                "importName": name,
                "meshName": self.out["meshes"][self.meshes[key]]["name"],
                "sourceObject": node["name"],
                "sourceProperties": node["extras"],
                "material": material,
                "localMinimum": position["min"],
                "localMaximum": position["max"],
                "triangles": triangles,
                "pose": pose,
            })

    def write(self, directory: Path, filename: str, source_hash: str) -> dict:
        if not self.records:
            raise ValueError(f"Empty import batch: {filename}")
        extensions = {ext for item in self.out["materials"] for ext in item.get("extensions", {})}
        if extensions:
            self.out["extensionsUsed"] = sorted(extensions)
        data = encode_glb(self.out, bytes(self.blob))
        if len(data) >= MAX_BYTES:
            raise ValueError(f"Import batch exceeds the MCP upload limit: {filename}")
        (directory / filename).write_bytes(data)
        return {
            "file": filename,
            "sha256": digest(data),
            "sourceSha256": source_hash,
            "bytes": len(data),
            "expectedMeshParts": len(self.records),
            "materialUses": Counter(record["material"] for record in self.records),
            "objects": self.records,
        }


def prepare(directory: Path) -> dict:
    """Write a pilot, assembly remainder and damage bank with stable IDs."""
    entries = {item["local_path"]: item.get("sha256")
               for item in json.loads(MANIFEST.read_text())["assets"]}
    source = source_bytes(SOURCE / "vesper-array.blend", entries)
    catalog = source_bytes(SOURCE / "panel-catalog.json", entries)
    directory.mkdir(parents=True, exist_ok=True)
    batches = []
    for filename, prefix in EXPORT_BATCHES:
        data = source_bytes(EXPORT / filename, entries)
        doc, blob = decode_glb(data)
        batches_to_write = {"vesper-damage.glb": Batch(doc, blob, prefix)} if prefix == "D" else {
            "vesper-pilot.glb": Batch(doc, blob, prefix),
            "vesper-assembly.glb": Batch(doc, blob, prefix),
        }
        for index, node in enumerate(doc["nodes"]):
            destination = ("vesper-damage.glb" if prefix == "D" else
                           "vesper-pilot.glb" if node["name"] in PILOT_OBJECTS else "vesper-assembly.glb")
            batches_to_write[destination].include(index)
        batches.extend(batch.write(directory, name, digest(data)) for name, batch in batches_to_write.items())
    if {record["sourceObject"] for record in batches[0]["objects"]} != PILOT_OBJECTS:
        raise ValueError("Missing foundation or asymmetric gateway in pilot")
    materials = {}
    for item in batches:
        doc, binary = decode_glb((directory / item["file"]).read_bytes())
        for material in doc["materials"]:
            pbr = material["pbrMetallicRoughness"]
            reference = pbr.get("baseColorTexture")
            if reference:
                texture = doc["textures"][reference["index"]]
                view = doc["bufferViews"][doc["images"][texture["source"]]["bufferView"]]
                start = view["byteOffset"]
                png = binary[start:start + view["byteLength"]]
                assert png.startswith(b"\x89PNG\r\n\x1a\n")
                (directory / (material["name"] + ".png")).write_bytes(png)
                materials[material["name"]] = {"colorMapSha256": digest(png)}
            else:
                materials[material["name"]] = {"linearBaseColor": pbr["baseColorFactor"]}
    report = {
        "version": 1,
        "blenderSha256": digest(source),
        "panelCatalogSha256": digest(catalog),
        "units": "one glTF unit per stud, Y up",
        "alignmentLandmark": "South portal center is +8 studs east of the Y-up origin and faces +Z.",
        "batches": batches,
        "materials": materials,
    }
    (directory / "import-index.json").write_text(json.dumps(report, indent=2) + "\n")
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, default=ROOT / "build/vesper-import")
    args = parser.parse_args()
    report = prepare(args.output_dir)
    for batch in report["batches"]:
        print(f'{batch["file"]}: {batch["expectedMeshParts"]} mesh parts expected, {batch["bytes"]:,} bytes')


if __name__ == "__main__":
    main()
