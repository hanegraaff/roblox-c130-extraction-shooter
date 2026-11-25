"""Prepare the P22 primitive floor, wall and furniture collision from the approved P21 layout.

One Blender unit is one stud. Blender (x, y, z) maps to Roblox (520 + x, z, -y).
Mesh visuals have their own managed source and should not duplicate the collision.
Run with --check to compare the authored recipe without modifying files.
"""

import argparse
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CATALOG = ROOT / "assets/blender/lobby-interior/assembly.json"
OUTPUT = ROOT / "assets/imports/lobby-interior/LobbyCollision.model.json"

ROOMS = {
    "Main": ("Main", 28.5),
    "Theater": ("Movie Theater", 21),
    "Gallery": ("Art Gallery", 19.2),
}


def rounded(values):
    """Remove tiny trigonometric residues from canonical CFrame components."""
    return [round(value, 8) or 0 for value in values]


def part(name, center, size, angle=0, *, cylinder=False):
    """Build one protected collider in approved Blender coordinates and dimensions."""
    x, y, z = center
    width, depth, height = size
    cosine, sine = math.cos(angle), math.sin(angle)
    rotation = [cosine, 0, sine, 0, 1, 0, -sine, 0, cosine]
    if cylinder:
        # The Roblox cylinder's local X axis is its height.
        rotation = [0, -1, 0, 1, 0, 0, 0, 0, 1]
        dimensions = [height, width, depth]
    else:
        dimensions = [width, height, depth]
    return {
        "Name": name,
        "ClassName": "Part",
        "Properties": {
            "Anchored": True,
            "CanCollide": True,
            "CanQuery": True,
            "CanTouch": False,
            "CastShadow": False,
            "Transparency": 1,
            "Shape": "Cylinder" if cylinder else "Block",
            "Size": rounded(dimensions),
            "CFrame": rounded([520 + x, z, -y, *rotation]),
            "TopSurface": "Smooth",
            "BottomSurface": "Smooth",
        },
    }


def box_between(name, low, high):
    """Build an axis-aligned box from opposed Blender-space corners."""
    center = [(a + b) / 2 for a, b in zip(low, high)]
    size = [b - a for a, b in zip(low, high)]
    return part(name, center, size)


def north_south_wall(name, x0, x1, y, height):
    """A wall running east–west, with slight end overlap to seal corner joints."""
    return box_between(name, (x0 - .3, y - .3, 0), (x1 + .3, y + .3, height))


def east_west_wall(name, x, y0, y1, height, *, bottom=0):
    """A wall running north–south, or a header with clearance below it."""
    return box_between(name, (x - .3, y0, bottom), (x + .3, y1, height))


def shared_wall(name, x, extent, opening):
    """Add both jambs and one header while leaving the finished aperture open."""
    y0, y1, height = extent
    door_y, door_width, door_height = opening
    low, high = door_y - door_width / 2, door_y + door_width / 2
    return [
        east_west_wall(name + "South", x, y0, low, height),
        east_west_wall(name + "North", x, high, y1, height),
        east_west_wall(name + "Header", x, low, high, height, bottom=door_height),
    ]


def floors_and_shells(catalog):
    floors, shells = [], []
    for room, (label, height) in ROOMS.items():
        x0, y0, x1, y1 = catalog["floor_limits_blender_xy"][label]
        floors.append(box_between("LobbyFloor" + room, (x0, y0, -1), (x1, y1, 0)))
        shells.append(box_between("Lobby" + room + "Ceiling", (x0, y0, height), (x1, y1, height + .6)))
        shells.extend([
            north_south_wall("Lobby" + room + "SouthWall", x0, x1, y0, height),
            north_south_wall("Lobby" + room + "NorthWall", x0, x1, y1, height),
        ])
        if room != "Main":
            outside_x = x0 if room == "Theater" else x1
            shells.append(east_west_wall("Lobby" + room + "OuterWall", outside_x, y0, y1, height))

    # The collision in each jamb tapers into the visual trim at body height. The
    # header begins at the finished center headroom measured in the approved P21.
    for side, (x, y, _) in zip(("West", "East"), catalog["door_centers_blender"]):
        wall = "Lobby" + side + "Portal"
        shells.extend(shared_wall(wall, x, (-13, 49, 28.5), (y, 15.74, 14.375)))
    # The theater extends one stud beyond the main hall's north end.
    shells.append(east_west_wall("LobbyTheaterNortheastReturn", -25, 49, 50, 21))
    return floors, shells


def furnishings():
    """Use solid body-sized profiles for furniture, retaining all visual passage widths."""
    parts = [
        part("LobbyDaisStep", (0, 31.5, .31), (17.17, 17.17, .62), cylinder=True),
        part("LobbyDaisDrum", (0, 31.5, 1.635), (16.36, 16.36, 2.03), cylinder=True),
        part("LobbyGalleryBench", (45, 29, 1.045), (12.55, 2.55, 2.09), -.23 * math.pi),
        part("LobbyTelevisionTable", (-47.5, 45.65, 1.9125), (15.15, 5.36, 3.825)),
        part("LobbyTelevisionCabinet", (-47.5, 45.65, 7.655), (11.10, 3.30, 7.34)),
    ]
    # The pedestal and bust are protected individually. The narrower upper
    # volumes keep broad character clearance beside the round stone plinth.
    parts.extend([
        part("LobbyBustFoot", (0, 31.5, 3.32), (12.1, 12.1, 1.34), cylinder=True),
        part("LobbyBustTorso", (0, 31.5, 7.6), (13.9, 7.35, 7.28)),
        part("LobbyBustHead", (0, 31.15, 15), (7.0, 6.1, 7.52)),
    ])

    for label, side in (("Left", -1), ("Right", 1)):
        parts.extend([
            part("LobbyWaitingBench" + label, (side * 11.7, 46.4, 1.745), (7.67, 2.63, 3.49)),
            part("LobbyArrivalBench" + label, (side * 13.4, 4.3, 1.045), (6.42, 2.55, 2.09), math.pi / 2),
        ])
        for name, x, y, scale in (
            ("MainPlanter", side * 20.7, 44.8, 1.05),
            ("ArrivalPlanter", side * 13.4, 9.3, .91),
            ("TheaterPlanter", -47.5 + side * 15.5, 46.3, .84),
        ):
            parts.append(part(
                "Lobby" + name + label, (x, y, scale * 1.18),
                (scale * 2.58, scale * 2.58, scale * 2.36), cylinder=True,
            ))

    for row in range(4):
        y = 15.6 + row * 5.78
        for label, side in (("Left", -1), ("Right", 1)):
            for seat in range(3):
                x = -47.5 + side * (6.05 + seat * 3.27)
                name = f"LobbyTheaterSeat{row + 1}{label}{seat + 1}"
                parts.append(part(name + "Base", (x, y - .22, 1.17), (3.12, 2.78, 2.34)))
                parts.append(part(name + "Back", (x, y - 1.085, 3.105), (2.71, .68, 1.53)))
    return parts


def folder(name, items):
    return {"Name": name, "ClassName": "Folder", "Children": items}


def collision_model(catalog):
    floors, shells = floors_and_shells(catalog)
    return {"ClassName": "Folder", "Children": [
        folder("LobbyFloors", floors),
        folder("LobbyShells", shells),
        folder("LobbyFurnishings", furnishings()),
    ]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="verify the committed collision recipe")
    args = parser.parse_args()
    data = collision_model(json.loads(CATALOG.read_text()))
    encoded = json.dumps(data, indent=2) + "\n"
    if args.check:
        if OUTPUT.read_text() != encoded:
            raise SystemExit("P22 collision does not match the approved layout recipe")
    else:
        OUTPUT.write_text(encoded)
    print("P22 collision recipe:", ", ".join(
        f"{len(section['Children'])} {section['Name']}" for section in data["Children"]
    ))


if __name__ == "__main__":
    main()
