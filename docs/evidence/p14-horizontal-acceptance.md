# P14 horizontal controls and acceptance — 2026-11-12

The user approved the orbit and edge view, requested that **A move the camera
left and D right**, and asked to finish P14's remaining acceptance. The dedicated
`fix/p14-horizontal-controls-acceptance` branch builds on [PR #21](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/21).
The shared signed pan rule now follows the actual camera right vector, so the
mobile left/right arrows use the same screen direction. Camera limits, weapon
zoom and the plane-relative orbit remain in place.

## Current evidence

The full host gate `python3 scripts/verify.py` passes **50 unit / 18 integration**
cases and the static, build, geometry and release-isolation gates. Studio's
current ordinary baseline passes **86 server / 3 client** TestEZ cases, with no
failures or skips. The [full host log](p14-horizontal-acceptance/host-verify.txt)
records the final non-Studio verification. The successful P14 candidate's game source and test fixtures
are `ca1d91a`; the later `e0601b1` changes only the P04 test fixtures for a
separate regression. Use source-specific results below rather than conflating
them with earlier candidates.

| Gate | Actual result |
| --- | --- |
| P14 A1–A3/A5 SDK | [Two real clients, 6/6 cases passed](p14-horizontal-acceptance/p14-multiplayer-passing.json), zero failures/skips, on `ca1d91a`. All 28 requested surface projections passed at both zooms, including two real slopes and each building's upper-floor panel. The native CFrame sweep covered 325 frames. GAU23 recorded 91.20 s / 1,385 frames / 16 orbit bins; M102 recorded 90.91 s / 1,362 frames / 16 bins. Matched camera-origin error was zero with zero frame-pairing failures. |
| Concurrent movement | Real Ground and Gunship clients moved for 2.99 overlapping seconds: the ground character walked 47.63 studs while the operator panned 150.89 studs. The Ground camera remained Custom and attached to its Humanoid; server orbit errors before/after were 0.423/0.417 studs. |
| New role and teardown | The new Gunship's first committed focus was already `(220, 0)` before any recenter input. The separate recenter committed on a later frame; operator departure and idempotent runtime teardown passed in the same P14 report. |
| Human controls | [Two-client HumanTestMultiplayer: 4/4 passed](p14-horizontal-acceptance/human-controls-multiplayer.json), zero failures, skips or errors, on `ca1d91a`. |
| P04 regression | [Two-client P04: 6/6 passed](p14-horizontal-acceptance/p04-multiplayer-passing.json), zero failures/skips, on `64e6a18`. Both baseline clients passed 3/3. Across 21 actual time-aligned pose observations, maximum replication error was 3.480 studs against the unchanged eight-stud bound. The nine-sample full orbit, zoom, restoration and operator departure passed. |
| Native desktop | Actual A/D holds produced −46.60 / +46.78 studs along the camera's RightVector. Releasing A held focus while frames advanced; R restored `(220, 0)`. Preview exit removed the HUD, effect and backdrop, restored Custom camera, and reentry created one of each. |
| Desktop operated orbits | An A-panned 30° view ran for [93.96 seconds](p14-horizontal-acceptance/desktop-30-orbit.json) at 1153×579: 1,410 advancing frames and all 16 orbit bins. The [40° view](p14-horizontal-acceptance/desktop-40-orbit.json) ran for 94.02 seconds at an actual 1280×720 viewport, also with 1,410 frames and 16 bins. Local focus drift was zero, maximum plane-relative look variation was 2.67e−7 / 1.91e−7, and all sampled corner rays pointed down. |
| Mobile operated orbits | After a real right-pad hold and release, the iPhone 17 Pro landscape [30° view](p14-horizontal-acceptance/mobile-30-orbit.json) ran for 94.01 seconds at 750×381, with 1,410 advancing frames, all 16 bins, zero focus drift or invalid frames, and all sampled corners downward. A native touch selected 40° without moving focus. Its [first orbit sample](p14-horizontal-acceptance/mobile-40-interrupted.json) was interrupted by a stalled capture and was not counted as a pass. After the user restored the viewport, an uninterrupted [40° rerun](p14-horizontal-acceptance/mobile-40-orbit.json) observed 387.79° of phase travel over 97.01 seconds, 1,455 frames, all 16 bins, zero focus drift or invalid frames, and a maximum frame gap of 0.074 seconds. |
| Desktop layout | At an actual [1920×1080 camera viewport](p14-horizontal-acceptance/layout-1920.json), the drawn reticle center and published aim both measured `(960, 540)`. The profile and weapon controls fit inside the viewport; Recenter appeared at viewport Y=16 after the GUI inset. The [rendered capture](p14-horizontal-acceptance/layout-1920.jpg) shows the controls and the separate test-only Studio panel. The 1280×720 viewport was also reviewed during the desktop 40° orbit. |
| Native mobile | iPhone 17 Pro landscape pad-left/pad-right holds produced −112.05 / +112.18 studs along camera-right. Release cleared direction and Recenter restored `(220, 0)`; role exit removed the HUD, touch controls and backdrop. |
| Two-finger touch | [Actual simulated touch events](p14-horizontal-acceptance/mobile-two-touch-after.json) held PanRight with one processed GUI touch while a separate world touch controlled RawPointer; both ended cleanly. A separate [touch alignment probe](p14-horizontal-acceptance/touch-inset-after.json) measured zero pixel between finger and reticle, zero angular difference between screen and converted viewport ray, and 0.000043-pixel reprojection error. |
| Simultaneous arrows | Two distinct real simulated Touch InputObjects landed on PanRight and PanUp, producing diagonal `PanDirection = (1, 1)`; after both ended it returned to `(0, 0)`. The [input trace](p14-horizontal-acceptance/mobile-two-arrow.json) records positions, processed state, GUI hits, the held direction and the simulator gesture. |
| Rendered thermal cover | Independent Studio review used a temporarily held valid camera frame and disposable targets/occluder. On both a real terrain slope and an Outpost upper floor, an exposed target was white while an on-screen covered target disappeared behind solid cover; that same target reappeared when the local test occluder was hidden. The cover and camera override were removed afterward. See the [30° slope covered](p14-horizontal-acceptance/p14-thermal-slope-30-covered.jpg) / [uncovered](p14-horizontal-acceptance/p14-thermal-slope-30-uncovered.jpg), [40° slope covered](p14-horizontal-acceptance/p14-thermal-slope-40-covered.jpg) / [uncovered](p14-horizontal-acceptance/p14-thermal-slope-40-uncovered.jpg), [30° upper covered](p14-horizontal-acceptance/p14-thermal-upper-30-covered.jpg) / [uncovered](p14-horizontal-acceptance/p14-thermal-upper-30-uncovered.jpg), and [40° upper covered](p14-horizontal-acceptance/p14-thermal-upper-40-covered.jpg) / [uncovered](p14-horizontal-acceptance/p14-thermal-upper-40-uncovered.jpg) captures. [Upper-frame metadata](p14-horizontal-acceptance/thermal-upper-metadata.json) records the target locations and actual first-hit geometry. This isolated visual comparison is not an operated-orbit test. |

The native two-finger review found two defects in the prior candidate: the pad
touch could claim the aim slot, and GUI inset made the reticle 58 pixels above
the aiming finger. [Before-fix measurements](p14-horizontal-acceptance/touch-inset-before.json)
and the actual two-contact report above show the correction. Native evidence
replaces the local account's name in GUI paths with `LocalPlayer` only; numeric
results and test-player SDK reports are otherwise retained.

Across all 30 passing P14 projection observations, including the 28 initial
sweep targets and two later lifecycle/coherence probes, the maximum
reticle/world projection error was 0.000329 pixel, drawn-reticle error was
zero, same-ray surface disagreement was zero, and distance from the requested
target was at most 1.145 studs.

The P14 fixture also required corrections without relaxing its tolerances. The
[bounded failure record](p14-horizontal-acceptance/p14-prior-failures.json)
preserves initial slope grazing, an insufficient visibility timeout, stale-frame
orbit sampling and a new-operator HUD readiness race. An independent
[300-frame ordering comparison](p14-horizontal-acceptance/render-order-comparison.json)
showed immediate callbacks could sample a 72 ms-old camera against the new
aircraft position, while deferred committed-frame comparisons had zero origin
error and at most 1.33 ms age. The successful fixture retains the original
1-pixel / 0.5-stud same-ray checks, 3-stud target bound, 2-stud camera-origin
bound, −1e−6 inward bound, 90-second orbits and actual two-client requirement.

The first P04 regression compared the live client plane with a fixed, aging
server snapshot and timed out; [the failure](p14-horizontal-acceptance/p04-stale-pose-failure.json)
is preserved. `e0601b1` timestamps each paired server sample and projects it to
the client's synchronized time while retaining the eight-stud replication bound.
That version completed the paired full-orbit pose checks but later failed an
[FOV-restoration assertion](p14-horizontal-acceptance/p04-baseline-failure.json) whose baseline was sampled before the fixture had
confirmed the pre-deployment camera. A separate [production-owner probe](p14-horizontal-acceptance/fov-restoration.json)
set a Custom camera to 57°, entered the 30° operator view, switched to 40°,
and returned to the same Custom camera at exactly 57° with the original mouse
state and no thermal artifacts. The later `64e6a18` test-fixture revision captures
both clients' exact Custom camera/FOV/mouse baselines in Lobby before deployment,
then retains actual restored values before applying the unchanged assertion.
The corrected P04 rerun passed as recorded above.

The independent tester reviewed candidate `64e6a18` (tree
`baf6ee29bd423715929f15b6aa42c197470c1f01`) and found no unresolved defect in
the corrected desktop or pad-plus-world input, P14/P04/HumanTest multiplayer,
or the rendered cover comparisons. The phone preview's test-only Studio panel
overlaps part of the round card and intersects the 105mm button; its center
remained operable, and the profile background extends beyond the 750×381
viewport while its text and Recenter remain visible. The initial viewport stall
interrupted the 40° orbit; after the user foregrounded Studio, the uninterrupted
rerun passed as above. Actual 1920×1080 layout and simultaneous touches on two
distinct direction arrows then passed as recorded above, on source `a64676e`
whose production and P14/P04 fixtures matched the checkout. The independent
tester reports these three observations close the remaining A4 validation gaps.
The sole `tests.rbxlx` Studio document was returned to Edit, the device simulator
to its default/FitToWindow, and `ManualHarness` remained absent. The prototype
test panel can obscure part of the phone preview; the 105mm button remained
operable, and that panel is excluded from release builds.
