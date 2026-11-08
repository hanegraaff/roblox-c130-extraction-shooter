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

### Implemented candidate — 2026-11-08

Source `ea9cd4ee567e28d205841b093180cad3d0921110`, tree `654ce450241698cc00353d9209a07a3e188654f8`, contains the expanded disk/perimeter orbit, eight bounded deterministic terrain hills, Foundry/Warehouse (64×48 studs each), Outpost (32×48), two usable floors per building, 32-stud room bays and 111 registered wall/interior/roof panels. Upper floors are at Y=10; sixteen 0.625-stud-rise, two-stud-run, eight-stud-wide treads connect each building. Lobby is at X=520. These dimensions, relief, unchanged 140-stud altitude and 750-stud future range budget are construction defaults, not additional user-selected rules. Panel damage, fragment physics, firing and mouse panning remain later increments.

The developer delivered source/tests; the independent tester found and verified corrections for stair-foot clearance, continuous doorway sweeps, malformed navigation markers, expanded-map shelter sight lines and an ineffective stopped-containment regression probe. Review also added explicit room bays and protected-lobby separation. A test-only signed-zero string-comparison defect was replaced by numeric 0.001-tolerance geometry checks with identity/flag rejection probes; product geometry is unchanged since `b157e8423ad8d745e97043fbc7bb8f6673e6d516`.

| Criterion | Named checks / environment | Observed evidence |
| --- | --- | --- |
| A1 | `python3 scripts/verify.py`; clean `git archive` reconstruction; `ExpandedMapRules`; expanded world/artifact contract | Pass: 33 unit / 18 integration; formatting, lint, strict types, rejection probes, both builds, 351 authored part transforms per build, 111 panel pivots and release isolation. Both clean-archive builds match candidate SHA-256. |
| A2 | `BuildingLayout` unit/loaded-geometry cases; actual P13 Humanoid traversal | Three correct footprints, two usable floors each, connected stairs, room bays, IDs/pivots and support/panel distinctions pass. All three actual upper-floor walks pass in the two-client P13 scenario. |
| A3 | `TerrainReconstruction` voxel/material/elevation and invalid-recipe cases | Two mutated rebuilds and preservation of unrelated terrain pass in Studio. Original-place sample: 1,152 voxels / eight hills, Adler32 2054186319. Fresh serialized-place load remains required; automatic approval review rejected the separate-process open before launch because of duplicate-instance/unsaved-work risk. |
| A4 | `Map.spec` anchors/routes/containment; `ExpandedMapNavigation` / P13 actual avatar | Supported/clear anchors, separate lobby, both 4×6×4 launcher routes, containment and all three actual building stair traversals pass. Focused actual WASD, both launcher routes (eight navigation segments) and Hill04 climb pass at 1081×619 / Automatic quality. |
| A5 | `ExpandedMapSightLines`; P13 replicated world/reset cases; P04 aircraft harness | 64-phase protected/exposed rays pass; two actual clients agree initially and after two resets. Third actual late client failed to launch. P04 stopped on a reticle-bound assertion; numeric diagnosis/full-orbit rerun remains open after a later test-server launch timed out on Roblox metadata/sign-in requests. |
| A6 | Exact map rebuild/cleanup baseline cases; P13 perturbed round resets and teardown | Two perturbed actual-round resets and controlled map teardown pass. P13's final runtime teardown scenario was not reached after late-join timeout; full five-scenario acceptance remains open. |

The final current host gate passed on the source above with subsequent prose changes; documentation-only follow-up is checked with `python3 scripts/check_repository.py`. A fresh Studio baseline passes 67 server / 2 per actual client with zero errors/failures/skips. These results do not replace the missing late-join, complete aircraft regression, fresh-load and final harness evidence.

See [bounded evidence and remaining checks](../docs/evidence/p13-terrain-and-buildings.md), [source/build manifest](../docs/evidence/p13/source-manifest.json), [full host log](../docs/evidence/p13/final-verify.txt), [clean reconstruction](../docs/evidence/p13/clean-reconstruction.json), [independent tester report](../docs/evidence/p13/tester-report.md) and [actual Studio reports](../docs/evidence/p13/studio-reports.json).

The technical writer updated 16 player/contributor/package documents and replaced the representative README image with a real 2026-11-08 Studio Edit overview of the source-reconstructed terrain/buildings; it is explicitly not the gameplay camera or multiplayer evidence. Single-client human controls pass 6/6 and lobby controls 4/4. The actual two-client human-settings regression remains unrun after the launch blocker. The original Studio document was returned to Edit with terrain/camera restored.

Source `ea9cd4e` is pushed in [draft PR #12](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/12); [GitHub Verify 42533469132](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/42533469132) passes on that tested source. Required late-join/final teardown, complete P04 regression and fresh serialized-file evidence remain open; P13 is not Complete. The concrete next file is `build/p13-tests-b78abbab64fb.rbxlx` (test SHA-256 in the manifest). Open it manually through the existing Studio application's File → Open from File, or obtain explicit approval for a single separate-document launch, then resume the recorded checks after multiplayer launch is reliable. P14 has not started. No merge or Roblox publication occurred.
