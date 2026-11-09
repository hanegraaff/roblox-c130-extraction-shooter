# P14 — Mouse-panned aircraft targeting

**Milestone:** M2 / level revision. **Dependencies:** P13. **Requirements:** R05, R06, R12, R13, R15. Status: [roadmap](../roadmap.md).

## Capability and player experience

The operator moves the mouse to pan across the enlarged battlefield and its multi-story buildings while retaining each weapon's distinct zoom. The aircraft stays on its perimeter orbit and its view stays inward-facing. Panning works in labelled solo preview and an assigned operator round; firing follows in P05.

## Implementation

Extend the existing thermal camera rather than creating a second owner. Implement pure bounded pan rules with injected pointer/delta time, a world-space battlefield focus and explicit recenter. Default to a viewport edge zone with bounded speed; reconcile it with the current central-70% reticle clamp so edge input can actually pan. Preserve focus across orbit motion and acknowledged weapon changes; selection changes FOV without recentering or resetting readiness. Reset pan on new-round/role entry. Camera position remains the canonical aircraft position; clamp focus inside the playable disk and enforce an inward look at every orbit phase, without free flight or independent zoom.

Project reticle rays onto actual terrain/building geometry, supporting elevated floors and a map-authored vertical aim envelope. Reconcile server aim-envelope checks with the expanded map; local camera orientation does not override muzzle obstruction or authorize hits. Avoid a high-rate pan remote. Restore mouse/camera/input/UI state and disconnect every owned listener on role loss/teardown. Record chosen edge-zone/speed/recenter binding and FOV values as defaults.

## Acceptance criteria

- **A1:** Full gate passes. Named `AircraftPanRules` tests cover center/edge input, frame-rate independence, finite bounds, huge delta time, NaN/infinity, world-space focus under orbit motion, recenter and exact disk-edge clamping. At sampled phases, camera origin follows aircraft and look remains inward.
- **A2:** Studio/client `PannedTargetProjection` fixtures reach center, all quadrants, useful near-boundary surfaces, terrain slopes and each building's upper-floor panels over a full orbit at both weapon FOVs. Reticle/world projection agrees within a declared tolerance; no hard-coded ground-plane intersection or permanent blind strip hides a required combat area. Server rejects out-of-disk/vertical-envelope and solid muzzle-obstructed endpoints.
- **A3:** Two actual clients verify the operator pan does not change aircraft pose or the ground client's camera. Switching keys/buttons preserves focus and acknowledged FOV/label/reticle coherence; rejected/stale selections do not reset pan or readiness. P05 later verifies firing/cooldown behavior through this seam.
- **A4:** Engine/rendered checks cover occluded highlights on slopes and upper floors, inward pan limits at both zooms and recenter. UI hover/focus cannot accidentally fire or trap mouse control; layout remains usable at 1280×720 and 1920×1080.
- **A5:** Reset, new round, operator departure and repeated preview/role entry restore default focus or normal camera as appropriate, with exactly one controller and no duplicate listeners/effects. Existing orbit/selection/round/preview tests remain valid after adapting fixed-center expectations only where this revision changes the contract.

## Focused human check

Operate a full orbit at both zooms. Pan to near/far terrain and upper-floor targets, switch weapons while panned and recenter. Record sensitivity, edge responsiveness, motion comfort and readable thermal/reticle/UI behavior. A screenshot alone does not prove coverage or panning feel.

## Documentation changes

Update current controls, actual pan/recenter bindings, view/aim contracts, camera defaults, preview instructions and representative actual gameplay capture. Label combat as planned until P05.

## Completion record

No implementation or validation performed by the steering revision. Record A1–A5 → tests/commands → actual counts/results, source/build, two-client/full-orbit reports, controls/viewport review, tester findings and CI/PR when implemented.

### Implementation start — 2026-11-09

Dependency P13 and its passing engine evidence are integrated on main `10327b4`.
Implementation uses dedicated branch `plan/14-aircraft-panning`. The original
Studio test document remains connected in Edit; its actual synced project is
PlayersVsC130Tests, place 0, with test Rojo on localhost:34872.

Initial tuning defaults, declared before candidate testing: raw-pointer edge
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

Source `a32613376599b38f787fe6484dc3e93a840ba935`, tree
`6cd40a2507d554dc12fa7a731e121783314cde63`, is pushed in
[draft PR #18](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/18).
It implements bounded raw-edge pan, persistent world-space focus, R recenter,
stable inward camera framing, geometry-aware projection and selected-muzzle
server aim validation against the authored −1..32-stud envelope. Production has
one existing camera owner and no pan remote or firing implementation. A normal
optional constructor input boundary drives deterministic engine fixtures; a
fresh ordinary default-input session remains required for native wiring/feel.

| Criterion | Actual evidence and pending checks |
| --- | --- |
| A1 | Full `python3 scripts/verify.py` exits zero: 43 unit / 18 integration, format/lint/strict types, rejection probes, both builds, 351 transforms, 111 pivots, 7,146 surface pairs and release isolation (25 runtime scripts; 414 release / 477 test Instances). Ten new pan unit cases pass. Native 585-CFrame engine samples remain unrun. |
| A2 | Authored envelope and selected-muzzle seam, same-frame ray metadata, terrain slope/upper-floor and full-orbit projection fixtures are implemented and compile; actual Studio projection/envelope/obstruction results are unavailable. |
| A3 | A six-case two-client P14 harness is implemented for aircraft/Ground-camera isolation and focus/FOV/selection coherence; no actual client session has run. |
| A4 | Native mouse/key/button, rendered thermal/UI, 1280×720 / 1920×1080 layout, comfort and refreshed gameplay capture remain required. The accurately captioned existing world image is not panning evidence. |
| A5 | Reset/new-round/operator departure/teardown fixtures and adapted P04 focus assertions compile; required real lifecycle, preview reentry and regression sessions remain unrun. |

The independent tester read the frozen production/harness source and found no
material source defect. Its independent Lune probe exercises 73,205 clamp
combinations: 9,360 explicit rejections and zero nonfinite output. Tiny roundoff
overshoot on extremely translated maps is documented; the current origin map is
unaffected. This review does not replace engine acceptance. The developer's exact
full host gate is reused on unchanged source; later prose is checked separately.
[GitHub Verify 42720211427](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/42720211427)
passes on the candidate.

The original Studio document disconnected during development. MCP now exposes
only unnamed instance `3115533b-a162-4a3b-a453-24ba1a187070`; state and Edit
execution both report **Place is not open**. Rojo is confirmed listening on
localhost:34872 for PlayersVsC130Tests. The user confirmed signed-in/open/Rojo
connection, but the MCP failure persists; enabling Studio MCP/ChatGPT Quick
Connect in that loaded document is requested and pending. No new Studio process
was launched, and no P14 engine test was started. After recovery, first identify
the project and verify all candidate sources before Play. Expected 79 server /
2 client baseline and six P14 scenarios are not passing evidence.

[Candidate evidence](../docs/evidence/p14-aircraft-panning.md),
[host log](../docs/evidence/p14/host-verify.txt),
[source/build manifest](../docs/evidence/p14/source-manifest.json) and
[independent report](../docs/evidence/p14/tester-report.md) preserve exact scope.
Required engine evidence remains open; P05 has not started. No merge or Roblox
publication occurred.
