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

Implementation started on `plan/06-ground-combat` from integrated main
`186def18af0a0dfcaba979d895afb08e3524d057`. The candidate implements the
server-owned M-7 and aircraft-health rules; acceptance remains open pending
current-source Studio and operated review.

| Criterion | Evidence and outstanding checks |
| --- | --- |
| A1 | Host rifle/health tests pass on earlier source; independent Studio smoke 110/110 server and 3/3 client passed on `275eb73`. Current origin geometry and normal steep-terrain stances still need engine and live-input checks. |
| A2 | Host tests cover pristine three-rocket, mixed, miss and duplicate behavior. The latest fixture adds actual pristine rocket sweeps and measured speed, but has not run in Studio. |
| A3 | Host tests cover bounded requests and movement; earlier actual two-/three-client fixtures exercised cover, rejection and friendly-fire. The latest origin-geometry and recovery fixtures are unrun. |
| A4 | Two actual clients on `275eb73` passed both nonyielding mutual-kill proposal orders; three clients passed the eliminated-teammate case. Instrumented distinct Heartbeat callback order, shared frame, projectile sweeps and operator forfeit are unrun on the latest source. |
| A5 | Two-client P06 7/7 and three-client P06Team 5/5 passed on `275eb73`. Latest repeated reset, stale-resource, reciprocal input and P05 regression checks remain open. |

The [verification record](../docs/evidence/p06-ground-combat.md) preserves
source-specific results, tester findings and the stalled Studio launch. Latest
host gate was 50 unit / 43 integration on `644a90d` with independent source
review. On `a4d53f3` a fresh Studio run passed 118/118 server and 3/3 client
cases after correcting the reproduced smoothed-Terrain bypass; a bounded real
slope probe accepted 154/154 normal standing/jumping samples. The next two-client
SDK launch stalled before Play, so current multiplayer/P05 regression checks
remain open. The test-only manual fallback on `e55a961` reached two actual
clients and passed 118/118 server and 3/3 per-client smoke, but its P06 suite
timed out at the query-failure case after five passing cases. A possible cadence
race is being diagnosed; the actual failure and incomplete suite are recorded.
The user ended that session. Candidate `60aa623` waits for actual server
readiness and adds bounded rejection diagnostics; its fresh host gate and
118/3 Studio smoke pass. The manual two-client rerun then timed out in an
earlier live rifle-hit case, before the query-recovery case. Candidate `6c5a016`
adds live-shot diagnostics and a safely inward fixture position; independent
host and 118/3 Studio smoke pass. Its two-client run passed actual cover,
aircraft-hit and query-failure recovery, then failed the shared-Heartbeat
assertion in the mutual-destruction case; callback values were not recorded
before the assertion, so its cause remains unproven. `56495f9` records callback
timing and outcome before asserting. Its real two-client run showed actual
aircraft-first callbacks within one simulation step and the correct Ground
result; the fixture failed its requested ground-first ordering because Roblox
executed callbacks in reverse registration order. `bdb1de1` calibrates actual
callback scheduling while retaining strict order/step/outcome assertions. Its
manual two-client P06 run passed 10/10, including both actual same-step orders
and Ground/AircraftDestroyed; the manual forfeit used server-kick. Its manual
P06Team run passed 7/7 with three actual clients. The test-only manual P05
regression on `dae58a4` passed 8/8 with two actual clients. The operated review
found a desktop reticle/ray inset mismatch, measured at about 11.3 studs on
the sampled ground surface. The `9adf5d5` fix passed host and 118 server /
4 client Studio smoke, P05 8/8, and the operated desktop reticle/ray comparison.
Simulated phone touch firing, reload and camera motion worked, but its ammo
panel overlapped the centered reticle. `0003fe4` adjusts the touch HUD and
handles device-mode transitions; independent host and Studio smoke pass
(118 server / 6 client). Actual two-client desktop ray alignment and simulated
phone layout, touch fire/reload/swipe pass on `0003fe4`. The native tester could
not acquire and hit the moving plane. The user subsequently hit it in a real
two-client round and health replicated 300→250, but reported no visible health
feedback, shots appearing above the reticle and no gun in the avatar's hands.
These player-facing findings and stale Lobby shot state require fixes and a
fresh review; they are not represented as a pass. `23e053c` adds a primitive
held rifle, dedicated health HUD, server-confirmed shooter hit indicator,
terminal server-impact tracer and reset shot clearing. Host and 118/6 Studio
smoke pass, but actual rifle pose, feedback readability and reported aim
alignment remain pending two-client and operated review.
A real current-P06
screenshot and operated desktop/mobile combat review are also
required. Rifle/aircraft health and movement limits are tuning defaults,
documented separately in decisions. The movement guard permits a 45-stud burst
and does not sweep intervening walls; it bounds movement but does not establish
that every short relocation is impossible.

[Draft PR #27](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/27)
contains the pushed candidate and its current evidence. It is not ready to merge
until the required current-source Studio and operated checks are complete.
[GitHub Verify 43306825870](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/43306825870)
passed on `a8bc57a89413b1ae79bbabd0576e58ef416c04a1`; this does not replace
the missing real-engine evidence.
[GitHub Verify 43310736534](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/43310736534)
also passed on `918296e9182f85edf82789f9ba398a297f9118ca`, containing the
Terrain fix and manual fallback; current Studio acceptance remains open.
[GitHub Verify 43324633959](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/43324633959)
passed on `4d8b56acb5df5fc8d44b143680e4b0fc113d45e8`, including the aim and
reactive mobile HUD fixes. This does not replace the remaining operated review.
