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

Planning only. Implementation and acceptance checks are unrun.
