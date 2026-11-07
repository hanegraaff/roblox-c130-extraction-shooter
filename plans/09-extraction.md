# P09 — Extraction and complete round outcomes

**Milestone:** M5. **Dependencies:** P08. **Requirements:** R03, R04, R11, R13, R15. Status: [roadmap](../roadmap.md).

## Capability and player experience

A ground player can now complete the mission: recover all three objectives, reach the exit, survive the dwell countdown and escape. The server awards a single result and resets into another playable round. Both sides have their intended win conditions.

## Implementation

Add server-side zone membership and continuous per-player dwell, using live character state and validated movement. The first valid completion proposes GroundWin to MatchService; extraction at the deadline is too late. Resolve deadline, damage, interactions and extraction in the design's documented step order. Provide all result reasons, individual extraction attribution, timeout/elimination outcomes, disconnect and disabled-aircraft paths, with clear result UI.

## Acceptance criteria

- **A1:** Full gate passes. Dwell tests cover locked exit, 0/1/2/3 objectives, entry/exit/re-entry, exact duration, death, spectator and changed-round state.
- **A2:** Boundary tests establish completion strictly before the deadline wins, exactly at/after it loses, and death in the same server step prevents extraction. Repeated result proposals never change the committed winner.
- **A3:** One player extracting wins for the ground team; other teammates are not falsely marked Extracted. Concurrent valid completions cannot produce duplicate rewards/results.
- **A4:** Operator departure/aircraft disablement leaves objectives and deadline active. Ground departures and rejoin follow the design; total elimination/empty server cleanup cannot deadlock.
- **A5:** Studio automated scenarios complete ground extraction, gunship elimination and timeout, plus rejected premature extraction. Both clients see the same result and reason.
- **A6:** Three complete back-to-back rounds restore objectives, cover, aircraft, tools, cameras and connections; stale shots/interactions cannot affect a new round.

## Focused human check

Play the full lobby → recover → extract → results → lobby path, then a loss. Check the countdown is understandable and interruption feedback is clear.

## Documentation changes

Rewrite the README around the complete implemented loop. Add outcome/order contracts and exact end-to-end scenario instructions; do not turn the README into a plan history.

## Completion record

Not implemented. Record A1–A6, source, three outcome reports and full-loop experience evidence.
