# P05 — Cannon and authoritative damage

**Milestone:** M3. **Dependencies:** P04. **Requirements:** R03, R07, R13, R15. Status: [roadmap](../roadmap.md).

## Capability and player experience

The operator fires a cannon with a visible shot/impact delay and cooldown. Exposed ground players can be damaged and eliminated; solid cover protects them. A round can end with the ground team eliminated.

## Implementation

Introduce combat orchestration, pure weapon/damage rules and validated fire intent. Derive muzzle origin/flight from server state, use swept queries and bounded projectile lifetime, and resolve direct/splash damage against pre-impact geometry. Add server-owned health/elimination integration and deduplicated cosmetic effects. Cooldown feedback may predict locally but must reconcile with accepted/rejected server results. Keep breakable cover intact until P07.

## Acceptance criteria

- **A1:** Full gate passes; damage/cooldown tests cover boundaries, clamps, invalid numbers, maximum flight lifetime and no duplicated damage from repeated impact delivery.
- **A2:** Remote tests reject forged origin/hit/damage, wrong role, stale/replayed sequences, impossible aim/range, NaN/infinity and flood requests without mutating health or cooldown.
- **A3:** Studio fixtures prove swept collision detects a thin wall, exposed targets take configured damage and occluded targets take none. Current geometry, not a client hit list, determines the result.
- **A4:** Ground death triggers one elimination and no respawn. All-ground-eliminated ends the round once; deadline/result prevents later cannon effects from changing health.
- **A5:** A shot still in flight at reset cannot affect the next round. Both clients receive consistent accepted shots/health and bounded effects; teardown returns projectile/effect counts to baseline.

## Focused human check

Check impact warning readability, cannon pacing, cover protection and legible hit/death feedback. At this stage ground players cannot return fire; do not describe the combat slice as balanced yet.

## Documentation changes

Document the weapon contract, units, rejection reasons and blast cover approximation. Update player controls and actual combat scope.

## Completion record

Not implemented. Record A1–A5 tests, source, two-client/occlusion evidence and unresolved feel observations.
