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

2026-11-08: source correction is committed and pushed in [draft PR #4](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/4). This is not a completion claim. See the [current evidence record](../docs/evidence/p02-warzone-map.md).

Corrected candidate: `8147d1cc433a92396a04a7141f991c8619bce84d`, tree `fc5d6c356cb0b54bd7a2747447af6158830d2fc8`. The candidate adds the circular authored battlefield, nine protected ground anchors, one future launcher anchor, separate stations, stable cover IDs/kinds, deterministic map/orbit configuration, server containment and pristine rebuild ownership. No roles, aircraft, weapons, launcher pickup or destruction are implemented.

| Criterion | Test / command and environment | Observed result |
| --- | --- | --- |
| A1 | Independent `python3 scripts/verify.py`; clean `git archive` reconstruction with pinned Rojo and installed locked TestEZ; artifact comparisons | Host gate passes: 14 unit / 2 integration, zero failures/skips; both clean builds hash-identical. All 112 part transforms/dimensions/shapes/collision flags match in each build; five geometry corruption probes reject. Actual corrected file-load evidence pending. |
| A2 | Four `MapRules.spec` cases through Lune; `Map.spec` real anchor/configuration/geometry validation | Four unit cases pass. Corrected Instance anchor/clearance/support suite is pending. |
| A3 | Map.spec two approaches: 4×6×4-stud upright envelope, 0.5-stud sampling, downward support rays; focused walking | Required corrected Studio clearance/navigation, anchor and walking review pending. |
| A4 | Map.spec cover rays at eight orbit phases, nine spawn anchors, eight firing positions, containment/cleanup | Required corrected engine and boundary review pending. |
| A5 | Manifest coverage/rejection checks; Map.spec two pristine rebuilds comparing IDs, poses, counts and temporary cleanup | Manifest checks pass; corrected two-rebuild engine evidence pending. |

Material finding and resolution: when the previous test document became accessible, the user and tester observed collapsed geometry. Studio ignored serialized Position/Orientation aliases, leaving every authored part at an identity pose; the server rejected the map and no suites completed. [Broken-baseline evidence](../docs/evidence/p02/broken-baseline.json) records Studio 0.746.0.7461269, place 0, one actual client and the startup errors. The developer replaced all authored poses with canonical CFrame, added generated-artifact comparisons and five failure probes, and extended actual file-load assertions. Developer and independent tester full host gates pass on the corrected source. Earlier host success did not prove engine behavior.

The corrected local test file is `build/p02-tests-5c809beff70b.rbxlx`; automated opening still leaves an unnamed/unavailable instance, so a manual File/Open check is pending. Expected 23 server / 2 client cases are source expectations only. The cloud place remains untouched. Resume by verifying the corrected document through MCP, running automatic suites and restart checks, then walking both approaches and reviewing boundary/sight lines. P03 remains Planned; no merge or Roblox publication occurred.

[GitHub Verify run 42512058874](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/42512058874) passed on corrected source `8147d1c`. Documentation review and final delivery records are in the linked evidence record.
