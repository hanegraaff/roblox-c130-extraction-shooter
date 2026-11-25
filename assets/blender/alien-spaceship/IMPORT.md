# Prism Seedship import

The approved Blender source and three exports come from [artwork PR #61](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/61). From the repository root, run:

```sh
python3 scripts/seedship/prepare_import.py
```

The output is in `build/seedship-import`. Start with `seedship-p.glb`, the 12-piece pilot. It includes the six-step threshold, the off-center impact sill, a hull plate and the specimen's mapped skin. Remaining batches split by material and preserve the source triangles, corner attributes, textures and object poses. The import index binds all 102 hull panels to their Pristine, Light, Heavy, intact query and residual query shapes. Total clears the panel. The accessory pieces and stable floors belong outside the panel states.

## Site

The ground-deck pivot is **(0, 2.4, 259) studs**. Apply a half-turn around Roblox +Y after correcting the measured importer transform. Blender local `(x, y, z)` becomes Roblox world `(-x, z + 2.4, y + 259)`. The 208 × 144-stud footprint sits inside the surveyed grade, with the main steps facing the bunker trail. After placement the breached sill is west of center. These landmarks calibrate orientation alongside the known one-stud scale.

## Native build

The pilot and 17 remaining private batches were approved under user
`2227341845`. The pilot established one unit per stud and a horizontal
half-turn from the importer. The detached Studio compiler matched all 2,972
pieces and the expected color and normal maps. Both Rojo mappings use the
native roots in ServerStorage. [Native import receipt](../../imports/alien-spaceship/native-receipt.json)

The staged index and approved asset IDs drive
`scripts/seedship/native_config.py`. The Studio Edit capture and compiler
retain the engine mesh and collision data. The two native roots and their
provenance can be recorded with `scripts/seedship/record_native.py` after
transferring the authoritative serialized data. The installed deck collision
uses solid strips that follow the authored outlines, leaving the stairs and
portals open.

The local Edit probe runs `scripts/seedship/check_native_world.luau` against
the managed templates. It samples the four entrances, 144 tread contacts and
six points on both decks. The shared destruction owner changes the wall and
roof from Pristine through Light, Heavy and Total, then restores their
original poses and collision when the test advances the round generation.

In a normal local Play session, an avatar walked through the main entrance,
climbed the port stair and crossed both upper galleries with the regular
third-person camera. Two clients in a separate Studio multiplayer test each
observed intact query cover in Pristine and Light, open space and residual
cover in Heavy, clear air in Total, and full cover after reset. [Native results](../../../docs/evidence/seedship-mars/native.json)

The Roblox recovery bay uses the approved diagnostic atlas on the terminal
face and a local examination light for Specimen 07. [Landed ship in Studio](../../../docs/evidence/seedship-mars/seedship.jpg) · [Recovery bay in Studio](../../../docs/evidence/seedship-mars/recovery-bay.jpg)
