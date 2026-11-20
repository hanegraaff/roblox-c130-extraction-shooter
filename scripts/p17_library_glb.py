"""Build/audit an equivalent P17 material-split GLB from approved P16 inputs.

Original Blender/FBX/OBJ/PNG files and their approval lock are never changed.
Every source triangle and corner UV survives, with explicit (X,Z,-Y) axes and
(U,1-V) UV conversion for glTF's top-left texture origin. One node/primitive per
source-object/material preserves material boundaries that the FBX upload lost.
The derivative excludes nonvisual proxy meshes; shared approved rectangles own
collision. --write creates managed derivative files, never uploads them.
glTF reference: https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html
"""
from __future__ import annotations

import argparse
from collections import OrderedDict
import hashlib
import json
import math
from pathlib import Path
import struct
import sys

from p17_assets import ROOT, SOURCE, EXPORT, BLEND_SHA, PACKAGE_LOCK_SHA, approved_catalog, sha

DESTINATION = Path("assets/imports/military-outpost")
GLB_PATH = DESTINATION / "panel-library-materials-v2.glb"
REPORT_PATH = DESTINATION / "panel-library-materials-v2.json"
MAX_BYTES = 20 * 1024 * 1024


def source_groups(path: Path) -> OrderedDict:
    """Read exact triangulated OBJ corner data, retaining material and winding."""
    vertices, uvs = [], []
    groups = OrderedDict()
    current_object = current_material = None
    for line in path.read_text().splitlines():
        fields = line.split()
        if not fields:
            continue
        tag = fields[0]
        if tag in ("v", "vt"):
            numbers = tuple(float(value) for value in fields[1:])
            if len(numbers) != (3 if tag == "v" else 2) or not all(math.isfinite(value) for value in numbers):
                raise ValueError(f"invalid finite OBJ coordinates: {path}")
            (vertices if tag == "v" else uvs).append(numbers)
        elif tag == "o":
            current_object = " ".join(fields[1:])
        elif tag == "usemtl":
            current_material = fields[1]
        elif tag == "f":
            if len(fields) != 4 or not current_object or not current_material:
                raise ValueError(f"OBJ requires named triangulated material faces: {path}")
            triangle = []
            for corner in fields[1:]:
                indices = corner.split("/")
                vi, ti = int(indices[0]) - 1, int(indices[1]) - 1
                if not 0 <= vi < len(vertices) or not 0 <= ti < len(uvs):
                    raise ValueError(f"invalid OBJ corner index: {path}")
                triangle.append((vertices[vi], uvs[ti]))
            groups.setdefault((current_object, current_material), []).append(tuple(triangle))
    return groups


def approved_inputs(root: Path) -> tuple[list[dict], list[dict]]:
    """Only hash-bound approved appearances/fragments/textures can enter output."""
    catalog = approved_catalog(root)
    lock = json.loads((root / SOURCE / "package-lock.json").read_text())
    locked = {entry["path"]: entry["sha256"] for entry in lock["files"]}
    materials = json.loads((root / EXPORT / "material-map.json").read_text())["materials"]
    def require_locked(relative: Path):
        if locked.get(relative.as_posix()) != sha(root / relative):
            raise ValueError(f"changed approved derivative input: {relative}")
    require_locked(EXPORT / "material-map.json")
    for material in materials:
        require_locked(EXPORT / material["base_color"])
    sources = []
    for family in catalog["families"]:
        for appearance, state in family["states"].items():
            sources.append(dict(family=family["id"], appearance=appearance,
                                source=state["mesh"], fragment_index=None))
        for index, fragment in enumerate(family["fragments"], 1):
            sources.append(dict(family=family["id"], appearance=None,
                                source=fragment["mesh"], fragment_index=index))
    for source in sources:
        path = EXPORT / source["source"]
        require_locked(path)
        source["source_sha256"] = sha(root / path)
    return sources, materials


def mapped(position: tuple) -> tuple:
    return position[0], position[2], -position[1]


def normal(triangle: tuple) -> tuple:
    a, b, c = [mapped(corner[0]) for corner in triangle]
    u, v = [b[i] - a[i] for i in range(3)], [c[i] - a[i] for i in range(3)]
    n = (u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0])
    length = math.sqrt(sum(value * value for value in n))
    return tuple(value / length for value in n) if length > 1e-12 else (0.0, 0.0, 1.0)


def build(root: Path = ROOT) -> tuple[bytes, dict]:
    sources, materials = approved_inputs(root)
    document = dict(asset=dict(version="2.0", generator="P17 approved OBJ material-split recipe v1"),
                    scene=0, scenes=[dict(nodes=[])], nodes=[], meshes=[], materials=[],
                    accessors=[], bufferViews=[], buffers=[], images=[], textures=[],
                    samplers=[dict(magFilter=9729, minFilter=9987, wrapS=10497, wrapT=10497)])
    binary = bytearray()
    def append(data: bytes, target: int | None = None) -> int:
        binary.extend(b"\0" * (-len(binary) % 4))
        view = dict(buffer=0, byteOffset=len(binary), byteLength=len(data))
        if target is not None:
            view["target"] = target
        index = len(document["bufferViews"])
        document["bufferViews"].append(view)
        binary.extend(data)
        return index
    def accessor(values: list[tuple], components: int, kind: str, component_type: int = 5126) -> int:
        packed = struct.pack("<" + ("f" if component_type == 5126 else "I") * (len(values) * components),
                             *(value for row in values for value in row))
        view = append(packed, 34963 if kind == "SCALAR" else 34962)
        entry = dict(bufferView=view, byteOffset=0, componentType=component_type, count=len(values), type=kind)
        if kind == "VEC3":
            entry.update(min=[min(row[axis] for row in values) for axis in range(3)],
                         max=[max(row[axis] for row in values) for axis in range(3)])
        result = len(document["accessors"])
        document["accessors"].append(entry)
        return result
    material_indices = {}
    texture_proof = []
    for index, material in enumerate(materials):
        png = (root / EXPORT / material["base_color"]).read_bytes()
        image_view = append(png)
        document["images"].append(dict(name=material["material"], bufferView=image_view, mimeType="image/png"))
        document["textures"].append(dict(sampler=0, source=index))
        document["materials"].append(dict(name=material["material"], doubleSided=True,
            pbrMetallicRoughness=dict(baseColorFactor=[1, 1, 1, 1], baseColorTexture=dict(index=index),
                                     metallicFactor=material["metalness"], roughnessFactor=material["roughness"])))
        material_indices[material["material"]] = index
        texture_proof.append(dict(material=material["material"], source=(EXPORT / material["base_color"]).as_posix(),
                                  sha256=hashlib.sha256(png).hexdigest(), bytes=len(png)))
    node_records, empty_sources = [], []
    triangle_count = 0
    for source in sources:
        groups = source_groups(root / EXPORT / source["source"])
        if not groups:
            if source["appearance"] != "Total":
                raise ValueError("non-Total approved source unexpectedly empty")
            empty_sources.append(source)
        for (source_object, material), triangles in groups.items():
            if material not in material_indices:
                raise ValueError(f"unknown approved material: {material}")
            points = [mapped(corner[0]) for triangle in triangles for corner in triangle]
            bounds_min = [min(point[axis] for point in points) for axis in range(3)]
            bounds_max = [max(point[axis] for point in points) for axis in range(3)]
            center = [(bounds_min[axis] + bounds_max[axis]) / 2 for axis in range(3)]
            positions, normals, coordinates, indices, lookup = [], [], [], [], {}
            for triangle in triangles:
                n = normal(triangle)
                for position, uv in triangle:
                    p = tuple(mapped(position)[axis] - center[axis] for axis in range(3))
                    t = (uv[0], 1 - uv[1])
                    key = p + n + t
                    if key not in lookup:
                        lookup[key] = len(positions)
                        positions.append(p); normals.append(n); coordinates.append(t)
                    indices.append((lookup[key],))
            label = source["appearance"] or f'Fragment{source["fragment_index"]:02d}'
            name = f'P17__{source["family"]}__{label}__{material}'
            primitive = dict(attributes=dict(POSITION=accessor(positions, 3, "VEC3"),
                                             NORMAL=accessor(normals, 3, "VEC3"),
                                             TEXCOORD_0=accessor(coordinates, 2, "VEC2")),
                             indices=accessor(indices, 1, "SCALAR", 5125), material=material_indices[material], mode=4)
            mesh_index = len(document["meshes"])
            node_index = len(document["nodes"])
            document["meshes"].append(dict(name=name, primitives=[primitive]))
            document["nodes"].append(dict(name=name, mesh=mesh_index, translation=center))
            document["scenes"][0]["nodes"].append(node_index)
            node_records.append(dict(source, node=name, source_object=source_object, material=material,
                                     triangles=len(triangles), center=center,
                                     size=[bounds_max[axis] - bounds_min[axis] for axis in range(3)]))
            triangle_count += len(triangles)
    document["buffers"] = [dict(byteLength=len(binary))]
    json_chunk = json.dumps(document, separators=(",", ":"), allow_nan=False).encode()
    json_chunk += b" " * (-len(json_chunk) % 4)
    binary.extend(b"\0" * (-len(binary) % 4))
    total = 12 + 8 + len(json_chunk) + 8 + len(binary)
    glb = (struct.pack("<III", 0x46546C67, 2, total) + struct.pack("<II", len(json_chunk), 0x4E4F534A)
           + json_chunk + struct.pack("<II", len(binary), 0x004E4942) + binary)
    report = dict(schema_version=1, recipe="approved-obj-material-split-v1", approved_blend_sha256=BLEND_SHA,
                  approved_package_lock_sha256=PACKAGE_LOCK_SHA, generator_sha256=sha(Path(__file__)),
                  glb_sha256=hashlib.sha256(glb).hexdigest(), glb_bytes=len(glb), axes=["X", "Z", "-Y"],
                  uv_mapping=["U", "1-V"], units="stud; no Roblox importer scale assumed",
                  triangulated_normals="flat geometric normals; no source triangles or UVs changed",
                  triangle_count=triangle_count, primitive_count=len(node_records), sources=len(sources),
                  nonempty_sources=len(sources)-len(empty_sources), empty_total_sources=empty_sources,
                  embedded_textures=texture_proof, used_materials=sorted({node["material"] for node in node_records}),
                  nodes=node_records, roblox_import_verified=False)
    if len(glb) >= MAX_BYTES or any(node["triangles"] > 20000 for node in node_records):
        raise ValueError("derivative exceeds file/per-mesh triangle budget")
    return glb, report


def decode_glb(data: bytes) -> tuple[dict, bytes]:
    """Independent container/accessor reader for auditing committed output bytes."""
    magic, version, total = struct.unpack_from("<III", data)
    if magic != 0x46546C67 or version != 2 or total != len(data):
        raise ValueError("invalid GLB header")
    json_length, json_kind = struct.unpack_from("<II", data, 12)
    offset = 20 + json_length
    binary_length, binary_kind = struct.unpack_from("<II", data, offset)
    if json_kind != 0x4E4F534A or binary_kind != 0x004E4942 or offset + 8 + binary_length != len(data):
        raise ValueError("invalid GLB chunks")
    return json.loads(data[20:offset]), data[offset + 8:]


def read_accessor(document: dict, binary: bytes, index: int) -> list[tuple]:
    entry = document["accessors"][index]
    view = document["bufferViews"][entry["bufferView"]]
    components = {"SCALAR": 1, "VEC2": 2, "VEC3": 3}[entry["type"]]
    fmt = {5126: "f", 5125: "I"}[entry["componentType"]]
    offset = view.get("byteOffset", 0) + entry.get("byteOffset", 0)
    length = entry["count"] * components * 4
    if offset < 0 or offset % 4 or view["buffer"] != 0 or length > view["byteLength"] or offset + length > len(binary):
        raise ValueError("invalid GLB accessor range/alignment")
    numbers = struct.unpack_from("<" + fmt * entry["count"] * components, binary, offset)
    return [numbers[i:i + components] for i in range(0, len(numbers), components)]


def audit_geometry(data: bytes, root: Path = ROOT) -> dict:
    """Compare decoded GLB triangles/UVs/materials/textures with approved inputs."""
    sources, materials = approved_inputs(root)
    expected = {}
    empty_count = 0
    for source in sources:
        groups = source_groups(root / EXPORT / source["source"])
        empty_count += not bool(groups)
        for (_, material), triangles in groups.items():
            label = source["appearance"] or f'Fragment{source["fragment_index"]:02d}'
            name = f'P17__{source["family"]}__{label}__{material}'
            expected[name] = (material, triangles)
    document, binary = decode_glb(data)
    if document.get("scene") != 0 or len(document.get("scenes", [])) != 1 or document["scenes"][0].get("nodes") != list(range(len(document["nodes"]))):
        raise ValueError("derivative active scene does not contain every source/material node")
    seen, triangle_count = set(), 0
    for node in document["nodes"]:
        name = node["name"]
        if name in seen or name not in expected or set(node) != {"name", "mesh", "translation"}:
            raise ValueError("unexpected/duplicate/transformed derivative node")
        seen.add(name)
        material, triangles = expected[name]
        primitives = document["meshes"][node["mesh"]]["primitives"]
        if len(primitives) != 1:
            raise ValueError("material derivative requires one primitive per node")
        primitive = primitives[0]
        if primitive["mode"] != 4 or document["materials"][primitive["material"]]["name"] != material:
            raise ValueError("derivative triangle mode/material changed")
        positions = read_accessor(document, binary, primitive["attributes"]["POSITION"])
        coordinates = read_accessor(document, binary, primitive["attributes"]["TEXCOORD_0"])
        normals = read_accessor(document, binary, primitive["attributes"]["NORMAL"])
        indices = read_accessor(document, binary, primitive["indices"])
        if len(indices) != len(triangles) * 3 or len(positions) != len(coordinates) or len(positions) != len(normals):
            raise ValueError("derivative triangle/vertex count changed")
        for i, triangle in enumerate(triangles):
            expected_normal = normal(triangle)
            for corner_index, (source_position, source_uv) in enumerate(triangle):
                vertex_index = indices[3 * i + corner_index][0]
                position = tuple(positions[vertex_index][axis] + node["translation"][axis] for axis in range(3))
                wanted = mapped(source_position)
                uv = coordinates[vertex_index]
                if not all(math.isclose(a, b, abs_tol=1e-5, rel_tol=1e-6) for a, b in zip(position, wanted)):
                    raise ValueError("derivative source triangle position/winding changed")
                if not all(math.isclose(a, b, abs_tol=1e-5, rel_tol=1e-6) for a, b in zip(uv, (source_uv[0], 1-source_uv[1]))):
                    raise ValueError("derivative source corner UV changed")
                if not all(math.isfinite(value) for value in normals[vertex_index]) or not math.isclose(sum(value**2 for value in normals[vertex_index]), 1, abs_tol=1e-5):
                    raise ValueError("invalid derivative geometric normal")
                if not all(math.isclose(a, b, abs_tol=1e-5) for a, b in zip(normals[vertex_index], expected_normal)):
                    raise ValueError("derivative geometric normal direction changed")
            triangle_count += 1
    if seen != set(expected):
        raise ValueError("missing derivative material/source node")
    if len(document["images"]) != len(materials) or len(document["materials"]) != len(materials):
        raise ValueError("derivative dropped approved material/image definitions")
    for index, material in enumerate(materials):
        image = document["images"][index]
        view = document["bufferViews"][image["bufferView"]]
        png = binary[view["byteOffset"]:view["byteOffset"] + view["byteLength"]]
        if image["mimeType"] != "image/png" or png != (root / EXPORT / material["base_color"]).read_bytes():
            raise ValueError("embedded derivative PNG differs from approved texture")
        pbr = document["materials"][index]["pbrMetallicRoughness"]
        if pbr != dict(baseColorFactor=[1, 1, 1, 1], baseColorTexture=dict(index=index),
                       metallicFactor=material["metalness"], roughnessFactor=material["roughness"]):
            raise ValueError("derivative PBR material mapping changed")
    return dict(primitives=len(seen), triangles=triangle_count, empty_total_sources=empty_count,
                embedded_textures=len(materials), positions_uvs_materials_textures_equivalent=True)


def verify(root: Path = ROOT) -> dict:
    generated, expected_report = build(root)
    data = (root / GLB_PATH).read_bytes()
    if data != generated or json.loads((root / REPORT_PATH).read_text()) != expected_report:
        raise ValueError("managed GLB/report differs from approved deterministic derivative recipe")
    detail = audit_geometry(data, root)
    return dict(suite="P17MaterialDerivative", discovered=1, passed=1, failed=0, skipped=0,
                glb_bytes=len(data), glb_sha256=hashlib.sha256(data).hexdigest(),
                used_materials=expected_report["used_materials"], **detail, roblox_import_verified=False)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()
    if args.write:
        glb, report = build()
        audit_geometry(glb)
        (ROOT / DESTINATION).mkdir(parents=True, exist_ok=True)
        (ROOT / GLB_PATH).write_bytes(glb)
        (ROOT / REPORT_PATH).write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(verify(), sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (ValueError, OSError, KeyError, struct.error) as error:
        print(f"P17 GLB derivative failed: {error}", file=sys.stderr)
        sys.exit(1)
