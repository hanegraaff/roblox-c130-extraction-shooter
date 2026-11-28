# C-130 Assault roadmap

Roblox development began with a small circular arena that could prove the central matchup. A single operator needed to see and engage the same battlefield that a Ground team was crossing. Once both sides could fight and finish a round, the map grew into a 720-stud warzone with multi-story landmarks, cover that opens under fire, and reusable rules for restoring the world between matches.

The focus then shifted to how a match feels from either side. A protected lobby and an aircraft arrival countdown give players time to orient themselves. Custom Blender environments, aircraft and equipment make the battlefield readable from the ground and through thermal sights. Mobile controls and a live balance panel make the same game easier to play and tune across devices and team sizes. [Game overview](README.md#game) · [Design contract](game-design.md)

<a name="public-mvp-launch"></a>

## MVP completion

The owner can declare the MVP complete with the game, illustrated README and Roblox listing preview accepted. Access may stay private, and the candidate can use its existing balance settings. The final MVP test includes the deferred three-client launcher transfer, firing, recovery and replay cases. The launcher model's desktop and phone fit review also remains open. [Launcher evidence](plans/29-rocket-launcher-model.md#completion-record)

| Plan | Status | Depends on |
| --- | --- | --- |
| [P26 · Live balance panel](plans/26-live-balance-panel.md) | Complete | P25 |
| [P27 · Mouse aiming, mobile controls and compact HUD](plans/27-ground-aim-and-mobile-controls.md) | Complete | P24, P25 |
| [P28 · C-130 model in flight](plans/28-c130-model.md) | Complete | P24, P25, aircraft references |
| [P29 · Rocket launcher model in play](plans/29-rocket-launcher-model.md) | Deferred | P25, launcher references |
| [P30 · Medkits at each battlefield building](plans/30-single-use-medkits.md) | Complete | P26, P27, medkit references |
| [P31 · Darker starting bunker](plans/31-bunker-thermal-contrast.md) | Complete | P18, Sandbreak |
| [P33 · Write the C-130 Assault README](plans/33-rewrite-readmes.md) | Complete | Integrated P26–P31 source |
| [P34 · Prepare the C-130 Assault Roblox page](plans/34-arcade-game-page.md) | Planned | P27–P31 |

### After MVP completion

The owner can schedule larger-roster balance trials when testers are available. A public release adds live capacity, performance, asset and audience verification on the selected candidate. The legacy handoff closed with the game reconstructable from source. The live 6- and 10-player, performance and public access checks await a named release. Controller support remains a future enhancement. [Legacy handoff](plans/12-mvp-release.md#user-directed-implementation-closeout) · [Release runbook](docs/release.md)

| Plan | Status | Depends on |
| --- | --- | --- |
| [P32 · Compare balance across team sizes](plans/32-balance-playtests.md) | Deferred | MVP completion and testers for 2-, 6- and 10-player matches |
| [P35 · Verify and open the public experience](plans/35-public-launch.md) | Deferred | MVP completion and owner request for public release |

## Plan index

Plan records hold acceptance criteria, tested revisions and evidence. The index also retains the cancelled level-selection proposal. [Evidence archive](docs/evidence/README.md) · [Earlier roadmap records](https://github.com/hanegraaff/roblox-c130-extraction-shooter/blob/fc8febb13d25189d21d9c28a42f9f4525af5990d/roadmap.md)

| Plan | Status | Depends on |
| --- | --- | --- |
| [P01: Executable foundation and tests](plans/01-foundation.md) | Complete | — |
| [P02: Circular greybox battlefield](plans/02-warzone-map.md) | Complete | P01 |
| [P03: Roles and round lifecycle](plans/03-rounds-and-roles.md) | Complete | P02 |
| [P04: Perimeter aircraft and inward thermal view](plans/04-aircraft-and-thermal.md) | Complete | P03 |
| [P13: Expanded terrain and multi-story buildings](plans/13-terrain-and-buildings.md) | Complete | P04 |
| [P14: Directional aircraft targeting](plans/14-aircraft-panning.md) | Complete | P13 |
| [P05: 30mm and 105mm gunship combat](plans/05-gunship-combat.md) | Complete | P04, P14 |
| [P06: M-7 fire and aircraft destruction](plans/06-ground-combat.md) | Complete | P05 |
| [P07: Progressive building-panel destruction and physics](plans/07-destruction.md) | Complete | P06, P13, P14 |
| [P16: Detailed military-outpost assets](plans/16-blender-military-outpost-assets.md) | Complete | P07, P13 |
| [P17: Replace the smaller Outpost](plans/17-integrate-military-outpost.md) | Complete | P16, P07, P13, P14 |
| [P08: Recoverable map rocket launcher](plans/08-rocket-launcher.md) | Complete | P07 |
| [P09: Complete team win/loss and replay loop](plans/09-match-outcomes.md) | Complete | P08, P17 |
| [P10: Combat presentation and spectating](plans/10-player-experience.md) | Complete | P09 |
| [P11: Balance, performance and resilience](plans/11-balance-and-performance.md) | Complete | P10 |
| [P12: Reconstructable implementation handoff](plans/12-mvp-release.md) | Complete | P11 |
| [P18: Game rebalancing](plans/18-game-rebalancing.md) | Complete | P07, P08, P14, P17, Seedship PR #62 |
| [P19: Weapon impacts, blast radius and audio](plans/19-weapon-impacts.md) | Complete | P05, P07, P08, P10, P11, P18 |
| [P20 · Sculpt the oversized bust](plans/20-lobby-bust.md) | Complete | Supplied bust and room references |
| [P21 · Build the complete lobby in Blender](plans/21-lobby-interior.md) | Complete | P20 visual approval |
| [P22 · Replace the protected Roblox lobby](plans/22-integrate-lobby.md) | Complete | P20 and P21 visual approvals, P02, P03 |
| [P23 · Lobby return, theater spectating and intermission](plans/23-lobby-return-and-intermission.md) | Complete | P03, P09, P10, P22 |
| [P24 · Ground head start and C-130 arrival](plans/24-ground-scatter-and-aircraft-arrival.md) | Complete | P03, P04, P09, P23 |
| [P25 · Weapon cooldowns, rocket damage and rifle ammunition](plans/25-weapon-cooldowns-and-rifle-ammo.md) | Complete | P05, P06, P08, P18, P19 |
| [P15: Interchangeable levels](plans/15-interchangeable-levels.md) | Cancelled | — |
| [Vesper Array radar outpost](docs/evidence/vesper-import-preflight.md) | Complete | P13 site dimensions, P07 |

## How plans move

Resume an in-progress plan or select one ready plan with complete prerequisites and the required source on its branch. Planned work awaits sequencing, blocked work has a concrete missing prerequisite, and deferred work awaits owner scheduling. A complete plan has its required verification, current documentation and source pushed for review. Record acceptance and integration in the plan. [Feature workflow](.agents/skills/implement-next-plan/SKILL.md)
