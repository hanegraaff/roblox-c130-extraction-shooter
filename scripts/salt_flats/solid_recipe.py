"""Derive Salt Flats panel and wreck proxy shapes in source Roblox studs.

Heavy uses the authored residual bands. Panel sashes retain their apertures,
and separate glass and frame solids reconstruct the authored roof openings.
Gables use conservative ascending strips under the silhouette. The wreck's
curved sides use thin plates along its faceted shell, with its ramp and deck
supplied by walk_surfaces.py.
"""
from __future__ import annotations

import math


def box(key, center, size, u=(1, 0, 0), v=(0, 1, 0)):
    """Describe an oriented Roblox Part with local X/Y axes u/v."""
    return {"key": key, "center": center, "size": size, "u": u, "v": v}


def panel_boxes(key, pivot, heavy):
    """Generate aligned authoritative solids for an authored panel state."""
    family, *fields = key.split()
    bands = [(0, 0.23), (0.75, 1)] if heavy else [(0, 1)]
    origin = pivot
    window = False
    roof = family == "Roof"
    gable = family == "Gable"
    if family == "Side":
        side, label = fields
        bay, level = map(int, label.split("."))
        window = level in (2, 4) and bay % 3 != 0
        u = (0, 0, -1) if side == "E" else (0, 0, 1)
        v, width, height = (0, 1, 0), 24, 12
    elif family == "Rear":
        bay, level = map(int, fields[0].split("."))
        window = level > 1 and bay % 2 == 0
        u, v, width, height = (-1, 0, 0), (0, 1, 0), 26, 12
    elif family == "Door":
        u, v, width, height = (1, 0, 0), (0, 1, 0), 10.7, 12
    elif roof:
        _, side, bay = fields[0].split(".")
        sign = -1 if side == "L" else 1
        width, height = math.hypot(52, 14), 24
        u, v = (52 * sign / width, -14 / width, 0), (0, 0, -1)
        window = int(bay) in (2, 4, 6)
    elif gable:
        wall, bay, _ = fields[0].split(".")
        peak = -52 if bay == "W" else 52
        left_edge = pivot[0] - 6.5
        u, v, width, height = (1, 0, 0), (0, 1, 0), 13, 14
        bands = [(0, 0.23), (0.77, 1)] if heavy else [(0, 1)]
        origin = [pivot[0], 47.99 + height / 2, pivot[2]]
    else:
        raise ValueError(f"Unknown Salt Flats panel {key}")

    def add(result, left, right, bottom, top, thickness=0.28, offset=None):
        if right - left < 0.0001 or top - bottom < 0.0001:
            return
        normal = (u[1]*v[2]-u[2]*v[1], u[2]*v[0]-u[0]*v[2], u[0]*v[1]-u[1]*v[0])
        # On a left roof slope the authored cover still extrudes down.
        exterior = -1 if (roof and normal[1] < 0) or (gable and wall == "Rear") else 1
        depth = -exterior * 0.14 if offset is None else offset
        center = [origin[i] + u[i] * width * ((left + right) / 2 - 0.5)
                  + v[i] * height * ((bottom + top) / 2 - 0.5)
                  + normal[i] * depth for i in range(3)]
        result.append(box(f"Proxy{len(result) + 1:02d}", center,
                          [(right-left)*width, (top-bottom)*height, thickness], u, v))

    result = []
    if gable:
        for lo, hi in bands:
            count = math.ceil(12 * (hi - lo))
            for i in range(count):
                a = lo + (hi-lo)*i/count
                b = lo + (hi-lo)*(i+1)/count
                high = min(62 - 14 * abs(left_edge + 13*x - peak) / 52 for x in (a, b))
                add(result, a, b, 0, (high - 47.99) / height)
        return result

    for lo, hi in bands:
        sections = [(0, 1, 0, 1)] if not window else [
            (0, 0.16, 0, 1), (0.84, 1, 0, 1), (0.16, 0.84, 0, 0.16), (0.16, 0.84, 0.85, 1),
        ]
        for left, right, bottom, top in sections:
            add(result, max(lo, left), min(hi, right), bottom, top)
        if not window:
            continue
        if roof:
            for left in (0.16, 0.33, 0.50, 0.67):
                add(result, max(lo, left+0.004), min(hi, left+0.165), 0.17, 0.84)
        for mullion in (0.16, 0.33, 0.50, 0.67, 0.84):
            if lo <= mullion <= hi:
                add(result, max(lo, mullion-0.09/width), min(hi, mullion+0.09/width),
                    0.16, 0.85, 0.31, 0)
        for rail in (0.16, 0.50, 0.85):
            add(result, max(lo, 0.16), min(hi, 0.84), rail-0.095/height,
                rail+0.095/height, 0.31, 0)
    return result


def wreck_skin():
    """Approximate the original curved cargo hull with thin faceted slabs."""
    result = []
    # Follows the first six transverse stations from the original wreck.
    stations = [(-37.0, 10.43, 10.12, 10.5), (-30, 10.6, 10.2, 10.5),
                (-17, 10.65, 10.3, 10.6), (0, 10.7, 10.3, 10.65),
                (14, 10.5, 10.1, 10.64), (25, 9.8, 9.5, 10.85),
                (28.1, 9.21, 9.05, 11.11)]
    for strip, (a, b) in enumerate(zip(stations, stations[1:])):
        full_length = b[0] - a[0]
        y, r, h, z = [(x+y)/2 for x,y in zip(a,b)]
        for face in range(18):
            s = math.radians(-137 + 274*face/18)
            t = math.radians(-137 + 274*(face+1)/18)
            p = (r*math.sin(s), z+h*math.cos(s))
            q = (r*math.sin(t), z+h*math.cos(t))
            dx, dy = q[0]-p[0], q[1]-p[1]
            span = math.hypot(dx, dy)
            center = [(p[0]+q[0])/2, (p[1]+q[1])/2, -y]
            result.append(box(f"Hull{strip + 1}_{face + 1:02d}", center,
                              [span+0.18, full_length+0.05, 0.5], (dx/span, dy/span, 0), (0, 0, 1)))
    result.append(box("AftBulkhead", [0, 9.4, -28], [14.5, 12.4, 0.4]))
    return result
