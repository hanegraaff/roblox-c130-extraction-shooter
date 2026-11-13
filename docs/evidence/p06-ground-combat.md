# P06 ground combat verification

P06 is in progress on its dedicated branch. This record distinguishes actual
engine runs, source-specific host tests, identified defects and unrun checks.

## Same-shot user diagnosis on `6613375`

The [matched user recording](p06-same-shot-user-661.json) contains 12 paired
client/server shots (sequences 133–144). For aircraft shots 133–135, raw
`GetMouseLocation()` Y was 144 and the actual aircraft center projected to
viewport Y 143.7–144.7. Production subtracted the 58-pixel GUI inset before
`ViewportPointToRay`, aiming at Y 86. Both the independently sampled client
and server rays missed; aircraft health stayed 300. The client target and
transmitted payload agreed within 0.001 studs, with paired frame times
1.8–18 milliseconds before server receipt. The aircraft center was also
12–20 pixels left of the pointer, so this recording does not establish that
every corrected shot would hit its silhouette. Ground shots 137–144 hit the
GroundDisk on both sides, as expected.

Before ending the session, a separate native mouse-ray measurement returned
raw mouse `(701,466)`, `Mouse.X/Y = (701,408)` and inset `(0,58)`.
`Mouse.UnitRay.Direction` dotted with `ViewportPointToRay(raw).Direction`
was 1; the inset-subtracted ray's dot was 0.993409276. This independently
confirms that the subtraction displaced the firing direction. The earlier
GroundAimGui test used the same subtraction for expected and actual values;
its pass proved internal agreement, not agreement with the physical pointer.
Its earlier alignment claims are superseded by this actual user evidence.

[Roblox's camera reference](https://create.roblox.com/docs/reference/engine/classes/Camera.md)
distinguishes viewport ray coordinates from GUI `AbsolutePosition`, which
uses core UI coordinates. The correction must retain raw viewport pixels for
desktop rays and convert only the drawn GUI offset using its measured origin
and inset. New engine checks must use native mouse rays and independently
projected world points rather than repeating the production conversion.

The terminal-only cosmetic segment also explains the user's feedback: a sky
miss placed its 50-stud streak 1150–1200 studs away, whereas a nearby ground
hit showed a thick static segment. A moving cosmetic trace along the resolved
path is being implemented without changing immediate server-authoritative
hits or cover. This is a diagnosis and proposed correction, not acceptance of
the revised presentation.

Diagnostic observers and transport were removed. The session returned to
Lobby, then server `StudioTestService:EndTest` closed it. MCP confirmed only
the original `tests.rbxlx` document remained in Edit. Source changes and fresh
engine/operated review can now proceed; no additional plan has begun.

## Corrected native aim and moving trace: `59252c9`

Source `59252c96d8774473cde642b50fc0ecd39e8bd5e3`, tree
`edac5ce19179897ebde7269f896e1d6efbd41577`, restores raw desktop viewport
aim and converts only GUI drawing offsets. A server-owned cosmetic tracer now
travels along the already-resolved shot ray; damage still resolves immediately.
The maximum visible segment is three studs, cosmetic speed is 1200 studs/second,
travel lasts 0.15–1 seconds, and a 0.1-second terminal hold precedes removal.
There is also a brief barrel flash. Reset and stop destroy owned effects.

The developer's full `python3 scripts/verify.py` passed 50 unit / 43 integration
cases and the other host gates. [GitHub Verify 43334404940](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/43334404940)
passed on that exact commit. The independent tester confirmed all four changed
Studio sources were byte-identical and ran fresh Play smoke: 118/118 server,
6/6 client, zero failures/skips. The [structured oracle report](p06-aim-592.json)
preserves the actual reports and source-specific samples.

After native pointer movement, actual raw mouse was `(500,258)` with inset
`(0,58)`. Corrected ray/native `Mouse.UnitRay` direction dot was 1.00000012;
the inset-subtracted comparison was 0.990908. An independently projected world
point and actual drawn reticle center converted to viewport coordinates both
equaled `(500,258)`. Touch projection rounded the center to `(577,290)` for
a 1153×579 viewport. These checks establish the coordinate correction; they do
not establish moving-plane user accuracy or network tracer readability.

Studio returned to the sole original Edit document. P06Team with three actual
clients is prepared for native launch. Current-source P06/P06Team, P05/P14
regressions, moving-tracer observation, operated desktop/phone review and a
current representative capture remain open; PR #27 remains draft.

The subsequent native three-client P06Team run did **not** pass. Its
[report and client console](p06-team-592.json) show 118/118 server smoke
(two clients present at that sampling), 6/6 smoke on Player1 and Player2,
and 5/6 with one error on Player3. Player3 failed the new independent world
projection assertion; it therefore never announced harness readiness. With
three actual players present, the team harness timed out at client readiness
and reported 0/2. No gameplay/team case is accepted from that run.

The assertion did not log its original viewport or camera values, so its
cause is not established. A [later same-client probe](p06-team-592-probe.json)
at 1081×618 / FOV 70 produced a passing rounded-world-ray dot of 0.999999702
and raw/native mouse ray dot of 1. That later reconstruction neither reproduces
nor explains the original failure. The test also captured its native mouse
sample before two render-frame waits; improving sample timing and diagnostic
precision is required without dropping the independent oracle. The tester
ended the session, cleared the selector and confirmed the original Edit
document before releasing it for investigation.

Test-only follow-up `dc081f4363f9deb42994c9b3d59fa61d640c8c44`, tree
`afc8b0780211b068bc45e25d0aefadbb16268544`, keeps the gameplay source from
`59252c9`. It waits up to ten seconds for a current camera and at least a
200×200 viewport, samples native pointer/ray together, and measures the actual
production ray against independent world and native-ray projections within
one pixel. The tolerance expresses the existing integer-raster contract
without a viewport-dependent angular assumption. An injected 58-pixel error
must fail that independent projection. Failure details now include viewport,
inset, camera/FOV, world point and ray samples. The developer's full host gate
passed 50 unit / 43 integration. The original Player3 failure remains
unexplained; this test revision is not a retrospective pass for it and needs
fresh actual three-client validation.

## Initial candidate `888de26`

Independent `python3 scripts/verify.py` passed 50 unit and 38 integration
cases plus the non-Studio gates. Fresh Studio smoke passed 109/109 server cases
with one client and 3/3 client cases. The first two-client SDK launch reached
one client and timed out before any P06 scenario; a single clean retry passed
5/5 P06 scenarios with two actual clients and zero failures/skips. The
[structured reports](p06-studio-888de26.json) preserve both outcomes.

The independent tester confirmed three material findings:

1. The equipped rifle reticle's actual AbsolutePosition was `(-12, -12)` on
   desktop and phone; mobile fire uses viewport center, so the displayed aim
   indicator was offscreen and not aligned with the firing ray.
2. On simulated iPhone 17 Pro landscape at 750×381, the Ground RoundHUD
   rectangle `(105,112,540,102)` overlapped RifleStatus `(210,187,330,36)`;
   FoundationStatus `(16,16,400,86)` further obstructed the view.
3. A disposable Studio MatchService fixture at a fixed pre-deadline clock ran
   `eliminate(lastGround); step(); proposeAircraftDestroyed(roundId)` without
   yielding, resulting in Gunship/GroundEliminated and rejecting the later
   destruction proposal. Production P05 impact calls eliminate and step
   immediately, so it cannot guarantee the design's same-step Ground victory
   precedence when elimination resolves first. The tester did not physically
   stage simultaneous projectiles.

The five-case two-client suite did not establish both-client shot/destroyed/
result observations, a real eliminated teammate's shared victory, operator
forfeit distinction, dead/spectator/flood/friendly-fire cases, repeated reset
and stale-resource cleanup, or pristine three-rocket engine behavior. Native
reciprocal desktop and phone firing/aim/reload and player feel also remained
unverified. These findings and gaps require correction and a fresh review.

## Corrected candidate `275eb73`

The developer corrected the reported rifle reticle and ground HUD layout, and
changed both combat owners to submit outcome proposals for a deferred
per-Heartbeat MatchRuntime evaluation. Independent host `python3
scripts/verify.py` passed 50 unit / 39 integration and all non-Studio gates.
Fresh Studio smoke passed 110/110 server cases and 3/3 client cases. The
two-client P06 suite passed 7/7 and the three-client P06Team suite passed 5/5,
with zero failures or skips; see the [structured reports](p06-studio-275eb73.json).
These include both nonyielding same-step outcome submission orders and a real
eliminated teammate observing the Ground win. They do not yet prove physically
concurrent projectile/Heartbeat callback ordering.

The subsequent P05 regression SDK launch stalled before Play and opened an
additional read-only test document; it did not run any P05 scenarios. Revised
native desktop and simulated-phone controls and layout remain unverified.
The tester stopped repeated launches and the user was asked to close both test
windows before a fresh document is opened.

## Movement and origin follow-up

Fixture-only `b4ad31f` adds pristine three-rocket swept impacts and a real
operator-forfeit/reset sequence. Independent host verification passed 50 unit /
39 integration; its two Heartbeat callbacks initially did not record their
actual execution order or shared frame. `720176b` adds those assertions and a
server-only movement budget before accepting rifle origins. Independent host
verification passed 50 / 42. Its defaults are 70 studs/second refill, 45-stud
burst and 8-stud quarantine recovery; rejected movement does not consume ammo
or change aircraft health. A legitimate server map correction resets the trusted
position. The 45-stud burst is a tolerance, not proof that all short teleports
are excluded. The guard measures displacement, not swept character-path cover;
a short relocation through a wall is a code-derived risk not reproduced in
Studio. A stricter path check could reject legitimate stair/slope movement and
needs its own engine validation. The revised engine scenarios remain unrun.

The independent reviewer then identified potential head-through-cover and
Terrain-origin bypasses. `c793399` adds root/head BasePart overlap checks, a
root-to-head Battlefield/Terrain ray and a conservative occupied-voxel check.
Its full independent host gate passed 50 / 42. `89ef004` adds controlled
Terrain-query failure handling, bidirectional root/head rays and cheap,
nonmutating rifle intent preflight before geometry; the independent host gate
passed 50 / 43. These later source revisions have no Studio acceptance yet.
The voxel test deliberately rejects partially occupied terrain voxels; actual
standing, jumping and steep-slope playability must be checked in Studio before
it can be treated as acceptable. A current P06 screenshot, operated desktop and
mobile review, the P05 regression and final two-/three-client suites remain
outstanding.

Candidate `644a90d` routes an optional nonyielding Terrain query through
server-only composition; production uses the same real Terrain query. The P06
real-client fixture injects one query failure, checks health and ammo remain
unchanged, then retries the same sequence and expects one ammunition spend.
Independent source review found no material defect in this delta, and the full
host gate passed 50 unit / 43 integration and all non-Studio checks. This
remote failure/recovery scenario and the current origin/slope fixtures remain
unrun in Studio. The two stale Studio Edit windows from the pending SDK launch
must be closed before safely reopening the rebuilt test document and resuming
the two-/three-client suites, P05 regression and operated control checks.

## Fresh Studio check on `644a90d`

After the user closed the stalled windows, the guarded launcher reopened a
single `tests.rbxlx` document. Candidate source signatures matched. Fresh
ordinary Play discovered 118 server cases, passing 116 with two errors and no
skips; the client passed 2/3 because its server fixture failed. The errors were
`root inside Terrain with exposed head accepted` and `sloped terrain sample
missing`. No multiplayer scenario was launched after the failed baseline.

The independent tester reproduced the first as an actual origin-geometry
defect. A disposable Rock block centered at `(2050, 16, 0)` with size
`(32, 16, 32)` gave a real Terrain surface at Y=`25.466398`. Root Y=23 and
head Y=25 were below that surface, yet the head's `ReadVoxels` cell reported
Air/zero occupancy and the guard allowed firing because both segment rays
started inside solid Terrain. Disposable geometry was removed afterward. The
same five slope samples passed in a separate direct engine rerun, but that
does not explain or erase the earlier failed fresh smoke. Both findings need
correction and a fresh candidate run.

## Terrain correction on `a4d53f3`

Independent host `python3 scripts/verify.py` passed 50 unit / 43 integration
and all non-Studio gates. Fresh Studio smoke passed all 118 server and 3 client
cases, with zero failures, skips or errors, including the prior smoothed buried
root/head cases and the slope fixture. A separate real-Terrain probe accepted
154/154 bounded standing/jumping positions on a spherical slope and one clear
stance in an air pocket between a Terrain floor and roof. These finite samples
are not proof for all future terrain or cave geometries. Fixtures were removed.

The subsequent two-client SDK launch stalled before Play, created one additional
read-only Edit document, and returned no P06 report. No current P06/P06Team/P05
multiplayer scenarios, real-client query-failure/recovery or operated rifle
checks ran. A test-only manual Server & Clients fallback is being prepared to
avoid relying solely on the stalled launcher; it is not yet engine-validated.

Candidate `e55a961` adds the P06/P06Team manual route only to the Studio test
mapping. Its `ManualHarness` selector is server-only and temporary; actual
server reports must be captured before ending the manual session and the
selector cleared afterward. The test assertions are shared with the SDK path.
Manual P06 uses an actual server-initiated player kick for the forfeit scenario,
whereas SDK P06 uses client `LeaveTest`; P06Team does not exercise departure.
After at least one client joins, failure to reach the requested count produces
a bounded report; a zero-client launch can fail in the outer bootstrap before
the harness emits one. Independent host verification on `9e12210` and a fresh
full host gate on `e55a961` each passed 50 unit / 43 integration, including
test/release isolation probes.

After the user started native Server & Clients with two clients, the manual
route on `e55a961` reached both actual clients. Fresh server smoke passed
118/118 and each client passed 3/3. The P06 report then had 5 passing cases,
one Terrain-query failure/recovery timeout and a corresponding harness-completion
failure; see the [actual report](p06-manual-e55.json). The preceding shot's
ammo had just decreased when the next request was sent, so the 0.15-second
cadence may have rejected it before query injection; the report lacks the
timing needed to prove this. The temporary selector was cleared in Edit.
The Studio stop tool returned success but did not close the actual manual
simulation windows; the user was asked to use End Session. The failure must be
diagnosed and the current-source tests rerun, not treated as a pass.

The user ended the owned simulation. Candidate `60aa623` makes the query-error
fixture wait for the server-owned rifle readiness and records each remote
decision, time, sequence, ammunition, health and injection count. It preserves
the original no-mutation and same-sequence recovery assertions. The optional
decision observer is server-composition-only and omitted in production; the
independent tester verified readiness returns a copy. Independent full host
verification passed 50 unit / 43 integration, and fresh Studio smoke passed
118/118 server and 3/3 client. The temporary test-only P06 selector is set in
the sole Edit document for a manual two-client rerun; its outcome is pending.

The user launched the prepared manual two-client rerun on `60aa623`. Server
smoke passed 118/118 and both clients passed 3/3. The P06 suite passed its
loadout and adversarial cases, then timed out waiting for an actual rifle hit
on the moving aircraft; harness completion failed as a consequence. The later
Terrain-query recovery case did not run. The [manual report](p06-manual-60aa.json)
and baselines preserve the result. The fixture had already destroyed its runtime
before diagnostic values could be inspected, so neither a moving-target miss
nor an origin/cadence rejection is established. The test is being instrumented.
The selector was cleared, and a supported `StudioTestService:EndTest` call from
the actual manual Server context closed all simulation windows, leaving the
original document in Edit with selector and SDK arguments absent.

Candidate `6c5a016` moves the trusted rifle fixture 20 studs inside the
playable disk, rather than exactly on the moving aircraft's boundary, while
preserving the live orbit, single-shot and solid-cover assertions. A server-only
optional shot observer, absent in production startup, records authoritative
origin, intended target, actual ray hit, aircraft position, time, health and
damage alongside readiness and rejection diagnostics. No retry or aircraft
freeze was added. The independent tester's full host gate passed 50 unit /
43 integration, and fresh ordinary Studio smoke passed 118/118 server and
3/3 client. The temporary P06 selector was set in Edit for a new manual
two-client run; its outcome is pending. This revision does not establish the
cause of the preceding rifle timeout without that real-client result.

The manual two-client run on `6c5a016` passed 118/118 server and 3/3 per
client smoke. Its rifle test showed sequence 1 hitting the actual solid cover
with ammo 30→29 and health unchanged, then sequence 2 hitting the actual
aircraft Hitbox with ammo 29→28 and health 300→295. The real-client injected
query failure occurred after the server's `nextFire` boundary, rejected with
health/ammo unchanged, and accepted the same sequence after recovery with one
ammo spent. Six P06 cases passed. The following mutual-destruction case failed
`callbacks did not share the recorded Heartbeat`, causing one additional
harness-completion failure. Its frame/order diagnostics were appended only
after the assertion and thus were not retained, so the cause is unproven. The
[actual report](p06-manual-6c5a.json) contains the shot and recovery details.
The tester ended the owned session via server `EndTest` and cleared the selector.

Candidate `56495f9` changes only the mutual-outcome fixture. It retains two
separate real Heartbeat callbacks and the required actual callback order and
Ground/AircraftDestroyed outcome, but records callback starts/ends, errors,
Heartbeat marker, prior Stepped epoch/time, deltas, clocks, health and phase
before assertions. Its same-frame assertion uses the recorded Stepped epoch
and Heartbeat delta rather than assuming the independent Heartbeat marker runs
before the callbacks. Independent host verification passed 50 unit / 43
integration; the unchanged `6c5a016` Studio smoke remains applicable. Its real
manual two-client outcome is pending.

The user launched the manual two-client run on `56495f9`: server smoke passed
118/118 with two clients, and each client passed 3/3. Six P06 cases passed;
the mutual-outcome case failed its requested ground-first order because Roblox
executed the registered Heartbeat callbacks aircraft-first, producing one
additional harness-completion failure. The [actual trace](p06-manual-56495.json)
records both callbacks in the same Stepped epoch 2, equal Heartbeat delta,
no callback errors, aircraft health 300→0, ground elimination while Active,
then Results/Ground/AircraftDestroyed. This is positive evidence for the
observed aircraft-first order only. Ground-first was not exercised; callback
registration order alone cannot establish it. The manual session ended through
the server `EndTest` API, and the original Edit selector was cleared.

Candidate `bdb1de1` adds a bounded calibration using two harmless independent
Heartbeat callbacks, then selects registration order for the two real combat
callbacks. The fixture still requires the actual requested callback order, same
Stepped epoch/time and Heartbeat delta, pristine swept-rocket damage boundaries
and Ground/AircraftDestroyed result. Calibration and actual timeline are
recorded before assertions; a scheduler change remains an explicit failure, not
a pass. Independent full host verification passed 50 unit / 43 integration.
The test-only manual two-client run is prepared but its Studio result is pending.

The user launched the prepared manual two-client run on `bdb1de1`. Fresh
server smoke passed 118/118 with both clients present, each client passed 3/3,
and P06 passed all 10 cases with no failures or skips. Both requested
mutual-destruction orders occurred as recorded within a shared Stepped epoch
and Heartbeat delta, with no callback errors; aircraft health reached zero and
the result was Ground/AircraftDestroyed in each. The forfeit case used an actual
server kick, leaving one player at report collection; it was not a client
`LeaveTest`. The [full report](p06-manual-bdb1.json) preserves the observations.
The tester ended the session via Server `EndTest`, cleared P06, then prepared
the separate P06Team selector for the three-client run.

The user then launched the manual P06Team run on the same source. All 7/7
scenarios passed with three actual players, server smoke 118/118 and 3/3 on
each client, with no failures/skips. Three live rocket sweeps after a rifle hit
reduced aircraft health 295→195→95→0; the separate two-client run established
pristine 300→200→100→0. [The report](p06-manual-team-bdb1.json) preserves the
actual teammate, friendly-fire and replicated result checks. Server `EndTest`
closed the session and the P06Team selector was cleared in original Edit.

Candidate `dae58a4` adds a test-mapping-only manual P05 regression route so
the existing gunship assertions can run without the stalled multiplayer SDK.
An independent source review confirms the exact `P05` selector is server-only,
requires Studio and nil SDK arguments, checks two actual players and preserves
the existing case body; startup failures are reported after at least one client
reaches the outer bootstrap. The original SDK path continues to use `EndTest`.
Release isolation includes deliberate missing/leaked-fixture probes. Its actual
manual two-client regression and a reciprocal native control review remain
pending.

The user launched the prepared manual P05 regression on `dae58a4`. All 8/8
gunship cases passed with two actual players present at report, zero failures
or skips; server smoke passed 118/118 (one client had joined at its sampling)
and both client smokes passed 3/3. The [full report](p06-p05-regression-dae58a4.json)
preserves actual invocation, observations and results. This verifies the shared
outcome and cleanup changes against P05 on this source; operated P06 controls
are reviewed separately.

In the same two-client session after P05 owners stopped, an independently owned
normal GameRuntime/HumanTestSession exercised native controls. Ground key 1
equipped the M-7; a desktop click spent ammo, R reloaded, and ground W moved out
of the building. Operator 1/2 selected GAU23/M102 with 30°/40° FOV and each
fired an actual server-resolved terrain impact. On simulated iPhone 17 Pro
landscape 750×381, real simulated Touch held FIRE (ammo 23→18), RELOAD restored
30/107, and a separate world swipe moved the camera. The simulator is not a
physical device and the native moving-aircraft hit was not established.

The tester reproduced a material desktop aim mismatch: mouse input at viewport
`(540,160)`, GUI inset Y=58 and visible reticle center `(540,160)` corresponded
to raw `GetMouseLocation=(540,218)`. The actual GroundShot matched the ray
through `(540,218)`; the ray through the visible reticle landed approximately
11.3 studs away. The [operated record](p06-operated-dae58a4.json) preserves the
measurements. A moving-plane burst missed but the exact role of this mismatch
in that miss was not established. A correction and fresh native input review
are required. The tester removed all test owners, restored the simulator,
ended the server session and cleared the Edit selector.

Candidate `9adf5d5` corrects the desktop mouse-to-viewport inset conversion and
uses one rounded viewport pixel for both the reticle and firing ray; touch keeps
the viewport-center aim. A new actual-client GUI/ray spec checks desktop and
touch positions using the real GUI inset and camera. The independent tester
confirmed both source files match the Studio document, the full host gate
passed 50 unit / 43 integration, and fresh Studio smoke passed 118/118 server
and 4/4 client cases with zero failures/skips/errors. The real operated
moving-aircraft aim check and current representative capture remain pending.

The manual two-client P05 regression on `9adf5d5` passed all 8/8 cases, with
118/118 server smoke and 4/4 on each actual client; see the [report](p06-p05-regression-9ad.json).
An operated desktop check at viewport `(540,160)` with GUI inset Y=58 found
the displayed reticle centered at `(540,160)` and the replicated GroundShot
exactly matching a fresh `ViewportPointToRay(540,160)` world query. The old
raw-inset ray landed elsewhere, so the previously measured mismatch is fixed.
Real simulated iPhone 17 Pro touch held FIRE (ammo 29→24), RELOAD restored
30/114 and a world swipe rotated the camera; its reticle was centered within
0.5 pixel. A moving-aircraft native hit was not established. The
[operated record](p06-operated-9ad.json) preserves measurements.

The phone review found a remaining layout defect: at 750×381 the reticle
rectangle `(363,179,24,24)` overlapped RifleStatus `(210,187,330,36)`, shown
in the [actual capture](p06-presentation/mobile-overlap-before.jpg). The
test session, simulator and temporary owners were stopped and selector cleared.
The phone HUD requires correction and a fresh layout/input check.

Candidate `6b569ea` moved the touch-only ammunition label away from the
center reticle; independent Studio smoke passed 118/118 server and 5/5 client.
The tester identified that input-mode changes after HUD creation could retain
the desktop layout. Candidate `0003fe4` samples touch capability in the owned
render loop and updates the existing label on transitions. An actual-controller
Studio case covers desktop→touch→desktop and idempotent cleanup. Independent
full host verification passed 50 unit / 43 integration, and fresh Studio smoke
passed 118/118 server and 6/6 client with no failures/skips/errors. The final
native two-client desktop/phone playability review is prepared, not yet passed.

In an ordinary native two-client session on `0003fe4`, server smoke passed
118/118 with both players present and each client passed 6/6. The tester used
the actual Studio panel to choose Gunship and start an Active round. Native
Ground key 1 equipped the M-7; W moved outside, a shot spent ammo and R
reloaded 29→30/119. At viewport mouse `(540,160)` with GUI inset Y=58, the
actual reticle and GroundShot ray matched within 0.0001 studs. Operator native
selection/firing produced an M102 terrain impact. The [structured operated
report](p06-operated-0003.json) records the exact source and observations.

On the same active client, switching to simulated iPhone 17 Pro landscape
750×381 yielded reticle `(363,179,24,24)`, ammo status `(245,267,260,36)`,
FIRE `(636,123,90,70)`, RELOAD `(636,59,90,54)` and jump `(655,233,70,70)`;
the production controls no longer overlap. Actual simulated touch FIRE spent
30→25, RELOAD restored 30/114, and a world swipe rotated the camera. Returning
to desktop restored the 330-wide status and hid touch buttons. The test-only
Studio panel initially overlaid phone controls, so the tester hid only that
panel for a [genuine phone capture](p06-presentation/mobile-after.jpg). The
[current desktop capture](p06-presentation/current-progress.jpg) is an actual
active Ground view. These simulated input checks are not physical-device tests.

The native operated moving-aircraft hit and resulting health feedback remain
unverified: after ordinary Ground movement and a 28-second projected-visibility
watch, the aircraft did not enter the targetable viewport. A right-mouse drag
in an earlier attempt did not rotate the camera, but its cause (automation,
focus or game behavior) was not established. No injected hit or success is
claimed. The user was asked to try ordinary camera tracking and firing; this
is a playability gap and possible acquisition concern, not a proven defect.
The simulator and owned session stopped, and selector/SDK args were cleared.

## User-operated reciprocal review

The user then operated a fresh ordinary two-client session with the Ground
rifle. Read-only Server observations saw aircraft health fall from 300 through
270 and 255 to 250 during rifle fire; the server and both clients subsequently
reported 250 while the round was Active. [Samples](p06-user-live.json) record
their separate times; they are not claimed simultaneous. Health restored to
300 in Lobby. The user reported that the aircraft could be hit but the health
decrease was not visibly apparent, the rifle appeared to shoot above the
crosshair, and the avatar had no visible gun. Those are material player-facing
findings even though the health mutation replicated.

Inspection confirms the Tool was created without a handle or visible rifle,
and health appeared only as a small number embedded in RoundHUD; neither
addresses the user's feedback. The tracer was a short-lived line from the
server character head to its resolved endpoint, while the reticle came from
the camera. This parallax may explain a visual difference, but the prior
camera-ray check did not establish the tracer's screen projection, and the
user's reported high shots are not yet reproduced. The user's round ended
before a tracer capture. The observed `GroundShot` attribute also remained
present in Lobby after health reset, though it cleared on the next round ID or
runtime stop. Visible rifle, unambiguous server-confirmed hit/health feedback,
aim/tracer behavior and reset clearing require correction and fresh tests.
The actual Server `EndTest` closed the session after capture; the sole Studio
document returned to Edit with selectors nil.

Candidate `6613375` makes the 15 visible authored aircraft parts queryable,
while keeping them anchored, noncolliding and nontouching and retaining the
canonical Hitbox as primary. The M-7 server ray continues along the intended
direction to its validated bounded range and still resolves the first actual
solid, including level cover. The resolved terminal tracer was enlarged to
50 studs long / 0.4 studs thick / 0.4 seconds; accepted shots flash the
reticle, confirmed aircraft hits display `AIRCRAFT HIT −5` for 1.2 seconds,
and aircraft health moved out of the center aiming area. New Studio fixtures
target actual wing/tail/fin/engine surfaces and preserve cover assertions.
The developer's full host gate passed 50 unit / 43 integration; real engine,
camera regressions and user perception remain unverified on this source. These
changes are a candidate response, not proof that the user's aim or feedback
concerns have been resolved.

The user launched the manual two-client P06 run on `6613375`. All 10/10
cases passed, server smoke passed 118/118 (one client present at its sampling)
and each client passed 6/6. The [actual report](p06-manual-661.json) records
an intended direction point only three studs away still stopping at solid cover
without damage, followed by an exposed direction point hitting the visible
aircraft Wing and health decreasing 300→295; tracer endpoint checks passed.
The forfeit case server-kicked the operator, and the tester then ended the
session and cleared the selector. Current-source user perception and P05/P14
regression remain outstanding.

The user reviewed `6613375` and reported the visible rifle still produced no
visible bullets toward the plane, a thick nearby laser-like streak toward
ground, and no apparent aircraft damage. Read-only [live samples](p06-user-661.json)
showed health still 300 at sampled sequence 116 with the latest shot marked
`aircraftHit=false`; current post-shot camera/plane samples could not establish
the shot-time aiming cause. The [actual Ground capture](p06-presentation/user-661-before.jpg)
preserves the user's build. The terminal-only trace is drawn in the final
50 studs of a 1200-stud miss, so it can be remote from the shooter while a
nearby ground hit produces a large visible segment; that concretely explains
why static terminal presentation can be unreadable, but does not explain all
aimed aircraft misses. A first short same-shot capture observed no new user
requests and returned no valid correlation; it is not evidence for a hit or
aim diagnosis. A subsequent bounded read-only client/server observer was armed
for up to 600 seconds, retaining at most 12 requests and 120 render frames, to
compare an actual user shot's camera target and server collision without
changing gameplay. Its outcome is pending.

Candidate `23e053c` responds to the user review with a server-created primitive
rifle (Handle and welded barrel/stock/magazine), a dedicated replicated-health
HUD, and a shooter-only `HIT −5` indicator driven by server-confirmed aircraft
damage. The authoritative muzzle ray and cover remain unchanged; the visual
tracer now shows a short terminal segment ending at the actual resolved point.
The replicated `GroundShot` is cleared on Resetting and Lobby. The independent
source review confirmed the optional hit indicator is derived from the server
award, player/round identity is checked, the rifle parts are noncolliding and
nonqueryable, and cleanup remains owner-scoped. Full host verification passed
50 unit / 43 integration and fresh Studio smoke passed 118/118 server and 6/6
client cases. The visible rifle grip, both-role health display, shooter-only
indicator and user-reported aim alignment are not yet accepted: a real
two-client and operated review is prepared. In particular, the shorter tracer
is not by itself proof that shots or impacts align with the user's crosshair.

The user reviewed `23e053c` and reported the rifle looked good, ammunition and
reload worked, but bullets were not visible and they perceived no damage. The
independent tester's [read-only samples](p06-user-23e.json) showed at least one
actual hit (300→295), while other sampled shots missed; the difference between
the user's perception and server state is a real feedback problem, not evidence
that damage universally failed. The [actual Ground capture](p06-presentation/user-23e-before.jpg)
shows the health label overlapping the aircraft's upper-center flight path.
The terminal tracer was not captured during the review. The tester could not
reconstruct past shot/reticle alignment from separately timed moving-camera
samples. The user reported a material playability failure; the visible aircraft
geometry, shot presentation, health HUD placement and confirmed-hit feedback
require revision and current-source user review. The tester ended the session
after it returned to Lobby; the original test document remained in Edit.

The manual P06 two-client run on `23e053c` passed all 10 cases, with fresh
server smoke 118/118 and 6/6 on each client. The fixtures exercise the equipped
rifle, replicated health, shooter-only confirmed hit feedback, authoritative
terminal tracer and reset clearing, along with prior combat/round assertions;
the [actual report](p06-manual-23e.json) records the run. Manual P06's forfeit
case uses an actual server-initiated player kick, so the session ended with
one player; the tester closed it and cleared the selector. These assertions do
not prove that the user perceives the gun, health feedback or shot alignment
as usable. A fresh ordinary two-client user review is prepared.
