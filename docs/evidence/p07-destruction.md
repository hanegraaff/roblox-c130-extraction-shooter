# P07 destruction verification

Implementation selected on 2026-11-13 on `plan/07-destruction`, from main
`e4c6e3a2506a9e9ac5574bdf42242f77f8200650`. P06, P13 and P14 are integrated.
This record will preserve candidate hashes, actual results, defects and limits;
the existing baseline does not validate newly implemented destruction.

Required environments are the full host gate, real Studio geometry/collision/
thermal/physics checks, two actual clients plus a late join, repeated resets,
and focused operated review. A representative actual destruction capture must
replace the README image after visible behavior stabilizes.

The existing `tests.rbxlx` Studio instance
`eea79821-d1ee-47bb-b6c6-cdf494d9ba94` was confirmed in Edit. The same test
document and Rojo `PlayersVsC130Tests` mapping on port 34872 will be reused.
Source and live-place ownership transfer explicitly between developer and tester.
No P07 suite has run at selection; no completion or publication is claimed.

Before writing/running new tests, the developer proposed and the primary agent
recorded D46–D48: firedAt-based consecutive accepted outcomes (including explicit
miss/expiry), 0.225-second maximum gap, zero first-impact credit, 1e-7 threshold
tolerance, capped stage credit with uninterrupted timing retained across stages;
central 50% opening; four fragments/transition, 48 live, eight-second lifetime,
launch at most 12 studs/second and 4 radians/second. Rejected requests leave
progress unchanged. Geometry/player-damage queries finish their batch before
residual geometry swaps. These defaults precede candidate test results.

## Development checks before a stable candidate

On the uncommitted development source, the developer's first focused Lune unit
run passed 54/54 (four new P07 cases). The integration run discovered 50,
passed 49 and failed one: exact repeated 0.15-second aircraft cadence exposed
floating-point readiness comparison rejection. The seven new destruction-ledger
cases passed in that run. This is a recorded failed development check, not a
passing full gate or engine result. The developer applied the pre-recorded
D46 readiness tolerance before the next full gate; independent verification
and exact stable source hashes remain pending.

For A6, read-only testing research found the official testing guide describes
live client-count adjustment, but the installed UI route is unverified. The
planned manual harness starts with two actual clients, records accumulating/
Damaged/Destroyed panels, waits for old debris to expire, then publishes an
explicit late-join checkpoint without resetting. A genuinely new third player
must join afterward and spectate the same round. Initially connected players
will not be relabeled as late joiners; this required check is still unrun.

## First committed candidate and independent findings

Source `e577ee4e0f364fb6084d096627cf1b4b23dae6a7`, tree
`9f357932834b7364760f8c3a2ead6bfa9893d0ba`, snapshots the first compiled
implementation. The developer's host gate passed 54 unit / 51 integration
with 353 authored part transforms per build; clean solo Studio passed 134
server / 6 client. Earlier development runs executed their named cases but had
a stale Edit `ReplicatedStorage.BootstrapStatus` left by the prior low-level
Run diagnostic. The developer preserved that inventory, removed only the
confirmed runtime folder and reran cleanly: actual Uptime advanced 13→33,
Running stayed true and no new bootstrap-ownership error appeared. No
production-code workaround was added. Direct Run cleanup must cover runtime
instances as well as Workspace attributes.

Independent pre-launch review reproduced a high-priority A2/A7 defect with the
actual DestructionService: 61 valid shots at 0.15-second cadence with 0.6-second
flight should complete nine seconds, but the adapter's idle wall-clock cutoff
discarded the valid in-flight tail and left progress zero. D49 records an
ordered interruption barrier correction before its new regression tests.
The tester also confirmed the unrun manual harness needed an authoritative
M102 readiness wait after traversal, and P05/P14 upper-panel helpers still
assumed BasePart registry roots instead of the new Model representation.
These are unresolved findings on the first candidate, not a multiplayer pass.
Actual creating-shot player protection and rendered thermal review also remain
required beyond the current geometry/batch helper checks.

A fourth adapter defect was confirmed before launch: a string PanelId on
unregistered/permanent cover was passed to the strict ledger, whose correct
unknown-ID rejection left the accepted shot frontier unresolved and stalled
later panel outcomes. The adapter must classify the actual current registered
model/descendant identity and consume other valid impacts as nonstructural
outcomes; direct malformed service inputs still reject without mutation.
The developer owns all four targeted corrections while the tester holds
read-only. The original [flight-tail reproduction](p07-flight-cutoff.txt) is
preserved separately from subsequent results.


## Corrected frozen candidate and independent checks

Candidate `cb530a0175f683f933d93fa7546b377614788c39`, tree
`9bfcf88f9c52dbfd57db77858ed7ad56ebc337eb`, fixes the four findings above.
D49 specifies the ordered interruption barrier; terminal cancellation still
invalidates all pending outcomes. Runtime/tests/assets scope SHA256 is
`62872c861b1c3ad6703b408b5df3ef4548fb68df8f2345f006135bb9b975554e`
over 103 files. The [candidate metadata](p07-candidate-cb530a0.json) and
[independent file hashes](p07-source-files-cb530a0.json) identify that scope.

The developer and independent tester each ran `python3 scripts/verify.py`
against unchanged candidate source: exit 0, **54 unit / 53 integration**,
zero suite failures/skips. Formatting, lint, strict type analysis, builds,
expected-failure/empty-suite/type/artifact-corruption probes and release/test
isolation checks passed. Each artifact contained 353 authored parts;
artifact inspection covered 7,146 visible-part pairs, 432 release / 515 test
Instances and 40 release runtime scripts. Environment: macOS 26.6.2 arm64,
Python 3.10.4, pinned Rojo 7.7.1, StyLua 2.6.0, Selene 0.32.0, Lune 0.11.1,
Wally 0.3.2 and luau-lsp 1.70.1.

The [corrected flight-tail reproduction](p07-flight-cutoff-corrected.txt)
executes the actual service: the original timestamp-cutoff schedule remains
stage 0, while the corrected ordered accepted prefix reaches stage 1 after
nine accepted seconds plus 0.6 seconds of flight. Committed integration tests
also cover partial-prefix clearing, no bridging/resurrection and terminal
cancellation. This is deterministic service evidence, not a multiplayer run.

On Studio 0.747.0.7471481, both independently started ordinary solo Play
sessions passed **137 server / 6 client**, zero failures/skips/errors. The
[developer report](p07-developer-clean-studio-137.json) records first actual
client at 0.148815 seconds and Bootstrap Uptime 13→31; the
[independent report](p07-tester-clean-studio-137.json) records 0.141554 seconds
and Uptime 11→23. Both ran from a clean Edit document with no bootstrap-ownership
error. The tester compared all 97 mapped script lengths and rolling hashes
against local source with zero mismatches; the external SHA256 manifest is
separate. An existing asset-type mismatch for `rbxassetid://203785492` was
observed in console. Signed-in user identifiers are redacted in saved reports.

Named engine tests include all-111-panel geometry/identity/support checks,
actual fragment fall/contact/group/query/avatar/cap/lifetime assertions,
registered-impact classification, geometry-batch pre-impact queries and
repeated map/reset cleanup. The pre-impact helper case does **not** yet prove
creating-shot actual-player blast protection or rendered thermal readability.

Native two-client/actual late-join checks, actual-player blast checks,
P05/P14 multiplayer regressions, operated readability and the new representative
capture remain pending. The same original Edit document was returned clean,
then armed with test-only `ManualHarness='P07'` for the requested native launch.
No P07 completion, merge or Roblox publication is claimed.


## Delivery checkpoint

[Draft PR #29](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/29)
was created on 2026-11-13 from `plan/07-destruction` at
`18c28e9a6f2d333b90e74a6a96da4a06d40d57d1`, with the pending checks stated
in its description. Remote main remained
`e4c6e3a2506a9e9ac5574bdf42242f77f8200650`. This draft delivery does not
mark P07 complete or integrate it.

## First actual native multiplayer run

On 2026-11-13 the user started Server & Clients with two actual clients.
Native server `30579148-0d78-4851-bce9-8384f9aa57da` observed Player1/-1
Operator Alive and Player2/-2 Ground Alive. Its baseline discovered/passed
137 server cases with zero failures/skips/errors; first actual client arrived
at 5.075 seconds. Runtime source remained `cb530a0` (documentation head
`a80780906fdd78e616f763cccb719c4c02ad1897`).

The P07 harness discovered three cases, passed two and failed one. Rejected
requests left cover unchanged. Actual M102 impacts on
`Foundry_S02_Roof_01_02` produced Intact after hits 1/2, Damaged after 3,
Damaged after 4/5 and Destroyed after 6. The sustained GAU-23 case timed out
with `P07 timeout: nine seconds of actual 30mm`. The harness stopped its owned
runtime; native windows remained open for diagnosis and controlled rearm.
This is a failed multiplayer gate. No late-join checkpoint was reached and
no A2/A7 or late-join pass is inferred. Cause and correction remain under
investigation; the passing solo/deterministic results above retain their
original scope.

The [native failure report](p07-native-first-failure.json) preserves both actual
client baseline reports (6/6 each), server identity, invocation and console.
Because the fixture's teardown removed its runtime state, a separate controlled
same-session probe is required to capture accepted/rejected GAU-23 timing;
the original failure has no retrospective per-shot timeline.

A subsequent source review also found a P05 regression fixture still requiring
the raw `P05MuzzleOverlap` tag as structural impact identity. The current
production normalization correctly reports no registered panel for that
external solid. Its collision/position/protected-health/no-flight assertions
must be retained while correcting that expected identity. A forecast warning
that P07's wall target may become occluded during heavy reloads remains a
fixture risk, not an observed native failure.

### Focused same-session GAU-23 diagnosis

The independent tester rearmed the actual production runtime on the same two
clients and fired the original bounded 61-request / 0.151-second fixture.
No thresholds, gap tolerance, clock or Heartbeat were replaced. The
[diagnostic trace](p07-gau-diagnostic.json) and
[summary](p07-gau-diagnostic-summary.json) show 60 accepted outcomes and
60 impacts, all on `Foundry_S02_Roof_01_03`; every view validated. Request
sequence 45 arrived 0.000859 seconds before the authoritative cooldown ended
and correctly rejected, although its local send interval was 0.151147 seconds.
The next accepted gap was 0.315841 seconds, above the existing 0.225-second
continuity limit. The ordered barrier correctly cleared 6.999062 valid seconds.

The local burst took 9.983341 seconds, median send interval 0.166708 seconds.
This establishes a reproducible fixture delivery-jitter failure path, while
the original failed run itself retains no retrospective timeline. The
observer's Readiness snapshot ran before dispatch; actual acceptance is derived
from resolved shot IDs/firedAt, not the observer's initial guess. A preparation
script error before any requests was cleaned up separately and is not a
candidate failure.

The authorized correction is confined to test fixtures: provide delivery margin
inside the unchanged cadence/gap bounds, use current view intent, record actual
accepted timing and preserve first-impact/threshold assertions. Production
cooldown, nine-second threshold and interruption rules remain unchanged.
The P05 external-solid fixture and P07 wall visibility guards are included
in that consolidated test-only correction before another full gate/rearm.

### Corrected fixture candidate and retained-session rerun

Source `8c5a871616cb9b99614385d40da5e7a68db5ce23`, tree
`2a06e066d3d70bd7db8b695e6f875b9dfc0b036f`, changes exactly three Studio
fixture modules. Runtime, core rules and assets are unchanged from `cb530a0`.
The [fixture hash record](p07-fixture-freeze-8c5a871.json) identifies those
files; combined SHA256 is
`34cbaf5fa48485f4bf9dc89dfdb7322b2bebc5d5444eed30b0e079cc621d0b2f`.

The developer's focused formatting, lint and Roblox-aware strict type checks
passed. The independent tester then ran one full `python3 scripts/verify.py`
gate: exit 0, 54 unit / 53 integration, all non-Studio gates passed. Review
confirmed current-send view generation, the bounded 0.18-second delivery
margin, actual 61 same-panel impacts, first-impact zero and at least nine
accepted seconds, settled snapshot checks, the exterior wall forecast and
the independent P05 overlap proof. No gameplay tolerance was widened.

The tester loaded fresh exact-source fixture modules into the existing native
server and its two actual clients, checked Source equality and retained
per-file hashes, then started P07 once on that same session. No SDK launcher,
new native session or source-only result substitutes for this actual rerun.
Its results are pending at this checkpoint.

That [retained-session rerun](p07-native-8c5a871-failure.json) discovered four
cases, passed three and failed one before late join. All 61 real GAU-23 impacts
hit the intended panel; first-impact credit was zero, accepted span was
11.032572 seconds and the stage transition occurred at 9.016574 accepted
seconds. The wall forecast selected `Warehouse_S01_West_01`; all three actual
M102 impacts produced the expected progress and Damaged opening. The actual
Ground client completed its Walk probe, but the immediate server assertion
failed with `server did not observe traversal`. Teardown restored the body
before its post-reply physics trajectory could be recorded. This is another
failed whole multiplayer gate, not an A3/A6 pass or late-join result.

Before another run, a minimal fixture-only correction declares a two-second
bound for the actual server root position to reach the same goal after the
client reply, preserving the original two-stud distance assertion. Start,
goal, reply/final server positions and elapsed wait must be retained before
restoration, including on failure. No goal teleport or simulated movement
will substitute for actual Humanoid/physics replication. A narrow same-session
probe will distinguish delayed replication from a persistent movement issue.

The minimal correction is committed as
`e45ef48dad0d8e43757a70662c74c6b190f1b18c`, tree
`8434c9f058bf357db159112de51cfac194cea388`; the
[one-file freeze record](p07-walk-freeze-e45ef48.json) identifies it. The
independent full host gate again passed 54 unit / 53 integration and all
non-Studio checks. No runtime/core/assets or client fixture changed from
the preceding candidate. A separate preparation probe failed parsing before
creating any runtime/Instances; it was abandoned in favor of the fixture's
new preserved trajectory observations.

The tester loaded/compared the exact fresh server fixture (42,445 bytes,
SHA256 `5ec48417cce8d9775ff5f5ec5dd0857a584276bcda2276ebbf1d0bf4903f28d7`)
and unchanged client fixture (11,965 bytes,
SHA256 `2bc26bc8e8c9840b84ba8e5bc040f390836021b81d074f9d6b820ea0e26fd2f8`),
then rearmed once in the same native two-client session. It passed the
revised GAU case, actual server-observed wall traversal and settled snapshot
setup, reaching `AwaitingLateJoin` at server time 1794582207.721844. The
checkpoint retains the same Active round, exactly two initial clients and a
240-second budget for a new third PlayerAdded. The primary agent sent the
human add-player request immediately. Late join and the final report remain
pending at this checkpoint; passing pre-checkpoint cases do not complete A6.

The [e45 native report](p07-native-e45ef48-report.json) records the checkpoint
expiring at 1794582447.791767, approximately 240.07 seconds after it started,
with exactly two real clients and no new PlayerAdded. Six cases were
discovered: five passed and the late-join case failed on timeout; the subsequent
reset case was never discovered or passed. The user reported Studio's
client-count control was grayed out. The fixture's runtime cleaned itself,
while the same native server/client windows remained open. The timeout was
not extended and no initial player was relabeled as a late spectator.

Roblox staff previously documented a
[Quick Open Actions workaround](https://devforum.roblox.com/t/unable-to-start-more-clients-when-test-server-is-active/3579798):
on macOS, Option-Command-P, search Start and invoke that action. The staff
report says it adds the original batch size, so an initial two-client session
may receive two new clients. This route is not yet verified on the installed
Studio 0.747 build. The normal guide's live-count statement appears in party
simulation context and did not establish an executable route for this UI.
The primary agent requested a read-only check of Start action availability
before another actual join attempt.

The planned fixture adaptation permits one or two actual new post-checkpoint
clients (total three or four), records arrival identities/times and verifies
every observed new spectator's state, character/equipment absence and shared
panel reconstruction in the same Active round. An actual new third remains
mandatory. Any optional batch settlement remains within the original
240-second checkpoint deadline. This adapts to the documented launcher batch;
it does not substitute initial clients, a restarted server or simulated joins.

The [late-cohort fixture freeze](p07-late-freeze-ebca51e.json) is committed as
`ebca51e65ebd081b6c40698d90e6f9b0a5076899`, tree
`78d7d468511b988e615a45ff80bffad2616e159e`. Focused format/lint/strict
checks passed. The independent `python3 scripts/verify.py` gate passed
54 unit / 53 integration, zero candidate failures/skips and all non-Studio
gates. Its new late-cohort path is still unrun pending usable Start action;
the earlier e45 timeout remains failed evidence.

The user subsequently confirmed Quick Open Actions does list Start, but it is
also disabled because the server is already running. Both suggested native UI
routes are therefore unavailable in this installed manual session. MCP exposes
no native toolbar action; game keyboard/mouse input does not control Studio's
menus, and native CUA is disabled. Earlier SDK-owned multiplayer launch retries
and manual-session AddPlayers rejection are preserved in prior evidence; no
unchanged-state retry was made here. No new client arrived, and the native
two-player session is preserved for all independent checks. A working way to
join a real client mid-round remains the specific external capability needed
to verify late reconstruction; stopping and starting with three clients does
not provide that evidence.

## Actual-player creating-blast protection

The independent tester ran a disposable actual-runtime probe on the retained
two native clients, rotating real roles across two rounds. The
[actual blast report](p07-a4-real-blast.json) passes both weapon profiles:
two discovered, two passed, zero failures/skips. The production runtime and
rules remained unchanged; fixture fire uses the validated delivery margin
and current-send view, actual accepted timestamps and normal remotes.

- GAU-23: creating transition after 9.182287 accepted seconds left the actual
  protected target at 100 health. A later real same-plane control impact
  through the hole reduced health 100→75 at 3.4991 studs, inside its 4-stud radius.
- M102: the third creating impact left the actual protected target at 100.
  A later control impact through the hole reduced health 100→0 at 3.5028 studs,
  inside its 18-stud radius.

Both profiles assert no ForceField, actual root separation from the panel,
blocked intact/residual rays, clear hole/control rays, drained prior flights
and an actual impact contained in the owned control solid. The positive control
proves the same target was within the blast radius; it is not an empty former
wall endpoint. QA runtime/transport were fully disposed afterward, preserving
the native server/client windows. This establishes the player-health portion
of A4; rendered thermal remains a separate unrun requirement.

Exact disposable replay artifacts are retained as text, outside all Rojo/test
source mappings: [server probe](p07-a4-server.luau.txt), SHA256
`2656d92a3f77591a440240ab44d90d77f9711a52cd18fdf3bf2cae992588a8de`,
and [client probe](p07-a4-client.luau.txt), SHA256
`48fa02e27e6fdf0f988c42ea65d54726a88d1111ac7a10827969f3a8bfcd2248`.
These imperative Studio-MCP evidence scripts are not release modules or
automatically discovered suites. With no other runtime/transport owner active
in an existing native session with two actual clients, execute the server
artifact first, then the client artifact once in each actual client. Read
Workspace `P07QAReport`, preserve it, and fire `P07QAStop` to dispose the owned
runtime/transport. Never run these against a published place.

## P05 actual multiplayer regression finding

The [P05 regression report](p07-p05-regression.json) uses the same retained
two-client session and the exact corrected server fixture (41,544 bytes,
SHA256 `d322115d6233f99f1f8fcb2e159c7540ea6ecaeb769ac591f839e541233d4144`)
plus unchanged 7,475-byte client fixture rearmed once per client. Seven cases
were discovered, five passed and two failed: the geometry case plus its
harness-completion entry. The first five rejection, cover, forged-endpoint,
readiness, lethal and reset paths passed. The corrected muzzle-overlap case
was not reached and is not claimed passing. Manual finish saved the report
without ending the native session; runtime/transport cleaned themselves.

The failed geometry request was M102 against real sloped Terrain; GAU terrain
and upper-panel shots passed. Target was
(-263.997925, 13.565300, -159.999237), sampled muzzle
(358.536316, 138, 68.648956), and first projectile sample
(358.370117, 138, 69.511086). The fixture did not retain the failed Impact
before its assertion. A [read-only reconstruction](p07-p05-slope-reconstruction.json)
on unchanged native Terrain found the sampled-muzzle ray 0.0294 studs from
target, but the profile-radius spherecast 5.1666 studs away; the first-projectile
origin spherecast was 5.2117 away. This reproduces the five-stud assertion
failure path through grazing ray/profile disagreement; it does not establish
the lost original Impact or a core gameplay defect.

A minimal fixture correction is authorized to select real sloped Terrain with
a stable non-grazing/profile guard while retaining the original five-stud
remote-impact assertion and preserving actual Impact/path facts before
assertion. Production collision/aim rules remain unchanged pending evidence.

The corrected fixture is frozen at
`873f0f690bfb76803c81f46e0b49390090e2be97`, tree
`b16fb42007179a852c71565beab6b87fc5973001`; its
[source record](p07-p05-freeze-873f0f6.json) retains the exact file SHA256.
Focused format/lint/Roblox strict checks passed. Independent full
`python3 scripts/verify.py` completed with 54 unit / 53 integration and all
non-Studio gates passing. The actual P05 rerun remains pending while the
same native session is used for rendered review; no gameplay/core source
changed in this correction.

The [corrected native P05 report](p07-p05-873f0f6-report.json) subsequently
passed **8/8**, zero failures/skips, on the same two actual clients. Fresh
server Source matched the frozen `0bcf1db...` hash; each unchanged client
fixture was compared and rearmed once. Both profiles passed real sloped
Terrain and upper-panel hits, the corrected unique muzzle-overlap / protected
health / zero-flight check passed, and switching, lethal/reset and exact
projectile lifetime paths passed. The prior failed P05 run remains preserved.

## Rendered and operated review scope

The [render review record](p07-render-review.json) and
[disposable server helper](p07-render-server.luau.txt) preserve the actual
two-client scene and limitations. Three real M102 impacts on
`Warehouse_S01_South_04` (impact times 1794583834.572075,
1794583838.787123 and 1794583843.038433) produced per-hit progress and Damaged.
The [Ground capture](p07/panel-opening.png) shows the new right-hand opening
beside the existing left doorway. The black upright block is an owned QA
visibility marker, not a game enemy or item. This actual staged playtest
capture replaces the README representative image for 2026-11-13.

The [operator capture](p07/operator-damaged-qa.png) is genuine but cannot prove
the intended clean thermal-hole comparison: from that orbit perspective,
`CentreThroughHole` was blocked by the Left residual while the Side target's
center ray was clear. Actual native Two/W/A/D controls worked. Native mouse
firing, a Destroyed-stage capture, clean rendered thermal comparison and
visually observed falling-fragment readability remain unverified. No further
camera/layout retries were made after the bounded scene replacement and
front-side wait. The actual player-health blast checks above retain their
independent passing scope.

Capture metadata records Active round 1, client viewport 1081×618 and graphics
Automatic; PNG outputs are 1920×1080. These images do not establish a
same-pixel calibration check. Image-time client snapshots precede the declared
round deadline; a later server snapshot is in timeout Results and does not
relabel the images as post-round captures. The helper's cumulative impacts
list is shared by earlier observation records, so individual shot timestamps
and per-observation stage/time are authoritative for chronology. The initial
intact overviews were not used as a matched before/after thermal proof.

Render runtime, transport and owned markers were fully disposed, preserving
the two native clients for the remaining independent reset/camera regressions.

## Independent actual two-client reset check

The [reset-only report](p07-reset-only-report.json) passes **2/2** actual
round cases, zero failures/skips. This is a separate suite; it does not skip
the late-join case inside the full P07 harness or turn that failed run into
a pass. Its [server artifact](p07-reset-only-server.luau.txt), SHA256
`f3bb3bf7aa109724ce8b3d594cc2d1b9d62af0b90849f979f94dc689eb4dc240`, and
[static-check record](p07-reset-only-sha256.json) are outside source mappings.
The developer ran formatting, lint and Roblox-aware strict analysis; the
independent tester installed exact Source, rearmed the existing 11,965-byte
P07 client helper once per actual client and executed the probe.

Each round had four live fragments, two actual in-flight projectiles and
positive published/rules sustained credit immediately before abort:
0.166685104 seconds in round 1 and 0.199863911 in round 2. Four bounded
current-view Fire intents at 0.18-second spacing use production validation;
no elapsed/progress/health claim is injected. After each reset, all 111 server
panel IDs/pivots/stages/progress and all 334 map-Part fingerprints match the
pristine baseline. All 576 material/occupancy voxel samples across eight hill
regions match. These are sampled native Terrain checks; the separate named
engine reconstruction cases provide the full-recipe voxel evidence.

Both actual clients verify all 30 roof panels and no historical debris after
each reset. The existing client vertical-ray helper is roof-specific, so
this is not described as all-111 client ray verification. Stale-round outcomes
reject without mutation and pristine state persists after the 2.25-second
pending-flight deadline. Runtime, transport, fragments, characters and teardown
lease were absent/drained before handing the native session to P14.

Replay requires no competing owner in the same actual two-client server:
install the server artifact as a fresh disposable ModuleScript, call the
current P07 client helper's `.run()` once in each client, then asynchronously
call the disposable module's `.run(sourceTag)` in the server. Read Workspace
`P07ResetOnlyReport`; collect it before removing only the disposable module
and its stage/report attributes. The probe owns its normal cleanup.

## Final executable source identity

The independent [103-file manifest](p07-source-identity-873f0f6.json) identifies
candidate `873f0f690bfb76803c81f46e0b49390090e2be97`, tree
`b16fb42007179a852c71565beab6b87fc5973001`. Canonical serialized manifest
SHA256 is `b782434834e82549f17af2e35f124eec7d11e9ebd92f8a7c87c8e5834b71c5fc`.
Only the three authorized Studio fixture modules differ from runtime candidate
`cb530a0`; all runtime/core/assets and TestEZ rule/engine specs are unchanged.
Later prose, screenshots and replay evidence do not change that executable
candidate.

## Final actual camera regression

The [full P14 regression report](p07-p14-regression-report.json) passes
**6/6**, zero failures/skips, in the retained actual two-client session.
The tester loaded exact fresh server Source (19,231 bytes, SHA prefix
`3b7b09a`) and client Source (72,253 bytes, `ecc6776f`) on both clients,
matching the candidate manifest. All raw report chunks were retrieved and
parsed before saving: 150,863 bytes, 49 observations plus baseline reports.

Both weapon full-orbit samples, upper-panel Model helpers, zoom/rejected
selection/pan plus Ground overlap, blocked/recenter behavior, actual occluded
thermal configuration, new-round focus reset, operator departure and repeated
teardown passed. The final required kick left one actual player. No capture
or input was added during orbit timing. This preserves P14 regression scope;
its existing thermal-configuration case does not close the new P07 rendered
hole-comparison or operated readability gaps described above.

The [independent review](p07-independent-review.md) consolidates findings,
exact-source gates, resolved defects and remaining unavailable/unverified
checks. Signed-in solo Studio identifiers are redacted in that prose; actual
local native test IDs remain distinguishable.

## Final cleanup and delivery limits

[Native cleanup proof](p07-native-final-cleanup.json) and
[original Edit proof](p07-final-edit-cleanup.json) confirm all results were
saved before actual-server EndTest succeeded. Runtime, aircraft, state,
transports, fragments, marker targets, characters, teardown lease and five
disposable server modules were absent/removed. Only the original Edit
`tests.rbxlx`, Studio `eea79821-d1ee-47bb-b6c6-cdf494d9ba94`, remains.
Its ManualHarness selector is nil, Workspace attributes are empty and no
BootstrapStatus/EntrypointStatus or QA artifacts remain. Existing Rojo PID
55771 still serves 127.0.0.1:34872. A final read-only comparison of all 97
mapped scripts reports zero byte-length/rolling-hash mismatches against the
current repository; external SHA256 identity is recorded separately.

The passing e45 traversal measured server distance 1.813776 studs from the
goal with almost no replication wait. It proves the unchanged two-stud
criterion in that run; the prior immediately restored failure has no saved
trajectory, so its exact cause is not retrospectively claimed.

All available automated gates and independent two-client blast, reset, weapon
and camera regressions have passing scoped evidence. Required genuine
post-damage late join is unavailable in the installed manual session, and
the focused rendered/operated gaps in A4/A7 remain open. The roadmap records
the concrete capability block, P08 remains Planned and PR #29 remains draft.
No plan completion, merge or Roblox publication is claimed. Later prose/media
commits preserve the final executable source `873f0f6` and its manifest.

The final delivery checkpoint verified remote feature head
`4f3fbeb01bc5769e340bd94ccda94c33d745a5d3` and clean local tracking state;
remote main remained `e4c6e3a2506a9e9ac5574bdf42242f77f8200650`.
[GitHub Verify 255](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/43451965908)
passes on executable source `873f0f6`, and
[Verify 259](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/43456880127)
passes on the evidence/media checkpoint `4f3fbeb`. Final repository checking
passes 77 Markdown / 166 JSON files, whitespace checking passes and all 103
executable-manifest files still match. PR #29 is open, draft and unmerged.
