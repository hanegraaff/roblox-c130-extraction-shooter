# Decisions, defaults, and open release details

Recorded 2026-11-07 from the supplied design conversation. “Selected” means explicit user choice or a central premise of that conversation. “Default” means a concrete initial implementation choice that can be revised without pretending the user chose it.

| ID | State | Decision and reason | Revisit when |
| --- | --- | --- | --- |
| D01 | Selected | 6–10 players: one gunship operator and 5–9 ground players | User changes match scope |
| D02 | Selected | Thermal targeting; scripted visible orbit; no manual piloting | Post-MVP flight proposal |
| D03 | Selected | Partial destruction via prefabricated states; no full collapse | Cover tests show a missing gameplay need |
| D04 | Selected | No respawns during a round; eliminated players spectate | User changes survival rules |
| D05 | Default from final scope | One cannon, rifle and anti-air; defer earlier mention of a second aircraft weapon | Combat slice is fun and tested |
| D06 | Default from design | Three shared items, one exit, ten-minute round; first extraction wins | Balance sessions justify tuning |
| D07 | Default | Disabled aircraft loses firepower; objectives and deadline remain; operator disconnect has same effect | Playtests show this invites abuse or boredom |
| D08 | Default | Desktop keyboard/mouse MVP; mobile/gamepad deferred | Device target is expanded |
| D09 | Default | Single place and same-server lobby; no persistence, queue service or external backend | Post-MVP progression or matchmaking |
| D10 | Default | Git-first Luau and Rojo; tests separate from release place | Tooling evidence warrants a replacement |
| D11 | Default | Disable world streaming for the bounded MVP district to keep ground and airborne views complete | Measured memory/performance requires streaming; add persistent aircraft and targeting-area tests before enabling |
| D12 | Default | Five-second extraction dwell; server step order resolves death/extraction conflicts | Playtests justify timing changes; preserve deterministic rules |
| D13 | Default | Seeded fair operator rotation; late joins/rejoins wait until next round | Role preference/party systems are added |
| D14 | Default | No friendly fire; direct-fire anti-air without homing; stylized non-graphic effects | User changes combat tone or weapon scope |

D11 deliberately simplifies the conversation's suggested streaming solution. A small map should first prove correctness and performance without remote-camera streaming holes. Enabling streaming later is an architecture change with its own tests, not a silent optimization.

## Open details that do not block initial implementation

| Detail | Needed by | Proposed approach |
| --- | --- | --- |
| Roblox owner/group, universe ID, development and release place IDs | P12; earlier if cloud testing is requested | Record actual values and permissions when supplied; never invent them |
| Named reference desktop and graphics setting | P11 | Record hardware, resolution and quality before profiling; use the budgets in testing.md |
| Final game name, art direction and approved third-party assets | P10 | Use the working title and original greybox assets until then |
| Desired release audience | P12 | Prepare a private test release first; publication still needs explicit authorization |

Tuning defaults (health, ammo, damage, cooldown, orbit radius/altitude, ranges) live in typed configuration once introduced. Plans require tests for invariants and bounds, not frozen assertions of provisional balance values.
