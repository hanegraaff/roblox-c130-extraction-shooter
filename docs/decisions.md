# Decisions, defaults, and open release details

Updated 2026-11-08 for the round prototype and greybox defaults, following the user's players-versus-C-130 revision and confirmation that M-7 fire damages the plane. “Selected” records user choices; “Default” records concrete initial implementation/tuning choices that can be revised. Stable IDs are retained; superseded choices are described in the change record below.

| ID | State | Decision and reason | Revisit when |
| --- | --- | --- | --- |
| D01 | Selected | 6–10 players: one operator versus one united team of 5–9 ground players | User changes match scope |
| D02 | Selected | Thermal targeting, circular map, scripted perimeter orbit, view always toward the main map | User changes view/flight scope |
| D03 | Selected | Partial destruction via prefabricated states; no full collapse | Cover tests show a missing need |
| D04 | Selected | No respawns during a round; eliminated players spectate | User changes survival rules |
| D05 | Selected | C-130: 30mm GAU-23/A Chain Gun and 105mm M102 Howitzer; ground: M-7 rifle plus one map launcher | User changes weapon roster |
| D06 | Selected | Ground team wins on aircraft destruction; C-130 wins on total ground elimination or timeout | User changes match rules |
| D07 | Selected | Three direct rockets destroy an undamaged plane; M-7 fire chips away at the same health pool | User changes aircraft durability |
| D08 | Default | Desktop keyboard/mouse MVP; touch/gamepad deferred | Device target expands |
| D09 | Default | Single place and same-server lobby; no persistence/queue/backend | Post-MVP systems require it |
| D10 | Default | Git-first Luau/Rojo, strict readable code, automated tests separate from release place | Tooling evidence warrants change |
| D11 | Default | Streaming disabled for bounded circular map so airborne and ground views remain complete | Measured performance needs streaming and its additional tests |
| D12 | Default | Deadline wins at exact expiry; otherwise plane destruction wins a same-step mutual kill | Product feedback changes tie handling |
| D13 | Default | Operator rotation prefers the most completed rounds waited, excludes the previous operator when alternatives exist and uses a seeded tie-break over sorted UserIds; late joins/rejoins cannot restore an active life | Party/preference systems are added |
| D14 | Default | No friendly fire; direct-fire rockets without homing; stylized non-graphic effects | User changes combat tone |
| D15 | Selected / default mapping | Switching aircraft weapons changes zoom; default 30mm is tighter than 105mm, no independent zoom control | Playtests tune FOVs or user changes mapping |
| D16 | Default | One fixed reachable launcher anchor; single carrier; drop/recover on death or disconnect; relocate invalid drops | Playtests change placement/transfer rules |
| D17 | Default | Launcher reloads one rocket at a time with replenishing supply, no ammo pickups; reload state follows the weapon | Balance evidence warrants supply changes |
| D18 | Default | Ten-minute round; exact rifle damage, cadence, reload, FOV and orbit speed are tunable | Multiplayer tests justify tuning |
| D19 | Default | Operator disconnect is ground win by forfeit; invalid/empty match aborts | Product changes disconnect policy |
| D20 | Default | Greybox center/focus (0,0,0), radius 180 studs, altitude 140 studs above ground, recovery threshold Y = −30; sheltered southern anchors and two painted center approaches | Required Studio clearance/sight-line review or later balance tests justify changes |
| D21 | Default | Production lobby waits eight seconds before attempting deployment, deployment has a fifteen-second readiness limit, and results last five seconds; the test mapping uses separate accelerated settings | Multiplayer review warrants timing changes |
| D22 | Default | Basic spectators follow the lowest-UserId living ground teammate automatically; use a fixed map overview if no target exists. Ground surrender is an explicit on-screen action | P10 improves spectator controls and feedback |
| D23 | Default / user-directed fix | Waiting players can walk in the protected lobby. In the test mapping, a single Studio client automatically previews the map without creating an active life or opponent; production roster rules remain 6–10. A test-only panel controls solo role previews, requested multiplayer roles, 30/60/180/600-second rounds, explicit start and reset | Human testing needs change |

Aircraft health is derived as three times direct rocket damage. Rifle damage is positive and small; previous rifle hits may reduce the further rockets needed. First and second rockets alone do not destroy a pristine plane. These are hard test invariants, not tuning defaults. Each C-130 weapon retains its independent cooldown/reload across switching.

The circular orbit uses the same center and horizontal radius as the map boundary. The model points along flight travel, while its camera looks at a ground-level map-center focus. Aiming moves the reticle inside that inward view. Exact altitude/FOVs are adjustable, with validation that playable sight lines and weapon ranges remain viable.

## Open details that do not block initial implementation

| Detail | Needed by | Proposed approach |
| --- | --- | --- |
| Roblox owner/group, universe ID, development/release place IDs | P12; earlier if cloud testing requested | Record actual values/access; never invent them |
| Named reference desktop and graphics setting | P11 | Record before profiling against testing.md budgets |
| Final title, art direction and approved assets | P10 | Working title: Players vs C-130; original greybox assets |
| Desired release audience | P12 | Prepare private test candidate; publish only with explicit authorization |

## Design change record

The 2026-11-07 revision removes extraction, mission items, escape zones, the shared collection counter and the aircraft-disabled continuation. P08 now delivers the single launcher pickup; P09 validates the destruction/elimination/timeout loop. D05–D07 and D12 replace their original scope/timing choices. The user confirmed M-7 chip damage in response to the rifle-damage clarification. The GitHub repository retains its original URL/name; renaming it is outside this steering update.
