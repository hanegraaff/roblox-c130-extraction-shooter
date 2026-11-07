# Testing and acceptance

## What runs today

`python3 scripts/verify.py` validates repository links, JSON, mapped paths, and asset-manifest file references, then builds release and test place artifacts with pinned Rojo. `python3 scripts/check_repository.py` runs only the repository checks. Neither command currently tests gameplay. No gameplay code or game tests exist yet.

Plan 01 turns `verify.py` into the full non-Studio gate and establishes the Studio test runner. Later plans must not invent a new command instead of extending that gate. Tool versions and exact commands become part of the implementation evidence.

## Required test levels

| Level | Purpose | Execution / evidence |
| --- | --- | --- |
| Static | Format, lint, strict Luau types, module boundaries | Pinned tools in local/CI gate; Roblox-aware definitions for engine code |
| Unit | Rules: transitions, timers, damage, ammo, orbit math, placement, dwell | Standalone Luau under Lune; deterministic clock/random inputs |
| Service integration | Real services connected through fakes for transport, clock and world queries | Lune where engine-independent; TestEZ in Studio for Instance-dependent adapters |
| Engine integration | Raycast/cover, Humanoid death, collision swaps, Instances, camera state | TestEZ in the test place, with assertions and a structured pass/fail summary |
| Multiplayer | Replication, roles, input rejection, late joins, visibility, cleanup | Server with two distinct client contexts initially; 6/10 roster fixtures plus real capacity sessions later |
| Experience | Readability, camera feel, sound, balance, fairness | Focused operated playtest and captured observations; supplements automated evidence |

Unit tests use observable invariants and boundary examples, not implementation-specific call order unless order is the contract. Integration tests use real services and fake boundaries, not fake services calling each other. Engine checks assert real world state. A client screenshot cannot establish server authority.

## Determinism and fixtures

- Inject the clock and seed; use a tiny map fixture with one exposed target, one solid wall, one breakable wall, a clear projectile path and an extraction zone.
- Include minimum/maximum population, a two-client development fixture, and seeded 10-player roster data. Ten fake player records do not count as ten network clients.
- Include source/target inside and outside every boundary, exact deadlines, duplicate messages, two pickups in one step, death during extraction, disconnect/reconnect, and a stale projectile after reset.
- Every suite states which requirement it proves, which values are fixtures, and why tolerances exist. Keep random balance tests reproducible by printing their seed.
- Avoid real-time sleeps in rule tests. Engine tests may wait for bounded replication/physics conditions with explicit timeout and useful diagnostics.

## Negative network tests

For each mutating action, exercise malformed payloads, NaN/infinity, oversized data, unknown weapon/item IDs, unowned equipment, wrong role, spectator/eliminated state, excessive rate, stale round ID, repeated sequence, impossible range/origin and blocked line of sight. Assert rejection **and unchanged ammo/health/objective/result state**. Valid traffic must still succeed after a rejected request.

Character movement is client-simulated in normal Roblox play. Include implausible travel/teleport requests around pickup and extraction; an authoritative proximity check alone does not prove a movement exploit is prevented.

## Studio execution and evidence

P01 must provide an explicit server runner and client runner in `test.project.json`, excluded from `default.project.json`. Run through the available Studio integration if connected; discover its actual capabilities before using it. Otherwise use documented Studio steps and a human-assisted run. Do not claim that Lune or a generated place simulated a real server.

Record for each required run:

1. Plan and tested source commit/tree, Studio version, test-place build, seed, map fixture and client count.
2. Suite names with discovered/passed/failed/skipped counts and useful output/log location.
3. Which assertions ran on the server versus each client; replication deadlines where relevant.
4. Reproduction steps and evidence for experience observations, including viewport and graphics settings.
5. Failures, limitations and whether the tested source changed afterward.

Keep concise text evidence under `docs/evidence/`; keep large logs/captures as linked CI artifacts or bounded repository assets. Never fabricate screenshots, live client counts or an experience URL. If a required engine check cannot run, finish independent work but leave the plan In progress or Blocked with the concrete missing access/evidence.

## Objective release budgets

These are initial engineering targets; P11 records a named reference desktop before measuring. Changing a budget needs a reason in the plan, not a quieter test.

- Test at 1920×1080 with a recorded graphics quality. Target client frame time p95 ≤33.3 ms for both roles during a scripted five-minute combat workload.
- Target server frame time p95 ≤16.7 ms for the same workload. Record the sampling method, active clients, projectile/cover/effect counts and Studio/cloud environment.
- Complete five consecutive accelerated deterministic rounds with no stale damage, objectives, results, listeners or map state. Server-owned temporary instance/connection counts must return to the baseline after each reset.
- Run a 30-minute multiplayer soak. After warmup and equivalent reset points, retained memory growth must be ≤10%, with no monotonic leak; record actual samples and separate engine caches from owned allocations.
- Exercise a controlled latency scenario near 150 ms round-trip, recording actual simulator settings/measurements, and confirm state converges without duplicated damage/rewards.
- Run actual 6-player and 10-player sessions before release. Studio supports up to eight locally simulated clients per current documentation; use an authorized Roblox test experience for the ten-player case. Recheck the platform limit if tooling changes.

Budgets do not promise performance on unspecified hardware. If a target is missed, optimize or record a scoped design decision; do not mark the gate passed.

## Completion evidence template

Each plan already includes a record to fill. List criterion ID → test name/file → command/environment → observed outcome. Include final source commit, CI URL, Studio report, tester findings, documentation review and remaining limitations. Required checks left unrun remain incomplete acceptance criteria.

The [Roblox testing documentation](https://create.roblox.com/docs/studio/testing-modes) is the source for actual Studio modes and simulated-client capabilities.
