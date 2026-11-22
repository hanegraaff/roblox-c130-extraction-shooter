# P11 — Balance, performance and resilience

**Milestone:** M6. **Dependencies:** P10. **Requirements:** R03, R05–R14, R15, R16. Status: [roadmap](../roadmap.md).

## Capability and player experience

Repeated rounds remain responsive and clean. The gunship has threatening firepower while ground players have readable cover, effective counterfire, viable routes to the launcher and enough time to threaten the plane. This validates the existing game rather than adding content systems.

## Implementation

Create deterministic combat/soak fixtures and bounded diagnostics for request rates, projectile/effect counts, cleanup and frame/memory metrics. Record reference desktop, resolution, graphics setting and sampling procedure before profiling. Tune only named configuration values with written reasons. Preserve three direct rockets from full health, positive M-7 chip damage, one launcher, the two weapon-linked zoom profiles with mouse panning, 720-stud diameter/three multi-story buildings, and selected panel thresholds (3 + 3 heavy hits; nine seconds sustained 30mm to damage). Tune cadence/gaps and fragment caps without silently changing those selected rules. Optimize demonstrated bottlenecks; do not add a framework or enable streaming without evidence and the required architecture/test revision.

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
profile at a verified 1920×1080 viewport per client and fixed graphics quality
5 of 10. Record the observed viewport, graphics settings and actual client
count. Report other settings separately from this reference.

Measure client render intervals and server Heartbeat intervals over the same
workload. Record p95, sample counts and elapsed time alongside the concurrent
combat resource peaks. For the 30-minute soak, compare the same reset point
after warmup and after each sampled round, with engine memory separate from
game-owned resource counts. Run the near-150 ms round-trip check separately
from the unshaped profile and record the applied delays and measured ping.

## Completion record

Not implemented. Record A1–A5, source, workload/seed, metric samples, actual client counts, tuning decisions and any capacity scenario still assigned to P12.
