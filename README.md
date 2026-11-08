# Players vs C-130

**A Roblox game in development: one gunship against a united ground team.**

The intended game puts one C-130 operator above a circular industrial battlefield and 5–9 teammates on the ground. The ground team uses M-7 rifles and one recoverable rocket launcher to destroy the plane. Three direct rockets destroy an undamaged aircraft; rifle fire chips away at the same health pool.

![Active ground player in the greybox shelter with role, round timer, surviving ground count and Surrender / spectate button](docs/evidence/p03/current-progress.jpg)

*Current progress: P03 active ground round prototype, captured in a local Roblox Studio multiplayer test on 2026-11-08 with chat hidden. Aircraft and combat are planned.*

## What you can play today

The local build is a round prototype on a circular greybox battlefield. Players wait on a protected lobby deck. With 6–10 players, the server selects one operator and sends everyone else to sheltered ground positions. Operator turns rotate between eligible players, preferring those who have waited more rounds. The operator currently stays at a protected station with a normal avatar camera; the flying aircraft and its targeting view are planned.

Ground players use **WASD**, **Space** and the mouse to explore. Follow the teal western route or ochre eastern route toward the gold center marker. Industrial walls and roofs provide cover, and an orange perimeter marks the edge. Leaving the battlefield or falling below it returns an active ground player to shelter. The marker reserves the future launcher location; there is no pickup or destructible cover yet.

A round panel shows phase, role, life state, remaining time and surviving ground players. Ground players can click **Surrender / spectate** or reset their character to give up their life. Death and reset do not respawn them during that round: they watch a living ground teammate instead. Late arrivals and reconnecting players wait for the next round. Resetting the operator's placeholder character retains the assignment and deadline.

The operator wins when all ground lives are gone or the timer expires; an operator disconnect gives the remaining ground team a forfeit win. Results lead to a restored map and a fresh lobby. Production defaults are ten-minute rounds. Weapons, aircraft damage, thermal view and the launcher are planned, so ground cannot yet earn an aircraft-destruction win through play. There is no published Roblox play link. See [P03](plans/03-rounds-and-roles.md) for verification evidence and limits, and [P02](plans/02-warzone-map.md) for map evidence.

The HUD is a prototype; Roblox's open team-chat panel can overlap its left side at smaller viewport sizes. Full player guidance and presentation polish are planned for P10.

The [roadmap](roadmap.md) tracks progress; the game described below is the planned MVP.

## Set up locally

For the complete local Studio workflow, use macOS with **Git**, **Python 3.10+**, system **curl**, and **Roblox Studio** installed. Sign in to Studio yourself and keep Play stopped while installing or connecting plugins. Setup downloads tools from GitHub and TestEZ from Wally, so network access is required. The setup/host checks also support Linux arm64/x86_64; automated Windows setup is not provided. See the [development guide](docs/development.md) for platform and tool details.

Clone the source and enter the checkout:

```sh
git clone https://github.com/hanegraaff/roblox-c130-extraction-shooter.git
cd roblox-c130-extraction-shooter
```

Choose the branch you intend to test before building. Use `main` for integrated source or the PR's head branch for an unmerged candidate. To review this roles/rounds increment, fetch and select its task branch:

```sh
git fetch origin
git switch plan/03-rounds-and-roles
```

If you will make changes, create a dedicated task branch from the selected source before editing; see the [branch rules](docs/development.md#branches-ci-and-review).

Install the pinned tools and dependencies, run the complete host gate, and make the tool commands available in this terminal:

```sh
python3 scripts/setup.py  # First-time setup; rerun if tool/dependency checks request it
python3 scripts/verify.py
export PATH="$HOME/.rokit/bin:$PATH"
rojo plugin install      # Install the matching Studio plugin once
```

The verifier builds `build/game.rbxlx` for local development and `build/tests.rbxlx` with automatic Studio test runners. A successful host run currently includes **24 unit and 14 integration tests**, formatting/lint/type checks, both builds, geometry checks and release isolation. It does not run Roblox Studio. The dependency and build directories are generated and stay out of Git.

## Play and develop locally with Rojo

Rojo's local server watches repository files and sends code/map changes to the Studio plugin. Keep the server terminal running while you work; **Ctrl+C** stops it. Reuse a matching server if it is already running.

For the development place, run:

```sh
rojo serve default.project.json --address 127.0.0.1 --port 34873
```

1. In Studio, use **File → Open from File** to open `build/game.rbxlx` as a local development document. Reuse it if it is already open.
2. Keep **Play stopped**. Open **Plugins → Rojo** and connect to `localhost:34873`. Confirm the project is **PlayersVsC130** before applying the mapping. If the newly installed toolbar button is absent in Edit mode, save work and restart Studio once. If only the panel is hidden, reopen it with the Rojo toolbar button; Play is not needed.
3. Click **Play**. The status panel reads **Development** / **Bootstrap running**, and the round panel shows a lobby waiting for six players. Your lobby character is protected and stationary. A solo client cannot start a production round.
4. For a small local round, use the separate test mapping below. Its server-only two-player minimum permits role testing with two clients; use three to watch teammate spectating while another ground player remains alive.
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
3. Open Studio's **Output** panel. Expect **45 server tests and 2 client tests**, with zero failures, skipped cases or errors. These cover rules, service lifecycle, status/character behavior, map queries, boundary correction and rebuilds. After those suites pass, the test runner starts the round runtime. A solo client waits for a second player.
4. Click **Stop**, then **Play** again. Check fresh passing reports and one status panel plus one round panel. Stop before changing the mapping or source.
5. To play both roles locally, select Studio's **Server & Clients** testing mode, choose **2 clients** (or **3** for teammate spectating), and start the session. The test mapping uses a three-second lobby delay and sixty-second rounds. Ground players can move, surrender or reset; operator movement is locked at the placeholder station. Watch the timer, result and return to lobby, then use **End Session** to close the test clients.

The [P03 multiplayer harness](docs/testing.md#run-the-p03-multiplayer-harness) separately starts three clients, adds a late spectator and drives three accelerated rounds. A single-client TestEZ pass does not establish replicated round behavior, and local rounds do not establish combat or release capacity.

After source changes, stop Play, rerun the host gate, verify Rojo delivered the candidate and start a fresh session. Open a generated artifact separately when checking file-load reconstruction. For a documentation-only change, `python3 scripts/check_repository.py` checks local links, JSON, mappings and assets. See the [testing guide](docs/testing.md#run-the-studio-smoke-suites) for structured server/client reports and required evidence.

## Planned roles

### C-130 operator

The aircraft flies automatically around the map perimeter. Your thermal-style view always faces inward toward the battlefield; move the aiming reticle within that view and choose between:

- **30mm GAU-23/A Chain Gun:** faster, precise fire with a tighter zoom.
- **105mm M102 Howitzer:** slower heavy fire with a wider view and larger blast.

Selecting a weapon changes zoom while preserving each weapon’s cooldown and reload state. Solid cover blocks thermal highlighting and damage. Selected walls and barricades can break, while major buildings remain stable protection.

You win by eliminating every ground player or surviving until time expires.

### Ground team

Every ground player starts with an **M-7 rifle**. Use cover and coordinated fire to wear down the aircraft. One player at a time can carry the map’s **rocket launcher**. Three direct hits destroy a full-health plane; prior rifle damage can reduce the rockets still needed. Aircraft destruction immediately wins for the whole ground team, including eliminated teammates.

The planned launcher can be dropped and recovered after its carrier dies or disconnects. It reloads one rocket at a time with replenishing supply and no separate ammo pickups. These handling and reload choices are [tuning defaults](docs/decisions.md).

## Planned round flow

1. **Gather:** 6–10 players join, with one operator and 5–9 ground teammates.
2. **Deploy:** the ground team enters the circular warzone with rifles; one launcher appears at its map anchor.
3. **Fight:** the operator attacks from orbit while the team uses cover, rifles and rockets to destroy the plane.
4. **Resolve:** aircraft destruction wins for ground; total ground elimination or timeout wins for the C-130.
5. **Replay:** a clear result leads back to the lobby and a fresh round.

The initial round-length default is ten minutes. The current prototype already enforces no respawns, teammate spectating and late-arrival waiting; the weapons, aircraft and launcher in this full flow remain planned.

## Planned controls

These combat bindings are proposals to validate as the corresponding features arrive. The current prototype supports standard ground movement/camera controls and the on-screen **Surrender / spectate** button during an active ground life.

| Action | Ground player | C-130 operator |
| --- | --- | --- |
| Move / aim | WASD / mouse; Space to jump | Mouse moves the reticle inside the inward-facing view |
| Fire | Left mouse button | Left mouse button |
| Aim / zoom | Right mouse button to aim | Zoom follows the selected weapon |
| Select weapon | 1: M-7; 2: launcher if carrying it | 1: 30mm; 2: 105mm |
| Reload | R | Independent automatic cooldown/reload |
| Interact / drop | E near launcher / G to drop it | — |
| Help | On-screen Help button | On-screen Help button |

The input target is desktop keyboard and mouse. Touch and gamepad support are deferred. Damage, cadence, reload timing, zoom and orbit speed need later playtesting; the three-rocket full-health rule is fixed. The MVP has one map, partial cover destruction and fresh equipment each round. Progression, purchases, vehicles, free flight and full building collapse are outside its scope.

## Follow development or contribute

- [Game design](game-design.md): intended rules and edge cases.
- [Roadmap](roadmap.md): capabilities and current status.
- [Requirements](requirements.md): acceptance obligations.
- [Development guide](docs/development.md): installation, builds, Studio and source synchronization.
- [Architecture](architecture.md): implemented boundaries and future systems.
- [Testing guide](docs/testing.md): automated gates and real-engine verification.

Source is maintained in [hanegraaff/roblox-c130-extraction-shooter](https://github.com/hanegraaff/roblox-c130-extraction-shooter). The repository retains its original name.
