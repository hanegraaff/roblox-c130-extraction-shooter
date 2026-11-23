# P18 — Game rebalancing

**Milestone:** Gameplay revision. **Dependencies:** P07, P08, P14, P17 and the integrated Prism Seedship (PR #62). **Requirements:** R03, R05–R10, R12, R13, R15–R18. Status: [roadmap](../roadmap.md).

## Capability and player experience

Scale aircraft durability to the Ground team, make building panels quick to demolish, remove the circular camera boundary that can trap directional controls, and place a fourth recoverable rocket launcher inside the alien spaceship.

The 2026-11-23 user revision explicitly selects **1,000 health per Ground player**, counted from the deployment roster, and **existing fixed rocket damage** (100 health units). The operator is excluded. Departures, deaths, spectators and late arrivals cannot resize or refill the current aircraft. The former three-rocket guarantee is superseded. M-7 damage remains 5 units.

One direct 105mm M102 impact destroys one registered wall/roof panel. Two earned seconds of valid same-panel 30mm impacts destroy a pristine panel. Interrupted firing retains earned damage but never counts paused time. Persistent Light/Heavy visuals remain useful during the shortened 30mm progression; howitzer fire may go straight to Total. Floors, stairs and supporting frames remain stable. The waiting lobby remains protected. Apply the shared rule to every battlefield building, including Sandbreak and the Seedship.

Operator WASD and touch arrows move smoothly across the map's world-aligned **720 × 720-stud square**, centered on the existing level center. Only the square edges limit pan position. At an edge, an unblocked axis must continue; reverse input must recover immediately at every orbit phase and both zooms. The former disk/frustum pan clipping is superseded. Keep the canonical aircraft orbit and independent mouse/touch aiming. Keep camera math finite, directions consistent, selection/recenter and role cleanup usable, including near-overhead views. Server combat still validates its own playable aim envelope and solid cover; extending presentation bounds grants no damage authority.

Retain the three existing launcher sites and add a stable, reachable fourth site inside the Prism Seedship. Each Ground player still carries at most one. Reuse atomic pickup, reload-preserving transfer/recovery, direct rocket damage and reset ownership.

## Acceptance criteria

- **A1 — Roster health:** Deterministic rules and service tests prove 1–9 Ground players produce 1,000–9,000 maximum health, operator exclusion, fixed 100-unit rockets/5-unit rifle hits, mixed/lethal/deduplicated damage, no resize/heal on deaths/departures/late arrival, and pristine reset using the next roster. Invalid counts/rounds reject without mutation. Two actual Studio clients observe identical maximum/current health and a fresh-round reset.
- **A2 — Fast panel destruction:** Rules and integration tests prove one direct M102 impact gives Total with no residual collider, two valid 30mm seconds give Total, below-threshold and interrupted/mixed-fire credit persists, paused time is excluded, stale/duplicate/unauthorized outcomes do not earn damage, and pre-impact batching/fragment caps/reset hold. Native Studio rays and two-client observations prove actual openings on representative wall/roof geometry, including Seedship and Sandbreak coverage.
- **A3 — Square camera movement:** Deterministic tests cover all square edges/corners, axis sliding, immediate reversal, normalized diagonal movement, invalid input, frame-time cap, both profiles and sampled full orbit. Real Studio camera/input tests verify smooth WASD and touch-pad directions, independent aim, both zooms/recenter, finite near-overhead frames, no circular-boundary jam, and cleanup without changing the aircraft orbit. Record focused operated review separately from numeric assertions.
- **A4 — Seedship launcher:** Git reconstruction and native supported/clearance/navigation checks prove four unique reachable anchors and the fourth is inside the ship. Two actual clients exercise raced claims, one carrier limit, independent identities, fixed rocket damage, reload-preserving drop/recovery and reset to all four anchors. Preserve spectator/role/stale-request rejection.
- **A5 — Delivery:** The final full `python3 scripts/verify.py` gate passes nonempty required suites, source-bound Studio smoke and focused multiplayer/regression gates pass, independent tester findings are resolved, and player/contributor/design documentation describes the revised whole experience. Source/evidence are committed and pushed with a reviewable PR. P12's separate live release/capacity gates are not prerequisites for this explicitly requested local revision and are not waived or completed by it.

## Implementation and evidence

Use the existing deterministic health, destruction ledger, camera and launcher owners. Update affected regression fixtures to exercise the new requirements rather than preserving superseded balance assertions. Keep historical plan/evidence results as history. Bind source identity and actual client counts in the new evidence. Do not publish or merge as part of this plan.

## Completion record

Implementation and verification have not yet been recorded. Dependencies are integrated in `origin/main` at `dc55a91`; P12 remains separately blocked on release evidence.
