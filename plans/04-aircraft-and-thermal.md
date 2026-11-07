# P04 — Orbiting aircraft and thermal view

**Milestone:** M2. **Dependencies:** P03. **Requirements:** R05, R06, R12, R15. Status: [roadmap](../roadmap.md).

## Capability and player experience

A ground player looks up and sees the aircraft circling. The operator sees that same district through a zoomable thermal-style targeting camera. Exposed players are readable; solid cover hides them.

## Implementation

Add a documented aircraft model with canonical hitbox/muzzle attachments, orbit rules and server-owned anchored movement. Implement thermal camera, bounded aim/zoom, occluded highlights and basic reticle/HUD. Restore normal/spectator camera and effects on role changes. Start with ordinary replication; add cosmetic interpolation only if a measured visual defect warrants it. Keep MVP streaming disabled as documented in D11.

## Acceptance criteria

- **A1:** Full gate passes. Orbit tests cover phase wrap, periodicity, altitude/radius, tangent orientation and invalid configuration using injected time and numeric tolerances.
- **A2:** Engine tests show the aircraft's canonical pose matches the orbit, remains outside ground traversal space and returns to the initial round phase after reset.
- **A3:** Two clients observe the aircraft and relevant battlefield. Automated pose checks record convergence tolerance under normal replication; a local smoothing shell, if used, has no independent collidable hitbox.
- **A4:** Engine fixtures verify exposed targets receive the effect and solid cover occludes it. Camera aim and zoom cannot exceed configured bounds. Document transparent-window behavior explicitly.
- **A5:** Role loss, elimination, operator disconnect and reset restore camera/input/post-processing and remove highlights/listeners. Repeated role entry creates only one controller.

## Focused human check

Inspect moving aircraft from the ground and targets behind/in front of intact cover from the operator. Verify legible contrast, stable reticle and zoom without clipping through cover. Record both views at a fixed location/time.

## Documentation changes

Update controls, aircraft/thermal limitations, orbit units and model attachment contracts. Mark weapons as pending.

## Completion record

Not implemented. Record A1–A5, both-client evidence, source, visual limits and any justified interpolation choice.
