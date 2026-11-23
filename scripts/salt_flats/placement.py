"""Preflight the unscaled Foundry replacement against managed battlefield source.

All coordinates are studs. The conservative oriented footprints enclose the
hangar, apron and wreck (including its wings and ramp). Hill footprints are
their sphere intersections at the lowest exposed foundation, padded by one
terrain voxel per side. Studio still owns final voxel and avatar verification.
"""
from __future__ import annotations

import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FOOTPRINTS = {
    "hangar": (-107, 107, -74, 74),
    "apron": (-106, 106, 72, 144),
    "wreck": (-189, -31, 57, 191),
}


def footprint_gap(x, z, area):
    """Return distance between a point and a source-oriented rectangle."""
    left, right, near, far = area
    return math.hypot(max(left-x, 0, x-right), max(near-z, 0, z-far))


def audit_site(batches, site, yaw_degrees, hill_moves, rotate):
    """Return measured site anchors and clearances, or reject intersecting assets."""
    theta = math.radians(yaw_degrees)
    c,s = math.cos(theta),math.sin(theta)
    x0,y0,z0 = site
    def world(x,z):
        return x0+c*x+s*z, z0-s*x+c*z

    def local(x,z):
        return c*(x-x0)-s*(z-z0), s*(x-x0)+c*(z-z0)

    def envelope(bounds):
        corners = [local(x,z) for x in bounds[:2] for z in bounds[2:]]
        return tuple(f(p[i] for p in corners) for i in [0,1] for f in [min,max])

    world_data = json.loads((ROOT/"assets/world/Battlefield.model.json").read_text())
    roots = {item["Name"]:item for item in world_data["Children"]}
    checked = {"Town shelter":(-55,55,65,163), "Vesper Array":(127,193,-105,-55),
               "Military Outpost":(126,162,138,190)}
    for folder in ("Anchors","Routes","Breakable"):
        for item in roots[folder]["Children"]:
            properties = item["Properties"]
            x,_,z = properties["CFrame"][:3]
            sx,_,sz = properties["Size"]
            checked[item["Name"]] = (x-sx/2,x+sx/2,z-sz/2,z+sz/2)
    wreck_points = []
    for batch in batches:
        for row in batch["objects"]:
            if row["role"] != "wreck":
                continue
            pose = row["pose"]
            low, high = row["localMinimum"], row["localMaximum"]
            for x in (low[0], high[0]):
                for y in (low[1], high[1]):
                    for z in (low[2], high[2]):
                        point = rotate((x,y,z),pose["rotation"])
                        u,_,v = (a+b for a,b in zip(point,pose["translation"]))
                        wreck_points.append(world(u,v))
    wreck_world = tuple(f(p[i] for p in wreck_points) for i in (0,1) for f in (min,max))

    def overlap(first, second):
        a,b,d,e = first
        l,r,n,f = second
        return a < r and b > l and d < f and e > n

    for name, obstacle in checked.items():
        oriented = envelope(obstacle)
        for region, area in FOOTPRINTS.items():
            if region == "wreck" and not overlap(obstacle, wreck_world):
                continue
            if overlap(oriented, area):
                raise ValueError(f"Salt Flats {region} would overlap {name}")

    edge = max(math.hypot(*world(x,z)) for l,r,n,f in FOOTPRINTS.values()
               for x in (l,r) for z in (n,f))
    if edge > 348:
        raise ValueError("Salt Flats footprint must leave a 12-stud perimeter route")
    distances = {}
    for hill in roots["TerrainRecipe"]["Children"]:
        if hill["Name"] == "TerrainBounds":
            continue
        name = hill["Name"]
        props = hill["Properties"]
        x,y,z = hill_moves.get(name,props["CFrame"][:3])
        r = props["Size"][0]/2
        if math.hypot(x,z)+r >= 358 or y != props["CFrame"][1]:
            raise ValueError(f"{name} would escape the disk or change in elevation")
        foot = math.sqrt(r*r - (y + 1.3)**2)
        x,z = local(x,z)
        gap = min(footprint_gap(x,z,area)-foot for area in FOOTPRINTS.values())
        if gap < 4:
            raise ValueError(f"{name} would reach within one voxel of Salt Flats")
        distances[name] = round(gap,3)
    wreck_roots = {row["sourceObject"] for batch in batches for row in batch["objects"]
                   if row["role"] == "wreck"}
    if not any(source.startswith("H41") for source in wreck_roots) or len(wreck_roots) != 61:
        raise ValueError("Incomplete wreck assembly or missing cargo ramp")
    return {
        "minimumBoundaryGapStuds": round(360-edge,3),
        "minimumHillFootprintGapsStuds": distances,
        "mainDoorCentersStuds": [[round(x,3),y0,round(z,3)] for x,z in
                                (world(u,72.65) for u in [-52,52])],
        "wreckSourceObjects": len(wreck_roots),
        "requiredMaximumAimHeightStuds": 64,
    }
