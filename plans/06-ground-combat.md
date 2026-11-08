# P06 — M-7 fire and aircraft destruction

**Milestone:** M3. **Dependencies:** P05. **Requirements:** R03, R08, R11, R13, R15. Status: [roadmap](../roadmap.md).

## Capability and player experience

Every ground teammate spawns with an M-7 rifle and can chip away at the C-130's shared health. Destroying it immediately wins for the ground team. Establish the three-rocket damage contract with automated fixtures; the actual map launcher is delivered in P08.

## Implementation

Add the M-7 loadout, selection/aim/reload/reserve rules and validated ground fire through the existing combat service. Introduce aircraft health and Destroyed state, deriving maximum health from three times direct rocket damage. Add a rocket impact rule exercised through server test fixtures, without granting launchers to the production loadout. Positive small M-7 damage and direct rockets use one health pool. MatchService commits a ground win on destruction and cancels outstanding combat. No active Disabled phase or damaging aircraft crash. Friendly ground fire is off.

## Acceptance criteria

- **A1:** Full gate passes. Tests cover M-7 magazine/reserve/cadence/reload limits, positive aircraft damage, no friendly fire and zero damage through obstructing geometry. Every ground player gets one rifle; none starts with a launcher.
- **A2:** Aircraft tests start at full health: first direct rocket leaves it alive, second leaves it alive, third destroys it and emits one ground-win proposal. Duplicate shot delivery cannot count twice; misses/near misses do not grant direct-hit damage. Mixed M-7/rocket damage can finish it sooner; no hidden regen/modifier breaks the three-hit rule.
- **A3:** Validation rejects unowned weapons, invented hits/origins, impossible range, dead/spectator fire and cadence floods without health/ammo mutation. Swept rocket fixture collisions detect the aircraft at intended speed and orbit position.
- **A4:** Aircraft health clamps at zero and destruction/result commit once; later cannon/rocket events cannot change the winner or health. All ground teammates receive the team win, including eliminated ones; operator disconnect uses a separate forfeit reason.
- **A5:** Two client contexts observe M-7 shots and consistent aircraft health/destruction. Reset restores health, rifles and ammunition with no duplicate tools/listeners or stale shots.

## Focused human check

Run reciprocal M-7 versus aircraft combat. Check aiming at the moving plane, hit/health feedback, cover and team-win clarity. State explicitly that live map launcher pickup remains pending P08; test fixtures are not player inventory.

## Documentation changes

Update named ground weapon, mixed-damage/three-rocket contract, destruction result and currently available loadout. Keep launcher availability correctly labeled as planned.

## Completion record

Not implemented. Record A1–A5 evidence, source, reciprocal combat review and tuning reasons.
