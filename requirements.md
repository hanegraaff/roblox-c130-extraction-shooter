# Requirements and test traceability

These requirements describe the MVP target. **None are implemented by the initial design scaffold.** Plans add concrete test filenames and results to their completion records; this table states the required behavior and intended test level.

| ID | Requirement | Plans | Required automated evidence |
| --- | --- | --- | --- |
| R01 | Git reconstructs source, configuration, world and asset references | P01, P02, P12 | Clean-checkout build; map/manifest validation; no test content in release artifact |
| R02 | Match starts with 6–10 players and exactly one operator | P03 | Roster boundary/role-selection tests; Studio role replication |
| R03 | Round lifecycle, deadline and result are authoritative and reset safely | P03, P09 | Transition, conflict, disconnect and repeated-reset integration tests |
| R04 | No respawns; late join and reconnect cannot recover an active life | P03, P10 | Lifecycle tests plus Studio character/death/reset/rejoin cases |
| R05 | Ground players see a synchronized scripted aircraft | P04 | Orbit math, server pose and two-client visibility/position checks |
| R06 | Thermal targeting supports zoom and does not expose players through solid cover | P04, P07 | Camera bounds and engine occlusion fixtures; focused visual review |
| R07 | Cannon shots have validated aim, travel, cooldown and covered-target protection | P05 | Shot validation, impact/deadline, blast obstruction and replication tests |
| R08 | Rifle and limited anti-air can damage/disable the aircraft | P06 | Ammo, cadence, range, aircraft-health and disablement tests |
| R09 | Selected cover changes state and collision consistently, then resets | P07 | Threshold/idempotency tests; engine collision and replication tests |
| R10 | Exactly three reachable objectives are randomized and shared atomically | P08 | Seeded placement, duplicate/raced pickup, distance and death/disconnect tests |
| R11 | Extraction requires all objectives, continuous presence and a live eligible player | P09 | Dwell/reset and outcome-conflict tests; complete Studio win/loss paths |
| R12 | Both roles and spectators receive understandable controls, HUD and results | P04, P10 | UI state/presentation tests; role-specific input and cleanup tests |
| R13 | Remotes reject malformed, stale, unauthorized and excessive requests | P01, P03–P09 | Table-driven negative inputs, finite-number checks, replay/rate tests; no-state-change assertions |
| R14 | Game supports repeated 6- and 10-player rounds within measured budgets | P11, P12 | Seeded soak/load fixtures, cleanup/resource invariants, recorded multiplayer metrics |
| R15 | Code, tests and documentation are human-readable and kept current | Every plan | Format/lint/type checks, documentation link gate and named reviewer evidence |

## Shared acceptance rules

- A plan's full applicable verification gate must pass. Add regression tests for fixed behavioral defects; a successful build alone does not prove gameplay.
- Required tests must actually be discovered and executed. A zero-test runner fails, as does any skipped required case. Intentional platform gaps remain open acceptance items.
- Test actual source modules and engine adapters. Do not duplicate production rules in tests and call the duplicate proof.
- Use a requirement ID and an observable behavior in suite documentation. Plan records map each acceptance criterion to a command/test and its result.
- The roadmap's dependency order ensures final integration of requirements spread over multiple plans. Completing an early plan does not imply the entire multi-plan requirement is complete.

## Release boundaries

MVP release requires a 10-player session in the Roblox client in addition to Studio tests. Local test capacity is not assumed to equal production capacity. Publishing and cloud playtests use only an explicitly authorized experience, place, and audience. Until that authorization and access exist, P12 remains incomplete; earlier local work can proceed.
