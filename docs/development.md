# Development guide

## Install and build from a clean clone

Use `main` for integrated play or `plan/29-rocket-launcher-model` for the local depot launcher candidate. Ordinary Studio sessions use offline balance defaults. Select the exact source commit when collecting evidence. Startup reconstructs managed landmarks before capturing the map reset snapshot. [Local setup](../README.md#set-up-locally) · [Balance owner guide](balance.md) · [P29 verification](testing.md#verify-the-depot-launcher-model)

Build, sync and collect evidence from the same selected source. History and prior integration facts belong in the [plan records](../roadmap.md) and their linked evidence; an older passing report does not validate a new candidate.

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

The full gate runs asset provenance and reconstruction, formatting, lint, strict type analysis, deterministic unit and service tests, intentional rejection probes, both builds, canonical geometry checks and artifact isolation. For initial setup, open `build/game.rbxlx` (release mapping) and `build/tests.rbxlx` (test mapping) as separate local Studio documents. Reuse those documents with Rojo for later source iterations. The verifier refreshes neither Studio document automatically. [Verification commands and coverage](testing.md#current-host-checks)

For direct tool commands in a shell, add Rokit’s tool shims to PATH:

```sh
export PATH="$HOME/.rokit/bin:$PATH"
```

For documentation-only changes:

```sh
python3 scripts/check_repository.py
```

This checks local file links, JSON, mapped paths, asset-manifest references and coverage of every authored file under `assets/world`, `assets/models`, `assets/blender`, `assets/exports` and `assets/imports`. Blender source/export entries require matching SHA-256 content hashes and stay within the documented ordinary-Git file budget. It does not check remote URLs or heading anchors. See the [testing guide](testing.md) for individual commands, report interpretation and separate required Studio runs.

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

If a Rojo server stops or restarts, reconnect the plugin in the existing Edit document and verify **PlayersVsC130Tests** on port **34872** before testing revised source. A running CLI server does not by itself reconnect a disconnected plugin or prove that source synced. If Connect fails, preserve the error and inspect delivered module/template identities; no successful connection fix is inferred from an HTTP response on the Rojo port.

If Connect reports **Http requests can only be executed by game server**, inspect the Studio mode first. A Play session with the Client view focused can produce this error. Stop Play, confirm the Edit DataModel is available, then reconnect; do not open another Studio instance to work around it.

For subsequent edits, keep the same confirmed MCP `studio_id`, edit repository source, let Rojo sync, inspect the expected source/world change through MCP, and start a fresh Play session. Stop Play before syncing the next candidate. A document's old hash-bearing filename does not prove which source it now contains: record the actual synced source commit, project and observed engine state. For fresh serialized-world validation, the [native world-load probe](testing.md#check-a-fresh-native-world-load) loads a new source-built binary in this same Edit process. If a criterion specifically requires a fresh place boot, retain that as a separate deliberate file-load check.

For the first launch with Studio fully closed on macOS, use the guarded helper:

```sh
python3 scripts/launch_studio.py build/tests.rbxlx
```

It validates the file, serializes concurrent launch attempts and uses the documented Studio `--task EditFile --localPlaceFile` arguments. If any Studio process is already running, it exits with status 2 and performs no launch. Resolve an existing/blocked session through MCP instead of retrying the launcher. Logs stay in ignored `build/studio-launch.log`.

On this Mac, even an Open Documents request addressed to an existing Studio PID created another Studio process. The earlier `open -a RobloxStudio <file>` commands were OS launches, not MCP file-open calls; the current MCP toolset has no local-place opener. Do not repeat these commands when refreshing an existing project or when a new unnamed instance reports **Place is not open**. Reuse the connected document with Rojo. If a genuinely new local document is required, make one deliberate open attempt, inspect it through MCP, and resolve any blocked launch before trying again. Preserve unsaved work and leave closing extra Studio windows to their owner.

See the official [Rojo live-sync workflow](https://rojo.space/docs/v7/getting-started/new-game/#live-syncing-into-studio) and [plugin installation](https://rojo.space/docs/v7/getting-started/installation/#installing-the-plugin).

The development mapping uses a two-player minimum, 600 seconds of combat and a 120-second intermission from each committed result. The development mapping and ordinary multiplayer test rounds both use 20 seconds of Scatter after the roster is ready. The ordinary test mapping uses quick replay. The P23 SDK selector checks the full intermission. [P24 aircraft arrival procedure](testing.md#run-the-p24-aircraft-arrival-harness) · [P23 lobby procedure](testing.md#run-the-p23-lobby-and-intermission-harness)

A solo Play session in the development mapping waits in the protected lobby. The bootstrap panel shows **Development** or **Test** during startup, then the round HUD takes over. The test mapping runs server and client TestEZ automatically. After the server suite finishes, an ordinary test session opens the map preview for one client or supports explicit starts with at least two. The next combat duration defaults to 60 seconds. Use **Server & Clients** with two clients to exercise both roles, three for launcher transfer, or four for spectator cycling between two living targets after one Ground player is eliminated. Test controls exist only in the test mapping. [Studio smoke and local play](testing.md#run-the-studio-smoke-suites)

Follow the [Studio suite instructions](testing.md#run-the-studio-smoke-suites), [expanded-map harness](testing.md#run-the-p13-expanded-map-harness), [aircraft harness](testing.md#run-the-p04-aircraft-harness) and [three-round harness](testing.md#run-the-p03-multiplayer-harness) to collect actual reports. Studio being installed does not mean MCP is connected; verify the handshake above. Keep Rojo as the synchronization mechanism for managed instances; do not also enable Script Sync on those same instances without an explicit migration and ownership decision.

For the P19 candidate, sync the branch's test build into the same local `PlayersVsC130Tests` document. Start two actual clients for normal-control impact review and use the `P19Profile` selector for the matched five-minute workload. The SDK's separate Replay scenario checks five resets on the same source. Keep baseline and candidate source identities with their separate Studio reports. [P19 checks and profile commands](testing.md#run-p19-weapon-impact-checks)

Source files drive managed scripts. Studio-built models/world changes must be exported into `assets/` and entered in the manifest, then rebuilt from a clean checkout. Stop simulation before authoring/exporting. Do not preserve transient playtest objects as authored assets.

## Author and validate the battlefield

[`Battlefield.model.json`](../assets/world/Battlefield.model.json) owns `Workspace.World.Battlefield`; [`MapRules`](../src/shared/MapRules.luau) owns its shared circle/orbit settings. The defaults are center/focus `(0, 0, 0)`, radius 360 studs, aircraft altitude 140 studs above ground, and recovery threshold Y = −30 studs. The server instantiates one anchored aircraft from the versioned C-130 template and flies it around this matching perimeter. Update geometry and settings together: startup rejects a disk whose pose or radius differs from the configured circle.

[`MapService`](../src/server/MapService.luau) validates unique descendant names, `Ground01`–`Ground09`, four landmark launcher anchors, including the elevated Seedship pickup, lobby/operator anchors, solid cover, clearance and floor support. Ground anchors remain three studs above grade. Launcher anchors may be elevated on a supported building floor/platform; Seedship is at `(0, 5.6, 214)` above its authored platform. Startup keeps a private pristine snapshot and connects server Heartbeat containment; `rebuild()` restores the bounded terrain recipe and replaces the map subtree from that snapshot; `destroy()` also restores pristine geometry and terrain before releasing its snapshot. Runtime cover receives `CoverId` and `CoverKind` attributes. These generic cover labels do not enroll a part in panel destruction. DestructionRuntime consumes only the validated building `_Panels` registries.

`GameRuntime` passes living Ground characters to containment during Scatter and Active and disables the lobby-station exemption for them. `MatchRuntime` rebuilds the battlefield at round reset and keeps the live lobby subtree. Battlefield consumers reacquire anchors and cover after reset. Lobby characters can walk at protected stations. The assigned operator stays anchored at its station, and Ground characters are released from their deployment spawns when Scatter starts.

For `.model.json` authoring, encode every part pose as a twelve-component `CFrame` (X/Y/Z translation, then the nine rotation-matrix components in row order). Never use `Position` or `Orientation` aliases: generated XML may retain them even though Studio ignores them on load. See the [asset authoring rules and example](../assets/README.md). The artifact inspector checks all authored parts in both builds against canonical transforms, positive dimensions, shape and collision/query/touch flags, with intentional corruption probes proving rejection. A successful or repeatable build still needs Studio loaded-transform assertions and world tests.

Keep all four bunker exits, their shared circuit, and the four landmark approaches clear. Keep the Seedship entry and launcher platform clear. Check route clearance against the installed buildings in Play and review each district from player height. The Studio smoke suite also checks supported anchors, protection at nine spawns, and two pristine terrain rebuilds. [Studio checks](testing.md#run-the-studio-smoke-suites)

`TerrainRecipe` restores the version 3 district material/relief rasters under `Battlefield.TerrainRecipe` with four-stud voxels and no random sampling. The owned box remains `(-368,-112,-368)`–`(368,32,368)`; terrain outside it is preserved. `scripts/districts/layout.py` regenerates the authored district/trail/southern relief inputs. Terrain appears at MapService startup rather than as serialized Edit voxels. Writes do not yield, while collision/query updates use bounded readiness waits. See the [world recipe](../assets/world/README.md#terrain-authoring-and-restoration).

`BuildingLayout` validates the pure footprint/story/panel contract. Server-only `BuildingGeometry` validates actual loaded floors, landings, sixteen connected treads, entry sweeps, five navigation markers and panel pivots before decorating public identities. Foundry and Warehouse are 64×48 studs (3072 square studs each); Outpost is 32×48 (1536 square studs). Each has two floors, a usable upper floor at Y=10, exterior panels on both stories and panelized roofs. The larger buildings have 32-stud room bays divided by registered interior panels. The base Edit map has 111 formal-building and 76 shelter panels. The Outpost-only replacement stage had 188 total; the other managed landmarks and Seedship change the runtime registry further, so current acceptance reads the actual registry. Static floors/stairs/frames remain separate. These dimensions are construction defaults; [decisions](decisions.md) distinguishes them from selected game rules.

Use the [world contract](../assets/world/README.md) when changing terrain, buildings or anchors. Add every authored source to the manifest, update the pure and artifact contracts, and run the named P13 engine/harness checks. A source-built artifact load is a separate reconstruction check from Rojo live sync. `python3 scripts/build_studio_world_probe.py` emits a native world binary, source expectations, hashes and a complete Edit-mode MCP probe under `build/studio-world-probe.*`. The [procedure](testing.md#check-a-fresh-native-world-load) exercises production MapService against that fresh world and restores its temporary geometry/terrain; it requires no new Studio process. Runtime Play/replication checks remain separate. The native-world check does not establish panning acceptance or implement panel damage.

## Author and review the Blender outpost

The [source guide](../assets/blender/military-outpost/README.md) gives the saved
file, exact collections/cameras, orbit/cutaway/interior inspection steps,
material-damage review links, scale/axis contracts and complete rebuild recipe.
The [export guide](../assets/exports/military-outpost/README.md) describes the
FBX/OBJ/PNG/material map and panel/reusable-kit identities. Blender 5.3.0 is the
recorded authoring version; Python's standard library is sufficient for the
portable audit and CI. The user approved P16 revision `e8fb840` on 2026-11-13;
the candidate imports that source into the detailed smaller Outpost. Its actual
Studio behavior and in-game visual approval are separate P17 gates.

A deliberate source rebuild runs `scripts/p16_build.py` in a factory-startup
Blender process. Reopen the saved `.blend` in a new background process through
`scripts/p16_blender_review.py -- --audit --fbx-audit`, then render that same saved
source with `--render`. Refresh `scripts/p16_audit.py --write-lock` and
`python3 scripts/refresh_outpost_manifest.py` only after the intended exports
and tool evidence exist, then run the full verifier. The package guide contains
copyable commands with the actual macOS executable path. Render/reopen commands
write evidence without saving mutations into the reviewed `.blend`. Full
`--render` generates all render receipts/metadata; the package guide also
documents the optional verified-receipt `--render-manifest-only` step after the
tested source is committed. Keep `--python-exit-code 1` on Blender commands so
Python failures propagate to the shell.

The `.blend` packs its twelve original baked PNGs and retains versioned relative
texture dependencies. `asset-inventory.json` measures the assembly/variants,
`panel-catalog.json` maps six material/shape families and the declared v2 panel
migration, and `reusable-kit.json` maps grouped prop exports to editable
components. Preserve the migration explicitly: 25 original IDs/pivots remain,
with fixed aperture changes and one added interior partition for P17 to validate.
No new material changes durability or client authority.

Ordinary Git stores source and exports below 20 MiB per file, with an initial
45 MiB package target (D64). Do not commit `.blend1` backups, caches or temporary
renders. `package-lock.json` hashes art files excluding itself/Markdown;
`assets/manifest.json` additionally records the lock and all source/export
provenance. The original reference illustrations remain visual inputs with
unspecified creator/license; do not bundle their pixels as texture sources or
invent an upload owner. Changes needing human visual approval must identify the
new saved-source hash. A green portable audit cannot grant approval or replace
P17's actual import, traversal, collision/thermal, fragment, replication/reset
and engine-performance checks.

## Reconstruct the approved Outpost

The candidate reconstructs only the smaller Outpost at `(144, 0, 164)` from
managed `MilitaryOutpost.model.json` and `MaterialPanels.model.json` templates.
It retains all 25 legacy panel pivots and adds one interior partition. There are
26 Outpost panels; later landmark imports supply their own registries. The base world file retains
its primitive source for review and replacement rollback. `GameRuntime` installs
the detailed building before `MapService` takes its pristine snapshot.

A clean checkout needs no new upload to rebuild the committed templates. It
uses actual mesh IDs and twelve repaired PNG color-map IDs owned by Roblox user
`2227341845`. Check all reconstruction inputs without changing them:

```sh
python3 scripts/p17_assets.py
python3 scripts/p17_library_glb.py
python3 scripts/p17_compile_outpost.py
python3 scripts/verify.py
```

The [import package guide](../assets/imports/military-outpost/README.md) identifies
the native receipts, actual packages/owner, GLB derivative, texture repair and
copyable regeneration commands. The original approved P16 Blender/FBX/OBJ/PNG
bytes and package lock remain unchanged. The material-split derivative preserves
source triangles, UVs and material boundaries; compilation fits observed import
scale/rotation/translation rather than assuming importer units.

MeshId plus target Size does not reconstruct native mesh intrinsics or collision
data. The compiler also loads the managed 407-profile native RBXM/receipt and
preserves engine-authored InitialSize and opaque PhysicalConfigData, PhysicsData
and AeroMeshData for all 2,332 uses. Profiles are keyed by MeshId, collision and
render fidelity; payloads are never inferred from normalized sizes. Ordinary
`AssetMesh.validate` checks public MeshSize/fidelities against the five compiled
native attributes. Payload-byte audits, runtime metadata checks and actual
render/contact/replication acceptance remain separate.

`OutpostReconstruction.prepare(assets)` validates the managed templates before
world writes. `install(world, assets)` replaces exactly the intended smaller
building and returns commit/rollback ownership. Missing assets, malformed support
geometry, unintended scripts, bad references or invalid panels reject startup.
The shared catalog and rectangle proxies own material appearance/solidity;
`PanelAssetBasis` rotates canonical material coordinates while keeping legacy
identity pivots. Supporting floors, stairs and frames remain stable. Panel-owned
dressing survives Pristine/Light and is removed at Heavy/Total, restoring on reset.
Only explicitly owned attachment MeshParts may use the 64-stud per-dimension,
32-stud canonical half-envelope construction allowance; ordinary panel geometry
retains its 40-stud default. These are authoring validation bounds, not weapon or
damage tuning.
See the [server API](../src/server/README.md#imported-material-panels-and-outpost-reconstruction-p17).

The current reconstruction repairs base-color textures but does not recreate
Blender scalar roughness, metalness or emission as SurfaceAppearance maps.
Those source values remain recorded as metadata. This material-finish compromise
needs explicit A6 in-game review; do not describe it as exact PBR reproduction.
Ordinary server/client validation reads shared `AssetMaterial` metadata instead
of protected SurfaceAppearance map properties. The compiler/artifact/Edit audits
bind actual slots to readable compiled attributes and the approved PNG receipt;
actual Instance-based preload establishes availability separately. Neither map
Content variants nor a fallback runtime slot read is permitted.

The operator's thermal owner locally hides classified non-cover props/fragments;
real collidable/queryable cover retains native occlusion. Ground views keep the
furnishings. Normal/thermal readability still needs actual rendered acceptance.

The authorized `C130P17Import` workspace is private (universe `10776653720`,
place `72732833195348`). Clean unpublished draft 11 contains source `010289d`,
not the newer local native-constructor candidate.
The last verified published version 5 contains the older clean `03c9c06`
primitive release build; saving the draft did not publish the candidate. Preserve
that separation when collecting source-specific evidence. Never cloud-save or publish
`build/tests.rbxlx`, TestEZ or development overrides. Publication of a new candidate
remains a separate named destination/audience action.

If future upload work needs permissions and Studio says **Save to Roblox to
manage MCP settings**, use an authorized private release-mapped workspace;
local testing does not require cloud-saving the test place. The existing asset
uploads and workspace authorization are recorded in the plan evidence and
should not prompt repeated permission requests for the same scope.

## Author progressive panels and fragments

Keep each primitive destructible wall, roof or interior panel as one anchored authored BasePart under a validated panel registry. The imported path instead requires a validated pristine material Model, with approved family, pivot, IntactSize and exact proxy geometry. Formal buildings use `_Panels`; additional level-owned `PanelRegistries` StringValues name a direct Battlefield Folder, with Name as the building identity. The active map uses SpawnShelter → SpawnShelterPanels for its 76 shelter panels alongside 112 formal-building panels after Outpost reconstruction. BuildingGeometry validates/decorates its globally unique ID, story/building metadata and Intact pivot before DestructionRuntime captures it. Do not author damaged live state or debris into the source map. Static floors, stairs and support frames belong in `_Static` and never enter the panel ledger. Generic `Breakable` cover is currently unaffected.

The primitive path uses the server-only [PanelResidual template](../assets/models/PanelResidual.model.json) is original primitive geometry: two normalized X strips, each width 0.25 and centered at −0.375/+0.375. PanelGeometry scales them along the longest face axis, preserving the authored thickness/pivot and a central 50% opening. Keep the manifest, source model, residual shape checks and all-panel Studio geometry assertions consistent. D50–D54 revise acceptance, persistent credit, appearance and shelter coverage while retaining the continuity/residual/fragment defaults; do not encode map-specific damage thresholds in the world package.

The timing anchor and earned damage have separate lifecycles. Pauses, misses, target/weapon changes, reload and eligibility loss break timing only; earned heavy/30mm credit stays on each panel until reset. Every resumed first impact earns zero elapsed time. Keep structural state separate from DamageAppearance: Light has visible persistent cosmetic scars, Heavy stays distinctly dark/fractured at zero current-stage progress, and only real residual geometry creates holes. Marks cannot enter collision/query/structural identity. Candidate `8053c8f` passes the full 55-unit/55-integration host gate; the unchanged production core has the recorded `4db4595` ordinary solo baseline of 142 server/six client cases. Warehouse and starting-shelter native-input scenes verify stopped/resumed credit and all four appearance tiers in normal/thermal views at a held canonical orbit pose. Current P05 passes eight two-client cases; the seven-case two-client/reset run now passes, and P14 passes six cases with two initial clients followed by operator departure to one remaining client. The user-confirmed live-clock fragment demonstration closes the visual falling check with its controlled Ground watch camera disclosed; the prior 54/53 host and 137/6 Studio totals stay historical.

Fragment physics owns the `PanelFragments` and `PanelStatic` collision groups exclusively while the runtime is active. Anchored level scenery and Terrain use the latter; captured original groups are restored on stop. Keep fragments outside combat/thermal world query include sets and preserve collision-group filtering. `CanQuery = false` alone is insufficient for a collidable fragment in all query modes. New query consumers must use the authoritative world geometry, not unrestricted Workspace descendants. See the [architecture contract](../architecture.md#progressive-panel-destruction-p07) and [P07 test procedure](testing.md#run-the-p07-destruction-harness).

## Launcher ownership and recovery

`GameRuntime` starts `LauncherRuntime` after `GroundCombatRuntime` and stops it first. The `LauncherState` folder carries independent atomic snapshots for Radar, Hangar, Depot and Seedship, plus Pickup, Drop and Fire RemoteEvents. The server owns each round identity and presents it as an available Model or held Tool. Each accepted shot sets that launcher's deadline 15 seconds ahead. Drop, transfer and recovery preserve the deadline. A new round creates four loaded launchers.

Launcher pickup and fire share the M-7 movement and origin checks. Pickup also needs eight-stud reach and a clear solid-world ray. Recovery uses the last trusted supported position or the launcher’s authored site anchor. A flight sweeps from the validated head origin through solid cover and Terrain, and only a direct aircraft collision awards damage. Round results take precedence over deferred transfers. Stop and reset clear owned representations, queued requests and flights.

Rojo maps the Blender-generated native template to `ServerStorage.Assets.DepotLauncher`. `LauncherGeometry` places the pickup against its floor and aligns the equipped version’s lower grip with the avatar’s hand. Each representation uses a clone of the same template. When there is room around the muzzle, the visible launch blends onto the server flight path over 16 studs. Preserve the three attachment frames when editing the master and run the export and reimport commands before reviewing the fit in the local test place. [Asset rebuild](../assets/blender/rocket-launcher/README.md) · [Server API](../src/server/README.md#landmark-launchers) · [P29 Studio procedure](testing.md#verify-the-depot-launcher-model)

## Aircraft model and view contracts

Edit the C-130 in its Blender master and run the export script to regenerate the managed server template. Rojo maps that template to `ServerStorage.Assets.C130`. `AircraftService` clones it into `Workspace.Aircraft`, where the transparent `Hitbox` is the canonical PrimaryPart, pivot and sole anchor. Solid airframe pieces and the fitted query bands inside rounded visuals provide the server query surfaces for Ground fire. The two named muzzle attachments on Hitbox supply the server firing origins, including the M102 barrel on the lower starboard side. Welds and rotor joints carry the model along the travel tangent. Clients spin only the four cosmetic rotor joints. The operator camera stays at the canonical aircraft position and holds its own targeting focus in world-aligned map coordinates. [Aircraft source and export procedure](../assets/blender/c130/README.md) · [Aircraft Studio procedure](testing.md#verify-the-c-130-flight-model)

Defaults are a 90-second orbit, 30° GAU23 FOV and 40° M102 FOV. Operator WASD/touch arrows pan at up to 120 studs/second in rendered directions, clamping the world-aligned focus at the 720 × 720-stud square edges. Each axis can slide/reverse independently. Releasing input holds the map point and selection preserves it at either lens. R / Recenter returns to map center. The finite projected-right frame can roll through near-overhead/outward corner views; native motion comfort requires operated review. A camera-only noncolliding/nonqueryable backdrop supplies presentation beyond the combat disk and is removed on exit. Mouse movement or a separate touch aims independently. One rounded/clamped 15–85% viewport pixel pair drives both reticle drawing and actual Battlefield/Terrain rays. Server view validation uses the same deterministic basis, a symmetric 1.25-second orbit-position tolerance plus one stud and a 1% viewport-per-edge raster margin. It validates a permitted claim rather than observing the actual camera. `AircraftService.aimAllowed()` still restricts damage to the combat disk, authored Y=−1…64 envelope and selected-muzzle line of sight, with a 0.5-stud first-surface tolerance. Gunship flights use bounded swept collision; initial BasePart overlap is conservative but cannot detect a muzzle buried in Terrain. P18’s [procedure](testing.md#run-the-p18-rebalancing-harness) separates source/frame checks, real fire and native input/contrast evidence.

`RoundPanel` yields camera ownership to `ThermalCameraController` for an active living operator or labelled test-only solo Operator preview. Ground/spectator/lobby cameras remain round-owned. Role loss removes thermal HUD, post-processing, highlights and role input listeners, restoring captured FOV/mouse state. Fresh role/new-round entry recenters pan; normal round reset returns the aircraft epoch and selection to their initial state. The public `ThermalCameraController.input(playerGui, rawPointer, windowFocused)` adapter keeps raw viewport coordinates for aim/rays and subtracts current GuiInset only for GUI-content mouse hit testing. `touchInput(playerGui, point, processed)` hit-tests the raw GUI-content touch point, rejects processed or actionable GUI touches for world aim, and uses `touchViewportPosition` to add the current inset for camera rays. Pad fingers and the separate world-aim finger have distinct ownership that is cleared on focus loss and teardown. Optional nonyielding input providers support deterministic controller fixtures without a production test flag; native-input and viewport review remain separate. The P06 ground controller owns the rifle reticle, ammo/reload and touch controls while an active ground life equips the M-7; the server validates fire and shared aircraft health. See [package contracts](../src/client/README.md) and the [P04 testing procedure](testing.md#run-the-p04-aircraft-harness).

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

P12’s legacy implementation handoff is closed by user direction. Its original live platform/access, capacity, performance and soak observations remain unverified and are retained in the future release checklist, separately from completed local implementation. Closing that handoff grants no new publication authorization.

Run `python3 scripts/prepare_release.py` after setup in a clean checkout of the candidate commit. It runs the full verifier, checks the runtime script sources in both builds and writes `build/release-receipt.json` with the source identity, artifact hashes, tool pins and cloud asset inventory. Use the release artifact `build/game.rbxlx` for an explicitly authorized Roblox destination and `build/tests.rbxlx` for local Studio acceptance. Record the exact place, audience, rollback version and actual live test evidence separately. [Release runbook](release.md)

Player data is not stored in Git. The MVP has no persistent inventory/progression and needs no DataStore access. Future persistence must add isolated test data and migration/failure tests before use.

### One-client map exploration

For solo inspection, use the test mapping on port 34872 and ordinary **Play** in the existing document. After foundational suites, the single client automatically previews the map with normal walking; choosing Operator in the test panel enters the thermal view and allows cosmetic profile switching. A solo production session waits for the second player. The isolated test preview keeps the round in Lobby. Use the root README's [human testing instructions](../README.md#run-local-automated-tests) for the in-game role/duration/start/reset/preview panel. No Command Bar workflow is required.
