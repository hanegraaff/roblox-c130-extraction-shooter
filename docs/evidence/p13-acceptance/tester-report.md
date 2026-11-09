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

## Current post-reconnection attempt

After the user reconnected the Rojo plugin, preflight on branch
`fix/p13-engine-acceptance` at `e8b245dc4a3b73cd1e72215b77a89ae2bde7a628`
(documentation follow-up to tested code `e2e4e54c5d9fb0d2195b1e2b7720b409a2d888f0`)
passes: all58 mapped scripts match exact source fingerprints and all351 loaded
parts match source geometry/flags. Actual DataModel name is `PlayersVsC130Tests`;
the original document's historical MCP filename remains unchanged. Geometry maximum
CFrame component error remains0.00001429265. The earlier stale-source issue is resolved.

Only after this successful preflight, the tester launches
`ExecuteMultiplayerTestAsync(2,{kind='P13'})`. The server process starts, but no real
clients connect. Console reports cloud beta-feature and installed-plugin request
timeouts, followed by `ServerTests:16: server smoke requires a real client within
10 seconds`. The server test script aborts before creating ServerTestReport, TestEZ
discovery or the gameplay runtime. Later actual server inspection still finds zero
players at server os.clock94.315809875; explicit EndTest at125.110706292 likewise
reports zero clients. No late arrival was observed, so this does not establish that
the ten-second guard is the cause of the current failure.

The actual returned report is API success with inner acceptance failure:

```json
{"success":true,"result":{"serverClockSeconds":125.1107062916708,"environment":"Studio","actualClientCount":0,"suite":"P13-launch-failure","passed":false,"detail":"No real clients connected after more than90seconds; server suite aborted at10second startup guard; Studio cloud feature/plugin requests timed out. No gameplay acceptance executed."}}
```

No required gameplay suite was discovered/executed in this attempt. P13 full
late-join/teardown, P04 numeric/full90-second orbit and HumanTestMultiplayer4cases
remain unverified on the corrected candidate. No further client/server launches
were attempted against the same unresolved external launch failure. No deadline
or authority assertion was weakened.

Bounded actual source proof, report and console are preserved in
`build/p13-acceptance-reconnected-launch-report.json`; relevant exact log lines are
in `build/p13-acceptance-reconnected-launch-log.txt`. Per-process timestamps are
retained verbatim; cross-process wall timestamps should not be used to infer join
latency. Final MCP inventory contains only the original Studio document in Edit.
The owned failed session was ended through its real server's EndTest; no CLI app
launch, unrelated process termination, managed-source Studio edit or temporary
fixture remains. Studio ownership is handed back to the primary agent.

Developer read-only log diagnosis was independently checked: both owned client
processes record StartClient, then four failed OAuth discovery/metadata attempts and
LoginController metadata timeout at process age about13.4seconds, with no
NetworkClient/RakNet game-connection marker afterward. Exact bounded error lines
and source line numbers are saved in
`build/p13-acceptance-client-launch-errors.json` for client logs
`20261109T005348Z_Studio_072e4` and `20261109T005349Z_Studio_fff76`.
This establishes a current external authentication-metadata/client-launch blocker,
rather than a demonstrated gameplay or startup-budget failure.

## Verification after the metadata endpoint recovered

Primary independently observed HTTP200 from the public OAuth discovery endpoint,
a concrete changed external condition. Tester rechecked all58 actual mapped source
fingerprints (zero mismatches), then made one additional P04 launch. It connected
two actual clients successfully. Client readiness on corrected staged startup is
1.940702 /2.101067seconds; both have actual Active Gunship/Ground characters and
roots, no outstanding load lease, fresh2/2 passing client baselines. Server baseline
67/67 passes with actual initial clientCount2. Live operator pixels(162.15,98.70)
are within the1081×658 viewport bounds. These values are preserved in
`build/p13-acceptance-p04-live.json`.

P04 now passes **6/6**, zero failed/skipped, two actual clients, two rounds and the
full production90-second orbit sampled at nine phases on both clients. It verifies
both acknowledged weapon/FOV profiles; stale/malformed/wrong-role/replayed/unknown
selection rejection; exposed/covered thermal fixtures; actual camera/aircraft
convergence; result/reset camera/input/effect restoration; actual operator departure
and aircraft ownership teardown. All39 observations are retained. Largest actual
pose error is1.677269101studs against the declared8-stud bound across21 pose probes
(including18 full-orbit probes). The previous reticle failure is not reproduced
on this current source/session; no reticle assertion or numeric tolerance was weakened.
Actual report: `build/p13-acceptance-p04-report.json`.

After another all58-source match, P13 passes **5/5**, zero failed/skipped, with two
initial real clients and an actual third late client (peak3). All three building
upper floors are traversed by the actual ground Humanoid; two perturbed round resets
restore geometry/terrain/IDs; all clients including the real late join observe the
rebuilt world; the late player remains a characterless Spectator; repeated runtime
teardown removes round/aircraft ownership. All9 received real-client observations
include2/2 passing client baselines. The server baseline is67/67 with zero errors/
failures/skips. Actual report: `build/p13-acceptance-p13-report.json`.

The same API AddPlayers(1) now succeeds without an API/argument change, resolving
the prior late-client capability gap under the recovered external condition.
HumanTestMultiplayer then passes **4/4**, zero errors/failed/skipped, two actual
clients, after a fresh all58-source match. Both actual client logs contain2/2
passing foundational client cases; the actual server log records the4/4 human
suite. The returned suite label remains `HumanTestControls`, while its invocation
is explicitly `ExecuteMultiplayerTestAsync(2,{kind='HumanTestMultiplayer'})`.
Reports: `build/p13-acceptance-human-report.json` and the bounded actual-run
three-log `build/p13-acceptance-human-baselines.json`.

## Final independent disposition

All previously open required P13 engine checks are now verified: native fresh world
interpretation/rebuild/cleanup5/5, actual two-to-three-client P13 scenarios5/5,
full90-second two-client aircraft regression6/6, and actual two-client settings4/4.
The actual current server baselines pass67/67, and all received required client
baselines pass2/2. No required case is skipped. No material tester finding remains.
Historical failed launches and the preflight-rejected stale-source attempt remain
recorded as development evidence; none is counted as a pass or silently replaced.

The tested runtime/world are unchanged; only the staged-readiness and diagnostic/
cleanup harness corrections separate tested codee2e4e54 from main. All58 source
fingerprints were checked before each successful launch. Geometry preflight checks
all351 parts; A3 separately interprets all334 fresh-native-world parts /357 nodes.
Host/CI verification on unchanged relevant content is primary/developer-owned and
is not rerun redundantly by this tester.

Final MCP inventory and state were checked after the self-ending human session:
only original instance21f6fc11-4429-4148-9764-89a36987e5e9 remains, in Edit mode.
No owned test process/session, temporary observer or fresh-world/terrain fixture
remains. Parent now owns Studio. No further Studio mutations or launches occur.
No source, tests, tracked evidence, docs, roadmap or Git state was edited by the
tester. Consolidated structured facts: `build/p13-acceptance-final-summary.json`.

This verifies the current P13 local capability and its regressions, not a fresh
full-place boot or release capacity. Panning, combat, panel destruction and actual
6/10-player release acceptance remain their separately scoped roadmap work.
