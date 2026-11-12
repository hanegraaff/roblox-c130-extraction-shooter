# Development guide

## Install and build from a clean clone

The integrated source on `main` contains the 720-stud battlefield, bounded authored terrain, three accessible two-story buildings and building surface-flicker fix, a server-owned perimeter aircraft, inward thermal view and named weapon-linked zoom, alongside lobby/round assignment, explicit character lives, surrender, teammate spectating, timed results and map reset. Firing, aircraft health/damage and launcher gameplay remain planned. P13 world/game source, passing engine acceptance evidence, test-startup fixes and native world-load tooling are integrated on `main` through merged [PR #16](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/16). Use updated `main` to reproduce the integrated map acceptance record; [acceptance integration evidence](evidence/p13-acceptance-integration.md) records the exact merge and host verification. The [root setup guide](../README.md#set-up-locally) gives branch/build commands. [P04](../plans/04-aircraft-and-thermal.md), [P03](../plans/03-rounds-and-roles.md) and [P02](../plans/02-warzone-map.md) record their separate verification scopes; [original P13 integration](evidence/p13-integration.md) records the earlier world-source merge and its host gate, while [P04 integration](evidence/p04-integration.md) preserves earlier aircraft integration facts.

The P14 panning candidate is on `plan/14-aircraft-panning` in [draft PR #18](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/18); it is not integrated into main and still needs real-engine/operated acceptance. Select that branch using the root guide before setup/build to test mouse edge-pan and R / Recenter.

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

The full gate runs formatting, lint, strict type analysis, 46 deterministic unit and 18 service tests, intentional rejection probes, both builds, canonical authored-geometry checks and artifact isolation checks. Builds are `build/game.rbxlx` (release mapping, currently a development aircraft/round prototype) and `build/tests.rbxlx` (test mapping). Open these files as separate local Studio documents; no cloud publication is needed.

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

Stop Play in the intended local test document. Open **Plugins → Rojo**, connect to `localhost:34872`, and verify the project is **PlayersVsC130Tests** before applying its mapping. For a development document instead, serve `default.project.json` on a different explicit port, such as `34873`. Keep test and development connections separate; never connect the test mapping to the cloud/release place. If the Rojo panel is hidden in Edit mode, reopen it with the Rojo toolbar button; a hidden panel does not mean the plugin is missing. On first plugin installation, save work and restart Studio only if the toolbar button/plugin is absent in Edit mode. Load the plugin in Edit before connecting.

If a Rojo server stops or restarts, reconnect the plugin in the existing Edit document and verify **PlayersVsC130Tests** on port **34872** before testing revised source. A running CLI server does not by itself reconnect a disconnected plugin.

If Connect reports **Http requests can only be executed by game server**, inspect the Studio mode first. A Play session with the Client view focused can produce this error. Stop Play, confirm the Edit DataModel is available, then reconnect; do not open another Studio instance to work around it.

For subsequent edits, keep the same confirmed MCP `studio_id`, edit repository source, let Rojo sync, inspect the expected source/world change through MCP, and start a fresh Play session. Stop Play before syncing the next candidate. A document's old hash-bearing filename does not prove which source it now contains: record the actual synced source commit, project and observed engine state. For fresh serialized-world validation, the [native world-load probe](testing.md#check-a-fresh-native-world-load) loads a new source-built binary in this same Edit process. If a criterion specifically requires a fresh place boot, retain that as a separate deliberate file-load check.

For the first launch with Studio fully closed on macOS, use the guarded helper:

```sh
python3 scripts/launch_studio.py build/tests.rbxlx
```

It validates the file, serializes concurrent launch attempts and uses the documented Studio `--task EditFile --localPlaceFile` arguments. If any Studio process is already running, it exits with status 2 and performs no launch. Resolve an existing/blocked session through MCP instead of retrying the launcher. Logs stay in ignored `build/studio-launch.log`.

On this Mac, even an Open Documents request addressed to an existing Studio PID created another Studio process. The earlier `open -a RobloxStudio <file>` commands were OS launches, not MCP file-open calls; the current MCP toolset has no local-place opener. Do not repeat these commands when refreshing an existing project or when a new unnamed instance reports **Place is not open**. Reuse the connected document with Rojo. If a genuinely new local document is required, make one deliberate open attempt, inspect it through MCP, and resolve any blocked launch before trying again. Preserve unsaved work and leave closing extra Studio windows to their owner.

See the official [Rojo live-sync workflow](https://rojo.space/docs/v7/getting-started/new-game/#live-syncing-into-studio) and [plugin installation](https://rojo.space/docs/v7/getting-started/installation/#installing-the-plugin).

The development mapping labels its panel **Development** and starts the production round runtime with a six-player minimum and 600-second rounds. A solo Play session waits at the protected lobby. The test mapping labels it **Test** and starts server/client TestEZ runners automatically. After the foundation/map suites finish, its server runner starts a two-player-minimum runtime with human controls (default next round: 60 seconds). One client automatically previews the map; multiplayer tests start explicitly through the test panel. Use Studio **Server & Clients** with two clients to play both roles or three to test teammate spectating. This override and every test helper are absent from the release mapping.

Follow the [Studio suite instructions](testing.md#run-the-studio-smoke-suites), [expanded-map harness](testing.md#run-the-p13-expanded-map-harness), [aircraft harness](testing.md#run-the-p04-aircraft-harness) and [three-round harness](testing.md#run-the-p03-multiplayer-harness) to collect actual reports. Studio being installed does not mean MCP is connected; verify the handshake above. Keep Rojo as the synchronization mechanism for managed instances; do not also enable Script Sync on those same instances without an explicit migration and ownership decision.

Source files drive managed scripts. Studio-built models/world changes must be exported into `assets/` and entered in the manifest, then rebuilt from a clean checkout. Stop simulation before authoring/exporting. Do not preserve transient playtest objects as authored assets.

## Author and validate the battlefield

[`Battlefield.model.json`](../assets/world/Battlefield.model.json) owns `Workspace.World.Battlefield`; [`MapRules`](../src/shared/MapRules.luau) owns its shared circle/orbit settings. The defaults are center/focus `(0, 0, 0)`, radius 360 studs, aircraft altitude 140 studs above ground, and recovery threshold Y = −30 studs. The server instantiates one anchored aircraft from the versioned C-130 template and flies it around this matching perimeter. Update geometry and settings together: startup rejects a disk whose pose or radius differs from the configured circle.

[`MapService`](../src/server/MapService.luau) validates unique descendant names, `Ground01`–`Ground09`, one `Launcher` anchor, lobby/operator anchors, solid cover, clearance and floor support. Ground/launcher anchor centers are three studs above ground. Startup keeps a private pristine snapshot and connects server Heartbeat containment; `rebuild()` restores the bounded terrain recipe and replaces the map subtree from that snapshot; `destroy()` also restores pristine geometry and terrain before releasing its snapshot. Runtime cover receives `CoverId` and `CoverKind` attributes. These labels reserve future destruction behavior and do not make cover destructible.

`GameRuntime` passes only active living ground characters to containment and disables the lobby-station exemption for them. `MatchRuntime` rebuilds the map at round reset, so consumers must reacquire anchor/cover Instances afterward. Lobby characters can walk at protected stations; only the assigned operator is anchored; ground characters cannot use the external lobby as an active hiding area.

For `.model.json` authoring, encode every part pose as a twelve-component `CFrame` (X/Y/Z translation, then the nine rotation-matrix components in row order). Never use `Position` or `Orientation` aliases: generated XML may retain them even though Studio ignores them on load. See the [asset authoring rules and example](../assets/README.md). The artifact inspector checks all authored parts in both builds against canonical transforms, positive dimensions, shape and collision/query/touch flags, with intentional corruption probes proving rejection. A successful or repeatable build still needs Studio loaded-transform assertions and world tests.

Keep both painted routes and the launcher marker clear. The Studio suite samples a 4×6×4-stud upright avatar envelope every 0.5 stud, checks floor support, rays from nine protected anchors to 64 perimeter phases, and two exact rebuilds. Run it in the separate test place using the [testing procedure](testing.md#run-the-studio-smoke-suites), then walk both routes and review the boundary and sight lines. Passing host tests or exporting geometry does not establish those engine/playability results.

`TerrainRecipe` reconstructs eight fixed Grass/Rock caps from the invisible sphere descriptors under `Battlefield.TerrainRecipe`. The manifest records recipe version 1, seed 0 (no random sampling), four-stud voxels and the owned box from `(-368,-112,-368)` to `(368,32,368)`. Only this box is cleared and rewritten; unrelated terrain outside it is preserved. Terrain appears when `MapService.start()` runs, not as serialized Terrain voxels in the Edit document. Fill operations do not yield, but collision/raycast updates can settle afterward; engine tests wait for bounded readiness rather than assuming immediate physics.

`BuildingLayout` validates the pure footprint/story/panel contract. Server-only `BuildingGeometry` validates actual loaded floors, landings, sixteen connected treads, entry sweeps, five navigation markers and panel pivots before decorating public identities. Foundry and Warehouse are 64×48 studs (3072 square studs each); Outpost is 32×48 (1536 square studs). Each has two floors, a usable upper floor at Y=10, exterior panels on both stories and panelized roofs. The larger buildings have 32-stud room bays divided by registered interior panels. Static floors/stairs/frames remain separate from the 111 Intact panels. These dimensions are construction defaults; [decisions](decisions.md) distinguishes them from selected game rules.

Use the [world contract](../assets/world/README.md) when changing terrain, buildings or anchors. Add every authored source to the manifest, update the pure and artifact contracts, and run the named P13 engine/harness checks. A source-built artifact load is a separate reconstruction check from Rojo live sync. `python3 scripts/build_studio_world_probe.py` emits a native world binary, source expectations, hashes and a complete Edit-mode MCP probe under `build/studio-world-probe.*`. The [procedure](testing.md#check-a-fresh-native-world-load) exercises production MapService against that fresh world and restores its temporary geometry/terrain; it requires no new Studio process. Runtime Play/replication checks remain separate. The native-world check does not establish panning acceptance or implement panel damage.

## Aircraft model and view contracts

[`C130.model.json`](../assets/models/C130.model.json) is the original primitive server-only template. `AircraftService` clones it to `Workspace.Aircraft`; `Hitbox` is its PrimaryPart, pivot and sole queryable gameplay volume. The model faces its travel tangent. On the P14 candidate, the camera at that canonical position independently faces a bounded world-space focus at ground height. `GAU23Muzzle` and `M102Muzzle` are Hitbox attachments used for selected-weapon obstruction checks and reserved for later server-derived firing origins. Decorative parts are anchored, noncolliding, nonqueryable and nontouching. There is no client smoothing shell or second hitbox.

Defaults are a 90-second orbit, 35° GAU23 FOV and 60° M102 FOV. Raw mouse input in the outer 12% of each viewport edge pans at up to 120 studs/second before the displayed reticle is rounded/clamped once to integer pixels inside 15–85% of each dimension; that same pixel pair is used for the GUI and ray. R / Recenter resets focus; acknowledged profile changes retain it. Each frame raycasts actual Terrain/Battlefield surfaces rather than assuming Y=0. The server owns profile selection; its acknowledged atomic `AircraftState.Selection` string supplies round/revision/weapon together. The client updates the weapon name, FOV and reticle projection from that acknowledgement. No fire remote exists yet. `AircraftService.aimAllowed()` is a server-only disk/authored-height/solid-sight-line seam for later combat. It captures the validated Battlefield/AimEnvelope NumberValues (currently Y=−1…32), rays from the selected muzzle attachment through Battlefield parts/Terrain, and permits a 0.5-stud first-surface endpoint tolerance. It is not a damage path.

`RoundPanel` yields camera ownership to `ThermalCameraController` for an active living operator or labelled test-only solo Operator preview. Ground/spectator/lobby cameras remain round-owned. Role loss removes thermal HUD, post-processing, highlights and role input listeners, restoring captured FOV/mouse state. Fresh role/new-round entry recenters pan; normal round reset returns the aircraft epoch and selection to their initial state. The public `ThermalCameraController.input(playerGui, rawPointer, windowFocused)` adapter keeps raw viewport coordinates for pan/rays and subtracts current GuiInset only for GUI-content hit testing. Optional nonyielding input providers support deterministic controller fixtures without a production test flag; native-input and viewport review remain separate. See [package contracts](../src/client/README.md) and the [P04 testing procedure](testing.md#run-the-p04-aircraft-harness).

## Implement the next capability

In Codex, invoke:

```text
Use $implement-next-plan to implement the next eligible plan in this repository.
```

The [skill](../.agents/skills/implement-next-plan/SKILL.md) chooses the next ready plan, delegates implementation, independent testing and documentation, and closes one increment with evidence. Repository-local skills live under `.agents/skills`; roles live under `.codex/agents`, following [OpenAI skill documentation](https://developers.openai.com/codex/skills) and [custom-agent documentation](https://developers.openai.com/codex/subagents).

Routine fixes can be requested directly. There is no need to run the full feature loop to correct a typo. The loop does not publish Roblox automatically or merge without authorization.

## Branches, CI and review

Every user-assigned task gets a dedicated branch before editing, including fixes, tooling, refactors, documentation and steering work outside the roadmap. Use `plan/NN-short-name` for plan increments and a descriptive `fix/`, `chore/` or `docs/` name for other tasks, unless the user requests another name. Continue an existing branch only when resuming the same task. Never work directly on `main` or append a new task to an unrelated task branch. Delegated agents work within the primary agent's task branch under coordinated ownership.

Inspect uncommitted work and fetch before branching; preserve another person's changes. Choose a base containing required dependencies. If a dependency exists only in an open PR, branch from that source and target the dependency branch for a focused stacked PR, recording the dependency and retargeting after integration. Each feature PR explains the player-visible result, plan/requirements, automated results, Studio evidence and limitations. Use the supplied PR template.

The GitHub workflow installs the pinned dependencies and runs the full non-Studio `verify.py` gate. Ordinary Linux CI does not run Roblox Studio; attach required engine evidence separately. CI green is necessary but does not waive engine acceptance.

After verifying the final candidate, commit and push the source and evidence. Mark a plan Complete only under `AGENTS.md`'s definition of done; record whether its PR is still open. Before starting a dependent plan, use a branch containing the completed dependency; do not accidentally branch from an older main that lacks it.

## Release preparation and publication

P12 creates a release record with the verified source commit, build hash, asset-manifest version, exact universe/place IDs, audience, test evidence and rollback build. A release uses `default.project.json`, never the test mapping. Verify that test helpers and development overrides are absent.

Publishing requires explicit authorization for that destination and audience. Source pushes and draft PRs are part of development; they are not Roblox publication. If authorization or access is missing, keep the tested candidate ready and report what is needed. Do not invent IDs or silently create a new experience.

Player data is not stored in Git. The MVP has no persistent inventory/progression and needs no DataStore access. Future persistence must add isolated test data and migration/failure tests before use.

### One-client map exploration

For solo inspection, use the test mapping on port 34872 and ordinary **Play** in the existing document. After foundational suites, the single client automatically previews the map with normal walking; choosing Operator in the test panel enters the thermal view and allows cosmetic profile switching. Production still waits for six players; the isolated test preview does not start a competitive round. Use the root README's [human testing instructions](../README.md#run-local-automated-tests) for the in-game role/duration/start/reset/preview panel. No Command Bar workflow is required.
