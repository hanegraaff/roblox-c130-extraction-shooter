# P14 orbit-relative whole-view correction — 2026-11-11

This is the dedicated `fix/p14-camera-view-bounds-orbit` branch, based on the
unmerged directional P14 revision `4f77dcd`. The user's clarified framing is:
stop pan when the **whole screen** reaches the level edge, and hold the viewing
angle **relative to the C-130** while its unchanged server orbit continues.
Previous world-fixed-focus and 35°/60° observations are historical, not evidence
for this correction.

## Cause and implementation

The previous controller looked from the orbiting plane toward a fixed world
point. When the plane passed close to a point near the disk edge, the horizontal
look distance approached zero and yaw/pitch changed abruptly. Clamping only
that center point to the disk still allowed the camera's peripheral rays to
show sky or outside ground.

`AircraftPanRules` now stores an orbit-local ground focus. Each rendered frame
rotates that offset with the canonical server aircraft position; it never moves
the aircraft. Directional input clips against a pure four-corner camera-frustum
test of the active level disk, with a two-stud inset. The widest enabled lens
bounds both profiles, so switching weapon zoom does not reset the held angle.
R/touch Recenter returns to a safe default view. Normal desktop/phone lens
defaults are 30° for GAU23 and 40° for M102. At the current 360-stud radius and
140-stud altitude, the former 60° wide lens left essentially no whole-view pan
range; the new numeric FOVs are tuning defaults (D40). Ultra-wide viewports may
use a narrower displayed lens to retain the same ground-only guarantee.

The test-only P14 client harness now steers in local coordinates, records
`PanLocalFocus`, tests four actual camera corner rays, and samples bounded held
views through orbit phases. It remains a separate automated fixture; native
keyboard/touch and rendered review require normal Play.

The phone simulator exposed a focus transition: a delivered pad touch could
remain blocked after Studio had reported window focus loss. A new touch on the
active pad now restores the touch controller's focus flag. Held touches still
clear through the existing `InputEnded` and teardown paths.

## Verification

`python3 scripts/verify.py > build/p14-orbit-relative-host.txt 2>&1` passed on
the candidate source: **47 unit / 18 integration** cases, formatting, lint,
strict types, deliberate rejection probes, both Rojo builds, authored geometry
and release isolation. The 14 pan cases cover both zooms at desktop and phone
aspect ratios, sustained edge holds, a differently sized level, input rejection,
frame-rate consistency, ultra-wide adaptation and a rigid view through 360
sampled orbit positions. [Full host log](p14-orbit-relative/host-verify.txt).

The current source was synced into `PlayersVsC130Tests` (`tests.rbxlx`, place 0)
through Rojo at `localhost:34872` in the existing Studio document. Ordinary
solo Play produced **83 server / 3 client TestEZ passes**, with zero failures or
skips, and the test-only Explore Map control selected Operator. These are smoke
reports, not the P14 six-scenario multiplayer harness.

Native desktop W moved local focus from `(220, 0)` to `(169.865, 0)` at the far
view edge. At 1153×579 and the wider 40° lens, the four actual
`ViewportPointToRay` ground intersections had radii **358.0, 358.0, 290.3,
290.3 studs** on the 360-stud disk. The view remained oblique at **36.36°**
downward pitch. R restored `(220, 0)`; a native D hold reached local
`(220, 35.489)` with all four corners still inside the disk. The 30° lens also
remained inside. No sky or outside ground appears in the rendered edge review.

On the **iPhone 17 Pro landscape simulator**, `TouchEnabled` was true, the
runtime `OperatorTouchControls` pad existed, and the active viewport measured
750×381. A real simulated PanUp touch initially delivered `InputBegan` but was
blocked by the stale focus flag. After the focused-touch correction and a
fresh Play, the same held touch showed 30 sampled unblocked render frames and
moved focus from `(220, 0)` to `(168.989, 0)`. A touch on the 105mm button
selected 40°. R then reset the view; a held PanRight touch moved focus to
`(220, 36.401)`. Its four measured ground-corner radii at 40° were **319.6,
332.9, 296.6, 160.8 studs**. The phone's two visible pad arrows, zoom buttons
and reticle are present in the [current Studio capture](p14-orbit-relative/current-progress.jpg).
Only test and lobby overlays were disabled locally for that capture; no source
or Studio place was changed by the capture.

With that sideways focus held and no further pan input, the aircraft advanced
from **−58.62° to −34.56°** around the map in a six-second live sample. The
client's projection frame advanced **1091 → 1181**, local focus stayed
`(220, 36.401)`, and plane-relative look components were stable: radial
**−0.69545 → −0.69506**, tangential **0.18082 → 0.18230**, vertical
**−0.69545 → −0.69545**. The earlier unattended desktop Play stopped rendering
after Studio window focus was lost while its server aircraft continued;
therefore its later frozen camera frames are not used as orbit evidence. The
active phone sample and the deterministic 360-position rule test support the
correction, while a full operated orbit is still an open P14 gate.

Play was stopped and the simulator was reset with `StopSimulationAsync()`,
leaving the same Studio test document in Edit mode. Full P14 two-client,
90-second/28-target, thermal-cover and lifecycle acceptance remains open and
must not be inferred from these focused checks.
