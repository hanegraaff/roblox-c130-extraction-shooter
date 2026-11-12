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

## Verification

`python3 scripts/verify.py > build/p14-orbit-relative-host.txt 2>&1` passed on
the candidate source: **47 unit / 18 integration** cases, formatting, lint,
strict types, deliberate rejection probes, both Rojo builds, authored geometry
and release isolation. The 14 pan cases cover both zooms at desktop and phone
aspect ratios, sustained edge holds, a differently sized level, input rejection,
frame-rate consistency, ultra-wide adaptation and a rigid view through 360
sampled orbit positions. [Full host log](p14-orbit-relative/host-verify.txt).

Current-source Studio Play, actual viewport corner rays, visual orbit review,
mobile interaction and an updated current-gameplay capture remain to be recorded
after the test document is available through Studio MCP. P14's full two-client
acceptance remains open and must not be inferred from the host gate.
