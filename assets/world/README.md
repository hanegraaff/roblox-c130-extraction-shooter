# Battlefield and terrain source

Rojo maps this folder to `Workspace.World`. [`Battlefield.model.json`](Battlefield.model.json) reconstructs the expanded primitive map, three multi-story buildings, starting shelter, invisible terrain recipe and anchors without cloud assets or unsaved Studio edits. [`manifest.json`](../manifest.json) records provenance and terrain ownership. Every authored part uses a twelve-component canonical `CFrame`; `Position`/`Orientation` aliases are forbidden. Artifact reconstruction and actual Studio loaded-transform/world checks remain separate gates.

This folder currently authors one level. The future [level contract](../../architecture.md#level-interchange-boundary-target-architecture) will package each level's footprint, orbit, aim envelope, world/terrain, anchors and panel identities separately while reusing core pan, zoom, combat and demolition rules. No second playable level or level switch is implemented yet.

## Coordinates and anchors

Distances are studs, with Y up. Ground and map center are `(0,0,0)`. P14 initializes and recenters the camera to a safe inward focus in the aircraft's orbit-local frame, then rotates that held focus with the aircraft while panning remains bounded by the level and viewport. Playable/orbit radius is 360, diameter 720, aircraft altitude 140 and recovery threshold Y=−30. These construction defaults live in `MapRules.defaults`; change matching geometry/settings together. The orange boundary is 24 studs high.

| Authored object | Contract |
| --- | --- |
| `GroundDisk` | Anchored cylinder, top Y=0, radius 360. |
| `GroundSpawn` | Neutral local-development SpawnLocation at `(0,0.05,120)`. Runtime character ownership disables automatic competitive respawns. |
| `Anchors/Ground01`–`Ground09` | Invisible, noncolliding/nonqueryable 3×3 grid: X=−20/0/20, Z=108/120/132, Y=3. Ground05 is the safe return pose. |
| `Anchors/Launcher` | One future launcher anchor `(0,3,0)` above the gold center marker; no weapon exists yet. |
| `Anchors/Lobby`, `Anchors/Operator` | `(520,3,0)` and `(520,3,−15)` on the separate protected deck. Both anchors and the entire deck must remain outside the combat disk. |
| `Permanent`, `Breakable` | Unique names become runtime `CoverId` and folder kind becomes `CoverKind`. Both remain solid and do not take damage yet. |
| `SpawnShelterPanels`, `PanelRegistries/SpawnShelter` | Revised candidate: 42 roof and 34 wall panels replace the seven old Permanent shelter colliders, preserving their union, entrances and anchors. The descriptor points to the direct `SpawnShelterPanels` Folder. Pristine geometry must protect all nine spawn anchors; later damage can open it. |
| `Routes` | Teal western and ochre eastern launcher approaches through X=−60/+60. Both remain usable without destruction. |
| `Buildings` | Foundry and Warehouse are 64×48 studs each; Outpost is 32×48. All have two usable floors and stairs. |
| `TerrainRecipe` | Eight invisible sphere descriptors plus the exact `TerrainBounds` ownership box; `TerrainRecipe.restore` supplies actual smooth terrain at runtime. |
| `AimEnvelope/MinimumY`, `MaximumY` | NumberValues authoring inclusive aircraft aim-height bounds in world studs, currently −1 and 32. These are configuration, not visible/colliding geometry. AircraftService validates/captures them and retains independent selected-muzzle obstruction checks. |

All descendant names must be unique and authored BaseParts anchored. Ground/launcher anchor centers are ground+3. Anchor validation uses a 4×6×4-stud upright envelope centered 0.2 studs above the anchor to avoid contact with the spawn pad; floor support is checked separately. Launcher approaches use that envelope every 0.5 stud. Actual avatar walking is a separate required check, not implied by fixture clearance.

## Buildings and panel identities

Each building owns named `_Static`, `_Panels` and `_Navigation` groups. Static floors, landings, frames and stairs stay separate from panel destruction. Ground-floor top is Y=0.125, separated from the battlefield surface; upper-floor top is Y=10.125; each stair has sixteen 0.625-stud rises, two-stud runs and eight-stud tread width. Wall panel faces use the 16×8-stud default; 16×16×1-stud roof tiles are centered at Y=20.625. The two larger buildings have 32-stud room bays, registered interior divider panels and inert 32×8×48 room bounds. Five numbered navigation markers define outside entry, circulation, stair ascent and upper-room traversal.

Server `BuildingGeometry` validates actual geometry and decorates `BuildingId`, `StoryId`, globally unique `PanelId`, Intact state/pivot and variant metadata. `StoryId` is `01` or `02` within a formal BuildingId. The candidate’s 111 formal-building panels plus 76 starting-shelter pieces give **187 registered panels**, under validation. `BuildingGeometry.registries` reads formal `_Panels` folders plus `PanelRegistries` StringValues. A StringValue’s Name is the ancillary building ID; Value is a direct Battlefield child Folder name, not a recursive path. `SpawnShelter` points to `SpawnShelterPanels` with StoryId `01`. No new two-story requirement applies to this ancillary envelope. The outside waiting deck/lobby at X=520 remains protected.

DestructionRuntime captures these Parts into identity Models and publishes structural Intact/Damaged/Destroyed separately from appearance Pristine/Light/Heavy/Total. Earned damage persists per panel across interruptions until reset. Light face scars preserve intact collision; Heavy keeps two solids around a genuine central 50% opening and a distinct dark fractured style at zero stage progress; Total has no solids. Visual scars cannot collide, query or identify as structural hits. Static floors/stairs/frames, terrain and standalone nonbuilding barriers remain unchanged. Restore pristine Parts before reacquiring the registry; do not author live damage, scars or debris back into this file.

## Terrain authoring and restoration

The manifest's recipe version 1 / seed 0 is deterministic and uses no randomness. Four-stud engine voxels reconstruct eight Grass/Rock hill caps with nominal apex Y=16; engine surface queries allow three studs of voxel tolerance. The exact axis-aligned owned volume is `(-368,-112,-368)`–`(368,32,368)` (736×144×736). Descriptors must remain inside that volume and within the playable disk. Rotated bounds and unsupported materials reject before terrain writes.

`MapService.start()` clears only that owned box and fills the spheres. `rebuild()` and `destroy()` restore the same terrain plus pristine geometry/IDs/anchors and remove transient descendants. Terrain outside the box is preserved. Fill operations do not yield, but collision/raycast updates may converge afterward; Studio tests wait up to five seconds. An Edit document can therefore show the authored part map before runtime has reconstructed terrain.

Edit the versioned descriptors and manifest together, update semantic/artifact tests, build, sync in Edit, then run `TerrainReconstruction`, `BuildingLayout`, `ExpandedMapNavigation`, `ExpandedMapSightLines` and the [P13 multiplayer harness](../../docs/testing.md#run-the-p13-expanded-map-harness). Compare sampled materials/elevations/voxels through repeated mutations/resets and a fresh source-built artifact load. Preserve unrelated terrain fixtures and actual loaded transforms in that evidence.

Do not export transient simulation state, projectiles or debris as authoring. Rebuild/teardown replace Battlefield from the private pristine snapshot, so consumers must reacquire its Instances. See [P13](../../plans/13-terrain-and-buildings.md) for actual acceptance results and gaps.

Visible frame members join at column edges, and upper-floor slabs fit inside the frame opening. Avoid overlapping same-facing coplanar surfaces: they cause z-fighting while the camera moves. The artifact gate checks visible building faces, permits hidden intersections inside opaque supports, and rejects floor/map overlap and duplicate panels. Columns extend to ground; the 0.125-stud floor lift preserves relative room height and stair rise.

The earlier P14/P07 artifacts had 360 world nodes / 334 world Parts and 353 authored Parts across all assets. The revised stable build now has 403 Battlefield Parts and 422 authored Parts across all assets, with 187 registered panels. The full host gate passes on `8f59c42`; its unchanged production core retains the `4db4595` solo engine baseline. Current Warehouse fixed-scene appearance checks are partial; shelter rendering, visual fragment motion and full two-client/regression acceptance remain pending. Take current node expectations from the generated probe rather than relabelling historical native-load reports.
