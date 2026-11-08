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

2026-11-08: source implementation and independent host verification are delivered on `plan/02-warzone-map`. Required Studio and focused walking evidence remain unavailable; this is not a completion claim. See the [P02 evidence record](../docs/evidence/p02-warzone-map.md) and [independent tester report](../docs/evidence/p02/tester-report.md).

Independent tester implementation commit: `028fe388cf3d92a57bea75f49cb585ff991e75e9`, tree `648f2411c5ac39d93cd5a1dcc9d7320e7ef87ecd`. Final source `9b5e7aa818fddd33d8d171a8938ed5a706abec26` adds only two source-comment corrections, with the full host gate rerun successfully by the coordinator. The candidate adds the circular authored battlefield, nine protected ground anchors, one future launcher anchor, separate stations, tagged cover, deterministic map/orbit configuration, server containment and pristine rebuild ownership. No roles, aircraft, weapons, launcher pickup or destruction are implemented.

| Criterion | Test / command and environment | Observed result |
| --- | --- | --- |
| A1 | Independent `python3 scripts/verify.py`, macOS arm64 / Python 3.10.4 / pinned tools; coordinator clean `git archive` reconstruction with installed locked TestEZ | Host gate passes: 14 unit, 2 integration, zero failures/skips; both clean builds hash-identical; release isolation passes with 138 release / 176 test Instances and 10 runtime scripts. |
| A2 | `tests/unit/MapRules.spec.luau`, four cases through Lune; `tests/studio/specs-server/Map.spec.luau` anchor/configuration/geometry validation | Four unit cases pass. Real Instance validation of numbered anchors, clearance and support is unrun. |
| A3 | Map.spec “two launcher approaches clear a 4x6x4 stud upright avatar and have continuous floor”; 0.5-stud sampling with overlap queries and downward rays | Required Studio clearance/navigation and anchor cases unrun. Actual walking review unrun. |
| A4 | Map.spec cover queries at eight orbit phases, all nine spawn anchors, eight firing positions; server containment/cleanup case | Required engine raycasts, containment and boundary review unrun. |
| A5 | Manifest coverage checker plus four independent rejection probes; Map.spec two pristine rebuilds comparing IDs, poses, counts and temporary cleanup | Manifest checks pass. Required two-rebuild engine evidence is unrun. |

External blocker: Studio MCP lists null-name instances, but `get_studio_state`, `execute_luau` and `skill` return **Place is not open**, including after opening the hash-labeled candidate. The user confirmed sign-in and offered to dismiss dialogs; subsequent checks still failed. A manual open of the exact test file has been requested. No live place was mutated, no engine suite/client count was observed, and no screenshot or multiplayer claim is made. Resume with the candidate open and identifiable, then run mapped server/client suites and focused route/boundary/sight-line review. Expected 23 server / 2 client cases are expectations only.

The independent tester found no material reproducible source defects. Source is pushed in [draft PR #4](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/4); documentation review and final delivery facts are recorded in the linked evidence record. P03 remains Planned until P02 satisfies its required gates. No Roblox publication occurred.

[GitHub Verify run 42511523878](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/42511523878) passed on documentation/evidence commit `8214d7067cd178b54421ecd2d27f15eb74fa9871`. The user reports Studio still cannot open the candidate; required engine acceptance remains open.
