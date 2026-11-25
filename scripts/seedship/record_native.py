"""Record the genuine Studio-native Seedship roots and private asset receipt."""
import base64
import json

from prepare_import import ROOT, OUTPUT, digest

ROOTS = ("PrismSeedship", "PrismPanelVariants")
RECEIPT = ROOT / "assets/imports/alien-spaceship/native-receipt.json"


def main():
    index = (OUTPUT / "import-index.json").read_bytes()
    stage = json.loads(index)
    models = json.loads((OUTPUT / "approved-assets.json").read_text())
    reports = json.loads((OUTPUT / "native-capture.json").read_text())
    output = json.loads((OUTPUT / "native-export.json").read_text())
    batches = []
    for batch in stage["batches"]:
        name = batch["file"]
        asset = models[name]
        report = reports[name]
        if (asset["moderationState"] != "Approved" or report["count"] != batch["expectedMeshParts"]
                or report["missing"] or report["cookFailures"]):
            raise ValueError(f"Incomplete native batch: {name}")
        batches.append({"file": name, "sourceBatchSha256": batch["sha256"], **asset, **report})
    if output["panels"] != 102 or sum(b["count"] for b in batches) != output["meshes"]:
        raise ValueError("Native assembly did not retain every mesh and panel identity")
    source = {}
    binaries = {}
    for name in ROOTS:
        path = ROOT / f"assets/models/{name}.rbxm"
        payload = b"".join(chunk.read_bytes().strip() for chunk in sorted(OUTPUT.glob(f"{name}.*.b64")))
        if len(payload) != output["sizes"][name]:
            raise ValueError(f"Unexpected Studio transfer length: {name}")
        binary = base64.b64decode(payload, validate=True)
        if not binary.startswith(b"<roblox!\x89\xff\r\n\x1a\n"):
            raise ValueError(f"Invalid Studio serialization: {name}")
        binaries[path] = binary
        source[str(path.relative_to(ROOT))] = digest(binary)
    receipt = {
        "studio": "0.748.0.7481526", "ownerUserId": "2227341845",
        "assetImportUniverseId": "10776653720", "sourceBindingSha256": digest(index),
        "sourceBlendSha256": stage["blendSha256"], "catalogSha256": stage["catalogSha256"],
        "axisCorrectionYDegrees": 180, "placedYawDegrees": stage["yawDegrees"],
        "placedDeckPivot": stage["locationStuds"], "nativeModels": source,
        "batches": batches, "meshPartCount": output["meshes"], "panelCount": output["panels"],
    }
    receipt_bytes = (json.dumps(receipt, indent=2, sort_keys=True) + "\n").encode()
    for path, binary in binaries.items():
        path.write_bytes(binary)
    RECEIPT.parent.mkdir(parents=True, exist_ok=True)
    RECEIPT.write_bytes(receipt_bytes)
    source[str(RECEIPT.relative_to(ROOT))] = digest(receipt_bytes)
    manifest = ROOT / "assets/manifest.json"
    data = json.loads(manifest.read_text())
    current = [record for record in data["assets"] if not record["id"].startswith("prism-seedship-native-")]
    for path, sha in sorted(source.items()):
        kind = "catalog" if path.endswith(".json") else "model"
        current.append({
            "id": f"prism-seedship-native-{path.rsplit('/', 1)[-1].split('.')[0].lower()}",
            "kind": kind, "source": "Studio-native Prism Seedship, damage states and import receipt.",
            "author": "Project contributors", "license": "Project-authored asset",
            "local_path": path, "roblox_asset_id": None, "upload_owner": None, "sha256": sha,
        })
    for batch in batches:
        current.append({
            "id": "prism-seedship-native-" + batch["file"].removesuffix(".glb"),
            "kind": "model", "source": "Private Roblox import of the approved Blender Seedship package.",
            "author": "Project contributors", "license": "Project-authored asset", "local_path": None,
            "roblox_asset_id": batch["id"], "upload_owner": receipt["ownerUserId"],
        })
    data["assets"] = current
    manifest.write_text(json.dumps(data, indent=2) + "\n")


if __name__ == "__main__":
    main()
