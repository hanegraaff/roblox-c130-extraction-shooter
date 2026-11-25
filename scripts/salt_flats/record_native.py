"""Record genuine Studio exports and the verified import manifest in Git."""
from __future__ import annotations

import base64
import json

from salt_flats.prepare_import import ROOT, STAGING, digest

NATIVE = ("SaltFlatsHangar", "SaltFlatsPanelVariants")
NATIVE_PATHS = [f"assets/models/{name}.rbxm" for name in NATIVE]
RECEIPT = "assets/imports/salt-flats/native-receipt.json"


def main():
    capture = json.loads((STAGING / "native-capture.json").read_text())
    exported = json.loads((STAGING / "native-export.json").read_text())
    staged = (STAGING / "import-index.json").read_bytes()
    index = json.loads(staged)
    if capture["meshes"] != exported["meshCount"] or capture["panels"] != exported["panels"]:
        raise ValueError("Studio native export count differs from its import")
    hashes = {}
    for name, path in zip(NATIVE, NATIVE_PATHS):
        encoded = b"".join(part.read_bytes().strip() for part in sorted(STAGING.glob(f"{name}.*.b64")))
        if len(encoded) != exported["sizes"][name]:
            raise ValueError(f"Missing Studio transfer chunks for {name}")
        binary = base64.b64decode(encoded, validate=True)
        if not binary.startswith(b"<roblox!\x89\xff\r\n\x1a\n"):
            raise ValueError(f"Unrecognized Studio binary for {name}")
        (ROOT / path).write_bytes(binary)
        hashes[path] = digest(binary)
    capture["nativeModels"] = hashes
    capture["sourceBlendSha256"] = index["blendSha256"]
    capture["sourceGlbSha256"] = index["assemblySha256"]
    capture["sourceBindingSha256"] = digest(staged)
    capture["placement"] = index["placement"]
    by_file = {row["file"]: row for row in index["batches"]}
    for row in capture["batches"]:
        batch = by_file[row["file"]]
        row["sourceBatchSha256"] = batch["sha256"]
        if row["count"] != batch["expectedMeshParts"]:
            raise ValueError("Native model piece count differs from input")
    receipt = (json.dumps(capture, indent=2, sort_keys=True) + "\n").encode()
    (ROOT / RECEIPT).write_bytes(receipt)

    manifest_path = ROOT / "assets/manifest.json"
    manifest = json.loads(manifest_path.read_text())
    entries = [row for row in manifest["assets"] if not row["id"].startswith("salt-flats-native-")]
    for path, sha in sorted((hashes | {RECEIPT: digest(receipt)}).items()):
        entries.append({
            "id": "salt-flats-native-" + path.rsplit("/", 1)[-1].split(".")[0].lower(),
            "kind": "catalog" if path == RECEIPT else "model",
            "source": "Genuine Studio data for the native Salt Flats hangar, damage states and wreck.",
            "author": "Project contributors",
            "license": "Project-authored asset",
            "local_path": path,
            "roblox_asset_id": None,
            "upload_owner": None,
            "sha256": sha,
        })
    for batch in capture["batches"]:
        entries.append({
            "id": "salt-flats-native-" + batch["file"].removesuffix(".glb"),
            "kind": "model",
            "source": "Approved Salt Flats source uploaded as a private Studio import batch.",
            "author": "Project contributors",
            "license": "Project-authored asset",
            "local_path": None,
            "roblox_asset_id": batch["asset"],
            "upload_owner": capture["ownerUserId"],
        })
    manifest["assets"] = entries
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")


if __name__ == "__main__":
    main()
