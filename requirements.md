# Requirements and test traceability

The 2026-11-10 control revision replaces operator mouse-edge camera panning with
WASD and an on-screen touch directional pad. Mouse movement aims the reticle.
The current MVP has one level; future level interchange must preserve the
circling C-130 and shared camera, zoom, combat and destruction rules.

These requirements describe the MVP target and future level boundary. The P07 candidate on `plan/07-destruction` combines the existing 720-stud terrain/building map, authoritative roles/rounds, inward thermal view and directional pan, gunship/M-7 combat and aircraft-health results with progressive building-panel damage, real residual openings and bounded physical fragments. `main` contains the earlier integrated P06 combat build. The [P07 record](plans/07-destruction.md) distinguishes implementation from remaining engine, multiplayer and operated acceptance; it does not complete every requirement spread across later plans. Launcher handling, release capacity and additional playable levels remain planned. Plan records link source-specific tests and observed results; this table states each requirement's full behavior and required test level.

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
| R09 | All battlefield buildings, including the starting shelter, show persistent Light/Heavy/Total panel damage: three direct heavy hits produce roughly 50% destruction, three more remove the panel; nine valid 30mm seconds damage it and earned credit survives interruptions; transitions include bounded physical debris | P13, P07 | Heavy-hit 0–6 and appearance boundaries; nine-second/no-paused-time credit, persistent interrupted/mixed-fire/idempotency tests; all-building coverage, residual-geometry collision/thermal, rigid-body, two-client and pristine-reset engine tests. D50 waives a real late-join P07 gate; runtime spectator rules remain |
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
