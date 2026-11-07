# P02 — Industrial greybox battlefield

**Milestone:** M1. **Dependencies:** P01. **Requirements:** R01, R15. Status: [roadmap](../roadmap.md).

## Capability and player experience

Create one readable ruined industrial district. Testers can traverse indoor cover, exposed streets and at least two approaches to the future extraction area. Greybox shapes establish gameplay geometry before decorative art.

## Implementation

Author/export the map under `assets/world` and reusable templates under `assets/models`. Include a separated lobby/operator station, nine valid ground spawn anchors, at least six candidate objective anchors, one extraction volume and stable cover IDs. Tag permanent cover separately from breakable prototypes. Add map validation and MapService lifecycle using the P01 patterns. Keep all objectives reachable without destroying anything. Record manifest provenance and reconstruction steps.

## Acceptance criteria

- **A1:** Full non-Studio gate passes; clean build reconstructs all map geometry/anchors without unsaved Studio edits.
- **A2:** Map tests find unique IDs, nine ground spawns, at least six objective candidates, one extraction zone, valid pivots/bounds, and no anchors inside solid geometry or below the kill plane.
- **A3:** Studio navigation/geometry fixtures establish at least two passable approaches and access to each candidate from ground spawns; use engine path/clearance checks with recorded avatar dimensions.
- **A4:** Engine raycasts identify permanent and breakable cover consistently; spawn points have protective geometry from the intended orbit envelope.
- **A5:** Map teardown/rebuild restores the same ID set and geometry count twice, with no leftover transient objects. Manifest validation passes for every authored asset.

## Focused human check

Walk the intended paths and inspect roof/interior cover from the future operator angle. Record confusing dead ends or sight lines; pathfinding success alone does not establish a usable map.

## Documentation changes

Document map tags, IDs, anchor contracts and asset ownership in package docs. Explain the walkable greybox in README without claiming combat or collectibles work.

## Completion record

Not implemented. Record A1–A5 evidence, source commit, Studio report, map review and any deliberate geometry limits.
