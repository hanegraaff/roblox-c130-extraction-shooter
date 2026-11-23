# Requirements and test traceability

The 2026-11-10 control revision replaces operator mouse-edge camera panning with
WASD and an on-screen touch directional pad. Mouse movement aims the reticle.
The current MVP has one level; future level interchange must preserve the
circling C-130 and shared camera, zoom, combat and destruction rules.

These requirements describe the MVP target and future level boundary. Integrated `main` includes the recoverable launcher, persistent destruction, playable Outpost, indoor Ground camera, and ordered combat with one attributed result and coordinated replay cleanup. P10 adds role guidance, spectator cycling and client-local presentation controls. The table lists required test levels. Plan records identify the source and environments each check exercised. D59 retains deterministic reconnect authority tests and excludes same-identity reconnect from Studio acceptance. [P17 record](plans/17-integrate-military-outpost.md), [P09 record](plans/09-match-outcomes.md), [P10 plan](plans/10-player-experience.md)

| ID | Requirement | Plans | Required automated evidence |
| --- | --- | --- | --- |
| R01 | Git reconstructs source, configuration, world, terrain and asset references | P01, P02, P13, P12, P16, P17 | Clean-checkout build; map/manifest validation; self-contained Blender sources/exports when added; no test content in release artifact |
| R02 | Match starts with 2–10 players, one operator and one united ground team. A solo player waits in the lobby | P03 | Roster boundary and role assignment tests, production-default deployment test, Studio role replication |
| R03 | Round lifecycle, deadline and team result are authoritative and reset safely | P03, P06, P09 | Transition, conflict, disconnect and repeated-reset integration tests. Studio replay exercises cover, aircraft, equipment and camera restoration. |
| R04 | No respawns. Late join and reconnect cannot recover an active life | P03, P08, P09, P10 | Lifecycle/rejoin service tests plus supported Studio character, death, reset and late-join cases (D59) |
| R05 | A 720-stud-diameter circular battlefield and matching perimeter orbit keep the aircraft visible and its panned view inward | P02, P04, P13, P14 | Doubled-diameter and equal-radius invariants; tangent model versus bounded panned camera; full-orbit visibility/position and terrain-range checks |
| R06 | Operator WASD/touch arrows pan smoothly across the world-aligned level square, blocked only at square edges; independent aim, zoom/recenter and solid-cover thermal occlusion remain | P04, P14, P05, P07, P18 | Edge/corner sliding and reversal, full-orbit/no-jam, native keyboard/touch, both FOVs, reticle and role cleanup tests; server aim restrictions remain authoritative |
| R07 | 30mm GAU-23/A and 105mm M102 fire with independent readiness and cover protection | P05 | Both weapon profiles, switch/cooldown abuse, validated aim/travel, obstruction and replication tests |
| R08 | Aircraft maximum health is 1,000 times deployment Ground-player count, fixed for the round. M-7 deals 5 and direct rockets deal fixed 100 | P06, P08, P09, P18 | 1–9-player roster boundaries, operator exclusion, no mid-round resize/heal, mixed/lethal/deduplicated damage, misses, deadlines, reset and two-client health replication |
| R09 | Every battlefield building panel is destroyed by one direct 105mm hit or two earned seconds of valid 30mm impacts; interrupted credit persists, shortened Light/Heavy/Total progression creates real openings and bounded fragments | P13, P07, P18 | One-hit/two-second boundaries, interrupted/mixed/no-paused-time credit, duplicate/stale rejection, all-building coverage, native opening/thermal/physics, two-client and pristine-reset checks |
| R10 | Ground players can acquire four map launchers: inside hangar, outside radar/depot and inside Prism Seedship. Each player carries at most one | P02, P13, P08, P09, P18 | Four reachable anchors, independent identities, atomic raced pickup, one carrier limit, reload-preserving drop/death/disconnect/reset tests |
| R11 | Ground wins on plane destruction. C-130 wins on all-ground elimination or timeout | P03, P06, P09 | Single committed result and credit, deadline and mutual-kill rules, distinct forfeit/abort reasons, and Studio win/loss/replay with the same result on all clients |
| R12 | Both roles and spectators receive understandable controls, panning/zoom, HUD, visible panel progression and results | P04, P14, P07, P08, P10 | UI state/presentation tests; role-specific input and cleanup tests |
| R13 | Remotes reject malformed, stale, unauthorized and excessive requests | P01, P03–P09, P14 | Table-driven negative inputs, finite-number checks, replay/rate tests; no-state-change assertions |
| R14 | Game supports repeated 6- and 10-player rounds within measured budgets | P11, P12 | Seeded soak/load fixtures, cleanup/resource invariants, recorded multiplayer metrics |
| R15 | Code, tests and documentation are human-readable and kept current | Every plan | Format/lint/type checks, documentation link gate and named reviewer evidence |
| R16 | Desert, forest, urban and Mars-inspired southern districts use connected bunker trails. The southern Seedship site includes red terrain, boulders, low ridges and an impact crater, with transitions to surrounding districts. The three original landmarks and the Seedship have accessible upper floors and panelized walls and roofs | P13, P07, P11, P12, P17 | Reconstructable terrain/manifest, building count/story/footprint/panel-ID checks; real walking/stair/clearance, supported spawns, connected approaches to all four launchers and full-orbit cover/sight-line checks |
| R17 | Operator WASD/touch panning reaches the overall level square smoothly throughout the orbit; independent aiming, selection and recenter remain usable without changing ground movement | P14, P10, P12, P18 | Pure axis/edge/corner/reversal/frame-time and full-orbit tests; native camera/input, near-overhead stability, multitouch, role isolation, GUI/layout and cleanup tests |
| R18 | Every future level has a circling C-130, while panning, zoom, damage and building demolition use core rules with level-supplied geometry/configuration | P14 architecture, P05–P07, archived P15 proposal | Level-schema validation, two distinct level fixtures, boundary/orbit/aim/panel ID tests, reset/late-join reconstruction and multiplayer acceptance before a second level ships |
| R19 | A detailed editable Blender outpost closely matches the three supplied exterior/interior references, includes indoor/outdoor assets and material-specific Pristine/Light/Heavy/Total panels/fragments, and receives explicit human visual approval before integration | P16, P17 | Asset inventory/catalog, Heavy opening/proxy audit, saved-scene clean reopen/render, export/dependency/budget/manifest checks; explicit human approval of the identified `.blend` revision is an additional mandatory nonautomated gate |
| R20 | The approved outpost replaces only the current smaller Outpost while retaining two usable stories, shared damage rules, actual openings, safe fragments, replication and pristine reset on the existing level | P17 | Clean reconstruction and map/registry regression, real avatar navigation, material-family wall/roof collision and thermal checks, actual two-client stage/reset tests, fragment safety, and human approval of actual integrated presentation. D67 waives the P17 performance benchmark |
| R21 | The ground camera smoothly adapts in authored indoor spaces that need closer framing and restores the prior outdoor zoom on exit. Solid cover stays opaque | P17 | Native Ground entry/exit on both Outpost floors, doorway continuity, prior zoom restoration, close outdoor zoom, and cleanup through character or round changes. Operator and spectator camera regressions |

Existing requirement IDs are preserved. The 2026-11-08 revision extends R05/R06/R09/R12 and adds R16; the 2026-11-10 revision updates R06 and adds R17/R18. P13/P14/P07 update the implemented smaller-map/fixed-focus assumptions while preserving prior completion evidence. R07 retains the 105mm M102 name confirmed in D31. R18's two-level checks would apply if a second playable level is commissioned. D71 replaces the planned level-selection feature with art for the existing battlefield.

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
