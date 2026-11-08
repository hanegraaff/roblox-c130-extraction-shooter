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

Not implemented. Record A1–A6 → actual test files/commands/results, tested commit/tree, CI link, Studio report, tester findings and docs review. Record missing tools/access as a concrete blocker, never a passing substitute.
