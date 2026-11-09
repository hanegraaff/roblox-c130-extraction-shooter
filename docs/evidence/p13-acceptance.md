# P13 engine acceptance resumption

All previously outstanding P13 checks now pass on source `e2e4e5`, with no
production gameplay/world changes. The independent tester exercised the actual
synced candidate in Studio 0.746.0.7461269 and returned the original document to
Edit. [Source manifest](p13-acceptance/source-manifest.json) records the exact
commit/tree, 58 mapped source signatures and Studio identity. This acceptance
work is delivered through [PR #16](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/16);
main remains `d570b11`, and Roblox publication has not occurred.

| Required check | Actual result and evidence |
| --- | --- |
| Fresh source-built native world / A3 | 5/5 cases; 334 world parts / 357 nodes, initial terrain and two perturbed rebuilds, unrelated terrain preservation and clean teardown. [Native report](p13-acceptance/fresh-world-report.json). |
| Expanded-map multiplayer / A4–A6 | 5/5 cases, initially two / peak three actual clients. Foundry, Warehouse and Outpost upper-floor walks, two perturbed round resets, actual third-client late spectator and idempotent teardown pass. Nine client observations each include 2/2 client baselines. [P13 report](p13-acceptance/p13-report.json). |
| Aircraft regression / A5–A6 | 6/6 cases, two actual clients, nine samples over a full 90-second orbit and two rounds. Both zoom profiles, invalid-selection coherence, thermal cover, reset and operator disconnect/cleanup pass. Maximum observed pose error 1.6772691 studs versus the declared 8-stud bound. [P04 report](p13-acceptance/p04-report.json). |
| Actual startup / baseline | 67/67 server and 2/2 per actual client, zero errors/failures/skips. P04 readiness is 1.941 / 2.101 seconds with actual Gunship/Ground bodies and roots; reticle (162.15, 98.70) remains inside 1081×658 at both 35°/60° profiles. [Live observations](p13-acceptance/p04-live.json). |
| Two-client human controls | 4/4 cases, zero errors/failures/skips, two actual clients: malformed input, conflicting role choices, requested real roles, next-round settings and reset/restart pass. [Human report](p13-acceptance/human-report.json), [client baseline logs](p13-acceptance/human-baselines.json). |
| Host gate / A1–A2 | 33 unit / 18 integration, strict/static checks, both builds, 351 transforms, 111 panel pivots and 7,146 surface-pair checks. [Full host log](p13-acceptance/host-verify.txt). [GitHub Verify 42540612044](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/42540612044) passes on documentation head `e8b245d`, with unchanged tested code. |

The historical reticle assertion failure was not reproduced in the full successful
regression. Numeric diagnostics are now retained before the unchanged assertion;
no production camera correction or unsupported root-cause claim is made. Final
MCP inspection confirms Edit mode and no `P13AcceptanceFreshWorld`, `P13Harness`,
`P04Harness`, `Aircraft` or `StudioTestControls` temporary instances. The independent
tester reports no unresolved material acceptance findings. P14 is not implemented.

## Candidate and earlier investigation

Work resumes from integrated main `d570b11236dd7f71146d220a0848ffc2090b059f`
on dedicated branch `fix/p13-engine-acceptance`, as requested by the user.
Candidate `e2e4e54c5d9fb0d2195b1e2b7720b409a2d888f0` adds test-startup
synchronization, retained failure diagnostics, independent P13 teardown checks and
a reproducible native-world probe builder. Production gameplay and world source
are unchanged in that candidate.

## Verified fresh native world load

P13 A3 now has actual engine evidence without launching another Studio process.
`scripts/build_studio_world_probe.py` builds the current Git-authored world using
pinned Rojo, embeds source expectations and emits a Luau probe under ignored
`build/`. The existing Studio Edit session executes
`SerializationService:DeserializeInstancesAsync` on the fresh binary `.rbxm` bytes.
This is native serialized-world interpretation, not a clone of the live map or a
claim that an entire new place document booted.

Actual native-world results: **5/5 named cases pass**, 334 authored world parts /
357 nodes match source identities/classes/poses/dimensions/shapes/flags, maximum
CFrame component error 0.0000142927. Production MapService reconstructs terrain,
then restores two actual panel/transient/Sand mutations. All three sampled states
match the original 1,152-voxel / 9,513-byte / Adler32 2054186319 terrain signature.
Unrelated terrain is compared exactly across both rebuilds, prior owned/unrelated
terrain is restored, double teardown passes, the fixture is removed and cleanup
reports no errors. The independent tester reviewed the procedure and actual result
and confirmed it satisfies A3's fresh source-built world-load criterion.

World source SHA-256:
`9d27fa7afbdc5c0caa18d690c6bb1f5f1ed012c3e008472686e58e4ed877e74b`.
Fresh native binary is 7,141 bytes, SHA-256
`1d6e62e81677182aab4f5d2f4c57825cced46443342ef96af8d921d08ac48fb2`.
The executed probe and committed builder emit byte-identical Luau (SHA-256
`2f2f116c2484b2ccf4c06814ecff8f40d87a2ccb8fe6c61e1fd6abdebaa0ed6d`).
[Actual native report](p13-acceptance/fresh-world-report.json),
[build metadata](p13-acceptance/fresh-world-build.json).

## Startup finding and source synchronization

A new bounded launch connected two actual clients and passed 67/67 server cases,
showing the former initial-launch blocker had cleared for that run. Both clients
then failed the old ten-second avatar expectation, before installing the P13
transport. Actual characters appeared later. The revised client suite waits for
server fixture completion, deferred RoundState publication, and a separately
bounded real-avatar/explicit-spectator readiness phase. Assertions remain required;
timeouts retain phase/role/loading/body diagnostics. P04 now preserves failed
numeric viewport/reticle observations, and P13 checks final teardown independently
of late-join success.

The candidate's full host gate passes **33 unit / 18 integration**, strict/static
checks, both builds, 351 transforms per artifact, 111 panel pivots, 7,146 surface
pair checks and release isolation. The native probe builder also compiles and
reproduces the exact tested binary/probe. [Host log](p13-acceptance/host-verify.txt).

The next Studio preflight found four stale test scripts; that run was explicitly
rejected and provides no candidate acceptance evidence. The old Rojo server was
not listening. The parent restarted the pinned test server on 127.0.0.1:34872,
but the plugin remained disconnected with its connection-error panel open.
[Exact stale-source report](p13-acceptance/stale-source.json).
The user was asked to reconnect the existing Edit document through Plugins → Rojo
to PlayersVsC130Tests on localhost:34872. Revised candidate engine checks must wait
until all 58 mapped source signatures match; elapsed time or a started Play session
does not establish synchronization.

At that interim point, P13 actual late join/reset/teardown, complete P04 numeric
diagnosis/full orbit and two-client human controls remained pending. The passing
results at the top of this record supersede that validation gap.

[Independent tester report](p13-acceptance/tester-report.md),
[initial startup result](p13-acceptance/startup-report.json) and
[bounded actual startup logs](p13-acceptance/startup-log.txt) preserve the failed
run and the tester's native-load review. These are distinct from the corrected
candidate's passing engine reports above.

## Reconnection and external launch recovery

The user reconnected Rojo. The tester then verified all 58 mapped source
signatures and all 351 authored loaded parts; maximum CFrame component error
was 0.00001429265 versus 0.001 tolerance. One bounded P13 launch started its real
server but no clients connected even after 125.111 server seconds. Both native
client processes logged four OAuth discovery timeouts followed by LoginController
metadata failure, before any game connection. The owned test was ended and the
original document restored. [Actual launch report](p13-acceptance/reconnected-launch-report.json),
[bounded cloud logs](p13-acceptance/reconnected-launch-log.txt),
[both client failures](p13-acceptance/client-launch-errors.json).

A read-only macOS `/usr/bin/curl` probe then received HTTP 200 / 1,231 bytes from
the same public discovery endpoint in 0.264 seconds. This new availability
evidence justified one bounded P04 retry. Actual client launch recovered; that
P04 run and the subsequent P13 and human runs passed as recorded above. The
network failure is retained as failed launch evidence, never counted as a passing
or skipped test. No speculative server-startup deadline or production change was
made in response to the zero-client launch.

## Delivery

Source/test candidate `e2e4e5` and evidence/documentation commit `1dc880a` are
pushed on `fix/p13-engine-acceptance` in
[draft PR #16](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/16).
The PR targets unchanged main `d570b11`. The earlier documentation checker passed
61 Markdown / 47 JSON files, and `git diff --check` passed. Final evidence and
documentation pass `python3 scripts/check_repository.py` (61 Markdown / 56 JSON)
and `git diff --check`. The technical writer reviewed the whole experience/setup
narrative, updated three documents and retained the still-current representative
Studio screenshot. Integration is separate from acceptance; no merge or Roblox
publication is part of this branch's delivery.
