# Decisions, defaults, and open release details

Updated 2026-11-09 for the P14 panning candidate and the expanded terrain/building and physical-destruction scope, following the user's players-versus-C-130 revision and confirmation that M-7 fire damages the plane. “Selected” records user choices; “Default” records concrete initial implementation/tuning choices that can be revised. Stable IDs are retained; superseded choices are described in the change record below.

| ID | State | Decision and reason | Revisit when |
| --- | --- | --- | --- |
| D01 | Selected | 6–10 players: one operator versus one united team of 5–9 ground players | User changes match scope |
| D02 | Selected | Thermal targeting, circular map, scripted perimeter orbit, view always toward the main map | User changes view/flight scope |
| D03 | Selected | MVP building panels have visible progressive destruction and real fragment physics, using prefabricated residual geometry; full structural collapse remains excluded | User changes structural scope |
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
| D20 | Default | Expanded-map candidate: center/focus (0,0,0), radius 360 studs, altitude 140 studs, recovery Y=−30; lobby anchors at X=520. Prior P02/P04 evidence used radius 180 | Later geometry/balance evidence warrants tuning |
| D21 | Default | Production lobby waits eight seconds before attempting deployment, deployment has a fifteen-second readiness limit, and results last five seconds; the test mapping uses separate accelerated settings | Multiplayer review warrants timing changes |
| D22 | Default | Basic spectators follow the lowest-UserId living ground teammate automatically; use a fixed map overview if no target exists. Ground surrender is an explicit on-screen action | P10 improves spectator controls and feedback |
| D23 | Selected | Waiting players can walk in the protected lobby; human testing supports solo exploration, role choice, immediate start and settings controls isolated from release builds | User changes human-testing workflow |
| D24 | Default | Solo test Play opens Ground preview; role cycles Auto/Ground/Operator, next-round durations are 30/60/180/600 seconds (default 60), and preferences last for the local session/reset only | Human testing needs more settings or different defaults |
| D25 | Default | Orbit period 90 seconds, increasing phase from positive X toward positive Z; use the server canonical anchored model with ordinary replication and no cosmetic shell | Measured visual stepping or balance warrants a bounded smoothing/tuning change |
| D26 | Default | GAU23 FOV 35°, M102 FOV 60°, reticle central 70%, keys 1/2 or named buttons. P14 integrates raw pointer input before the reticle clamp and preserves focus through acknowledged zoom | P14 camera-feel/readability tests |
| D27 | Selected | Double implemented battlefield diameter: 360 → 720 studs; radius 180 → 360, four times the area; orbit continues matching the perimeter | User changes level scale |
| D28 | Selected | Authored terrain, two large buildings and one smaller building, all at least two stories with usable upper floors; dedicated construction P13; primitive art is sufficient | User changes level content |
| D29 | Selected / default control | Mouse movement pans the inward aircraft view while weapon zoom still applies. Default: bounded edge pan, world-space focus retained across orbit/zoom, explicit recenter, no independent zoom or manual flight | P14 operated review tunes control/speed/edge zone |
| D30 | Selected | Large building panels; average room approximately two panels wide and one tall. Three direct heavy-cannon hits → roughly 50%-destroyed variant; three more → fully destroyed. Nine seconds sustained on-panel 30mm fire damages a panel; progression must be visible | User changes structural thresholds |
| D31 | Selected | User confirmed the heavy weapon stays 105mm M102 Howitzer and the new panel-damage rules apply to it; the revision's 120mm reference does not change the roster | User changes weapon roster |
| D32 | Default | 16×8-stud panels, 32-stud representative room width; damaged face has 45–55% open area. Static supporting frames/floors/stairs; destructible exterior panels on every story and roofs of all buildings | P13 avatar/architecture and P07 opening checks |
| D33 | Default | Each stage takes three heavy-hit credits or nine valid 30mm seconds; mixed credit is proportional (one heavy hit = three seconds). Further nine seconds destroys Damaged. Cadence-derived gap tolerance; interruption/miss/blocked shot/target change clears only uncommitted 30mm credit, not heavy credit or completed stages. Direct impacts alone cause structural damage | P05/P07 cadence and mixed-fire tests; user changes policy |
| D34 | Selected / default constraints | Physical fragment motion/collision is MVP scope. Default: server-owned bounded fragments collide with static scenery only, cannot damage/push players, block gameplay queries/routes or cause chain collapse; count/impulse/lifetime caps and reset cleanup required | P07 actual physics and P11 profiling |
| D35 | Selected sequencing / default asset scope | Demonstrate full level/destruction mechanics with simple graphics in MVP. Refined assets get dedicated later plans; P10 handles readable presentation, not a mandatory high-detail art pass | A separately scoped post-MVP asset plan is approved |
| D36 | Default | P13 construction uses Foundry/Warehouse 64×48 (3072 square studs each), Outpost 32×48 (1536); two floors with ground top Y=0.125, upper top Y=10.125, roof center Y=20.625, sixteen 0.625-rise / 2-run / 8-wide stair treads, 32-stud room bays and 111 wall/roof/interior panels. Eight fixed Grass/Rock caps use nominal apex Y=16, four-stud voxels and bounded recipe v1/seed 0. A future 750-stud range budget covers the full disk at altitude 140; it is feasibility evidence, not implemented weapon range | Navigation, visibility and later combat/balance tests justify tuning |

| D37 | Default | P14 candidate: outer 12% viewport edge zone, speed ramps to 120 studs/second, per-update delta cap 0.1 seconds, R / Recenter button returns to center. Raw pointer input drives pan before the central-70% displayed reticle clamp; actionable UI/text focus, viewport exit and window focus loss suspend pan. Focus is world-space X/Z at ground height; new role/round entry resets it. Battlefield/AimEnvelope NumberValues bound aim to Y=−1…32 studs, covering current terrain/roofs. These defaults await operated engine review | P14 coverage, input/layout and comfort evidence warrants tuning |

Aircraft health is derived as three times direct rocket damage. Rifle damage is positive and small; previous rifle hits may reduce the further rockets needed. First and second rockets alone do not destroy a pristine plane. These are hard test invariants, not tuning defaults. Each C-130 weapon retains its independent cooldown/reload across switching.

The circular orbit uses the same center and horizontal radius as the map boundary. The model points along flight travel. The P14 candidate uses a mouse-panned focus clamped within the disk, still inward-facing and retained across weapon-linked zoom changes; main’s earlier baseline uses fixed map-center focus. Exact altitude/FOVs are adjustable, with validation that playable sight lines and weapon ranges remain viable.

## Open details that do not block initial implementation

| Detail | Needed by | Proposed approach |
| --- | --- | --- |
| Roblox owner/group, universe ID, development/release place IDs | P12; earlier if cloud testing requested | Record actual values/access; never invent them |
| Named reference desktop and graphics setting | P11 | Record before profiling against testing.md budgets |
| Final title, art direction and approved assets | P10 | Working title: Players vs C-130; original greybox assets |
| Desired release audience | P12 | Prepare private test candidate; publish only with explicit authorization |

## Design change record

The 2026-11-07 revision removes extraction, mission items, escape zones, the shared collection counter and the aircraft-disabled continuation. P08 now delivers the single launcher pickup; P09 validates the destruction/elimination/timeout loop. D05–D07 and D12 replace their original scope/timing choices. The user confirmed M-7 chip damage in response to the rifle-damage clarification. The GitHub repository retains its original URL/name; renaming it is outside this steering update.

The 2026-11-08 level revision supersedes fixed center-only aiming and generic cosmetic-only cover breakage. D27–D30 record selected scale/content/pan/threshold requirements; D31 records the confirmed existing 105mm heavy weapon, and D32–D34 distinguish construction, sustained/mixed-fire and fragment defaults. Required mechanics and physics belong in the MVP; higher-detail asset generation is deferred separately (D35). Existing P02/P04 implementation and evidence remain historical facts.
