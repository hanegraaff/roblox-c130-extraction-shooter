# Project instructions

## Purpose and sources of truth

Build the Roblox players-versus-C-130 game described in [game-design.md](game-design.md): one operator circles a circular battlefield while one team of 5–9 M-7-equipped ground players tries to destroy the plane. One rocket launcher is placed on the map; three direct hits destroy an undamaged plane, and rifle fire also chips away at its health. Read that document, [requirements.md](requirements.md), [architecture.md](architecture.md), [roadmap.md](roadmap.md), and the selected plan before implementation.

Use this conventional uppercase filename for Codex discovery. Do not create a second, case-only `agents.md` file. User instructions take precedence; update the affected design and plans when the user changes direction. Distinguish decisions from tuning defaults in [docs/decisions.md](docs/decisions.md).

## Work in coherent increments

- Implement one eligible plan at a time. Use the repository's [feature-loop skill](.agents/skills/implement-next-plan/SKILL.md) when asked to implement the next plan. That workflow delegates to a developer, tester, and technical writer; ordinary small edits do not require delegation.
- Preserve unrelated changes. Inspect the branch and remote before editing or pushing. Use GitHub at `https://github.com/hanegraaff/roblox-c130-extraction-shooter` as the source repository.
- Perform every user-assigned coding task on its own dedicated branch before editing, whether it implements a roadmap plan or is an unrelated fix, tooling change, refactor or maintenance task. Use a separate branch for documentation and steering changes too. Never work directly on `main` or add a new task to an unrelated task's branch. Resume the same task on its existing dedicated branch; delegated agents share that task branch under coordinated ownership. Branch from source containing any required dependencies, including an unmerged dependency branch when necessary. Use `plan/NN-short-name` for plan increments and a descriptive `fix/`, `chore/` or `docs/` branch for other tasks, unless the user specifies another name.
- Keep roadmap status in `roadmap.md` only. Record implementation and validation evidence in the plan's completion record. Do not mark incomplete work complete or automatically start another plan.
- This initial repository is a design and build scaffold. Plan 01 establishes executable Luau and Studio tests; their absence must not be described as passing game tests.

## Roblox Studio MCP and source ownership

- Use Roblox Studio's built-in MCP server as the primary way to inspect the open place, operate Studio, run supported playtests, and collect engine evidence. Check `list_roblox_studios` and use the intended instance/place ID before making changes; if several places are open and the target is unclear, ask which one. Consult the connected Studio server's `skill` tool for relevant version-specific guidance.
- MCP controls a live Studio session; it does not link GitHub to a Roblox account or replace source synchronization. Git is the source of truth. Edit Rojo-managed scripts/definitions in the repository and sync them into Studio. Export intended Studio-authored world/assets to their managed paths and manifest; never leave an MCP-created change solely in Studio or assume it synchronized back to Git.
- Reuse a working Studio document and its confirmed `studio_id` across source iterations. Keep the matching Rojo live-sync server connected, sync repository changes into that document, then start a fresh Play session. Do not run `open -a RobloxStudio`, an executable file-open command, or repeated launch retries to refresh an already-open project: these can create additional Studio processes, including unnamed instances that report **Place is not open**. MCP has no local-place file-open operation. For the initial macOS launch with Studio fully closed, use `python3 scripts/launch_studio.py <place>`; it refuses an additional process when Studio is running. If a genuinely new document is required, attempt it once and verify its identity before continuing; an unavailable instance is not a reason to launch more copies.
- Coordinate agents that share a Studio instance: only one may mutate a given place at a time, and the tester must exercise the candidate the developer actually delivered. Preserve unsaved work, use a separate test place for test mappings, and confirm the target before syncing or writing.
- If Studio MCP is unavailable, follow [the setup guide](docs/development.md#connect-roblox-studio-mcp) and continue independent repository work. Do not claim real-engine checks passed or mark a plan complete when its required Studio evidence is unavailable.

## Human-readable Luau

- Use `--!strict` in first-party Luau. Prefer small cohesive modules, explicit types, descriptive names, straightforward control flow, and composition over inheritance. Avoid service locators, generic frameworks, circular dependencies, and giant scripts.
- Keep Roblox-independent rules deterministic. Inject time, randomness, world queries, and transport at boundaries. Express durations in seconds, positions in studs, angles in radians, and health/damage in named game units.
- Document every module's responsibility, execution side, dependencies, and important invariants in a header. Document exported types and callable APIs, class-like constructors and methods, lifecycle/cleanup behavior, and non-obvious private algorithms. Explain input/output contracts, failure behavior, authority, yielding, and units where relevant. Do not narrate obvious syntax.
- Keep a short README in each logical source package. Update it when the package boundary or public API changes. Follow [docs/code-style.md](docs/code-style.md) for examples and formatting.
- Prefer explicit errors/results for expected rejection; reserve assertions for violated internal invariants. Never swallow errors or scatter `any` to silence the type checker.
- Own and disconnect event connections, cancel tasks, and destroy temporary Instances at round reset or controller teardown. Initialization and shutdown must be testable and idempotent.

## Authority and fair play

- The server owns roles, round deadlines, ammunition, cooldowns, damage, launcher ownership, cover/aircraft destruction, weapon selection, and results. Clients send bounded intent, never authoritative hits, damage amounts, rocket-hit totals, or victory claims.
- Validate every remote at runtime: payload shape and size, finite numbers, role, round ID, life state, weapon ownership, rate, range, and line of sight as applicable. Reject stale/replayed requests and test rejection without mutation.
- Solid cover blocks thermal highlighting and damage according to the explicit rules in `game-design.md`. Client effects cannot change collision, health, or launcher ownership. Spectators cannot act in the round.
- Keep server-only rules and assets out of ReplicatedStorage. Do not mistake replicated data for a security boundary.

The plane carries the 30mm GAU-23/A Chain Gun and 105mm M102 Howitzer; the user confirmed that the new heavy-panel damage rules apply to the existing 105mm weapon (D31). Weapon selection changes zoom without resetting cooldowns or panning offset. Operator WASD pans on desktop: A moves the camera left and D moves it right. A directional pad pans in its labelled directions on touch devices, and the mouse aims the reticle. Ground WASD movement is unchanged. The held camera angle stays relative to the circling aircraft; the 2026-11-12 revision allows roughly the outer 25% of the viewport to extend beyond the level edge in each direction. Keep the canonical aircraft orbit unchanged, the camera inward-facing and short of straight down, and sky out of view. Lens and pitch limits are tuning values in D40–D41; D42 records horizontal direction.

Design level-specific geometry and configuration as interchangeable inputs to shared systems. Every future level has a circling C-130. Panning, zoom, combat damage and building-panel demolition belong to the core game rules, not one map's scripts. The MVP still ships one circular level; additional playable levels and level selection are future work. Update the level contract, reconstruction, reset and acceptance plans before adding a second level.

The revised MVP doubles the current map diameter to 720 studs and requires terrain plus two large buildings and one smaller building, all at least two stories with usable upper floors. Building wall and roof panels must visibly progress to roughly half-destroyed after three direct heavy-cannon hits and disappear after three more; nine seconds of sustained on-panel 30mm fire must damage a panel. Actual bounded fragment physics and authoritative openings are MVP work, even with primitive art. Keep stable supporting structure; refined assets are later work. Proposed interruption/mixed-fire/debris defaults belong in decisions, not disguised as user-selected rules.

Ground wins on aircraft destruction; the C-130 wins on ground-team elimination or timeout. Do not reintroduce collection/escape mechanics.

## Tests and evidence

- Implement tests with each behavior change. Cover normal behavior, boundaries, invalid input, timing conflicts, disconnects, and cleanup as appropriate. Trace acceptance criteria to named tests.
- Use fast deterministic Luau unit tests for rules; service integration tests with controlled adapters for orchestration; real Studio tests for Instances, raycasts, camera behavior, collision, and replication. Test doubles do not prove engine behavior.
- Follow [docs/testing.md](docs/testing.md). Run the plan's required gates. Report exact commands, environments, counts, failures, and unavailable checks. Zero discovered tests, skipped required tests, or an unavailable Studio connection are not a pass.
- Keep tests out of release places. Never use production player data or enable test-only role/minimum-player overrides in a published build.
- Automated checks are the primary acceptance evidence. Add focused visual/playability review for things tests cannot establish: thermal legibility, cover readability, camera feel, effects, sound, and balance. A screenshot alone is not multiplayer validation.

## Documentation and assets

- The root README addresses players first: premise, both roles, how a round works, controls, availability, and limitations. Revise it to describe the whole current experience. Clearly label planned behavior until it exists; keep implementation history in plans and the roadmap.
- Always include one representative screenshot of current implemented progress near the top of the root README. Use an actual Studio/playtest capture committed to the repository, with a working relative image path, useful alt text and a caption identifying its stage/date. Refresh that image when visible progress changes; reuse a still-current capture for nonvisual tasks. Replace the representative image rather than accumulating a screenshot history. Never present planned art or a mockup as current gameplay.
- The root README is also the primary local how-to guide: prerequisites, obtaining/selecting the right source branch, dependency setup, building, starting Rojo, connecting its plugin in Edit mode, playing locally, running host and Studio tests, and updating the same local document after edits. Keep commands, project names, ports, expected outcomes and current availability accurate as the game changes. Routine setup and testing must be understandable from the README itself.
- Put advanced contributor setup and engineering detail in `docs/development.md`, `architecture.md`, and package READMEs, with links from the root how-to. Maintain commands, relative links, diagrams, test instructions, and asset provenance together with changes.
- Git must reconstruct the game: code, project mappings, world definitions or exports, configuration, and an asset manifest. Follow [assets/README.md](assets/README.md). Never leave a required Studio-only edit unexported.
- Do not commit credentials, runtime player data, caches, generated builds, or unlicensed assets. Avoid opaque external model scripts; inspect and remove unintended code before use.

## Definition of done and delivery

A plan is complete when its acceptance criteria pass, required Studio evidence exists, the tester's material findings are resolved, documentation matches the implementation, and the source/evidence are committed and pushed. Record PR/commit and verification facts, not promises. A complete plan can still have an unmerged PR; record integration separately.

Open a reviewable PR for a feature increment when possible. Do not merge without the user's authorization. Publishing to Roblox is a separate release action and requires explicit authorization for the named experience/place and audience. Preparing a build or creating a PR does not authorize publication. Reuse authorization already given in the conversation; do not introduce repeated approval checkpoints.
