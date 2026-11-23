# Prism Seedship import

The approved Blender source and three exports come from [artwork PR #61](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/61). From the repository root, run:

```sh
python3 scripts/seedship/prepare_import.py
```

The output is in `build/seedship-import`. Start with `seedship-p.glb`, the 12-piece pilot. It includes the six-step threshold, the off-center impact sill, a hull plate and the specimen's mapped skin. Remaining batches split by material and preserve the source triangles, corner attributes, textures and object poses. The import index binds all 102 hull panels to their Pristine, Light, Heavy, intact query and residual query shapes. Total clears the panel. The accessory pieces and stable floors belong outside the panel states.

## Site

The ground-deck pivot is **(0, 2.4, 259) studs**. Apply a half-turn around Roblox +Y after correcting the measured importer transform. Blender local `(x, y, z)` becomes Roblox world `(-x, z + 2.4, y + 259)`. The 208 × 144-stud footprint sits inside the surveyed grade, with the main steps facing the bunker trail. After placement the breached sill is west of center. These landmarks calibrate orientation alongside the known one-stud scale.

The Mars basin and trail are managed in the battlefield source. Private model uploads, engine binding and gameplay verification are pending. Native acceptance includes both decks, the four openings, camera clearance and wall and roof damage through reset on two clients.
