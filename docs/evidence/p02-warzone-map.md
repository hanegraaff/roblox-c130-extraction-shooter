# P02 battlefield evidence

2026-11-08. Corrected source and independent acceptance are delivered in [PR #4](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/4). The first accessible Studio candidate exposed a real asset-transform defect. Canonical CFrame serialization fixes it, and the corrected candidate passes the required host, engine and focused walking checks. [Roadmap](../../roadmap.md) owns status; the [plan](../../plans/02-warzone-map.md) maps criteria.

## Corrected candidate

Source commit `8147d1cc433a92396a04a7141f991c8619bce84d`, tree `fc5d6c356cb0b54bd7a2747447af6158830d2fc8`. The [31-file corrected manifest](p02/corrected-source-manifest.json) records runtime source, tests, tools, assets and project definitions; developer-supplied combined path/byte SHA256 is `99df2bb5ca47eca0d011b277c9182fd5240bcc1a79ff6491bb65880177d573c8`. The independent tester checked all path hashes and both build hashes unchanged.

| Build | SHA256 |
| --- | --- |
| `build/p02-game-26622dbbb953.rbxlx` | `26622dbbb9530c827210126e7ba2217d64bc86ae7939f1f5fb949168b4ceae7b` |
| `build/p02-tests-5c809beff70b.rbxlx` | `5c809beff70bb0997df60b1321673faf697b999ce95bee4f89c5b6778280717e` |

Generated builds stay ignored. The battlefield and cover template are original primitives with no uploaded/external model dependency. All 112 authored parts now use canonical twelve-component `CFrame` properties. The former `Position`/`Orientation` aliases produced XML properties that Studio ignored on file load.

The coordinator reconstructed both artifacts from `git archive 8147d1cc433a92396a04a7141f991c8619bce84d` in a disposable directory, copying only installed locked `Packages` as a dependency. Commands were `rojo build default.project.json --output build/game.rbxlx`, `rojo build test.project.json --output build/tests.rbxlx` and `python3 scripts/inspect_build.py`. Both hashes matched the corrected candidate; no working source or Studio state was copied. The [reconstruction log](p02/corrected-reconstruction.txt) includes the new geometry gate and rejection probes. Reconstruction alone does not establish engine playability.

## Independent host verification

The developer and independent feature tester each ran the complete `python3 scripts/verify.py` successfully on the corrected source. Exact subcommands/results are preserved in the [developer log](p02/cframe-verify.txt) and [independent log](p02/cframe-independent-verify.txt). Environment: macOS Darwin 25.6.0 arm64, Python 3.10.4; pinned Rojo 7.7.1, StyLua 2.6.0, Selene 0.32.0, Lune 0.11.1, Wally 0.3.2, luau-lsp 1.70.1.

- Unit: 14 discovered/passed, zero failures/skips; four MapRules cases cover matching circle/focus/orbit, finite/configuration rejection, disk boundaries and sampled orbit positions.
- Service integration: 2 discovered/passed, zero failures/skips.
- Format, lint and strict Roblox-aware analysis pass, alongside deliberate failing-test, empty-suite and invalid-type rejection probes.
- Both builds and release isolation pass: 138 release / 176 test Instances, 10 allowed runtime scripts in release.
- New artifact checks compare all 112 authored parts in each build against source for CFrame, dimensions, shape and collision flags. Five deliberate geometry faults are rejected: original alias serialization, changed pose, changed size, nonfinite CFrame and missing CFrame.
- Earlier independent manifest probes rejected missing authored coverage, duplicate ID, missing local source and nonnumeric cloud ID; those checks remain in the production repository validator.

[GitHub Verify run 42512058874](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/42512058874) completed successfully on corrected source `8147d1c`, including clean dependency installation and the full host gate. Ordinary CI does not run Studio.

## Studio defect and correction

Initially MCP listed unnamed instances and returned **Place is not open**. The user opened the exact previous local test file manually, making document `p02-tests-72ab93292948.rbxlx` accessible through instance `cc341aae-47b9-43b5-a3c0-11e96d2f935e`, place ID 0, Studio `0.746.0.7461269`. The cloud place **C130 - Shootout** (`86732903023804`) was preserved.

The user reported a rectangle/divider instead of the circular battlefield. Independent engine inspection confirmed that GroundDisk, GroundSpawn and ShelterRoof all loaded at the origin with identity CFrames, despite their intended distinct poses. The [broken-baseline capture](p02/broken-baseline.jpg), inspected by the coordinator, shows the upright disk and stacked parts. The [machine report](p02/broken-baseline.json) records one actual Play client, server startup rejection `ground geometry does not match circle configuration`, server bootstrap timeout, client bootstrap unavailable, no BootstrapStatus and no ServerTestReport. The test document was stopped cleanly. This is a material defect affecting A1–A5; the earlier passing host checks did not prove a working map.

The developer corrected every authored part to canonical CFrame and strengthened generated-artifact checks. Existing `Map.spec` assertions now additionally verify the loaded ground-disk, spawn and roof poses. Expected engine counts remain 23 server / 2 client; these are expectations, not discovered or passed counts.

## Corrected Studio acceptance and walking review

The user opened corrected `p02-tests-5c809beff70b.rbxlx`, making intended local instance `574c4eb0-6eaf-4f2e-beb3-8666a0066bda` accessible. The tester verified document identity, place ID 0, Studio `0.746.0.7461269`, correct disk position `(0,-2,0)` with vertical cylinder axis, and spawn `(0,0.05,120)` before Play. The cloud place and old broken document remained untouched. No live authored patch was needed.

The [final independent tester report](p02/final-tester-report.md) maps all criteria. The [structured Studio report](p02/studio-report.json) preserves actual reports, TestEZ console, context/client counts, route targets/timing, avatar dimensions, boundary probes and cleanup. Client identifiers are omitted; no counts are altered. The [pre-acceptance record](p02/pre-acceptance-studio-record.json) preserves earlier access gaps as history.

Two fresh Play sessions each discovered/passed **23 server / 2 client cases**, zero failures/skips/errors, with **one actual client** and deterministic seed 1. These are repeated executions of the same cases, not 50 unique cases. Aggregate runner labels remain `P01-server` / `P01-client`; actual console output includes Foundation and Map cases. Each run had one BootstrapStatus, one GUI and no MapFixture leftovers. Stop between sessions and final Stop restored zero players, no runtime status/report/fixtures and 117 authored map descendants. The corrected document was left in Edit.

The real Map cases passed loaded-transform validation; nine numbered ground anchors, one launcher and invalid geometry/count/clearance/elevation rejection; both 4×6×4-stud clearance routes sampled every 0.5 stud with support rays; permanent/breakable cover metadata and raycasts, nine protected anchors across eight orbit phases and eight exposed firing positions; containment and disconnected cleanup; and two rebuilds comparing IDs/poses/counts after deleted cover and transient insertion.

The operated R15 avatar had HipHeight 1.998025 studs, root size 2×2×1, and visual/accessory extents 4.228424×6.365918×2.915490. This actual avatar differs from the 4×6×4 fixture. All 18 route navigation steps succeeded: west spawn-to-launcher, east launcher-to-spawn, and east spawn-to-launcher. Health remained 100; no jumps, destruction or ammunition were needed. West batch wall time was 16.4 seconds including capture/query overhead, while east reverse and forward navigation tool totals were 15.847 and 15.655 seconds. These are observations, not performance budgets.

For actual wall contact, the avatar moved from x169.27 toward x195 for two seconds and stopped at x177.949 inside the boundary. A controlled server position `(195,3,0)` returned to Ground05 `(0,3,120)` within 0.25 seconds; the client observed the return. Four cardinal perimeter views at radius 180/altitude 140 and an overview showed open lanes and stable shelter/ruin silhouettes. Eight-phase automated rays establish sight-line behavior; there is no active aircraft yet.

Observed viewport: 1081×619, Automatic graphics; captures: 1886×1080. The tester found the two doorways, teal/ochre lanes, gold marker and orange boundary readable. The coordinator inspected all ten captures: [overview](p02/final/overview.jpg), [spawn](p02/final/spawn.jpg), [west](p02/final/west-lane.jpg), [east](p02/final/east-lane.jpg), [marker](p02/final/launcher-marker.jpg), [boundary](p02/final/boundary-contact.jpg), and perimeter [east](p02/final/orbit-east.jpg), [north](p02/final/orbit-north.jpg), [south](p02/final/orbit-south.jpg), [west](p02/final/orbit-west.jpg). Captures supplement actual queries/walking rather than replace them.

No material tester findings or required P02 engine gaps remain. This is local one-client map acceptance, not multiplayer/combat/capacity/performance evidence or a universal avatar compatibility claim. There was no separate release-document Play: release source reconstruction/isolation is host-verified, and map engine/experience evidence used the separate test place.

## Documentation and delivery

The prior technical-writer review updated the whole player experience and engineering/package documentation, with no material rules contradiction. The writer additionally reviewed corrected source/tests and updated asset, development, testing, architecture and server-spec documentation for canonical CFrame, all 112 part comparisons, five corruption probes and loaded-transform assertions. It found no new contradiction. Repository and whitespace checks pass. Historical [initial tester report](p02/tester-report.md), [initial host log](p02/independent-verify.txt), [pre-correction final log](p02/final-verify.txt), manifests and unavailable Studio record remain as earlier evidence, not corrected-candidate acceptance.

Corrected source `8147d1c` is committed and pushed in PR #4. All required P02 checks and documentation review are satisfied; final evidence/status/PR delivery records are committed separately. Integration remains subject to the user’s merge authorization. No merge or Roblox publication occurred.

Final delivery: acceptance/documentation commit `7ac678e9bc250accd7704463ccec074712ff0686` is pushed to `origin/plan/02-warzone-map`. PR #4 was marked ready for review (draft false), verified open and unmerged. The coordinator’s final repository check passes (45 Markdown / 12 JSON) and whitespace check passes. Roadmap records P02 Complete and P03 Ready; P03 is not implemented. These final status/delivery edits change no tested source.
