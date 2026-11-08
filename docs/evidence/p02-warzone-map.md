# P02 battlefield evidence

2026-11-08. Source implementation and independent non-Studio checks are verified. Required Studio and walking/visual checks remain unavailable. Roadmap status is owned by [roadmap.md](../../roadmap.md); criterion results are in the [plan record](../../plans/02-warzone-map.md).

## Candidate and reconstructable assets

Independent tester source commit `028fe388cf3d92a57bea75f49cb585ff991e75e9`, tree `648f2411c5ac39d93cd5a1dcc9d7320e7ef87ecd`. Final source commit `9b5e7aa818fddd33d8d171a8938ed5a706abec26`, tree `df03853f249408a7b443278a1ae8025bdff4d767`, adds only the writer-requested ownership and clearance comment corrections. No behavior or tests changed. The coordinator reran the full host gate on this final source; [final log](p02/final-verify.txt). The [31-file source manifest](p02/source-manifest.json) hashes runtime source, tests, tools, assets and project definitions; combined path/byte SHA256 is `7a4b671db736301d214f25026641163fe9750ce739df670d8f8bd50f2cbcd8d1`. The [final source manifest](p02/final-source-manifest.json) records the comment-corrected candidate (manifest-file SHA256 `bb2a3fd8ba78f23d9e545fa13d49ff20546d2e6825c7eb7f1e86fdb0da44705c`). Subsequent prose/evidence changes do not change that runtime candidate.

| Build | SHA256 |
| --- | --- |
| `build/p02-game-fb969754a1ed.rbxlx` | `fb969754a1ed0e37a5ee3a4a9b4a822de74f7e3c72856958005125b36aa57bea` |
| `build/p02-tests-72ab93292948.rbxlx` | `72ab93292948d823ace9d889bdab2e94d957bdc6e92c773f8552806a59685eac` |

Generated builds stay ignored. The authored battlefield and cover template are original primitives, both recorded in the asset manifest, with no uploaded or external model dependency. The map center is `(0, 0, 0)`, radius 180 studs, future orbit altitude 140 studs, and kill plane Y = -30. These are tuning defaults. The gold marker is the future launcher location, not a working pickup. The separate lobby/operator deck has no role assignment or transport yet.

The coordinator reconstructed both artifacts from `git archive 9b5e7aa818fddd33d8d171a8938ed5a706abec26` extracted into a disposable directory, copying only installed locked `Packages` as a dependency. Commands there were `rojo build default.project.json --output build/game.rbxlx`, `rojo build test.project.json --output build/tests.rbxlx` and `python3 scripts/inspect_build.py`. Both SHA256 values matched the working candidate byte for byte. No working source or Studio-authored state was copied. The [bounded reconstruction log](p02/clean-reconstruction.txt) preserves the commands and hashes. This establishes reconstruction, not engine playability.

## Independent host verification

The developer and independent feature tester each ran `python3 scripts/verify.py` successfully on the unchanged runtime candidate. The preserved [independent log](p02/independent-verify.txt) records exact subcommands and output. Environment: macOS Darwin 25.6.0 arm64, Python 3.10.4, pinned Rojo 7.7.1, StyLua 2.6.0, Selene 0.32.0, Lune 0.11.1, Wally 0.3.2 and luau-lsp 1.70.1.

- Unit: 14 discovered, 14 passed, zero failed/skipped; four are new MapRules cases.
- Service integration: 2 discovered, 2 passed, zero failed/skipped.
- Formatting, lint (zero errors/warnings/parse errors) and strict Roblox-aware analysis passed.
- Intentional failing-test, empty-suite and invalid-type probes rejected as required.
- Both builds and release isolation passed: 138 release / 176 test Instances, 10 allowed runtime scripts in release.
- Four independent manifest probes rejected missing authored coverage, duplicate ID, missing local source and a nonnumeric cloud ID. All 31 source hashes and both build hashes matched the stable candidate.

The [tester report](p02/tester-report.md) found no material reproducible source defects. No developer correction cycle was needed. Static/source review does not prove clearance, cover collision, boundary behavior or cleanup in Roblox.

## Required Studio and experience evidence

The [structured Studio record](p02/studio-report.json) deliberately has null version/place/client/report fields: no actual engine run was observed. MCP listed IDs `4b6ae435-0060-4f42-b6fa-2ada6f17d931`, `cc341aae-47b9-43b5-a3c0-11e96d2f935e` and subsequently `eb029242-c828-4781-b342-5957b612ed43`, all with null names. State, Edit probes and `skill(rbx-unit-test)` returned **Place is not open**. Opening the local hash-labeled candidate did not expose a DataModel. The user confirmed sign-in and offered to dismiss dialogs; the tester rechecked after more than a minute with the same result. A manual open check of the exact candidate was requested.

No live place was mutated. A2's Instance anchor checks, A3's route/clearance/navigation, A4's cover/spawn/perimeter raycasts and containment, A5's two rebuilds, the existing server/client smoke regressions and focused walking/visual review are unrun. Expected 23 server / 2 client cases are source expectations, not discovered or passed counts. The automatic report suite labels remain `P01-server` / `P01-client`; tie future results to this P02 source/build and its Map.spec cases.

To resume, open the candidate test file as a separate local Studio document, verify its identity through MCP, consult relevant Studio skill guidance, start Play and collect both automatic reports, restart and repeat. Exercise the two marked routes, boundary and sampled sight lines; use the separate game build for the development experience check. Preserve the actual Studio version, client count, reports, viewport/graphics settings and observations. Do not run test mappings in a release place.

## Documentation and delivery

The technical writer reviewed actual implementation/tests and the verified evidence, then updated the player README, development/testing guides, architecture, requirements introduction, decisions and source/test/asset package READMEs. It found no material behavior contradiction. Two source comments were corrected as described above; the coordinator reviewed the prose and ran the final full verifier successfully (14 unit / 2 integration, zero failures/skips). Final `python3 scripts/check_repository.py` passed with 44 Markdown / 9 JSON files, and `git diff --check` passed.

Source and documentation/evidence commit `8214d7067cd178b54421ecd2d27f15eb74fa9871` are pushed in [draft PR #4](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/4). Required Studio evidence remains open; P02 is Blocked for that concrete external condition, and P03 remains Planned. No Complete claim, merge or Roblox publication is made.

[GitHub Verify run 42511523878](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/42511523878) completed successfully on documentation/evidence commit `8214d7067cd178b54421ecd2d27f15eb74fa9871`. Job `Static, unit, service and artifact gates` (128825427887) passed on `ubuntu-latest` / Python 3.12, including exact dependency installation and the full verification step. Later delivery-record edits are prose/evidence only.

The user subsequently reported that Studio still cannot open the file. Narrow local-log inspection found repeated `RobloxStudioPluginOTADownloadLock` acquisition failures in newer Studio instances. This is a possible startup blocker, not evidence of a malformed candidate or a proven root cause. The user was advised to save work, quit Studio instances themselves and reopen the candidate; exact error text was requested. No process was terminated, no settings were edited and no engine pass was inferred. The final test build filename is `build/p02-tests-72ab93292948.rbxlx`.
