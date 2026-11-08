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
