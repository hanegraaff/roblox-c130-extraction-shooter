# P11 — Balance, performance and resilience

> Current-rule revision: [P18](18-game-rebalancing.md), requested 2026-11-23, supersedes prior health/three-rocket, panel-durability and circular camera-bound assumptions and adds the Seedship launcher. This plan's recorded tests remain historical evidence for their identified source. Future release checks must use P18's revised rules.

**Milestone:** M6. **Dependencies:** P10. **Requirements:** R03, R05–R14, R15, R16. Status: [roadmap](../roadmap.md).

## Capability and player experience

Repeated rounds remain responsive and clean. The gunship has threatening firepower while ground players have readable cover, effective counterfire, viable routes to the launcher and enough time to threaten the plane. This validates the existing game rather than adding content systems.

## Implementation

Create deterministic combat/soak fixtures and bounded diagnostics for request rates, projectile/effect counts, cleanup and frame/memory metrics. Record reference desktop, resolution, graphics setting and sampling procedure before profiling. Tune only named configuration values with written reasons. Preserve three direct rockets from full health, positive M-7 chip damage, one launcher, two weapon-linked zoom profiles with WASD and directional touch panning and separate mouse aim, the 720-stud diameter and three multi-story buildings, and the selected panel thresholds (3 + 3 heavy hits and nine seconds of sustained 30mm fire to damage a panel). Tune cadence, gaps and fragment caps only while preserving those rules. Optimize demonstrated bottlenecks and revise architecture and testing before introducing streaming.

## Acceptance criteria

D63 schedules [P17's smaller-Outpost replacement](17-integrate-military-outpost.md)
before this plan. Profile its actual imported art, material-specific variants
and fragment workload against the same budgets. A previous primitive building
measurement cannot establish the replacement's performance.

- **A1:** Full gate and all prior required engine scenarios pass on the final candidate. Load/replay/flood tests cannot exceed configured queues or duplicate authoritative effects.
- **A2:** Five accelerated rounds return owned temporary instances/connections to baseline with no stale state. A 30-minute soak meets the ≤10% retained-memory growth criterion in `docs/testing.md`.
- **A3:** The scripted workload meets p95 client ≤33.3 ms and server ≤16.7 ms targets on the recorded environment. Report actual client count and metrics; ten fake roster entries are not a ten-client benchmark.
- **A4:** A measured/simulated near-150 ms RTT scenario converges to correct health/launcher-ownership/selected-weapon/result state without duplicate damage or pickups. Timeouts fail clearly rather than hanging.
- **A5:** Record multiplayer balance observations at the available supported local client count, including launcher acquisition/recovery, time to destroy the aircraft, use of both gunship weapons, cover/counterfire and role engagement. Include enlarged-map travel/launcher-access times, upper-floor counterplay, pan reach at both zooms, mixed-weapon panel exposure and fragment-physics load. Every tuning change preserves rule invariants and has rerun relevant tests.

## Focused human check

Review whether each role has useful choices. Use playtest observations to identify obvious imbalance; do not declare a statistically reliable win rate. Real 6/10-player cloud validation is the P12 gate, even if local tests pass.

## Documentation changes

Record metrics, hardware/settings, tuning rationale and known limits in the plan evidence. Update public claims only to match measured results.

## Local performance reference

The reference machine for this increment is a MacBook Pro (`MacBookPro18,3`,
Apple M1 Pro, 16 GiB RAM) running macOS 26.6.2 (`25G83`) and Roblox Studio
`0.748.0.7481526`. Use the separate local `PlayersVsC130Tests` place with the
imported Outpost and two actual clients, one for each role. Run the five-minute
profile at a verified 1920×1080 viewport per client and fixed graphics
quality 8 of 10. The initial preflight reached 1920×1080 on both SDK clients at
level 8 and Studio rejected attempts to apply the original level 5 reference.
Set the observed higher level as the reference before collecting frame samples.
Record the actual setup and client count for each run.

Measure client render intervals, server scheduler time (`Stats.HeartbeatTime`)
and server frame intervals over the same workload. Record p95, sample counts
and elapsed time alongside the concurrent combat resource peaks. For the
30-minute soak, compare the same reset point
after warmup and after each sampled round, with engine memory separate from
game-owned resource counts. Run the near-150 ms round-trip check separately
from the unshaped profile and record the applied delays and measured ping.

## Completion record

Delivery is tracked in [PR #45](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/45).
The fixture seed is `11021`. Weapon, timing, camera and destruction settings
retain their existing values during this increment.

### Initial candidate and independent findings

- `4152ed2a81d73a7637a9ef44afed77481e491627` (tree
  `a79e9fb185e7672824aa53bc48a2e8a4a7aa118c`) passed
  `python3 scripts/verify.py` on macOS arm64 with 82 unit, 73 integration,
  15 tooling and 48 asset regression cases, both builds and artifact
  isolation. The independent tester reproduced the exact-source unit and
  integration counts with Lune 0.11.1.
- `ExecuteMultiplayerTestAsync(2, {kind = "P11", scenario = "Replay", clients = 2})`
  passed seven of eight cases with two actual clients, 191 server smoke
  cases and 13 smoke cases per client. The first four replays and shutdown
  passed. The fifth replay sampled 15 instead of 23 connections while two
  replacement avatar loads were active. `7afeba4` waits for fresh, live
  lobby characters and no active loads before asserting exact resource counts.
  [Initial replay report](../docs/evidence/p11/4152ed2-replay.json)
- The first Latency attempt configured 65 ms each way with zero jitter or
  loss. The sole connected client's Studio Ping samples were 133–135 ms.
  The SDK timed out with one actual client and no passing scenario. The
  six original network settings were restored. [Initial latency report](../docs/evidence/p11/4152ed2-latency.json)
- `python3 scripts/build_studio_world_probe.py` and the fresh binary probe
  in Studio Edit passed five of five native world-load cases on the same
  source. The probe verified 434 nodes and 403 parts, the eight hills, two
  perturbed rebuilds and cleanup. [Fresh world report](../docs/evidence/p11/fresh-native-world.json)

### Revised candidate checks

- The full host gate passed on `62fd4d2b78dd2cdf2a5c3fe66c74ae659b3afe66`
  (tree `0b3819f70eb2c3e0c3c647e7f9e35709d998893e`) with 82 unit,
  74 integration, 15 tooling and 48 asset cases. Both Rojo builds passed
  artifact isolation and all 2,804 authored transform checks per build.
  The additional structural test fills the 512-outcome window and its
  513 interruption boundaries, then verifies overflow/replay rejection,
  ordered drain and pristine reset.
- Independent Replay on `7afeba47df6e73b507faba2ea9de3cb29c28fe0a`
  (tree `447f11e160f41b8a7804c752cab63ffcb589a06c`) passed eight of
  eight cases with two actual clients, 192 server smoke cases and 13 smoke
  cases per client. All five rounds restored 188 pristine panels and 23
  owned runtime connections in Lobby. Rifle and launcher queues peaked at
  1 and 8 respectively, each below its 32-entry bound. Duplicated input
  caused one launcher pickup, one rifle hit (300→295 aircraft health),
  and one heavy-cannon panel credit per round. No active flights, effects,
  temporary tools, debris, barriers or load tasks remained at the reset
  checkpoint. The later host commit formats the structural test and
  refreshes the P17 source binding. Its P11 runtime/harness source bytes
  match this independent replay. [Revised replay report](../docs/evidence/p11/7afeba4-replay.json)
- The initial Profile preflight on `7afeba4` completed three of four cases with
  two actual clients. Both rendered at 1920×1080. Studio reported quality level
  8 and the setter for level 5 raised a native exception. The preflight stopped
  before the five-minute sample, so the frame budgets were unmeasured in this
  invocation. [Initial profiling preflight](../docs/evidence/p11/7afeba4-profile-preflight.json)
- `60467f620154fc39adcb7b854f6c5c6511682add` (tree
  `d85f80fa59ae7e4f3825bf59dba2b8b815f2fa1b`) sets the Profile reference to
  graphics quality 8 and passed the full host gate at the same counts. Only
  the Profile setting, its error text and the generated test-source binding
  changed. Production, Replay and Soak inputs used by their active code paths
  match their recorded candidates.

### Retained-memory soak

`ExecuteMultiplayerTestAsync(2, {kind = "P11", scenario = "Soak", clients = 2})`
passed four of four cases on `62fd4d2` with two actual clients and clean
192-server/13-per-client smoke reports. The SDK session took 2,242.53 seconds.
Ten loaded cycles after warmup totaled 1,800.47 seconds. Each cycle exercised
both gunship weapons, M-7 fire, rockets and imported Outpost damage. The ten
measured cycles accepted 4,947 30mm shots, 200 105mm shots, 1,500 rifle
shots and 430 rockets. Every measured round opened at least two Outpost
panels and produced four concurrent physical imported fragments. Each reset
restored the runtime resource baseline before memory collection.

| Studio process | Samples | Post-warmup MB | Last reset MB | Retained growth |
| --- | ---: | ---: | ---: | ---: |
| Server | 11 | 2583.13 | 2625.61 | 1.64% |
| Client `-1` | 11 | 2758.64 | 2795.25 | 1.33% |
| Client `-2` | 11 | 2746.97 | 2819.75 | 2.65% |

Each series stayed below 10% endpoint growth and declined at least once.
These are process-level engine readings. The separately counted game-owned
connections, temporary Instances and queues returned to baseline after each
round. The independent tester verified shutdown and return to Edit.
[Soak report](../docs/evidence/p11/62fd4d2-soak.json)

### Initial five-minute frame profile

`ExecuteMultiplayerTestAsync(2, {kind = "P11", scenario = "Profile", clients = 2})`
completed the workload on `60467f6` and passed three of four cases. Both actual
clients held 1920×1080 at quality level 8, with Studio renderer level 17 and
automatic frame-rate management. The workload ran for 300.0009 seconds and
accepted 799 30mm, 32 105mm, 150 rifle and 71 rocket shots. Six Outpost
panels opened. Peaks included four imported fragments, five gunship
projectiles, two rocket flights and eleven gunship effect Instances.

| Measurement | Valid samples | p95 | Target |
| --- | ---: | ---: | ---: |
| Gunship client render intervals | 4615 | 67.7 ms | ≤33.3 ms |
| Ground client render intervals | 6653 | 67.5 ms | ≤33.3 ms |
| Server scheduler (`Stats.HeartbeatTime`) | 17629 | 0.6 ms | ≤16.7 ms |
| Server Heartbeat intervals | 17629 | 17.5 ms | Diagnostic |

The two client intervals exceeded the budget. Four live samples per client
showed 1.7–3.4 ms reported CPU render time and near-zero reported GPU render
time alongside 52.6–67.1 ms frame intervals. This suggests Studio frame
pacing deserves investigation. A separate seven-second check reproduced about
67 ms p95 with roughly 2 ms CPU render work. macOS accepted the activation
request but retained the prior foreground application, and the observed
Gunship input remained blocked. The focus experiment could not isolate the
cause. Shutdown passed and the original settings and Edit document were
verified. [Full profile report](../docs/evidence/p11/60467f6-profile.json), [focus check](../docs/evidence/p11/60467f6-operated-review.json)

### Two-client latency convergence

`ExecuteMultiplayerTestAsync(2, {kind = "P11", scenario = "Latency", clients = 2})`
passed all five cases on `60467f6`, with clean 192-server/13-per-client smoke.
The two actual clients both read back 65 ms inbound and 65 ms outbound, with
zero jitter and loss. Engine Ping was 132.39–134.94 ms, while seven application
echoes per client yielded medians of 166.282 ms and 166.686 ms. Both clients
converged on the same launcher owner, M102 selection, exactly one 300→295
rifle damage award, and one Gunship timeout result. Shutdown passed and the
six original zero network settings were restored.
[Latency verdict and samples](../docs/evidence/p11/60467f6-latency.json)

### Operated balance observations

An ordinary local session on `60467f6` used three actual clients, one
Gunship and two Ground, with clean 192-server/13-per-client smoke. Real
Ground Humanoids walked both painted approaches with `MoveTo`, without
teleporting. The west route took 12.26 seconds and about 196 studs from its
deployment anchor. The east route took 13.51 seconds and about 216 studs
from the neighboring deployment anchor. The east player reached the
pickup first. After a voluntary drop, the west player recovered the same
`launcher:1`. Three real projectile hits used controlled moving-target aim
from the center and produced 300→200→100→0 in 9.72 seconds from the first
fire request. This measures the shot sequence from ready equipment. The
actual round took about 137 seconds to reach zero health, including pauses
to coordinate test commands.

In the second round, a Ground player reached the upper Outpost room in
18.0 seconds from deployment. All eight sampled room rays hit a solid
wall. On the balcony, 21 of 48 sampled orbit positions offered a clear
line. An actual M-7 shot when the aircraft entered that opening chipped
health from 300 to 295. This illustrates the tradeoff between protection
and an exposed firing opportunity. Both operator weapon selections
produced their expected 30° and 40° FOVs. Native background input was
blocked, so this run did not compare actual pan reach. The scripted profile
and soak separately exercised both gunship weapons, observed real Outpost
openings and measured concurrent material-fragment load. The local
observations cannot establish population-scale balance. [Operated report](../docs/evidence/p11/60467f6-operated-review.json)

### Prior engine regressions

The source-bound Edit audit compared 159 mapped Luau sources to the `60467f6`
test artifact with identical classes and SHA-256 digests at every path. The
following suites passed on that source. [Initial native regression records](../docs/evidence/p11/prior-regressions.json)

| Suite | Actual clients | Passed |
| --- | ---: | ---: |
| Lobby Controls, Human Test Controls | 1 each | 4/4 and 6/6 |
| Human Test Multiplayer | 2 | 4/4 |
| P04 aircraft, P05 gunship | 2 each | 6/6 and 8/8 |
| P06 ground, P07 destruction | 2 each | 10/10 and 7/7 |
| P08 launcher | 3 initial | 11/11 |
| P09 Outcomes and Departures | 3 initial each | 5/5 and 2/2 |
| P09 LastGround and Empty | 2 initial each | 3/3 and 2/2 |

- P06Team initially saw aircraft damage before it sent the exposed shot.
  The fixture removed the wall after ammunition admission and before the
  corresponding ray resolved. `3623b77` checks the resolved numbered shot
  while the wall remains installed, then checks the Wing collision and
  teammate overlap on the second resolved shot. Independent rechecks passed
  10/10 on two actual clients and 7/7 on three. [P06 recheck](../docs/evidence/p11/3623b77-P06-recheck.json), [P06Team recheck](../docs/evidence/p11/3623b77-P06Team-recheck.json)
- P14's first SDK launch had one actual client and timed out before
  deployment. The two-client retry passed full 90-second projections at
  each FOV, pan preservation, ground-camera isolation, blocked-input and
  recenter checks, thermal occlusion and resource teardown. The old role-loss
  assertion expected `Custom` during P10's deliberate Results overview.
  `3623b77` checks the neutral Results camera and thermal teardown, then
  checks that Lobby restores the player's own Humanoid and `Custom` view.
  The independent recheck on `074def6` passed 6/6 with two actual clients
  and 192-server/13-per-client smoke. Both full orbits and both camera
  transitions passed after abort and actual operator departure.
  [P14 recheck](../docs/evidence/p11/074def6-P14-recheck.json)
- P13's first two-client run rejected the legitimate repeated `Solid` names
  under separately identified building panels. `074def6` compares stable
  Battlefield-relative paths, retains exact duplicate rejection and
  numerical tolerances, and keeps the actual third-client check.
  The recheck passed geometry agreement, upper-floor traversal, two
  perturbed resets and teardown. A third actual client arrived during
  Active as a characterless spectator and failed its startup layout fixture.
  [P13 recheck](../docs/evidence/p11/074def6-P13-recheck.json), [late-client error](../docs/evidence/p11/P13-late-client-error.txt)
- P03 reached four actual clients and verified server-side spectator state.
  The fourth client's `GroundAimGui` fixture required an actual character
  even though the server correctly left that spectator characterless. The
  failed startup smoke suite prevented its harness acknowledgement.
  [P03 late-client error](../docs/evidence/p11/P03-late-client-error.txt)
- P10 requested four actual clients and timed out with three before gameplay.
- The managed P17 suite passed 10/10 on `074def6` with two actual clients,
  192 server smoke cases and 13 per client. The local SDK invocation used
  the existing P17 manual selector. Both clients verified loaded meshes,
  Outpost traversal, and all six material damage families through the actual
  openings and two resets. The runner reported complete owned cleanup. The
  original Edit document's temporary selector and report attributes were
  cleared after collecting the 12-chunk archive.
  [Managed Outpost suite](../docs/evidence/p11/074def6-P17-report.json)

`3a09d68` corrects the shared client layout fixture used at P03 and P13
startup. A characterless client now performs the same M-7 and launcher layout
assertions using an inert Model under its local PlayerScripts. The fixture
removes the temporary local reference and restores the camera. The actual
late-join role and no-avatar assertions remain in each native harness.

The fixture corrections change earlier suite setup and observations. The
P11 runtime, workload and sampling source remain byte-identical to `60467f6`
across those corrections. The full `python3 scripts/verify.py` gate passed
on `074def6e61f7ae6054c918ae58f303adbc3cbf6b` (tree
`dde25ec3e99394b07606e9b9377331393e2be93e`) with the same 82 unit, 74
integration, 15 tooling, 48 asset and 2,804-per-artifact transform counts.
The release artifact retains SHA-256
`266c2322717eebc081b110eba391cde626edb65bcbe245dc4a25404b70022cf7`.
The corresponding test artifact hashes to
`5e98407f5473a04c8d88e43977b099543c0001aa7bb15eb0df854c6dd46674d2`.
The writer reviewed the player README and mapping descriptions and provided
exact SDK and native procedures in the [testing guide](../docs/testing.md#run-the-p11-performance-harness).

The full host gate also passed on `3a09d68b8f435d0e2dd08d5b5817e1256cb228c2`
(tree `2f99292b5cf0b0e24163d29c3ef6afa9444a557a`) at the same counts. The
release artifact retains the same hash. The updated test build hashes to
`55f494bb04e6ac0570fe8da97fe7a8ac5e8b02690b509a58d8737481762365a2`.
[GitHub Verify #449](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/45062411282)

The first P03 recheck requested three clients and stopped at two actual
clients before deployment. The staged SDK retry stalled when its server
child opened Studio sign-in instead of the test DataModel. The original
document remained in Edit with the test selector cleared and the launcher
continued waiting for that child until Studio was restarted.
[P03 launch report](../docs/evidence/p11/3a09d68-P03-startup-failure.json),
[staged launch report](../docs/evidence/p11/3a09d68-P03-staged-startup-failure.json)

After the restart, the same test artifact passed all five P13 cases with
two initial clients and one actual late join. The late player stayed a
characterless spectator during the third active round and confirmed
geometry, terrain and aircraft replication. The server passed 192 smoke
cases and all three clients passed 13 each. Short frame snapshots from
both active roles at default viewports still showed multi-client Studio
intervals around 67 ms during this recheck.
[P13 restart evidence](../docs/evidence/p11/3a09d68-P13-after-restart.json)

The P03 retry after the restart reached all three initial clients. The
PointerGui button hit-test assertion failed in one client and GroundAimGui
could not find the production `RifleStatus` item in another. The server
timed out waiting for the client harnesses before the late-join step and
reported zero of two cases passing.
[P03 restart evidence](../docs/evidence/p11/3a09d68-P03-after-restart.json)

The P10 staged retry passed all eight cases on the same artifact. The
tester started three actual clients and added one through Studio's supported
`AddPlayers(1)` before gameplay. All four clients passed 13 smoke cases each,
and the server passed 192. The roster stayed at four through gameplay and
the runtime teardown passed.
[P10 staged restart evidence](../docs/evidence/p11/3a09d68-P10-after-restart-staged.json)

The test-only follow-up `f653142` sets `ResetOnSpawn` to `false` for the
PointerGui and GroundAimGui fixtures, matching the production HUD during
character loading. The pointer check waits for the real button in Studio's
hit map and then verifies both production input adapters in that frame.
P17's generated fixture fingerprint records the new spec hashes.
`python3 scripts/verify.py` passed on macOS arm64 with 82 unit, 74
integration, 15 tooling and 48 asset cases, both Rojo builds and test-place
isolation. The local test build SHA-256 was
`61e992339530e75b4a8e1b1a3b521c77ca53fa1adabf528f84b4bb418e5db802`.

The tester verified the changed fixture hashes in the Rojo-synced Edit
document. P03 passed all nine cases across rounds 1–3 at peak four actual
clients. The late fourth client passed 13 smoke cases and reported the
same characterless spectator state as the server. The server passed 192
smoke cases. The original document returned to Edit after teardown.
[P03 passing recheck](../docs/evidence/p11/f653142-P03-persistent-fixtures.json)

### Passing five-minute frame profile after restart

During the P03 recheck, actual clients reported short intervals of about
16.6–18.1 ms. The tester repeated the full profile on Rojo-bound `f653142`
with two actual clients at the same 1920×1080 resolution, graphics level 8,
automatic frame-rate management and zero artificial network delay.
`ExecuteMultiplayerTestAsync(2, {kind = "P11", scenario = "Profile", clients = 2})`
passed all four cases, including loaded profiling and complete runtime
teardown. Both clients kept the pinned settings throughout sampling.

| Measurement | Valid samples | p95 | Target |
| --- | ---: | ---: | ---: |
| Gunship client render intervals | 17,928 | 18.1 ms | ≤33.3 ms |
| Ground client render intervals | 17,890 | 18.3 ms | ≤33.3 ms |
| Server scheduler (`Stats.HeartbeatTime`) | 17,905 | 0.6 ms | ≤16.7 ms |
| Server Heartbeat intervals | 17,905 | 17.9 ms | Diagnostic |

The 300.021-second workload accepted 798 GAU-23 shots, 32 M102 shots, 150
M-7 shots and 71 rockets. It opened five imported Outpost panels and
observed four concurrent imported fragments. All four series had zero
invalid samples. Early and mid-load snapshots for both roles were near
16–18 ms. The cause of the initial slower frame pacing remains undetermined.
The tester restored the original Edit session and its simulator and graphics
settings. The delivery follow-up derives both profile failure messages from
the pinned settings to correct the stale level-5 text.
[Passing profile report](../docs/evidence/p11/f653142-P11-profile-after-restart.json)

| Criterion | Evidence on this branch | Verdict |
| --- | --- | --- |
| A1 | Full host gate, replay floods and ordered queue bounds, fresh world reconstruction, and the prior-engine suite reports above | Pass |
| A2 | Five accelerated rounds and 30 loaded minutes after warmup, with both actual clients returning to baseline and all process growth below 3% | Pass |
| A3 | Five loaded minutes with both roles at 1920×1080 and quality 8. Client p95 18.1 ms and 18.3 ms, server scheduler p95 0.6 ms | Pass |
| A4 | Both clients agree on single damage, pickup, selection and result under measured 166.3 ms and 166.7 ms median application round trips | Pass |
| A5 | Three-client route and combat observations, both FOV coverage in P14, and measured imported Outpost exposure and fragment loads | Pass |
