# Players vs C-130

**An asymmetric Roblox game in development: one gunship against a united ground team.**

A ruined industrial warzone fills a circular battlefield. One player operates a C-130 circling the map's perimeter. Everyone on the ground belongs to the same team, armed with an M-7 rifle and one goal: destroy the plane before it kills them all or the clock runs out.

A single rocket launcher is placed on the map. Reaching it and protecting its carrier gives the team its strongest counterattack: three direct rocket hits destroy an undamaged plane. M-7 fire also chips away at aircraft health, so coordinated rifle fire matters.

## Can I play it yet?

Not yet. This repository contains the game design, architecture, implementation plans, development skill, and a buildable empty Roblox place structure. It contains **no implemented gameplay** and has no published Roblox experience link. The descriptions below explain the intended MVP.

Follow the [roadmap](roadmap.md) for progress. The first foundation introduces a greybox battlefield and roles; gunship combat, ground fire, and the special launcher follow in later phases.

## Run the project in Roblox Studio

**Roblox Studio and its built-in MCP server are required for this project's supported local development and playtest workflow.** Studio runs the place; MCP lets Codex connect to the open place for inspection and testing. The [Rojo](https://rojo.space/) plugin syncs the files in this repository into Studio. MCP alone does not sync source files.

1. Install [Roblox Studio](https://create.roblox.com/docs/studio/setup) on a Mac or Windows computer and sign in to your Roblox account. Open a local development place; a Baseplate is enough to check the connection.
2. In Studio, open **Assistant → … → Settings → MCP Servers** (or **… → Manage MCP Servers** in older versions). Turn on **Enable Studio as MCP server**. Under **Quick Connect**, turn on **ChatGPT (codex)** if available.
3. Start a new Codex thread or restart the ChatGPT desktop app so the Studio tools load. Ask it to **continue Roblox setup**. It should find the open place with `list_roblox_studios`. If Quick Connect is unavailable, follow the [manual MCP connection steps](docs/development.md#connect-roblox-studio-mcp).
4. Install the [official Rojo Studio plugin](https://rojo.space/docs/v7/getting-started/installation/) and the pinned Rojo CLI. From this repository, run `rokit install`, then `rojo serve default.project.json`. Connect the Rojo plugin in the development place to that server. See the [development guide](docs/development.md#sync-this-repository-with-studio) for builds and the separate test place.

The current scaffold opens as an empty place; gameplay is still planned. A local place is sufficient for development and does not require publishing a Roblox experience.

## Two ways to play

### C-130 operator

The plane flies automatically around the circular map's perimeter. Your thermal-style camera always points inward toward the main battlefield. Aim the reticle within that view and switch between:

- **30mm GAU-23/A Chain Gun:** faster, more precise fire with a tighter zoom.
- **105mm M102 Howitzer:** slower heavy fire with a wider view and larger blast area.

Switching weapons changes the camera zoom automatically. Each weapon keeps its own cooldown/reload state; switching does not make it instantly ready. Watch aircraft health and the remaining ground players. You win by eliminating the entire ground team or surviving until time expires.

Thermal vision cannot see through solid cover. Selected walls and barricades can break, while major buildings remain useful protection.

### Ground team

Every ground player starts with an **M-7 rifle**. Use cover and coordinated fire to wear down the aircraft. One player at a time can carry the map's **rocket launcher**; it is the only weapon pickup, and there are no mission items to collect.

Three direct rocket hits are enough to destroy the plane from full health. Rifle damage can reduce how many further rockets are needed. Aircraft destruction immediately wins the round for the entire ground team.

The initial launcher handling rules let a teammate recover it if its carrier dies or disconnects. It reloads one rocket at a time, with no separate ammunition pickups. These handling/reload details are documented tuning defaults in [decisions](docs/decisions.md).

## A round from start to finish

1. **Gather:** 6–10 players join: one C-130 operator and 5–9 ground teammates.
2. **Deploy:** ground players enter the circular warzone with M-7 rifles; one rocket launcher appears at its map location.
3. **Fight:** the C-130 orbits and attacks while the team uses cover, rifle fire and the launcher to destroy it.
4. **Win or lose:** the ground team wins on aircraft destruction; the C-130 wins on total ground-team elimination or timeout.
5. **Debrief:** see the result, then return to the lobby for a fresh round.

The initial round-length target is ten minutes. There are no respawns during a round. Eliminated players spectate living teammates; late arrivals wait for the next round.

## Planned MVP content

| Feature | First release scope |
| --- | --- |
| Battlefield | One circular industrial warzone with cover and routes to one launcher location |
| Aircraft | One visible C-130 orbiting the perimeter; targeting view always faces the main map |
| Aircraft weapons | 30mm GAU-23/A Chain Gun and 105mm M102 Howitzer, each with its own zoom |
| Ground weapons | M-7 rifle for everyone; one shared, recoverable rocket launcher on the map |
| Aircraft damage | Small rifle damage; three direct rockets destroy a full-health plane |
| Destruction | Selected cover changes from intact to damaged to destroyed |
| Survival | No respawns; spectating and a clear team result |
| Progression | Each round starts fresh; no persistent inventory or economy |

The initial input target is desktop keyboard and mouse. Touch and gamepad support are deferred unless the scope changes. This is a design default, not a claim that device compatibility has been tested.

## Planned controls

These are initial bindings to validate during implementation. In-game help will show the actual supported controls.

| Action | Ground player | C-130 operator |
| --- | --- | --- |
| Move / aim | WASD / mouse; Space to jump | Mouse moves the aiming reticle within the inward-facing view |
| Fire | Left mouse button | Left mouse button |
| Aim / zoom | Right mouse button to aim | Zoom changes with selected weapon |
| Select weapon | 1: M-7; 2: launcher if carrying it | 1: 30mm; 2: 105mm |
| Reload | R | Per-weapon automatic cooldown/reload |
| Interact / drop | E near launcher / G to drop it | — |
| Help | On-screen Help button | On-screen Help button |

## What this game is aiming for

The ground team must choose when to stay protected, when to expose itself to fire, and how to get the launcher into position. The operator balances focused 30mm fire with wider 105mm attacks while orbit motion changes sight lines. Both sides need useful cover, readable danger, and clear damage feedback.

Exact damage, reload times, zoom angles and orbit speed will be tuned through playtests. The three-rocket full-health rule is a fixed requirement, not a balance value to quietly change. There is no escape zone or collection mission. The MVP also excludes free flight, full building collapse, vehicles, additional maps, crafting, ranking, purchases and persistent progression. Effects are stylized and non-graphic.

## Follow development or contribute

- [Game design](game-design.md) explains rules and edge cases.
- [Roadmap](roadmap.md) shows each phase and the experience it delivers.
- [Requirements](requirements.md) connects features to plans and test obligations.
- [Development guide](docs/development.md) explains building the scaffold and the future Studio workflow.
- [Architecture](architecture.md) describes how the systems will be organized.
- [Testing strategy](docs/testing.md) covers automated checks and multiplayer validation.

The source remains in [hanegraaff/roblox-c130-extraction-shooter](https://github.com/hanegraaff/roblox-c130-extraction-shooter); the repository retains its original name. No public Roblox release is available yet.
