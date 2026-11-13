# Roadmap to MVP

The integrated source on `main` includes the development shell, verification tooling, 720-stud circular battlefield with bounded terrain and three two-story buildings, authoritative roles/rounds, perimeter aircraft, verified WASD/mobile panning with weapon-linked zoom, gunship combat, M-7 fire and aircraft destruction. [PR #27](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/27) integrates P06; its [integration record](docs/evidence/p06-integration.md) identifies the exact merge and fresh host gate. P13 map acceptance is integrated through [PR #16](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/16). The P14 stack is integrated through [PRs #18–#22](docs/evidence/p14-integration.md); its two-client, mobile touch, full-orbit, rendered-cover and layout checks pass. [P14 acceptance evidence](docs/evidence/p14-horizontal-acceptance.md) and the [integration record](docs/evidence/p14-integration.md) identify tested source and merge facts. P05 is integrated through [PR #25](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/25); P07 persistent panel damage, real openings, physical fragments and starting-shelter destruction are integrated through [PRs #30 and #29](docs/evidence/p07-integration.md), with a matching accepted tree and fresh main host gate. P15 reserves future interchangeable levels with a circling C-130 and shared game systems. Build one complete, tested capability at a time. See [game design](game-design.md) for the complete intended game.

## Milestones and plans

| Milestone | Plan / capability | Status | Depends on | What a human can experience afterward |
| --- | --- | --- | --- | --- |
| M1 — Playable foundation | [P01: Executable foundation and tests](plans/01-foundation.md) | Complete | — | Open a development place, spawn, and see an explicit test/boot status |
| M1 | [P02: Circular greybox battlefield](plans/02-warzone-map.md) | Complete | P01 | Walk the circular warzone and both approaches to the launcher anchor |
| M1 | [P03: Roles and round lifecycle](plans/03-rounds-and-roles.md) | Complete | P02 | Join a lobby, receive a role, enter a round, spectate and return |
| M2 — Gunship | [P04: Perimeter aircraft and inward thermal view](plans/04-aircraft-and-thermal.md) | Complete | P03 | Ground sees the orbit; operator looks inward with distinct 30mm/105mm zoom profiles |
| M2 — Level revision | [P13: Expanded terrain and multi-story buildings](plans/13-terrain-and-buildings.md) | Complete | P04 | Walk a 720-stud-diameter terrain map with two large buildings and one smaller one, each at least two stories |
| M2 — View revision | [P14: Directional aircraft targeting](plans/14-aircraft-panning.md) | Complete | P13 | Pan the aircraft view with WASD or mobile arrows, aim independently and retain the view through the orbit |
| M3 — Combat slice | [P05: 30mm and 105mm gunship combat](plans/05-gunship-combat.md) | Complete | P04, P14 | Operator fires both named weapons through the panned view while cover protects players |
| M3 | [P06: M-7 fire and aircraft destruction](plans/06-ground-combat.md) | Complete | P05 | M-7-equipped teammates damage the plane; destroying it wins the round |
| M4 — Changing cover | [P07: Progressive building-panel destruction and physics](plans/07-destruction.md) | Complete | P06, P13, P14 | See persistent Light/Heavy/Total damage on every battlefield building, including the starting shelter, with real openings and falling fragments |
| M5 — Team battle loop | [P08: One recoverable map rocket launcher](plans/08-rocket-launcher.md) | Ready | P07 | Acquire/recover one launcher and destroy an undamaged plane with three direct hits |
| M5 | [P09: Complete team win/loss and replay loop](plans/09-match-outcomes.md) | Planned | P08 | Win by plane destruction, ground elimination or timeout, then replay cleanly |
| M6 — MVP readiness | [P10: Player guidance, spectating and presentation](plans/10-player-experience.md) | Planned | P09 | Understand each role, weapons, launcher, elimination and team result without developer help |
| M6 | [P11: Balance, performance and resilience](plans/11-balance-and-performance.md) | Planned | P10 | Play repeated stable rounds with readable counterplay |
| M6 | [P12: Reconstructable release and multiplayer acceptance](plans/12-mvp-release.md) | Planned | P11 | Play the verified MVP in an explicitly authorized Roblox test/release experience |
| M7 — Future levels | [P15: Interchangeable levels](plans/15-interchangeable-levels.md) | Planned | P12 | Choose among validated levels, each with a circling C-130 and the same camera, zoom, combat and demolition rules |

2026-11-12 P05 delivery: source `232889f` passes the 50-unit / 33-integration
host gate, 104 server and 3 per-client Studio smoke, and the eight-case
two-client P05 harness. Operated desktop and simulated-phone checks verify
firing, panning and simultaneous touch controls; the independent review's
material presentation and collision findings were fixed and rechecked.
[PR #25](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/25)
is integrated on `main` at `5cc7de8`; P06 used updated main including those records.
The [P05 plan](plans/05-gunship-combat.md) and [evidence](docs/evidence/p05-gunship-combat.md)
record tested source, remaining limitations and prior failures; the
[integration record](docs/evidence/p05-integration.md) records the matching tree
and fresh main gate.

2026-11-12 P06 delivery: tested runtime/test source `0ab3607`, tree
`3d6bb3fd49629f66d12e31f921975a151607714f`, passes the final 50-unit /
43-integration host gate, fresh native two-client P06 10/10 with 118 server
and 6 per-client smoke, controlled three-client P06Team 7/7, and current
two-client P05/P14 regressions 8/8 and 6/6. The user accepted corrected
crosshair/tracer/damage feedback; simulated-phone controls and current gameplay
captures are recorded. Earlier failed launches and the contaminated Run probe
remain separately preserved. Final evidence and documentation were pushed at
`d72fc6764ac89f2313addc94ba9f1077ca5d5068`; [PR #27](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/27)
is ready for review. See the [P06 record](plans/06-ground-combat.md) and
[final independent QA](docs/evidence/p06-final-review.md). P07 is eligible but
unstarted; it must include the P06 branch source or its eventual merge. No P06
merge or Roblox publication occurred.

2026-11-12 P06 main integration: with user authorization, PR #27 merged into
`main` at `1d71c63a4d8daea5d3f1526f3e02e6be6de6d2c6`, with a tree identical
to verified final head `dce058d`. The fresh integrated full host gate passes
50 unit / 43 integration and all build/geometry/isolation gates. The
[integration record](docs/evidence/p06-integration.md) preserves merge, build
and existing Studio evidence. Routine setup selects `main`; P07 can branch
from it and remains unstarted. No Roblox publication occurred.

2026-11-13 P07 main integration: with the user's authorization, PR #30 merged
into the P07 branch at `6336830`, then PR #29 merged it into `main` at
`3c0cfab`. Both merge trees exactly match accepted final head `15b362f`.
A fresh full gate on integrated main passes 55 unit / 55 integration and all
build/reconstruction/isolation checks. The [integration record](docs/evidence/p07-integration.md)
preserves exact hashes, commands, prior Studio evidence and scope. Routine
setup now selects main. P07 stays Complete; P08 stays Ready and unstarted,
with its dependency source now integrated. No Roblox publication occurred.

2026-11-13 accepted P07 revision (pre-integration): the user removed a real late-joining-client
scenario from current acceptance (D50). That old unavailable capability no
longer blocks P07; runtime spectator restrictions remain. Dedicated
`fix/p07-progressive-persistent-damage` and dependent
[PR #30](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/30)
preserve earned 30mm damage, distinguish Light/Heavy/Total and make the starting
battlefield shelter destructible under the same rules as the other buildings.
Final source `8053c8f` passes the independent 55-unit / 55-integration host gate
and GitHub CI; the unchanged production core's fresh Studio baseline passes
142 server / 6 client. Final actual two-client P07 passes 7/7, including both
live-work resets with all 187 panels verified on server and each client. P05
passes 8/8. Actual native-fired normal/thermal Warehouse and shelter reviews
show persistent Light scars, Heavy's real half opening and Total removal;
stopped/resumed native GAU fire credits no paused time. Final P14 regression
passes 6/6, including both full orbits and actual operator departure. The
separate visual falling-fragment observation also passes: in an additional
ordinary live-orbit two-player round, the user confirms “Yes, I saw pieces
fall” after the third native M102 target hit in a labelled Ground close-up.
Actual recorded gravity/contact agrees; earlier settled GPU captures are not
relabelled as airborne proof. The
[revision record](docs/evidence/p07-damage-revision.md) separates current proof
from earlier failed runs. P07 acceptance is complete on this branch and P08
is Ready, without starting implementation. P08 must include this dependency
source until integration. No P07 integration or Roblox
publication occurred.

2026-11-13 earlier P07 candidate (historical): [draft PR #29](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/29)
contains progressive panels, real openings and bounded physical fragments on
`plan/07-destruction`, based on integrated main `e4c6e3a`. The final executable
candidate `873f0f6` passes 54 unit / 53 integration and all host gates;
unchanged core `cb530a0` passed clean Studio 137 server / 6 client tests.
Actual two-client checks prove heavy/30mm progression, wall traversal,
state agreement and debris expiry. Separate actual-player blast checks pass
2/2, P05 regression 8/8, reset-only two-round checks 2/2 and P14 regression
6/6. These separate results do not turn the failed full P07 late-join run
into a pass. The [plan record](plans/07-destruction.md) and
[verification evidence](docs/evidence/p07-destruction.md) retain exact scopes,
source hashes, failures, cleanup and the current QA opening capture.

At that earlier checkpoint, acceptance still needed a genuinely new post-damage client: the installed
Studio 0.747 manual session disables both client count and Quick Open Actions
Start, and the previously unavailable SDK/manual-session AddPlayers routes
were not retried without changed conditions. Clean rendered thermal-hole
comparison, Destroyed/falling-fragment visual review and native firing /
complete operated readability also remain open after bounded review attempts.
That checkpoint's late-join requirement is superseded by D50 and the active
revision above. P08 remained Planned; no later plan started. Main was unchanged,
and no P07 merge or Roblox publication occurred.

## How plans move

`Planned` → `Ready` → `In progress` → `Complete`. Use `Blocked` only for a concrete missing decision, access or dependency, with the reason in the plan record. Dependency sequencing alone is represented by Planned. Only this table owns status; individual plans own implementation/evidence records.

Plan IDs remain stable; table/dependency order places the later-added P13/P14 before P05 rather than renumbering delivered plans. Select the lowest-numbered Ready plan whose dependencies are Complete; then ensure those dependencies' source is present on the implementation branch before coding. Resolve an open dependency PR's branch when main lacks that source. Resume an In progress plan before starting another. Reassess a Blocked plan when new evidence shows its blocker may have cleared; elapsed time alone is not resolution. If no Ready plan exists, the coordinator may promote the first Planned plan whose dependencies are complete. An unresolved Blocked prerequisite cannot be skipped to claim its dependent capability.

Use the [feature-loop skill](.agents/skills/implement-next-plan/SKILL.md) for one plan. Split a plan here before implementation if it is no longer a coherent increment; preserve IDs and requirement links. Do not implement the entire roadmap in one invocation.

## Completion versus release

A Complete plan has all required automated and Studio evidence, resolved material tester findings, current documentation, and source pushed to GitHub. Its completion record identifies the tested source and PR; PR integration may still await the human's decision. Dependent work must include that source, rather than starting from stale main.

P01 establishes the full non-Studio `python3 scripts/verify.py` gate. Every later plan must preserve it and add its own acceptance suites. Studio is a distinct required gate when the plan changes engine/player behavior. A green CI badge cannot substitute for it.

Only P12 requires cloud publication and real 10-player acceptance. Prepare the candidate first, then use existing explicit authorization or request it for the actual experience/place/audience. Local feature testing and GitHub delivery can proceed before those IDs are known. No source or documentation task implicitly authorizes a Roblox release.

## First meaningful review points

- After **P04**, check the two-role experience: both views describe the same world and cover works visually.
- After **P13/P14**, review terrain/building traversal and full-orbit pan reach at both zooms before combat depends on them.
- After **P06**, test attacking and counterattacking on the revised map.
- After **P07**, demonstrate the complete panel progression and physical fragments with simple graphics; art refinement cannot substitute for missing mechanics.
- After **P09**, play the complete team-versus-plane loop and inspect destruction/elimination/timeout conflicts.
- After **P12**, the MVP is ready only with the recorded gates and authorized publication; “code written” is not release completion.

## Later asset refinement and other proposals

Future ideas beyond P15 belong in separate post-MVP proposals: additional weapons, gamepad, progression, matchmaking, vehicles or full structural collapse. Operator touch panning belongs to P14; interchangeable levels belong to P15. Progressive panel destruction and bounded physical fragments are required MVP scope, not deferred ideas.

Dedicated later asset-generation plans should separately refine terrain dressing, building architecture/materials and damage/debris variants, and aircraft/equipment assets. Scope those proposals after the simple-graphics mechanics are demonstrated, retaining panel IDs/pivots, openings, collision, thermal readability and performance contracts. P10 supplies readable UI/effects/audio, without making high-detail art an MVP dependency. These are future planning topics, not newly authorized implementation increments.

## Initial delivery record

2026-11-07: established design, architecture, requirements, twelve plans, repository-local feature loop, role instructions, source/test/asset boundaries and build verification. [Scaffold evidence](docs/evidence/bootstrap.md) records checks. No gameplay plan is complete.

2026-11-07 gameplay revision: changed the design to Players vs C-130, a circular battlefield/perimeter orbit, inward weapon-linked camera zoom, 30mm/105mm aircraft weapons, M-7 rifles and one recoverable launcher. P08/P09 replace their previous collection/escape scope while retaining IDs; no implementation status changes. The user confirmed rifle chip damage plus three direct rockets from full aircraft health.

2026-11-08: P01 delivered the executable shell with passing clean-install, static/unit/service/build/isolation gates, independent Studio server/client restart evidence and current documentation. [PR #3](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/3) was merged into `main` with user authorization at `b62f6132ea0998d880daab2d1a5d86b7ab6cd95d`, including the main README’s Studio play/test instructions. See the [P01 completion record](plans/01-foundation.md). P02’s prerequisite source is now on `main`; its subsequent implementation record follows. No Roblox publication occurred.

2026-11-08: P02 source implementation and independent host verification are delivered in [draft PR #4](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/4). The full host gate passes (14 unit / 2 integration), and clean reconstruction matches both candidate build hashes. Required Studio map/route/cover/boundary/rebuild and walking evidence is blocked: MCP lists null-name instances but reports **Place is not open** after local-file open attempts and a dialog recheck. See the [P02 record](plans/02-warzone-map.md). P02 is not Complete; P03 remains Planned. No merge or Roblox publication occurred.

2026-11-08 resumption: the user opened the exact P02 local test document, clearing the open-place blocker. Engine inspection found a material asset serialization defect: authored Position/Orientation values were absent from the loaded CFrames. P02 is resumed for correction and required engine validation; the existing host checks did not detect this defect. P03 remains Planned.

2026-11-08 correction: `8147d1c` replaces all 112 authored part poses with canonical CFrame and adds artifact geometry comparisons plus five corruption probes. Independent full host verification and GitHub Verify pass. The old candidate’s actual Studio startup failure is preserved in evidence. Corrected engine acceptance is blocked until `p02-tests-5c809beff70b.rbxlx` is accessible; automated open still yields an unnamed/unavailable instance and the user has been asked to open it manually. PR #4 stays draft; P03 remains Planned.

2026-11-08 completion: P02’s corrected source `8147d1c` passes independent host gates and two fresh Studio sessions (23 server / 2 client cases each, one actual client, no failures/skips/errors), actual walking on both approaches, physical boundary contact/recovery and clean rebuild/restart checks. Material serialization findings are resolved. Evidence and documentation are pushed in `7ac678e`; [PR #4](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/4) is ready for review and remains unmerged. The [P02 record](plans/02-warzone-map.md) links exact source/build/report facts. P03 is Ready but has not been implemented; its future branch must include the open P02 source. No Roblox publication occurred.

2026-11-08 integration: PR #4 merged into `main` with user authorization at `6c919de9990bcc1379bb7e52e67f9805e0abb683`, after its final head passed GitHub Verify. P02 remains Complete and its dependency source is integrated; P03 remains Ready and has not been implemented. The root-guide/steering follow-up in PR #5 is retargeted to `main`. No Roblox publication occurred.

2026-11-08 P03 delivery: authoritative roles/rounds, explicit no-respawn characters, reconnect/late-join restrictions, teammate spectating, basic results and map/camera reset pass independent host verification (24 unit / 14 integration), six adversarial probes, Studio baseline (45 server / 2 per actual client), nine multiplayer scenarios over three rounds with initial three / peak four clients, and focused two-client review. Unsafe seed and asynchronous teardown findings are resolved. Tested source is `e0d2857`; source, documentation and durable evidence are pushed in `b798a02`. [PR #6](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/6) is open for review, unmerged; [GitHub Verify run 42518634591](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/42518634591) passes on that candidate. See the [P03 record](plans/03-rounds-and-roles.md). P04 is Ready but has not been implemented; its source must include the open P03 branch until integration. No Roblox publication occurred.

2026-11-08 human-testing follow-up: the user requested lobby walking, solo exploration and role/settings controls. [PR #7](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/7) delivers a test-only panel, chosen solo/real-round roles, duration/start/reset controls and unlocked Waiting movement on `fix/human-test-controls`, stacked on open P03 PR #6. Full host verification (24 unit/14 integration), Studio baseline (45 server / 2 client), four movement cases, six solo human-control cases and four actual two-client role cases pass; [GitHub Verify](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/42523454928) also passes. [Evidence](docs/evidence/lobby-preview.md) records tested source `b243090`, pushed candidate `bbe2c94`, captures and limits. Existing roadmap statuses are unchanged; P04 has not been implemented. Neither PR was merged and no Roblox publication occurred.

2026-11-08 integration completion: with explicit user authorization, P03 [PR #6](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/6) merged at `031c7dc1735b3ed6f0f8a2ed49a8d042576e23cc`, then the human-testing [PR #7](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/7) was retargeted to `main` and merged at `6cf0f1ee29e4c122f2d7d68164a2d93ff2408238`. Integrated content is identical to checked PR #7 head `939e890`; a fresh full host gate passes 24 unit/14 integration with matching builds. [Integration evidence](docs/evidence/p03-integration.md) records the verification. Routine local setup now uses `main`. P03 stays Complete, P04 stays Ready and unimplemented; no dependency branch is needed for their integrated source. No Roblox publication occurred.

2026-11-08 P04 delivery: the canonical perimeter aircraft, inward thermal camera, bounded reticle and acknowledged 35°/60° named weapon profiles pass independent host verification (30 unit / 18 integration), five adversarial probes and six two-client Studio scenarios spanning a full 90-second orbit and two rounds. Baseline reports pass 57 server / 2 per actual client; maximum observed pose difference is 0.424 studs against the declared eight-stud bound. Final operated controls/rendered cover occlusion/cleanup review passes. The stale aircraft-planned label is resolved; prototype HUD overlap and a wide-view aircraft strip in the upper-left sky remain documented presentation limits. Tested logic is `33e7b1d`; final label/comment source is `b27f738`; documentation and durable evidence are pushed in `7d9e200`. [PR #9](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/9) is ready for review and unmerged. See the [P04 record](plans/04-aircraft-and-thermal.md). P05 is Ready but has not been implemented; its branch must include the open P04 source until integration. No merge or Roblox publication occurred.

2026-11-08 P04 integration: with explicit user authorization, [PR #9](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/9) merged into `main` at `da1327ac60425c544b7f2804107bb318fe9490dd`. Its tree is identical to checked final head `2f6432f`, which passed [GitHub Verify 42526346654](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/42526346654). A fresh integrated full host gate passes 30 unit / 18 integration tests and both build hashes match the final Studio-reviewed candidate. [Integration evidence](docs/evidence/p04-integration.md) records exact source/build and validation scope. Routine local setup now uses `main`; P04 stays Complete and P05 stays Ready/unimplemented, with no unmerged dependency branch required. No Roblox publication occurred.

2026-11-08 MVP level steering revision: selected twice the implemented diameter (360 → 720 studs), terrain, two large buildings plus one smaller building (all at least two stories), mouse panning with weapon zoom, and visible progressive panel destruction with real bounded fragment physics. Added P13 (construction) and P14 (panning) ahead of P05; existing plan IDs and completed P01–P04 evidence are preserved. P07 now requires 3 + 3 direct heavy hits, roughly 50%-open damaged geometry and nine seconds of sustained on-panel 30mm fire to damage a panel, even with primitive assets. R16 adds terrain/building traceability. D31 records the user's confirmation to keep the existing 105mm M102 and apply the new panel-damage rules; interruption/mixing/debris details are labeled defaults. This is documentation/steering only: no new gameplay, engine evidence or completion claim. Later asset refinement is separately scoped. No merge or Roblox publication occurred.

2026-11-08 P13 candidate delivery: [draft PR #12](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/12) contains a 720-stud battlefield, deterministic terrain, two large and one smaller two-story buildings, usable upper floors and 111 registered wall/roof/interior panels. Tested source `ea9cd4e` passes independent/current host gates (33 unit / 18 integration, 351 authored transforms), clean reconstruction and Studio baseline (67 server / 2 client). Two actual clients agree initially and after two perturbed resets; an actual Humanoid reaches all three upper floors; focused routes/hill movement and single-client controls pass. P13 remains Blocked: third-client late join times out, a subsequent Studio server launch encounters Roblox metadata/sign-in timeouts, the P04 reticle assertion/full-orbit regression remains unresolved, and fresh serialized-place loading was rejected before launch by automatic approval review because of duplicate-instance/unsaved-work risk. The [P13 record](plans/13-terrain-and-buildings.md) and [evidence](docs/evidence/p13-terrain-and-buildings.md) preserve exact results and next checks. Documentation and a real Studio Edit overview describe the current candidate. [GitHub Verify 42533469132](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/42533469132) passes on the tested source; acceptance is incomplete and PR stays draft. P14 remains Planned; no merge or Roblox publication occurred.

2026-11-08 building-flicker integration: with user authorization, [PR #13](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/13) merged into `plan/13-terrain-and-buildings` at `4d329a0c28e33a709321755b89a7a46af2d362b3`. Its tree matches reviewed/CI-passing head `3f949c7`; a fresh integrated full host gate passes 33 unit / 18 integration, 351 transforms per artifact and 7,146 surface-pair checks. The [fix integration record](docs/evidence/building-flicker.md#merge-and-integration--2026-11-08) links source/build/CI facts and the existing unchanged-source Studio evidence. Routine candidate setup now selects the P13 branch containing the fix. P13 remains Blocked and PR #12 stays draft with its recorded acceptance gaps; P14 remains Planned. No Roblox publication occurred.

2026-11-08 P13 main integration: with explicit user authorization, [PR #12](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/12) merged into `main` at `19b70082b69f00f3901359403f39ba51b67a0506`, including the surface-flicker fix and its records. Its tree is identical to reviewed head `2e3e4d5`, which passed [GitHub Verify 42536588227](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/42536588227). A fresh main full host gate passes 33 unit / 18 integration, 351 authored transforms per artifact, 111 panel pivots and 7,146 surface-pair checks. [Main integration evidence](docs/evidence/p13-integration.md) preserves hashes and verification scope. Routine setup now selects `main`. P13 remains Blocked with late-join/final teardown, P04 reticle/full-orbit, two-client human-controls and fresh-file acceptance open; P14 remains Planned and has not started. No Roblox publication occurred.

2026-11-08 P13 acceptance closure: source `e2e4e5` on `fix/p13-engine-acceptance` passes fresh native-world reconstruction (5/5), expanded-map multiplayer (5/5, two initial / three actual peak clients), full 90-second P04 aircraft regression (6/6) and two-client human controls (4/4). Baselines pass 67 server / 2 per actual client with zero failures/errors/skips. Current host gate passes 33 unit / 18 integration and all build/static/geometry checks; [CI Verify 42540612044](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/42540612044) passes. The independent tester has no remaining material findings; final docs match the current experience. [Acceptance evidence](docs/evidence/p13-acceptance.md) and the [plan record](plans/13-terrain-and-buildings.md) preserve source identity, failed launch history, actual reports and limitations. P13 is Complete; P14 is Ready but has not started. [PR #16](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/16) delivers the acceptance tooling and records separately from unchanged main; no merge or Roblox publication occurred.

2026-11-08 P13 acceptance integration: with explicit user authorization, [PR #16](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/16) merged into `main` at `de1eb9b3bcf400dc0168067a1e2d9694e26ca22f`. Its tree equals reviewed head `545e6cd`, which passed [GitHub Verify 42544610250](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/42544610250). A fresh integrated host gate passes 33 unit / 18 integration and every build/static/geometry gate. The [integration record](docs/evidence/p13-acceptance-integration.md) preserves exact hashes and the verification log. Passing engine evidence remains applicable to identical source; routine setup now uses main for the game, test-startup corrections and native-world probe. P13 stays Complete; P14 stays Ready/unimplemented. No Roblox publication occurred.

2026-11-09 P14 candidate delivery: `a326133` implements bounded mouse edge panning, persistent world-space focus through orbit/zoom, R recenter, geometry-aware reticle rays and authored-height/selected-muzzle aim validation. Full host gate passes 43 unit / 18 integration and every static/build/geometry/release-isolation gate; [CI Verify 42720211427](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/42720211427) passes. Independent source review finds no material defect; a 73,205-case clamp probe produces no nonfinite output. [Draft PR #18](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/18) preserves the source. P14 is Blocked: the original Studio document disconnected, and MCP exposes only an unnamed instance reporting Place is not open despite confirmed Rojo service. Required actual two-client/full-orbit projections, native input, rendered thermal/layout/comfort, lifecycle regressions and gameplay capture are unrun. The [P14 record](plans/14-aircraft-panning.md) and [evidence](docs/evidence/p14-aircraft-panning.md) retain exact facts and recovery steps. P05 remains Planned and unstarted; no merge or Roblox publication occurred.

2026-11-09 P14 engine follow-up: current source `8bbab8e` resolves fixture steering/pointing sequencing, real GUI-inset hover blocking and a reproduced fractional reticle raster mismatch. Full host gate passes 46 unit / 18 integration; current ordinary Studio smoke passes 82 server / 3 client. Earlier two-client arrival regression passes 2/2 and 585 native camera samples pass; native input, numeric layout at both resolutions and repeated preview cleanup have focused positive evidence. Full current P14 acceptance is Blocked: native UI requests two clients but only one connects; manual sequential AddPlayers is rejected outside an SDK-owned session. Complete rendered thermal/both-FOV orbit comfort review is also unavailable after native viewport-focus loss. All owned simulations are ended, the original document is Edit and the temporary selector is nil. [PR #18](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/18) stays draft; [evidence](docs/evidence/p14-aircraft-panning.md) preserves failures and exact verification limits. P05 remains Planned; main is unchanged and no publication occurred.

2026-11-12 P14 acceptance completion: the horizontal control and touch-aim source `ca1d91a`, P04 fixture revision `64e6a18`, and operated evidence `8cec062` pass the 50 unit / 18 integration host gate; 86 server / 3 per-client Studio smoke; P14 6/6, P04 6/6 and HumanTestMultiplayer 4/4 with two actual clients; native desktop/mobile full orbits at both FOVs, simultaneous arrows and independent touch aiming; actual 1280×720 / 1920×1080 layout; and rendered slope/upper-floor cover comparisons. The independent tester confirmed the remaining validation gaps were closed and Studio returned to Edit. [PR #22](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/22) delivers the unmerged change on a branch stacked on PR #21; [the P14 record](plans/14-aircraft-panning.md) and [acceptance evidence](docs/evidence/p14-horizontal-acceptance.md) identify tested source and reports. P05 is Ready but has not been started; its branch must include the unmerged P14 source. No merge or Roblox publication occurred.

2026-11-12 P14 main integration: with user authorization, PRs #18–#22 merged into `main` in dependency order, ending at `169cecd6f10f82569526c57d5c1aa30c178e3ffe`. Its tree is identical to tested PR #22 head `50236e6`; a fresh integrated host gate passes 50 unit / 18 integration and all static/build/geometry/isolation checks. The [integration record](docs/evidence/p14-integration.md) records each merge and links the independently verified Studio acceptance. P14 stays Complete and P05 remains Ready but unstarted; future work can branch from integrated `main`. No Roblox publication occurred.
