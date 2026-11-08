# P03 — Roles and round lifecycle

**Milestone:** M1. **Dependencies:** P02. **Requirements:** R02, R03, R04, R13, R15. Status: [roadmap](../roadmap.md).

## Capability and player experience

Players wait in a lobby, receive an operator or ground role, deploy and return after a timed round. An eliminated player spectates instead of respawning. This establishes the match contract before weapons are added.

## Implementation

Implement pure phase/roster rules and MatchService/RoleService adapters. Enforce 6–10 production players and test-only minimum of two players (also supporting three-client launcher tests). Add fair rotation, deployment readiness/cancellation, monotonic deadlines, basic timeout/elimination/abort outcomes, explicit character spawning and minimal phase/role/timer UI. Provide result proposals for aircraft destruction and operator forfeit as well as ground elimination/timeout; later combat plans connect actual damage. Store round membership by UserId so reconnects cannot restore life. Tag all queued work and updates with round IDs/revisions. Add basic teammate spectating and cleanup now; P10 improves presentation.

## Acceptance criteria

- **A1:** Full gate passes. Boundary tests at 5/6/10/11 players reject invalid rosters and assign exactly one operator and place every other player on one ground team for valid rosters; tie-break/rotation is deterministic with a seed.
- **A2:** Transition tests reject illegal phase changes and commit one result only. Fake-time tests reach the deadline exactly; cancelled deployment returns to lobby without partial active players.
- **A3:** Death/manual reset does not create a fresh active character. Rejoin/late join cannot gain an active role or new gear in the same round; departure cleanup can release a held weapon without duplicating ownership.
- **A4:** Wrong-role, stale-round, replayed and spectator commands reject without state change. Test-only population override is absent from the release build.
- **A5:** Two real Studio client contexts receive their correct roles, phase and deadline. Operator remains protected; an eliminated ground player spectates and cannot interact.
- **A6:** Three accelerated rounds restore roster, camera, map, connections and phase state. Tests cover operator/ground departures during deployment and Active, using the design's distinct policies.

## Focused human check

Observe waiting, deployment, timer, elimination, result and return states on both clients. At this stage the operator has a placeholder view and combat is unavailable; make that explicit.

## Documentation changes

Describe role assignment, no-respawn behavior, reconnect rules and actual development controls. Add lifecycle/API contracts and evidence to the service docs.

## Completion record

Not implemented. Record A1–A6 mappings, source, client count, Studio output and cleanup evidence.
