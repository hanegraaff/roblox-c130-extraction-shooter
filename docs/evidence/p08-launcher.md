# P08 launcher verification

## Candidate and environment

Work began on 2026-11-13 on `plan/08-rocket-launcher`, from integrated
`origin/main` commit `c7210bed7e28938640c04b450d827cd727d6215d`.
A fresh `git fetch origin` confirmed that dependency source before branching;
the working tree was clean. No existing open P08 PR was found.

The first stable candidate is commit
`88732d4e926d3463f95900928aa13d9a9d97eee8`, tree
`64948c6878e23044eb2677bded61b6080a19f60c`. The developer handed off exclusive
Studio mutation ownership to the independent tester after source edits stopped.
Developer-run focused checks passed 55 unit and 65 integration cases, strict
analysis, Selene, StyLua, both Rojo builds, repository checks and artifact
isolation. These focused results are separate from the independent full gate
and engine execution below. The new mapped smoke baseline is expected to be
155 server cases and six per client; expected counts are not execution results.

The primary agent coordinates implementation, independent testing and prose
review through the repository's feature-developer, feature-tester and
technical-writer roles. Exact tested candidate hashes and results will be
recorded after verification. No result below is inferred from historical P07
evidence.

## Acceptance ledger

| Criterion | Required evidence | Current evidence |
| --- | --- | --- |
| A1 | Full host gate; one identity/owner/representation under raced and repeated claims | Pending candidate |
| A2 | Runtime role/life/round/shape/replay/rate/reach/movement rejection without mutation, then valid pickup; retained M-7 | Pending candidate |
| A3 | Drop/death/reset/disconnect reload continuity, valid recovery/fallback, terminal precedence | Pending candidate |
| A4 | Actual swept rockets: two nonlethal direct hits, third ground win; mixed rifle damage, cover/miss/duplicate rejection; feasible reload timing | Pending candidate |
| A5 | Three actual clients: operator and two ground players, raced pickup, death/disconnect/recovery, replicated owner/readiness/health, reconnect authority | Pending Studio candidate |
| A6 | Repeated pristine reset, one anchor launcher and no old tool/projectile/callback authority | Pending candidate |

Focused operated review must cover both approaches, pickup, M-7/launcher
selection, firing/misses/reload, drop/recovery, desktop/touch controls and clear
team feedback. A screenshot does not replace multiplayer evidence.

## Independent first-candidate checks

On candidate `88732d4`, the independent tester's full
`python3 scripts/verify.py` passes **55 unit / 65 integration** and every
static, build, corruption-probe, geometry and release-isolation gate.
The [full host log](p08/host-88732d4.txt) includes 422 authored Part transforms
in each artifact, 506 release / 593 test Instances and 43 release runtime
scripts. A fresh ordinary one-client Play passes **155 server / 6 client**
with zero failures, errors or skips; the
[normalized report](p08/solo-88732d4.json) preserves source/tree, startup,
version and actual context. Seven key mapped module/harness signatures matched
repository lengths and Adler32 values before testing.

The first three-client SDK invocation failed startup: it requested three, but
only **two actual clients** connected. The
[failed SDK report](p08/sdk-88732d4-failed.json) records one discovered failing
startup case and zero passes. The outer invocation's successful return is not
a gameplay pass. The tester ended only the owned session, confirmed the
original document returned to Edit, then prepared the documented native
three-client fallback. This failure remains historical even if a later route
passes.

The independent source review identified a desktop pickup/readiness overlap
and missing actual carrier character-reset coverage. The first-candidate GUI
test asserted layout constants without checking rectangle intersections.
Fix planning also found that CharacterOwner handled Humanoid death but did not
handle unexpected removal of its owned character, potentially leaving a
characterless carrier's life marked Alive. These findings require correction
and new evidence; the first candidate is not accepted. Before edits resumed,
the tester confirmed the original document was Edit, RunService was stopped,
no BootstrapStatus existed and the temporary P08 manual selector was cleared.
No native three-client session had started at that checkpoint.

The user subsequently launched native Server & Clients with the selector nil.
That ordinary three-client session used first-candidate `88732d4`, not the
corrected source. Its 155 server / six per-client smoke cases passed, but
focused actual-client checks reproduced both defects. The
[native defect summary](p08/initial-native-defects.json),
[raw character-removal observations](p08/initial-native-removal.json) and
[overlap capture](p08/initial-desktop-overlap.jpg) preserve exact scope and
QA-pose disclosure. The pickup occupied the same 32-pixel-high strip as the
ammo label at viewport 1081×618. Destroying an actual living ground character
left Life=Alive and GroundAlive=2 after two Heartbeats while the operator and
teammate remained. No held-launcher or full P08 harness pass is claimed from
that ordinary session. Actual-server EndTest closed its children and restored
the original Edit document with no selector or bootstrap owner.

The corrected candidate is `273611f53583d6aa1dc18f7e44bdfb20d7aea7bc`, tree
`b847044da75d31c37a5f98e0a2184e924ee62ad4`. It separates desktop pickup,
documents both ground weapons, adds owned-character-removal handling, and adds
actual GUI intersection, character-lifecycle and carrier-removal/reload
scenarios. Its expected smoke count is 156 server / seven per client, and the
P08 harness now names eleven scenarios. These expectations require fresh
execution and do not retroactively repair first-candidate evidence.

Independent `python3 scripts/verify.py` on `273611f` passes **55 unit / 65
integration** and all host gates ([log](p08/host-273611f.txt)). Its fresh solo
Studio baseline **fails**: 156 server cases, 154 passes and two failures;
seven client cases, six passes and one failure. The new CharacterOwner case
passed its own assertions but left the actual player without a character,
causing the later fragment-physics case to fail and its fixture cleanup to
leave collision groups owned. The next panel-reset case and client server-gate
check then failed. See the [failed report](p08/solo-273611f-failed.json) and
[console traces](p08/solo-273611f-console.txt). The actual GUI intersection
regression passed. Fixture isolation must be corrected; these failures are not
accepted or relabelled as a passing baseline. The exact original raw
`character:Destroy()` path also needs a regression independently of assigning
`Player.Character = nil` first. Play was stopped before further source edits.

## Corrected source verification

Current tested runtime/test source is
`75b1e882a33f73a4c4aa429cb0fb125648d75501`, tree
`055b7664a60d1f0cef49615d8009b29cabde1f2b`. Owned model Destroying now shares
the generation-scoped, once-only life-loss path with Died/CharacterRemoving;
internal teardown disconnects before destruction. The exact raw Destroy path
is exercised. The character fixture explicitly restores a living ready avatar
after its owner drains, and the fragment fixture validates avatar prerequisites
before acquiring resources and protects cleanup. The desktop HUD also reserves
the bottom inventory region; rendered native inventory review remains separate.

The independent tester's full `python3 scripts/verify.py` passes **55 unit / 65
integration** and all static/build/probe/isolation gates
([log](p08/host-75b1e88.txt)). Key changed mapped sources/specs matched repository
signatures before execution. Fresh ordinary solo Studio passes **156 server /
7 client**, zero failures, skips or errors
([report](p08/solo-75b1e88-pass.json)). This includes the exact raw Destroy,
avatar-restoration and semantic HUD rectangle regressions. The original test
document returned to Edit without a stale bootstrap owner before preparing the
native P08 selector. Three-client, operated and affected multiplayer regression
results remain separate requirements.

## Initial Studio availability

The initial MCP query returned no instances. Studio is installed at
`/Applications/RobloxStudio.app`; a subsequent process check found Studio PID
92781. The guarded command `python3 scripts/launch_studio.py build/tests.rbxlx`
exited 2 without launching another process because that instance was already
running. MCP then listed `e45b78d9-003f-45ad-b35e-00e5a5ed494a` as Unavailable,
with `Place is not open`. The user reported they were not signed in and would
sign in. No engine gate has passed at this checkpoint. The existing Rojo
listener on localhost:34872 is not proof of a plugin connection or synchronized
candidate.

P08 retains its own A5 requirements. D50's waiver of a real late-join scenario
applies only to P07 and is not a waiver for P08.

After the user signed in and opened the file, the same instance reported
`tests.rbxlx`, Edit mode, local `placeId = 0`, Studio
`0.747.0.7471481`. Read-only inspection confirmed ServerTests, ClientTests,
DevelopmentSettings and the new LauncherService/LauncherRuntime; ManualHarness
was nil and BootstrapStatus absent. The mapped modules establish that source
synchronization is working, but do not establish a passing Play session.

The installed server's `rbx-unit-test` guidance was consulted; tests conform to
the existing automatic TestEZ runners. Its `rbx-docs-search` and `rbx-permissions`
guidance were also consulted before looking up the official
[StudioTestService reference](https://create.roblox.com/docs/reference/engine/classes/StudioTestService).
The documented methods add clients or remove a client, without a same-identity
reconnect parameter/method. The testing-modes guide returned no reconnect
procedure. This bounds the available automation; it does not convert a
deterministic tombstone test into actual reconnect evidence.
