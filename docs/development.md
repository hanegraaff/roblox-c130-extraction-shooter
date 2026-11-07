# Development guide

## Start with the current scaffold

This is a Git-first Roblox project. Gameplay implementation begins with [Plan 01](../plans/01-foundation.md). The current build creates an empty DataModel with explicit source/asset containers; it is not a playable level.

Prerequisites: Git, Python 3.10 or newer, and the pinned Rojo CLI. Install [Rokit](https://github.com/rojo-rbx/rokit) using its official instructions, then run these commands from the repository root:

```sh
rokit install
python3 scripts/verify.py
```

`rokit.toml` pins Rojo 7.7.1. Alternatively install that release from [Rojo's releases](https://github.com/rojo-rbx/rojo/releases/tag/v7.7.1) and put `rojo` on PATH. The verifier checks the version. Builds are written to `build/game.rbxlx` and `build/tests.rbxlx`; they are ignored by Git.

For documentation-only work, run:

```sh
python3 scripts/check_repository.py
```

This checks repository structure and local file links. It does not check remote website availability or Markdown heading anchors. The full verification entrypoint also builds both project mappings and fails if Rojo is missing.

## Roblox Studio workflow

Install Roblox Studio and the matching official Rojo plugin when you start implementation. Open a disposable local development place, then run:

```sh
rojo serve default.project.json
```

Connect the Studio Rojo plugin to the local server. Verify the target place before syncing. For engine tests, use a separate test place and `rojo serve test.project.json`; never publish that test place as the game.

Plan 01 adds executable bootstraps, strict Luau/tooling pins, test dependencies, and instructions for running the engine suite. Until then there is no `test:studio` command and no playable scene. If Studio's Codex integration is needed, use the Roblox setup workflow to connect the installed Studio instance; do not assume the tool connection exists because Studio is installed.

Source files drive managed scripts. Studio-built models/world changes must be exported into `assets/` and entered in the manifest, then rebuilt from a clean checkout. Stop simulation before authoring/exporting. Do not preserve transient playtest objects as authored assets.

## Implement the next capability

In Codex, invoke:

```text
Use $implement-next-plan to implement the next eligible plan in this repository.
```

The [skill](../.agents/skills/implement-next-plan/SKILL.md) chooses the next ready plan, delegates implementation, independent testing and documentation, and closes one increment with evidence. Repository-local skills live under `.agents/skills`; roles live under `.codex/agents`, following [OpenAI skill documentation](https://developers.openai.com/codex/skills) and [custom-agent documentation](https://developers.openai.com/codex/subagents).

Routine fixes can be requested directly. There is no need to run the full feature loop to correct a typo. The loop does not publish Roblox automatically or merge without authorization.

## Branches, CI and review

Use `plan/NN-short-name` for feature branches unless the user requests a name. Inspect uncommitted work and fetch before branching. Do not discard another person's changes. Each feature PR explains the player-visible result, plan/requirements, automated results, Studio evidence and limitations. Use the supplied PR template.

The current GitHub workflow runs repository checks and both Rojo builds. P01 expands it to the full static/unit/integration gate. Ordinary CI does not run Roblox Studio; attach required engine evidence separately. CI green is necessary but does not waive engine acceptance.

After verifying the final candidate, commit and push the source and evidence. Mark a plan Complete only under `AGENTS.md`'s definition of done; record whether its PR is still open. Before starting a dependent plan, use a branch containing the completed dependency; do not accidentally branch from an older main that lacks it.

## Release preparation and publication

P12 creates a release record with the verified source commit, build hash, asset-manifest version, exact universe/place IDs, audience, test evidence and rollback build. A release uses `default.project.json`, never the test mapping. Verify that test helpers and development overrides are absent.

Publishing requires explicit authorization for that destination and audience. Source pushes and draft PRs are part of development; they are not Roblox publication. If authorization or access is missing, keep the tested candidate ready and report what is needed. Do not invent IDs or silently create a new experience.

Player data is not stored in Git. The MVP has no persistent inventory/progression and needs no DataStore access. Future persistence must add isolated test data and migration/failure tests before use.
