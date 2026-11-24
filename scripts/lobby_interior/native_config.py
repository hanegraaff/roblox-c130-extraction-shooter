"""Describe expected native mesh bounds and texture slots from staged lobby GLBs."""

import argparse
import json
import struct

from stage_import import OUTPUT, decode_glb, digest, embedded_color
from salt_flats.prepare_import import rotate, vertex_rows


def row_for(doc, binary, node, record):
    """Compute the exact staged vertex envelope after applying the authored pose."""
    (surface,) = doc["meshes"][node["mesh"]]["primitives"]
    positions = surface["attributes"]["POSITION"]
    source_limits = doc["accessors"][positions]
    local_low, local_high = source_limits["min"], source_limits["max"]
    local_center = [(lo + hi) / 2 for lo, hi in zip(local_low, local_high)]
    local_center = rotate(local_center, node["rotation"])
    vertices = [rotate(struct.unpack("<3f", row), node["rotation"])
                for row in vertex_rows(doc, binary, positions)]
    limits = [(min(v[i] for v in vertices), max(v[i] for v in vertices)) for i in range(3)]
    pbr = doc["materials"][surface["material"]]["pbrMetallicRoughness"]
    color_slot = pbr.get("baseColorTexture")
    return {
        "name": record["managedName"],
        "sourceObject": record["sourceObject"],
        "role": record["role"],
        "material": record["material"],
        "triangles": record["triangles"],
        "center": [t + (lo + hi) / 2 for t, (lo, hi) in zip(node["translation"], limits)],
        "size": [hi - lo for lo, hi in limits],
        "orientedCenter": [t + v for t, v in zip(node["translation"], local_center)],
        "intrinsicSize": [hi - lo for lo, hi in zip(local_low, local_high)],
        "orientedBasis": [rotate(axis, node["rotation"]) for axis in ((1, 0, 0), (0, 1, 0), (0, 0, 1))],
        "linearColor": pbr.get("baseColorFactor", [1, 1, 1, 1]),
        "colorSha256": digest(embedded_color(doc, binary, surface["material"])) if color_slot else None,
        "portrait": record.get("painting", {}).get("portrait"),
    }


def configure(filename):
    """Return the documented source identity and all expected native rows for one GLB."""
    index_bytes = (OUTPUT / "import-index.json").read_bytes()
    index = json.loads(index_bytes)
    (batch,) = [entry for entry in index["batches"] if entry["file"] == filename]
    raw = (OUTPUT / filename).read_bytes()
    if digest(raw) != batch["sha256"]:
        raise ValueError(f"Staging bytes changed before binding {filename}")
    doc, binary = decode_glb(raw)
    rows = {}
    for node, record in zip(doc["nodes"], batch["objects"], strict=True):
        if node["name"] != record["importName"]:
            raise ValueError(f"Unexpected native key in {filename}")
        rows[node["name"]] = row_for(doc, binary, node, record)
    return {
        "file": filename,
        "sha256": batch["sha256"],
        "sourceSha256": index["assemblySha256"],
        "siteOrigin": index["siteOrigin"],
        "rows": rows,
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("file", help="Filename in the staged lobby import directory")
    settings = configure(parser.parse_args().file)
    print(json.dumps(settings, separators=(",", ":")))
