# Players vs C-130

**A Roblox game in development: one gunship against a united ground team.**

One player operates a circling C-130 while 5–9 teammates on the ground try to destroy it. Every ground player starts with an M-7 rifle. One shared map launcher provides recoverable rockets: three direct hits destroy an undamaged aircraft, and rifle fire wears down the same health pool.

![Warehouse wall with dark fractured side strips around its new half-panel opening after three direct 105mm hits](docs/evidence/p07-revision/normal-heavy.png)

*P07 damage revision, 2026-11-13: actual two-client Studio capture after three native-fired 105mm hits. Heavy damage keeps fractured side strips around a real opening. The black block is a temporary QA visibility marker; the normal-color comparison camera and aircraft pose are held for the stage review. [Normal and thermal comparisons](docs/evidence/p07-damage-revision.md) document the test setup.*

## What you can play today

The local candidate on **`plan/08-rocket-launcher`** includes the single launcher alongside the existing battlefield, gunship and rifle combat, directional thermal camera, progressive cover damage and round loop. **P08 acceptance is still open**: use the [plan record](plans/08-rocket-launcher.md) and [verification evidence](docs/evidence/p08-launcher.md) for tested source and remaining checks. Integrated `main` contains P07 and does not yet include player launcher handling. There is no published Roblox play link.

A normal round starts in the protected, walkable lobby with 6–10 players. The server assigns one operator, preferring eligible players who have waited longer, and deploys everyone else as one ground team. The aircraft circles the edge of the **720-stud battlefield** automatically. Ground wins by destroying it; the operator wins by eliminating all ground lives or surviving until timeout. The default limit is ten minutes. An operator disconnect forfeits to the remaining ground team. Results return everyone to a fresh lobby and restore the battlefield.

As **operator**, hold WASD to pan the inward thermal view: A moves left and D right. Touch devices use the labelled arrows. The mouse, or a separate touch, aims the reticle. Releasing the pan holds the view angle relative to the circling plane. At wide zoom the level edge can enter roughly the outer quarter of the screen. R / Recenter restores the safe view. Select **1 / 30mm GAU-23/A Chain Gun** for the tighter view or **2 / 105mm M102 Howitzer** for the wider view. Hold left mouse / FIRE to fire at a valid surface. Switching retains the pan and each weapon's ammunition and reload timing. Solid cover hides thermal highlights and protects players from blasts.

As **ground**, use WASD and Space to move and jump. Equip the M-7 from its tool slot, aim at the plane and hold left mouse to fire; R reloads the rifle. Touch players aim with the camera and use FIRE / RELOAD. Follow the teal western or ochre eastern route to the center launcher. Within reach, use **E / PICK UP** to claim it; another teammate can carry it only after it is released. Keep the rifle and select either weapon through the native tool slots, or the touch **M-7 / ROCKET** buttons. Rockets fly straight with travel time, so lead the moving plane. Their four-second automatic reload continues while holstered, dropped or passed to someone else. **G / DROP** releases the launcher for a teammate. Death, character reset or disconnect also releases it while the round remains active; an invalid recovery position sends it back to its original anchor. There are no separate ammo pickups. The team status shows whether the launcher is available or carried; use aircraft health to judge remaining damage, since earlier rifle hits can reduce the rockets still needed.

Use the eight grass/rock hills, two large buildings and one smaller building for cover. Each building has stairs and two usable floors. Battlefield walls and roofs, including the starting shelter, take persistent damage: Light scars precede a real Heavy opening after three direct 105mm hits; three more hits on the residual solids remove the panel. Nine earned seconds of valid same-panel 30mm impacts advance each stage. Earned damage survives stops, misses, reloads and target changes; the first resumed hit earns zero paused time. Heavy panels retain their dark fractured appearance. Bounded fragments fall against scenery without damaging or blocking players. Floors, stairs, frames, terrain and the separate outside lobby remain stable.

The HUD shows role, life, time, survivors, ammunition and aircraft health. Confirmed hits show **AIRCRAFT HIT −5** for the rifle or **ROCKET HIT** for the launcher. Friendly fire is off. Ground death, character reset or Surrender / spectate consumes that round's life; eliminated players follow a living teammate. Late arrivals and reconnecting players cannot regain an active life or launcher. Operator reset replaces only the protected station body. An orange boundary marks the playable disk; leaving it or falling below the map returns an active ground player to shelter. Movement/origin checks can temporarily reject pickup or fire after implausible position jumps; they issue no automatic ban.

This is primitive development art and a local test candidate. Actual same-identity reconnect remains an open P08 validation item; deterministic tombstone tests do not replace that engine check. Physical-device mobile review, gamepad controls, combat audio, release performance and real 6/10-player capacity are unverified or planned. The MVP has one level; additional selectable levels, complete player guidance and balance/release acceptance are later work. Progression, purchases, ground vehicles and full structural collapse are outside scope.

## Set up locally

For the complete local Studio workflow, use macOS with **Git**, **Python 3.10+**, system **curl**, and **Roblox Studio** installed. Sign in to Studio yourself and keep Play stopped while installing or connecting plugins. Setup downloads tools from GitHub and TestEZ from Wally, so network access is required. The setup/host checks also support Linux arm64/x86_64; automated Windows setup is not provided. See the [development guide](docs/development.md) for platform and tool details.

Clone the source and enter the checkout:

```sh
git clone https://github.com/hanegraaff/roblox-c130-extraction-shooter.git
cd roblox-c130-extraction-shooter
```

Select the launcher candidate before building this version:

```sh
git fetch origin
git switch plan/08-rocket-launcher
git pull --ff-only origin plan/08-rocket-launcher
```

Do not discard local edits when switching source; select the same source for builds, Rojo sync and test evidence.

If you will make changes, create a dedicated task branch from the selected source before editing; see the [branch rules](docs/development.md#branches-ci-and-review).

Install the pinned tools and dependencies, run the complete host gate, and make the tool commands available in this terminal:

```sh
python3 scripts/setup.py  # First-time setup; rerun if tool/dependency checks request it
python3 scripts/verify.py
export PATH="$HOME/.rokit/bin:$PATH"
rojo plugin install      # Install the matching Studio plugin once
```

The verifier builds `build/game.rbxlx` for local development and `build/tests.rbxlx` with automatic Studio test runners. The host gate runs **55 unit and 65 integration tests**, formatting/lint/type checks, both builds, geometry checks and release isolation. It does not run Roblox Studio. The dependency and build directories are generated and stay out of Git.

## Play and develop locally with Rojo

Rojo's local server watches repository files and sends code/map changes to the Studio plugin. Keep the server terminal running while you work; **Ctrl+C** stops it. Reuse a matching server if it is already running.

For the development place, run:

```sh
rojo serve default.project.json --address 127.0.0.1 --port 34873
```

1. In Studio, use **File → Open from File** to open `build/game.rbxlx` as a local development document. Reuse it if it is already open.
2. Keep **Play stopped**. Open **Plugins → Rojo** and connect to `localhost:34873`. Confirm the project is **PlayersVsC130** before applying the mapping. If the newly installed toolbar button is absent in Edit mode, save work and restart Studio once. If only the panel is hidden, reopen it with the Rojo toolbar button; Play is not needed.
3. Click **Play**. The status panel reads **Development** / **Bootstrap running**, and the round panel shows a lobby waiting for six players. Your lobby character is protected and can move with WASD. A solo client cannot start a production round.
4. For solo exploration or a small local round, use the separate test mapping below. A single client automatically previews the battlefield. Two clients support real role/round testing; use three for launcher transfer/recovery and teammate spectating while another ground player remains alive.
5. Click **Stop** before editing repository files. Let Rojo sync changes into this same document, inspect the expected change, and start a fresh Play session. Reopening a new build after every edit is unnecessary.

If Rojo reports **Http requests can only be executed by game server**, stop Play and reconnect in Edit mode. Keep a separate test document for the test mapping below. The [development guide](docs/development.md#sync-this-repository-with-studio) covers the guarded macOS launcher, MCP connection and further troubleshooting.

## Run local automated tests

Run the full host gate after code/configuration changes:

```sh
python3 scripts/verify.py
```

For real-engine tests, start the test sync server in another terminal with Rokit's tools on PATH:

```sh
export PATH="$HOME/.rokit/bin:$PATH"
rojo serve test.project.json --address 127.0.0.1 --port 34872
```

1. Open `build/tests.rbxlx` as a **separate local test document**. Keep Play stopped while connecting **Plugins → Rojo** to `localhost:34872`; confirm **PlayersVsC130Tests**. Never apply this mapping to a cloud/release place.
2. Click **Play**. The panel should read **Test**. The mapped TestEZ runners execute automatically; do not start a second manual run.
3. Open Studio's **Output** panel. Require nonempty server and client reports with every discovered test passing and zero failures, skipped cases or errors. On source `75b1e88`, fresh ordinary Play passed **156 server tests and 7 client tests with one actual client**, with zero failures, errors or skips. Require fresh source-specific reports after changes; this solo result does not establish three-client launcher acceptance. The [P08 record](plans/08-rocket-launcher.md) tracks the separate checks. The test server records first-client startup progress in `workspace.ServerTestStartup` and waits up to 60 seconds for that client before publishing an explicit failed report. See the [testing guide](docs/testing.md#run-the-studio-smoke-suites) for startup diagnostics and source-specific evidence. These cover rules, selection rejection, service lifecycle, status/character behavior, actual GUI-hover/text-focus blocking, building/story/panel geometry, terrain reconstruction, supported routes, canonical aircraft poses, solid sight lines, boundary correction, all-panel residual geometry, pre-impact cover, fragment physics and pristine resets. These engine suites do not replace the three-client P08 or other multiplayer and operated checks. After those suites pass, the test runner starts the round runtime. With one client, it automatically moves you to the battlefield for solo exploration. The HUD reads **Studio preview • Ground**. This bypasses the lobby location for testing; no opponent, active life or competitive round is created.
4. Click **Stop**, then **Play** again. Check fresh passing reports and one status panel plus one round panel. Stop before changing the mapping or source.
5. Use the **STUDIO TESTING** panel at the bottom right. Click **Role** to cycle Auto → Ground → Operator. With one client, the choice changes your solo preview immediately: Ground can walk, while Operator previews the inward thermal view. Hold **WASD** to pan and move the mouse to aim, or use the touch directional pad and a separate aiming touch. Use **R / Recenter** to reset the safe view, and **1 / 2** or the named buttons to inspect both zoom profiles. Solo selection is cosmetic and does not grant an active role. Click **Next round** to cycle 30, 60, 180 or 600 seconds.
6. For a real role/round test, use Studio **Server & Clients** with **2 clients** (or **3** for launcher recovery and teammate spectating). Choose your roles, then click **Start round now** to bypass the lobby wait. Two Operator choices, or everyone choosing Ground, produces an explanation rather than silently changing a tester's choice. **Auto** fills the required operator when nobody explicitly requests it.
7. **Reset test / apply settings** ends the local test and restores preview/lobby. Role and duration choices apply to the next explicit **Start round now**; they do not change an active role or deadline. Use **End Session** to close multiplayer test clients when finished.

For **solo exploration**, just click **Play** in the test document; no **Server & Clients** windows are needed. If the panel says **Development**, stop Play and connect this document to the test server on `localhost:34872`, confirming **PlayersVsC130Tests**.

Use **Return to lobby** to inspect the walkable lobby, or **Explore map (solo)** to return to preview. No Command Bar commands are required. Solo previews are clearly labelled and do not grant an active round life, opponent or weapons. The panel and all override/settings code are excluded from the release mapping; production still requires 6–10 players and uses its normal role selection. See [test-control evidence](docs/evidence/lobby-preview.md) for verified cases.

The [P08 launcher harness](docs/testing.md#run-the-p08-launcher-harness) requires **three actual clients**: one operator and two ground players. It checks raced acquisition, rejected requests, real rockets, reload-preserving drop/death/character-removal/disconnect recovery, replication and reset. Actual same-identity reconnect remains separately required and unverified; P07’s late-join waiver does not apply to it. The revised [P07 destruction harness](docs/testing.md#run-the-p07-destruction-harness) requires **two actual clients**. It checks persistent Light/Heavy/Total progression, earned 30mm time across separated bursts, starting-shelter damage, openings, rejection, replication and resets. A real late join is waived for this P07 gate; no third client or mid-session Start action is required. Fresh reports and separate operated normal/thermal review are still needed for this revision. The [P14 pan harness](docs/testing.md#run-the-p14-panned-targeting-harness) requires two actual clients, a full orbit at each FOV, real terrain/upper-floor surface projections, selection coherence, role isolation and cleanup. Its automated pointer-input fixtures are separate from native mouse/keyboard/button review and 1280×720 / 1920×1080 rendered checks. The [P13 map harness](docs/testing.md#run-the-p13-expanded-map-harness) starts two actual clients, walks a ground avatar into all three upper floors, perturbs and resets the map twice, then requests a third actual late client to check rebuilt-map replication. The [P04 multiplayer harness](docs/testing.md#run-the-p04-aircraft-harness) uses two actual clients to sample a full 90-second orbit, check both zoom profiles and rejected selections, test thermal fixtures, reset/reentry and operator departure. The [P03 multiplayer harness](docs/testing.md#run-the-p03-multiplayer-harness) separately starts three clients, adds a late spectator and drives three accelerated rounds. The [P05 combat harness](docs/testing.md#run-the-p05-gunship-combat-harness) adds two-client firing, cover, rejection, result and reset checks. The [P06 harness](docs/testing.md#run-the-p06-ground-combat-harness) checks rifle and aircraft-health behavior; its earlier candidate fixture passed with two actual clients. A single-client TestEZ pass does not establish replicated combat or release capacity.

After source changes, stop Play, rerun the host gate, confirm Rojo is connected to **PlayersVsC130Tests** on `localhost:34872`, verify it delivered the candidate and start a fresh session. If the sync server was restarted, reconnect the existing document's Rojo plugin in Edit before testing.

For fresh serialized-world acceptance through Studio MCP, build the probe from the selected checkout:

```sh
python3 scripts/build_studio_world_probe.py
```

Run the generated `build/studio-world-probe.luau` through MCP in the existing **Edit** document. It loads a newly built native world artifact, verifies source geometry and terrain restoration, then removes its fixture and restores prior terrain. This world-load check needs no new Studio process; normal Play server/client tests remain separate. See the [fresh-world procedure](docs/testing.md#check-a-fresh-native-world-load) for generated files, report checks and source identity.

For a documentation-only change, `python3 scripts/check_repository.py` checks local links, JSON, mappings and assets. See the [testing guide](docs/testing.md#run-the-studio-smoke-suites) for structured server/client reports and required evidence.

## Controls and cover

| Action | Ground player | C-130 operator |
| --- | --- | --- |
| Move / aim | WASD and mouse; Space to jump | WASD pans (A left, D right); touch arrows pan in their shown directions; mouse or a separate touch aims |
| Recenter view | — | R / Recenter |
| Select weapon and zoom | Native tool slots; M-7 / ROCKET touch buttons | 1 / 30mm button; 2 / 105mm button |
| Fire | Hold left mouse / FIRE while equipped | Hold left mouse / FIRE at a valid aim point |
| Reload | M-7: R / RELOAD; launcher: automatic | Automatic, independently per weapon |
| Pick up / drop launcher | E / PICK UP within reach; G / DROP while carrying | — |
| Surrender / spectate | On-screen button during an active life | — |

The M-7 defaults are **5 damage**, a **30-round magazine**, **120 reserve rounds**, **0.15-second cadence** and **2-second reload**. Aircraft health starts at **300**. The faster 30mm holds **100 rounds**, fires every **0.15 seconds** and automatically reloads in **5 seconds**; the 105mm holds **one round** and automatically reloads in **4 seconds**. The 105mm has a wider blast. These values are tuning defaults; switching cannot refill ammunition or reset readiness.

Panel damage counts server-resolved **direct gunship impacts**, separately from blast damage to players. The first 30mm hit, including the first after a pause or target change, starts timing with zero elapsed credit; trigger time alone does not count. Current mixing defaults let one heavy hit contribute one third of a stage and preserve it through interruptions. All earned per-panel heavy and 30mm damage persists until reset; only the timing connection between hits breaks. Light scars do not make holes. Heavy/Damaged panels leave two solid side strips around a central 50% opening; those strips still block movement, shots and thermal sight lines. A creating blast uses the cover present before the damage batch; later shots can exploit the hole. Up to 48 server-owned fragments fall against scenery and expire after eight seconds. They do not damage or collide with players or supply cover. See [destruction contracts](architecture.md#progressive-panel-destruction-p07) for timing and collision details.

The launcher carries one ready rocket and automatically replenishes after four seconds. Its reload deadline follows the single round weapon through switching and transfers. A direct rocket applies 100 aircraft-health units once; three alone destroy a pristine 300-health plane. Cover, misses and near misses do not earn a direct hit. A rocket already flying may still count after its shooter dies if another ground player keeps the round active; a committed result cancels remaining work. See the [roadmap](roadmap.md) and [P08 evidence](docs/evidence/p08-launcher.md) for acceptance and integration state.

## Follow development or contribute

- [Game design](game-design.md): intended rules and edge cases.
- [Roadmap](roadmap.md): capabilities and current status.
- [Requirements](requirements.md): acceptance obligations.
- [Development guide](docs/development.md): installation, builds, Studio and source synchronization.
- [Architecture](architecture.md): implemented boundaries and future systems.
- [Testing guide](docs/testing.md): automated gates and real-engine verification.

Source is maintained in [hanegraaff/roblox-c130-extraction-shooter](https://github.com/hanegraaff/roblox-c130-extraction-shooter). The repository retains its original name.
