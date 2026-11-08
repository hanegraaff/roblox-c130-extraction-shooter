# P02 battlefield evidence

2026-11-08. Corrected source and independent host verification are delivered in [draft PR #4](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/4). The first accessible Studio candidate exposed a real asset-transform defect. That defect is corrected in source; required engine acceptance of the corrected candidate remains pending. [Roadmap](../../roadmap.md) owns status; the [plan](../../plans/02-warzone-map.md) maps criteria.

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

The automated open command for corrected `p02-tests-5c809beff70b.rbxlx` created unnamed instance `01c3e5f9-86c4-46d5-901a-22b98004c052`, still returning **Place is not open** after a bounded recheck. The tester did not retest stale source. The user has been asked to open the corrected local document through File → Open from File in the working Studio window. Required corrected-source anchor/route clearance, cover/perimeter rays, containment, two rebuilds, automatic server/client regressions and focused walking/visual review remain pending.

## Documentation and delivery

The prior technical-writer review updated the whole player experience and engineering/package documentation, with no material rules contradiction. The writer additionally reviewed corrected source/tests and updated asset, development, testing, architecture and server-spec documentation for canonical CFrame, all 112 part comparisons, five corruption probes and loaded-transform assertions. It found no new contradiction. Repository and whitespace checks pass. Historical [initial tester report](p02/tester-report.md), [initial host log](p02/independent-verify.txt), [pre-correction final log](p02/final-verify.txt), manifests and unavailable Studio record remain as earlier evidence, not corrected-candidate acceptance.

The corrected source is committed and pushed in draft PR #4. P02 is Blocked on the corrected document becoming accessible, and P03 remains Planned until the required corrected engine and experience gates pass. The final list recheck still showed only the old named test document and the cloud place; the corrected instance remained unnamed. No merge or Roblox publication occurred.
