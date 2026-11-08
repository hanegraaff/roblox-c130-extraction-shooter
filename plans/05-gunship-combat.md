# P05 — 30mm and 105mm gunship combat

**Milestone:** M3. **Dependencies:** P04. **Requirements:** R03, R06, R07, R13, R15. Status: [roadmap](../roadmap.md).

## Capability and player experience

The operator can engage exposed ground players with the 30mm GAU-23/A Chain Gun or 105mm M102 Howitzer. Their firing cadence, blast footprint and zoom differ; intact cover protects players. Eliminating the whole ground team ends the round.

## Implementation

Introduce common combat orchestration, explicit configurations for both aircraft weapons, validated selection/fire intent, per-weapon readiness, server-derived muzzle paths and bounded swept projectile collision. The 30mm offers faster precise fire with tighter view; the 105mm offers slower heavy shells with wider view and readable warning/travel time. Resolve blast against pre-impact geometry; keep breakable cover intact until P07. Switching never resets ammo, cooldown or reload. Add health/elimination and deduplicated cosmetic feedback.

## Acceptance criteria

- **A1:** Full gate passes. For both named weapons, tests cover damage/cadence/reload boundaries, bounded flight lifetime, clamping and one damage award per shot/target.
- **A2:** Switching selects the configured FOV and active weapon coherently, including under rejected/stale requests. Rapid alternating selection cannot reset either weapon's cooldown/reload or refill ammo; remaining readiness survives switch-away/switch-back.
- **A3:** Remote tests reject forged muzzle/hit/damage, wrong role, stale/replayed sequence, impossible aim/range, out-of-disk endpoints, NaN/infinity and floods without health/readiness mutation. Valid shots still succeed afterward.
- **A4:** Engine fixtures show swept queries hit thin cover; exposed targets take configured damage and protected targets take none. Both weapons use authoritative world geometry and respect the inward camera/aim envelope.
- **A5:** Ground death eliminates once without respawn; all-ground elimination commits C-130 victory once. Deadline/result stops later damage, and a shot from a previous round cannot damage the next. Two clients observe consistent selected weapon, shot, health and result; reset clears resources.

## Focused human check

Operate both weapons, switch while reloading and inspect warning/impact/thermal frames. Verify readable differences, useful cover and stable zoom changes. Ground counterfire arrives in P06.

## Documentation changes

Document both weapon contracts, per-weapon timing, zoom mapping, blast cover approximation and actual controls.

## Completion record

Not implemented. Record A1–A5 tests, source, two-client/weapon-switch evidence and feel observations.
