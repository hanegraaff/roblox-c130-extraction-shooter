"""Create local thermal tint templates from already-verified texture bindings."""
import hashlib
import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from inspect_build import compiled_surface_attributes, instance_nodes


def main():
    artifact = Path(sys.argv[1])
    nodes = instance_nodes(artifact)
    textures = {}
    for path, item in sorted(nodes.items()):
        if not path.startswith("ServerStorage/Assets/SaltFlats") or item.get("class") != "MeshPart":
            continue
        reference = item.findtext("Properties/Content[@name='TextureContent']/uri")
        if reference:
            material = compiled_surface_attributes(item)["ImportMaterialKey"]
            if textures.setdefault(material, reference) != reference:
                raise ValueError(f"Texture differs across Salt Flats batches: {material}")
    if not textures:
        raise ValueError("No mapped Salt Flats color textures")
    path = Path("assets/presentation/SaltFlatsThermalSurfaces.model.json")
    palette = {"ClassName": "Folder", "Children": [
        {"Name": key, "ClassName": "SurfaceAppearance", "Properties": {"ColorMap": image, "Color": [1, 1, 1]}}
        for key, image in sorted(textures.items())
    ]}
    raw = (json.dumps(palette, indent=2) + "\n").encode()
    path.write_bytes(raw)
    manifest_path = Path("assets/manifest.json")
    manifest = json.loads(manifest_path.read_text())
    manifest["assets"] = [row for row in manifest["assets"] if row["local_path"] != path.as_posix()]
    manifest["assets"].append({
        "id": "salt-flats-thermal-palette",
        "kind": "material",
        "source": "Native Salt Flats color maps reused for local thermal shading.",
        "author": "Project contributors",
        "license": "Project-authored asset",
        "local_path": path.as_posix(),
        "roblox_asset_id": None,
        "upload_owner": None,
        "sha256": hashlib.sha256(raw).hexdigest(),
    })
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"Verified {len(textures)} Salt Flats legacy texture bindings")


if __name__ == "__main__":
    main()
