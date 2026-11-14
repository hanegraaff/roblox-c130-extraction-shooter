"""Refresh P16 provenance/hashes after deliberate Blender source/export changes.

Run from any directory. Only records prefixed ``p16-`` are replaced; existing
world/model/runtime-recipe records are retained. This does not run authoring,
approve assets, upload anything or validate geometry. Run verify.py afterward.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PACKAGE_ROOTS = ("assets/blender/military-outpost", "assets/exports/military-outpost")
KINDS = {".blend": "source", ".png": "texture", ".obj": "mesh", ".fbx": "mesh",
         ".mtl": "material", ".json": "catalog"}


def main() -> None:
    """Replace only the known package's provenance with the current file bytes."""
    records = []
    for directory in PACKAGE_ROOTS:
        folder = ROOT / directory
        if not folder.is_dir():
            raise ValueError(f"Missing P16 package: {directory}; build it before refreshing")
        for path in sorted(folder.rglob("*")):
            if not path.is_file() or path.suffix == ".md":
                continue
            if path.suffix not in KINDS or not path.resolve().is_relative_to(folder.resolve()):
                raise ValueError(f"Unexpected P16 source/export dependency: {path}")
            relative = path.relative_to(ROOT).as_posix()
            records.append({
                "id": "p16-" + path.relative_to(ROOT / "assets").as_posix().replace("/", "-").replace(".", "-"),
                "kind": KINDS[path.suffix],
                "source": "Original Blender authoring and deterministic baked textures; scripts/p16_build.py, seed 1601. User-supplied illustrations used as visual references only.",
                "author": "Project contributors",
                "license": "Original project-authored asset; no third-party mesh or texture content bundled. No additional redistribution license specified.",
                "local_path": relative,
                "roblox_asset_id": None,
                "upload_owner": None,
                "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            })
    manifest_path = ROOT / "assets/manifest.json"
    manifest = json.loads(manifest_path.read_text())
    manifest["assets"] = [item for item in manifest["assets"] if not item["id"].startswith("p16-")] + records
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"Refreshed {len(records)} P16 source/export records; run python3 scripts/verify.py.")


if __name__ == "__main__":
    main()
