# Salt Flats import preflight

The [approved Blender source](../../blender/plane-hangar/salt-flats-hangar.blend)
and [assembled GLB](../../exports/plane-hangar/salt-flats-hangar.glb) came from
[artwork PR #54](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/54).
Native import is pending private Roblox asset access. The staging package is
reproducible from the approved source and stays in the ignored build directory.

## Foundry fit

The proposed replacement keeps the 208 × 144-stud shell, both fighters, the
apron, and all 61 mesh objects belonging to the C-130 wreck. One source unit
is one stud. Map Blender `(x, y, z)` to `(x, z, -y)` before applying a 60°
rotation around Roblox +Y and the floor pivot `(-211, 0.125, -116)`. The
west door and the off-center wreck skin both serve as orientation landmarks.
Both bays open toward the interior of the map. The proposed placement keeps
25.9 studs of clearance at the nearest conservative footprint corner and
avoids the shelter, other buildings, anchor and route markers, and standalone
cover. The preflight models two terrain relocations to clear the foundation and
apron. Check their voxel surfaces and the approaches in Studio before
adopting the moves.

| Authored object | Proposed center in Roblox studs |
| --- | --- |
| Foundry replacement floor pivot | `(-211, 0.125, -116)` |
| TerrainHill00 | `(-99, -36, 180)` |
| TerrainHill07 | `(-284, -32, 25)` |

The gables and high roof reach approximately Y=63. A maximum aim height of
64 studs would include the roof while retaining the current ground minimum.
The proposed terrain, aim and placement values appear in the generated
index for review.

## Stage native inputs

From the repository root on macOS with Blender 5.3:

```sh
/Applications/Blender.app/Contents/MacOS/Blender -b \
  assets/blender/plane-hangar/salt-flats-hangar.blend \
  --python-exit-code 1 -P scripts/salt_flats/export_damage.py
python3 scripts/salt_flats/prepare_import.py
```

The upload candidates are the sixteen `salt-flats-*.glb` files in
`build/salt-flats-import`. Start with the 13-piece `salt-flats-p.glb` pilot.
It contains the hardstand, west door panel and a wreck skin cassette. The
generated `import-index.json` records the hashes, material names, poses,
bounds, triangle counts, expected native names and part ownership. It checks
the approved source and export hashes, binds the alternate library to the
same Blender file and checks that all 152 Pristine, Light and Heavy poses
align. Total clears the panel. The wreck keeps its authored group and the
ramp and footpaths stay part of it.

The preparation preserves the 327,336 assembly triangles and 168,050 alternate
triangles. It splits material slots for Roblox and divides the oversized
22,176-triangle wreck rib material into two spatial pieces. Triangle corners
retain their original positions, normals and UVs. Batch files keep the
embedded maps and material assignments.

The pilot still needs genuine Roblox mesh and texture IDs, native scale and
orientation measurements and a visible material check. Follow the
[import skill](../../../.agents/skills/import-blender-to-roblox/SKILL.md) for
the managed reconstruction, solid collision, combat and round-reset tests.
Bind the wreck separately from the 152 building panels so its entire
hierarchy clears after one direct howitzer hit or a continuous three-second
30mm burst. The hangar panels use the existing progressive damage rules.


## Local walking-surface probe

The staging index includes source-space collision boxes for the four levels,
all 120 treads, the apron and the wreck's deck and ramp. The Studio Edit probe
in `scripts/salt_flats/check_walk_surfaces.luau` takes the `walkingSurfaces`
entry as input. It passed 120 tread rays, 51 ramp rays and the cargo deck
height check in the isolated `salt-flats-integration-tests.rbxlx` document.
The probe creates temporary Parts and removes them. Native avatar traversal,
whole-aircraft cover and the assembled match still require the full import.
