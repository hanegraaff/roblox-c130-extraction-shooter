"""Build uniquely named, material-split candidates for Roblox Studio import.

The staged Blender round trip remains the geometry baseline. This derivative
keeps its binary accessors, images, transformations and panel associations.
Only generated files under build/sandbreak-import are written.
"""

from copy import deepcopy
import json
import math
from pathlib import Path
import struct
import sys

SCRIPTS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS))

from radar_outpost.prepare_import import Batch, ROOT, decode_glb, digest
from salt_flats.prepare_import import pose_tree, rotate, vertex_rows

STAGING = ROOT / "build/sandbreak-import"
MAX_PARTS = 240


class SandbreakBatch(Batch):
    """Address individual material slots through distinct Studio mesh names."""

    def add_node(self, node_index, pose, records):
        original = self.source["nodes"][node_index]
        name = original["name"]
        origin, rotation, props = pose
        mesh = self.source["meshes"][original["mesh"]]
        for ordinal, surface in enumerate(mesh["primitives"], 1):
            key = f"{name}_{ordinal:02d}"
            primitive = deepcopy(surface)
            primitive["attributes"] = {
                semantic: self.dependency("accessors", accessor)
                for semantic, accessor in surface["attributes"].items()
            }
            primitive["indices"] = self.dependency("accessors", surface["indices"])
            material = None
            if "material" in surface:
                material = self.source["materials"][surface["material"]]
                primitive["material"] = self.dependency("materials", surface["material"])

            position = surface["attributes"]["POSITION"]
            local_points = [struct.unpack("<fff", row) for row in vertex_rows(self.source, self.binary, position)]
            points = [tuple(a + b for a, b in zip(origin, rotate(vertex, rotation))) for vertex in local_points]
            axes = tuple(zip(*points))
            low, high = ([round(extreme(axis), 6) for axis in axes] for extreme in (min, max))
            mesh_index = len(self.out["meshes"])
            self.out["meshes"].append({"name": key, "primitives": [primitive]})
            self.out["scenes"][0]["nodes"].append(len(self.out["nodes"]))
            self.out["nodes"].append({
                "name": key,
                "mesh": mesh_index,
                "translation": origin,
                "rotation": rotation,
            })
            triangles, remainder = divmod(self.source["accessors"][surface["indices"]]["count"], 3)
            if remainder or not 0 < triangles <= 20_000:
                raise ValueError(f"Invalid triangle count for {key}")
            pbr = material["pbrMetallicRoughness"] if material else {}
            self.records.append({
                "importName": key,
                "sourceObject": records[name],
                "sourceProperties": props,
                "material": material["name"] if material else "query",
                "expectsColorMap": "baseColorTexture" in pbr,
                "triangles": triangles,
                "localMinimum": self.source["accessors"][position]["min"],
                "localMaximum": self.source["accessors"][position]["max"],
                "posedMinimum": low,
                "posedMaximum": high,
                "pose": {"translation": origin, "rotation": rotation},
            })


def color_data(doc, blob, primitive):
    """Return the bytes of the material's embedded base color, if present."""
    material = doc["materials"][primitive["material"]]["pbrMetallicRoughness"]
    texture = doc["textures"][material["baseColorTexture"]["index"]]
    image = doc["images"][texture["source"]]
    view = doc["bufferViews"][image["bufferView"]]
    offset = view.get("byteOffset", 0)
    return blob[offset:offset + view["byteLength"]]


def verify_derivative(batch, original_doc, original_binary, native_path):
    """Compare every exported corner attribute and embedded material dependency."""
    prepared, binary = decode_glb(native_path.read_bytes())
    sources = {node["name"]: node for node in original_doc["nodes"]}
    for name, node in zip(batch.records, prepared["nodes"], strict=True):
        source_key, ordinal = node["name"].rsplit("_", 1)
        source = original_doc["meshes"][sources[source_key]["mesh"]]["primitives"][int(ordinal) - 1]
        deriv, = prepared["meshes"][node["mesh"]]["primitives"]
        if node["name"] != name["importName"] or any(
            node[axis] != name["pose"][axis] for axis in ("rotation", "translation")
        ):
            raise ValueError(f"Native names or poses changed: {node['name']}")
        for attr, index in (source["attributes"] | {"indices": source["indices"]}).items():
            mapped = deriv["indices"] if attr == "indices" else deriv["attributes"][attr]
            if list(vertex_rows(original_doc, original_binary, index)) != list(vertex_rows(prepared, binary, mapped)):
                raise ValueError(f"Native {attr} changed: {node['name']}")
        if name["expectsColorMap"]:
            if color_data(original_doc, original_binary, source) != color_data(prepared, binary, deriv):
                raise ValueError(f"Native color map changed: {node['name']}")


def check_site(index):
    """Check authored anchors, playable disk and active hill footprint in source space."""
    world = json.loads((ROOT / "assets/world/Battlefield.model.json").read_text())
    roots = {item["Name"]: item for item in world["Children"]}
    origin = index["siteOriginRoblox"]
    anchors = {}
    for item in roots["Anchors"]["Children"]:
        if item["Name"].startswith("Ground"):
            pos = item["Properties"]["CFrame"][:3]
            anchors[item["Name"]] = [axis - offset for axis, offset in zip(pos, origin)]
    expected = {(x, 3, z) for x in (-20, 0, 20) for z in (-12, 0, 12)}
    if len(anchors) != 9 or {tuple(pos) for pos in anchors.values()} != expected:
        raise ValueError("The source map's deployment anchors differ from the approved shelter grid")
    active_hills = {"TerrainHill00": (-99, -36, 180), "TerrainHill07": (-284, -32, 25)}
    hill_clearances = {}
    objects = [item for item in index["objects"].values()
               if item["kind"] in {"query-solid", "structure", "attached-art", "hall-dressing"}
               or item["kind"].startswith("yard-")]
    rectangles = [
        [low[0] + origin[0], high[0] + origin[0], low[2] + origin[2], high[2] + origin[2]]
        for low, high in (item["bounds"] for item in objects)
    ]
    edge = max(math.hypot(x, z) for left, right, near, far in rectangles
               for x in (left, right) for z in (near, far))
    if edge > 348:
        raise ValueError("Sandbreak is too close to the playable disk boundary")
    for item in roots["TerrainRecipe"]["Children"]:
        name = item["Name"]
        if not name.startswith("TerrainHill"):
            continue
        properties = item["Properties"]
        x, y, z = active_hills.get(name, properties["CFrame"][:3])
        radius = properties["Size"][0] / 2
        # Use the circular cut at ground level plus one voxel of allowance.
        cut = math.sqrt(radius ** 2 - y ** 2)
        gap = min(math.hypot(max(left - x, 0, x - right), max(near - z, 0, z - far))
                  for left, right, near, far in rectangles) - cut
        if gap < 4:
            raise ValueError(f"Sandbreak is within one terrain voxel of {name}: {gap:.2f} studs")
        hill_clearances[name] = round(gap, 3)
    return {
        "floorPivot": origin,
        "spawnAnchorsRelative": anchors,
        "routeCenters": {item["Name"]: item["Properties"]["CFrame"][:3]
                         for item in roots["Routes"]["Children"]},
        "boundaryGapStuds": round(360 - edge, 3),
        "terrainGapStuds": hill_clearances,
    }


def main():
    index_bytes = (STAGING / "import-index.json").read_bytes()
    index = json.loads(index_bytes)
    round_trip = json.loads((STAGING / "round-trip.json").read_text())
    source_hash = digest((ROOT / index["source"]).read_bytes())
    if source_hash != index["sourceSha256"] or source_hash != round_trip["sourceSha256"]:
        raise ValueError("The staged source revision has no matching Blender round trip")
    result = {
        "sourceSha256": index["sourceSha256"],
        "stagingIndexSha256": digest(index_bytes),
        "site": check_site(index),
        "batches": [],
    }
    paths = {}
    for source, row in index["objects"].items():
        for filename, node in row["exports"].items():
            paths.setdefault(filename, {})[node] = source
    for filename, sha256 in sorted(index["files"].items()):
        path = STAGING / filename
        raw = path.read_bytes()
        if digest(raw) != sha256:
            raise ValueError(f"Staged GLB hash changed: {path}")
        original, binary = decode_glb(raw)
        poses = pose_tree(original)
        if set(paths[filename]) != {node["name"] for node in original["nodes"]}:
            raise ValueError(f"Staged Blender nodes differ from receipt: {path}")
        batch = SandbreakBatch(original, binary, path.stem)
        batch.out["asset"]["generator"] = "Sandbreak Roblox import preparation"
        for node_index in poses:
            batch.add_node(node_index, poses[node_index], paths[filename])
        if len(batch.records) > MAX_PARTS:
            raise ValueError(f"Native batch exceeds {MAX_PARTS} parts: {path}")
        native_name = f"sandbreak-native-{filename}"
        output = batch.write(STAGING, native_name, sha256)
        verify_derivative(batch, original, binary, STAGING / native_name)
        output["basis"] = "GLB X/Y/Z in studs, relative to site floor pivot. Measure native axis signs in pilot."
        result["batches"].append(output)
    (STAGING / "native-index.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    triangles = sum(row["triangles"] for batch in result["batches"] for row in batch["objects"])
    print(f"Native preflight passed: {len(result['batches'])} GLBs, "
          f"{sum(len(batch['objects']) for batch in result['batches'])} named mesh uses, "
          f"{triangles} triangles including the pilot")
    print(f"Start with {STAGING / 'sandbreak-native-pilot.glb'}")


if __name__ == "__main__":
    main()
