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

## Connect Roblox Studio MCP

The preferred interactive workflow uses Roblox Studio's **built-in MCP server** with Codex or the ChatGPT desktop app on the same Mac/Windows machine. MCP lets the agent inspect the open place and use available Studio editing and playtest tools; it does not by itself sync this repository or create a Roblox experience. Follow the [official connection guide](https://create.roblox.com/docs/studio/mcp) for the current UI and tool capabilities.

1. Open Roblox Studio, sign in to the intended Roblox account yourself, and open a place. A disposable Baseplate is sufficient for the initial connection; a local place does not need a cloud place ID.
2. Open **Assistant → … → Settings → MCP Servers** (older Studio versions use **… → Manage MCP Servers**). Enable **Studio as MCP server**. Under **Quick Connect**, enable **ChatGPT (codex)** if it is available. Studio's setting is per account.
3. If Quick Connect is unavailable, use the Roblox setup skill's manual registration instructions. Check for an existing `Roblox_Studio` entry first and do not add a duplicate. On macOS the Studio-supplied command is `/Applications/RobloxStudio.app/Contents/MacOS/StudioMCP` when installed in `/Applications`; it is not a project script or a credential.
4. Open a new Codex thread or restart the ChatGPT desktop app so the server's tools load. Ask the agent to continue Roblox setup; it should call `list_roblox_studios`, select the intended instance and inspect the place. If multiple Studio instances are open, identify the intended one before any write.

Signing in gives Studio the account context; the MCP connection is to a local open Studio instance, not a permanent link between GitHub and a Roblox account. A local place is enough for early development. Creating or publishing an experience in Roblox Cloud requires an authorized account/owner and the separate release approval in this repository's instructions. Do not put Roblox passwords, tokens, or other credentials in Git.

## Sync this repository with Studio

Install Roblox Studio and the matching official Rojo plugin when you start implementation. Open a disposable local development place, then run:

```sh
rojo serve default.project.json
```

Connect the Studio Rojo plugin to the local server. Verify the target place before syncing. For engine tests, use a separate test place and `rojo serve test.project.json`; never publish that test place as the game.

Plan 01 adds executable bootstraps, strict Luau/tooling pins, test dependencies, and instructions for running the engine suite. Until then there is no `test:studio` command and no playable scene. Studio being installed does not mean MCP is connected; verify the handshake above. Keep Rojo as this project's chosen synchronization mechanism. Roblox also documents Script Sync, but do not enable both for the same instances without an explicit migration and ownership decision.

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
