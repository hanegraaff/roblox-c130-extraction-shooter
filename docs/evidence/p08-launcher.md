# P08 launcher verification

[Draft PR #32](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/32)
contains the implementation, prose and source-bound evidence. Verified delivery
`370aff49b986ac3b1a70f52b643afc6a81c71277` has a passing
[GitHub Verify run](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/43519154819).
Acceptance remains open; CI does not replace actual multiplayer or operated
checks.

Verified production runtime is `ef7826b`: full host **55 unit / 65
integration** and fresh solo Studio **156 server / 7 client** pass. The
subsequent test-only harness revision `07e77ea` passes the full host gate and
the fresh native P08 suite **11/11** with three actual initial clients. The unchanged
server/input core's source-bound two-client regressions on `75b1e88` pass P06
**10/10**, P05 **8/8** and P14 **6/6**. Final phone layout/native-control review
passes. Actual same-identity reconnect is the sole remaining required
validation gap; its explicit `requiredUnverified` entry prevents full P08
acceptance.

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
| A1 | Full host gate; one identity/owner/representation under raced and repeated claims | Pass: deterministic/engine checks and actual three-client P08 single-identity/loadout/race cases |
| A2 | Runtime role/life/round/shape/replay/rate/reach/movement rejection without mutation, then valid pickup; retained M-7 | Pass: host rejection/retry and actual P08 malformed/wrong-role/stale/flood/impossible-travel and later valid pickup |
| A3 | Drop/death/reset/disconnect reload continuity, valid recovery/fallback, terminal precedence | Pass: deterministic/engine rules, actual drop/switch/transfer/death/raw-reset/Kick/recovery and in-flight post-death hit |
| A4 | Actual swept rockets: two nonlethal direct hits, third ground win; mixed rifle damage, cover/miss/duplicate rejection; feasible reload timing | Pass: engine obstruction/deduplication plus actual P08 pristine 300→200→100→0 and mixed 300→195→95→0/Results |
| A5 | Three actual clients: operator and two ground players, raced pickup, death/disconnect/recovery, replicated owner/readiness/health, reconnect authority | Three-client behavior/replication passes; actual same-identity reconnect remains required and unverified |
| A6 | Repeated pristine reset, one anchor launcher and no old tool/projectile/callback authority | Pass: actual P08 reset/old-intent and teardown plus deterministic/engine cancellation and current regressions |

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

Fresh SDK two-client P06 regression on the unchanged runtime/test source passes
**10/10**, including both mutual-kill event orders, actual operator LeaveTest,
forfeit/reset and teardown ([report](p08/p06-regression-75b1e88.json)).
The separate fresh SDK two-client P05 regression passes **8/8** with a
156-server baseline and seven per actual client
([report](p08/p05-regression-75b1e88.json)).
Fresh SDK two-client P14 regression also passes **6/6**, including a full
90-second orbit at each weapon FOV, role loss/new-round entry and drained
teardown. Server baseline is 156/156 and both actual clients pass 7/7.
The [bounded summary](p08/p14-regression-75b1e88-summary.json) and
[full returned report](p08/p14-regression-75b1e88-raw.json) retain the original
cases, populations and source; the passing report contains 49 observations.

A single changed-condition P08 launch used the documented staged SDK route:
`ExecuteMultiplayerTestAsync(2, {kind = "P08"})`, then actual-server
`StudioTestService:AddPlayers(1)` once exactly two clients were present. The
addition returned normally but never connected the third player within the
harness's bounded wait. The [staged failed report](p08/staged-sdk-75b1e88-failed.json)
records the initial request/addition and actual population: total requested
three, peak two, zero passes and one failed startup case. This does not prove
P08 gameplay. All owned children ended and the original document returned to
Edit with no selector. No repeated three-client SDK launch was attempted under
the same conditions. Native three-client acceptance remains open.

## Ordinary three-client operated review

The user's next native session started ordinary HumanTestSession on `75b1e88`
with three actual players and no manual selector. It passed 156 server / seven
per-client smoke cases. The
[operated observations](p08/operated-75b1e88-partial.json) preserve actual role,
input, route and GUI data. Native D moved a ground player 9.60 studs in 600 ms;
both ground Humanoids then walked every authored east/west approach waypoint
through controlled MoveTo, with no teleport or trusted-correction override.
Parallel native E attempts produced one owner and one launcher Tool while
both retained M-7. Native 1/2 selected the two real Tools. Actual enabled native
desktop inventory slots remained clear of the readouts. The
[earlier capture](p08/held-75b1e88.jpg) uses natural walking endpoints
and the normal camera; its test panel is visible. The capture tool omits
CoreGui inventory, which was measured separately.

Actual simulated-phone M-7/ROCKET/DROP/PICK UP/FIRE touches worked after the
MCP safe-area input offset was calibrated to (+62,+20). Native fire, drop and
re-pick preserved the exact reload deadline, and early fire created no extra
shot. The observed shot hit ground and left aircraft health at 300; this does
not prove three player-fired aircraft hits. Actual carrier death during reload
followed by teammate pickup retained one weapon identity/readiness, with all
three clients agreeing and the dead player Eliminated/characterless.
The separate [recovery report](p08/operated-recovery-75b1e88.json) adds exact raw
Model:Destroy during reload and actual carrier Kick/recovery in fresh normal
rounds. Raw destruction consumes the ground life; actual disconnect leaves
two players, one ground life and an Active round. Each recovery preserves the
same identity and exact deadline. These are current core behavior observations,
not a report that the full eleven-case P08 harness ran.

The phone review also found a material layout failure. At 750×381, visible
native slots occupied (313,316,60,60) and (378,316,60,60), while ammo occupied
(245,325,260,36); team status also overlapped the slots by one pixel. The
[phone capture](p08/phone-overlap-75b1e88.jpg) omits CoreGui and is not by itself
overlap proof; exact bounds are in the operated JSON. That earlier layout is
not accepted. The phone-only correction is source
`0cd65458b4afcdcf8e8b111c3b0adaed19c7652c`, tree
`40748edb77e71d26e6e060bf2f941e532b88103c`: compact touch status rows above
the reticle, with native inventory, reticle and active-round HUD exclusion
regions in the GUI test. Server rules and input-send paths are unchanged from
`75b1e88`; desktop geometry/image is unchanged. Primary's full
`python3 scripts/verify.py` passes 55 unit / 65 integration and all gates
([log](p08/host-0cd6545.txt)). Independent fresh ordinary solo on `0cd6545`
passes **156 server / 7 client**, zero failures/skips/errors
([report](p08/solo-0cd6545-pass.json)). Actual-phone recheck remains required.
The old operated session ended through actual-server EndTest with
all owned fixture connections cancelled; the original document was Edit with
no selector/bootstrap owner and the simulator was restored to default.

The actual `0cd6545` phone recheck **failed** despite the passing cloned-HUD
test. The [inset diagnostic](p08/phone-inset-0cd6545-failed.json) and
[actual capture](p08/phone-inset-0cd6545-failed.jpg) show different ScreenGui
origins: GroundHUD uses IgnoreGuiInset/DeviceSafeInsets with origin (0,−58),
while RoundHUD uses normal CoreUISafeInsets. With GuiInset=(0,58), the new team
row actually occupied y36–60 and overlapped the round summary y8–46; weapon
readiness occupied y62–86 and overlapped aircraft health y55–89. Native slots
were clear, but the header collision is material. A same-origin clone/reserved
rectangle test did not prove cross-ScreenGui behavior. Merely shifting rows
down would also collide with the actual centered reticle, so this needs a
cross-layer layout correction and actual nonzero-inset regression. The normal
SDK invocation with nil args was rejected before any child launched; the
supported `(2, {})` call started the ordinary review session. The failed
session was ended, all owned fixture connections removed, simulator restored,
and the original document returned to Edit with no manual selector/bootstrap.

## Inset-aware phone correction

Source `ef7826bc80310c17be4bcde93fe7607620303289`, tree
`db1f4e50296a2620d13e36839525c7562220a629`, changes only client HUD layout,
feedback presentation, inactive HUD wording and its GUI test. Active-ground
touch uses a compact shared header: summary y8–30, a 32-pixel-high Surrender
target y8–40, health/readiness y44–66 and left ownership y70–92 in common
GUI-content coordinates. Readouts convert through the measured ScreenGui
origin, and controls remain clear of native inventory/movement UI. Touch
confirmed hits append HIT to weapon readiness rather than floating over the
selectors; rifle shot acknowledgement retains its flash. Desktop/operator
layouts and reticle/ray calculation remain unchanged. D58 records these as
tuning defaults, not user-selected geometry.

The updated production RoundPanel/Ground controller fixture uses distinct
ScreenGuis and measured origins, includes confirmed rifle/rocket presentation,
and restores its owned HUD/role/tool/camera/CoreGui changes. Primary's full
`python3 scripts/verify.py` passes **55 unit / 65 integration** and all gates
([log](p08/host-ef7826b.txt)). Fresh independent solo Studio passes **156 server /
7 client**, zero failures/skips/errors
([report](p08/solo-ef7826b-pass.json)). The ordinary two-client review also has
fresh 156-server / seven-per-client baselines. Actual 750×381 and 568×320
phone views at a measured 58-pixel inset pass the independent actual-GUI probe:
zero HUD/native/header/reticle intersections, zero out-of-CoreSafe rectangles,
fitting status text and zero-pixel drawn-reticle error. An actual 567×299 view
also passes. None of the earlier phone failures becomes a pass retroactively.

The [final phone review](p08/final-phone-review-ef7826b.json) records native
M-7/ROCKET/DROP/PICK UP/FIRE/RELOAD touches at actual 568×320, preserved rocket
reload across fire/drop/re-pick, rejected early fire, and rifle reload from
25 to 30 rounds with reserve 120→115. HIT readability used an explicitly
client-only GroundShot presentation fixture: inline text measured 160×14
inside the 240×22 readout, the floating touch label stayed hidden, server
aircraft health stayed 300 and actual last shot was not an aircraft hit.
Two bounded QA-camera real rifle aiming attempts missed; they remain misses,
not damage proof. Input conversion used measured `GetInsetArea` coordinates.
The [750×381 capture](p08/phone-750-ef7826b.jpg) and
[stricter 567×299 capture](p08/phone-567x299-ef7826b.jpg) show actual final UI;
CoreGui inventory proof comes from the separately recorded bounds.

The current [representative desktop capture](p08/current-held.jpg) is from the
final source's ordinary two-client SDK session, normal camera/natural walking
endpoint. Only the test panel was hidden for review and then restored; the
capture tool omits native inventory. The initial three-client image remains
historical. All material implementation/GUI findings have been fixed and
rechecked; the writer's API/narrative review agrees with the source, including
the difference between touch inline HIT and rifle reticle flash.

After final review, the tester restored the default simulator, removed the
owned custom device and all fixtures/connections, restored the test panel and
ended the owned SDK session. The only instance was the original `tests.rbxlx`
Edit document, not running, with no bootstrap owner. Its synced source
signatures matched `ef7826b`. The tester then armed `ManualHarness = "P08"`
for the user's stable native three-client handoff. No subsequent Studio
mutation or competing launch is authorized by elapsed waiting time; the
selector stays fixed until that handoff is exercised.

## First complete native P08 invocation

The user exercised the stable three-client handoff on `ef7826b`. The actual
server had nil SDK arguments and ManualHarness=P08; initial/peak/current
population was three, matching the requested count. Server smoke passed
156/156 and all three actual clients (−1,−2,−3) passed 7/7. The
[full failed invocation](p08/native-ef7826b-failed.json) and
[console](p08/native-ef7826b-console.txt) preserve fingerprints and reports.

The P08 gameplay suite did **not** pass: seven cases were discovered before
early exit, five passed and two failed. Initial single-launcher/loadout,
rejection/flood/movement checks, raced real-client pickup and miss/drop/transfer/
selection/early-reload cases pass. The next case timed out waiting for aircraft
health 200 after the carrier fired and died; a harness-completion failure
records that same interruption, and final teardown passes. Raw reset,
three-player-fired-rocket, mixed-fire and disconnect cases were not reached.

Investigation found a harness sequencing defect: `lead(carrier)` is evaluated
before the fire helper waits for reload readiness, although the prior transfer
case deliberately leaves reload in progress. Thus the target can be seconds
old at dispatch. Other direct-rocket loops use the same pattern. The stopped
runtime had already removed shot/impact state before inspection, so this run
cannot establish flight cancellation; it establishes the failed health
assertion. The correction must calculate moving aim after readiness and retain
bounded dispatch/impact diagnostics, without changing the required health or
bypassing real fire/collision. The tester ended the owned native session and
verified original Edit, nil selector, no bootstrap owner and no running
simulation before repository edits resumed. This failed result remains
historical even if the corrected harness later passes.

## Harness timing correction

Test-only source `07e77ea5b57fba359ab611ea39e2c42c7b977881`, tree
`032f7b162bcc8bba6e48c002b2ca0da30939b444`, changes only the server P08
harness. All three direct-rocket call sites supply lazy moving-target
providers; the helper waits for client rendezvous and identity reload
readiness before preparing and dispatching aim. Deliberate upward misses
remain explicit vectors. Original health-200, three-direct-hit and mixed-fire
assertions are unchanged. Stronger pre-death checks require a fresh shot,
health 300, no matching impact and an actual live flight. After death the
teammate/round must stay active, and a flight must still exist until its impact
if health has not yet changed.

The report retains up to 192 newest JSON-safe `traces` with
`droppedTraceRecords`: preparation/dispatch/acceptance-derived time and aim age,
target/head/aircraft/rocket positions, IDs, readiness, impact, phase/life/health
and resource counts. Quarter-second live-flight samples and explicit
before/after-death/before-cleanup records survive teardown; the observer is
disconnected before cleanup. These diagnostics do not award damage or bypass
production collision.

Primary's full `python3 scripts/verify.py` passes 55 unit / 65 integration and
every host gate ([log](p08/host-07e77ea.txt)). The independent tester reviewed
the sequencing/unchanged assertions and verified synced harness source
(35,814 bytes, Adler32 3441968132); production Ground/Round module signatures
remain the previously accepted `ef7826b` values. The original local document
was Edit/not running, with no bootstrap owner, before the tester armed P08 for
the next stable native handoff. This is preparation, not a passing native
result. Source/UI, full-orbit and phone checks need no unrelated rerun for this
harness-only correction; the new native session will run fresh 156/7 baselines.

## Corrected native P08 acceptance result

The user started a fresh native Server & Clients session with three actual
players after the corrected harness was synced and armed. Production/UI source
remains `ef7826b`; harness source is `07e77ea`; observed delivery head was
`c3b155d`. Studio 0.747.0.7471481 ran local `tests.rbxlx` (placeId 0) through
the manual-server-clients route with nil SDK arguments and ManualHarness=P08.
The [source-bound result/baseline summary](p08/native-07e77ea-pass.json),
[full 115,010-byte returned report](p08/native-07e77ea-full.json),
[selected trace/cleanup audit](p08/native-07e77ea-audit.json) and
[server console](p08/native-07e77ea-console.txt) preserve the run. The summary
hashes the full report. The [independent final review](p08/independent-final-07e77ea.md)
maps every criterion and remaining gap.

All **11/11** P08 cases pass, zero failures/skips. Requested, initial and peak
population is **three actual clients**: one operator and two ground players.
Current/final population is two after the intentional carrier Kick. Fresh
server smoke passes **156/156**; all three clients (−1,−2,−3) explicitly pass
**7/7** with zero errors/skips, captured before departure. All 150 trace records
are retained under the 192-record cap, with zero dropped records.

The suite verifies initial single-weapon/loadout state; malformed/wrong-role/
stale/flood/impossible-travel rejection; raced acquisition; miss/drop/transfer/
switch/early-fire reload continuity; post-death in-flight damage; raw character
removal/recovery without respawn; real reset/anchor/old-intent rejection; three
real rockets and mixed damage; actual carrier Kick/recovery; and drained
idempotent teardown. Health/result assertions were not weakened.

Trace audit confirms the corrected timing. Moving-direct aim age at derived
acceptance is **0.033848–0.283879 seconds**. Death shot `rocket:1:2` has age
0.033848 seconds: health starts 300, the shooter is Alive with Humanoid health
100 and two flights exist (the other is the previous deliberate miss). After
death, the shooter is Eliminated, the launcher is Available with its exact
reload deadline retained, the round stays Active and both flights persist.
The matching shot then reports aircraftHit=true and aircraft health 200.
Separately, pristine aircraft health goes **300→200→100→0 / Results**. Twenty-one
actual rifle hits reduce 300→195, followed by rockets to **95→0 / Results**.
The passing cases assert the Ground/AircraftDestroyed result.

No unresolved reproduced production defect remains. A1/A2/A3/A4/A6 pass; A5's
actual three-client acquisition, death/disconnect/recovery and replicated
identity/readiness/health portion passes. **Actual same-identity reconnect is
still required and unverified**, explicitly reported as
`actualReconnectVerified = false` and `requiredUnverified = {"A5 actual same-identity reconnect"}`.
The eleven passing cases do not erase that independent gate. Current helpers
provide additional identities rather than reconnecting a departed one; pure
MatchService tombstone checks prove policy, not the real adapter/network
scenario. D50 does not waive P08. Full plan acceptance remains incomplete on
that concrete missing evidence; P09 is not promoted or implemented.

After preserving evidence, actual-server EndTest closed all owned children.
Only original `e45b78d9-003f-45ad-b35e-00e5a5ed494a` remained, Edit, not running,
ManualHarness=nil and BootstrapStatus absent. The default simulator and
LandscapeLeft orientation were verified. No active test or owned fixture
remains, and Studio mutation ownership returned to primary. No merge or Roblox
publication occurred.

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
