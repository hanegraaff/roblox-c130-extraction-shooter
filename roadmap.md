# Roadmap to MVP

The initial design and repository scaffold are prepared; **gameplay has not started**. Build one complete, tested capability at a time. Each plan explains the player experience, implementation boundaries and objective acceptance criteria. See [game design](game-design.md) for the complete intended game.

## Milestones and plans

| Milestone | Plan / capability | Status | Depends on | What a human can experience afterward |
| --- | --- | --- | --- | --- |
| M1 — Playable foundation | [P01: Executable foundation and tests](plans/01-foundation.md) | Ready | — | Open a development place, spawn, and see an explicit test/boot status |
| M1 | [P02: Industrial greybox battlefield](plans/02-warzone-map.md) | Planned | P01 | Walk protected and exposed routes through the test district |
| M1 | [P03: Roles and round lifecycle](plans/03-rounds-and-roles.md) | Planned | P02 | Join a lobby, receive a role, enter a round, spectate and return |
| M2 — Gunship | [P04: Orbiting aircraft and thermal view](plans/04-aircraft-and-thermal.md) | Planned | P03 | Ground sees the moving aircraft; operator surveys the same battlefield |
| M3 — Combat slice | [P05: Cannon and authoritative damage](plans/05-gunship-combat.md) | Planned | P04 | Operator can engage exposed players; solid cover protects them |
| M3 | [P06: Ground weapons and aircraft disablement](plans/06-ground-combat.md) | Planned | P05 | Ground players coordinate rifle/anti-air fire against the aircraft |
| M4 — Changing cover | [P07: Partial destruction](plans/07-destruction.md) | Planned | P06 | Selected cover breaks consistently and changes safe routes |
| M5 — Extraction loop | [P08: Shared mission objectives](plans/08-objectives.md) | Planned | P07 | Recover three items and see team progress persist through losses |
| M5 | [P09: Extraction and complete outcomes](plans/09-extraction.md) | Planned | P08 | Win by extracting or preventing escape; replay a clean next round |
| M6 — MVP readiness | [P10: Player guidance, spectating and presentation](plans/10-player-experience.md) | Planned | P09 | Understand each role, danger, objective, elimination and result without developer help |
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
- After **P09**, play the complete survival-to-extraction loop and inspect win/loss edge cases.
- After **P12**, the MVP is ready only with the recorded gates and authorized publication; “code written” is not release completion.

## Initial delivery record

2026-11-07: established design, architecture, requirements, twelve plans, repository-local feature loop, role instructions, source/test/asset boundaries and build verification. [Scaffold evidence](docs/evidence/bootstrap.md) records checks. No gameplay plan is complete.

Future ideas belong in a separate post-MVP proposal: second cannon type, additional maps, touch/gamepad, progression, matchmaking, vehicles or richer destruction. They must not silently enter the current plans.
