# P24 — Give Ground players a 20-second head start

**Gameplay iteration.** Builds on P23's lobby flow and P03/P04/P09 round and aircraft ownership. Covers R02–R06, R11–R13. [Roadmap](../roadmap.md) · [Requirements](../requirements.md)

## Player experience

Once the roster has deployed and the Ground players can move, give them **20 seconds** to scatter. Ground sees the battlefield and an on-screen **C-130 arrives in 20** countdown. The operator sees the same remaining seconds on an opaque black screen. At zero, the plane appears on its perimeter orbit, the operator gains the thermal view and both sides can fire. The normal ten-minute combat clock starts at aircraft arrival.

## Implementation

- Give `RoundRules` and `MatchService` an explicit scatter phase between deployment readiness and active combat. Keep avatar loading and its existing failure timeout separate. Lock the roster and aircraft health at deployment. Replicate the round ID, phase and one server deadline through `MatchRuntime`. Derive both displays from server time. A delayed client draws the remaining seconds on first render.
- During scatter, Ground can move, find cover and pick up or drop a launcher under the usual ownership rules. Keep both sides' fire closed at server admission and resolution. Discard early requests so they cannot spend ammunition, start cooldowns, cause damage or fire automatically at reveal. Ground death/reset or departure still consumes the life. Use the existing elimination/departure/forfeit outcomes if a side is lost. A committed ending cancels the reveal and starts P23 intermission.
- Coordinate `AircraftService`, `GameRuntime` and combat queries so the canonical aircraft, its hit surfaces and its effects are absent from player view and targeting throughout deployment and scatter. At the first eligible server step, reveal one aircraft at the canonical orbit start and open combat once. Preserve the Ground positions and equipment earned during scatter. Gate the operator camera, thermal highlights, input and audio until reveal, including between assignment and first HUD paint. The P23 theater prompt becomes available when combat starts.

## Acceptance

| ID | Planned check | Passing observation |
| --- | --- | --- |
| A1 | Extend `RoundRules` and `MatchService` clock tests | Slow avatar loads consume none of the 20 seconds. At 19.999 seconds the round is still in scatter. At 20 seconds a ready round reveals once, with the full combat duration. Repeated steps and old callbacks cannot reveal twice or affect a subsequent round. |
| A2 | Extend aircraft, launcher and combat service/harness tests | Ground moves off spawn and can acquire a launcher. Before reveal neither side can score a hit, spend a round or queue a shot for later. At reveal the same carrier can fire a fresh valid shot at the real plane. Verify a scatter death/reset, operator departure, last Ground departure, late join and normal next-round recovery. |
| A3 | Add a native two-client round-start case and repeat next round | From Ground, watch the countdown while walking and confirm the sky and weapon queries contain no target aircraft. From the operator client, confirm a legible countdown over full black with no battlefield glimpse, thermal targets or usable gun controls. Both switch at the server transition, Ground stays where they scattered and the operator can aim and fire. Repeat with role rotation to catch stale overlays or camera ownership. |

Run `python3 scripts/verify.py` and the affected Studio round, aircraft and combat suites. Inspect countdown placement and the transition on desktop and a touch layout, including visibility while moving. Update the player guide, phase diagram, package contracts and test harness instructions with the delivered sequence.

## Completion record

### Verification on 2026-11-25

The P24 gameplay suite tested `70084b89b99f5c730f50e4fa2155385ba67fc3cf`, tree `d4344ceab98aa9a0dfed6ea4523c47aa7983f181`. The GitHub source commit `e0a7dfadfbb7b0c5a5f19f4a15693e8d51aba619` has the same tree. `python3 scripts/verify.py` passed on macOS arm64 with Python 3.15.2. It ran 85 unit, 85 integration, 26 tooling and 70 asset tests, plus strict analysis, format, lint, expected rejection probes, both Rojo builds, authored geometry and release isolation. The test build SHA-256 is `ee627b3727fc18122b4580f40e4543d000dee06537e8a9f01b0b12711b09a846`. The Studio Edit comparison matched 183 scripts and five authored poses. [PR #72](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/72) · [GitHub Verify #678](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/45640939533)

| Criterion | Observed verification |
| --- | --- |
| A1 | `RoundRules.spec.luau` and `MatchService.spec.luau` cover delayed readiness, 19.999/20.000 seconds, a delayed server step, stale readiness and one reveal with a full combat interval. The native P24 harness observed both actual clients at the same deadlines, a canonical phase-zero arrival and 600 combat seconds twice. |
| A2 | `MatchService.spec.luau` covers a consumed scatter life, protected late join and reconnect, operator forfeit, last Ground departure, terminal elimination and intermission recovery. Native P24 checked movement, launcher pickup/drop/recovery, no early aircraft or fire mutations, retained position and equipment, fresh rocket damage and gunship fire twice. The third scatter ended on actual Ground death with both players returned to protected lobby bodies. |
| A3 | `PlayerPresentation.spec.luau` covers role views and delayed first countdown paint. Native P24 passed 9/9 with two actual clients and rotated roles. It sampled 1,473 pre-arrival operator frames with zero view leaks, early thermal frames or visible aircraft. Operated desktop and iPhone 17 Pro landscape checks verified readable countdowns during Ground movement and the correct view transition. |

The independent tester caught two smoke fixture mismatches, a stale blackout render binding, Ground countdown overlap with native chat and an early camera sample timing defect. The corrected candidate passed the two-client P24 suite with 207 server and 23 per-client smoke cases. The documentation reviewer verified the player and contributor guides, phase and camera contracts and the local test procedure. [Studio evidence and earlier runs](../docs/evidence/p24/studio.md)

P05 passed 9/9 with two actual clients and P18 passed 11/11 with three initial actual clients on `70084b8`. On `6db1823fd151fa3b6cb487c60250f0da6745be2c`, tree `fa615c9783d26b402d7d6dc7cef4f6934b171787`, P04 passed 6/6 with two actual clients and P03 passed 9/9 with three initial and four peak actual clients. P03 exercised a live late join, native theater entry and movement, three resets and actual departures. The two tested trees have identical runtime Luau and P24, P05 and P18 cases. The final full host gate passed again. The release build reproduced SHA-256 `01f3b94197dd0b58be5d41a2de93ff54d1388e92c0786ddbce18ce78f92bd75f` and the rebound test build SHA-256 is `8838895d14ae4329ff42c3d58907f5f806770b62c4f4f7880bbbb3438a8f0a4b`. [Combat and launcher reports](../docs/evidence/p24/studio.md#combat-and-launcher-regressions) · [Orbit and lobby reports](../docs/evidence/p24/studio.md#orbit-and-lobby-regressions) · [GitHub Verify #680](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/45643619932)
