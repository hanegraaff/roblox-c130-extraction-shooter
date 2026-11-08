# Requirements and test traceability

These requirements describe the MVP target. The current source includes the executable foundation, circular greybox, authoritative roles/rounds and P04 perimeter aircraft with inward thermal view and named weapon-linked zoom: deployment, no-respawn lives, spectating, deadlines, basic results and reset. Host suites cover roster boundaries, transition/outcome conflicts, reconnect and command rejection; the [P03 record](plans/03-rounds-and-roles.md) distinguishes its actual host, engine and multiplayer evidence. [P02](plans/02-warzone-map.md) records prior one-client map/walking checks. [P04](plans/04-aircraft-and-thermal.md) records aircraft pose, selection/view, thermal and cleanup acceptance. Combat, aircraft damage and the launcher lifecycle remain planned. The 2026-11-08 expanded terrain/buildings, panning and physical panel destruction are also planned; prior prototype evidence does not validate those changes. Plan records link concrete tests and observed results; this table states each requirement's full behavior and intended test level.

| ID | Requirement | Plans | Required automated evidence |
| --- | --- | --- | --- |
| R01 | Git reconstructs source, configuration, world, terrain and asset references | P01, P02, P13, P12 | Clean-checkout build; map/manifest validation; no test content in release artifact |
| R02 | Match starts with 6–10 players, one operator and one united ground team | P03 | Roster boundary/role-selection tests; Studio role replication |
| R03 | Round lifecycle, deadline and team result are authoritative and reset safely | P03, P06, P09 | Transition, conflict, disconnect and repeated-reset integration tests |
| R04 | No respawns; late join and reconnect cannot recover an active life | P03, P10 | Lifecycle tests plus Studio character/death/reset/rejoin cases |
| R05 | A 720-stud-diameter circular battlefield and matching perimeter orbit keep the aircraft visible and its panned view inward | P02, P04, P13, P14 | Doubled-diameter and equal-radius invariants; tangent model versus bounded panned camera; full-orbit visibility/position and terrain-range checks |
| R06 | Mouse pans the inward thermal view across the larger battlefield; weapon zoom remains coherent and remaining solid panel geometry occludes players | P04, P14, P05, P07 | Pan bounds/recenter/full-orbit/FOV/reticle and elevated-target tests; selection rejection; intact/damaged/hole/destroyed engine occlusion fixtures |
| R07 | 30mm GAU-23/A and 105mm M102 fire with independent readiness and cover protection | P05 | Both weapon profiles, switch/cooldown abuse, validated aim/travel, obstruction and replication tests |
| R08 | M-7 chips away at aircraft health; three direct rockets destroy a pristine plane | P06, P08 | Positive rifle damage; first/second nonlethal and third lethal rocket; mixed damage, replay and miss tests |
| R09 | Building panels visibly progress: three direct heavy hits produce roughly 50% destruction, three more remove the panel; nine seconds sustained 30mm fire damages it; transitions include bounded physical debris | P13, P07 | Heavy-hit 0–6 boundaries; nine-second/no-early-transition, interrupted/mixed-fire/idempotency tests; residual-geometry collision/thermal, rigid-body, two-client/late-join and pristine-reset engine tests |
| R10 | Exactly one map launcher can be acquired, carried and recovered by teammates | P02, P13, P08 | Reachable anchor, atomic raced pickup, one owner/identity, reload-preserving drop/death/disconnect/reset tests |
| R11 | Ground wins on plane destruction; C-130 wins on all-ground elimination or timeout | P03, P06, P09 | Single result, deadline/mutual-kill/forfeit conflicts and complete Studio win/loss/replay paths |
| R12 | Both roles and spectators receive understandable controls, panning/zoom, HUD, visible panel progression and results | P04, P14, P07, P10 | UI state/presentation tests; role-specific input and cleanup tests |
| R13 | Remotes reject malformed, stale, unauthorized and excessive requests | P01, P03–P09, P14 | Table-driven negative inputs, finite-number checks, replay/rate tests; no-state-change assertions |
| R14 | Game supports repeated 6- and 10-player rounds within measured budgets | P11, P12 | Seeded soak/load fixtures, cleanup/resource invariants, recorded multiplayer metrics |
| R15 | Code, tests and documentation are human-readable and kept current | Every plan | Format/lint/type checks, documentation link gate and named reviewer evidence |
| R16 | Authored traversable terrain contains two large buildings and one smaller building, each at least two stories with accessible upper floors and panelized walls/roofs | P13, P07, P11, P12 | Reconstructable terrain/manifest, building count/story/footprint/panel-ID checks; real walking/stair/clearance, supported spawns, two launcher routes and full-orbit cover/sight-line checks |

Existing requirement IDs are preserved. The 2026-11-08 revision extends R05/R06/R09/R12 and adds R16; P13/P14/P07 update the implemented smaller-map/fixed-focus assumptions while preserving prior completion evidence. R07 retains the 105mm M102 name confirmed in D31.

## Shared acceptance rules

- A plan's full applicable verification gate must pass. Add regression tests for fixed behavioral defects; a successful build alone does not prove gameplay.
- Required tests must actually be discovered and executed. A zero-test runner fails, as does any skipped required case. Intentional platform gaps remain open acceptance items.
- Test actual source modules and engine adapters. Do not duplicate production rules in tests and call the duplicate proof.
- Use a requirement ID and an observable behavior in suite documentation. Plan records map each acceptance criterion to a command/test and its result.
- The roadmap's dependency order ensures final integration of requirements spread over multiple plans. Completing an early plan does not imply the entire multi-plan requirement is complete.

## Release boundaries

MVP release requires a 10-player session in the Roblox client in addition to Studio tests. Local test capacity is not assumed to equal production capacity. Publishing and cloud playtests use only an explicitly authorized experience, place, and audience. Until that authorization and access exist, P12 remains incomplete; earlier local work can proceed.
