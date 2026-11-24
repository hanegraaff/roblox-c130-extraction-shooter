"""Stage the approved waiting lobby for native Roblox import without uploading it."""

import argparse
import json
import math
from pathlib import Path
import posixpath
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from radar_outpost.prepare_import import ROOT, decode_glb, digest
from salt_flats.prepare_import import NativeBatch, pose_tree


SOURCE = ROOT / "assets/blender/lobby-interior"
EXPORT = ROOT / "assets/exports/lobby-interior/waiting-lobby.glb"
BUST_EXPORT = ROOT / "assets/exports/lobby-bust/lobby-bust.glb"
APPROVAL = ROOT / "docs/evidence/p22/blender-oil-reimport.json"
OUTPUT = ROOT / "build/lobby-import"
PART_LIMIT = 200
TRIANGLE_LIMIT = 20_000
SITE_ORIGIN = [520, 0, 0]


def new_batch(doc, binary, prefix):
    batch = NativeBatch(doc, binary, prefix, namespace="P22")
    batch.out["asset"]["generator"] = "P22 waiting lobby Roblox import preparation"
    return batch


def embedded_color(doc, binary, material_index):
    """Read the exact bytes used by the material's glTF base-color slot."""
    pbr = doc["materials"][material_index]["pbrMetallicRoughness"]
    texture = doc["textures"][pbr["baseColorTexture"]["index"]]
    image = doc["images"][texture["source"]]
    view = doc["bufferViews"][image["bufferView"]]
    start = view.get("byteOffset", 0)
    return binary[start : start + view["byteLength"]]


def rehydrate_oil_images(doc, binary, catalog):
    """Embed the four exact, locally referenced oil images for native staging."""
    expected = {}
    for painting in catalog["paintings"]:
        number = painting["portrait"]
        if number not in {2, 3, 4, 6}:
            continue
        local = f"assets/blender/lobby-interior/oil-portraits/portrait-{number}-oil.png"
        if painting["source"] != local:
            raise ValueError(f"Unexpected approved oil path for portrait {number}")
        uri = posixpath.relpath(local, EXPORT.parent.relative_to(ROOT).as_posix())
        expected[uri] = (ROOT / local, painting["source_sha256"])
    external = [image for image in doc["images"] if "uri" in image]
    if len(expected) != 4 or len(external) != 4 or {image["uri"] for image in external} != expected.keys():
        raise ValueError("Lobby GLB must use the four exact approved oil image URIs")

    data = bytearray(binary)
    for image in external:
        source, approved_hash = expected[image["uri"]]
        if source.resolve() != source:
            raise ValueError(f"Oil portrait must be stored at its approved source path: {source.name}")
        payload = source.read_bytes()
        if not payload.startswith(b"\x89PNG\r\n\x1a\n") or digest(payload) != approved_hash:
            raise ValueError(f"Oil portrait bytes differ from approved PNG: {source.name}")
        data.extend(b"\x00" * (-len(data) % 4))
        image["bufferView"] = len(doc["bufferViews"])
        doc["bufferViews"].append({
            "buffer": 0,
            "byteOffset": len(data),
            "byteLength": len(payload),
        })
        data.extend(payload)
        del image["uri"]
        image["mimeType"] = "image/png"
    doc["buffers"][0]["byteLength"] = len(data)
    return bytes(data)


def check_paintings(doc, binary, poses, catalog):
    """Bind each native canvas and every pilot frame piece to the approved catalog."""
    indices = {node["name"]: i for i, node in enumerate(doc["nodes"])}
    if len(indices) != len(doc["nodes"]):
        raise ValueError("Duplicate source object names cannot be bound to native parts")
    paintings = {}
    pilot = set()
    for painting in catalog["paintings"]:
        number = painting["portrait"]
        index = indices[painting["canvas"]]
        (primitive,) = doc["meshes"][doc["nodes"][index]["mesh"]]["primitives"]
        material = primitive["material"]
        approved_image = (ROOT / painting["source"]).read_bytes()
        vertices = doc["accessors"][primitive["attributes"]["POSITION"]]
        low, high = vertices["min"], vertices["max"]
        center = [(a + b) / 2 for a, b in zip(low, high)]
        width = max(high[0] - low[0], high[2] - low[2])
        height = high[1] - low[1]
        x, y, z = painting["center_blender"]
        if (
            doc["materials"][material]["name"] != painting["material"]
            or digest(approved_image) != painting["source_sha256"]
            or embedded_color(doc, binary, material) != approved_image
            or math.dist(center, (x, z, -y)) > 0.001
            or math.dist((width, height), painting["size_studs"]) > 0.001
            or poses[index][:2] != ([0, 0, 0], [0, 0, 0, 1])
        ):
            raise ValueError(f"Approved canvas does not match its source: portrait {number}")
        paintings[index] = painting
        members = {
            i for name, i in indices.items() if name.startswith(painting["frame_prefix"])
        }
        stretcher = indices[painting["canvas"].replace("canvas", "stretcher")]
        if not members:
            raise ValueError(f"Missing frame for portrait {number}")
        if number == 4:
            pilot = members | {index, stretcher}
    if {row["portrait"] for row in paintings.values()} != set(range(1, 7)) or not pilot:
        raise ValueError("Expected six approved paintings and a complete portrait 4 pilot")
    return paintings, pilot


def approved_inputs():
    """Read the owner-approved current art bytes without changing the historical P21 lock."""
    report = json.loads(APPROVAL.read_text())
    blend = (SOURCE / "waiting-lobby.blend").read_bytes()
    raw = EXPORT.read_bytes()
    catalog_bytes = (SOURCE / "assembly.json").read_bytes()
    if digest(blend) != report["source_sha256"] or digest(raw) != report["export_sha256"]:
        raise ValueError("Source and export must match the approved P22 hashes")
    if digest(catalog_bytes) != report["catalog_sha256"]:
        raise ValueError("Placement catalog must match the approved P22 hash")
    catalog = json.loads(catalog_bytes)
    bust_sha = digest(BUST_EXPORT.read_bytes())
    if bust_sha != report["approved_bust_sha256"] or bust_sha != catalog["p20_glb_sha256"]:
        raise ValueError("Standalone bust export must match the approved P20 identity")
    return report, raw, catalog


def stage(destination):
    """Stage a complete framed portrait, then bounded batches of the remaining assembly."""
    report, raw, catalog = approved_inputs()
    doc, binary = decode_glb(raw)
    binary = rehydrate_oil_images(doc, binary, catalog)
    poses = pose_tree(doc)
    source_nodes = doc["nodes"]
    if len(poses) != len(source_nodes) or len(doc["scenes"]) != 1:
        raise ValueError("Expected one fully connected lobby scene")
    (bust_root,) = [node for node in source_nodes if node["name"] == "Lobby Bust · base center"]
    bust = set(bust_root["children"])
    if len(bust) != 34 or catalog["p20_instances"] != 1 or catalog["pivot_roblox"] != SITE_ORIGIN:
        raise ValueError("Expected one 34-part approved bust and the established site origin")
    paintings, pilot = check_paintings(doc, binary, poses, catalog)

    # NativeBatch writes each material as a separately named import part. It
    # copies accessor and image dependencies byte-for-byte into each GLB.
    doc["scenes"][0]["nodes"] = list(range(len(source_nodes)))
    native_pilot = new_batch(doc, binary, "Pilot")
    chunks = [native_pilot]
    triangle_count = 0
    for index, node in enumerate(source_nodes):
        if "mesh" not in node:
            continue
        role = "Bust" if index in bust else "Room"
        if index in paintings:
            role = "Portrait"
        if index in pilot:
            batch = native_pilot
        else:
            if chunks[-1] is native_pilot or len(chunks[-1].records) >= PART_LIMIT:
                chunks.append(new_batch(doc, binary, f"Room{len(chunks):02}"))
            batch = chunks[-1]
        (primitive,) = doc["meshes"][node["mesh"]]["primitives"]
        triangles, remainder = divmod(doc["accessors"][primitive["indices"]]["count"], 3)
        if not 0 < triangles <= TRIANGLE_LIMIT or remainder or primitive.get("mode", 4) != 4:
            raise ValueError(f"Invalid Studio triangle inventory: {node['name']}")
        triangle_count += triangles
        batch.add(index, poses[index], role)
        record = batch.records[-1]
        if index in paintings:
            record["painting"] = paintings[index]
            record["managedName"] = f"P22_Portrait_{paintings[index]['portrait']:02}"
        else:
            record["managedName"] = record["importName"]

    records = [record for batch in chunks for record in batch.records]
    if len(records) != report["inventory"]["mesh_objects"] or (
        triangle_count != report["inventory"]["assembled_triangles"]
    ):
        raise ValueError("Staged parts or triangles differ from the approved reimport report")
    destination.mkdir(parents=True, exist_ok=True)
    batches = [
        batch.write(destination, f"lobby-{batch.prefix.lower()}.glb", digest(raw)) for batch in chunks
    ]
    index = {
        "schema": 1,
        "approvedLayoutCommit": "ec431397c6047882dd85e2b46566645da8100ef0",
        "artApproval": str(APPROVAL.relative_to(ROOT)),
        "blendSha256": report["source_sha256"],
        "assemblySha256": report["export_sha256"],
        "bustSha256": report["approved_bust_sha256"],
        "catalogSha256": report["catalog_sha256"],
        "siteOrigin": SITE_ORIGIN,
        "axes": "Roblox (520 + Blender X, Blender Z, -Blender Y), one source unit per stud.",
        "meshParts": len(records),
        "triangles": triangle_count,
        "batches": batches,
    }
    (destination / "import-index.json").write_text(json.dumps(index, indent=2) + "\n")
    return index


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=OUTPUT)
    result = stage(parser.parse_args().output)
    for item in result["batches"]:
        print(f"{item['file']}: {item['expectedMeshParts']} parts, {item['bytes']:,} bytes")
    print(f"Verified {result['meshParts']:,} mesh uses and {result['triangles']:,} triangles.")
