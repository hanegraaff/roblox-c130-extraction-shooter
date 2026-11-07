# Project instructions

## Purpose and sources of truth

Build the Roblox asymmetric extraction shooter described in [game-design.md](game-design.md): one player operates an orbiting C-130-style gunship while 5–9 ground players collect three shared objectives and extract. Read that document, [requirements.md](requirements.md), [architecture.md](architecture.md), [roadmap.md](roadmap.md), and the selected plan before implementation.

Use this conventional uppercase filename for Codex discovery. Do not create a second, case-only `agents.md` file. User instructions take precedence; update the affected design and plans when the user changes direction. Distinguish decisions from tuning defaults in [docs/decisions.md](docs/decisions.md).

## Work in coherent increments

- Implement one eligible plan at a time. Use the repository's [feature-loop skill](.agents/skills/implement-next-plan/SKILL.md) when asked to implement the next plan. That workflow delegates to a developer, tester, and technical writer; ordinary small edits do not require delegation.
- Preserve unrelated changes. Inspect the branch and remote before editing or pushing. Use GitHub at `https://github.com/hanegraaff/roblox-c130-extraction-shooter` as the source repository.
- Keep roadmap status in `roadmap.md` only. Record implementation and validation evidence in the plan's completion record. Do not mark incomplete work complete or automatically start another plan.
- This initial repository is a design and build scaffold. Plan 01 establishes executable Luau and Studio tests; their absence must not be described as passing game tests.

## Human-readable Luau

- Use `--!strict` in first-party Luau. Prefer small cohesive modules, explicit types, descriptive names, straightforward control flow, and composition over inheritance. Avoid service locators, generic frameworks, circular dependencies, and giant scripts.
- Keep Roblox-independent rules deterministic. Inject time, randomness, world queries, and transport at boundaries. Express durations in seconds, positions in studs, angles in radians, and health/damage in named game units.
- Document every module's responsibility, execution side, dependencies, and important invariants in a header. Document exported types and callable APIs, class-like constructors and methods, lifecycle/cleanup behavior, and non-obvious private algorithms. Explain input/output contracts, failure behavior, authority, yielding, and units where relevant. Do not narrate obvious syntax.
- Keep a short README in each logical source package. Update it when the package boundary or public API changes. Follow [docs/code-style.md](docs/code-style.md) for examples and formatting.
- Prefer explicit errors/results for expected rejection; reserve assertions for violated internal invariants. Never swallow errors or scatter `any` to silence the type checker.
- Own and disconnect event connections, cancel tasks, and destroy temporary Instances at round reset or controller teardown. Initialization and shutdown must be testable and idempotent.

## Authority and fair play

- The server owns roles, round deadlines, ammunition, cooldowns, damage, objectives, destruction, extraction, and results. Clients send bounded intent, never authoritative hits, damage amounts, inventory totals, or victory claims.
- Validate every remote at runtime: payload shape and size, finite numbers, role, round ID, life state, item ownership, rate, range, and line of sight as applicable. Reject stale/replayed requests and test rejection without mutation.
- Solid cover blocks thermal highlighting and damage according to the explicit rules in `game-design.md`. Client effects cannot change collision, health, or objective state. Spectators cannot act in the round.
- Keep server-only rules and assets out of ReplicatedStorage. Do not mistake replicated data for a security boundary.

## Tests and evidence

- Implement tests with each behavior change. Cover normal behavior, boundaries, invalid input, timing conflicts, disconnects, and cleanup as appropriate. Trace acceptance criteria to named tests.
- Use fast deterministic Luau unit tests for rules; service integration tests with controlled adapters for orchestration; real Studio tests for Instances, raycasts, camera behavior, collision, and replication. Test doubles do not prove engine behavior.
- Follow [docs/testing.md](docs/testing.md). Run the plan's required gates. Report exact commands, environments, counts, failures, and unavailable checks. Zero discovered tests, skipped required tests, or an unavailable Studio connection are not a pass.
- Keep tests out of release places. Never use production player data or enable test-only role/minimum-player overrides in a published build.
- Automated checks are the primary acceptance evidence. Add focused visual/playability review for things tests cannot establish: thermal legibility, cover readability, camera feel, effects, sound, and balance. A screenshot alone is not multiplayer validation.

## Documentation and assets

- The root README addresses players first: premise, both roles, how a round works, controls, availability, and limitations. Revise it to describe the whole current experience. Clearly label planned behavior until it exists; keep implementation history in plans and the roadmap.
- Put contributor setup and engineering detail in `docs/development.md`, `architecture.md`, and package READMEs. Maintain commands, relative links, diagrams, test instructions, and asset provenance together with changes.
- Git must reconstruct the game: code, project mappings, world definitions or exports, configuration, and an asset manifest. Follow [assets/README.md](assets/README.md). Never leave a required Studio-only edit unexported.
- Do not commit credentials, runtime player data, caches, generated builds, or unlicensed assets. Avoid opaque external model scripts; inspect and remove unintended code before use.

## Definition of done and delivery

A plan is complete when its acceptance criteria pass, required Studio evidence exists, the tester's material findings are resolved, documentation matches the implementation, and the source/evidence are committed and pushed. Record PR/commit and verification facts, not promises. A complete plan can still have an unmerged PR; record integration separately.

Open a reviewable PR for a feature increment when possible. Do not merge without the user's authorization. Publishing to Roblox is a separate release action and requires explicit authorization for the named experience/place and audience. Preparing a build or creating a PR does not authorize publication. Reuse authorization already given in the conversation; do not introduce repeated approval checkpoints.
