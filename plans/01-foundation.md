# P01 — Executable foundation and tests

**Milestone:** M1. **Dependencies:** none. **Requirements:** R01, R13, R15. Status is tracked in [roadmap](../roadmap.md).

## Capability and player experience

Turn the empty source scaffold into a runnable development place with a safe temporary spawn and a small status panel. A tester can open it, spawn, and distinguish a running game bootstrap from the separate test environment. Combat, roles and the battlefield are later capabilities.

## Implementation

1. Add minimal server/client bootstraps with explicit component start/stop, cleanup ownership and strict types. Establish typed configuration validation and reusable finite-number/payload/rate validation needed by later network adapters; avoid speculative remotes.
2. Pin StyLua, Selene, Lune and Roblox-aware Luau analysis; record exact versions and commands. Add Wally/TestEZ with its lockfile for engine tests. Prove actual module loading in standalone and Instance-based runtimes rather than assuming compatible `require` paths.
3. Expand `scripts/verify.py` and CI with formatting, lint, type analysis, deterministic unit/service suites and both builds. Zero discovered tests and failures must return failure. Add a test-only Studio server/client bootstrap and a structured result report. Use the connected Roblox Studio MCP as the primary interactive test interface; verify the target place and actual tool capabilities before running it.
4. Keep test dependencies, fixtures, development settings and test runners out of the release DataModel. Add a build inspection assertion. The two-player override is test-only and cannot be enabled by a client.
5. Document setup from a clean clone, exact Studio run steps, tool versions, result interpretation and module contracts.

## Acceptance criteria

- **A1:** A clean tool/dependency install followed by `python3 scripts/verify.py` passes all named gates and builds both places.
- **A2:** Unit tests reject invalid/NaN/infinite configuration or payload values and accept valid boundaries; integration tests show start/stop can run twice without duplicate listeners/tasks.
- **A3:** A deliberately failing test in a disposable fixture makes the runner/gate fail; an empty suite also fails. Remove injected failures before delivery and record the observed exit codes.
- **A4:** A strict type error in a disposable first-party fixture fails analysis; Roblox globals are resolved by actual engine definitions, not broad `any` declarations.
- **A5:** Automated artifact inspection confirms the release place contains source bootstraps and excludes all test runners/dependencies/fixtures/overrides.
- **A6:** Studio runs one server and one client smoke suite against actual mapped modules, with nonzero counts and zero failures. Stop/restart produces no duplicate GUI or bootstrap resources.

## Focused human check

Open the development place and test place separately; verify spawn, status legibility and useful output. Record Studio version and screenshot if useful. This does not establish any multiplayer gameplay claim.

## Documentation changes

Update development/testing guides, source/test package READMEs and the root README's actual availability. Keep the game described as a development shell.

## Completion record

Implemented the development shell with a Git-authored temporary spawn, server bootstrap status, client status panel, explicit idempotent lifecycle composition, finite/configuration/payload/rate rules, pinned tooling and separate standalone/Studio test adapters. There are no gameplay remotes, roles, combat or rounds in this increment.

Tested source commit: `8337a79c70fc25f32fc37c65d877806f0677b80a`; tree: `490df5b6844ee898d50bb24f5d8836e9fd9ecdf8`. The [durable evidence report](../docs/evidence/p01-foundation.md) contains exact tool versions, commands, build hashes, bounded logs, captures and the machine-readable Studio report.

| Criterion | Tests/commands and actual result |
| --- | --- |
| A1 | Fresh source export, `python3 scripts/setup.py` then `python3 scripts/verify.py`: both exit 0 on macOS/Python 3.10.4. Developer and independent tester also ran the full gate successfully. Both Rojo build hashes reproduce. |
| A2 | `tests/unit/Validation.spec.luau`, `Config.spec.luau`, `RateLimit.spec.luau`: 10/10 under Lune; `tests/integration/Lifecycle.spec.luau`: 2/2. Finite/bounded inputs, no-mutation rejection, refill boundaries, repeated cleanup and rollback/retry pass. |
| A3 | `verify.py:negative_probes`: intentionally failed test returns exit 1 (5 passed/1 failed); empty unit suite returns exit 1. Both require intended diagnostics; disposable fixtures removed. |
| A4 | Strict Roblox-aware analysis of all first-party source/tests/runner passes with pinned genuine engine definitions. Disposable `Part.Anchored` boolean/string and number/string errors return exit 1; fixture removed. |
| A5 | `python3 scripts/inspect_build.py`: release has 18 Instances/8 runtime scripts; test has 54 Instances. Bootstraps/spawn present; all test packages/runners/specs/settings/overrides excluded from release. |
| A6 | Studio 0.746.0.7461269, local test build, seed 1, actual one server/one client: two full Play cycles each discover/pass server 14 and client 2, zero failures/skips/errors. Stop clears runtime state; restart retains one status Folder and one GUI. Separate development-build spawn/label/isolation review passes. |

Independent feature tester found no material defects or open P01 acceptance gaps. Visual observations at 1081×619/Automatic quality confirm readable Test/Development labels, fitted three-line text and a healthy avatar standing on the temporary platform. Original Studio place preserved; candidate documents stopped in Edit. These smoke tests make no multiplayer-capacity, combat or performance claim.

The technical writer reviewed the actual implementation/evidence and updated the player README, development/testing guides, architecture/current requirements, source/test package contracts and asset documentation. It reported no implementation contradiction or unresolved question. The coordinator reviewed those changes; subsequent prose is checked with `python3 scripts/check_repository.py` and `git diff --check`. No behavior changed after the tested source snapshot.

Delivery: source `8337a79c70fc25f32fc37c65d877806f0677b80a` and documentation/evidence `86d0dd01898a9ed21dcd30aedb5f0236a0a041ce` are pushed to `plan/01-foundation`. [PR #3](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/3) is open for review and unmerged. [GitHub Verify run 42502874041](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/42502874041) on the documentation/evidence candidate succeeded: both installation and the full verification job passed on `ubuntu-latest` with Python 3.12. Final record-only changes pass the repository checker (42 Markdown, 5 JSON) and `git diff --check`.

All P01 acceptance criteria and independent documentation review are satisfied. P02 is eligible without being implemented. Roadmap status remains authoritative. No Roblox publication or PR merge was performed.
