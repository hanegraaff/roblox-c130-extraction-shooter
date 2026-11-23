"""Stage the approved Salt Flats scene for native Studio calibration and import.

Run Blender's export_damage.py first. Imports are split by material and by
triangle budget without dropping triangles, vertex attributes, or image data.
The index keeps the original identity, local mesh bounds, authored pose,
material channels, and intended terrain/placement together for the native bind.
"""
from __future__ import annotations

from copy import deepcopy
import json
import math
from pathlib import Path
import struct
import sys
from typing import Iterator


sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from radar_outpost.prepare_import import Batch, ROOT, decode_glb, digest, source_bytes
from salt_flats.placement import audit_site

STAGING = ROOT / "build/salt-flats-import"
BLEND = ROOT / "assets/blender/plane-hangar/salt-flats-hangar.blend"
ASSEMBLY = ROOT / "assets/exports/plane-hangar/salt-flats-hangar.glb"
TRIANGLE_LIMIT = 20_000
BATCH_PART_LIMIT = 250
SITE = (-211, 0.125, -116)
YAW_DEGREES = 60
HILL_MOVES = {"TerrainHill00": [-99, -36, 180], "TerrainHill07": [-284, -32, 25]}
PILOT = {"Hardstand • jointed twin service apron", "Door W.L.1 • Pristine",
         "H01.1 • torn skin cassette"}


def rotate(point: list | tuple, quat: list | tuple) -> list[float]:
    """Rotate a glTF XYZ position by an XYZW unit quaternion."""
    x, y, z = point
    a, b, c, d = quat
    u, v, w = 2 * (b*z-c*y), 2 * (c*x-a*z), 2 * (a*y-b*x)
    return [x+d*u+b*w-c*v, y+d*v+c*u-a*w, z+d*w+a*v-b*u]


def pose_tree(doc: dict) -> dict[int, tuple[list[float], list[float], dict]]:
    """Flatten authored rigid transforms and inherit wreck or panel ownership."""
    poses = {}
    def visit(i, offset, rotation, extras):
        node = doc["nodes"][i]
        a,b,c,d = rotation
        x,y,z,w = node.get("rotation", (0,0,0,1))
        q = [d*x+a*w+b*z-c*y, d*y-a*z+b*w+c*x,
             d*z+a*y-b*x+c*w, d*w-a*x-b*y-c*z]
        if "matrix" in node or node.get("scale", [1,1,1]) != [1,1,1]:
            raise ValueError(f"Unexpected non-rigid Blender transform on {node['name']}")
        origin = [a+b for a,b in zip(offset, rotate(node.get("translation", (0,0,0)), rotation))]
        props = extras | node.get("extras", {})
        if i in poses:
            raise ValueError("A glTF node has multiple parents")
        poses[i] = origin, q, props
        for child in node.get("children", []):
            visit(child, origin, q, props)
    for root in doc["scenes"][doc.get("scene", 0)]["nodes"]:
        visit(root, [0,0,0], [0,0,0,1], {})
    return poses


def vertex_rows(doc: dict, blob: bytes | bytearray, i: int) -> Iterator[bytes]:
    """Iterate exact accessor components, accounting for interleaved views."""
    a = doc["accessors"][i]
    v = doc["bufferViews"][a["bufferView"]]
    widths = {5120: 1, 5121: 1, 5122: 2, 5123: 2, 5125: 4, 5126: 4}
    channels = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}
    size = widths[a["componentType"]] * channels[a["type"]]
    stride = v.get("byteStride", size)
    start = v.get("byteOffset", 0) + a.get("byteOffset", 0)
    for index in range(a["count"]):
        offset = start + index*stride
        yield bytes(blob[offset:offset+size])


def partition(source: dict, data: bytes) -> tuple[dict, bytes]:
    """Spatially divide oversized material primitives by triangle centroid."""
    doc, blob = deepcopy(source), bytearray(data)

    def add_accessor(template, rows, bounds=None):
        blob.extend(b"\0" * (-len(blob) % 4))
        start = len(blob)
        blob.extend(b"".join(rows))
        doc["bufferViews"].append({"buffer": 0, "byteOffset": start, "byteLength": len(blob)-start})
        item = {key: value for key,value in template.items() if key not in ("min","max","byteOffset")}
        item.update(bufferView=len(doc["bufferViews"])-1,count=len(rows))
        if bounds is not None:
            item["min"], item["max"] = bounds
        doc["accessors"].append(item)
        return len(doc["accessors"])-1

    for mesh in doc["meshes"]:
        result = []
        for primitive in mesh["primitives"]:
            ia = doc["accessors"][primitive["indices"]]
            n, remainder = divmod(ia["count"], 3)
            if not n or remainder or primitive.get("mode", 4) != 4:
                raise ValueError(f"Expected indexed triangles in {mesh['name']}")
            if n <= TRIANGLE_LIMIT:
                result.append(primitive)
                continue
            verts = {attr: list(vertex_rows(doc, blob, i)) for attr,i in primitive["attributes"].items()}
            positions = [struct.unpack("<3f", row) for row in verts["POSITION"]]
            axis = max(range(3), key=lambda i: max(p[i] for p in positions)-min(p[i] for p in positions))
            ix = [int.from_bytes(row,"little") for row in vertex_rows(doc,blob,primitive["indices"])]
            tris = list(zip(ix[::3], ix[1::3], ix[2::3]))
            tris.sort(key=lambda t: sum(positions[i][axis] for i in t))
            chunk_size = math.ceil(n / math.ceil(n / TRIANGLE_LIMIT))
            for start in range(0,n,chunk_size):
                faces = tris[start:start+chunk_size]
                order = dict.fromkeys(i for tri in faces for i in tri)
                remap = {old:new for new,old in enumerate(order)}
                bounds = [[op(positions[i][axis] for i in order) for axis in range(3)] for op in (min,max)]
                attrs = {attr:add_accessor(doc["accessors"][primitive["attributes"][attr]],
                                          [rows[i] for i in order],bounds if attr == "POSITION" else None)
                         for attr,rows in verts.items()}
                indices = add_accessor(ia | {"componentType":5125},
                                       [struct.pack("<I",remap[i]) for tri in faces for i in tri])
                result.append(primitive | {"attributes":attrs,"indices":indices})
        mesh["primitives"] = result
    return doc, bytes(blob)


class NativeBatch(Batch):
    """Reuse the repository's GLB dependency copier with Salt Flats naming."""

    def add(self, index, pose, role):
        doc = self.source
        node = doc["nodes"][index]
        origin, rotation, props = pose
        for ordinal, surface in enumerate(doc["meshes"][node["mesh"]]["primitives"], 1):
            name = f"SF_{self.prefix}_{index:03d}_{ordinal:02d}"
            material = doc["materials"][surface["material"]]
            position = doc["accessors"][surface["attributes"]["POSITION"]]
            data = surface | {
                "attributes": {key:self.dependency("accessors",val) for key,val in surface["attributes"].items()},
                "indices": self.dependency("accessors",surface["indices"]),
                "material": self.dependency("materials",surface["material"]),
            }
            self.out["scenes"][0]["nodes"].append(len(self.out["nodes"]))
            self.out["nodes"].append({"name":name,"mesh":len(self.out["meshes"]),
                                      "translation":origin,"rotation":rotation})
            self.out["meshes"].append({"name":name,"primitives":[data]})
            self.records.append({
                "importName":name, "sourceObject":node["name"], "sourceProperties":props,
                "role":role, "material":material["name"],
                "localMinimum":position["min"], "localMaximum":position["max"],
                "triangles":doc["accessors"][surface["indices"]]["count"]//3,
                "pose":{"translation":origin,"rotation":rotation},
            })


def batches(path, prefix, raw):
    original, data = decode_glb(raw)
    if len(original["scenes"]) != 1:
        raise ValueError(f"Expected one scene in {path}")
    poses = pose_tree(original)
    doc, data = partition(original, data)
    # Batch's copier expects standalone roots. Each selected pose is flattened
    # explicitly, and the original hierarchy remains represented in the index.
    doc["scenes"][0]["nodes"] = list(range(len(doc["nodes"])))
    pilot = NativeBatch(doc,data,"P") if prefix == "A" else None
    outputs = []
    active = NativeBatch(doc,data,f"{prefix}1")
    for i, node in enumerate(doc["nodes"]):
        if "mesh" not in node:
            continue
        props = poses[i][2]
        if props.get("DamageGroup") == "HerculesWreck":
            role = "wreck"
        elif "PanelId" in props:
            role = "panel"
        elif props.get("ThermalNonCover"):
            role = "dressing"
        else:
            role = "assembly"
        if pilot is not None and node["name"] in PILOT:
            pilot.add(i,poses[i],role)
            continue
        if len(active.records)+len(doc["meshes"][node["mesh"]]["primitives"]) > BATCH_PART_LIMIT:
            outputs.append(active)
            active = NativeBatch(doc,data,f"{prefix}{len(outputs)+1}")
        active.add(i,poses[i],role)
    outputs.append(active)
    if pilot is not None:
        if {row["sourceObject"] for row in pilot.records} != PILOT:
            raise ValueError("Pilot must include the hardstand, west door and wreck skin")
        outputs.insert(0,pilot)
    total = sum(r["triangles"] for output in outputs for r in output.records)
    expected = sum(original["accessors"][s["indices"]]["count"]//3 for node in original["nodes"]
                   if "mesh" in node for s in original["meshes"][node["mesh"]]["primitives"])
    if total != expected:
        raise ValueError("Import prep changed the original triangle count")
    return [batch.write(STAGING, f"salt-flats-{batch.prefix.lower()}.glb", digest(raw))
            for batch in outputs]


def main():
    manifest = {a["local_path"]:a.get("sha256") for a in
                json.loads((ROOT/"assets/manifest.json").read_text())["assets"]}
    blend = source_bytes(BLEND,manifest)
    assembly = source_bytes(ASSEMBLY,manifest)
    damage = STAGING/"hangar-states.glb"
    damage_bytes = damage.read_bytes()
    receipt = json.loads(damage.with_suffix(".json").read_text())
    if receipt != {"blendSha256": digest(blend), "glbSha256": digest(damage_bytes)}:
        raise ValueError("Regenerate the alternate states from the approved Blender source")
    sources = batches(ASSEMBLY, "A", assembly) + batches(damage, "D", damage_bytes)
    panels: dict[str, dict[str, tuple]] = {}
    for batch in sources:
        for record in batch["objects"]:
            props = record["sourceProperties"]
            if "PanelId" not in props or props.get("PanelDressing"):
                continue
            # Original assembly door numbers are mesh children of a panel.
            if " • " + props["Appearance"] not in record["sourceObject"]:
                continue
            state = panels.setdefault(props["PanelId"], {})
            pose = record["pose"]
            pivot = tuple(pose["translation"] + pose["rotation"])
            if state.setdefault(props["Appearance"], pivot) != pivot:
                raise ValueError(f"Multiple pivots for {props['PanelId']}")
    if len(panels) != 152:
        raise ValueError("Missing authored Salt Flats panel identities")
    for key, states in panels.items():
        if set(states) != {"Pristine", "Light", "Heavy"} or any(
            math.dist(pose, states["Pristine"]) > 0.001 for pose in states.values()
        ):
            raise ValueError(f"Missing or misaligned damage geometry for {key}")
    site_checks = audit_site(sources, SITE, YAW_DEGREES, HILL_MOVES, rotate)
    report = {
        "version":1, "blendSha256":digest(blend), "assemblySha256":digest(assembly),
        "placement":{"locationStuds":SITE,"yawDegrees":YAW_DEGREES,"hillMoves":HILL_MOVES, **site_checks},
        "units":"one glTF unit per stud, Y up, doors face +Z before placement",
        "batches":sources,
    }
    (STAGING/"import-index.json").write_text(json.dumps(report,indent=2)+"\n")
    for batch in sources:
        print(f"{batch['file']}: {batch['expectedMeshParts']} pieces, {batch['bytes']:,} bytes")


if __name__ == "__main__":
    main()
