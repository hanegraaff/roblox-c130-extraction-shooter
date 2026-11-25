"""Export the approved hangar's existing Light and Heavy states with Blender.

Run from the repository root in background mode with the approved blend open.
The library retains the source pivots, panel metadata, and separate state
geometry. Only the existing alternate-state collection is exported.
"""
import hashlib
import json
from pathlib import Path

import bpy


def export_damage() -> None:
    source = Path("assets/blender/plane-hangar/salt-flats-hangar.blend").resolve()
    if Path(bpy.data.filepath).resolve() != source:
        raise ValueError("Open the managed Salt Flats Blender source first")
    variants = next(collection for collection in bpy.context.scene.collection.children
                    if collection.name.startswith("07  Library"))
    variants.hide_viewport = False
    bpy.ops.object.select_all(action="DESELECT")
    states = {}
    for item in variants.objects:
        if item.type != "MESH":
            raise ValueError(f"Unexpected alternate-state object {item.name}")
        case = item if "PanelId" in item else item.parent
        key, appearance = case["PanelId"], case["Appearance"]
        if appearance not in ("Light", "Heavy"):
            raise ValueError(f"Unexpected appearance {appearance!r}")
        if item == case:
            states.setdefault(key, set()).add(appearance)
        else:
            # The four door stencils belong to their parent's damage state.
            item["PanelId"], item["Appearance"] = key, appearance
            item["PanelDressing"] = True
        item.select_set(True)
    if len(states) != 152 or any(values != {"Light", "Heavy"} for values in states.values()):
        raise ValueError("Expected both authored appearances for all 152 panel IDs")
    output = Path("build/salt-flats-import/hangar-states.glb").resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(output), export_format="GLB", use_selection=True,
        export_extras=True, export_yup=True, export_cameras=False,
        export_lights=False, export_animations=False,
    )

    receipt = {
        "blendSha256": hashlib.sha256(source.read_bytes()).hexdigest(),
        "glbSha256": hashlib.sha256(output.read_bytes()).hexdigest(),
    }
    output.with_suffix(".json").write_text(json.dumps(receipt, indent=2) + "\n")


if __name__ == "__main__":
    export_damage()
