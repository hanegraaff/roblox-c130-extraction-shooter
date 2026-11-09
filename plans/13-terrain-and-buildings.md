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

### Building flicker integration — 2026-11-08

The user-authorized [PR #13](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/13) merged into the P13 branch at `4d329a0c28e33a709321755b89a7a46af2d362b3`. The merged tree matches reviewed head `3f949c7`, including the 0.125-stud building lift and clean floor/frame joins. The fix's Studio baseline passes 67/2 and actual traversal reaches all three upper floors; a fresh integrated full host gate passes 33 unit / 18 integration and 351 transforms. [Integration evidence](../docs/evidence/building-flicker.md#merge-and-integration--2026-11-08) records exact source, CI and build facts.

The earlier `b78abbab64fb` artifact belongs to the original candidate. Current fresh-load target is `build/p13-tests-0a374bff6bb1.rbxlx` (SHA-256 `0a374bff6bb144ef5049ec708449ebac4b7f79417c728daa37e01bdc214c6780`), prepared from the merged source. Use the current artifact when resuming fresh-load acceptance. Terrain recipe/sample data is unchanged. Required late join/final teardown, complete P04 regression, two-client human controls and fresh-load evidence remain open; PR #12 remains draft and P14 has not started. No Roblox publication occurred.

### Source integration on main — 2026-11-08

With explicit user authorization, [PR #12](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/12) merged into `main` at `19b70082b69f00f3901359403f39ba51b67a0506`, including the building surface-flicker fix. Its full tree equals reviewed head `2e3e4d5`, which passed [GitHub Verify 42536588227](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/42536588227). The fresh main `python3 scripts/verify.py` gate passes 33 unit / 18 integration, 351 authored transforms, 111 panel pivots and 7,146 surface-pair checks. [Main integration record](../docs/evidence/p13-integration.md) preserves source/build hashes and exact limits. The setup guide now uses `main`; no dependency branch is required for this source.

This user-authorized merge integrates source without closing acceptance. No new Studio session is claimed: runtime/assets/tests are unchanged from the checked source. Required late join/final teardown, P04 reticle/full-orbit, two-client human controls and fresh serialized-place evidence remain open, so P13 is not Complete and P14 has not started. The prepared `build/p13-tests-0a374bff6bb1.rbxlx` artifact remains current. No Roblox publication occurred.

### Engine acceptance resumption on a dedicated branch — 2026-11-08

The user's correction keeps further work on `fix/p13-engine-acceptance`, branched
from main `d570b11236dd7f71146d220a0848ffc2090b059f`. Candidate
`e2e4e54c5d9fb0d2195b1e2b7720b409a2d888f0`, tree
`912f4c5202d6de6e620cc8f226dc52d543de054a`, fixes test-startup synchronization,
retains failed P04 numeric diagnostics, independently checks P13 teardown, and adds
a reproducible native-world probe builder. Production gameplay/world source is
unchanged. Full host verification passes 33 unit / 18 integration, both builds,
351 authored transforms, 111 panel pivots and 7,146 surface-pair checks.

**A3 now passes:** a fresh source-built native `.rbxm` is deserialized in the
existing Studio Edit document. All 5 named cases pass: 334 world parts / 357 nodes,
initial terrain signature, two perturbed rebuilds with unrelated-voxel preservation,
and clean double teardown/restoration. The independent tester reviewed the actual
result and accepted this as A3's fresh native-world load. It is not a new-place
boot claim. [Acceptance evidence](../docs/evidence/p13-acceptance.md) preserves
exact artifact/probe/source hashes, actual results and the independent review.

A new two-client launch exposed the old ten-second avatar-startup assumption;
67 server cases passed, but both client baselines failed and no P13 gameplay case
passed. The candidate corrects staged readiness without removing assertions.
Its engine rerun remains pending: four mapped test scripts were stale, the stopped
Rojo server was restarted on localhost:34872, and the existing plugin still needs
reconnection. Require all 58 source signatures to match before counting a run.
Late join/reset/final teardown, P04 numeric diagnosis/full orbit and two-client
human controls remain open. No acceptance completion, P14 implementation, merge or
Roblox publication is claimed.

The source/tests and interim evidence are pushed in
[draft PR #16](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/16)
(candidate `e2e4e5`, evidence/docs `1dc880a`). The final documentation checker
passes 61 Markdown / 47 JSON files; diff checks pass. The PR remains draft while
the required synchronized-candidate engine scenarios are pending.

### Acceptance closure — 2026-11-08 local / 2026-11-09 UTC

The independent tester exercised source
`e2e4e54c5d9fb0d2195b1e2b7720b409a2d888f0`, tree
`912f4c5202d6de6e620cc8f226dc52d543de054a`, at documentation head
`e8b245dc4a3b73cd1e72215b77a89ae2bde7a628`. Every run first matched all 58
mapped source signatures in the existing Studio 0.746.0.7461269 test document;
351 loaded authored parts match within 0.001 (maximum error 0.00001429265).
Production gameplay/world source remains unchanged from integrated main.

| Criterion | Final acceptance evidence |
| --- | --- |
| A1 | Full current host gate passes 33 unit / 18 integration, strict/static checks, both builds, 351 transforms, 111 panel pivots and 7,146 surface-pair checks. Earlier clean-archive reconstruction remains applicable to unchanged gameplay/world source. [CI Verify 42540612044](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/42540612044) passes on `e8b245d`. |
| A2 | Existing BuildingLayout/panel tests plus renewed actual Humanoid traversal pass for Foundry, Warehouse and Outpost upper floors. |
| A3 | Fresh native source-built world load passes all five named cases, including initial signature, two perturbed rebuilds, unrelated-voxel preservation and clean double teardown/restoration. Native world interpretation is verified; no separate full-place boot is claimed or required by this criterion. |
| A4 | Existing supported routes/anchors, lobby separation, containment and focused human review remain valid for unchanged geometry. Renewed actual ground-avatar upper-floor traversal passes in every building. |
| A5 | P13 passes 5/5 with two initial clients and an actual third late spectator; nine real-client observations agree initially, after two resets and on late join. P04 passes 6/6 with two actual clients, nine samples over the full 90-second orbit and two rounds; maximum observed pose error is 1.6772691 studs against the 8-stud bound. Both numeric reticle/zoom profiles, selection rejection and thermal cover pass. |
| A6 | Both perturbed round resets and independent repeated runtime/aircraft teardown pass. The two-client human-controls regression passes 4/4, including role conflicts, exact requested roles, next-round settings and reset/restart. No owned test fixtures remain; the sole original document is back in Edit. |

The successful P04 baseline reports 67/67 server cases with two actual clients,
and 2/2 per client, zero failures/errors/skips. P13's server baseline reports
67/67 while the first client is present; its separate multiplayer harness then
proves two initial and three peak actual clients. All nine P13 observations
include passing 2/2 client baselines, including the characterless late spectator.
The historical reticle failure was not reproduced; retained numeric diagnostics
now precede the unchanged bound assertion. No production camera fix is claimed.

Rojo reconnection resolved the stale-source gap. One subsequent native client
launch failed before gameplay on Roblox OAuth metadata timeouts; that failed
launch is preserved separately. A successful read-only endpoint probe supplied
new availability evidence, then the bounded retry and subsequent required suites
passed. Assertions were not weakened to bypass that failure.

[Final acceptance evidence](../docs/evidence/p13-acceptance.md),
[structured tester closure](../docs/evidence/p13-acceptance/final-summary.json),
[independent report](../docs/evidence/p13-acceptance/tester-report.md) and
[source manifest](../docs/evidence/p13-acceptance/source-manifest.json) preserve
commands, source hashes, actual reports and scope. The technical writer updated
the player/setup/testing narrative and confirmed the representative screenshot
still matches unchanged visible progress. No material tester findings remain.
Delivery stays on [PR #16](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/16),
with integration separate from acceptance. P14 has not been implemented; no merge
or Roblox publication occurred.

Final passing reports and experience/roadmap documentation are committed and
pushed in `c5cb7ff4d238fb9b00ac9480c99724a1613a03ab`;
[GitHub Verify 42544499355](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/42544499355)
passes. PR #16 is open, ready for review and unmerged. Final repository checks
pass 61 Markdown / 56 JSON files and `git diff --check`. Main remains `d570b11`.
