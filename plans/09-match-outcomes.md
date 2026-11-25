# P09 — Complete team win/loss and replay loop

**Milestone:** M5. **Dependencies:** P08, P17. **Requirements:** R03, R04, R08, R10, R11, R13, R15. Status: [roadmap](../roadmap.md).

D63 places P09 after the approved smaller-Outpost integration. This plan uses the P08 launcher and the P17 Outpost source integrated on `main`. The full round loop exercises the resulting building and its destruction and reset behavior.

## Capability and player experience

Play a complete match: the ground team destroys the C-130, or the C-130 eliminates all ground players or survives the clock. Each outcome leads to a clear team result and a clean next round, including when players leave or destruction happens at a timing boundary.

## Implementation

Integrate and harden the existing MatchService result boundary across both aircraft weapons, M-7, launcher ownership and aircraft health. Follow the documented server order: deadline first; pre-impact damage batch; aircraft destruction before same-step ground elimination; then departure/forfeit handling and launcher interactions if still Active. Record a single result reason and attribution, freeze terminal state, and reset all combat/world/controller resources. No new collection or escape subsystem is needed.

## Acceptance criteria

- **A1:** Full gate passes. Outcome tests cover plane destruction, all-ground elimination, timeout and operator forfeit, awarding one correct team result. No client win claim or late callback can change it.
- **A2:** A lethal rocket strictly before deadline can win; at or after deadline C-130 wins. Same pre-deadline step aircraft/last-player destruction yields GroundWin under the documented tie default. A result committed in an earlier step is never reversed.
- **A3:** A projectile can resolve after shooter death while teammates keep the round active; if the round has already ended it cannot award damage/victory. Repeated impacts/results cannot double-count destruction or team credit.
- **A4:** Operator departure, last-ground departure, simultaneous departures, empty server and invalid deployment follow the design in supported Studio scenarios. Deterministic service tests verify reconnect policy; actual same-identity reconnect is excluded under D59. Forfeit/abort reasons remain distinct from physical aircraft destruction; launcher ownership cannot strand or duplicate on departure.
- **A5:** Automated Studio scenarios complete ground plane-destruction, C-130 elimination and timeout paths, and show the same result/reason to all clients. Verify all ground players are one team and friendly fire remains off.
- **A6:** Three full back-to-back rounds restore one launcher, rifles, aircraft health/orbit, both weapon cooldowns/zoom, cover, cameras and connections. Stale requests/projectiles cannot cross round IDs.

## Focused human check

Play lobby → fight → plane destroyed → results → lobby, then elimination and timeout losses. Inspect who won, why, camera/result cleanup and equipment on replay.

## Documentation changes

Rewrite the README around the complete implemented players-versus-C-130 loop. Document timing/forfeit contracts and runnable end-to-end scenarios without adding a feature-by-feature history.

## Completion record

### Candidate and verification

The tested candidate is `a1b0af0b27bffbe028ba388725829c60dca4c9ff`, tree
`8f6ed749d576f70c9e77a30aea77feb80de4315c`. It uses the same production and
asset bytes as `42c806639a311c2d72d6b3c06ccac9ca638f7f6e`. The last source
revision adds the P09 fixture's all-client startup barrier and smoke-report
retention. A Rojo build and an Edit audit compared SHA-256 for all 144 mapped
script sources in the existing local `tests.rbxlx` document. Roblox Studio
was `0.748.0.7481526`. [Build hashes and Studio identity](../docs/evidence/p09/source-a1b0af0.json)

`python3 scripts/verify.py` passed on Darwin arm64 with Python 3.10.4. It ran
66 unit, 73 service integration, 15 tooling and 48 asset regression cases.
Formatting, lint, strict Roblox types, expected rejection probes, asset
reconstruction, geometry and release/test isolation passed. The test artifact
contains 5,403 Instances. The release artifact contains 5,301 Instances and
53 runtime scripts. The corresponding GitHub Verify run passed on the tested
source. [GitHub Verify #413](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/44819061089)

Use the [P09 match outcome harness](../docs/testing.md#run-the-p09-match-outcome-harness)
to reproduce the SDK runs with `{ kind = "P09", scenario = "…" }` in
`StudioTestService:ExecuteMultiplayerTestAsync`. Successful sessions carry
191 passing server smoke cases and 12 passing cases from each initial actual
client, with zero errors, failures or skips. The shortened match fixtures used
seed 1, the current 720-stud battlefield and real production combat remotes.

| Criterion | Evidence and observed result |
| --- | --- |
| A1 | Full host gate passed. The `MatchService` service cases cover timeout, precedence, immutable results and replay. `Outcomes` and `Departures` observed the three competitive endings and operator forfeit. A real client win claim through the surrender remote was rejected. |
| A2 | Native `MatchOutcome.spec.luau` ran three real spherecast cases with an injected clock. A lethal rocket before expiry beat a same-step last-ground death. At equality and after expiry, rocket damage was skipped and timeout won. The `earlier total ground elimination` service case verifies that a later rocket cannot reverse it. |
| A3 | In `Outcomes`, three actual rockets destroyed the plane after the carrier died during the lethal flight, while a teammate stayed alive. All clients agreed on the one terminal result and the server retained `rocket:1:3` and the carrier as credit. The later-elimination round canceled an in-flight rocket. The native deadline fixture and service cases reject duplicate or terminal impacts and result proposals. |
| A4 | `Departures` passed 2/2 with three actual initial clients and one remaining. It recovered one launcher after carrier disconnect and awarded Ground `OperatorForfeit`, leaving aircraft health at 300. `LastGround` passed 3/3 with two actual initial clients and one remaining. Raw model removal with both clients connected yielded `GroundEliminated`. A subsequent real disconnect yielded `GroundDeparted`. `Empty` passed 2/2 with two actual clients and grouped server kicks. Both players left and the server recorded `EmptyServer` with no winner. `Outcomes` verified `CharacterIncomplete` with no winner for an invalid deployment. The service suite covers same-identity reconnect authority under D59. |
| A5 | `Outcomes` passed 5/5 with three actual clients. All three agreed on `AircraftDestroyed`, `GroundEliminated`, `Timeout` and the invalid-deployment abort. The two Ground players shared one team. The teammate-directed M-7 shot consumed one round and caused zero friendly damage. |
| A6 | The same `Outcomes` session ran three competitive rounds, restoring one launcher, rifle magazine and reserve, aircraft health and orbit, both gunship weapon cooldowns and zoom, actual Outpost Light damage, role cameras and baseline connections. Old-round remotes and projectiles could not affect the next round. The P07 shared-runtime regression passed 7/7 with two actual clients on `42c8066`, including physical openings, Humanoid traversal, fragment expiry and two resets during live fragments and pending work. |

[Outcomes](../docs/evidence/p09/outcomes-a1b0af0.json),
[departures](../docs/evidence/p09/departures-a1b0af0.json),
[last-ground removal and departure](../docs/evidence/p09/last-ground-a1b0af0.json),
[empty server](../docs/evidence/p09/empty-a1b0af0.json),
[P07 physical-cover regression](../docs/evidence/p09/p07-physical-cover-42c8066.json),
[P07 smoke](../docs/evidence/p09/p07-physical-cover-smoke-42c8066.json).

### Independent findings and retest

Studio exposed a departure-attribution error in the initial source. Both the
last-ground disconnect and two-client departure settled as `GroundEliminated`.
The corrected owner keeps the character-removal fact until the outcome step,
distinguishing a same-step player departure from confirmed death or an owned
model loss. Deployment still cancels when the roster leaves and aborts when a
character goes missing with its player connected. [Initial last-ground failure](../docs/evidence/p09/last-ground-failed-a8d6eef.json),
[initial empty-server failure](../docs/evidence/p09/empty-failed-a8d6eef.json)

The initial correction exposed a separate fixture race. The server began
deployment before both client smoke suites finished, so the ready-character
layout test failed on each client. The P09 fixture now waits in Lobby for every
initial client's passing smoke report before changing characters. The first
corrected Empty launch timed out with one of two requested clients. The later
two-client run passed. [Failed fixture run](../docs/evidence/p09/last-ground-fixture-failed-42c8066.json),
[failed client smoke](../docs/evidence/p09/last-ground-smoke-failed-42c8066.json),
[one-client startup](../docs/evidence/p09/empty-startup-failed-a1b0af0.json)

The independent tester found stale launcher text on the rendered timeout HUD.
The foundation panel now describes the one available map launcher and the client
smoke suite asserts that copy. [Earlier HUD capture](../docs/evidence/p09/timeout-hud-before-fix-a8d6eef.jpg)

### Operated player review

An ordinary two-client Studio session used the test panel to start rounds.
In the Ground win, the actual Humanoid moved from shelter to the center by
MCP navigation. Native E picked up the launcher, native 2 equipped it, and
three native mouse shots moved aircraft health from 300 to 200 to 100 to 0.
The tester temporarily positioned the local camera to help lead the moving
aircraft. Ground `AircraftDestroyed` appeared on the HUD, followed by the
terminal overview and a fresh local-character camera, empty equipment and
pristine aircraft in Lobby. The revised launcher text was readable at
1081×618 with Automatic graphics.

The operated C-130 then switched to the 105mm at 40° using native 2, panned
with W and eliminated the Ground player by firing through the ordinary
thermal view. The HUD showed `GroundEliminated` and replay restored camera
and equipment. The third round used the 30-second test-panel setting and
ended in `Timeout`. Both clients displayed the correct reason and returned
to their local Custom cameras with empty equipment and aircraft health 300.
The centered result stayed legible at 1081×618 and 1153×618 with Automatic
graphics. Default team chat overlaps the older top-left status panel when
open. The independent review found every required scenario verified and
returned Studio to the original stopped local Edit document with its
temporary attributes cleared. [Operated trace](../docs/evidence/p09/operated-review-a1b0af0.json),
[timeout HUD](../docs/evidence/p09/timeout-hud-a1b0af0.jpg),
[Edit cleanup](../docs/evidence/p09/edit-cleanup-a1b0af0.json)

The technical writer updated the complete match guide, local build and play
steps, and timing and departure contracts. The root README retains the
selected P16 Blender authoring image. `python3 scripts/check_repository.py`
and `git diff --check` passed after the documentation and evidence changes.

### Delivery

[PR #41](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/41)
targets `main` from `plan/09-match-outcomes`.
