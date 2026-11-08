# Development guide

## Install and build from a clean clone

The current local place contains the circular greybox battlefield, a ground spawn, cover and location markers, server containment, and the bootstrap status panel. [P02](../plans/02-warzone-map.md) records its host, local Studio and focused walking acceptance evidence and limits; aircraft, combat and roles remain future work.

Prerequisites are Git, Python 3.10 or newer, system `curl`, and network access to GitHub tool releases and the Wally registry/CDN. The setup script supports macOS and Linux on arm64/aarch64 and x86_64. Roblox Studio itself runs on supported Mac/Windows computers; the repository’s automated setup does not currently support Windows.

From the repository root:

```sh
python3 scripts/setup.py
python3 scripts/verify.py
```

Setup downloads hash-checked Rokit 1.2.0, installs the exact tools below, installs TestEZ 0.4.1 through Wally with the committed lockfile, generates Lune type definitions, and downloads hash-checked Roblox engine definitions from the pinned luau-lsp release. It needs no Roblox account. Generated `.tools/`, `Packages/` and `build/` content stays out of Git. Rokit and Lune also maintain normal user-level tool/type caches.

| Tool | Pin | Purpose |
| --- | --- | --- |
| Rojo | 7.7.1 | DataModel mapping, sourcemap and builds |
| StyLua | 2.6.0 | Luau formatting |
| Selene | 0.32.0 | Luau linting |
| Lune | 0.11.1 | Deterministic standalone suites |
| Wally | 0.3.2 | Locked TestEZ dependency |
| luau-lsp | 1.70.1 | Strict analysis with actual Roblox definitions |

[rokit.toml](../rokit.toml) owns the six tool pins; [wally.toml](../wally.toml) and [wally.lock](../wally.lock) own TestEZ. The verifier rejects missing or mismatched tool versions, missing packages and changed engine definitions. If these checks fail, rerun setup and inspect its error rather than skipping the gate.

The full gate runs formatting, lint, strict type analysis, deterministic unit/service tests, intentional rejection probes, both builds, canonical authored-geometry checks and artifact isolation checks. Builds are `build/game.rbxlx` (release mapping, currently the greybox development build) and `build/tests.rbxlx` (test mapping). Open these files as separate local Studio documents; no cloud publication is needed.

For direct tool commands in a shell, add Rokit’s tool shims to PATH:

```sh
export PATH="$HOME/.rokit/bin:$PATH"
```

For documentation-only changes:

```sh
python3 scripts/check_repository.py
```

This checks local file links, JSON, mapped paths, asset-manifest references and coverage of every authored file under `assets/world` and `assets/models`. It does not check remote URLs or heading anchors. See the [testing guide](testing.md) for individual commands, report interpretation and separate required Studio runs.

## Connect Roblox Studio MCP

The preferred interactive workflow uses Roblox Studio's **built-in MCP server** with Codex or the ChatGPT desktop app on the same Mac/Windows machine. MCP lets the agent inspect the open place and use available Studio editing and playtest tools; it does not by itself sync this repository or create a Roblox experience. Follow the [official connection guide](https://create.roblox.com/docs/studio/mcp) for the current UI and tool capabilities.

1. Open Roblox Studio, sign in to the intended Roblox account yourself, and open a place. A disposable Baseplate is sufficient for the initial connection; a local place does not need a cloud place ID.
2. Open **Assistant → … → Settings → MCP Servers** (older Studio versions use **… → Manage MCP Servers**). Enable **Studio as MCP server**. Under **Quick Connect**, enable **ChatGPT (codex)** if it is available. Studio's setting is per account.
3. If Quick Connect is unavailable, use the Roblox setup skill's manual registration instructions. Check for an existing `Roblox_Studio` entry first and do not add a duplicate. On macOS the Studio-supplied command is `/Applications/RobloxStudio.app/Contents/MacOS/StudioMCP` when installed in `/Applications`; it is not a project script or a credential.
4. Open a new Codex thread or restart the ChatGPT desktop app so the server's tools load. Ask the agent to continue Roblox setup; it should call `list_roblox_studios`, select the intended instance and inspect the place. If multiple Studio instances are open, identify the intended one before any write.

Signing in gives Studio the account context; the MCP connection is to a local open Studio instance, not a permanent link between GitHub and a Roblox account. A local place is enough for early development. Creating or publishing an experience in Roblox Cloud requires an authorized account/owner and the separate release approval in this repository's instructions. Do not put Roblox passwords, tokens, or other credentials in Git.

## Sync this repository with Studio

For iterative source synchronization, keep one local development document and one separate local test document. Use Rojo live sync to update their managed content rather than opening a new hash-named build after each edit. Install the plugin from the pinned CLI once:

```sh
rojo plugin install
```

After setup, add Rokit’s tools to PATH as above. For the local test document, start:

```sh
rojo serve test.project.json --address 127.0.0.1 --port 34872
```

Stop Play in the intended local test document. Open **Plugins → Rojo**, connect to `localhost:34872`, and verify the project is **PlayersVsC130Tests** before applying its mapping. For a development document instead, serve `default.project.json` on a different explicit port, such as `34873`. Keep test and development connections separate; never connect the test mapping to the cloud/release place. On first plugin installation, save work and restart Studio if the toolbar button is missing in Edit mode or appears only during Play. Load the plugin in Edit before connecting.

If Connect reports **Http requests can only be executed by game server**, inspect the Studio mode first. A Play session with the Client view focused can produce this error. Stop Play, confirm the Edit DataModel is available, then reconnect; do not open another Studio instance to work around it.

For subsequent edits, keep the same confirmed MCP `studio_id`, edit repository source, let Rojo sync, inspect the expected source/world change through MCP, and start a fresh Play session. Stop Play before syncing the next candidate. A document's old hash-bearing filename does not prove which source it now contains: record the actual synced source commit, project and observed engine state. If a criterion specifically requires loading a generated place artifact, do that as a deliberate separate file-load check.

For the first launch with Studio fully closed on macOS, use the guarded helper:

```sh
python3 scripts/launch_studio.py build/tests.rbxlx
```

It validates the file, serializes concurrent launch attempts and uses the documented Studio `--task EditFile --localPlaceFile` arguments. If any Studio process is already running, it exits with status 2 and performs no launch. Resolve an existing/blocked session through MCP instead of retrying the launcher. Logs stay in ignored `build/studio-launch.log`.

On this Mac, even an Open Documents request addressed to an existing Studio PID created another Studio process. The earlier `open -a RobloxStudio <file>` commands were OS launches, not MCP file-open calls; the current MCP toolset has no local-place opener. Do not repeat these commands when refreshing an existing project or when a new unnamed instance reports **Place is not open**. Reuse the connected document with Rojo. If a genuinely new local document is required, make one deliberate open attempt, inspect it through MCP, and resolve any blocked launch before trying again. Preserve unsaved work and leave closing extra Studio windows to their owner.

See the official [Rojo live-sync workflow](https://rojo.space/docs/v7/getting-started/new-game/#live-syncing-into-studio) and [plugin installation](https://rojo.space/docs/v7/getting-started/installation/#installing-the-plugin).

The development mapping labels its panel **Development**. The test mapping labels it **Test** and starts the server/client TestEZ runners automatically during Play. Follow the [Studio suite instructions](testing.md#run-the-studio-smoke-suites) and inspect both reports. Studio being installed does not mean MCP is connected; verify the handshake above. Keep Rojo as the synchronization mechanism for managed instances; do not also enable Script Sync on those same instances without an explicit migration and ownership decision.

Source files drive managed scripts. Studio-built models/world changes must be exported into `assets/` and entered in the manifest, then rebuilt from a clean checkout. Stop simulation before authoring/exporting. Do not preserve transient playtest objects as authored assets.

## Author and validate the battlefield

[`Battlefield.model.json`](../assets/world/Battlefield.model.json) owns `Workspace.World.Battlefield`; [`MapRules`](../src/shared/MapRules.luau) owns its shared circle/orbit settings. The defaults are center/focus `(0, 0, 0)`, radius 180 studs, aircraft altitude 140 studs above ground, and recovery threshold Y = −30 studs. No aircraft is instantiated yet. Update geometry and settings together: startup rejects a disk whose pose or radius differs from the configured circle.

[`MapService`](../src/server/MapService.luau) validates unique descendant names, `Ground01`–`Ground09`, one `Launcher` anchor, lobby/operator anchors, solid cover, clearance and floor support. Ground/launcher anchor centers are three studs above ground. Startup keeps a private pristine snapshot and connects server Heartbeat containment; `rebuild()` replaces the map subtree from that snapshot. Runtime cover receives `CoverId` and `CoverKind` attributes. These labels reserve future destruction behavior and do not make cover destructible.

For `.model.json` authoring, encode every part pose as a twelve-component `CFrame` (X/Y/Z translation, then the nine rotation-matrix components in row order). Never use `Position` or `Orientation` aliases: generated XML may retain them even though Studio ignores them on load. See the [asset authoring rules and example](../assets/README.md). The artifact inspector checks all authored parts in both builds against canonical transforms, positive dimensions, shape and collision/query/touch flags, with intentional corruption probes proving rejection. A successful or repeatable build still needs Studio loaded-transform assertions and world tests.

Keep both painted routes and the launcher marker clear. The Studio suite samples a 4×6×4-stud upright avatar envelope every 0.5 stud, checks floor support, rays from nine protected anchors to eight perimeter phases, and two exact rebuilds. Run it in the separate test place using the [testing procedure](testing.md#run-the-studio-smoke-suites), then walk both routes and review the boundary and sight lines. Passing host tests or exporting geometry does not establish those engine/playability results.

## Implement the next capability

In Codex, invoke:

```text
Use $implement-next-plan to implement the next eligible plan in this repository.
```

The [skill](../.agents/skills/implement-next-plan/SKILL.md) chooses the next ready plan, delegates implementation, independent testing and documentation, and closes one increment with evidence. Repository-local skills live under `.agents/skills`; roles live under `.codex/agents`, following [OpenAI skill documentation](https://developers.openai.com/codex/skills) and [custom-agent documentation](https://developers.openai.com/codex/subagents).

Routine fixes can be requested directly. There is no need to run the full feature loop to correct a typo. The loop does not publish Roblox automatically or merge without authorization.

## Branches, CI and review

Use `plan/NN-short-name` for feature branches unless the user requests a name. Inspect uncommitted work and fetch before branching. Do not discard another person's changes. Each feature PR explains the player-visible result, plan/requirements, automated results, Studio evidence and limitations. Use the supplied PR template.

The GitHub workflow installs the pinned dependencies and runs the full non-Studio `verify.py` gate. Ordinary Linux CI does not run Roblox Studio; attach required engine evidence separately. CI green is necessary but does not waive engine acceptance.

After verifying the final candidate, commit and push the source and evidence. Mark a plan Complete only under `AGENTS.md`'s definition of done; record whether its PR is still open. Before starting a dependent plan, use a branch containing the completed dependency; do not accidentally branch from an older main that lacks it.

## Release preparation and publication

P12 creates a release record with the verified source commit, build hash, asset-manifest version, exact universe/place IDs, audience, test evidence and rollback build. A release uses `default.project.json`, never the test mapping. Verify that test helpers and development overrides are absent.

Publishing requires explicit authorization for that destination and audience. Source pushes and draft PRs are part of development; they are not Roblox publication. If authorization or access is missing, keep the tested candidate ready and report what is needed. Do not invent IDs or silently create a new experience.

Player data is not stored in Git. The MVP has no persistent inventory/progression and needs no DataStore access. Future persistence must add isolated test data and migration/failure tests before use.
