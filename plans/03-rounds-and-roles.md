# P03 — Roles and round lifecycle

**Milestone:** M1. **Dependencies:** P02. **Requirements:** R02, R03, R04, R13, R15. Status: [roadmap](../roadmap.md).

## Capability and player experience

Players wait in a lobby, receive an operator or ground role, deploy and return after a timed round. An eliminated player spectates instead of respawning. This establishes the match contract before weapons are added.

## Implementation

Implement pure phase/roster rules and MatchService/RoleService adapters. Enforce 6–10 production players and test-only minimum of two players (also supporting three-client launcher tests). Add fair rotation, deployment readiness/cancellation, monotonic deadlines, basic timeout/elimination/abort outcomes, explicit character spawning and minimal phase/role/timer UI. Provide result proposals for aircraft destruction and operator forfeit as well as ground elimination/timeout; later combat plans connect actual damage. Store round membership by UserId so reconnects cannot restore life. Tag all queued work and updates with round IDs/revisions. Add basic teammate spectating and cleanup now; P10 improves presentation.

## Acceptance criteria

- **A1:** Full gate passes. Boundary tests at 5/6/10/11 players reject invalid rosters and assign exactly one operator and place every other player on one ground team for valid rosters; tie-break/rotation is deterministic with a seed.
- **A2:** Transition tests reject illegal phase changes and commit one result only. Fake-time tests reach the deadline exactly; cancelled deployment returns to lobby without partial active players.
- **A3:** Death/manual reset does not create a fresh active character. Rejoin/late join cannot gain an active role or new gear in the same round; departure cleanup can release a held weapon without duplicating ownership.
- **A4:** Wrong-role, stale-round, replayed and spectator commands reject without state change. Test-only population override is absent from the release build.
- **A5:** Two real Studio client contexts receive their correct roles, phase and deadline. Operator remains protected; an eliminated ground player spectates and cannot interact.
- **A6:** Three accelerated rounds restore roster, camera, map, connections and phase state. Tests cover operator/ground departures during deployment and Active, using the design's distinct policies.

## Focused human check

Observe waiting, deployment, timer, elimination, result and return states on both clients. At this stage the operator has a placeholder view and combat is unavailable; make that explicit.

## Documentation changes

Describe role assignment, no-respawn behavior, reconnect rules and actual development controls. Add lifecycle/API contracts and evidence to the service docs.

## Completion record

### Implemented capability and source

2026-11-08: implemented deterministic server-only `RoleService`, `RoundRules` and `MatchService`; engine `GameRuntime`, `MatchRuntime` and `CharacterOwner`; and client `RoundPanel`. Normal matches require 6–10 players, assign one protected placeholder operator and one ground team, enforce explicit no-respawn lives, and resolve timeout/elimination/forfeit before resetting. Reconnect tombstones prevent restored lives; late arrivals spectate. The ground surrender button sends bounded, rate-limited server intent. Actual aircraft, combat and launcher ownership remain future plans; P03 provides server result/cleanup seams without claiming those features.

Tested source: `e0d285723399535677b64335dccca11f4cfd1d19`, Git tree `b17441df12625a0ef5eaea6c58c5f00638d66a8b`. Subsequent documentation/evidence edits do not alter tested runtime or test source. The branch is `plan/03-rounds-and-roles`, based on `b4fa902`, which contains integrated P01/P02 dependencies. See [durable evidence](../docs/evidence/p03-rounds-and-roles.md), [structured Studio results](../docs/evidence/p03/studio-report.json), [independent host log](../docs/evidence/p03/independent-verify.txt) and [source signatures](../docs/evidence/p03/source-signatures.json).

### Acceptance mapping

| Criterion | Named automated evidence and actual result |
| --- | --- |
| A1 | `python3 scripts/verify.py` passes 24 unit / 14 integration cases plus all static, rejection, build, geometry and isolation gates. `RoleService.spec` checks 5/11 rejection, 6/10 exactly-one-operator assignment, seeded join-order independence, longest-waiting alternative and 2/3-player fixtures. Safe-integer seed regressions reject overflow configuration. |
| A2 | `RoundRules.spec` exhausts phase pairs and tests exact-deadline and mutual-elimination ordering. `MatchService.spec` checks readiness, cancellation, single terminal commit and injected exact-time expiry. All pass in Lune and through actual Instance requires in Studio. |
| A3 | `MatchService.spec` checks once-only deferred life release, rejoin tombstones, immediate operator reconnect/forfeit and deployment departures. Actual multiplayer cases verify death without respawn, teammate camera spectating, and a newly added fourth client remaining a characterless spectator unable to surrender. Cleanup is a seam for P08; there is no held launcher to recover in P03. |
| A4 | `MatchService.spec` rejects malformed, nonfinite, oversized-action, wrong-role, stale-round, spectator and replay commands without revision mutation. Six additional independent adversarial probes pass. Actual clients send wrong-role/stale/eliminated/spectator requests through the production remote without changing match revision. Generated release inspection excludes test settings, runners and packages; production minimum is six. |
| A5 | Actual Studio multi-client run: initial three clients receive correct roles, phase/deadline and HUD; a fourth joins during Active. All four client baseline suites pass 2/2. The operator is anchored/protected; an eliminated ground client follows a living teammate and rejected requests cannot interact. |
| A6 | Three actual accelerated rounds (IDs 1, 2, 3) exercise elimination, timeout and operator forfeit, with ground departure, operator reset, camera/roster restoration, stable connection counts and exact map signatures after intentionally removed cover/added transient debris each round. The ninth engine case stops during real `LoadCharacterAsync`, verifies truthful pending accounting/global ownership, rejects premature acquisition, drains and reacquires cleanly. Both deployment departure roles, last-ground/both-participant departure and empty/spectator policies also pass deterministic integration tests. |

### Environments and counts

Independent tester ran `python3 scripts/verify.py > build/p03-host-independent-final.log 2>&1` on macOS arm64 with pinned tools: 24/24 unit and 14/14 integration, zero failures/skips. Both builds pass; geometry inspection checks 112 authored parts in each; the release artifact contains only its 17 allowlisted runtime scripts. Six disposable adversarial probes pass against the actual service modules. The initial large-seed failure and asynchronous cleanup findings were corrected and rechecked; no material automated finding remains open.

Studio 0.746.0.7461269 used the existing local test document `p02-tests-5c809beff70b.rbxlx`, place ID 0, with Rojo `PlayersVsC130Tests` on port 34872. All 35 mapped first-party sources matched repository byte counts/Adler32 before fresh execution. The server baseline passes 45/45 with zero errors/skips; it completed while one client had connected. Each of the four actual clients passes its 2/2 baseline cases. The separate `StudioTestService:ExecuteMultiplayerTestAsync(3, {kind = "P03"})` scenario records initial three / peak four clients, rounds 1–3 and 9/9 passing multiplayer cases, zero failures/skips. These distinct counts must not be conflated.

Release build SHA256: `dc27f977409398b36f01f5c21e1d70685eed2e3e86c8b163d352ce4860394096`. Test build SHA256: `d90c5cb523a6588d8a20e1c44294e6bc0af8d630cfdeecaa4fdf19f5787dc140`. These identify generated artifacts from tested source; Studio acceptance used verified live synchronization rather than assuming the document's original filename identifies its current content.

### Documentation and scope

Focused two-client review additionally observed both role views and Active → Results (`GroundEliminated`) → Lobby/Waiting → Deploying → Active, with role rotation, understandable result labels and each client's Custom camera restored to its own Humanoid. Its baseline again passed 45 server / 2 per client. [Focused observations](../docs/evidence/p03/focused-review.json), [ground result](../docs/evidence/p03/ground-result.jpg) and [operator result](../docs/evidence/p03/operator-result.jpg) supplement the automated reports. Chat was hidden only in the capture clients; the original test document returned to Edit, and unrelated live test contexts were preserved.

Independent technical writer updated the whole player README/local setup guide, architecture/current requirements, development/testing/decision records and package/test READMEs. The root representative screenshot is an actual P03 active-ground multiplayer capture from 2026-11-08. Aircraft, thermal targeting, weapons, damage and launcher behavior stay explicitly planned. Open team chat can overlap the prototype HUD at the tested viewport; this is documented presentation polish for P10. Local tests do not establish 6/10-player release capacity, balance or combat readiness. No Roblox publication or PR merge occurred.


### GitHub delivery and integration

Source, documentation and durable evidence are pushed to `origin/plan/03-rounds-and-roles` in candidate `b798a029a8058fd6dfeb784bfc1a0b258c61e438`. [PR #6](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/6) is open, ready for review and unmerged, targeting `main`. [GitHub Verify run 42518634591](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/42518634591) passes setup and the full host gate on that pushed documentation/evidence candidate. The final status/link records also pass `python3 scripts/check_repository.py` and `git diff --check`; they do not alter tested source. Roadmap integration remains separate from acceptance; P04 is eligible but unimplemented and must include P03 source if begun before merge.
