"""Fit actual imported MeshPart receipts to exact approved source coordinates.

Receipt centers determine the whole-model similarity transform independently of
MeshPart local rotations. Every component must retain its unique source name,
finite rigid pose and source bounds. Nothing here uploads, mutates Studio or
replaces missing material appearance with a placeholder.
"""
from __future__ import annotations

import argparse
import itertools
import json
import math
from pathlib import Path
import sys

from p17_assets import ROOT, SOURCE, EXPORT, BLEND_SHA, PACKAGE_LOCK_SHA, approved_catalog, sha
from p17_library_glb import source_groups, mapped


def multiply(matrix: list, vector: list) -> list:
    return [sum(matrix[3 * row + column] * vector[column] for column in range(3)) for row in range(3)]


def transpose(matrix: list) -> list:
    return [matrix[3 * column + row] for row in range(3) for column in range(3)]


def product(a: list, b: list) -> list:
    return [sum(a[3 * row + index] * b[3 * index + column] for index in range(3))
            for row in range(3) for column in range(3)]


def determinant(matrix: list) -> float:
    a, b, c, d, e, f, g, h, i = matrix
    return a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g)


def finite(values: list, count: int) -> bool:
    return isinstance(values, list) and len(values) == count and all(
        isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value) for value in values)


def rigid(rotation: list) -> bool:
    identity = product(rotation, transpose(rotation))
    return all(abs(value - (1 if index in (0, 4, 8) else 0)) < 1e-4 for index, value in enumerate(identity)) and abs(determinant(rotation) - 1) < 1e-4


def source_metrics(root: Path = ROOT) -> dict:
    """Measure evaluated OBJ faces, never guessed raw-import origin/scale."""
    approved_catalog(root)
    inventory_path = root / SOURCE / "asset-inventory.json"
    source_path = root / EXPORT / "outpost-assembly-v1.obj"
    lock = json.loads((root / SOURCE / "package-lock.json").read_text())
    locked = {entry["path"]: entry["sha256"] for entry in lock["files"]}
    for path in (inventory_path, source_path):
        if locked.get(path.relative_to(root).as_posix()) != sha(path):
            raise ValueError("assembly normalization requires exact approved source geometry/inventory")
    inventory = json.loads(inventory_path.read_text())
    source_objects = {record["name"].replace(" ", "_"): record for record in inventory["objects"]
                      if record["collection"][:2] in ("01", "02", "03", "04", "05")}
    metrics = {}
    for (object_name, material), triangles in source_groups(source_path).items():
        if object_name not in source_objects:
            raise ValueError("assembly OBJ contains an object outside the approved inventory")
        record = metrics.setdefault(object_name, dict(points=[], materials=set(), triangles=0,
                                                       source_object=source_objects[object_name]["name"],
                                                       collection=source_objects[object_name]["collection"]))
        record["points"].extend(mapped(corner[0]) for triangle in triangles for corner in triangle)
        record["materials"].add(material)
        record["triangles"] += len(triangles)
    if set(metrics) != set(source_objects):
        raise ValueError("assembly OBJ/inventory object coverage differs")
    for record in metrics.values():
        points = record.pop("points")
        low = [min(point[axis] for point in points) for axis in range(3)]
        high = [max(point[axis] for point in points) for axis in range(3)]
        record.update(center=[(low[axis] + high[axis]) / 2 for axis in range(3)],
                      size=[high[axis] - low[axis] for axis in range(3)], materials=sorted(record["materials"]))
    return metrics


def rotations() -> list[list[int]]:
    """The 24 proper signed-axis transforms cover supported importer axis bases."""
    candidates = []
    for permutation in itertools.permutations(range(3)):
        for signs in itertools.product((-1, 1), repeat=3):
            rotation = [signs[row] if permutation[row] == column else 0 for row in range(3) for column in range(3)]
            if determinant(rotation) == 1:
                candidates.append(rotation)
    return candidates


def fit_similarity(source: list[list], observed: list[list]) -> dict:
    """Fit all matching centers; reject nonuniform scale/misplaced components."""
    if len(source) != len(observed) or len(source) < 4:
        raise ValueError("normalization fit requires four or more matched source centers")
    source_mean = [sum(point[axis] for point in source) / len(source) for axis in range(3)]
    observed_mean = [sum(point[axis] for point in observed) / len(observed) for axis in range(3)]
    centered_source = [[point[axis] - source_mean[axis] for axis in range(3)] for point in source]
    centered_observed = [[point[axis] - observed_mean[axis] for axis in range(3)] for point in observed]
    variance = sum(value * value for point in centered_source for value in point)
    if variance <= 0:
        raise ValueError("degenerate source centers cannot establish import axes")
    best = None
    for rotation in rotations():
        rotated = [multiply(rotation, point) for point in centered_source]
        scale = sum(sum(a * b for a, b in zip(point, other)) for point, other in zip(rotated, centered_observed)) / variance
        if not math.isfinite(scale) or scale <= 0:
            continue
        transformed_mean = multiply(rotation, source_mean)
        translation = [observed_mean[axis] - scale * transformed_mean[axis] for axis in range(3)]
        errors = [max(abs(other[axis] - translation[axis] - scale * multiply(rotation, point)[axis]) / scale
                      for axis in range(3)) for point, other in zip(source, observed)]
        candidate = dict(rotation=rotation, scale=scale, translation=translation, maximum_center_error_studs=max(errors))
        if best is None or candidate["maximum_center_error_studs"] < best["maximum_center_error_studs"]:
            best = candidate
    if best is None or best["maximum_center_error_studs"] > 1e-4:
        raise ValueError("import does not match one approved rigid/uniform similarity transform")
    return best


def normalize_assembly(receipt: dict, root: Path = ROOT) -> dict:
    """Normalize actual referenced geometry; missing textures remain explicit."""
    if receipt.get("schema_version") != 1 or receipt.get("approved_blend_sha256") != BLEND_SHA or receipt.get("source_fbx_path") != (EXPORT / "outpost-assembly-v1.fbx").as_posix():
        raise ValueError("mismatched approved assembly receipt identity")
    owner = receipt.get("upload_owner", {})
    if owner.get("type") not in ("User", "Group") or not str(owner.get("id", "")).isdigit() or int(owner["id"]) <= 0:
        raise ValueError("missing actual imported asset owner")
    manifest = json.loads((root / "assets/manifest.json").read_text())
    package = next(record for record in manifest["assets"] if record.get("local_path") == receipt["source_fbx_path"])
    if package.get("roblox_asset_id") != receipt.get("model_asset_id") or package.get("upload_owner") != f'{owner["type"]} {owner["id"]}':
        raise ValueError("assembly receipt package/owner differs from source manifest")
    components = receipt.get("components")
    if not isinstance(components, list) or receipt.get("mesh_count") != len(components):
        raise ValueError("invalid assembly receipt component count")
    metrics = source_metrics(root)
    by_name = {}
    for component in components:
        name = component["name"].replace(" ", "_")
        if name in by_name or name not in metrics:
            raise ValueError("duplicate/unknown imported assembly object identity")
        pose, size = component["cframe"], component["size"]
        if not finite(pose, 12) or not finite(size, 3) or not all(value > 0 for value in size) or not rigid(pose[3:]):
            raise ValueError("invalid imported assembly geometry/rotation")
        mesh_id = component.get("mesh_id", "")
        if not mesh_id.startswith("rbxassetid://") or not mesh_id[13:].isdigit() or int(mesh_id[13:]) <= 0:
            raise ValueError("missing actual imported assembly MeshId")
        by_name[name] = component
    if set(by_name) != set(metrics):
        raise ValueError("imported assembly does not cover every approved object exactly once")
    names = sorted(metrics)
    fit = fit_similarity([metrics[name]["center"] for name in names], [by_name[name]["cframe"][:3] for name in names])
    inverse = transpose(fit["rotation"])
    records, maximum_bounds_error = [], 0.0
    for name in names:
        source, component = metrics[name], by_name[name]
        local_rotation = product(inverse, component["cframe"][3:])
        local_size = [value / fit["scale"] for value in component["size"]]
        world_size = [sum(abs(local_rotation[3 * axis + column]) * local_size[column] for column in range(3)) for axis in range(3)]
        error = max(abs(world_size[axis] - source["size"][axis]) for axis in range(3))
        maximum_bounds_error = max(maximum_bounds_error, error)
        if error > 1e-4:
            raise ValueError(f"imported assembly bounds differ from approved object: {name}")
        records.append(dict(source, name=name, mesh_id=component["mesh_id"],
                            cframe=source["center"] + local_rotation, size=local_size,
                            raw_path=component["path"], texture_status="requires-source-material-repair"))
    landmarks = {name: metrics[name]["center"] for name in ("Exterior_balcony_landing", "Garage_roller_drum", "Upper_Main", "Foundation")}
    if landmarks["Exterior_balcony_landing"][0] <= 16 or landmarks["Garage_roller_drum"][2] <= 24:
        raise ValueError("asymmetric approved stairs/garage orientation changed")
    return dict(schema_version=1, approved_blend_sha256=BLEND_SHA, approved_package_lock_sha256=PACKAGE_LOCK_SHA,
                model_asset_id=receipt["model_asset_id"], revision_id=receipt["revision_id"],
                upload_owner=receipt["upload_owner"], workspace=receipt["workspace"], similarity=fit,
                maximum_bounds_error_studs=maximum_bounds_error, asymmetric_landmarks=landmarks,
                components=records, mesh_count=len(records), material_repair_complete=False)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--assembly", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    receipt = json.loads(args.assembly.read_text())
    normalized = normalize_assembly(receipt)
    normalized["raw_receipt_sha256"] = sha(args.assembly)
    normalized["normalizer_sha256"] = sha(Path(__file__))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(normalized, indent=2) + "\n")
    print(json.dumps({key: value for key, value in normalized.items() if key != "components"}, sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (ValueError, OSError, KeyError) as error:
        print(f"P17 import normalization failed: {error}", file=sys.stderr)
        sys.exit(1)
