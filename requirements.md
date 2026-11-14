# Requirements and test traceability

The 2026-11-10 control revision replaces operator mouse-edge camera panning with
WASD and an on-screen touch directional pad. Mouse movement aims the reticle.
The current MVP has one level; future level interchange must preserve the
circling C-130 and shared camera, zoom, combat and destruction rules.

These requirements describe the MVP target and future level boundary. Integrated `main` includes the P07 battlefield/round/view/combat/destruction systems plus P08 single-launcher acquisition, carry/recovery, reload continuity and real player-fired rockets. It also contains the approved P16 Blender kit outside runtime mappings; P17 has not replaced the playable building. The [P08 record](plans/08-rocket-launcher.md) preserves its eleven-case native pass on `07e77ea` against production/UI `ef7826b`, with three actual clients and recorded 156-server/seven-per-client smoke. D59 excludes unsupported actual same-identity reconnect while retaining runtime authority tests. The [main integration record](docs/evidence/p08-p16-main-integration.md) records the matching merged tree and fresh full host gate. Later release capacity, presentation and additional levels remain planned. This table states each requirement's full behavior and required test level; plan records identify actual source-bound evidence.

| ID | Requirement | Plans | Required automated evidence |
| --- | --- | --- | --- |
| R01 | Git reconstructs source, configuration, world, terrain and asset references | P01, P02, P13, P12, P16, P17 | Clean-checkout build; map/manifest validation; self-contained Blender sources/exports when added; no test content in release artifact |
| R02 | Match starts with 6–10 players, one operator and one united ground team | P03 | Roster boundary/role-selection tests; Studio role replication |
| R03 | Round lifecycle, deadline and team result are authoritative and reset safely | P03, P06, P09 | Transition, conflict, disconnect and repeated-reset integration tests |
| R04 | No respawns; late join and reconnect cannot recover an active life | P03, P08, P10 | Lifecycle/rejoin service tests plus supported Studio character/death/reset/late-join cases (D59) |
| R05 | A 720-stud-diameter circular battlefield and matching perimeter orbit keep the aircraft visible and its panned view inward | P02, P04, P13, P14 | Doubled-diameter and equal-radius invariants; tangent model versus bounded panned camera; full-orbit visibility/position and terrain-range checks |
| R06 | Operator WASD and mobile directional pad pan the inward thermal view relative to the circling aircraft, with A/left arrow panning left and D/right arrow panning right; the level edge can enter roughly the outer 25% of the viewport in each direction without sky or a straight-down view; mouse movement aims; remaining solid panels occlude players | P04, P14, P05, P07 | Directional key/touch holds, edge visibility/recenter/full-orbit/FOV/reticle and elevated-target tests; selection rejection; intact/damaged/hole/destroyed engine occlusion fixtures |
| R07 | 30mm GAU-23/A and 105mm M102 fire with independent readiness and cover protection | P05 | Both weapon profiles, switch/cooldown abuse, validated aim/travel, obstruction and replication tests |
| R08 | M-7 chips away at aircraft health; three direct rockets destroy a pristine plane | P06, P08 | Positive rifle damage; first/second nonlethal and third lethal rocket; mixed damage, replay and miss tests |
| R09 | All battlefield buildings, including the starting shelter, show persistent Light/Heavy/Total panel damage: three direct heavy hits produce roughly 50% destruction, three more remove the panel; nine valid 30mm seconds damage it and earned credit survives interruptions; transitions include bounded physical debris | P13, P07 | Heavy-hit 0–6 and appearance boundaries; nine-second/no-paused-time credit, persistent interrupted/mixed-fire/idempotency tests; all-building coverage, residual-geometry collision/thermal, rigid-body, two-client and pristine-reset engine tests. D50 waives a real late-join P07 gate; runtime spectator rules remain |
| R10 | Exactly one map launcher can be acquired, carried and recovered by teammates | P02, P13, P08 | Reachable anchor, atomic raced pickup, one owner/identity, reload-preserving drop/death/disconnect/reset tests |
| R11 | Ground wins on plane destruction; C-130 wins on all-ground elimination or timeout | P03, P06, P09 | Single result, deadline/mutual-kill/forfeit conflicts and complete Studio win/loss/replay paths |
| R12 | Both roles and spectators receive understandable controls, panning/zoom, HUD, visible panel progression and results | P04, P14, P07, P08, P10 | UI state/presentation tests; role-specific input and cleanup tests |
| R13 | Remotes reject malformed, stale, unauthorized and excessive requests | P01, P03–P09, P14 | Table-driven negative inputs, finite-number checks, replay/rate tests; no-state-change assertions |
| R14 | Game supports repeated 6- and 10-player rounds within measured budgets | P11, P12 | Seeded soak/load fixtures, cleanup/resource invariants, recorded multiplayer metrics |
| R15 | Code, tests and documentation are human-readable and kept current | Every plan | Format/lint/type checks, documentation link gate and named reviewer evidence |
| R16 | Authored traversable terrain contains two large buildings and one smaller building, each at least two stories with accessible upper floors and panelized walls/roofs | P13, P07, P11, P12, P17 | Reconstructable terrain/manifest, building count/story/footprint/panel-ID checks; real walking/stair/clearance, supported spawns, two launcher routes and full-orbit cover/sight-line checks |
| R17 | Operator directional panning works with desktop WASD and an on-screen touch pad; a held camera angle remains stable relative to the plane through its orbit, while touch aiming, selection and recenter remain usable without changing ground movement | P14, P10, P12 | Pure axis/edge/frame-time and orbit-local tests; actual camera rays and native keyboard/emulated or actual touch hold/multitouch, role isolation, GUI hit, layout and cleanup tests |
| R18 | Every future level has a circling C-130, while panning, zoom, damage and building demolition use core rules with level-supplied geometry/configuration | P14 architecture, P05–P07, P15 | Level-schema validation, two distinct level fixtures, boundary/orbit/aim/panel ID tests, reset/late-join reconstruction and multiplayer acceptance before a second level ships |
| R19 | A detailed editable Blender outpost closely matches the three supplied exterior/interior references, includes indoor/outdoor assets and material-specific Pristine/Light/Heavy/Total panels/fragments, and receives explicit human visual approval before integration | P16, P17 | Asset inventory/catalog, Heavy opening/proxy audit, saved-scene clean reopen/render, export/dependency/budget/manifest checks; explicit human approval of the identified `.blend` revision is an additional mandatory nonautomated gate |
| R20 | The approved outpost replaces only the current smaller Outpost while retaining two usable stories, shared damage rules, actual openings, safe fragments, replication and pristine reset on the existing level | P17 | Clean reconstruction and map/registry regression; real avatar navigation, material-family wall/roof collision/thermal checks, actual two-client stage/reset tests, fragment safety and measured performance; human approval of actual integrated presentation |

Existing requirement IDs are preserved. The 2026-11-08 revision extends R05/R06/R09/R12 and adds R16; the 2026-11-10 revision updates R06 and adds R17/R18. P13/P14/P07 update the implemented smaller-map/fixed-focus assumptions while preserving prior completion evidence. R07 retains the 105mm M102 name confirmed in D31. R18's second playable level is future work and does not claim that the current code already switches levels.

The 2026-11-13 Blender revision adds R19/R20 for P16/P17. The user's follow-up
sequencing revision (D63) places them between P07 and P08 as the next two
increments, before P09 and remaining MVP work. The approved replacement must
participate in the applicable P09/P11/P12 round-loop, regression, performance and
release checks. This does not invalidate earlier simple-art evidence. Reference
images and plans are not delivered models or evidence of implemented
material-aware destruction.

## Shared acceptance rules

- A plan's full applicable verification gate must pass. Add regression tests for fixed behavioral defects; a successful build alone does not prove gameplay.
- Required tests must actually be discovered and executed. A zero-test runner fails, as does any skipped required case. Operations unsupported by Studio are excluded from Studio acceptance under D59. Supported required tests that are temporarily unavailable remain open acceptance items; explicit Roblox-client release gates retain their own environment.
- Test actual source modules and engine adapters. Do not duplicate production rules in tests and call the duplicate proof.
- Use a requirement ID and an observable behavior in suite documentation. Plan records map each acceptance criterion to a command/test and its result.
- The roadmap's dependency order ensures final integration of requirements spread over multiple plans. Completing an early plan does not imply the entire multi-plan requirement is complete.

## Release boundaries

MVP release requires a 10-player session in the Roblox client in addition to Studio tests. Local test capacity is not assumed to equal production capacity. Publishing and cloud playtests use only an explicitly authorized experience, place, and audience. Until that authorization and access exist, P12 remains incomplete; earlier local work can proceed.
