"""Prepare source alignment targets for the Studio native binder."""
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
INDEX = ROOT / "build/vesper-import/import-index.json"
CATALOG = ROOT / "assets/blender/radar-outpost/panel-catalog.json"


def cross(a, b):
    return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]


def world_bounds(row):
    """Bound the source box after the native importer bakes node rotation."""
    from itertools import product

    quaternion = row["pose"].get("rotation", (0, 0, 0, 1))
    offset = row["pose"].get("translation", (0, 0, 0))
    corners = []
    for corner in product(*zip(row["localMinimum"], row["localMaximum"])):
        first = cross(quaternion[:3], corner)
        second = cross(quaternion[:3], first)
        corners.append([corner[i] + offset[i] + 2 * (quaternion[3] * first[i] + second[i])
                        for i in range(3)])
    ranges = [(min(axis), max(axis)) for axis in zip(*corners)]
    return ([round((low + high) / 2, 6) for low, high in ranges],
            [round(high - low, 6) for low, high in ranges])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("models", nargs=3, type=int, help="approved pilot, assembly and damage model IDs, in order")
    args = parser.parse_args()
    index = json.loads(INDEX.read_text())
    catalog = json.loads(CATALOG.read_text())
    rows = []
    for batch in index["batches"]:
        for row in batch["objects"]:
            center, size = world_bounds(row)
            rows.append(dict(key=row["importName"], meshName=row["meshName"],
                             sourceObject=row["sourceObject"], role=row["sourceProperties"]["role"],
                             material=row["material"], center=center, size=size))
    panels = []
    for record in catalog["panels"]:
        x, y, z = record["pivotXYZ"]
        states = record["states"]
        panels.append(dict(
            id=record["id"], pivot=[x, z, -y], pristineSource=states["Pristine"]["visual"],
            lightSource=states["Light"]["visual"], heavySource=states["Heavy"]["visual"],
            intactProxy=states["Pristine"]["solid"], heavyProxy=states["Heavy"]["solid"],
        ))
    config = dict(
        models=args.models, panels=panels, fragments=catalog["fragments"],
        colors={key: m["linearBaseColor"] for key, m in index["materials"].items() if "linearBaseColor" in m},
        source=index["blenderSha256"],
        receipts=[dict(modelId=asset_id, sha256=batch["sha256"], file=batch["file"])
                  for asset_id, batch in zip(args.models, index["batches"])],
    )
    canonical = json.dumps(config, sort_keys=True, separators=(",", ":")).encode()
    config["receipt"] = hashlib.sha256(canonical).hexdigest()
    destination = INDEX.parent
    (destination / "native-binding.json").write_text(json.dumps(config, separators=(",", ":")))
    for index in range(0, len(rows), 80):
        (destination / f"native-rows-{index // 80:02}.json").write_text(json.dumps(rows[index:index + 80],
                                                                               separators=(",", ":")))


if __name__ == "__main__":
    main()
