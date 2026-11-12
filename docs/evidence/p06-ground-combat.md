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
