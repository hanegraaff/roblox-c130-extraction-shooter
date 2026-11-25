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

The increment uses `plan/06-ground-combat`, based on integrated main
`186def18af0a0dfcaba979d895afb08e3524d057`. The tested runtime/test candidate
is `0ab360775bdd7d97a2654aa3b6857ddbc3d6157e`, tree
`3d6bb3fd49629f66d12e31f921975a151607714f`. Gameplay is unchanged from
`59252c9`; `dc081f4` improves independent camera-test sampling and `0ab3607`
adds bounded native-client startup diagnostics. Later commits contain prose
and evidence. All current acceptance checks below passed. Integration into
`main` is recorded separately from implementation and validation.

| Criterion | Passing current-source evidence |
| --- | --- |
| A1 | Developer and final primary-agent `python3 scripts/verify.py`: 50 unit / 43 integration, plus format/lint/types, builds, geometry and release isolation. `GroundCombatService` cases cover readiness and reload. Fresh Studio baseline: 118 server and 6 per client. P06 10/10 and P06Team 7/7 include named loadout and cover/Wing-damage cases with ammo/friendly-fire assertions. |
| A2 | `AircraftHealth` host cases cover pristine boundaries, mixed damage, duplicates and misses. Current two-client P06 actual swept fixtures produce pristine 300→200→100→0 at 300 studs/second in 50-stud steps; the named direct-sweep case covers mixed damage/replay/miss behavior. |
| A3 | Named P06 forged/wrong-role and query-failure cases pass in both current two-/three-client suites. `GroundMovementGuard`, `GroundOriginGeometry` and ground-combat cases cover implausible origins, body/cover/Terrain rejection, stale/replayed/flood input, eliminated fire, rejection without mutation and same-sequence recovery. |
| A4 | Both named P06 same-simulation-batch order cases pass with recorded shared frames/equal Heartbeat deltas and Ground/AircraftDestroyed. The actual operator-disconnect case passes with its separate forfeit reason. P06Team proves the eliminated teammate receives the shared Ground result. |
| A5 | P06 10/10 and P06Team 7/7 observe shared shots/health/destruction, repeated reset, tools/listeners/effects cleanup. User accepts current desktop aim/tracers/damage; simulated-phone layout/fire/reload/swipe pass. Current P05 and full P14 regressions pass 8/8 and 6/6. Actual current capture and final documentation review are recorded. |

### Actual Studio and operated evidence

The [verification record](../docs/evidence/p06-ground-combat.md) preserves
all source-specific runs and failures. Its linked structured reports are the
primary evidence; an earlier pass is not relabeled as a current-source run.

Named cases are implemented in the [ground-combat server harness](../tests/studio/server/GroundCombatHarness.luau),
[client observations](../tests/studio/client/GroundCombatHarness.luau),
[rifle rules](../tests/integration/GroundCombatService.spec.luau),
[aircraft health](../tests/integration/AircraftHealth.spec.luau),
[movement guard](../tests/integration/GroundMovementGuard.spec.luau),
[origin geometry](../tests/studio/specs-server/GroundOriginGeometry.spec.luau)
and [independent GUI/native-ray checks](../tests/studio/specs-client/GroundAimGui.spec.luau).
The [final independent QA report](../docs/evidence/p06-final-review.md) resolves
the material findings and identifies the remaining scope limits.

The [final local host report](../docs/evidence/p06-final-host.json) and
[complete gate log](../docs/evidence/p06-final-host.log) record the primary
agent's full verification on unchanged runtime/test source, including exact
environment and expected negative probes. Subsequent prose/evidence changes
require the repository checker rather than another unchanged gameplay run.

- [Current three-client P06Team](../docs/evidence/p06-team-0ab-restart.json):
  7/7, server smoke 118/118 with three players and client smoke 6/6 on each,
  zero failures/skips/errors. This was a distinct controlled restart of exact
  test-runner source after full owner cleanup, with three already-connected
  clients. It is not a clean native cold-start or delayed-join claim.
- [Final fresh native two-client P06](../docs/evidence/p06-final-0ab.json):
  10/10, server smoke 118/118 with two players and 6/6 on each client, zero
  failures/skips/errors. First arrival 7.320930 seconds; actual pristine rocket
  sweeps, both same-frame/equal-delta callback orders, forfeit, repeated reset
  and moving-tracer tests pass. The operator-kick fixture leaves one client;
  the tester then ends the server session and clears all temporary selectors.
- [Current desktop user review](../docs/evidence/p06-user-0ab.json): a normal
  three-player round, native M-7 input, 12 paired request/camera samples and
  health decreasing 195→155 in the preserved window. The user reported visible
  tracers, shots aligned with the crosshair, aircraft damage and no issues.
  This supersedes the earlier failed operated reviews. The [representative
  current capture](../docs/evidence/p06-presentation/current-progress.jpg)
  shows the held primitive rifle and health 155/300; [capture metadata](../docs/evidence/p06-presentation/current-progress.json)
  records its actual source, role, viewport and hash.
- [Current simulated-phone review](../docs/evidence/p06-phone-0ab.json):
  iPhone 17 Pro landscape, 750×381; reticle centered at (375,191), readable
  nonoverlapping controls, touch FIRE 22→17, RELOAD 30/77 and a separate world
  swipe changing the camera. Simulator state and diagnostic observers were
  restored/removed. This is not physical-device evidence.
- [Current P05 regression](../docs/evidence/p06-p05-0ab.json): 8/8 with two
  actual clients. The human-session owner stopped completely before one fixture
  player departed; exact client harness modules were rearmed and the unchanged
  full P05 server suite ran with its normal cleanup.
- [Current P14 regression](../docs/evidence/p06-p14-0ab.json): 6/6 with two
  actual clients, both full weapon orbits, ground/slope/upper-floor projection,
  zoom/rejected selection, concurrent ground movement/operator pan, UI blocking,
  thermal occlusion, role/round reset and repeated teardown. Its final actual
  operator departure left one client as expected; the tester then ended the
  session and confirmed only the original Edit document remained.

### Startup and prior findings

Matched native user shots on `6613375` identified a 58-pixel inset error:
raw mouse and the aircraft's viewport projection agreed, but the firing ray
subtracted GUI inset. Earlier alignment checks mirrored that mistake. The
corrected production ray and GUI drawing now have independent native
`Mouse.UnitRay`, world-projection and measured GUI checks; their previous
claims and subsequent startup failures remain recorded in the evidence.

Native Studio client processes sometimes arrived after the original ten-second
server wait. `0ab3607` permits a separate bounded sixty-second first-client
wait without changing roster or gameplay deadlines. [Startup evidence](../docs/evidence/p06-startup-0ab.json)
contains fresh 118/6 solo smoke and an actual zero-client Run simulation which
correctly emitted an explicit failed zero-discovery report after 60.044 seconds.
That negative probe retained two diagnostic Workspace attributes in Edit and
contaminated a later native launch; the original failed run was preserved and
those temporary attributes cleared before the separate successful runner
restart. The testing guide now documents saving/restoring those exact values.
Arrival beyond ten seconds under the revised budget has not been demonstrated.

The server movement guard's 45-stud burst bounds endpoint displacement without
sweeping intervening walls. It is not a complete movement anti-cheat. The
conservative Terrain-origin policy is tested against current wall/Terrain
fixtures; unusual cave shapes and severe latency need broader later playtests.
Rifle/aircraft health, movement and cosmetic values are tuning defaults in
[decisions](../docs/decisions.md). The actual map launcher remains P08 work.

### Delivery

[PR #27](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/27)
contains the implementation; all required local/Studio and operated checks
pass. The technical writer reviewed the player/contributor narrative and found
no material design contradiction. [GitHub Verify 43340569992](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/43340569992)
passed on `9109d312e283ef31fd5c3482f2154f2e43e470aa`, containing unchanged
tested source and the current screenshot/review/regression records. Final
evidence and review state are recorded in the delivery commits. No P06 merge
or Roblox publication has occurred; no later plan has been implemented.

Final acceptance evidence and reviewed documentation were committed and pushed
at `d72fc6764ac89f2313addc94ba9f1077ca5d5068`. PR #27 was then marked ready
for review. The roadmap records implementation completion separately from
integration and promotes P07 without starting it. The last Studio state is
the sole original test document in Edit with temporary settings cleared.

With the user's later authorization, PR #27 merged into `main` at
`1d71c63a4d8daea5d3f1526f3e02e6be6de6d2c6`. Its tree exactly matches the
final reviewed head. A fresh integrated full host gate passes 50 unit / 43
integration and all other required host checks. The [integration record](../docs/evidence/p06-integration.md)
links exact hashes, builds and the retained Studio acceptance; it does not
claim another engine run. Routine setup now uses `main`. P07 remains unstarted
and no Roblox publication occurred.
