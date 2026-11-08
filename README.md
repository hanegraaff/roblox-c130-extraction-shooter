# Players vs C-130

**A Roblox game in development: one gunship against a united ground team.**

The intended game puts one C-130 operator above a circular industrial battlefield and 5–9 teammates on the ground. The ground team uses M-7 rifles and one recoverable rocket launcher to destroy the plane. Three direct rockets destroy an undamaged aircraft; rifle fire chips away at the same health pool.

## What you can play today

The local build contains a circular greybox battlefield. Your avatar starts in its southern shelter. Follow the teal western route or ochre eastern route toward the gold marker at the center; that marker reserves the future rocket-launcher location. Industrial walls and roofed cover separate the routes from exposed areas, and an orange perimeter marks the battlefield edge. The launcher marker cannot be picked up, and cover cannot be destroyed yet.

Use standard Roblox desktop controls: **WASD** to move, **Space** to jump, and the mouse to control the view. The server is configured to return characters that leave the battlefield or fall below it to the shelter. A separate lobby/operator deck is authored outside the battlefield; role assignment and transport to it are still planned.

A status panel shows **Bootstrap running** with a **Development** or **Test** label. Aircraft, roles, weapons, rounds, spectating and results remain planned. Normal Roblox respawning still applies. There is no published Roblox play link. The map has passed host checks and local Studio clearance, cover, boundary, rebuild and walking checks with one client. [P02](plans/02-warzone-map.md) records the evidence and limits; this does not establish multiplayer combat or support for every avatar size.

The [roadmap](roadmap.md) tracks progress; the game described below is the planned MVP.

## Test in Roblox Studio

From the repository root, install dependencies on your first run and build the places:

```sh
python3 scripts/setup.py  # First-time setup
python3 scripts/verify.py
```

See the [development guide](docs/development.md) for prerequisites and source synchronization.

1. In Studio, use **File → Open from File** and select this repository’s `build/game.rbxlx`. This local build is separate from an existing cloud place such as “C130 - Shootout.”
2. Click **Play**. Your avatar should spawn in the southern shelter, with **Development** and **Bootstrap running** in the status panel.
3. Walk both colored routes to the gold center marker. Inspect the cover and orange perimeter using **WASD**, **Space**, and the mouse.
4. Click **Stop**, then **Play** again. Confirm you still have exactly one status panel.
5. For automated Studio tests, open `build/tests.rbxlx` as a separate document and click **Play**. The panel should read **Test**; the suites run automatically. Open Studio’s **Output** panel and expect **23 server tests and 2 client tests**, with zero failures, skipped cases or errors. The current map has passed these suites locally; rerun them for your generated build.
6. Stop and restart the test place to confirm the suites pass again and the panel is not duplicated. Click **Stop** when finished.

After source changes, stop Play, rerun `python3 scripts/verify.py`, and reopen the generated builds. The [testing guide](docs/testing.md#run-the-studio-smoke-suites) explains server/client reports and troubleshooting. The server suites include map clearance, cover raycasts, boundary correction and two map rebuilds. Aircraft and combat arrive in later plans.

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

The initial round-length default is ten minutes. There will be no respawns during a round. Eliminated ground players spectate living teammates; late arrivals wait for the next round.

## Planned controls

These bindings are proposals to validate as the corresponding features arrive. Only standard avatar movement and camera controls work in the current map build.

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
