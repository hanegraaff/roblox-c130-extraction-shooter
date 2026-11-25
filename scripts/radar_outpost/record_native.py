"""Bind the serialized Studio assembly, variant bank and observed imports to Git."""
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
NATIVE_MODELS = (
    ROOT / "assets/models/VesperArray.rbxm",
    ROOT / "assets/models/VesperPanelVariants.rbxm",
)
RECEIPT = ROOT / "assets/imports/radar-outpost/native-receipt.json"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("observation", type=Path, help="captured Studio observation JSON")
    args = parser.parse_args()
    binding = json.loads((ROOT / "build/vesper-import/native-binding.json").read_text())
    observed = json.loads(args.observation.read_text())
    if observed["meshCount"] != 1417 or len(observed["versions"]) != len(binding["receipts"]):
        raise ValueError("Incomplete Studio import receipt")
    for model, version in zip(binding["receipts"], observed["versions"]):
        model["assetVersionId"] = version
    model_paths = {p.relative_to(ROOT).as_posix(): digest(p) for p in NATIVE_MODELS}
    receipt = {
        "schema": 1,
        "ownerUserId": "2227341845",
        "testUniverseId": "10776653720",
        "testPlaceId": "72732833195348",
        "sourceBlenderSha256": binding["source"],
        "bindingSha256": binding["receipt"],
        "models": binding["receipts"],
        "meshCountBeforeBankCompilation": observed["meshCount"],
        "textureIdsByMaterial": observed["colors"],
        "nativeModelsByPathAndSha256": model_paths,
        "placement": {"positionStuds": [160, 0.125, -80], "fileAxisCorrectionYDegrees": 180},
    }
    RECEIPT.parent.mkdir(parents=True, exist_ok=True)
    RECEIPT.write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n")
    manifest_path = ROOT / "assets/manifest.json"
    manifest = json.loads(manifest_path.read_text())
    entries = [entry for entry in manifest["assets"] if not entry["id"].startswith("vesper-native-")]

    def entry(name, kind, source, path=None, asset_id=None):
        entries.append({
            "id": "vesper-native-" + name,
            "kind": kind,
            "source": source,
            "author": "Project contributors",
            "license": "Project-authored asset",
            "local_path": path.relative_to(ROOT).as_posix() if path else None,
            "roblox_asset_id": str(asset_id) if asset_id else None,
            "upload_owner": "2227341845" if asset_id else None,
            **({"sha256": digest(path)} if path else {}),
        })

    entry("assembly", "model", "Owned native Vesper assembly preserved by Studio SerializationService", NATIVE_MODELS[0])
    entry("variants", "model", "Owned native Vesper state bank preserved by Studio SerializationService", NATIVE_MODELS[1])
    entry("receipt", "catalog", "Studio reconstruction and imported asset identity receipt", RECEIPT)
    for batch in binding["receipts"]:
        entry("upload-" + Path(batch["file"]).stem, "model", "Approved Vesper export uploaded for private Studio import",
              asset_id=batch["modelId"])
    manifest["assets"] = entries
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")


if __name__ == "__main__":
    main()
