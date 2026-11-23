"""Stage the approved Seedship meshes for a material-split Studio import."""
import json
import math
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from radar_outpost.prepare_import import ROOT, decode_glb, digest, source_bytes
from salt_flats.prepare_import import NativeBatch, pose_tree

ART = ROOT / "assets/blender/alien-spaceship"
EXPORTS = ROOT / "assets/exports/alien-spaceship"
OUTPUT = ROOT / "build/seedship-import"
FILES = (
    ("prism-seedship.glb", "A"),
    ("light-and-intact-proxies.glb", "L"),
    ("heavy-and-fragments.glb", "H"),
)
SITE = (0, 2.4, 259)
YAW_DEGREES = 180
PILOT = {
    "South threshold • six fan steps",
    "Impact • fallen sill plate",
    "Prism_Skirt_01_Pristine",
    "S-07 • dermal sculpt",
}
MAX_PARTS = 200
MAX_MESH_TRIANGLES = 20_000


def stage(raw, family, destination):
    """Split by material and batch while preserving all poses and triangles."""
    document, blob = decode_glb(raw)
    poses = pose_tree(document)
    document["scenes"][0]["nodes"] = list(range(len(document["nodes"])))
    chunks = []
    if family == "A":
        pilot = NativeBatch(document, blob, "P", namespace="PS")
        chunks.append(pilot)
    active = NativeBatch(document, blob, family + "1", namespace="PS")
    chunks.append(active)
    total = 0
    for index, node in enumerate(document["nodes"]):
        if "mesh" not in node:
            continue
        surfaces = document["meshes"][node["mesh"]]["primitives"]
        for surface in surfaces:
            count, remainder = divmod(document["accessors"][surface["indices"]]["count"], 3)
            if remainder or not 0 < count <= MAX_MESH_TRIANGLES or surface.get("mode", 4) != 4:
                raise ValueError(f"Unsupported mesh primitive on {node['name']}")
            total += count
        role = poses[index][2]["Role"]
        if family == "A" and node["name"] in PILOT:
            pilot.add(index, poses[index], role)
            continue
        if len(active.records) + len(surfaces) > MAX_PARTS:
            number = 1 + sum(chunk.prefix.startswith(family) for chunk in chunks)
            active = NativeBatch(document, blob, family + str(number), namespace="PS")
            chunks.append(active)
        active.add(index, poses[index], role)
    if family == "A" and {piece["sourceObject"] for piece in pilot.records} != PILOT:
        raise ValueError("Pilot lost a scale, material, or orientation landmark")
    if sum(piece["triangles"] for chunk in chunks for piece in chunk.records) != total:
        raise ValueError("Staged triangle count differs from the source")
    return [chunk.write(destination, f"seedship-{chunk.prefix.lower()}.glb", digest(raw)) for chunk in chunks]


def validate_panels(catalog, batches):
    """Bind every state and query mesh to the same approved source pivot."""
    objects = {}
    for batch in batches:
        for record in batch["objects"]:
            objects[record["sourceObject"]] = record
    for panel in catalog["panels"]:
        x, y, z = panel["pivot"]
        expected = (x, z, -y)
        for key in ("pristine", "light", "heavy", "intactAndLightQuery", "heavyQuery"):
            record = objects[panel[key]]
            if record["sourceProperties"]["PanelId"] != panel["id"]:
                raise ValueError(f"Incorrect ownership for {panel[key]}")
            if math.dist(expected, record["pose"]["translation"]) > 0.002:
                raise ValueError(f"Incorrect pivot for {panel[key]}")
        if panel["total"] is not None:
            raise ValueError(f"Total must clear panel {panel['id']}")
    if len(catalog["panels"]) != 102 or not set(catalog["fragments"]) <= objects.keys():
        raise ValueError("Incomplete Seedship damage bank")
    breach = objects["Impact • fallen sill plate"]["pose"]["translation"]
    steps = objects["South threshold • six fan steps"]["pose"]["translation"]
    if not (breach[0] > 60 and breach[2] > 50 and steps[2] > 65):
        raise ValueError("Pilot landmarks are reversed or scaled")


def main():
    manifest = {entry["local_path"]: entry.get("sha256") for entry in
                json.loads((ROOT / "assets/manifest.json").read_text())["assets"]}
    blend = source_bytes(ART / "prism-seedship.blend", manifest)
    catalog = source_bytes(ART / "panel-catalog.json", manifest)
    OUTPUT.mkdir(parents=True, exist_ok=True)
    batches = []
    for name, family in FILES:
        batches.extend(stage(source_bytes(EXPORTS / name, manifest), family, OUTPUT))
    validate_panels(json.loads(catalog), batches)
    inspection = json.loads((ROOT / "docs/images/alien-spaceship/inspection.json").read_text())
    bounds = inspection["sourceAndReimportWorldBounds"]
    if inspection["sourceSha256"] != digest(blend):
        raise ValueError("Blender inspection differs from the approved source")
    # This half-turn maps Blender coordinates to world (-x, z + 2.4, y + 259).
    minimum = (SITE[0] - bounds[1][0], SITE[2] + bounds[0][1])
    maximum = (SITE[0] - bounds[0][0], SITE[2] + bounds[1][1])
    if not (-106 <= minimum[0] < maximum[0] <= 106 and 186 <= minimum[1] < maximum[1] <= 332):
        raise ValueError("Approved assembly does not fit the surveyed landing pad")
    if any(math.hypot(x, z) > 360 for x in (minimum[0], maximum[0]) for z in (minimum[1], maximum[1])):
        raise ValueError("Assembly would cross the battlefield boundary")
    report = {
        "version": 1,
        "blendSha256": digest(blend),
        "catalogSha256": digest(catalog),
        "axes": "One glTF unit per stud; source Blender (x, y, z) maps to (x, z, -y)",
        "locationStuds": SITE,
        "yawDegrees": YAW_DEGREES,
        "worldFootprintXZ": (minimum, maximum),
        "batches": batches,
    }
    (OUTPUT / "import-index.json").write_text(json.dumps(report, indent=2) + "\n")
    for batch in batches:
        print(f"{batch['file']}: {batch['expectedMeshParts']} pieces, {batch['bytes']:,} bytes")


if __name__ == "__main__":
    main()
