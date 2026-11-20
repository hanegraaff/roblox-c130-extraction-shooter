# Players vs C-130

![Blender viewport showing the two-story outpost with teal walls, rooftop equipment, balcony and external stairs](blender_outpost.png)

*User-provided P16 Blender authoring viewport, selected 2026-11-13. [Editable source and review views](assets/blender/military-outpost/README.md).*

One player operates a circling C-130 while 5–9 ground teammates try to bring it down. The ground team starts with M-7 rifles and can share one recoverable rocket launcher found on the map. Three direct rockets destroy an undamaged aircraft. Rifle hits reduce the same health pool.

## Play a round

Rounds start in the protected, walkable lobby. With 6–10 players, the server assigns one operator and deploys everyone else as one ground team. The C-130 automatically circles the edge of the 720-stud battlefield. The default round lasts ten minutes, and friendly fire is off.

- **Ground team.** Use the hills and buildings as cover while teammates fire on the aircraft. Follow the teal west route or ochre east route to the center launcher. Lead the moving plane when firing a rocket. The carrier keeps their M-7, and the launcher's four-second reload continues through weapon switches, drops and transfers. A living teammate can recover it after a drop, death or disconnect while the round is active. If the drop position is invalid, the launcher returns to its original anchor.
- **C-130 operator.** Scan the ground through the inward-facing thermal camera. The 30mm GAU-23/A Chain Gun gives a tighter view, and the 105mm M102 Howitzer gives a wider view and blast. Weapon selection changes zoom and preserves the pan, ammunition and reload timing for each weapon. Releasing the directional controls holds the camera angle relative to the plane through its orbit.
- **Spectating.** Ground death, character reset or surrender consumes your round life. The spectator camera follows a living ground teammate when one is available. Late arrivals and reconnecting players wait for the next round. Operator reset replaces the protected station body and preserves aircraft health.

The ground team wins when it destroys the plane. The C-130 wins by eliminating every ground player or surviving until time runs out. A lethal impact must land before the deadline. The ground team wins if the plane is destroyed and the last ground player is eliminated in the same pre-deadline step. A rocket already in flight can still hit after its shooter dies while the round remains active.

If the operator leaves while a ground player is alive, the ground team wins by forfeit. If the last ground player leaves while the operator remains, the C-130 wins by departure. An empty match or failed deployment can end without a winner. All remaining players see the same result and reason. After Results, the lobby camera returns and the battlefield, aircraft and equipment reset for the next round.

## Controls

| Action | Ground player | C-130 operator |
| --- | --- | --- |
| Move and aim | WASD to move, Space to jump, mouse or touch camera to aim | WASD or touch arrows pan, with A left and D right. The mouse or a separate touch aims |
| Recenter view | — | R / Recenter |
| Select weapon | Native tool slots or M-7 / ROCKET touch buttons | 1 / 30mm button or 2 / 105mm button |
| Fire | Hold left mouse / FIRE while equipped | Hold left mouse / FIRE at a valid surface |
| Reload | M-7 with R / RELOAD, launcher reloads automatically | Automatic for each weapon |
| Pick up or drop launcher | E / PICK UP within reach, G / DROP while carrying | — |
| Surrender | Surrender / spectate button during an active life | — |

Both roles see the timer, remaining ground lives and aircraft health during play. Ground players can also see ammunition and whether the launcher is available or carried. Confirmed aircraft hits use **AIRCRAFT HIT −5** or **ROCKET HIT** on desktop, and **HIT** in the weapon readiness row on touch.

## Cover and the Outpost

The battlefield has eight grass and rock hills and three usable two-story buildings. The detailed Outpost has a workshop, upstairs command room, balcony and exterior stairs. The ground camera moves closer inside its rooms as needed and restores the previous outdoor zoom at exit. The orange boundary marks the playable disk. Leaving it or falling below the map returns an active ground player to shelter.

Solid walls hide ground thermal highlights and block shots and blasts. Walls and roofs, including the battlefield starting shelter, show persistent Light damage, open at Heavy damage after three direct 105mm hits, and disappear after three more. Nine earned seconds of valid same-panel 30mm hits advance a stage. Interruptions preserve earned damage and pause its timing. A new opening benefits later impacts. Debris falls against scenery, and floors, stairs, supports and the outside lobby stay intact. [Destruction rules](architecture.md#progressive-panel-destruction-p07)

## Availability

This branch is playable locally in Roblox Studio. The current match build is available for review on `plan/09-match-outcomes`. Integrated `main` includes the playable Outpost and its indoor camera. The older private import workspace is separate from current local play. Complete player guidance, combat audio, balance and performance checks, and real 6- and 10-player Roblox client acceptance are later work. The MVP has one level. [P09 review](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/41), [roadmap](roadmap.md)

## Set up locally

Use macOS with **Git**, **Python 3.10+**, system **curl** and **Roblox Studio** for the complete workflow. Sign in to Studio and keep Play stopped while installing or connecting plugins. Setup requires network access to GitHub releases and the Wally registry. The automated tool setup also supports Linux arm64/x86_64. [Development prerequisites](docs/development.md#install-and-build-from-a-clean-clone)

Clone the repository and select the match candidate. On an existing clone, fetch and switch to the corresponding local tracking branch while preserving local edits.

```sh
git clone --branch plan/09-match-outcomes https://github.com/hanegraaff/roblox-c130-extraction-shooter.git
cd roblox-c130-extraction-shooter
python3 scripts/setup.py
python3 scripts/verify.py
export PATH="$HOME/.rokit/bin:$PATH"
rojo plugin install
```

Setup installs the pinned tools and dependencies. Install the matching Rojo Studio plugin once. The verifier runs host unit and service tests, static checks, asset reconstruction and release isolation, and builds `build/game.rbxlx` and `build/tests.rbxlx`. Create a dedicated task branch before contributor edits. [Branch rules](docs/development.md#branches-ci-and-review)

## Play and develop locally with Rojo

From the repository root, start the development sync server. Keep its terminal running while working. Reuse it if it is already serving the same project and port.

```sh
rojo serve default.project.json --address 127.0.0.1 --port 34873
```

1. In Studio, use **File → Open from File** to open `build/game.rbxlx` as a local document. Reuse the document if it is already open.
2. In Edit mode, open **Plugins → Rojo** and connect to `localhost:34873`. Confirm the **PlayersVsC130** mapping before applying it. If a newly installed plugin's toolbar button is absent, save work and restart Studio once.
3. Click **Play**. Expect **Development** and **Bootstrap running**, a walkable lobby and a round panel waiting for six players. Use the separate test mapping for solo exploration or a smaller active match.
4. After repository edits, stop Play, confirm the same Edit document received the expected change through Rojo, and start fresh Play. If the server restarted or the plugin disconnected, reconnect the existing document in Edit mode. [MCP, sync and troubleshooting](docs/development.md#sync-this-repository-with-studio)

## Run local automated tests

Run `python3 scripts/verify.py` after code or configuration changes. Use `python3 scripts/check_repository.py` for documentation-only changes.

Start the test sync server in another terminal with Rokit on PATH.

```sh
export PATH="$HOME/.rokit/bin:$PATH"
rojo serve test.project.json --address 127.0.0.1 --port 34872
```

1. Open `build/tests.rbxlx` as a separate **local** test document. With Play stopped, connect **Plugins → Rojo** to `localhost:34872` and confirm **PlayersVsC130Tests**. Use this mapping only in the local test document.
2. Click **Play**. Expect **Test** and automatic TestEZ reports in Studio **Output**. The P09 mapping expects **191 server cases and 12 per actual client**, all passing with zero failures, skips or errors. The server waits up to 60 seconds for the first client. Stop and start fresh Play to confirm fresh reports, one status HUD and one round HUD. [Collect Studio smoke reports](docs/testing.md#run-the-studio-smoke-suites)
3. With one client, Play opens the labelled Ground preview. Use the **STUDIO TESTING** panel to cycle **Role** through Auto, Ground and Operator, or move between **Explore map (solo)** and **Return to lobby**. Preview lets you walk the map or use the thermal camera and both zooms while waiting for a match.
4. For an active local match, use Studio **Server & Clients** with **2 clients**, or **3** to exercise launcher transfer and teammate spectating. Set roles and **Next round** duration, then click **Start round now**. Leave an **Auto** choice if nobody selects Operator. Two Operator choices or all Ground choices are rejected with a message.
5. Play through Results and wait for the lobby to return. Start the next round to inspect restored equipment and cover. **Reset test / apply settings** returns to the lobby or solo preview. Test-panel role and duration choices apply to the next explicit start. Use **End Session** when finished.

The [P09 match harness](docs/testing.md#run-the-p09-match-outcome-harness) runs aircraft destruction, elimination, timeout, replay, departure and setup-abort scenarios in actual Studio server/client sessions. The [testing guide](docs/testing.md) also covers targeted launcher, gunship, destruction, camera and Outpost checks. Stop Play and confirm the updated source reached the same test document before collecting fresh evidence.

## Inspect the Blender outpost

Open [military-outpost.blend](assets/blender/military-outpost/military-outpost.blend) in **Blender 5.3.0** to explore the exterior, furnished rooms, saved views and six material and shape damage families. Run `python3 scripts/p16_audit.py` to check the committed package without launching Blender. [Asset review guide](assets/blender/military-outpost/README.md), [in-game Outpost record](plans/17-integrate-military-outpost.md)

## Follow development or contribute

- [Game design](game-design.md) and [requirements](requirements.md)
- [Development guide](docs/development.md), [architecture](architecture.md) and [testing guide](docs/testing.md)
- [Author Roblox assets](.agents/skills/author-roblox-assets/SKILL.md) and [import Blender assets into Roblox](.agents/skills/import-blender-to-roblox/SKILL.md)
