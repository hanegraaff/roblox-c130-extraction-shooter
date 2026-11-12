# P06 ground combat verification

P06 is in progress on its dedicated branch. This record distinguishes actual
engine runs, source-specific host tests, identified defects and unrun checks.

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
