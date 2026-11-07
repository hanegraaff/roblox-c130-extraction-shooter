# P08 — Shared mission objectives

**Milestone:** M5. **Dependencies:** P07. **Requirements:** R10, R13, R15. Status: [roadmap](../roadmap.md).

## Capability and player experience

The ground team searches for three mission items at randomized valid locations. Any living teammate can collect an item; everyone sees progress, and deaths do not undo recovered items. The extraction indicator becomes ready when all items are collected; actual escape arrives in P09.

## Implementation

Add seeded selection from the curated anchors, objective templates/IDs, server-validated interaction and immutable team progress. Resolve contested pickups atomically without yielding during mutation. Use server-observed reach/life/phase and movement plausibility; a prompt activation is only intent. Add shared progress HUD and extraction-ready signaling, including correct late-join snapshots.

## Acceptance criteria

- **A1:** Full gate passes. Placement tests across a documented seed set always choose three distinct valid reachable anchors; identical seeds reproduce placements.
- **A2:** Two requests for one item, duplicated messages or delayed callbacks increment progress only once. Collected count remains within 0–3.
- **A3:** Invalid ID, range, implausible travel, wrong role, dead/spectator, stale round and flood inputs reject without objective mutation. A valid interaction still succeeds afterward.
- **A4:** Collected progress survives collector elimination/disconnect; rejoin cannot recollect or respawn. Late clients receive the correct current item set/count.
- **A5:** In Studio, each item is physically reachable and collectible and both clients display the same progress. Reset returns to zero and a fresh seeded selection without leaked old items.

## Focused human check

Verify that item prompts, shared progress and the locked/ready exit state are understandable from the ground. Avoid presenting a working extraction countdown before P09 exists.

## Documentation changes

Explain team-shared progress, randomized placement and currently available objective behavior. Document item/anchor contracts and atomicity tests.

## Completion record

Not implemented. Record A1–A5 evidence, source, seed set and interaction/readability observations.
