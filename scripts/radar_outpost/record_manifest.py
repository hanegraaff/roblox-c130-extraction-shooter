"""Refresh only Vesper Array entries after deliberately rebuilding and inspecting the package."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ASSETS = {
    'source': ('source', 'assets/blender/radar-outpost/vesper-array.blend'),
    'panels': ('catalog', 'assets/blender/radar-outpost/panel-catalog.json'),
    'assembly': ('mesh', 'assets/exports/radar-outpost/vesper-array.glb'),
    'variants': ('mesh', 'assets/exports/radar-outpost/damage-library.glb'),
}


def main():
    path = ROOT / 'assets/manifest.json'
    manifest = json.loads(path.read_text())
    records = [a for a in manifest['assets'] if not a['id'].startswith('vesper-array-')]
    for key, (kind, local_path) in ASSETS.items():
        records.append({
            'id': 'vesper-array-' + key,
            'kind': kind,
            'source': 'Original modeling and baked surface art from scripts/radar_outpost. Four supplied illustrations guided the design.',
            'author': 'Project contributors',
            'license': 'Project-authored meshes and surface art. No third-party mesh, font or reference pixels bundled.',
            'local_path': local_path,
            'roblox_asset_id': None,
            'upload_owner': None,
            'sha256': hashlib.sha256((ROOT / local_path).read_bytes()).hexdigest(),
        })
    manifest['assets'] = records
    path.write_text(json.dumps(manifest, indent=2) + '\n')


if __name__ == '__main__':
    main()
