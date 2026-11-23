# Salt Flats hangar import

The [approved Blender source](../../blender/plane-hangar/salt-flats-hangar.blend)
and [assembled GLB](../../exports/plane-hangar/salt-flats-hangar.glb) came from
[artwork PR #54](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/54).
The finished private asset batches are recorded in [the native receipt](native-receipt.json). The staging package is
reproducible from the approved source and stays in the ignored build directory.

## Foundry fit

The replacement keeps the 208 × 144-stud shell, both fighters, the
apron, and all 61 mesh objects belonging to the C-130 wreck. One source unit
is one stud. Map Blender `(x, y, z)` to `(x, z, -y)` before applying a 60°
rotation around Roblox +Y and the floor pivot `(-211, 0.125, -116)`. The
west door and the off-center wreck skin both serve as orientation landmarks.
Both bays open toward the interior of the map. The placement keeps
25.9 studs of clearance at the nearest conservative footprint corner and
avoids the shelter, other buildings, anchor and route markers, and standalone
cover. The placement relocates two terrain mounds to clear the foundation and
apron.

| Authored object | Center in Roblox studs |
| --- | --- |
| Foundry replacement floor pivot | `(-211, 0.125, -116)` |
| TerrainHill00 | `(-99, -36, 180)` |
| TerrainHill07 | `(-284, -32, 25)` |

The gables and high roof reach approximately Y=63. The maximum aim height of
64 studs includes the roof while retaining the current ground minimum.
The terrain, aim and placement values appear in the generated
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

The pilot confirmed one source unit per stud. Its asymmetric west door and
wreck skin showed that Roblox reverses X and Z. The compiler undoes that
turn before applying the world placement. All sixteen approved uploads loaded
3,395 mesh pieces with no missing color maps. The native receipt lists every
Model ID and version and hashes both Studio-serialized binary roots. The same
roots are mapped through Rojo in release and local test documents.

## Local walking-surface probe

The staging index includes source-space collision boxes for the four levels,
all 120 treads, the apron and the wreck's deck and ramp. The Studio Edit probe
in `scripts/salt_flats/check_walk_surfaces.luau` takes the `walkingSurfaces`
entry as input. It passed 120 tread rays, 51 ramp rays and the cargo deck
height check in the isolated `salt-flats-integration-tests.rbxlx` document.
The probe creates temporary Parts and removes them.

## Studio playtest

The source-built local test place ran in Studio `0.748.0.7481526` on macOS
arm64. Build it with
`rojo build test.project.json --output build/salt-flats-tests.rbxlx`.
The solo session passed 198 server and 14 client smoke checks. An
actual avatar walked from the apron through the west bay entrance, climbed all
three switchbacks to the fourth level, and walked up the wreck ramp into the
cargo hold. All 34 waypoints passed. The normal third-person camera stayed
12.5 studs from its focus at the sampled stair and ramp waypoints. The
[fourth-floor gallery capture](../../../docs/images/plane-hangar/studio-gallery.jpg)
shows the loaded materials and player scale.

The [isolated Studio probe](../../../scripts/salt_flats/check_native_world.luau)
mounted all 152 wall and roof panels. It submitted resolved impacts to the
production damage ledger. Representative wall and roof panels remained solid
in Light, opened a real breach while retaining residual collision in Heavy,
and cleared their geometry in Total. The next round restored the test panels'
original pivots and solid cover. The portal pier stayed intact.

In a separate two-client match, the operator's production weapon remote
sent one 105 mm shot. Both clients confirmed overhead cover before impact,
an empty wreck with no remaining cover after impact, and restored cover
after the ordinary round reset. A fresh two-client session repeated those
observations with the 30 mm chain gun. The wreck cleared after 38 fire
requests over 6.88 seconds of live play, including any initial misses and
projectile travel. The server rule requires three uninterrupted seconds of
confirmed hits.

The final two-client session checked the playing roles' cameras. The
gunship client used the thermal camera with native occluded highlights,
retained the hangar panels and wreck skins, and hid 95 pieces of independent
dressing. The ground client kept the dressing visible with the normal
third-person camera. Each two-client session passed 198 server smoke checks
and all 14 smoke checks on each client. See the
[structured Studio results](../../../docs/evidence/salt-flats-studio.json)
and [host CI run](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/45204525686).
