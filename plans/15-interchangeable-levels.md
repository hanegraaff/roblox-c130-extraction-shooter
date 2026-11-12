# P15 — Interchangeable levels

**Milestone:** M7 / future levels. **Dependencies:** P12. **Requirements:** R01, R05, R06, R09, R10, R16, R18. Status: [roadmap](../roadmap.md).

## Capability and player experience

Players can choose or rotate among at least two validated levels. Every level has one C-130 circling it. The operator's directional pan, weapon-linked zoom and aim work on each level; weapons, health, rocket rule, building-panel damage thresholds and physical fragment limits keep the same game rules. The current 720-stud circular industrial battlefield remains the MVP's only playable level until this plan is implemented.

## Architecture contract

Define a versioned, immutable `LevelDefinition` with a stable level ID and source asset/terrain recipe; playable horizontal footprint and containment/recovery bounds; orbit center/radius/altitude/phase; aim height envelope and queryable cover; role spawns, protected station and launcher anchor; stable building/panel identities and all panel variants. Validate the package and asset provenance before selecting it. Permit a circular orbit that encloses a noncircular playable footprint, while retaining an inward camera and enough weapon range/visibility for the entire level.

`MapService` owns active level construction, pristine rebuild and one generation token. `AircraftService` consumes the selected orbit definition. `AircraftPanRules` and the operator controller consume the selected footprint to clamp focus; all device inputs feed the same directional rule. Combat, launcher, thermal and destruction services consume level geometry/IDs through explicit interfaces and retain server authority. They must not duplicate core weapon, zoom, health, panel progression or debris behavior per level. A level switch occurs at a safe lobby/reset boundary and invalidates stale shots, ownership and client view state. Late joiners receive the current level and panel states. The release artifact includes all level sources and manifest entries; no required scene lives only in Studio.

## Acceptance criteria

- **A1:** Two distinct Git-authored level packages build from a clean checkout. Validation rejects missing/duplicate IDs, malformed bounds, orbit that fails to enclose the footprint, inaccessible anchors, unsupported upper floors, bad aim envelopes and absent panel variants without mutating the active level.
- **A2:** The same aircraft/orbit/pan/zoom rule tests run against both definitions and at least one differing size or noncircular footprint. WASD/touch focus reaches each playable boundary and never leaves it; full orbit remains inward-facing with useful sight lines and range.
- **A3:** Server combat, muzzle obstruction, health, rocket damage and panel progression/fragment rules produce the same configured outcomes on both levels. Solid cover and residual openings remain authoritative. Rejected/stale level or round commands have no effect.
- **A4:** Two actual clients observe the same chosen level, C-130 pose, cover state and result. Repeated level switch/reset, late join and departure reconstruct exactly one world/aircraft/launcher and current panel state with no leaked listeners, fragments or prior-generation damage.
- **A5:** Player guide and level UI identify the active level and its controls; operated desktop and mobile review covers camera reach, readability, building access and cover on both levels. Record performance at 6 and 10 players under the established budgets before release.

## Delivery boundary

This plan is future work. The 2026-11-10 architecture revision defines the target contract; it does not claim that current `MapRules.defaults`, `TerrainRecipe`, `BuildingLayout`, `MapService` or the Rojo world mapping can switch levels today. Implement only after the preceding MVP plans are complete or a user-directed dependency revision supplies the needed source and acceptance scope. Do not mark P15 complete from a second mock map or host-only tests.
