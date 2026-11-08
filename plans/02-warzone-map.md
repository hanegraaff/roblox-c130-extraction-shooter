# P02 — Circular greybox battlefield

**Milestone:** M1. **Dependencies:** P01. **Requirements:** R01, R05, R10, R15. Status: [roadmap](../roadmap.md).

## Capability and player experience

Walk a circular industrial warzone with protected indoor cover, exposed firing positions and at least two approaches to a single future rocket-launcher location. The map boundary and overhead perimeter orbit are designed together.

## Implementation

Author/export the battlefield under `assets/world` and templates under `assets/models`. Define one map center, playable radius, ground-level camera focus and aircraft altitude/orbit contract. Add a separate lobby/operator station, nine valid ground spawn anchors, exactly one launcher anchor and stable cover IDs. Ground traversal stays within the circular bounds; no exterior hiding area is available. Keep both launcher approaches traversable without destruction or ammunition. Document provenance and clean reconstruction.

## Acceptance criteria

- **A1:** Full non-Studio gate passes; clean build reconstructs geometry/anchors without unsaved Studio edits.
- **A2:** Map validation finds unique IDs, nine ground spawns and exactly one reachable launcher anchor. Configuration rejects nonpositive/nonfinite radii, mismatched map/orbit centers/radii and invalid ground-level focus or altitude.
- **A3:** Studio navigation/clearance tests establish at least two passable approaches to the launcher from spawn areas, using recorded avatar dimensions. No spawn/launcher anchor is inside geometry, outside the disk or below the kill plane.
- **A4:** Engine raycasts distinguish permanent/breakable cover and demonstrate protected spawns plus usable ground firing angles toward sampled perimeter aircraft positions. The circular boundary is enforced and cannot provide a safe hiding exterior.
- **A5:** Map teardown/rebuild restores IDs and geometry counts twice, with no transient leftovers; manifest validation covers every authored asset.

## Focused human check

Walk both launcher approaches, inspect the boundary and review sight lines from sampled perimeter positions. Paths must be understandable as well as technically traversable. There is no pickup or combat implementation yet.

## Documentation changes

Document circle/orbit coordinates, radius/altitude units, anchor contracts and asset ownership. Describe the actual walkable greybox in README.

## Completion record

Not implemented. Record A1–A5 evidence, source, Studio report and geometry/route review.
