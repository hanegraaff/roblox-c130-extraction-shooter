"""Emit native query probes tied to the Blender panel layout, in Roblox axes."""
import json
from math import hypot, sqrt
from pathlib import Path

from layout import BAYS, ROOF

ROOT = Path(__file__).resolve().parents[2]
CATALOG = ROOT / "assets/blender/radar-outpost/panel-catalog.json"


def pose(point):
    x, y, z = point
    return [x, z, -y]


def samples(record, bay):
    _, a, b, _ = bay
    span = hypot(b[0] - a[0], b[1] - a[1])
    axis = ((b[0] - a[0]) / span, (b[1] - a[1]) / span)
    outward = (axis[1], -axis[0])

    def wall(fraction, z):
        inset = .16 + .098 * min(z, 9.8) if z < 10 else 1.10
        return pose([(a[i] + b[i]) / 2 + axis[i] * fraction * span + outward[i] * (2.5 - inset)
                     for i in range(2)] + [z])

    def lip(point):
        x, y = point
        scale = 1 / sqrt((x / 24.1) ** 2 + (y / 17.6) ** 2)
        return x * scale, y * scale

    def roof(fraction):
        alpha = fraction + .5
        inner_a, inner_b = lip(a), lip(b)
        return pose([.47 * (a[i] * (1 - alpha) + b[i] * alpha)
                     + .53 * (inner_a[i] * (1 - alpha) + inner_b[i] * alpha)
                     for i in range(2)] + [ROOF + 4])

    if record["surface"] == "Roof":
        probes = [dict(origin=roof(at), direction=[0, -5.5, 0], kind=label)
                  for at, label in ((0, "center"), (-.38, "left"), (.38, "right"))]
    else:
        y = 8.58 if record["story"] == "01" else 17.63
        y_opening = 4.63 if record["story"] == "01" else 13.9
        probes = [dict(origin=wall(at, y), direction=pose([-5.5 * p for p in outward] + [0]), kind=label)
                  for at, label in ((0, "center"), (-.38, "left"), (.38, "right"))]
        probes.append(dict(origin=wall(.13, y_opening), direction=pose([-4.5 * p for p in outward] + [0]),
                           kind="aperture"))
    return dict(id=record["id"], probes=probes)


def main():
    bays = {bay[0]: bay for bay in BAYS}
    records = json.loads(CATALOG.read_text())["panels"]
    print(json.dumps([samples(record, bays[record["id"].split("_")[-1]]) for record in records],
                     separators=(",", ":")))


if __name__ == "__main__":
    main()
