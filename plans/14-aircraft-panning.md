# P14 — Directional aircraft targeting

**Milestone:** M2 / level revision. **Dependencies:** P13. **Requirements:** R05, R06, R12, R13, R15. Status: [roadmap](../roadmap.md).

## Capability and player experience

The operator uses WASD on desktop or an on-screen directional pad on mobile to pan across the enlarged battlefield and its multi-story buildings while retaining each weapon's distinct zoom. Mouse movement only aims the reticle; a separate touch can aim while holding the pad. Pan reaches the level edge and allows roughly the outer quarter of the view beyond it in each direction, without sky or a straight-down look. A held view angle stays fixed relative to the C-130 as it circles, revealing a changing part of the level with steady orbital motion. Panning works in labelled solo preview and an assigned operator round; firing follows in P05.

## Implementation

Extend the existing thermal camera rather than creating a second owner. Implement pure bounded pan rules with injected signed directional axes/delta time and an orbit-local held view offset. Desktop WASD and mobile pad holds feed the same core rule; pointer/touch coordinates aim independently and the central-70% displayed reticle clamp remains. Preserve the relative camera angle across orbit motion and acknowledged weapon changes; selection changes FOV without resetting readiness. R/new-round/role entry returns to the default safe view. Camera position remains the canonical aircraft position. Limit the wide view by the disk intersections at the quarter-screen points on both centerlines, while keeping corner rays downward and pitch short of vertical. Ground WASD movement remains unchanged.

Project reticle rays onto actual terrain/building geometry, supporting elevated floors and a map-authored vertical aim envelope. Reconcile server aim-envelope checks with the expanded map; local camera orientation does not override muzzle obstruction or authorize hits. Avoid a high-rate pan remote. Restore mouse/camera/input/UI state and disconnect every owned listener on role loss/teardown. Record chosen speed/recenter binding and FOV values as defaults.

## Acceptance criteria

- **A1:** Full gate passes. Named `AircraftPanRules` tests cover neutral/four-direction/diagonal input, frame-rate independence, differing level bounds, huge delta time, NaN/infinity, held orbit-local orientation, safe recenter and quarter-screen edge limits at both zooms. At sampled phases, camera origin follows aircraft without changing its path, and its local orientation remains steady when input is released.
- **A2:** Studio/client `PannedTargetProjection` fixtures reach useful near-boundary surfaces, terrain slopes and each building's upper-floor panels when that portion is visible during the full orbit at both weapon FOVs. Actual camera centerline rays verify the quarter-screen limits, while reticle/world projection agrees within a declared tolerance. No hard-coded ground-plane intersection or permanent blind strip hides a required combat area. Server rejects out-of-disk/vertical-envelope and solid muzzle-obstructed endpoints.
- **A3:** Two actual clients verify operator WASD/touch pan does not change aircraft pose or the ground client's camera/movement. Switching keys/buttons preserves focus and acknowledged FOV/label/reticle coherence; rejected/stale selections do not reset pan or readiness. P05 later verifies firing/cooldown behavior through this seam.
- **A4:** Engine/rendered checks cover occluded highlights on slopes and upper floors, visible level edges at all four pan limits and both zooms, downward corner rays, smooth relative orientation through the full orbit, and recenter. Native WASD and a mobile emulator or device prove held, simultaneous and released directional-pad inputs; a second touch can aim independently. Text/window focus cannot pan or trap control. Layout remains usable at 1280×720 and 1920×1080 plus representative mobile safe areas.
- **A5:** Reset, new round, operator departure and repeated preview/role entry restore the safe default view or normal camera as appropriate, with exactly one controller and no duplicate listeners/effects. Existing orbit/selection/round/preview tests remain valid after adapting prior world-focus and FOV defaults where this revision changes the contract.

## Focused human check

Operate a full orbit at both zooms on desktop and mobile. Pan with WASD or the touch pad to left/right/top/bottom view limits; check the level edge is visible with roughly a quarter-screen allowance at wide zoom, no sky and no straight-down pose. Release input and confirm the view angle stays fixed relative to the plane while scenery changes smoothly through the orbit. Reach terrain and upper-floor targets visible in each sector, switch weapons while panned and recenter. Verify mouse movement aims without moving the camera; verify a second touch can aim while holding the pad. Record sensitivity, release/diagonal behavior, motion comfort and readable thermal/reticle/UI behavior. A screenshot alone does not prove coverage or panning feel.

## Documentation changes

Update current desktop/mobile controls, actual pan/recenter bindings, view/aim contracts, camera defaults, preview instructions and representative actual gameplay capture. Label combat as planned until P05. Link the future interchangeable-level contract in P15 without claiming a second playable level.

## Completion record

The current control revision and acceptance evidence are recorded below; P14's
remaining operated checks are not yet complete.

### Horizontal controls and acceptance resumption — 2026-11-12

On `fix/p14-horizontal-controls-acceptance` ([draft PR #22](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/22)), A and the mobile left arrow now pan
toward the actual camera left; D and the right arrow pan right. Native desktop
and iPhone direction checks pass. During acceptance, real two-finger testing
revealed and resolved a pad/aim ownership error and a GUI-inset touch offset;
the same two-contact and finger/reticle tests now pass.

| Criterion | Actual current result |
| --- | --- |
| A1 | Full host gate passes 50 unit / 18 integration; 325 native CFrame samples, horizontal direction tests across 65 phases, and two 90-second P14 orbit summaries pass. |
| A2 | Two actual clients pass all 28 initial target projections at both FOVs, including nonflat slopes and second-story panels in all three buildings. Maximum target error across all 30 projection observations is 1.145 studs; reticle/world error is at most 0.000329 pixel and same-ray surface disagreement is zero. |
| A3 | Real Gunship and Ground clients panned and walked concurrently for 2.99 seconds; the Ground camera remained Custom and attached to its Humanoid, and the canonical orbit remained within the two-stud check. Zoom/rejection and the 4/4 HumanTestMultiplayer regression pass. |
| A4 | Native A/D, mobile left/right, release/recenter, real pad-plus-world two-touch input, and rendered slope/upper-floor occlusion at both FOVs pass. Desktop full orbits at both FOVs and mobile 30° full orbit pass. The mobile 40° sample was interrupted by a Studio rendering stall; a continuous 90-second rerun, two simultaneous directional arrows, and actual 1920×1080 layout review remain open. |
| A5 | P14 SDK passes role reset, fresh-operator default focus, actual operator departure and idempotent teardown; the separate P04 6/6 regression verifies per-client camera/input restoration and operator departure. |

The independent tester's findings, source revisions, durable reports, visual
comparisons and known Studio limitation are in
[horizontal acceptance evidence](../docs/evidence/p14-horizontal-acceptance.md).
The user has been asked to foreground the existing test viewport so the three
remaining A4 observations can be retried. No Roblox publication occurred.

### Edge visibility revision — 2026-11-12

The user approved the orbit behavior and asked to pan slightly past all four
level edges, suggesting about 25% of the viewport. Dedicated branch
`fix/p14-camera-edge-overscan` applies that allowance to the wide view along
each centerline, retains the zoom-preserved relative angle, and supplies a
camera-only visual ground backdrop outside the playable disk. Focused host and
desktop/mobile Studio results are recorded in the
[edge evidence](../docs/evidence/p14-edge-overscan.md). The full P14 two-client
and operated acceptance gates remain open.

### Orbit-relative view correction — 2026-11-11

The 2026-11-12 user revision supersedes the whole-viewport boundary described
below: the level edge should enter about the outer 25% of the viewport in each
direction. The fixed plane-relative angle and unchanged orbit remain selected.

The user confirmed that pan should stop when the **whole camera view** reaches
the level edge and that a held angle should remain fixed **relative to the
circling plane**. The previous world-fixed ground focus caused an apparent spin
as the aircraft passed near it. Dedicated branch
`fix/p14-camera-view-bounds-orbit` changes pan to an aircraft-local offset and
clips all viewport corner rays to the current level disk. The canonical server
orbit is untouched. To leave useful pan range with the 140-stud orbit altitude,
the 30mm/105mm view defaults are tuned from 35°/60° to 30°/40°; D40 records this
as tuning, not a new weapon rule. Current host verification, the corrected
phone focus transition, and focused desktop/mobile Studio observations are recorded in
[the correction evidence](../docs/evidence/p14-orbit-relative-view.md). P14 remains
Blocked until the updated two-client and full operated acceptance gates pass.

### Control and future-level revision — 2026-11-10

The user replaced mouse-edge camera panning with operator WASD and an on-screen
mobile directional pad, confirmed that “planning” meant panning, and chose mouse
movement as reticle aim only. The existing 720-stud circular level still supplies
the playable bound; that stage clamped a world-space focus point to the disk.
The 2026-11-11 correction above supersedes that framing. Weapon zoom, recenter
and authoritative aim remain core rules.
The user also selected a future architecture in which every interchangeable
level has a circling C-130 while camera pan/zoom, combat damage and building
demolition stay shared. [P15](15-interchangeable-levels.md) owns implementing
level interchange after the MVP. This revision does not claim a second level.

The follow-up work is on `fix/p14-keyboard-mobile-pan`, branched from the unmerged
P14 candidate `5ab4d19` and delivered as [draft PR #19](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/19); source, host and Studio results are recorded in
[the revision evidence](../docs/evidence/p14-directional-revision.md). The old
mouse-edge results below remain historical evidence for the earlier candidate,
not acceptance of this changed control scheme. P14 stays Blocked until all
applicable keyboard, mobile, multiplayer and rendered acceptance checks pass.

### Implementation start — 2026-11-09

Dependency P13 and its passing engine evidence are integrated on main `10327b4`.
Implementation uses dedicated branch `plan/14-aircraft-panning`. The original
Studio test document remains connected in Edit; its actual synced project is
PlayersVsC130Tests, place 0, with test Rojo on localhost:34872.

Historical initial tuning defaults, declared before the 2026-11-10 control revision: raw-pointer edge
zone 12% on each side, maximum pan speed 120 studs/second, per-update delta-time
cap 0.1 seconds and **R** to recenter. Retain acknowledged 35°/60° weapon FOVs and
central-70% displayed reticle; raw edge input drives pan before that display
clamp. UI hover/text focus suspends pan. An authored maximum aim elevation of
32 studs covers the current roof/hill geometry. These are implementation defaults,
not additional user-selected rules; validation may justify documented tuning.
No acceptance result is claimed at implementation start.

Declared engine tolerances before testing: reticle projection agreement at most
1 pixel / 0.5 studs at the hit surface; horizontal inward dot at least −0.000001
(zero is permitted directly below the aircraft at the disk edge); live canonical
camera-origin agreement within 2 studs between replication/Heartbeat updates.
Use an explicit stable camera basis for that near-vertical edge case. The authored
aim envelope will use numeric values rather than additional visible geometry.

Automated edge-input steering must reach a target neighborhood within 3 studs;
this control-steering tolerance is separate from the tighter 1-pixel / 0.5-stud
same-frame projection agreement. Surface assertions still require an actual
nonflat Terrain slope or the requested building's StoryId `02` panel, as applicable.

### Candidate delivery and acceptance gap — 2026-11-09

Previous mouse-edge source `8bbab8e50f8d177a06910851f1afcc423486aa74`, tree
`c445a376c14645868a52f81868c59730955b9f6d`, is pushed in
[draft PR #18](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/18).
It implements the pan/focus/projection/envelope contracts above. Three engine
findings are corrected: fixture steering-to-pointing sequencing (`f16e695`),
real GUI-inset hover blocking (`25b44e7`) and fractional reticle raster agreement
(`8bbab8e`). Excluded test-only native UI invocation support is `e6ff4e7`.
Raw pan input, declared tolerances and the two-player requirement remain intact.

| Criterion | Actual result / required remainder |
| --- | --- |
| A1 | Full `python3 scripts/verify.py` exits zero: **46 unit / 18 integration**, static/rejection/build gates, 351 transforms, 111 pivots, 7,146 surface pairs; 414 release/478 test Instances, 25 runtime scripts. 13 pure pan cases. 585 native CFrames pass on earlier full attempts; current ordinary smoke passes 82 server / 3 client, one actual client. Full current phase-aligned suite remains open. |
| A2 | Earlier focused arrival regression passes 2/2 with two actual clients, zero world error and 0.000153 px at the original failing target. Current actual production raster probes draw/ray/store with 0 px error. Server envelope/muzzle baseline passes. Full 28-target/both-90-second-orbit/slope/upper-floor and rendered coverage remains open. |
| A3 | Native solo weapon keys/buttons preserve focus; authoritative zoom coherence is observed. Current two-client isolation/selection/rejection and applicable P04/human multiplayer regressions remain open. |
| A4 | Native hover/text blocking and recenter pass; numeric 1280×720/1920×1080 layout checks pass; real panned preview is refreshed. Complete rendered thermal cover, both-FOV full-orbit comfort and operated viewport review remain open after native viewport-focus loss. |
| A5 | Two preview exit/reentry cycles restore normal camera/input and singleton ownership; historical teardown checks pass. Full current reset/new-round/operator-departure/kick and multiplayer lifecycle regressions remain open. |

The [evidence record](../docs/evidence/p14-aircraft-panning.md) links actual
reports, commands, invocation/client counts, declared tolerances, source hashes
and chronological failures. [Host log](../docs/evidence/p14/host-verify.txt),
[source/build manifest](../docs/evidence/p14/source-manifest.json) and
[independent tester report](../docs/evidence/p14/tester-report.md) are durable.
Independent 73,205-combination probe has 9,360 explicit rejections and zero
nonfinite outputs; tiny extreme translated-map boundary roundoff is retained as
a limitation of no current-map impact. Source/harness review and engine retests
leave no reproduced material production defect unresolved, while missing
required acceptance remains blocking. The exact source passes
[GitHub Verify 42729968970](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/42729968970).

The original unnamed-place connection blocker is resolved. Current native UI
requests two clients but only one connects; SDK full launches also fail before a
usable two-player session. A final distinct native one-client + AddPlayers(1) attempt is
rejected because the manual session is not SDK-owned. No P14 scenario executes
on these current launch failures. Earlier two-client partial results are not a
full six-case pass. No further launch variants are attempted.

All owned simulations are ended. Only original Studio
`ab521a9d-50ef-49e7-a9c4-f56e2a88f5c5` remains in Edit, with the temporary
ManualHarness restored nil. Fixtures/device state are restored. The technical
writer updated current player/contributor/package documentation, public raster
API, actual counts and guarded manual invocation/cleanup; final prose/evidence
is checked separately from unchanged source: repository checker passes 64 Markdown / 78 JSON files and `git diff --check` passes. The real README image is a labelled
Waiting/Lobby preview, not multiplayer acceptance.

Required engine/native evidence remains open; roadmap P14 is Blocked and P05
remains Planned. Source and evidence are delivered on this task branch; PR #18
stays draft. Main is unchanged, with no merge or Roblox publication.
