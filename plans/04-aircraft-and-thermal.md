# P04 — Perimeter aircraft and inward thermal view

**Milestone:** M2. **Dependencies:** P03. **Requirements:** R05, R06, R12, R15. Status: [roadmap](../roadmap.md).

## Capability and player experience

Ground players see a C-130 circle the map's perimeter. The operator's thermal view always faces inward toward the main map. Choosing the 30mm or 105mm profile changes zoom; live firing arrives in P05.

## Implementation

Add an aircraft model with documented canonical hitbox/muzzle attachments and server-owned anchored circular movement. Use map center/radius/altitude to compute orbit and tangent. Separately orient the camera toward the ground-level map-center focus at all phases. Let the player move the reticle inside the view; do not add free camera yaw/pitch or independent zoom. Provide distinct FOV profiles and named selection UI for the 30mm GAU-23/A Chain Gun and 105mm M102 Howitzer, with tighter 30mm zoom. Keep role-authorized selection state coherent with presentation. Use occluded thermal highlights and restore camera/effects on role change. Keep MVP streaming disabled per D11.

## Acceptance criteria

- **A1:** Full gate passes. Orbit tests cover periodicity, phase wrap, altitude, equal map/orbit radius, tangent orientation and invalid configuration with injected time and documented tolerances.
- **A2:** At sampled phases over a full orbit, engine checks match canonical aircraft pose to the perimeter and camera look direction to the map-center focus; model heading remains tangent. Reset returns to initial orbit/view state.
- **A3:** Two clients see the aircraft and battlefield with documented pose convergence tolerance. Any cosmetic smoothing shell is noncollidable and cannot define a second gameplay pose.
- **A4:** Unit/engine tests verify finite distinct FOVs, `FOV30mm < FOV105mm`, selection/HUD/reticle coherence, and inward look direction during both zoom levels and transitions. Stale/rejected selection cannot leave the wrong view active.
- **A5:** Exposed targets receive the thermal effect; solid cover occludes them. Out-of-map aim endpoints reject. Role loss/disconnect/reset restores camera/input/post-processing and removes highlights/listeners; repeat entry creates one controller.

## Focused human check

Inspect the aircraft from the ground and thermal view over a full orbit with both weapon profiles. Verify understandable magnification, reticle stability and cover occlusion. Weapon firing is still pending.

## Documentation changes

Update named weapons, selection-linked zoom, inward-facing view, controls and orbit/model attachment contracts.

## Completion record

### Selection and verification scope

2026-11-08: selected P04 on `plan/04-aircraft-and-thermal` from integrated `main` commit `27f488e`. P03 and the human-testing controls are already integrated; no dependency branch is required. The workspace was clean and GitHub had no open plan PR at selection.

Required evidence is the full host gate, real-engine canonical pose/camera/reset checks, two actual client contexts with measured pose convergence, both weapon profiles and rejected-selection coherence, exposed/covered thermal fixtures, bounded aim rejection, and repeated role/controller cleanup. Focused full-orbit review and a representative actual playtest capture supplement the automated gates. Source implementation, independent tester findings and final delivery facts follow when verified.
