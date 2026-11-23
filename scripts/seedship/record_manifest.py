"""Record the inspected Seedship package and preserve all other asset records."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PACKAGE = (
    ("source", "source", "assets/blender/alien-spaceship/prism-seedship.blend"),
    ("catalog", "catalog", "assets/blender/alien-spaceship/panel-catalog.json"),
    ("assembly", "mesh", "assets/exports/alien-spaceship/prism-seedship.glb"),
    ("light", "mesh", "assets/exports/alien-spaceship/light-and-intact-proxies.glb"),
    ("heavy", "mesh", "assets/exports/alien-spaceship/heavy-and-fragments.glb"),
)


def main():
    path = ROOT / "assets/manifest.json"
    manifest = json.loads(path.read_text())
    inspection = json.loads((ROOT / "docs/images/alien-spaceship/inspection.json").read_text())
    records = []
    for key, kind, local_path in PACKAGE:
        item = ROOT / local_path
        digest = hashlib.sha256(item.read_bytes()).hexdigest()
        if kind == "source":
            assert digest == inspection["sourceSha256"], "Inspect the saved source before recording it."
        if kind == "mesh":
            assert digest == inspection["files"][item.name]["sha256"], item
        records.append({
            "id": "prism-seedship-" + key,
            "kind": kind,
            "source": "Original Prism Seedship model, baked mineral maps and panel geometry from scripts/seedship. Four user-supplied illustrations guided the design.",
            "author": "Project contributors",
            "license": "Project-authored meshes and surface art. The visual reference images are separate from this package.",
            "local_path": local_path,
            "roblox_asset_id": None,
            "upload_owner": None,
            "sha256": digest,
        })
    ids = {record["id"] for record in records}
    manifest["assets"] = [item for item in manifest["assets"] if item["id"] not in ids] + records
    path.write_text(json.dumps(manifest, indent=2) + "\n")


if __name__ == "__main__":
    main()
