# P06 — Ground weapons and aircraft disablement

**Milestone:** M3. **Dependencies:** P05. **Requirements:** R03, R08, R13, R15. Status: [roadmap](../roadmap.md).

## Capability and player experience

Ground players use rifles and limited anti-air ammunition to threaten the aircraft. Coordinated hits can disable it, ending cannon fire while leaving the objective/extraction mission and deadline active.

## Implementation

Add typed rifle and direct-fire anti-air configurations, equipment selection, reload/reserve rules and server-authoritative shot validation. Use the existing damage/orchestration boundary; do not create a second health system. Add aircraft health/Disabled state, synchronized feedback and a cosmetic failure sequence. Disable queued hostile cannon projectiles as specified in the design. The operator spectates after disablement. Friendly ground fire is off.

## Acceptance criteria

- **A1:** Full gate passes. Tests cover magazine/reserve limits, exact cadence/reload boundaries, switching during reload and finite ammunition; rejection never consumes or grants ammo.
- **A2:** Server tests reject unowned weapons, invented hits, impossible origins/ranges, firing while dead/spectating and cooldown floods. Swept anti-air collision works at configured speed.
- **A3:** Aircraft health clamps at zero, Disabled commits once, cannon requests/in-flight hostile shots stop, and the original round deadline remains unchanged. Operator departure uses the same safe disablement path.
- **A4:** Friendly fire cannot damage ground teammates. Both client contexts observe consistent aircraft health, weapon state and disablement; clients cannot restore aircraft health.
- **A5:** Reset restores aircraft, equipment and ammunition without duplicating tools/listeners or retaining stale shots.

## Focused human check

Run the first reciprocal-combat playtest with both roles. Record ability to aim, see the aircraft, understand ammo/health, use cover and respond to danger. Note balance observations as observations; do not infer a stable win rate from two testers.

## Documentation changes

Update controls, ammunition/cooldown behavior, no-friendly-fire rule and aircraft disablement explanation across player and service docs.

## Completion record

Not implemented. Record A1–A5 evidence, source, combat review and tuning changes with reasons.
