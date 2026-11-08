# P01 foundation verification

## Environment and source

- Execution date: 2026-11-08, macOS development workstation.
- Starting source: `ce4fa767ea15495770043f453499bfa8b7ba7103` on `main`, matching `origin/main`; clean working tree before P01.
- Feature branch: `plan/01-foundation`.
- Initial Studio connection: `1ef60301-a4e1-43c6-ab80-5eed1e109fe2`, “C130 - Shootout”, place ID `86732903023804`, Studio `0.746.0.7461269`. Read-only inspection found the default Terrain, Camera, Baseplate and SpawnLocation. This existing place is preserved; candidate engine runs use separate local build documents.
- Baseline repository checker: `python3 scripts/check_repository.py` passed (39 Markdown files, 3 JSON files). This baseline is scaffold validation, not a game test.

## Tested candidate and tools

The tested Git source tree is `490df5b6844ee898d50bb24f5d8836e9fd9ecdf8`, committed unchanged as `8337a79c70fc25f32fc37c65d877806f0677b80a` after independent verification. No source/test/configuration changes followed this snapshot at the time of these checks. Documentation and delivery records are recorded separately below.

| Tool/dependency | Exact version |
| --- | --- |
| Setup bootstrap / Rokit | 1.2.0 |
| Rojo | 7.7.1 |
| StyLua | 2.6.0 |
| Selene | 0.32.0 |
| Lune | 0.11.1 |
| Wally | 0.3.2 |
| luau-lsp | 1.70.1 |
| Wally TestEZ | 0.4.1 |
| Local Python | 3.10.4 |

Setup hash-checks Rokit and the upstream Roblox `globalTypes.d.luau` definitions pinned to luau-lsp 1.70.1. Definitions SHA256: `2857efa8245485f8c25c19c018ee1ef9b46afab4efd2ea70fc3257cd3faf7080`. No broad `any` engine-global shim is used.

| Build | SHA256 |
| --- | --- |
| `build/game.rbxlx` | `7475bc8887a563185eb592be52127b223979b002884fc98affa02adeb0ed06d0` |
| `build/tests.rbxlx` | `6c380eeb82954d9ee0e571d0974117cd964767587168cd76978aa51e8e2b8c08` |

Both hashes were reproduced by the independent clean export/install/build below. Generated places are ignored, reconstructable artifacts.

## Non-Studio acceptance

Three full gate executions passed on the same source: developer, independent tester, and coordinator's clean source export. The tester's command was `python3 scripts/verify.py`; see the preserved [independent gate log](p01/independent-verify.txt) and [clean installation/gate log](p01/clean-install.txt).

For the clean run, the coordinator exported `git archive 490df5b6844ee898d50bb24f5d8836e9fd9ecdf8` into a new temporary directory with no `.tools`, `Packages`, or `build` directory. It ran `python3 scripts/setup.py` (exit 0), then `python3 scripts/verify.py` (exit 0). Standard user Rokit/Lune tool caches were reused by the installers; generated checkout dependencies and definitions were installed afresh. The clean working directory was `/var/folders/9f/8_pj_z1j57l5dbn4w71mg3p00000gn/T/c130-p01-clean-6o61s2i6`, local log `/tmp/p01-clean-install.log`.

| Criterion | Actual command/test | Observed outcome |
| --- | --- | --- |
| A1 | Clean export: `python3 scripts/setup.py`, `python3 scripts/verify.py` | Both exit 0; all six pinned tool versions checked; repository, formatting, lint, strict analysis, suites, rejection probes, both builds, artifact isolation pass. |
| A2 | `lune run scripts/run_tests.luau unit`; `tests/unit/{Validation,Config,RateLimit}.spec.luau` | 10 discovered, 10 passed, 0 failed/skipped. Includes finite endpoints, NaN/infinity, malformed/oversized/cyclic/metatable payloads, invalid bounds, configuration, exact token refill and unchanged rejected state. |
| A2 | `lune run scripts/run_tests.luau integration`; `tests/integration/Lifecycle.spec.luau` | 2 discovered, 2 passed, 0 failed/skipped: two idempotent start/stop cycles restore listener/task counters; partial initialization failure rolls back and can retry. |
| A3 | `verify.py:negative_probes`, temporary copy of `Validation.spec.luau` replaced by an intentional failure | Runner discovers 6, passes 5, fails 1 with `deliberate failure`; exit 1 accepted only with intended diagnostic. |
| A3 | Same disposable fixture with an empty unit directory | `empty required suite: unit`, exit 1; no zero-count success. Fixture is removed. |
| A4 | Main `luau-lsp analyze --platform=roblox --sourcemap=build/sourcemap.json --definitions=@roblox=.tools/globalTypes.d.luau src tests scripts/run_tests.luau` | Exit 0 using genuine pinned engine definitions. |
| A4 | Disposable `build/StrictTypeProbe.luau`: string assigned to `Part.Anchored` and a `number` | Exit 1 with expected boolean/string and number/string diagnostics; probe removed in `finally`. |
| A5 | Both `rojo build` commands, then `python3 scripts/inspect_build.py` | Release: 18 Instances and exactly 8 runtime scripts. Test: 54 Instances. Release excludes TestEZ/packages/specs/runners/fixtures/development overrides. Both contain mapped bootstraps and the authored spawn. |

StyLua returned success; Selene reported 0 errors, 0 warnings, 0 parse errors. The standalone luau-lsp sourcemap-watch registration warning is informational; analysis completed successfully. These gates establish foundation behavior, not later gameplay, multiplayer combat or performance.

## Studio acceptance and experience review

Independent tester owns live-place operations. Final candidate local documents are selected by the hash-bearing filenames, without modifying the original cloud place. First test document: `a848de82-e636-465a-bb35-8965796043a6`, `p01-tests-6c380eeb8295.rbxlx`, place ID 0, Studio `0.746.0.7461269`.

First actual Play smoke: server 14/14, client 2/2, 0 failures/skips/errors, one actual network client. Server cases include the 12 shared/service cases plus bootstrap resource restart and spawn/raycast assertions. Client cases verify replicated test status/character and repeated panel lifecycle. The tester observed one `BootstrapStatus`, one `FoundationStatus`, a spawned character and the `Test` label.

After Stop, the Edit context had zero players, no runtime status Folder and no server test report. Restarting Play ran server 14/14 and client 2/2 again, with one actual client and zero failures/skips/errors; exactly one status Folder and one GUI existed. A6 passed on both cycles. These are two runs of the same cases, not additional unique test coverage.

The separate development document `87b74d0b-6915-425e-83bf-0a4a3983f79d`, `p01-game-7475bc8887a5.rbxlx`, place ID 0, spawned a healthy character (health 100) standing on the Plastic platform. Its label read `Development`, one status/GUI existed, and TestPackages, development settings, server runner and client runner were absent. The console was empty. Both candidate documents were stopped in Edit at handoff; the original place and initial preview remained untouched.

Visual review used viewport 1081×619 with Automatic graphics quality. The 400×86 status label reported `TextFits = true`; its high-contrast three-line text distinguished Test from Development. Core chat help sat above the panel's text. Captures are [test Play](p01/test-play.jpg) and [development Play](p01/development-play.jpg). The coordinator inspected both captures. These observations establish shell legibility and spawn, not camera/combat feel or performance budgets.

The preserved [machine-readable Studio report](p01/studio-report.json) records source, environment, build hashes, actual client count, counts for each context/cycle, cleanup observations and limitations. Suite results came from `Workspace.ServerTestReport` on the server and `Players.LocalPlayer.PlayerScripts.ClientTests.ClientTestReport` on the client; the tester also inspected actual runtime Instances, character state and console output through Studio MCP.

## Review and delivery

Independent feature tester reported no material defects or unresolved required checks for P01. No developer correction cycle was needed. This remains a foundation shell: no roles, rounds, battlefield or weapons are implemented; no gameplay/capacity/performance claim follows from one-client smoke tests.

The technical writer reviewed the actual implementation/tests/evidence and updated the player README, development/testing guides, architecture, requirements introduction, source/test package READMEs and asset documentation. It found no material implementation contradiction or missing source contract. The coordinator reviewed the resulting prose. No behavior changed after the tested source snapshot; only ignored Markdown and durable evidence/delivery records were added afterward.

Source commit `8337a79c70fc25f32fc37c65d877806f0677b80a` and documentation/evidence commit `86d0dd01898a9ed21dcd30aedb5f0236a0a041ce` were pushed to `origin/plan/01-foundation`. [PR #3](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/3) was open and unmerged at initial delivery. [GitHub Verify run 42502874041](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/42502874041) succeeded on the documentation/evidence candidate: job `Static, unit, service and artifact gates` (128799204232), including both setup and verification steps, completed successfully on `ubuntu-latest` with Python 3.12.

The coordinator's final `python3 scripts/check_repository.py` passed (42 Markdown files, 5 JSON files), and `git diff --check` passed. All required P01 checks are satisfied; no material tester findings or documentation gaps remain. Final roadmap/PR/evidence edits are records only. P02 is Ready and has not been implemented. PR integration is separate from plan completion. No Roblox publication is requested or performed.

Integration, 2026-11-08: on explicit user authorization, the main README gained manual Studio play/restart and automatic test instructions in `43ad1ac5a7cb90e1d3d4f0ec1519e97c10fb2126`. Repository/diff checks and [GitHub Verify run 42510271531](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/42510271531) passed before merge. PR #3 then merged into `main` at `b62f6132ea0998d880daab2d1a5d86b7ab6cd95d`, verified through GitHub PR metadata and a local fast-forward. The tested gameplay source is unchanged; P02’s prerequisite is now integrated.
