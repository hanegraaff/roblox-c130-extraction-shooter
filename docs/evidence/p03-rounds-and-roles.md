# P03 roles and round lifecycle evidence

2026-11-08. This record distinguishes deterministic host checks, real Studio
server/client checks and focused player review. The [plan](../../plans/03-rounds-and-roles.md)
owns criterion mappings and the [roadmap](../../roadmap.md) owns status.

## Source and environment

The task branch is `plan/03-rounds-and-roles`, based on integrated dependency
source `b4fa902` from `origin/main`. The initial working tree was clean and no
existing P03 PR was found. P02 is integrated through PR #4; no dependency branch
is required.

The existing local test document is `p02-tests-5c809beff70b.rbxlx`, place ID 0,
Studio instance `21f6fc11-4429-4148-9764-89a36987e5e9`. Initial MCP inspection
confirmed Edit mode, the test runner and `Workspace.World`. The existing Rojo
server serves `test.project.json` as `PlayersVsC130Tests` on
`127.0.0.1:34872`. The document filename identifies its original load, rather
than the later live-synced candidate.

The connected Studio exposes `StudioTestService.ExecuteMultiplayerTestAsync`
and `AddPlayers`. The current official API reference documents launching up to
eight client DataModels from a plugin context, server-side `EndTest`, and
client-side `LeaveTest`. The actual run used these APIs through Studio MCP;
results are recorded below.

No Roblox publication or PR merge is part of this increment.

## Independent findings and corrections

The first source candidate, `1586e4b`, passed the independent full host gate
(23 unit / 13 service integration cases). Six additional disposable policy probes
found one material failure: a finite seed of `1e308` was accepted and deployment
assigned two ground players with no operator. Seed configuration and assignment
now require an integer in `0..2147483647`, and round seed mixing remains within
that range. Named regression cases exercise both public assignment rejection
and constructor validation.

Review also found that stopped runtime accounting discarded character owners
while `LoadCharacterAsync` was still pending. This could report zero tasks and
restore automatic spawning too early. Retired owners are now retained until
drained. A global teardown lease prevents a different runtime from acquiring the
automatic-spawn policy between final load completion and policy restoration.
The actual-engine `CharacterCleanup` regression requires a real pending avatar
load, nonzero pending accounting after stop, rejection of premature acquisition,
bounded drain, restored policy and successful subsequent ownership.

Earlier policy review corrected operator reconnect suppressing forfeit,
spectator-only survivors affecting competitive outcomes, premature equipment
recovery before terminal evaluation, death during deployment, movable surrendered
bodies and stale asynchronous character callbacks. Deterministic tests cover
the pure policies; engine-dependent claims remain subject to fresh Studio runs.

The candidate submitted for final independent acceptance is `e0d285723399535677b64335dccca11f4cfd1d19`
(Git tree `b17441df12625a0ef5eaea6c58c5f00638d66a8b`). Developer verification
passes 24 unit / 14 integration cases, static checks, intentional rejection
probes, both builds, 112 authored part checks per build and release isolation.
The independent final host and Studio results also pass, as recorded below.

## Final automated evidence

- [Independent tester report](p03/tester-report.md) records criterion mappings,
  exact commands, source/build identities, resolved findings and focused review.
  Its `build/` paths identify the original local artifacts; the durable normalized
  reports and archives linked here preserve the relevant results in Git.
- [Independent full verifier log](p03/independent-verify.txt):
  `python3 scripts/verify.py > build/p03-host-independent-final.log 2>&1`,
  24 unit / 14 integration cases, zero failures/skips; all format, lint, strict
  types, intentional failing/empty/type probes, both builds, geometry corruption
  probes and release isolation pass. The released mapping has 17 allowlisted
  runtime scripts and no test override/runner/package.
- [Six independent adversarial probe results](p03/adversarial-results.json)
  all pass. The [archived disposable probe text](p03/adversarial-probes.txt) was executed with
  `lune run build/p03-adversarial-final.luau`; copy it back under `build/` to
  preserve its relative production-module requires when rerunning. The
  [initial findings](p03/initial-findings.json) preserve the original seed failure
  and pending-load accounting findings; their historical “Awaiting correction”
  labels describe that initial candidate, not the final source.
- [Studio report](p03/studio-report.json): 45/45 server baseline cases,
  2/2 on each of four actual clients, and 9/9 multiplayer scenarios with zero
  failures/skips. The baseline server finished while one client had connected;
  the separate multiplayer harness waited for three and added a fourth during
  Active. It completed actual rounds 1–3 for elimination, timeout and operator
  forfeit, plus the real pending-avatar-load regression.
- [Source signatures](p03/source-signatures.json): all 35 first-party mapped
  sources match the repository byte count and Adler32 before engine execution.
  The report records Studio 0.746.0.7461269 and the actual live-synced document.

The harness checks role/deadline replication and actual camera subjects on
clients, rejects actual production remote requests from unauthorized/stale
contexts, verifies late-join character restrictions, and intentionally removes
cover/adds transient debris before each reset. It then checks the original
map signature and restored lobby cameras. Runtime resources remain stable
between equivalent populated rounds and reach zero after teardown. The final
regression begins a real yielding avatar load before stopping, verifies pending
work and the global teardown lease remain visible, rejects a new owner, then
waits for drain/restoration and starts/stops a subsequent owner.

Generated artifact SHA256 values from the tested source:

| Artifact | SHA256 |
| --- | --- |
| `build/game.rbxlx` | `dc27f977409398b36f01f5c21e1d70685eed2e3e86c8b163d352ce4860394096` |
| `build/tests.rbxlx` | `d90c5cb523a6588d8a20e1c44294e6bc0af8d630cfdeecaa4fdf19f5787dc140` |

## Presentation and limits

The [representative image](p03/current-progress.jpg) is an actual active-ground
capture from the focused two-client Studio session on 2026-11-08, with CoreGui
chat disabled only in that test client for the capture. The logical viewport
was 1081×658 with graphics quality Automatic. The central phase, role, timer,
survivor count and surrender action were readable; open team chat overlapped
  the prototype bootstrap panel and the left edge of the round card, as shown
  in the [unmodified chat-overlap capture](p03/chat-overlap.jpg). This remains
documented P10 presentation polish. The protected operator still has an ordinary
avatar camera and a placeholder station; this is not an aircraft targeting view.

A subsequent focused two-client session observed both role views and actual
Active → Results (`GroundEliminated`) → Lobby/Waiting → Deploying → Active
transitions, including role rotation, clear result labels and restoration of
Custom camera mode with each client's own Humanoid. Its baseline again passed
45 server cases and two cases per client. Only a preexisting avatar ContentId
203785492 type warning appeared; no first-party runtime error was reported.
The original confirmed test document was returned to Edit. An unrelated nil-args
three-client session discovered during focused review was preserved untouched;
the tester operated and ended only contexts matched to `P03Focused` arguments,
the correct two-player roster and the same deadline.
The [focused observation record](p03/focused-review.json), [ground result](p03/ground-result.jpg)
and [operator result](p03/operator-result.jpg) preserve the reviewed states.

Client report identities are replaced by report slots in durable structured
evidence. No runtime player data or generated place files are committed.
These local four-client checks do not establish release capacity, combat,
aircraft visibility/thermal presentation or balance.

## GitHub delivery

[PR #6](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/6) merged into `main` with user authorization on 2026-11-08 at `031c7dc1735b3ed6f0f8a2ed49a8d042576e23cc`. Candidate `b798a029a8058fd6dfeb784bfc1a0b258c61e438` pushes the source, independent evidence, representative image and current documentation. [GitHub Verify run 42518634591](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/42518634591) passes on that candidate. Final roadmap/status/link records are documentation-only and checked separately; this record identifies original P03 engine-tested source `e0d2857`. The subsequent human-testing follow-up is recorded separately in [its evidence](lobby-preview.md), with [integrated-source verification](p03-integration.md) after both PRs merged. No Roblox publication occurred.
