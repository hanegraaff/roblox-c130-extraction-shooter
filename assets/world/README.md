# Battlefield and terrain source

Rojo maps the battlefield model and the stock district assembly to `Workspace.World.Battlefield`. [`Battlefield.model.json`](Battlefield.model.json) reconstructs the expanded primitive map, three multi-story buildings, starting shelter, invisible terrain recipe and anchors without cloud assets or unsaved Studio edits. [`manifest.json`](../manifest.json) records provenance and terrain ownership. Every authored part uses a twelve-component canonical `CFrame`; `Position`/`Orientation` aliases are forbidden. Artifact reconstruction and actual Studio loaded-transform/world checks remain separate gates.

This folder currently authors one level. The future [level contract](../../architecture.md#level-interchange-boundary-target-architecture) will package each level's footprint, orbit, aim envelope, world/terrain, anchors and panel identities separately while reusing core pan, zoom, combat and demolition rules. No second playable level or level switch is implemented yet.

## Coordinates and anchors

Distances are studs, with Y up. Ground and map center are `(0,0,0)`. P14 initializes and recenters the camera to a safe inward focus in the aircraft's orbit-local frame, then rotates that held focus with the aircraft while panning remains bounded by the level and viewport. Playable/orbit radius is 360, diameter 720, aircraft altitude 140 and recovery threshold Y=−30. These construction defaults live in `MapRules.defaults`; change matching geometry/settings together. The orange boundary is 24 studs high.

| Authored object | Contract |
| --- | --- |
| `GroundDisk` | Anchored cylinder, top Y=0, radius 360. |
| `GroundSpawn` | Neutral local-development SpawnLocation at `(0,0.05,120)`. Runtime character ownership disables automatic competitive respawns. |
| `Anchors/Ground01`–`Ground09` | Invisible, noncolliding/nonqueryable 3×3 grid: X=−20/0/20, Z=108/120/132, Y=3. Ground05 is the safe return pose. |
| `Anchors/LauncherHangar`, `LauncherRadar`, `LauncherDepot` | One weapon inside the eastern hangar door and one outside each of the radar and depot entrances. |
| `Anchors/Lobby`, `Anchors/Operator` | `(520,3,0)` and `(520,3,−15)` on the separate protected deck. Both anchors and the entire deck must remain outside the combat disk. |
| `Permanent`, `Breakable` | Unique names become runtime `CoverId` and folder kind becomes `CoverKind`. Both remain solid and do not take damage yet. |
| `SpawnShelterPanels`, `PanelRegistries/SpawnShelter` | Revised candidate: 42 roof and 34 wall panels replace the seven old Permanent shelter colliders, preserving their union, entrances and anchors. The descriptor points to the direct `SpawnShelterPanels` Folder. Pristine geometry must protect all nine spawn anchors; later damage can open it. |
| `Routes` | Stock-material parking stripes and faded road dashes. |
| `MarsBoulders` | Native boulders and small scree at the southern crater and ridges. Larger boulders supply cover. |
| `Buildings` | Foundry and Warehouse are 64×48 studs each; Outpost is 32×48. All have two usable floors and stairs. |
| `GroundCameraInteriors` | Optional Folder of local camera metadata. Each Configuration has a room-oriented `Frame` (CFrame), full `Size` (Vector3 in studs) and `MaxDistanceStuds` (number). The Outpost's workshop and upstairs command room each use a five-stud cap. |
| `TerrainRecipe` | Material and relief rasters and the exact `TerrainBounds` ownership box. `TerrainRecipe.restore` writes native smooth terrain at runtime. |
| `AimEnvelope/MinimumY`, `MaximumY` | NumberValues authoring inclusive aircraft aim-height bounds in world studs, currently −1 and 32. These are configuration, not visible/colliding geometry. AircraftService validates/captures them and retains independent selected-muzzle obstruction checks. |

All descendant names must be unique and authored BaseParts anchored. Ground/launcher anchor centers are ground+3. Anchor validation uses a 4×6×4-stud upright envelope centered 0.2 studs above the anchor to avoid contact with the spawn pad; floor support is checked separately. The district review samples the integrated route centerlines every two studs with a 4 × 5.8 × 4-stud collision probe. Actual avatar walking is a separate required check, not implied by fixture clearance.

## Buildings and panel identities

Each building owns named `_Static`, `_Panels` and `_Navigation` groups. Static floors, landings, frames and stairs stay separate from panel destruction. Ground-floor top is Y=0.125, separated from the battlefield surface; upper-floor top is Y=10.125; each stair has sixteen 0.625-stud rises, two-stud runs and eight-stud tread width. Wall panel faces use the 16×8-stud default; 16×16×1-stud roof tiles are centered at Y=20.625. The two larger buildings have 32-stud room bays, registered interior divider panels and inert 32×8×48 room bounds. Five numbered navigation markers define outside entry, circulation, stair ascent and upper-room traversal.

Server `BuildingGeometry` validates actual geometry and decorates `BuildingId`, `StoryId`, globally unique `PanelId`, Intact state/pivot and variant metadata. `StoryId` is `01` or `02` within a formal BuildingId. The candidate’s 111 formal-building panels plus 76 starting-shelter pieces give **187 registered panels**. `BuildingGeometry.registries` reads formal `_Panels` folders plus `PanelRegistries` StringValues. A StringValue’s Name is the ancillary building ID; Value is a direct Battlefield child Folder name, not a recursive path. `SpawnShelter` points to `SpawnShelterPanels` with StoryId `01`. No new two-story requirement applies to this ancillary envelope. The outside waiting deck/lobby at X=520 remains protected.

At runtime the managed Vesper Array replaces the primitive Warehouse before the
map snapshot. It keeps the 64 × 48-stud site and south approach. The 18 roof
segments surround an open well and both wall stories have 18 panels. There are
no interior dividers. The twin stairs use the same 16 rises and an
eight-stud tread width with a 1.875-stud run. The active runtime registers
199 panels with the detailed Outpost and starting shelter installed. The
primitive source counts above describe the Edit map. See the
[Vesper import record](../../docs/evidence/vesper-import-preflight.md).

The active Sandbreak import replaces the original starting shelter at `(0, 0, 120)` before the map snapshot. The same `SpawnShelterPanels` registry now owns 103 native wall and roof panels at runtime. The nine ground spawn anchors retain their authored positions. Pristine and Light share query shapes, Heavy keeps the native residual geometry, and reset restores the pristine assembly. The 76 primitive panels remain the Edit-map fallback. [Sandbreak integration and verification](../blender/spawn-bunker/IMPORT.md)

Salt Flats Hangar replaces Foundry at runtime. Its 208 × 144-stud shell and
four accessible levels sit beside the apron and walk-in Hercules wreck.
The 152 wall, gable and roof panels use the shared progressive damage ledger.
The wreck uses its own one-hit howitzer or three-second continuous 30mm
threshold. The map snapshot restores the building and wreck between rounds.
The replacement raises the aim ceiling to
64 studs for coverage of the roof. The axis correction, world pivot, native
assets and checks are in the [Salt Flats import receipt](../imports/salt-flats/README.md).

For a compact interior, center the descriptor on the usable room, put its
local +Y boundary at the ceiling, and keep exterior balconies and roofs outside
the bounds. Validate both sides of doors and the height of stair landings in
Studio. Base the cap on observed avatar and camera clearance. A spacious
room can use the ordinary third-person camera without an interior descriptor.

DestructionRuntime captures these Parts into identity Models and publishes structural Intact/Damaged/Destroyed separately from appearance Pristine/Light/Heavy/Total. Earned damage persists per panel across interruptions until reset. Light face scars preserve intact collision; Heavy keeps two solids around a genuine central 50% opening and a distinct dark fractured style at zero stage progress; Total has no solids. Visual scars cannot collide, query or identify as structural hits. Static floors/stairs/frames, terrain and standalone nonbuilding barriers remain unchanged. Restore pristine Parts before reacquiring the registry; do not author live damage, scars or debris back into this file.

## Terrain authoring and restoration

The version 3 recipe uses 180 × 180 four-stud cells. Each relief digit is a hexadecimal elevation in studs above grade. Run `python3 scripts/districts/layout.py` after editing district boundaries, trail centerlines, or southern relief. At startup and reset, the server clears the bounded terrain volume and writes native materials and graded elevations together. The disk supports ground movement at grade. To preview the terrain in a newly built Studio document before Play, run this in the Edit Command Bar. The integrated buildings appear during Play.

```luau
local map = workspace.World.Battlefield
local ok, reason = require(game.ServerScriptService.Server.TerrainRecipe).restore(workspace.Terrain, map.TerrainRecipe)
assert(ok, reason)
map.GroundDisk.LocalTransparencyModifier = 1
```

The four bunker exits join an exterior circuit. Branches reach the eastern hangar door, radar south gate, depot entrance and northern approach to the Seedship site. The site spans X=−106…106 and Z=186…332 at grade. The western impact crater uses a raised rim and a floor at grade. The surrounding ridges taper toward the site, the battlefield edge and the adjoining sand and gravel. [Stock scenery sources and Studio sync](../imports/districts/README.md)

Do not export transient simulation state, projectiles or debris as authoring. Rebuild/teardown replace Battlefield from the private pristine snapshot, so consumers must reacquire its Instances. See [P13](../../plans/13-terrain-and-buildings.md) for actual acceptance results and gaps.

Visible frame members join at column edges, and upper-floor slabs fit inside the frame opening. Avoid overlapping same-facing coplanar surfaces: they cause z-fighting while the camera moves. The artifact gate checks visible building faces, permits hidden intersections inside opaque supports, and rejects floor/map overlap and duplicate panels. Columns extend to ground; the 0.125-stud floor lift preserves relative room height and stair rise.

The earlier P14/P07 artifacts had 360 world nodes / 334 world Parts and 353 authored Parts across all assets. The revised stable build now has 403 Battlefield Parts and 422 authored Parts across all assets, with 187 registered panels. The full host gate passes on `8053c8f`; its unchanged production core retains the `4db4595` solo engine baseline. Warehouse and shelter fixed-scene native firing/normal-thermal appearance checks are recorded, and current P05 passes. The final seven-case two-client/reset and six-case P14 regressions pass in their respective contexts. A user-confirmed live-clock fragment demonstration with a disclosed close-up Ground watch camera also closes the visual falling check. Current P07 acceptance checks pass. Take current node expectations from the generated probe rather than relabelling historical native-load reports.
