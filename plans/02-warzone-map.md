# P02 — Circular greybox battlefield

**Milestone:** M1. **Dependencies:** P01. **Requirements:** R01, R05, R10, R15. Status: [roadmap](../roadmap.md).

The 2026-11-08 larger-level revision is a new construction increment in [P13](13-terrain-and-buildings.md): this plan and its completion record retain the original 180-stud-radius greybox acceptance, without claiming the new terrain/buildings are implemented.

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

2026-11-08: corrected candidate passes all required acceptance criteria. Source and evidence are delivered in [PR #4](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/4); integration is separate. See the [full evidence record](../docs/evidence/p02-warzone-map.md), [final independent tester report](../docs/evidence/p02/final-tester-report.md) and [structured Studio report](../docs/evidence/p02/studio-report.json).

Tested source: `8147d1cc433a92396a04a7141f991c8619bce84d`, tree `fc5d6c356cb0b54bd7a2747447af6158830d2fc8`. Source did not change during or after final independent acceptance; subsequent changes are prose/evidence only.

| Criterion | Named test / command and environment | Observed result |
| --- | --- | --- |
| A1 | Independent `python3 scripts/verify.py`; coordinator clean `git archive` reconstruction; generated-artifact geometry comparisons; Studio file load | Full host gate passes: 14 unit / 2 integration, zero failures/skips; both source-only builds hash-identical. All 112 part poses/dimensions/shapes/collision flags match in each build; five geometry fault probes reject. Actual loaded disk/spawn/roof transforms pass. |
| A2 | Four `MapRules.spec` cases; Map.spec “authored anchors validate and malformed identity count clearance and elevations reject” | Lune and real Studio pass: circle/focus/orbit rejection, nine numbered spawns, one launcher, unique identity, supported/clear anchors, invalid geometry/count/elevation rejection. |
| A3 | Map.spec “two launcher approaches clear a 4x6x4 stud upright avatar and have continuous floor”; actual R15 route navigation | Real overlap queries and support rays every 0.5 stud pass. Both spawn-to-launcher routes and east reverse complete: all 18 navigation steps succeed, health 100. Fixture and actual avatar dimensions recorded separately. |
| A4 | Map.spec “cover queries protect all nine spawns and expose firing angles to eight perimeter samples”; containment case; actual boundary probes | Permanent/breakable metadata/rays, nine protected spawns at eight phases and eight firing positions pass. Actual wall stops movement at x177.949; controlled outside position returns to Ground05 within 0.25 seconds, observed by client. |
| A5 | Manifest coverage/rejection checks; Map.spec “two rebuilds restore exact geometry IDs poses counts and remove transient content” | Host manifest checks pass. Two real rebuilds restore IDs, poses and counts and remove transients. Fresh session restart/cleanup restores baseline with no MapFixture/status/report leftovers. |

Studio `0.746.0.7461269`, exact local document `p02-tests-5c809beff70b.rbxlx`, place ID 0, instance `574c4eb0-6eaf-4f2e-beb3-8666a0066bda`, seed 1. **Two fresh sessions each pass 23/23 server and 2/2 client tests**, zero failures/skips/errors, one actual client. Repeated runs execute the same cases. Both Stops restore zero players, no runtime status/report/fixtures, and 117 authored map descendants. The document is stopped in Edit; old/cloud places are untouched.

The operated R15 avatar has HipHeight 1.998025 studs, root 2×2×1, visual/accessory extents 4.228424×6.365918×2.915490. The automated clearance fixture is 4×6×4 studs, not an all-avatar guarantee. Focused review at viewport 1081×619 / Automatic graphics found both doorways/routes, marker and boundary readable; actual walking and four cardinal perimeter views supplement the automated evidence. The coordinator inspected the saved captures.

Resolved material finding: the first accessible prior candidate loaded Position/Orientation aliases as identity CFrames, stacking geometry and rejecting server startup. The user’s observation was reproduced and preserved in [baseline evidence](../docs/evidence/p02/broken-baseline.json). Canonical CFrame assets, all-part artifact comparisons, five corruption probes and loaded-transform assertions fix and cover the defect. Final independent review reports no material findings or required engine gaps.

Developer and tester full host gates pass on the corrected source. [GitHub Verify run 42512058874](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/42512058874) also passes on `8147d1c`, including clean tool/dependency setup. The technical writer reconciled player, contributor, architecture and package docs with actual implementation and evidence; no contradictions remain. Final prose is checked with `scripts/check_repository.py` and `git diff --check`.

This is a one-client local greybox increment: roles, aircraft, combat, pickup, destruction and rounds remain planned. Release reconstruction/isolation passes; no separate release-document Play or multiplayer/capacity/performance claim is made. No merge or Roblox publication occurred. Final delivery commit/PR facts are recorded in the linked evidence record.

Delivery: source `8147d1c` and acceptance/documentation commit `7ac678e9bc250accd7704463ccec074712ff0686` are pushed on `plan/02-warzone-map`. PR #4 is ready for review, open and unmerged. All required criteria, tester findings and documentation obligations are satisfied. Roadmap promotes only P03 to Ready; it is not implemented. Final record/status changes contain no runtime edits.

Integration, 2026-11-08: with user authorization, PR #4 merged into `main` at `6c919de9990bcc1379bb7e52e67f9805e0abb683`. The head `0dc3e16d8d5e2a887b1a1a6e68fe20b3f8d23281` had passing [GitHub Verify run 42515478604](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/42515478604). Tested gameplay source remains `8147d1c`; later changes added the verified Studio-session workflow and documentation. P03 can now use the dependency source from `main`. No Roblox publication occurred.
