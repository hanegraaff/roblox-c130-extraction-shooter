"""Source-space collision boxes for the authored hangar and wreck walking surfaces.

Each box is described in Roblox axes before the Foundry site transform. Wreck
boxes first use the wreck's own axis conversion, then inherit its GLB root pose.
Floor faces come from the Blender assembly. Cosmetic millwork remains separate.
"""
from __future__ import annotations

import math


def walk_surfaces() -> dict:
    """Return deterministic floor, stair, and ramp proxies in source studs."""
    hangar = []
    wreck = []

    def add(owner, key, center, size, pitch=0):
        owner.append({"key": key, "center": center, "size": size, "pitchDegrees": pitch})

    add(hangar, "GroundFloor", [0, -0.71, 0], [209, 1.42, 145])
    add(hangar, "Apron", [0, -0.53, 108], [212, 1, 72])
    for floor in range(1, 4):
        height = floor * 12
        add(hangar, f"Gallery{floor + 1}", [0, height - 0.43, -64.5], [206, 0.86, 13.8])
        for side, sign in [("W", -1), ("E", 1)]:
            add(hangar, f"{side}{floor}_Landing", [sign * 92, height - 6.3, -36.4],
                [19.2, 0.6, 5.3])
            for flight in range(2):
                start, end = (58, 39) if flight == 0 else (39, 58)
                base = height - 12 + flight * 6
                x = sign * (97 if flight == 0 else 87)
                for step in range(10):
                    y = base + (step + 1) * 0.6 - 0.18
                    z = -(start + (end - start) * (step + 0.5) / 10)
                    add(hangar, f"{side}{floor}_{flight + 1}_Tread{step + 1:02}", [x, y, z],
                        [9.1, 0.36, 1.95])
    add(wreck, "CargoDeck", [0, 2.72, 5], [14.85, 1.02, 67])
    # The open ramp rises away from its approach. Rotate around source X to
    # align the walking face with both authored endpoints.
    run = 55.2 - 38.55
    rise = 3.16 - 0.09
    pitch = math.atan2(rise, run)
    center_z = (55.2 + 38.55) / 2 - math.sin(pitch) * 0.09
    center_y = (3.16 + 0.09) / 2 - math.cos(pitch) * 0.09
    add(wreck, "Ramp", [0, center_y, center_z], [14.8, 0.18, math.hypot(run, rise)],
        math.degrees(pitch))
    # The one-stud apron joins the ground disk. Allow a narrow overlap at the
    # hinge so the same ramp supports avatar movement after native snapping.
    add(wreck, "RampHingeTransition", [0, 3.02, 38.47], [14.8, 0.27, 0.24])
    return {"hangar": hangar, "wreck": wreck}
