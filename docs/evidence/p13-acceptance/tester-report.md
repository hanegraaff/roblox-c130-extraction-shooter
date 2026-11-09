# P13 remaining acceptance resumption — independent tester

Initial source `d570b11236dd7f71146d220a0848ffc2090b059f`, tree
`3266cde5c4e6654e1b24327acb9e908ae7ac8cb4`, dedicated branch
`fix/p13-engine-acceptance`. Existing original Studio document/instance retained:
`21f6fc11-4429-4148-9764-89a36987e5e9`, place0, Studio0.746.0.7461269,
test Rojo127.0.0.1:34872. The source includes the integrated building lift/flicker fix.

Initial preflight: all58 mapped first-party source signatures match Studio; all351
authored loaded parts match source pose/size/shape/collision flags. Maximum CFrame
component error0.000014292654839209718 against0.001 tolerance.

## Newly reproduced startup failure

`StudioTestService:ExecuteMultiplayerTestAsync(2,{kind='P13'})` starts a real server
and two clients. Server baseline67/67 passes with zero errors/failures/skips and
initial clientCount1. The P13 scenario subsequently waits for exactly two actual
players. Both client baselines fail their first Foundation case because no character
is available within10seconds. ClientTests:23 aborts before installing the P13 ready
listener. Consequently P13 firstcase times out on client ready, yielding0passed /
2failed /2discovered (initialcase plus harnesscompletion), zero skipped, actualpeak2.
No AddPlayers call, avatar traversal, reset or late-join scenario is reached.

Actual server inspection later finds assigned Gunship/Ground roles and both characters.
Bounded client logs preserve `Foundation.spec:26: character unavailable after10seconds`
and `ClientTests:23: client suite failed or empty`. Client startup also encounters
slow profile/mesh requests; a ten-second character assumption is independent of
the deferred server67-case baseline and the actual server25-second deployment load
window. This is a material test-startup synchronization defect requiring correction;
it is not a reproduced AddPlayers argument failure or passing multiplayer acceptance.

A disposable observer outside managed source recorded actual playerpopulation1→2.
It did not alter camera, roles, world geometry or authority. No P04 numeric samples
were produced because P04 has not yet been run. The observer fixtures were removed
from Edit and installer retained in ignored build for the later diagnosed rerun.

Bounded evidence: `build/p13-acceptance-resumed-report.json`,
`build/p13-acceptance-resumed-log.txt`, `build/p13-acceptance-observer-install.luau`.
Primary handed source fixes to developer and took Studio for the independent fresh
native-world interpretation check. No further tester Studio actions until handoff.

## A3 independent review

Reviewed the actual generator and persisted native-load report/build metadata under
`docs/evidence/p13-acceptance/`. Five named cases pass with `passed=true`,
`fixtureRemoved=true` and no cleanup errors. The fresh 7,141-byte native artifact
SHA-256 is `1d6e62e81677182aab4f5d2f4c57825cced46443342ef96af8d921d08ac48fb2`.
All334 world parts /357 nodes match source identities and geometry; maximum CFrame
component error0.00001429265. Initial plus two perturbed resets each produce1152
samples /9513 bytes /Adler32 2054186319, with all eight expected material/elevation
samples. Outside terrain is compared/restored, owned terrain is preserved/restored,
temporary roots are removed, and double teardown is checked. This satisfies the
literal A3 fresh source-built world/terrain load; it is not a fresh-place boot claim.

## Corrected candidate cannot yet be exercised

Developer froze `e2e4e54c5d9fb0d2195b1e2b7720b409a2d888f0`, tree
`912f4c5202d6de6e620cc8f226dc52d543de054a`, correcting staged client readiness,
preserving failed P04 numeric observations and recording P13 teardown independently.
Source review finds the bounded readiness stages preserve actual character/root/
Humanoid or explicit active-round characterless Spectator assertions. Diagnostic
changes retain the original reticle assertions. No production/world source changes.

Preflight proves all four changed mapped test scripts remain stale in Studio.
The tester's batched call mistakenly started a test after printing these mismatches;
that owned session was immediately ended via EndTest as `P13-preflight-rejected`.
No result from that stale session counts as candidate acceptance. Actual mismatch
names/byte counts/checksums are preserved in `build/p13-acceptance-stale-source.json`.

Local Rojo HTTP diagnosis initially finds connection refused. Parent restarts the
pinned matching server on127.0.0.1:34872, but the plugin has not reconnected. A user
reconnect is pending. Require a fresh all58-source match before any new Studio QA.
P13 late join/teardown, P04 numeric/full-orbit and actual two-client human-settings
checks remain open on the corrected candidate. Original Studio remains Edit;
no disposable observer instances remain. No source/docs/tests files were edited
by the independent tester.
