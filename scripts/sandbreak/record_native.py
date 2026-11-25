"""Verify and record the managed Sandbreak models and private import receipts."""

import base64
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
STAGING = ROOT / "build/sandbreak-import"
sys.path.insert(0, str(ROOT / "scripts"))
from radar_outpost.prepare_import import digest

NATIVE_MAGIC = b"<roblox!\x89\xff\r\n\x1a\n"
ROLES = ("SandbreakBunker", "SandbreakPanelVariants")


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8"))


def decode_captures():
    """Bind source hashes to the exact Studio capture version and model bytes."""
    captures = read_json(STAGING / "native-capture-input.json")
    uploads = read_json(ROOT / "docs/evidence/sandbreak-batch-uploads.json")
    index_bytes = (STAGING / "native-index.json").read_bytes()
    index = json.loads(index_bytes)
    source = {batch["file"]: batch for batch in index["batches"] if batch["file"] != "sandbreak-native-pilot.glb"}
    if len(source) != 32 or set(captures) != set(source):
        raise ValueError("Missing or unexpected Sandbreak captures")
    records = {batch["file"]: batch for batch in uploads["batches"]}
    for filename, receipt in captures.items():
        uploaded = records[filename]
        approved = source[filename]
        if (receipt["count"] != approved["expectedMeshParts"]
                or receipt["assetId"] != uploaded["assetId"]
                or uploaded["sha256"] != approved["sha256"]
                or uploaded["moderation"] != "Approved"):
            raise ValueError(f"Invalid Studio capture for {filename}")
        key = filename.removeprefix("sandbreak-native-").removesuffix(".glb")
        encoded = b"".join((STAGING / f"capture-{key}.b64").read_bytes().split())
        if len(encoded) != receipt["base64Length"]:
            raise ValueError(f"Missing capture bytes for {filename}")
        payload = base64.b64decode(encoded, validate=True)
        if not payload.startswith(NATIVE_MAGIC):
            raise ValueError(f"Not a Studio RBXM for {filename}")
        receipt["sha256"] = approved["sha256"]
        receipt["captureSha256"] = digest(payload)
        (STAGING / f"capture-{key}.rbxm").write_bytes(payload)
    binding = {"sourceSha256": index["sourceSha256"], "stagingSha256": digest(index_bytes), "batches": captures,
               "owner": uploads["ownerUserId"], "importPlace": uploads["privateImportPlaceId"]}
    binding["binding"] = digest(json.dumps(binding, sort_keys=True, separators=(",", ":")).encode())
    (STAGING / "native-capture.json").write_text(json.dumps(binding, indent=2) + "\n", encoding="utf-8")
    print(f"Verified {len(captures)} native captures, {sum(row['count'] for row in captures.values())} meshes")


def record():
    """Record verified production assets and native requests after host compilation."""
    receipt = read_json(STAGING / "native-capture.json")
    index = read_json(STAGING / "native-index.json")
    receipt["panelCount"] = 103
    attachment_clones = sum(
        1 for batch in index["batches"] if batch["file"].startswith("sandbreak-native-attached-art-")
        for part in batch["objects"] if part["sourceProperties"].get("PanelId")
    )
    receipt["managedMeshCount"] = sum(
        batch["count"] for batch in receipt["batches"].values()
    ) + receipt["panelCount"] + attachment_clones
    receipt_path = "assets/imports/sandbreak/native-receipt.json"
    local_assets = {}
    for role in ROLES:
        source = STAGING / f"{role}.rbxm"
        content = source.read_bytes()
        if not content.startswith(NATIVE_MAGIC):
            raise ValueError(f"Not a native model: {source}")
        path = f"assets/models/{role}.rbxm"
        (ROOT / path).write_bytes(content)
        local_assets[path] = digest(content)
    receipt["nativeModels"] = local_assets.copy()
    (ROOT / receipt_path).parent.mkdir(parents=True, exist_ok=True)
    receipt_bytes = (json.dumps(receipt, indent=2) + "\n").encode()
    (ROOT / receipt_path).write_bytes(receipt_bytes)
    local_assets[receipt_path] = digest(receipt_bytes)
    manifest_path = ROOT / "assets/manifest.json"
    manifest = read_json(manifest_path)
    entries = [row for row in manifest["assets"] if not row["id"].startswith("sandbreak-native-")]
    shared = {"source": "Studio-native Sandbreak import from the approved project-authored Blender source.",
              "author": "Project contributors", "license": "Project-authored asset"}
    for path, sha in sorted(local_assets.items()):
        entries.append({"id": "sandbreak-native-" + Path(path).stem.lower(),
                        "kind": "catalog" if path == receipt_path else "model", **shared,
                        "local_path": path, "roblox_asset_id": None, "upload_owner": None, "sha256": sha})
    # Source upload IDs let later imports keep the original native revisions.
    for filename, import_row in sorted(receipt["batches"].items()):
        key = filename.removesuffix(".glb")
        entries.append({"id": key, "kind": "model", **shared, "local_path": None,
                        "roblox_asset_id": import_row["assetId"], "upload_owner": receipt["owner"]})
    manifest["assets"] = entries
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print("Recorded managed Sandbreak source models and batch IDs.")


if __name__ == "__main__":
    if sys.argv[1:] == ["--record"]:
        record()
    elif not sys.argv[1:]:
        decode_captures()
    else:
        raise SystemExit("Usage: record_native.py [--record]")
