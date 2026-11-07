# C-130 Extraction Shooter

**An asymmetric Roblox game in development: one gunship above, a team trying to escape below.**

An industrial district has become a warzone. One player operates the weapons of a C-130-style aircraft circling overhead. The other players must cross exposed streets, use surviving buildings for cover, recover three mission items, and reach extraction before time runs out.

The aircraft is powerful, but the ground team can fight back. Selected barricades and walls can break, changing which routes are safe. Destroying the aircraft's ability to fire buys time; the team still needs to finish the mission.

## Can I play it yet?

Not yet. This repository currently contains the game design, architecture, implementation plans, development skill, and a buildable empty Roblox place structure. It contains **no implemented gameplay** and has no published Roblox experience link. The descriptions below explain the intended MVP.

Follow the [roadmap](roadmap.md) for progress. The first playable foundation will let testers join a greybox battlefield in different roles; combat and extraction follow in later phases.

## Two ways to play

### Gunship operator

You operate a zoomable, high-contrast thermal-style targeting camera and a heavy cannon. The aircraft follows its own orbit, leaving you free to search for exposed players, choose your shots, and watch your cooldown and aircraft health.

Thermal vision does not see through solid buildings. The ground team can use cover, and your view changes as the aircraft circles. Your job is to stop every ground player from escaping before the round ends.

### Ground team

You enter with a rifle and limited anti-air ammunition. Work together to collect three mission items from locations chosen at the start of the round. Every collected item counts for the whole team and stays collected even if its collector is eliminated.

Once all three are recovered, extraction opens. At least one living teammate must stay in the extraction zone for its countdown to finish. Leaving the zone or being eliminated interrupts that player's attempt. One successful extraction wins for the team.

## A round from start to finish

1. **Gather:** a normal match starts with 6–10 players: one gunship operator and 5–9 ground players.
2. **Deploy:** ground players enter the district; the aircraft begins its orbit. The initial round-length target is ten minutes.
3. **Recover:** collect the three shared objectives while surviving cannon fire and changing cover.
4. **Extract:** reach the unlocked exit and survive its countdown before the deadline.
5. **Debrief:** see the result, then return to the lobby for another round.

There are no respawns during a round. Eliminated players spectate living teammates; players arriving after deployment wait for the next round. The gunship wins if everyone on the ground is eliminated or the timer expires without a successful extraction.

## Planned MVP content

| Feature | First release scope |
| --- | --- |
| Battlefield | One ruined industrial district with indoor cover and exposed routes |
| Aircraft | One visible, automatically orbiting gunship; no piloting controls |
| Weapons | One gunship cannon, one ground rifle, one limited-ammunition anti-air weapon |
| Objectives | Three team-shared items placed at validated randomized locations |
| Destruction | Selected cover changes from intact to damaged to destroyed |
| Survival | No respawns; spectating and a clear round result |
| Progression | Each round starts fresh; no persistent inventory or economy |

The initial input target is desktop keyboard and mouse. Touch and gamepad support are deferred unless the scope changes. This is a design default, not a claim that device compatibility has been tested.

## Planned controls

These are initial bindings to validate during implementation. The in-game help will show the actual supported controls.

| Action | Ground player | Gunship operator |
| --- | --- | --- |
| Move / look | WASD / mouse; Space to jump | Mouse moves targeting view |
| Fire | Left mouse button | Left mouse button |
| Aim / zoom | Right mouse button to aim | Mouse wheel to zoom |
| Reload / weapon | R / number keys 1–2 | Cannon reloads on cooldown |
| Interact | E near a mission item | — |
| Help | On-screen Help button | On-screen Help button |

## What this game is aiming for

The tension comes from movement and counterplay. Ground players should have useful cover, readable danger, and meaningful chances to damage the aircraft. The gunship should feel powerful while needing good timing and target selection. Weapon damage, orbit speed, and timers will be tuned through multiplayer playtests rather than treated as finished balance values.

The MVP excludes free flight, full building collapse, vehicles, additional maps, crafting, ranked matchmaking, purchases, and persistent progression. Visuals are intended to be stylized and readable, with no graphic gore.

## Follow development or contribute

- [Game design](game-design.md) explains the rules and edge cases.
- [Roadmap](roadmap.md) shows each phase and the experience it delivers.
- [Requirements](requirements.md) connects features to implementation plans and test obligations.
- [Development guide](docs/development.md) explains building the scaffold and the future Studio workflow.
- [Architecture](architecture.md) explains how the game will be organized.
- [Testing strategy](docs/testing.md) describes automated checks and multiplayer validation.

The source lives in [hanegraaff/roblox-c130-extraction-shooter](https://github.com/hanegraaff/roblox-c130-extraction-shooter). There is no public release yet; GitHub source availability is separate from Roblox availability.
