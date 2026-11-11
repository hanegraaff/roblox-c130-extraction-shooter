# P14 directional controls and level-contract revision — 2026-11-10

This record concerns the dedicated `fix/p14-keyboard-mobile-pan` branch based on
unmerged P14 source `5ab4d19`. It supersedes mouse-edge camera input and updates
the design for future interchangeable levels. The previous candidate's
[engine evidence](p14-aircraft-panning.md) remains historical and does not prove
new keyboard or touch controls. P14 is still Blocked in the roadmap; P15 is
Planned future work.

## Scope and source contract

The operator uses desktop WASD or a mobile directional pad for camera pan. Mouse
movement aims without panning; on touch devices, a separate touch on the world
view aims while a pad direction is held. `AircraftPanRules.step` takes signed
camera-relative right/up axes in −1…1, normalizes diagonals, caps one update at
0.1 seconds and clamps focus to the current level's playable disk. Default speed
is 120 studs/second. R/touchable Recenter, world-space focus, zoom persistence,
actual geometry rays and server muzzle/cover authority remain. A measured HUD
origin converts viewport pixels to ScreenGui offsets on devices with safe-area
shifts. No pan remote is
added. Role exit clears held touch objects, aiming touch, GUI and listeners.
Ground WASD movement is outside the operator controller and unchanged.

The [architecture](../../architecture.md) defines a future versioned
`LevelDefinition`: playable footprint, orbit, aim envelope, world/terrain,
anchors, and stable panel IDs/variants. Every level has a circling C-130; pan,
zoom, weapons, aircraft damage and demolition remain shared rules. Current
`MapRules.defaults`, terrain and world mapping are still single-level. [P15](../../plans/15-interchangeable-levels.md)
owns adding and validating a second playable level.

## Verification

`python3 scripts/verify.py > build/p14-directional-host-verify.txt 2>&1`
exits zero on the directional candidate: **47 unit / 18 integration** cases,
format/lint/strict types, deliberate rejection probes, both Rojo builds,
351 authored transforms, 111 panel pivots, 7,146 surface pairs and release
isolation (414 release / 478 test Instances; 25 release runtime scripts).
[Full host log](p14-directional/host-verify.txt). One new pure case sustains
directional input to all level edges with a smaller alternate disk; existing
normal/diagonal/timing/nonfinite/raster tests were adapted to the new input
contract. Fixture steering now supplies directional input through the production
constructor boundary. Host counts are not engine pass claims.

Current-source Studio MCP instance `66f0c75f-351d-47aa-9d58-9f46edf40dd2`
opened `build/tests.rbxlx`, synced from `PlayersVsC130Tests` at
`localhost:34872`. In ordinary Play, the iPhone 17 Pro landscape simulator
reported `TouchEnabled=true` and a 750×381–382 camera viewport. The first
phone run passed **83/83 server** and **2/3 client** tests: the actual reticle
was 65.15 pixels from its camera ray because the phone GUI origin was
(−62, −20) relative to viewport pixels. After the measured-origin correction
synced, the second phone run passed **83/83 server** and **3/3 client**, zero
failed/skipped. Four actual reticle draw/ray samples had zero pixel error.

In the same phone Play session, the server's test-only solo preview selected
Gunship. `OperatorTouchControls` and `ThermalHUD` existed with four 56×56
direction buttons, two weapon buttons and Recenter. An MCP native mouse hold
on `PanRight` in the simulator moved `PanFocus` from (0, 0, 0) to
(−65.12, 0, −110.17) over the first hold. A sustained hold reached a focus
magnitude of **360 studs**, equal to the authored level radius; a further hold
remained at magnitude **360** while sliding along the boundary. Tapping
Recenter returned focus to (0, 0, 0). The [current screenshot](p14-directional/current-progress.jpg)
is the actual simulated-phone Operator preview. The `StudioTestPanel` was
hidden locally for the capture; production HUD and touch controls stayed visible.

The device simulator was restored to its previous `ScaleToPhysicalSize` and
`LandscapeRight` settings, then stopped (`GetDeviceAsync() == "default"`). In a
fresh desktop ordinary Play, current source again passed **83/83 server** and
**3/3 client** tests, zero failed/skipped. `TouchEnabled=false`. A native W key
hold moved `PanFocus` from (0, 0, 0) to (−23.04, 0, −117.65), about 120 studs
in one second. Moving the native mouse to (100, 100) changed reticle pixels
from (577, 290) to (173, 158) while `PanFocus` stayed exactly fixed. Play was
stopped afterward. The console also contained Studio's Assistant plugin
version-change warning and an unrelated asset-type mismatch; neither changed
the test reports.

Remaining P14 acceptance: native simultaneous two-finger pad/aim, diagonal and
release feel, both zoom profiles at operated map edges, the six-case two-client
full-orbit harness and rendered cover/thermal review. The earlier manual
second-client connection and SDK AddPlayers restrictions are documented in the
P14 record; no repeat launch is counted as acceptance. P14 stays **Blocked**.
Commit/tree and PR integration will be recorded after delivery.
