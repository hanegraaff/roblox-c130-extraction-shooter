# Requirements and test traceability

These requirements describe the MVP target. The current source includes the executable foundation, circular greybox assets, pure map/orbit configuration and a server map adapter. Host verification covers the foundation portions of R01/R13/R15 and the pure P02 rules; P02's required engine and walking evidence remains separate. R05's aircraft and R10's launcher lifecycle are still planned. Plan completion records link concrete tests and observed results; this table states each requirement's full behavior and intended test level.

| ID | Requirement | Plans | Required automated evidence |
| --- | --- | --- | --- |
| R01 | Git reconstructs source, configuration, world and asset references | P01, P02, P12 | Clean-checkout build; map/manifest validation; no test content in release artifact |
| R02 | Match starts with 6–10 players, one operator and one united ground team | P03 | Roster boundary/role-selection tests; Studio role replication |
| R03 | Round lifecycle, deadline and team result are authoritative and reset safely | P03, P06, P09 | Transition, conflict, disconnect and repeated-reset integration tests |
| R04 | No respawns; late join and reconnect cannot recover an active life | P03, P10 | Lifecycle tests plus Studio character/death/reset/rejoin cases |
| R05 | A circular map and matching perimeter orbit keep the aircraft visible and its view inward | P02, P04 | Circle/orbit invariants, tangent model versus inward camera, full-orbit visibility/position checks |
| R06 | Thermal view faces the map; selecting 30mm/105mm changes to distinct zoom levels without revealing covered players | P04, P05, P07 | Inward look/FOV/reticle coherence, selection rejection and engine occlusion fixtures |
| R07 | 30mm GAU-23/A and 105mm M102 fire with independent readiness and cover protection | P05 | Both weapon profiles, switch/cooldown abuse, validated aim/travel, obstruction and replication tests |
| R08 | M-7 chips away at aircraft health; three direct rockets destroy a pristine plane | P06, P08 | Positive rifle damage; first/second nonlethal and third lethal rocket; mixed damage, replay and miss tests |
| R09 | Selected cover changes state and collision consistently, then resets | P07 | Threshold/idempotency tests; engine collision and replication tests |
| R10 | Exactly one map launcher can be acquired, carried and recovered by teammates | P02, P08 | Reachable anchor, atomic raced pickup, one owner/identity, reload-preserving drop/death/disconnect/reset tests |
| R11 | Ground wins on plane destruction; C-130 wins on all-ground elimination or timeout | P03, P06, P09 | Single result, deadline/mutual-kill/forfeit conflicts and complete Studio win/loss/replay paths |
| R12 | Both roles and spectators receive understandable controls, HUD and results | P04, P10 | UI state/presentation tests; role-specific input and cleanup tests |
| R13 | Remotes reject malformed, stale, unauthorized and excessive requests | P01, P03–P09 | Table-driven negative inputs, finite-number checks, replay/rate tests; no-state-change assertions |
| R14 | Game supports repeated 6- and 10-player rounds within measured budgets | P11, P12 | Seeded soak/load fixtures, cleanup/resource invariants, recorded multiplayer metrics |
| R15 | Code, tests and documentation are human-readable and kept current | Every plan | Format/lint/type checks, documentation link gate and named reviewer evidence |

Requirement IDs are preserved across the gameplay revision; R05–R08 and R10–R11 now describe the circular arena, selected weapons, launcher and aircraft-destruction loop. No earlier gameplay implementation needs migration.

## Shared acceptance rules

- A plan's full applicable verification gate must pass. Add regression tests for fixed behavioral defects; a successful build alone does not prove gameplay.
- Required tests must actually be discovered and executed. A zero-test runner fails, as does any skipped required case. Intentional platform gaps remain open acceptance items.
- Test actual source modules and engine adapters. Do not duplicate production rules in tests and call the duplicate proof.
- Use a requirement ID and an observable behavior in suite documentation. Plan records map each acceptance criterion to a command/test and its result.
- The roadmap's dependency order ensures final integration of requirements spread over multiple plans. Completing an early plan does not imply the entire multi-plan requirement is complete.

## Release boundaries

MVP release requires a 10-player session in the Roblox client in addition to Studio tests. Local test capacity is not assumed to equal production capacity. Publishing and cloud playtests use only an explicitly authorized experience, place, and audience. Until that authorization and access exist, P12 remains incomplete; earlier local work can proceed.
