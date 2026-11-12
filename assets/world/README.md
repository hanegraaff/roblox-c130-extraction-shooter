# Battlefield and terrain source

Rojo maps this folder to `Workspace.World`. [`Battlefield.model.json`](Battlefield.model.json) reconstructs the expanded primitive map, three buildings, invisible terrain recipe and anchors without cloud assets or unsaved Studio edits. [`manifest.json`](../manifest.json) records provenance and terrain ownership. Every authored part uses a twelve-component canonical `CFrame`; `Position`/`Orientation` aliases are forbidden. Artifact reconstruction and actual Studio loaded-transform/world checks remain separate gates.

This folder currently authors one level. The future [level contract](../../architecture.md#level-interchange-boundary-target-architecture) will package each level's footprint, orbit, aim envelope, world/terrain, anchors and panel identities separately while reusing core pan, zoom, combat and demolition rules. No second playable level or level switch is implemented yet.

## Coordinates and anchors

Distances are studs, with Y up. Ground and map center are `(0,0,0)`. P14 initializes/recenters the local camera focus there, then pans its world-space X/Z within the disk at ground height. Playable/orbit radius is 360, diameter 720, aircraft altitude 140 and recovery threshold Y=−30. These construction defaults live in `MapRules.defaults`; change matching geometry/settings together. The orange boundary is 24 studs high.

| Authored object | Contract |
| --- | --- |
| `GroundDisk` | Anchored cylinder, top Y=0, radius 360. |
| `GroundSpawn` | Neutral local-development SpawnLocation at `(0,0.05,120)`. Runtime character ownership disables automatic competitive respawns. |
| `Anchors/Ground01`–`Ground09` | Invisible, noncolliding/nonqueryable 3×3 grid: X=−20/0/20, Z=108/120/132, Y=3. Ground05 is the safe return pose. |
| `Anchors/Launcher` | One future launcher anchor `(0,3,0)` above the gold center marker; no weapon exists yet. |
| `Anchors/Lobby`, `Anchors/Operator` | `(520,3,0)` and `(520,3,−15)` on the separate protected deck. Both anchors and the entire deck must remain outside the combat disk. |
| `Permanent`, `Breakable` | Unique names become runtime `CoverId` and folder kind becomes `CoverKind`. Both remain solid and do not take damage yet. |
| `Permanent/ShelterRoof` | 108×96-stud canopy centered `(0,14,114)`, underside Y=13; protects all nine spawn anchors across 64 orbit samples. |
| `Routes` | Teal western and ochre eastern launcher approaches through X=−60/+60. Both remain usable without destruction. |
| `Buildings` | Foundry and Warehouse are 64×48 studs each; Outpost is 32×48. All have two usable floors and stairs. |
| `TerrainRecipe` | Eight invisible sphere descriptors plus the exact `TerrainBounds` ownership box; `TerrainRecipe.restore` supplies actual smooth terrain at runtime. |
| `AimEnvelope/MinimumY`, `MaximumY` | NumberValues authoring inclusive aircraft aim-height bounds in world studs, currently −1 and 32. These are configuration, not visible/colliding geometry. AircraftService validates/captures them and retains independent selected-muzzle obstruction checks. |

All descendant names must be unique and authored BaseParts anchored. Ground/launcher anchor centers are ground+3. Anchor validation uses a 4×6×4-stud upright envelope centered 0.2 studs above the anchor to avoid contact with the spawn pad; floor support is checked separately. Launcher approaches use that envelope every 0.5 stud. Actual avatar walking is a separate required check, not implied by fixture clearance.

## Buildings and panel identities

Each building owns named `_Static`, `_Panels` and `_Navigation` groups. Static floors, landings, frames and stairs stay separate from future destruction. Ground-floor top is Y=0.125, separated from the battlefield surface; upper-floor top is Y=10.125; each stair has sixteen 0.625-stud rises, two-stud runs and eight-stud tread width. Wall panel faces use the 16×8-stud default; 16×16×1-stud roof tiles are centered at Y=20.625. The two larger buildings have 32-stud room bays, registered interior divider panels and inert 32×8×48 room bounds. Five numbered navigation markers define outside entry, circulation, stair ascent and upper-room traversal.

Server `BuildingGeometry` validates actual geometry, headroom, connected treads and swept entry corridors, then applies `BuildingId`, `StoryId`, `PanelId`, `PanelState = Intact`, `IntactPivot` and `VariantContract = Intact/Damaged/Destroyed:v1`. `StoryId` is `01` or `02` within its `BuildingId`; together they identify a story. `PanelId` is globally unique. The 111 exterior/roof/interior panels have stable names and pivots. P07 will implement damaged/destroyed geometry, progression and fragment physics; metadata alone does not make panels destructible.

## Terrain authoring and restoration

The manifest's recipe version 1 / seed 0 is deterministic and uses no randomness. Four-stud engine voxels reconstruct eight Grass/Rock hill caps with nominal apex Y=16; engine surface queries allow three studs of voxel tolerance. The exact axis-aligned owned volume is `(-368,-112,-368)`–`(368,32,368)` (736×144×736). Descriptors must remain inside that volume and within the playable disk. Rotated bounds and unsupported materials reject before terrain writes.

`MapService.start()` clears only that owned box and fills the spheres. `rebuild()` and `destroy()` restore the same terrain plus pristine geometry/IDs/anchors and remove transient descendants. Terrain outside the box is preserved. Fill operations do not yield, but collision/raycast updates may converge afterward; Studio tests wait up to five seconds. An Edit document can therefore show the authored part map before runtime has reconstructed terrain.

Edit the versioned descriptors and manifest together, update semantic/artifact tests, build, sync in Edit, then run `TerrainReconstruction`, `BuildingLayout`, `ExpandedMapNavigation`, `ExpandedMapSightLines` and the [P13 multiplayer harness](../../docs/testing.md#run-the-p13-expanded-map-harness). Compare sampled materials/elevations/voxels through repeated mutations/resets and a fresh source-built artifact load. Preserve unrelated terrain fixtures and actual loaded transforms in that evidence.

Do not export transient simulation state, projectiles or debris as authoring. Rebuild/teardown replace Battlefield from the private pristine snapshot, so consumers must reacquire its Instances. See [P13](../../plans/13-terrain-and-buildings.md) for actual acceptance results and gaps.

Visible frame members join at column edges, and upper-floor slabs fit inside the frame opening. Avoid overlapping same-facing coplanar surfaces: they cause z-fighting while the camera moves. The artifact gate checks visible building faces, permits hidden intersections inside opaque supports, and rejects floor/map overlap and duplicate panels. Columns extend to ground; the 0.125-stud floor lift preserves relative room height and stair rise.

The P14 world adds the AimEnvelope Folder and two NumberValues: 360 authored world nodes / 334 world Parts, with 351 authored Parts across all assets unchanged. Earlier P13 native-load evidence records its historical 357-node source; it must not be relabeled as the current artifact.
