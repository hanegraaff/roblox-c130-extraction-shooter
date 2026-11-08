# Roadmap to MVP

The current source includes the development shell, verification tooling, circular greybox battlefield and authoritative roles/rounds with no respawns and teammate spectating. Host and local multi-client Studio evidence cover the implemented round prototype; **aircraft and combat are still planned**. Build one complete, tested capability at a time. Each plan explains the player experience, implementation boundaries and objective acceptance criteria. See [game design](game-design.md) for the complete intended game.

## Milestones and plans

| Milestone | Plan / capability | Status | Depends on | What a human can experience afterward |
| --- | --- | --- | --- | --- |
| M1 — Playable foundation | [P01: Executable foundation and tests](plans/01-foundation.md) | Complete | — | Open a development place, spawn, and see an explicit test/boot status |
| M1 | [P02: Circular greybox battlefield](plans/02-warzone-map.md) | Complete | P01 | Walk the circular warzone and both approaches to the launcher anchor |
| M1 | [P03: Roles and round lifecycle](plans/03-rounds-and-roles.md) | In progress | P02 | Join a lobby, receive a role, enter a round, spectate and return |
| M2 — Gunship | [P04: Perimeter aircraft and inward thermal view](plans/04-aircraft-and-thermal.md) | Planned | P03 | Ground sees the orbit; operator looks inward with distinct 30mm/105mm zoom profiles |
| M3 — Combat slice | [P05: 30mm and 105mm gunship combat](plans/05-gunship-combat.md) | Planned | P04 | Operator fires both named weapons, switching zoom while cover protects players |
| M3 | [P06: M-7 fire and aircraft destruction](plans/06-ground-combat.md) | Planned | P05 | M-7-equipped teammates damage the plane; destroying it wins the round |
| M4 — Changing cover | [P07: Partial destruction](plans/07-destruction.md) | Planned | P06 | Selected cover breaks consistently and changes safe routes |
| M5 — Team battle loop | [P08: One recoverable map rocket launcher](plans/08-rocket-launcher.md) | Planned | P07 | Acquire/recover one launcher and destroy an undamaged plane with three direct hits |
| M5 | [P09: Complete team win/loss and replay loop](plans/09-match-outcomes.md) | Planned | P08 | Win by plane destruction, ground elimination or timeout, then replay cleanly |
| M6 — MVP readiness | [P10: Player guidance, spectating and presentation](plans/10-player-experience.md) | Planned | P09 | Understand each role, weapons, launcher, elimination and team result without developer help |
| M6 | [P11: Balance, performance and resilience](plans/11-balance-and-performance.md) | Planned | P10 | Play repeated stable rounds with readable counterplay |
| M6 | [P12: Reconstructable release and multiplayer acceptance](plans/12-mvp-release.md) | Planned | P11 | Play the verified MVP in an explicitly authorized Roblox test/release experience |

## How plans move

`Planned` → `Ready` → `In progress` → `Complete`. Use `Blocked` only for a concrete missing decision, access or dependency, with the reason in the plan record. Dependency sequencing alone is represented by Planned. Only this table owns status; individual plans own implementation/evidence records.

Select the lowest-numbered Ready plan whose dependencies are Complete; then ensure those dependencies' source is present on the implementation branch before coding. Resolve an open dependency PR's branch when main lacks that source. Resume an In progress plan before starting another. Reassess a Blocked plan when new evidence shows its blocker may have cleared; elapsed time alone is not resolution. If no Ready plan exists, the coordinator may promote the first Planned plan whose dependencies are complete. An unresolved Blocked prerequisite cannot be skipped to claim its dependent capability.

Use the [feature-loop skill](.agents/skills/implement-next-plan/SKILL.md) for one plan. Split a plan here before implementation if it is no longer a coherent increment; preserve IDs and requirement links. Do not implement the entire roadmap in one invocation.

## Completion versus release

A Complete plan has all required automated and Studio evidence, resolved material tester findings, current documentation, and source pushed to GitHub. Its completion record identifies the tested source and PR; PR integration may still await the human's decision. Dependent work must include that source, rather than starting from stale main.

P01 establishes the full non-Studio `python3 scripts/verify.py` gate. Every later plan must preserve it and add its own acceptance suites. Studio is a distinct required gate when the plan changes engine/player behavior. A green CI badge cannot substitute for it.

Only P12 requires cloud publication and real 10-player acceptance. Prepare the candidate first, then use existing explicit authorization or request it for the actual experience/place/audience. Local feature testing and GitHub delivery can proceed before those IDs are known. No source or documentation task implicitly authorizes a Roblox release.

## First meaningful review points

- After **P04**, check the two-role experience: both views describe the same world and cover works visually.
- After **P06**, test whether attacking and counterattacking are enjoyable before adding more content.
- After **P09**, play the complete team-versus-plane loop and inspect destruction/elimination/timeout conflicts.
- After **P12**, the MVP is ready only with the recorded gates and authorized publication; “code written” is not release completion.

## Initial delivery record

2026-11-07: established design, architecture, requirements, twelve plans, repository-local feature loop, role instructions, source/test/asset boundaries and build verification. [Scaffold evidence](docs/evidence/bootstrap.md) records checks. No gameplay plan is complete.

2026-11-07 gameplay revision: changed the design to Players vs C-130, a circular battlefield/perimeter orbit, inward weapon-linked camera zoom, 30mm/105mm aircraft weapons, M-7 rifles and one recoverable launcher. P08/P09 replace their previous collection/escape scope while retaining IDs; no implementation status changes. The user confirmed rifle chip damage plus three direct rockets from full aircraft health.

2026-11-08: P01 delivered the executable shell with passing clean-install, static/unit/service/build/isolation gates, independent Studio server/client restart evidence and current documentation. [PR #3](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/3) was merged into `main` with user authorization at `b62f6132ea0998d880daab2d1a5d86b7ab6cd95d`, including the main README’s Studio play/test instructions. See the [P01 completion record](plans/01-foundation.md). P02’s prerequisite source is now on `main`; its subsequent implementation record follows. No Roblox publication occurred.

Future ideas belong in a separate post-MVP proposal: additional weapons or maps, touch/gamepad, progression, matchmaking, vehicles or richer destruction. They must not silently enter the current plans.

2026-11-08: P02 source implementation and independent host verification are delivered in [draft PR #4](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/4). The full host gate passes (14 unit / 2 integration), and clean reconstruction matches both candidate build hashes. Required Studio map/route/cover/boundary/rebuild and walking evidence is blocked: MCP lists null-name instances but reports **Place is not open** after local-file open attempts and a dialog recheck. See the [P02 record](plans/02-warzone-map.md). P02 is not Complete; P03 remains Planned. No merge or Roblox publication occurred.

2026-11-08 resumption: the user opened the exact P02 local test document, clearing the open-place blocker. Engine inspection found a material asset serialization defect: authored Position/Orientation values were absent from the loaded CFrames. P02 is resumed for correction and required engine validation; the existing host checks did not detect this defect. P03 remains Planned.

2026-11-08 correction: `8147d1c` replaces all 112 authored part poses with canonical CFrame and adds artifact geometry comparisons plus five corruption probes. Independent full host verification and GitHub Verify pass. The old candidate’s actual Studio startup failure is preserved in evidence. Corrected engine acceptance is blocked until `p02-tests-5c809beff70b.rbxlx` is accessible; automated open still yields an unnamed/unavailable instance and the user has been asked to open it manually. PR #4 stays draft; P03 remains Planned.

2026-11-08 completion: P02’s corrected source `8147d1c` passes independent host gates and two fresh Studio sessions (23 server / 2 client cases each, one actual client, no failures/skips/errors), actual walking on both approaches, physical boundary contact/recovery and clean rebuild/restart checks. Material serialization findings are resolved. Evidence and documentation are pushed in `7ac678e`; [PR #4](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/4) is ready for review and remains unmerged. The [P02 record](plans/02-warzone-map.md) links exact source/build/report facts. P03 is Ready but has not been implemented; its future branch must include the open P02 source. No Roblox publication occurred.

2026-11-08 integration: PR #4 merged into `main` with user authorization at `6c919de9990bcc1379bb7e52e67f9805e0abb683`, after its final head passed GitHub Verify. P02 remains Complete and its dependency source is integrated; P03 remains Ready and has not been implemented. The root-guide/steering follow-up in PR #5 is retargeted to `main`. No Roblox publication occurred.
