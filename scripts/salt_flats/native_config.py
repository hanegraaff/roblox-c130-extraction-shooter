"""Generate native compiler instructions from the exact approved upload batches."""
from __future__ import annotations

import json
import struct

from salt_flats.prepare_import import STAGING, decode_glb, digest, rotate, vertex_rows
from salt_flats.solid_recipe import panel_boxes, wreck_skin
from salt_flats.walk_surfaces import walk_surfaces


def main():
    staging_bytes = (STAGING / "import-index.json").read_bytes()
    stage = json.loads(staging_bytes)
    cloud = json.loads((STAGING / "cloud-models.json").read_text())["models"]

    panels = {}
    versions = []
    for batch in stage["batches"]:
        cloud_asset = cloud[batch["file"]]
        if cloud_asset["state"] != "Approved":
            raise ValueError(f"Model is not approved: {batch['file']}")
        source = (STAGING / batch["file"]).read_bytes()
        if digest(source) != batch["sha256"]:
            raise ValueError(f"Upload batch changed after staging: {batch['file']}")
        doc, blob = decode_glb(source)
        native = []
        for node, row in zip(doc["nodes"], batch["objects"], strict=True):
            primitive = doc["meshes"][node["mesh"]]["primitives"][0]
            material = doc["materials"][primitive["material"]]
            pbr = material["pbrMetallicRoughness"]
            props = row["sourceProperties"]
            panel, appearance = props.get("PanelId", ""), props.get("Appearance", "")
            if panel and " • " + appearance in row["sourceObject"]:
                panels.setdefault(panel, {})[appearance] = [props["Story"], row["pose"]["translation"]]
            translation = node["translation"]
            points = [rotate(struct.unpack("<3f", point), node["rotation"]) for point in
                      vertex_rows(doc, blob, primitive["attributes"]["POSITION"])]
            extrema = [[min(v[k] for v in points), max(v[k] for v in points)] for k in range(3)]
            center = [offset + (low+high)/2 for offset, (low, high) in zip(translation, extrema)]
            extent = [high-low for low, high in extrema]
            color = pbr.get("baseColorFactor", [1, 1, 1, 1])
            emissive = material.get("emissiveFactor", [0, 0, 0])
            native.append([row["importName"], row["role"], panel, appearance,
                           center, extent, color, "baseColorTexture" in pbr, row["material"],
                           max(emissive) > 0.1])
        record = {"model": cloud_asset["id"], "file": batch["file"], "sha256": batch["sha256"],
                  "rows": native}
        versions.append({k: v for k, v in record.items() if k != "rows"})
        (STAGING / (batch["file"].removesuffix(".glb") + ".native.json")).write_text(
            json.dumps(record, separators=(",", ":"))
        )
    compiled = {}
    for key, states in panels.items():
        level, pivot = states["Pristine"]
        compiled[key] = {"story": level, "pivot": pivot,
                         "pristine": panel_boxes(key, pivot, False),
                         "heavy": panel_boxes(key, pivot, True)}
    source_doc, _ = decode_glb((STAGING.parent.parent /
                                "assets/exports/plane-hangar/salt-flats-hangar.glb").read_bytes())
    wreck_node = next(n for n in source_doc["nodes"] if n["name"].startswith("C-130 •"))
    settings = {"blend": stage["blendSha256"], "assembly": stage["assemblySha256"],
                "binding": digest(staging_bytes), "panels": compiled,
                "walk": walk_surfaces(), "wreckSkin": wreck_skin(),
                "wreckOrigin": wreck_node["translation"],
                "wreckYaw": 22, "models": versions}
    (STAGING / "native-settings.json").write_text(json.dumps(settings, separators=(",", ":")))


if __name__ == "__main__":
    main()
