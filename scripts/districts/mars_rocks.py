"""Place boulders and talus at authored mesas without blocking the ship or trails."""
import json
import math
from pathlib import Path
import random

import layout

ROOT = layout.ROOT
CLUSTERS = [(-178, 264, 9), (-221, 240, 11), (-127, 291, 8),
            (-165, 207, 6), (-104, 342, 4), (126, 273, 10),
            (143, 229, 6), (108, 309, 6), (152, 253, 6),
            (-122, 205, 4), (76, 177, 3)]
COLORS = [(127, 67, 51), (150, 79, 60), (162, 88, 62),
          (143, 88, 67), (163, 102, 74), (111, 66, 57)]


def can_place(x, z, reach):
    """Exclude the full rotated bounds from the reserve, map edge and trails."""
    left, right, north, south = layout.RESERVE
    if left-reach <= x <= right+reach and north-reach <= z <= south+reach:
        return False
    if math.hypot(x, z) + reach > 351:
        return False
    return all(layout.line_distance(x,z,a,b) > reach+9 for a,b in layout.SEGMENTS)


def placements():
    rng = random.Random(4197)
    result = []
    for center_x, center_z, height in CLUSTERS:
        for index in range(9):
            angle = rng.uniform(0, math.tau)
            radius = rng.uniform(4, 18) if index else 0
            x, z = center_x + math.cos(angle)*radius, center_z + math.sin(angle)*radius
            scale = height if index == 0 else height*rng.uniform(.13, .51)
            width, depth = scale*rng.uniform(1.17, 1.70), scale*rng.uniform(.9, 1.38)
            reach = math.hypot(width, depth, scale)/2
            if not can_place(x, z, reach):
                continue
            # Closely match the material at the biome fringe.
            color = rng.choice(COLORS)
            mix = layout.martian_weight(x, z)
            color = [round(channel*mix + sand*(1-mix)) for channel,sand in zip(color,(173,135,98))]
            elevation = layout.relief(x,z)
            result.append({
                "x": x, "z": z, "height": scale, "width": width, "depth": depth,
                "yaw": rng.uniform(0,360), "pitch": rng.uniform(-8,13), "roll": rng.uniform(-12,9),
                "elevation": elevation, "bury": min(1.5, .45*scale),
                "color": color, "solid": scale >= 3.6,
            })
    return result


def main():
    """Print an Edit-mode command that stages the detached native model."""
    compiler = Path(__file__).with_suffix(".luau").read_text()
    print("local function compile()\n" + compiler + "\nend")
    print("local placements = game:GetService('HttpService'):JSONDecode([==[" + json.dumps(placements()) + "]==])")
    print("""local rockBank = compile()(workspace.World.Battlefield.DistrictScenery, placements)
local bytes = game:GetService('SerializationService'):SerializeInstancesAsync({rockBank})
rockBank:Destroy()
return buffer.tostring(game:GetService('EncodingService'):Base64Encode(bytes))""")


if __name__ == "__main__":
    main()
