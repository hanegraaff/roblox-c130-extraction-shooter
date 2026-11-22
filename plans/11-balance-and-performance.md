# P11 — Balance, performance and resilience

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

Draft delivery is tracked in [PR #45](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/45).
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
