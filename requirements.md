# Requirements and test traceability

The 2026-11-10 control revision replaces operator mouse-edge camera panning with
WASD and an on-screen touch directional pad. Mouse movement aims the reticle.
The current MVP has one level; future level interchange must preserve the
circling C-130 and shared camera, zoom, combat and destruction rules.

These requirements describe the MVP target and the future level boundary. The source integrated on `main` includes the executable foundation, 720-stud circular map with bounded terrain and three two-story buildings, authoritative roles/rounds and P04 perimeter aircraft with inward thermal view and named weapon-linked zoom: deployment, no-respawn lives, spectating, deadlines, basic results and reset. Host suites cover roster boundaries, transition/outcome conflicts, reconnect and command rejection; the [P03 record](plans/03-rounds-and-roles.md) distinguishes its actual host, engine and multiplayer evidence. [P02](plans/02-warzone-map.md) records prior one-client map/walking checks. [P04](plans/04-aircraft-and-thermal.md) records aircraft pose, selection/view, thermal and cleanup acceptance. Combat, aircraft damage and the launcher lifecycle remain planned. P13 implements the expanded terrain/building source and adds its own validation; its [plan record](plans/13-terrain-and-buildings.md) owns the actual acceptance results. The unmerged P14 source candidate adds directional pan, recenter, surface-aware reticle projection and an authored aim-height envelope; real-engine and operated acceptance results are recorded in [P14](plans/14-aircraft-panning.md). Physical panel destruction remains planned. Prior prototype evidence does not validate the expanded map. Plan records link concrete tests and observed results; this table states each requirement's full behavior and intended test level.

| ID | Requirement | Plans | Required automated evidence |
| --- | --- | --- | --- |
| R01 | Git reconstructs source, configuration, world, terrain and asset references | P01, P02, P13, P12 | Clean-checkout build; map/manifest validation; no test content in release artifact |
| R02 | Match starts with 6–10 players, one operator and one united ground team | P03 | Roster boundary/role-selection tests; Studio role replication |
| R03 | Round lifecycle, deadline and team result are authoritative and reset safely | P03, P06, P09 | Transition, conflict, disconnect and repeated-reset integration tests |
| R04 | No respawns; late join and reconnect cannot recover an active life | P03, P10 | Lifecycle tests plus Studio character/death/reset/rejoin cases |
| R05 | A 720-stud-diameter circular battlefield and matching perimeter orbit keep the aircraft visible and its panned view inward | P02, P04, P13, P14 | Doubled-diameter and equal-radius invariants; tangent model versus bounded panned camera; full-orbit visibility/position and terrain-range checks |
| R06 | Operator WASD and mobile directional pad pan the inward thermal view relative to the circling aircraft, with A/left arrow panning left and D/right arrow panning right; the level edge can enter roughly the outer 25% of the viewport in each direction without sky or a straight-down view; mouse movement aims; remaining solid panels occlude players | P04, P14, P05, P07 | Directional key/touch holds, edge visibility/recenter/full-orbit/FOV/reticle and elevated-target tests; selection rejection; intact/damaged/hole/destroyed engine occlusion fixtures |
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
| R17 | Operator directional panning works with desktop WASD and an on-screen touch pad; a held camera angle remains stable relative to the plane through its orbit, while touch aiming, selection and recenter remain usable without changing ground movement | P14, P10, P12 | Pure axis/edge/frame-time and orbit-local tests; actual camera rays and native keyboard/emulated or actual touch hold/multitouch, role isolation, GUI hit, layout and cleanup tests |
| R18 | Every future level has a circling C-130, while panning, zoom, damage and building demolition use core rules with level-supplied geometry/configuration | P14 architecture, P05–P07, P15 | Level-schema validation, two distinct level fixtures, boundary/orbit/aim/panel ID tests, reset/late-join reconstruction and multiplayer acceptance before a second level ships |

Existing requirement IDs are preserved. The 2026-11-08 revision extends R05/R06/R09/R12 and adds R16; the 2026-11-10 revision updates R06 and adds R17/R18. P13/P14/P07 update the implemented smaller-map/fixed-focus assumptions while preserving prior completion evidence. R07 retains the 105mm M102 name confirmed in D31. R18's second playable level is future work and does not claim that the current code already switches levels.

## Shared acceptance rules

- A plan's full applicable verification gate must pass. Add regression tests for fixed behavioral defects; a successful build alone does not prove gameplay.
- Required tests must actually be discovered and executed. A zero-test runner fails, as does any skipped required case. Intentional platform gaps remain open acceptance items.
- Test actual source modules and engine adapters. Do not duplicate production rules in tests and call the duplicate proof.
- Use a requirement ID and an observable behavior in suite documentation. Plan records map each acceptance criterion to a command/test and its result.
- The roadmap's dependency order ensures final integration of requirements spread over multiple plans. Completing an early plan does not imply the entire multi-plan requirement is complete.

## Release boundaries

MVP release requires a 10-player session in the Roblox client in addition to Studio tests. Local test capacity is not assumed to equal production capacity. Publishing and cloud playtests use only an explicitly authorized experience, place, and audience. Until that authorization and access exist, P12 remains incomplete; earlier local work can proceed.
