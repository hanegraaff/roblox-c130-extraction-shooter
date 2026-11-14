# P09 — Complete team win/loss and replay loop

**Milestone:** M5. **Dependencies:** P08, P17. **Requirements:** R03, R04, R08, R10, R11, R13, R15. Status: [roadmap](../roadmap.md).

The user's D63 sequencing revision places P16 Blender assets and P17 smaller-Outpost integration next, between P07 and P08 in the roadmap. Resume this plan only after the approved replacement is complete, retaining the already completed P08 launcher source and evidence. Exercise the resulting building and its destruction/reset behavior in the full round loop.

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

Not implemented. Record A1–A6, source, each outcome report and complete-loop/replay evidence.
