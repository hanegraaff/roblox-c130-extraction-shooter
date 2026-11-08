# P13 — Expanded terrain and multi-story buildings

**Milestone:** M2 / level revision. **Dependencies:** P04. **Requirements:** R01, R05, R09, R10, R15, R16. Status: [roadmap](../roadmap.md).

## Capability and player experience

Explore a battlefield twice the current diameter, with terrain, two large buildings and one smaller building, all at least two stories. Walk upper floors and two protected approaches to the launcher anchor. Primitive graphics demonstrate the space and future panel destruction; refined art is separate later work.

## Implementation

Change playable radius 180 → 360 studs (diameter 360 → 720), retaining equal orbit radius and a shared center. Author traversable terrain/elevation, exactly two large and one smaller building, usable stairs, stable floors/supports and modular exterior panels on every story plus panelized roofs. Record footprint areas to make large/small objectively distinct; select actual dimensions during construction. Use D32 panel/room dimensions as defaults, then validate avatar clearance. Version a terrain export or deterministic recipe with fixed seed, bounds and material/elevation expectations; update the manifest and teach MapService pristine terrain reconstruction. Revalidate every anchor, floor-support/height check, boundary/recovery behavior and aircraft range/altitude sight line; relocate the current lobby beyond the enlarged boundary. Preserve human test controls and production isolation.

Register stable building/story/panel IDs and pivots, with reserved geometry contracts for Intact/Damaged/Destroyed variants; P07 implements damage/swaps/physics. Distinguish static floors/stairs/frames from destructible walls and roofs. Full collapse and runtime terrain deformation are outside this increment. Keep the map reconstructable from Git, without required unsaved Studio edits.

## Acceptance criteria

- **A1:** Full host gate and clean-checkout build pass with all new terrain/world sources in the manifest. Named `ExpandedMapRules` cases assert diameter 720, radius/orbit 360, finite geometry and invalid mismatches. Artifact inspection covers new geometry and the terrain source contract.
- **A2:** `BuildingLayout` checks find exactly two larger footprints and one smaller footprint, each with at least two usable stories, connected stairs, valid unique building/story/panel IDs and intact panel pivots. A representative room is about two panels wide and one tall. Each building has destructible exterior panels on every story and roof panels, with static support distinguished explicitly.
- **A3:** Studio `TerrainReconstruction` compares sampled elevation/material/support before and after two rebuilds and a fresh source-built load; mutated terrain and transients restore without touching unrelated terrain. Verify actual loaded transforms, not only exported properties.
- **A4:** Studio `ExpandedMapNavigation` tests supported/clear spawns, lobby separation, terrain containment/recovery and two passable launcher approaches without destruction. Use the recorded upright-avatar clearance envelope (at least the existing 4×6×4-stud fixture); operate an actual avatar from ground into every building and onto each upper floor. No required route relies on jumping through a wall or spending ammunition.
- **A5:** Studio `ExpandedMapSightLines` samples a full perimeter orbit: terrain/buildings provide protected positions and useful ground counterfire angles, the plane remains visible, and supported weapon ranges/vertical envelope are feasible. Two actual clients see the same terrain/buildings/aircraft after sync, reset and late join. Fixed-focus prototype framing is an interim limitation until P14, not panning evidence.
- **A6:** Repeated reset/teardown restores exact terrain, authored geometry, IDs and anchors; no panel/runtime fixtures survive. Existing round/preview/selection suites still pass or are deliberately updated for the new authored geometry, without discarding their behavioral assertions.

## Focused human check

Walk both launcher routes and all building stairs/floors. Inspect terrain readability, relative building scale, travel time and cover from ground and aircraft views. Record viewport and graphics settings; capture actual expanded-map progress for the representative README image. This increment does not claim firing or destruction is playable.

## Documentation changes

Update world/model package contracts, map coordinates, terrain authoring/rebuild procedure, manifest, player availability and local test expectations. Preserve completed P02/P04 evidence as historical prototype records. P14 supplies panning next.

## Completion record

No implementation or validation performed by the steering revision. Record A1–A6 → named tests/commands → environment/counts/results, tested source/build, Studio/client reports, operated navigation, tester findings, CI/PR and remaining limitations when implemented.
