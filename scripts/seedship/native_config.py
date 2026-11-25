"""Derive Studio capture metadata from staged Seedship GLBs and approved asset IDs."""
import json
import struct

from prepare_import import ART, OUTPUT, decode_glb, digest
from salt_flats.prepare_import import rotate, vertex_rows


def capture_rows(batch, model):
    path = OUTPUT / batch["file"]
    data = path.read_bytes()
    if digest(data) != batch["sha256"]:
        raise ValueError(f"Staged bytes changed after approval: {path.name}")
    doc, binary = decode_glb(data)
    rows = {}
    for node, record in zip(doc["nodes"], batch["objects"], strict=True):
        surface = doc["meshes"][node["mesh"]]["primitives"][0]
        material = doc["materials"][surface["material"]]
        pbr = material["pbrMetallicRoughness"]
        props = record["sourceProperties"]
        vertices = [rotate(struct.unpack("<3f", point), node["rotation"])
                    for point in vertex_rows(doc, binary, surface["attributes"]["POSITION"])]
        bounds = [(min(v[i] for v in vertices), max(v[i] for v in vertices)) for i in range(3)]
        rows[record["importName"]] = [
            record["sourceObject"], record["role"], props.get("PanelId", ""), props.get("Appearance", ""),
            [t+(a+b)/2 for t,(a,b) in zip(node["translation"], bounds)],
            [b-a for a,b in bounds],
            pbr.get("baseColorFactor", [1, 1, 1, 1]), "baseColorTexture" in pbr,
            "normalTexture" in material, max(material.get("emissiveFactor", [0, 0, 0])) > 0.1,
            record["material"], bool(props.get("ThermalNonCover")),
        ]
    return {"file": path.name, "asset": model["id"], "rows": rows}


def main():
    index = (OUTPUT / "import-index.json").read_bytes()
    stage = json.loads(index)
    models = json.loads((OUTPUT / "approved-assets.json").read_text())
    for batch in stage["batches"]:
        model = models.get(batch["file"])
        if model and model["moderationState"] == "Approved":
            target = OUTPUT / (batch["file"].removesuffix(".glb") + ".native.json")
            target.write_text(json.dumps(capture_rows(batch, model), separators=(",", ":")))
    catalog = json.loads((ART / "panel-catalog.json").read_text())
    config = {"binding": digest(index), "blend": stage["blendSha256"], "panels": catalog["panels"],
              "fragments": catalog["fragments"], "locationStuds": stage["locationStuds"],
              "yawDegrees": stage["yawDegrees"], "batches": [entry["file"] for entry in stage["batches"]]}
    (OUTPUT / "bind.json").write_text(json.dumps(config, separators=(",", ":")))


if __name__ == "__main__":
    main()
