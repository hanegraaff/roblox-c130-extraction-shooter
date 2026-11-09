# P13 engine acceptance resumption

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

Remaining checks are P13 actual late join/reset/teardown, complete P04 numeric
diagnosis/full orbit and two-client human controls on the synchronized candidate.
No passing result for these revised suites is claimed in this interim record.
P14 has not started, and no merge or Roblox publication occurred.

[Independent tester report](p13-acceptance/tester-report.md),
[initial startup result](p13-acceptance/startup-report.json) and
[bounded actual startup logs](p13-acceptance/startup-log.txt) preserve the failed
run and the tester's native-load review. These are distinct from the corrected
candidate's pending engine checks.
