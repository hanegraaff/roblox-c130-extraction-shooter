# Players vs C-130

![Blender viewport showing the two-story outpost with teal walls, rooftop equipment, balcony and external stairs](blender_outpost.png)

*User-provided P16 Blender authoring viewport, selected 2026-11-13. [Editable source and review views](assets/blender/military-outpost/README.md).*

One player operates a circling C-130 while a team of 1–9 Ground players tries to bring it down. Ground starts with M-7 rifles and can recover four rocket launchers from the map, carrying one per player. With the shipped settings, aircraft health starts at **1,000 per Ground player** in the deployment roster. That maximum stays fixed for the round. Direct rockets deal **150 damage** and M-7 hits deal **5** to the same health pool.

## Play a round

Rounds start in the protected, walkable lobby. By default, with 2–10 players, the server assigns one operator and deploys everyone else as one ground team. Once the deployed avatars are ready, Ground gets **20 seconds** to spread out, take cover or pick up and drop a launcher. Ground sees **C-130 arrives in 20** on desktop or the compact **C-130 in 20s** on touch. The operator sees the same time on a full black screen that clears when the thermal view is ready. Both sides can fire when the aircraft appears and begins to circle the edge of the 720-stud battlefield. The ten-minute combat clock starts at that moment. Friendly fire is off.

From the ground, look for the high-wing C-130 with olive-and-gray camouflage, a brushed shark face painted across the nose, four spinning propellers and a howitzer on its right side. Hits on the airframe reduce its shared health. [Blender preview from below](assets/exports/c130/c130-painted-preview.png)

The stone bust faces you as you arrive. Turn left for the theater and its television, or right for the gallery's two photographs and four oil portraits.

- **Ground team.** Follow the trails from any Sandbreak exit. Pick up a launcher inside the Salt Flats hangar, outside Vesper Radar’s south gate, outside the military depot by the parking lot, or inside the Prism Seedship on its lower deck. Buildings and large rock formations provide cover. Keep your M-7 when you pick up a launcher. The rifle has a **30-round magazine**, **unlimited reserve** and a **two-second reload**. Each launcher reloads automatically in **15 seconds** after firing. Its timer follows the launcher through weapon switches, drops and transfers. A living teammate can recover it after a drop, death or disconnect if the round continues. If the drop position is invalid, the launcher returns to its original anchor. All four launchers start loaded each round.
- **C-130 operator.** Scan for bright white Ground silhouettes against dark grayscale terrain and scenery in the thermal view. The aircraft body is hidden from its operator’s targeting view while remaining visible to Ground players. The 30mm GAU-23/A Chain Gun gives a tighter view. The 105mm M102 Howitzer gives a wider view and blast, then automatically reloads **12 seconds** after firing. Weapon selection changes zoom and preserves the pan, ammunition and reload timing for each weapon. WASD or touch arrows pan across the level’s 720 × 720-stud square. The square edges stop movement on that axis while allowing movement along the edge and immediate reversal. Releasing the controls holds the target point on the map as the plane continues its orbit.
- **After elimination.** Ground death or character reset consumes your round life during the head start or combat and sends you back to the lobby. Players joining or reconnecting mid-round also start in the lobby. Once the aircraft arrives, walk up to the theater TV and choose **Spectate** to follow a living Ground player. The still image stays on the TV. Choose **Exit spectating** to take control of your avatar at the TV. An operator who resets during the head start or combat gets a new protected station body and keeps the role and aircraft health.

In the local P29 candidate, look for the sand-and-graphite launcher with its teal stripe and raised handle. You see the same model in your avatar’s hand and resting on its side after a drop. [Depot launcher preview](assets/exports/rocket-launcher/three-quarter.png)

The ground team wins when it destroys the plane. The C-130 wins by eliminating every ground player or surviving until time runs out. A lethal impact must land before the deadline. The ground team wins if the plane is destroyed and the last ground player is eliminated in the same pre-deadline step. A rocket already in flight can still hit after its shooter dies while the round remains active.

If the operator leaves while a ground player is alive, the ground team wins by forfeit. If the last ground player leaves while the operator remains, the C-130 wins by departure. An empty match or failed deployment can end without a winner. An ending during the head start cancels aircraft arrival. At the result, surviving players return to the lobby and spectator mode closes. Everyone can walk around while the HUD shows the result and the **two-minute intermission**. The battlefield resets during that time. The next match can deploy after the countdown when the lobby meets its player minimum.

## Controls

### Ground

Mouse movement turns your view and your avatar follows the horizontal aim while staying upright. The rifle and launcher both aim through the same raised crosshair, which stays horizontally centered.

| Action | Desktop | Touch |
| --- | --- | --- |
| Move and jump | **WASD** relative to the view, **Space** to jump | Movement stick and jump button |
| Look and aim | Move the mouse | Drag on the battlefield view |
| Zoom | Mouse wheel | Roblox camera zoom gesture |
| Select a weapon | Native tool slots | **M-7** or **ROCKET** when available |
| Fire | Hold left mouse with a weapon equipped | Hold **FIRE** with a weapon equipped |
| Reload | **R** for the M-7 | **RELOAD** for the M-7 |
| Pick up or drop a launcher | **E** within reach, **G** while carrying | **PICK UP** within reach, **DROP** while carrying |
| Free the cursor | Hold **Left Alt** to use buttons | — |

### C-130 operator

| Action | Desktop | Touch |
| --- | --- | --- |
| Pan | **WASD**, with **A** left and **D** right | Directional arrows |
| Aim | Move the mouse | Touch and drag on the battlefield view. Use a separate touch to pan at the same time |
| Select a weapon | **1** for 30mm, **2** for 105mm | **30mm** or **105mm** |
| Fire | Hold left mouse at a valid surface | Hold **FIRE** at a valid surface |
| Recenter | **R** | **Recenter** |

The launcher and both aircraft weapons reload automatically. During combat, both roles see the clock, the number of Ground players still alive and the aircraft's health. Ground also sees personal health and the equipped weapon's readiness. The rifle shows **30 / ∞** when full and keeps its loaded count visible during reload. On touch, the HUD keeps status near the edges and shows launcher actions when they become available. The Roblox player list is hidden during touch combat and returns in the lobby. The operator sees the selected weapon and its ammunition or reload status.

At the theater TV, use the **Spectate** prompt. While watching, use **Previous** or **Next** to switch between living Ground players when more than one is available. Desktop players can also press **[** or **]**.

On desktop, press **P** or select **Settings** to adjust **Effects** and **Camera shake**. Use **↑/↓** to select a setting and **←/→** to change it, or click a setting to cycle through **Off**, **Reduced** and **Full**. Ground movement and firing pause while the menu is open. Choices last for the play session and start at Full effects and Reduced shake. Effects change cue sounds, pulses and impact visuals. Shake briefly affects the lobby camera after aircraft destruction.

## Battlefield cover

Sandbreak and Salt Flats sit in yellow sand among stock boulders, cacti and dry brush. The trail toward Vesper turns to forest soil beneath pines and redwoods. The military depot sits beside worn asphalt, a striped parking lot and a line of telephone poles. South of Sandbreak, rust-red terrain fades into the desert and depot gravel. Follow the south trail to the landed Prism Seedship. Its twin stairs lead up to observation galleries, and the S-4 recovery bay on the lower deck holds the preserved alien. A shallow crater, boulders and low ridges surround the site. [District screenshots](docs/evidence/districts/README.md) · [Southern basin](docs/evidence/seedship-mars/basin.jpg)

Salt Flats Hangar occupies the former Foundry site. The full-size hangar has twin aircraft bays, four accessible levels, and a walk-in C-130 wreck beside the apron. The wreck offers overhead cover until a direct howitzer hit or three uninterrupted seconds of 30mm hits destroy it. Vesper Array occupies the former Warehouse site. Four entrances open onto a courtyard beneath the radar dish. Twin stairs lead to the observation gallery. The dish and the strip beneath the gallery give temporary cover, and the open roof exposes much of the route to the aircraft. The detailed Outpost has a workshop, upstairs command room, balcony and exterior stairs. The Ground camera automatically moves closer as needed in the Outpost workshop and upstairs command room. It restores your previous zoom when you leave those rooms. The orange boundary marks the playable disk. Leaving it or falling below the map returns an active ground player to shelter.

Ground players deploy inside the Sandbreak bunker at the original spawn site. Four entrances lead out past the roof breach, nearby vehicle wrecks, and radio relay. [Sandbreak import and review](assets/blender/spawn-bunker/IMPORT.md)

Solid walls hide Ground thermal highlights and block shots and blasts. With the default Medium panel damage, one direct 105mm hit destroys a wall or roof panel. Two earned seconds of valid same-panel 30mm hits destroy it too: earlier hits show Light damage, and one earned second opens the Heavy damage variant. Interruptions preserve earned damage and pause its timing. The same rules apply to Sandbreak, the hangar, radar, depot and Seedship. A new opening benefits later impacts. Debris falls against scenery, and floors, stairs, supports and the outside lobby stay intact. [Destruction rules](architecture.md#progressive-panel-destruction-p07)

A howitzer shell bursts wherever it first hits the battlefield, including empty ground. A shell that lands next to a building can open several exposed panels within **25 studs** of the contact point. Solid cover at the start of the combat step still shields players and panels. With Effects set to Full, the howitzer burst has a brighter expanding fireball and a more visible smoke plume. Reduced uses a smaller, shorter burst, and Off clears the local effects. The 30mm uses a smaller burst, and rockets leave smoke and burst on contact. The howitzer has a deep thump, while 30mm impacts are shorter. Ground and metal contacts sound different. [Weapon impacts plan](plans/19-weapon-impacts.md)

## Availability

The integrated game on `main` includes the painted C-130, balance editor, Ground mouse look, raised crosshair and compact touch HUD. The depot launcher model is available for local Studio testing on `plan/29-rocket-launcher-model`. Its desktop and phone review and three-client checks are pending. Controller support and medkit pickups are planned. [Depot launcher plan](plans/29-rocket-launcher-model.md) · [Roadmap](roadmap.md)

The lobby **Balance** panel lets the experience owner and trusted testers adjust health, damage, weapon timing, panel durability, round length, intermission and minimum players. Ordinary local Studio Play uses the defaults in this guide. The owner confirmed balance changes took effect across rounds in the private two-player Roblox playtest. Public release checks are pending. [Owner guide](docs/balance.md) · [Panel verification](plans/26-live-balance-panel.md#completion-record) · [Future release checklist](docs/release.md)

## Set up locally

Use macOS with **Git**, **Python 3.10+**, system **curl** and **Roblox Studio** for the complete workflow. Sign in to Studio and keep Play stopped while installing or connecting plugins. Setup requires network access to GitHub releases and the Wally registry. The automated tool setup also supports Linux arm64/x86_64. [Development prerequisites](docs/development.md#install-and-build-from-a-clean-clone)

Clone `main` for the integrated build. To test the depot launcher model, use `--branch plan/29-rocket-launcher-model` in the clone command and run the same setup steps.

```sh
git clone --branch main https://github.com/hanegraaff/roblox-c130-extraction-shooter.git
cd roblox-c130-extraction-shooter
python3 scripts/setup.py
python3 scripts/verify.py
export PATH="$HOME/.rokit/bin:$PATH"
rojo plugin install
```

On an existing clone, preserve your local edits and run `git fetch origin`. Switch with `git switch main` for the integrated build or `git switch plan/29-rocket-launcher-model` for the depot launcher candidate. Run `git pull --ff-only` to update the selected branch, then run setup and verification from the repository root.

For the editable lobby assembly, open `assets/blender/lobby-interior/waiting-lobby.blend` in Blender 5.3.0 and choose **Render → Render Image** from the saved arrival camera. [Room views and camera guide](assets/blender/lobby-interior/README.md)

Setup installs the pinned tools and dependencies. Install the matching Rojo Studio plugin once. The verifier runs host unit and service tests, static checks, asset reconstruction and release isolation, and builds `build/game.rbxlx` and `build/tests.rbxlx`. Create a dedicated task branch before contributor edits. [Branch rules](docs/development.md#branches-ci-and-review)

## The two Studio files

**Always publish from `build/game.rbxlx`.** Use the same two filenames for every update.

| File | Purpose | Rojo connection |
| --- | --- | --- |
| `build/game.rbxlx` | Play the game and publish it to Roblox | **PlayersVsC130**, port **34873** |
| `build/tests.rbxlx` | Run local tests and use the test controls | **PlayersVsC130Tests**, port **34872** |

The build commands update these files in place. Keep their Studio documents open and use the matching Rojo connection to bring source changes into them. Before publishing, stop Play and confirm the game document contains the latest changes. Rebuilding a file on disk does not refresh a document already open in Studio. If live sync is disconnected, reconnect it or reopen the same file after preserving any unsaved work.

Publish updates from the same game document to the same Roblox place. **Publish As** chooses the destination the first time. Once that document is linked to the correct place, use **Publish** for later updates. Build hashes and Roblox version numbers identify releases in the verification records.

## Publish and play privately

1. In Creator Dashboard, select the approved test experience. Open **Publish settings → Manage Audience → Manage access → Playtest**, set the audience to **Playtesters**, and save. Set the start place’s player limit to **10**. [Roblox audience settings](https://create.roblox.com/docs/production/publishing/publish-games-and-places#target-audience)
2. Note the place’s current published version for rollback. Open `build/game.rbxlx` in Studio, choose **File → Publish As**, and select the approved experience and its existing start place. [Roblox Version History](https://create.roblox.com/docs/projects/version-history)
3. Open the published place in Studio and use **Collaborate** to grant each invited tester **Play** access. In Creator Dashboard, use **⋯ → Copy URL** on the experience tile and share it with those testers. [Roblox collaborator permissions](https://create.roblox.com/docs/projects/collaboration#manage-collaborators), [Copy the Roblox link](https://create.roblox.com/docs/projects/configure-games#copy-landing-page-link)
4. Have everyone open the link in the **Roblox app** and join the same server. You can start with **two players total**, including you. For a larger match, keep everyone connected until the next round starts with the full group.

The [P12 handoff record](plans/12-mvp-release.md#authorization-and-destination-access) preserves the earlier destination and authorization scope. Any future publication must have authorization covering its actual candidate, place and audience; closing the handoff or merging source does not publish it. The [release runbook](docs/release.md) covers future destination/access checks and live validation.

## Play and develop locally with Rojo

From the repository root, start the development sync server. Keep its terminal running while working. Reuse it if it is already serving the same project and port.

```sh
rojo serve default.project.json --address 127.0.0.1 --port 34873
```

1. In Studio, use **File → Open from File** to open `build/game.rbxlx` as a local document. Reuse the document if it is already open.
2. In Edit mode, open **Plugins → Rojo** and connect to `localhost:34873`. Confirm the **PlayersVsC130** mapping before applying it. If a newly installed plugin's toolbar button is absent, save work and restart Studio once.
3. Click **Play** to check the walkable lobby and the HUD waiting for two players. Take either doorway to the theater or gallery and walk back to the entrance. Use **Server & Clients** with two clients to start a match and watch the shared 20-second countdown lead into ten minutes of combat. The separate test mapping offers solo exploration and explicit role and round controls. [Aircraft arrival checks](docs/testing.md#run-the-p24-aircraft-arrival-harness) · [Lobby and theater checks](docs/testing.md#run-the-p23-lobby-and-intermission-harness)
4. After repository edits, stop Play, confirm the same Edit document received the expected change through Rojo, and start fresh Play. If the server restarted or the plugin disconnected, reconnect the existing document in Edit mode. [MCP, sync and troubleshooting](docs/development.md#sync-this-repository-with-studio)

## Run local automated tests

Run `python3 scripts/verify.py` after code or configuration changes. Use `python3 scripts/check_repository.py` for documentation-only changes.

Start the test sync server in another terminal with Rokit on PATH.

```sh
export PATH="$HOME/.rokit/bin:$PATH"
rojo serve test.project.json --address 127.0.0.1 --port 34872
```

1. Reuse the existing **local** test document; for its first setup, open `build/tests.rbxlx` separately from the game/cloud document. With Play stopped, connect **Plugins → Rojo** to `localhost:34872` and confirm **PlayersVsC130Tests**. Use this mapping only in the local test document.
2. Click **Play**. Expect automatic TestEZ reports in Studio **Output** and a **Test** bootstrap panel while the test runtime starts. Require nonzero discovery in the server report and every actual client report, with all cases passing and zero failures, skips or errors. Take expected counts from the current source and its verification record. The server waits up to 60 seconds for the first client. Stop and start fresh Play to confirm fresh reports, one bootstrap status owner and one visible round HUD after startup. [Collect Studio smoke reports](docs/testing.md#run-the-studio-smoke-suites)
3. With one client, Play opens the labelled Ground preview. Use the **STUDIO TESTING** panel to cycle **Role** through Auto, Ground and Operator, or move between **Explore map (solo)** and **Return to lobby**. Preview lets you walk the map or use the thermal camera and both zooms while waiting for a match.
4. For an active local match, use Studio **Server & Clients** with **2 clients**. Use **3** clients for launcher handover or theater spectating after elimination, or **4** to give the viewer two living targets to cycle through. Set roles and **Next round** combat duration, then click **Start round now**. Leave an **Auto** choice if nobody selects Operator. Two Operator choices or all Ground choices are rejected with a message. The 20-second head start precedes the selected combat duration.
5. Play through Results and inspect the lobby return and restored cover. **Reset test / apply settings** returns to the lobby or solo preview. The ordinary test panel supports quick replay, and the P23 harness checks the full intermission. Use **End Session** when finished. [P23 Studio procedure](docs/testing.md#run-the-p23-lobby-and-intermission-harness)

To try the live settings controls locally, stop Play in the test document and enter `game.ServerStorage.DevelopmentSettings:SetAttribute("ManualHarness", "P26Panel")` in Studio’s Command Bar. Click **Play**, open **Balance** in the lobby, then save and apply a named preset. The first client is the test owner. Stop the session and clear the selector with `game.ServerStorage.DevelopmentSettings:SetAttribute("ManualHarness", nil)`. [Test with a second player](docs/balance.md#try-it-in-studio) · [Automated panel check](docs/testing.md#verify-the-live-balance-panel)

Use two Studio clients to verify the C-130's reveal, full orbit, four propellers, gunship views, hit surfaces and appearance on replay. To check Ground mouse look, indoor zoom, both touch roles and the arrival HUD, run an operated match and its replays. [Aircraft model checks](docs/testing.md#verify-the-c-130-flight-model) · [Ground and touch controls](docs/testing.md#verify-p27-aim-and-mobile-hud)

On the depot launcher candidate, use three Studio clients to verify pickup, firing, handoff, recovery and reset. Inspect the model at each site and while equipped from desktop and phone views. [Depot launcher checks](docs/testing.md#verify-the-depot-launcher-model)

Use the three-client weapon balance procedure to test howitzer switching, launcher handover and shared damage, rifle reload feedback and equipment reset. Run the two-client gunship and aircraft-arrival regressions for impact behavior and pre-arrival fire gating. Stop Play and confirm source reached the same document before collecting fresh evidence. [Weapon balance checks](docs/testing.md#verify-p25-weapon-balance) · [Gunship checks](docs/testing.md#run-the-p05-gunship-combat-harness) · [Aircraft arrival checks](docs/testing.md#run-the-p24-aircraft-arrival-harness)

For P19, run the two-client gunship regression and the impact acceptance scenarios. The five-minute `P19Profile` workload measures both roles and the server. Its Replay scenario exercises five resets and an empty-air rocket expiry. Review rendered impacts and listen to weapons in a separate operated session. [P19 Studio procedure](docs/testing.md#run-p19-weapon-impact-checks)

For lobby art and collision regression, verify the portraits and both lobby routes, then confirm players can walk through the rooms after each reset. [Furnished lobby checks](docs/testing.md#verify-the-p22-waiting-lobby)

## Inspect the Blender assets

Open [military-outpost.blend](assets/blender/military-outpost/military-outpost.blend) in **Blender 5.3.0** to explore the exterior, furnished rooms, saved views and six material and shape damage families. Run `python3 scripts/p16_audit.py` to check the committed package without launching Blender. [Asset review guide](assets/blender/military-outpost/README.md), [in-game Outpost record](plans/17-integrate-military-outpost.md)

Open the painted C-130 in **Blender 5.3.0** to inspect the UV-mapped skin, swept wings and saved camera below the right side of the nose. The review render uses translucent propeller sweeps. [Editable painted C-130](assets/blender/c130/c130-painted.blend) · [Aircraft asset guide](assets/blender/c130/README.md)

Open the depot launcher master in **Blender 5.3.0** to inspect the grip, ground contact and muzzle marker used by both presentations. [Editable depot launcher](assets/blender/rocket-launcher/rocket-launcher.blend) · [Launcher asset guide](assets/blender/rocket-launcher/README.md)

## Follow development or contribute

- [Game design](game-design.md) and [requirements](requirements.md)
- [Development guide](docs/development.md), [architecture](architecture.md) and [testing guide](docs/testing.md)
- [Release preparation and live acceptance](docs/release.md)
- [Author Roblox assets](.agents/skills/author-roblox-assets/SKILL.md) and [import Blender assets into Roblox](.agents/skills/import-blender-to-roblox/SKILL.md)
