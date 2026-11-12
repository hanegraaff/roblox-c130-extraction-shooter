# Testing and acceptance

## Current host checks

Run `python3 scripts/setup.py` once for the pinned dependencies, then `python3 scripts/verify.py`. The verifier is the full non-Studio gate for the foundation, map, round and aircraft/view source. It fails on missing tools, type/lint/format errors, test failures, empty required suites or leaked test content. Future plans extend this entrypoint as their behaviors arrive.

| Gate | Command used by the verifier |
| --- | --- |
| Repository inputs | `python3 scripts/check_repository.py` |
| Format | `stylua --check src tests scripts/run_tests.luau` |
| Lint | `selene src tests scripts/run_tests.luau` |
| Roblox sourcemap | `rojo sourcemap test.project.json --output build/sourcemap.json` |
| Strict types | `luau-lsp analyze --platform=roblox --sourcemap=build/sourcemap.json --definitions=@roblox=.tools/globalTypes.d.luau src tests scripts/run_tests.luau` |
| Unit rules | `lune run scripts/run_tests.luau unit` |
| Lifecycle integration | `lune run scripts/run_tests.luau integration` |
| Release/test builds | `rojo build default.project.json --output build/game.rbxlx` and `rojo build test.project.json --output build/tests.rbxlx` |
| Authored geometry, corruption probes and artifact isolation | `python3 scripts/inspect_build.py` |

Direct tool commands require `$HOME/.rokit/bin` on PATH; setup and verify arrange that internally. The [development guide](development.md) lists versions and installation requirements.

The standalone runner discovers `*.spec.luau` modules and emits JSON with `suite`, `discovered`, `passed`, `failed` and `skipped`. The P14 candidate unit suites have 47 cases across nine modules: finite/payload/config/rate checks, expanded map/building layout, aircraft orbit, zoom/aim and bounded directional-pan rules, roster boundaries/seeded rotation and phase/outcome policy. The 18 integration cases exercise the real lifecycle controller, `MatchService` and server-only `AircraftSelection` with controlled time/life-cleanup/eligibility boundaries. Server-only role/round modules load from `src/server`, without replicating authoritative code to make it testable. The suites load production modules, not copies of their rules.

The verifier also copies source into disposable fixtures to inject a deliberately failing case and an empty unit suite. Both must exit nonzero with the intended diagnostic. A temporary strict-type fixture assigns strings to `Part.Anchored` and a number variable; analysis must reject it using real Roblox definitions. These are expected rejection probes, not shipped failing tests. The temporary fixtures are removed after the probes.

Artifact inspection parses the generated XML, checks the runtime-script allowlist and verifies the absence of test runners, TestEZ, fixtures and development overrides from the release DataModel. It also compares all authored `.model.json` Part/SpawnLocation entries with both generated builds: twelve finite canonical `CFrame` components, positive matching dimensions, shape, and Anchored/CanCollide/CanQuery/CanTouch flags. The current assets contribute 351 checked parts per build, plus the manifest terrain contract, three footprints, stair/room layout and 111 panel pivots. `Position`/`Orientation` aliases in source or serialized output reject. Five disposable corruptions must fail the production geometry checker: a pose alias, wrong pose, wrong size, NaN pose component and missing CFrame. These expected rejections are artifact probes, separate from Luau suite counts. A separate building-surface guard checks 7,146 visible-part pairs for exposed coplanar faces, allowing ordinary edge/contact joins and intersections hidden inside opaque supports. Three corruption probes reject a floor on the battlefield plane, an overlapping floor/frame face and a duplicate wall panel; these are also artifact probes, not extra Luau cases.

Update the allowlist deliberately when adding runtime modules and keep canonical authoring rules in the [asset guide](../assets/README.md). Build success, byte-identical reconstruction and serialized-property checks do not establish actual engine-loaded geometry, navigation or raycasts. The Studio map suite separately asserts the loaded disk, spawn and roof transforms before testing world behavior.

## Run the Studio smoke suites

1. Build with the full verifier. Open `build/tests.rbxlx` as a separate local Studio document, or sync `test.project.json` into a separate test place. Preserve any unrelated open place and unsaved work.
2. Through Studio MCP, list connected instances, select the intended test document and inspect its state. Consult the connected server’s relevant skill guidance. Confirm that `ServerScriptService.ServerTests`, `StarterPlayer.StarterPlayerScripts.ClientTests`, `ReplicatedStorage.TestPackages` and `ServerStorage.DevelopmentSettings` belong to the test mapping.
3. Start **Play** with one actual client for the foundational TestEZ suites. The mapped server and client runners execute automatically. The server requires a player within ten seconds. Startup waits are bounded; a missing report or timeout is a failure requiring investigation. The client first waits up to 60 seconds for a successful server fixture report, then up to 35 seconds for RoundState and role rendezvous, then up to 25 seconds for an actual ready avatar or explicit characterless late-spectator state. These are separate test-only stages; timeout diagnostics retain phase, role, life, load lease and character/root presence. The round runtime starts only after the server suites pass, avoiding map rebuild/character races. Ordinary solo Play then enters labelled map preview; real test rounds still require at least two actual players and an explicit start.
4. Read both structured JSON reports and the Studio Output log. In the **server** context:

   ```luau
   return workspace:GetAttribute("ServerTestReport")
   ```

   In the **client** context:

   ```luau
   return game:GetService("Players").LocalPlayer.PlayerScripts.ClientTests:GetAttribute("ClientTestReport")
   ```

5. The directional P14 candidate expects 83 server cases and three client cases; consult the [P14 record](../plans/14-aircraft-panning.md) for actual execution evidence and open checks. Earlier P13 reports retain their historical 67-case baseline; earlier P14 reports retain their recorded 79-server/two- or three-client-case counts; they do not prove the current 82-server/three-client-case baseline. For each run, collect fresh reports. Each must have `discovered > 0`, `passed == discovered`, and zero `failed`, `skipped` and `errors`. Reports include `suite`, `environment = "Studio"` and fixture `seed = 1`; the server adds actual `clientCount`, and the client adds its `userId`. Aggregate labels remain `P01-server` and `P01-client`; server discovery includes Foundation, Map, Aircraft and ExpandedMap specs plus the shared unit/service cases. A report's client count and context must match the claim being made.
6. Stop Play and start it again. Collect fresh reports and verify one `ReplicatedStorage.BootstrapStatus`, one local `PlayerGui.FoundationStatus` and one round HUD after round startup, with no leftover `EntrypointStatus` or `EntrypointPanel`. The baseline suites also exercise two explicit stop/start cycles of the bootstrap owner and status controller.
7. In the separate development document, Play and confirm **Development** / **Bootstrap running**, a protected lobby character and a round panel waiting for six players. The test build reads **Test** and waits for two after its suites. Review actual viewport readability and Output, then stop when finished.

The P14 server runner loads all 47 unit and 18 integration cases through actual Instance requires, plus two foundation, five map, four aircraft and seven expanded-map engine cases (83 expected total). The additional aircraft cases exercise authored height bounds and selected-muzzle obstruction. These counts describe the current baseline contract; preserve actual source-specific execution facts in the plan rather than carrying forward an older report as a new pass. Foundation checks cover bootstrap ownership and the anchored spawn raycast. [`Map.spec.luau`](../tests/studio/specs-server/Map.spec.luau) exercises actual `MapService` with disposable Instance fixtures:

- Assert actual loaded disk/spawn/roof transforms, then reject invalid disk dimensions, anchor identity/count and exterior/below-ground/floating/blocked anchors before restoring validity.
- Sample both launcher approaches every 0.5 stud with a 4×6×4-stud upright envelope and downward floor rays. This recorded envelope is a clearance fixture, not an avatar compatibility claim.
- Raycast permanent/breakable cover, all nine sheltered anchors and firing positions toward 64 perimeter aircraft samples.
- Correct exterior/below-threshold characters, preserve legal disk/station positions, and disconnect containment on stop.
- Rebuild twice after removed cover and transient debris; compare descendant counts, stable part names and poses, then exercise idempotent destruction.

The client TestEZ suite has two Foundation cases for replicated bootstrap status, initial character availability and status GUI/controller cleanup, plus one P14 PointerGui case. `PointerGui.spec.luau` calls the production default-input adapter against actual normal/full-bleed GUI buttons and an actual focused TextBox, verifies window-focus blocking and unchanged raw pointer coordinates, then releases focus and destroys its fixtures. `ClientTests.PointerGuiInset` records the observed inset. The current ordinary smoke reports all three passing; earlier two-case reports remain historical, and a new multiplayer session still needs its own reports. It does not prove round replication, no-respawn behavior or spectator cameras; the separate multiplayer harness below targets those. Prior P02 map/walking evidence is recorded in its plan. A new geometry candidate still needs engine checks; host success cannot satisfy them. The 4×6×4-stud clearance fixture and the operated R15 avatar are separate evidence, not proof for all avatar proportions or accessories.

For the focused review, walk from the southern shelter along the teal west route and ochre east route to the gold center marker, inspect the orange boundary, and review exposed sight lines toward sampled perimeter positions. Record whether routes are understandable, cover is readable and movement feels usable, with viewport/graphics settings and actual observations. Watch the perimeter aircraft from the ground and inspect the inward thermal view in solo Operator preview or a real two-client round. Launcher pickup and live combat remain unavailable.

Do not manually invoke another TestEZ run while the automatic runners are active. Rebuild or sync after source changes and run a fresh Play session to avoid require-cache and stale-document ambiguity. Keep engine reports tied to the tested source tree and build hash; required engine gaps remain open even if the host gate passes.

## Run the P03 multiplayer harness

Use the same confirmed local test document in Edit, with `test.project.json` fully synced and Play stopped. The normal MCP Play tool starts one client. For the P03 scenario, use `StudioTestService.ExecuteMultiplayerTestAsync` from MCP's Edit/plugin context to start **three actual clients** with arguments `{ kind = "P03" }`. It yields until the server calls `EndTest`, so launch it in a task and preserve its return value in the Edit DataModel:

```luau
task.spawn(function()
    local report = game:GetService("StudioTestService")
        :ExecuteMultiplayerTestAsync(3, { kind = "P03" })
    workspace:SetAttribute("P03LastReport", game:GetService("HttpService"):JSONEncode(report))
end)
return "P03 multiplayer test started"
```

Inspect Studio state and Output while it runs. After it ends, read `workspace:GetAttribute("P03LastReport")` in Edit. Missing evidence, timeout, failure or a client that never acknowledges is incomplete acceptance. The return report identifies `P03-multiplayer`, initial/peak client counts, completed round IDs and nine named case outcomes. Check that every case passes, no case is skipped and all three round IDs are nonzero/distinct. Capture the separate baseline server/client TestEZ reports as well.

The test-only server [RoundHarness](../tests/studio/server/RoundHarness.luau) starts the actual `GameRuntime` with a two-player minimum, 30-second rounds, eight-second lobby and two-second results. Three initial clients provide an operator and two ground players, allowing one eliminated player to follow a living teammate. `AddPlayers(1)` adds a fourth actual client during Active to test late-join spectating. The client [RoundHarness](../tests/studio/client/RoundHarness.luau) reports its actual attributes, round HUD and CameraSubject, sends production surrender requests and uses `LeaveTest` for real disconnects. Its separate transport is excluded from release artifacts.

The named scenarios target replicated roles/phase/deadline/UI; characterless late-join spectating; death without respawn and teammate camera; wrong-role/stale/eliminated command rejection; protected operator reset; elimination, timeout and operator-forfeit outcomes; ground departure while a teammate remains; three map/camera/roster resets; stable connections and draining-load teardown. Each round perturbs cover and adds transient map content before checking pristine restoration. Deterministic service tests separately cover deployment departures, reconnect tombstones, exact deadlines and result conflicts. The [P03 record](../plans/03-rounds-and-roles.md) distinguishes which engine scenarios actually ran and any open gaps.

For focused player review, use an ordinary three-client **Server & Clients** session without harness args. After the foundational suites, this starts a two-player-minimum loop with 60-second rounds, explicit start and three-second results. Observe both role views, countdown, surrender/reset, teammate camera, result and fresh lobby. The operator avatar remains at a protected station while its camera uses the inward thermal view. Check keys 1/2 and named buttons for coherent 30°/40° profiles, then confirm role loss restores the normal camera. Firing, damage and launcher gameplay remain unavailable. Record readability and camera observations separately from automated pass counts. End the test session when finished.

## Run the P04 aircraft harness

Use the same confirmed local test document in Edit, with `test.project.json` fully synced and Play stopped. Start **two actual clients** through `StudioTestService` from MCP's Edit/plugin context. Preserve the yielded result without blocking the MCP call:

```luau
task.spawn(function()
    local report = game:GetService("StudioTestService")
        :ExecuteMultiplayerTestAsync(2, { kind = "P04" })
    workspace:SetAttribute("P04LastReport", game:GetService("HttpService"):JSONEncode(report))
end)
return "P04 aircraft test started"
```

The [server AircraftHarness](../tests/studio/server/AircraftHarness.luau) starts actual `GameRuntime` and the [client harness](../tests/studio/client/AircraftHarness.luau) observes each real client through excluded test transport. Allow approximately two minutes: it samples a complete production-speed **90-second orbit** at nine points on both clients and runs two rounds. The six named scenarios cover initial canonical pose/both profiles; rejected selection coherence and valid traffic afterward; exposed/covered thermal fixtures; both-client pose convergence/inward view/tangent model; reset/reentry/singleton HUD/effect/input restoration; and actual operator disconnect with complete server teardown.

After the self-ending session returns to Edit, inspect `workspace:GetAttribute("P04LastReport")`. Require the inner `P04-multiplayer` report to have `clientCount = 2`, `discovered = passed = 6`, zero failed/skipped cases, and passing baseline reports of 83 server and 3 per actual client on the directional P14 source. A failure can append a failed harness-completion case; never treat an early exit or missing client acknowledgement as six passing scenarios. Keep actual baseline client counts distinct from the harness's two-client count: the baseline server may finish while clients are still joining.

The pose convergence bound is **8 studs** (approximately 0.32 seconds of motion at 25.13 studs/second on the expanded orbit), measured against the server pose sent to each client. Engine canonical tests use **0.01 studs** and heading dot tolerance `1e-5` for CFrame precision; the live server comparison permits **2 studs** between Heartbeat updates. Record observed errors separately from these permitted bounds. There is no smoothing shell or second gameplay pose.

`Aircraft.spec.luau` additionally samples 17 canonical phases using injected engine time, verifies Hitbox/attachment/collision/query contracts and reset, and tests actual clear/solid-obstructed/exterior/nonfinite aim endpoints. P14 adds authored-envelope rejection and selected-muzzle obstruction cases, making four aircraft cases in the expected 82-case baseline. Thermal automation combines real obstruction rays with occluded Highlight configuration. It must be supplemented by actual rendered review of exposed and fully covered targets, both FOVs, reticle stability, full-orbit ground visibility and role-loss cleanup. A screenshot or Highlight property alone cannot establish correct visual occlusion.

Use the [P04 record](../plans/04-aircraft-and-thermal.md) for original aircraft acceptance and the [P13 record](../plans/13-terrain-and-buildings.md) for the expanded-map regression source, reports and scope. Ordinary Play supports solo Operator preview for inspection, but that cosmetic preview is not two-client replication evidence. Keep unrelated sessions untouched and return the session you launched to Edit.

## Run the P14 panned-targeting harness

The orbit-relative correction is on `fix/p14-camera-view-bounds-orbit`, based on the directional [draft PR #19](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/19). Its host gate passes 47 unit / 18 integration cases; current-source Studio results remain pending in [correction evidence](evidence/p14-orbit-relative-view.md). The earlier directional candidate passed 83 server / 3 client ordinary Studio smoke, with native desktop key/mouse and simulated-phone pad/recenter checks in [prior evidence](evidence/p14-directional-revision.md); those results do not establish the new framing. Use the same confirmed test document in Edit with the entire candidate synced, including Battlefield/AimEnvelope NumberValues. Match mapped source signatures and loaded geometry/configuration before starting. The expected ordinary server/client baselines are 83 / 3; retain actual counts and client identities.

From MCP Edit/plugin context, start two actual clients and preserve the self-ending result without blocking the MCP call:

```luau
task.spawn(function()
    local report = game:GetService("StudioTestService")
        :ExecuteMultiplayerTestAsync(2, { kind = "P14" })
    workspace:SetAttribute("P14LastReport", game:GetService("HttpService"):JSONEncode(report))
end)
return "P14 panned-targeting test started"
```

Read `workspace:GetAttribute("P14LastReport")` after the original document returns to Edit. Require inner suite `P14-multiplayer`, two actual initial clients, six discovered/passing scenarios, zero failures/skips and passing actual baseline reports. An early error or harness-completion case cannot replace the complete six scenarios. The cases cover:

- Real camera-ray projection to center, four quadrants, useful near-boundary surfaces, nonflat terrain slopes and StoryId `02` panels in Foundry, Warehouse and Outpost: 14 targets at each acknowledged FOV, with at least one full production orbit per FOV.
- A finite inward camera basis over 325 native CFrames (65 orbit phases × five orbit-local held views), actual viewport corner-ground containment at every projection probe, plus rendered orbit statistics covering 16 phase bins at each FOV.
- World-space pan preservation through acknowledged/rejected selections, no operator-driven change to the Ground camera, and no change to the canonical aircraft pose.
- Blocked/outside input, recenter, slope/upper-floor occluded Highlight configuration, result/reset/new-operator entry, actual operator departure and drained idempotent runtime/transport teardown.

Declared tolerances are at most 1 pixel / 0.5 studs for same-frame reticle/raycast agreement, plus at most 1 pixel between the actual drawn reticle center (AbsolutePosition + half size + current GuiInset) and its raw ray pixels; 3 studs for automated directional-input steering into the requested target neighborhood; horizontal inward dot at least −1e-6; and at most 2 studs for live canonical camera origin between updates. Target identity remains mandatory: terrain probes require a real nonflat Terrain hit, and building probes require the requested building’s second-story panel. These are distinct from the unchanged 0.01-stud canonical engine pose and 8-stud two-client pose-convergence bounds. Preserve observed maxima separately.

The fixture stops the ordinary client entrypoint through owned cleanup, then constructs the same production RoundPanel with a nonyielding injected directional-pan/aim-pointer/recenter/profile-intent provider. It never assigns focus or adds production test flags/remotes. This proves engine behavior through controlled input, not native input wiring. Run a fresh ordinary human/preview session using the normal UserInputService constructor path for actual WASD, mouse aiming without pan, keys 1/2/R and buttons. Use a mobile emulator or device for held and simultaneous touch-pad directions, a second aiming touch, recenter/profile taps, safe-area layout and lifecycle cleanup. Check active operator and repeated solo Operator/Ground preview entry, text/UI hover, viewport exit/window focus loss, restored mouse/camera state and singleton ownership. Hold each pan bound through orbit motion and confirm the local angle remains stable while the actual corner rays stay on the level.

### Manual Studio Server & Clients route

A test-only invocation route is available when SDK child launch fails. It runs the same six-case P14 harness with the same assertions; it does not guarantee clients will connect. The latest current-source attempt launched two native client processes but only one joined, so that attempt is not complete multiplayer evidence. Preserve source-specific launch reports and stop that owned session before trying another method.

1. In the confirmed test document’s **Edit** DataModel, with Play stopped, verify the entire candidate and `ServerStorage.DevelopmentSettings` are synced. Its `ManualHarness` attribute must start absent. Set the temporary trusted server-only selector:

   ```luau
   game:GetService("ServerStorage").DevelopmentSettings:SetAttribute("ManualHarness", "P14")
   ```

2. Start Studio’s native **Server & Clients** mode with **2 clients**. The dispatcher requires Studio, nil SDK test arguments and that exact selector before ordinary HumanTestSession startup. No client remote can set the marker; it is absent from Git defaults and the release mapping. `StudioTestService:AddPlayers` is an SDK-owned-session capability and is not a supported way to populate this manual context.
3. In the actual **Server** DataModel, confirm two actual Players and collect `workspace:GetAttribute("ServerTestReport")`, `workspace:GetAttribute("ManualP14Invocation")` and, when present, `workspace:GetAttribute("ManualP14Report")`. The last value is JSON with `invocation` and the same six-case `result`; it is not the Edit DataModel’s SDK `P14LastReport`. Require current 82/3 baselines and all six cases, zero failures/skips. A missing second player, timeout, early failure or first-case diagnostic remains failed/incomplete evidence.
4. Save the report before cleanup. The manual finish callback writes it to the actual Server workspace rather than self-ending through the SDK return path. End the owned manual session from that actual Server context with `game:GetService("StudioTestService"):EndTest({ reason = "P14 manual cleanup after report collection" })` after preserving evidence, then confirm the original document is back in Edit. Generic MCP Stop was a no-op for this manual context; do not treat its return as proof of teardown.
5. In the restored Edit document, remove the temporary selector with `game:GetService("ServerStorage").DevelopmentSettings:SetAttribute("ManualHarness", nil)`. Verify it is nil even after failure, and do not commit it or carry it into ordinary preview/testing. No human End Session action is required once actual-server EndTest has closed the owned children and Edit is confirmed.

The default SDK route above still uses its normal self-ending EndTest/return behavior. Manual and SDK invocation metadata must remain distinct; neither a delivery callback nor a marker changes client-count or acceptance requirements.

Separately operate both zooms over a full orbit and inspect exposed/covered thermal targets on slopes and upper floors. Verify layout at actual 1280×720 and 1920×1080 viewports, recording simulator/graphics settings and restoring prior state. Record directional responsiveness, off-axis movement, motion comfort, zoom-preserved orbit-local angle and recenter. At the upper/lower/side pan limits, inspect the whole frame for sky, outside ground and near-vertical motion. Capture a representative actual panned gameplay image for the root README. Earlier native preview observations and the representative gameplay capture remain source-specific. Full native orbits at both FOVs, 1920×1080 review and lifecycle/thermal acceptance remain pending. Current-source P04 and HumanTestMultiplayer regression reports also remain required. Numerical fixture or property checks alone do not establish the rendered/operated review.

## Run the P13 expanded-map harness

Use the confirmed local test document in Edit with the candidate `test.project.json` fully synced. Check actual source identity and loaded transforms rather than relying on a historical document filename. Start two actual clients and preserve the returned report:

```luau
task.spawn(function()
    local report = game:GetService("StudioTestService")
        :ExecuteMultiplayerTestAsync(2, { kind = "P13" })
    workspace:SetAttribute("P13LastReport", game:GetService("HttpService"):JSONEncode(report))
end)
return "P13 expanded-map test started"
```

The test-only server/client `ExpandedMapHarness` expects five scenarios: initial two-client map/terrain/panel/aircraft agreement; a real ground Humanoid walking from outside entry through every building's stairs into its upper room; two perturbed round resets; an actual third late client observing the rebuilt map as a characterless spectator; and idempotent teardown of owned round/aircraft/transport resources. It places the avatar at each building's outside starting marker, then uses normal Humanoid movement between that entry and the upper floor; it does not teleport between route waypoints.

Read `workspace:GetAttribute("P13LastReport")` after the session self-ends in Edit. Require five discovered/passing scenarios, zero failures/skips, two initial actual clients, peak three actual clients and all three named buildings in the walked list. Collect the separate baseline reports (83 server, 3 per actual client on the directional P14 source); their actual startup client counts can differ from the harness count. A first-case failure or harness-completion error is incomplete acceptance. The teardown/resource assertion runs independently after earlier scenario failure, including a failed third-client launch; its own result is retained without erasing that earlier failure.

Static map replication compares exact part identities, classes, shapes, collision/query/touch flags and counts, with a 0.001 tolerance for numeric CFrame components and sizes. Numeric comparison avoids treating signed zero as world divergence. Each client also checks stable panel IDs/Intact state, eight actual terrain apex material/elevation queries and canonical aircraft presence on the expanded perimeter. The full-time P04 harness remains a separate camera/selection/orbit regression.

The baseline `ExpandedMap.spec.luau` adds `BuildingLayout`, `TerrainReconstruction`, `ExpandedMapNavigation`, `ExpandedMapSightLines` and cleanup checks. These inspect loaded floor/stair/room/panel geometry, reject malformed markers and lobby overlap, compare sampled voxel materials/occupancies through two mutations/rebuilds while preserving unrelated terrain, test invalid recipes without writes, and sample 64 protected/exposed orbit angles. Terrain queries may take up to five seconds after writes to converge; nominal apex Y=16 permits three studs of four-stud voxel surface tolerance. Future 750-stud full-disk range feasibility is a construction budget, not a firing feature.

For A3 serialized-world interpretation, use the [fresh native world-load probe](#check-a-fresh-native-world-load) in the existing Edit session. It loads a newly built binary world rather than cloning the live map. A full fresh-place boot, if separately required, remains a distinct **File → Open from File** check with its own runtime/server/client reports. Live sync and byte-identical builds alone establish neither native world interpretation nor fresh-place startup.

For focused review, operate the actual avatar along both launcher routes, onto terrain and into all upper floors; inspect building scale, room/stair clearance, ground/aircraft cover readability and travel time. Record viewport/graphics settings and capture the actual candidate. Fixture clearance, Humanoid automation and subjective operated review are distinct evidence. These map suites do not establish panning, firing or physical panel damage. The separate P14 procedure exercises the new bounded view/projection contract.

## Check a fresh native world load

The acceptance startup fixes, helper and passing engine evidence are integrated on `main` through merged [PR #16](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/16). After updating `main` and completing pinned dependency setup, run from the checkout:

```sh
python3 scripts/build_studio_world_probe.py
```

It uses pinned Rojo to build the versioned battlefield into a native `.rbxm` and writes these ignored artifacts:

| File | Purpose |
| --- | --- |
| `build/studio-world-probe.project.json` | Temporary world-only Rojo mapping. |
| `build/studio-world-probe.rbxm` | Fresh serialized world, independent of the live map. |
| `build/studio-world-probe.expected.json` | Every authored node identity/class and part pose/size/shape/flag contract. |
| `build/studio-world-probe.luau` | Complete MCP probe, embedding the binary bytes and source expectations. |
| `build/studio-world-probe.json` | Source commit, world-source/binary/probe SHA-256 values, sizes and expected counts. |

Select the intended existing test Studio instance, confirm **Edit** mode and that its production MapService modules match the candidate, then call Studio MCP `execute_luau` with that confirmed `studio_id`, `datamodel_type = "Edit"` and `code` equal to the generated `.luau` file contents. Preserve its returned structured JSON alongside the metadata. The script uses `SerializationService:DeserializeInstancesAsync` to interpret the fresh binary natively, parents a temporary `P13AcceptanceFreshWorld` fixture and exercises the real MapService. It does not launch Studio or publish an asset.

Require `passed = true`, five passing named cases, `fixtureRemoved = true` and an empty `cleanupErrors` array. The P14 world contract is 334 authored world parts and 360 nodes (the additional AimEnvelope Folder and NumberValues), checked for exact identities/classes/flags and numeric poses/sizes within 0.001. Initial terrain and two perturbed rebuilds must each reproduce eight hills and the fixed 1152-voxel sample (9513 encoded bytes, Adler-32 2054186319), with matching apex materials/elevations. Each rebuild removes a deleted-panel/transient mutation, restores source geometry and preserves an unrelated terrain fixture exactly. Teardown is idempotent; cleanup restores the saved terrain volume, unrelated fixture voxels and removes all probe models.

The [historical P13 native-load report](evidence/p13-acceptance/fresh-world-report.json) identifies its actual source hashes, engine version and 357-node results; do not relabel it as the P14 360-node artifact. That report proves fresh source-built **world** interpretation and P13 A3 terrain reconstruction in the existing process. It does not prove a fresh **place boot**, player startup, the current server/client runtime baseline, multiplayer replication or full-orbit camera behavior; collect those through their separate procedures.

## Required test levels

| Level | Purpose | Execution / evidence |
| --- | --- | --- |
| Static | Format, lint, strict Luau types, module boundaries | Pinned tools in local/CI gate; Roblox-aware definitions for engine code |
| Unit | Rules: transitions, timers, damage, ammo, circular orbit math, weapon-linked zoom, single-launcher ownership | Standalone Luau under Lune; deterministic clock/random inputs |
| Service integration | Real services connected through fakes for transport, clock and world queries | Lune where engine-independent; TestEZ in Studio for Instance-dependent adapters |
| Engine integration | Raycast/cover, Humanoid death, collision swaps, Instances, camera state | TestEZ in the test place, with assertions and a structured pass/fail summary |
| Multiplayer | Replication, roles, input rejection, late joins, visibility, cleanup | Two distinct client contexts for gameplay claims; P01 only requires its one-client smoke; actual 6/10 capacity sessions arrive later |
| Experience | Readability, camera feel, sound, balance, fairness | Focused operated playtest and captured observations; supplements automated evidence |

Unit tests use observable invariants and boundary examples, not implementation-specific call order unless order is the contract. Integration tests use real services and fake boundaries, not fake services calling each other. Engine checks assert real world state. A client screenshot cannot establish server authority.

## Determinism and fixtures

- Inject the clock and seed; use a tiny map fixture with one exposed target, one solid wall, one breakable wall, a clear projectile path, circular map bounds and one launcher anchor.
- Include minimum/maximum population, a two-client development fixture, and seeded 10-player roster data. Ten fake player records do not count as ten network clients.
- Include source/target inside and outside every boundary, exact deadlines, duplicate messages, two launcher claims in one step, carrier death during reload, simultaneous aircraft/last-player destruction, disconnect/reconnect, and a stale projectile after reset.
- Every suite states which requirement it proves, which values are fixtures, and why tolerances exist. Keep random balance tests reproducible by printing their seed.
- Avoid real-time sleeps in rule tests. Engine tests may wait for bounded replication/physics conditions with explicit timeout and useful diagnostics.

## Core gameplay invariants

- With an undamaged plane and no rifle fire, direct rocket hits one and two leave it alive; hit three commits destruction and one ground win. A duplicated impact never counts twice. Misses/near misses do not count as direct hits.
- M-7 damage is positive and accumulates on that same health pool. Cover blocks shots, health never goes negative, and mixed rifle/rocket damage can require fewer remaining rockets.
- Exactly one launcher is available or held per round. Simultaneous claims, death/disconnect/drop, invalid-position recovery and reset cannot duplicate it or refresh reload early.
- The orbit follows the map perimeter at all sampled phases while model heading follows the tangent. The P14 camera holds a bounded WASD/touch-panned angle relative to that aircraft; the earlier integrated baseline tracks map center. Both aircraft weapon FOVs keep targeting coherent, distinct and inward-facing, including elevated surfaces and whole-frame level containment.
- Rapid 30mm/105mm switching cannot reset weapon timers, refill ammunition or bypass reload. Rejected/stale selection restores the correct weapon/FOV/reticle combination.
- Deadline first, then aircraft destruction before ground elimination within the same pre-deadline step: test boundary/mutual-kill cases and late in-flight rockets explicitly.

## Negative network tests

For each mutating action, exercise malformed payloads, NaN/infinity, oversized data, unknown weapon/launcher IDs, unowned equipment, wrong role, spectator/eliminated state, excessive rate, stale round ID, repeated sequence, impossible range/origin and blocked line of sight. Assert rejection **and unchanged ammo/health/launcher-ownership/result state**. Valid traffic must still succeed after a rejected request.

Character movement is client-simulated in normal Roblox play. Include implausible travel/teleport requests around launcher pickup and ground firing origins; an authoritative proximity check alone does not prove a movement exploit is prevented.

## Studio execution and evidence

The explicit server/client runners are mapped only by `test.project.json` and excluded from `default.project.json`. Use the Roblox Studio MCP connection as the primary way to inspect and operate the test place and supported playtests; identify the intended Studio instance and discover its actual capabilities first. If the required operation is unavailable, use documented Studio steps and a human-assisted run where possible. Do not claim that Lune or a generated place simulated a real server; an unavailable required engine check remains open.

Record for each required run:

1. Plan and tested source commit/tree, Studio version, test-place build, seed, map fixture and client count.
2. Suite names with discovered/passed/failed/skipped counts and useful output/log location.
3. Which assertions ran on the server versus each client; replication deadlines where relevant.
4. Reproduction steps and evidence for experience observations, including viewport and graphics settings.
5. Failures, limitations and whether the tested source changed afterward.

Keep concise text evidence under `docs/evidence/`; keep large logs/captures as linked CI artifacts or bounded repository assets. Never fabricate screenshots, live client counts or an experience URL. If a required engine check cannot run, finish independent work but leave the plan In progress or Blocked with the concrete missing access/evidence.

## Objective release budgets

These are initial engineering targets; P11 records a named reference desktop before measuring. Changing a budget needs a reason in the plan, not a quieter test.

- Test at 1920×1080 with a recorded graphics quality. Target client frame time p95 ≤33.3 ms for both roles during a scripted five-minute combat workload.
- Target server frame time p95 ≤16.7 ms for the same workload. Record the sampling method, active clients, projectile/cover/effect counts and Studio/cloud environment.
- Complete five consecutive accelerated deterministic rounds with no stale damage, launcher ownership, results, listeners or map state. Server-owned temporary instance/connection counts must return to the baseline after each reset.
- Run a 30-minute multiplayer soak. After warmup and equivalent reset points, retained memory growth must be ≤10%, with no monotonic leak; record actual samples and separate engine caches from owned allocations.
- Exercise a controlled latency scenario near 150 ms round-trip, recording actual simulator settings/measurements, and confirm state converges without duplicated damage/rewards.
- Run actual 6-player and 10-player sessions before release. Studio supports up to eight locally simulated clients per current documentation; use an authorized Roblox test experience for the ten-player case. Recheck the platform limit if tooling changes.

Budgets do not promise performance on unspecified hardware. If a target is missed, optimize or record a scoped design decision; do not mark the gate passed.

## Completion evidence template

Each plan already includes a record to fill. List criterion ID → test name/file → command/environment → observed outcome. Include final source commit, CI URL, Studio report, tester findings, documentation review and remaining limitations. Required checks left unrun remain incomplete acceptance criteria.

The [Roblox testing documentation](https://create.roblox.com/docs/studio/testing-modes) is the source for actual Studio modes and simulated-client capabilities.

## Solo exploration and lobby movement regression

An ordinary one-client Play in `PlayersVsC130Tests` automatically enters a labelled solo map preview after the expected 83 server / 3 client baseline cases on the directional P14 source. WASD works in both the preview and the protected lobby. The preview keeps the player Waiting and the phase Lobby; it does not fabricate an operator, active life or match result. With two or more clients, use the human panel to choose roles and explicitly start the real round loop. See the [root guide](../README.md#run-local-automated-tests) for human test panel controls.

The explicit `ExecutePlayModeAsync({kind = "LobbyControls"})` scenario runs four TestEZ engine cases through `LocalTestControlsCheck`, then ends the session with structured results. Check `discovered = passed = 4`, no errors/failures/skips, and actual `clientCount = 1`. Focused operated WASD checks supplement unanchored-root assertions. No additional Studio client windows are required. [Fix evidence](evidence/lobby-preview.md) records actual execution.

For human-control regression, run `ExecutePlayModeAsync({kind = "HumanTestControls"})` and require six discovered/passing cases, zero failures/skips/errors, one actual client. Then `ExecuteMultiplayerTestAsync(2, {kind = "HumanTestMultiplayer"})` requires four passing cases and two actual clients, covering conflicting choices, requested real roles, changing next-round settings without mutating an active round, and reset/start applying the new choices. Both sessions end themselves; verify the original document is back in Edit and close only the session you launched. Operated test-panel button checks supplement the server decoder tests.

## Expanded-map, panning and planned destruction acceptance

Historical P02/P04 evidence establishes the prior 180-stud-radius, fixed-focus prototype. [P13](../plans/13-terrain-and-buildings.md) supplies the current 360-stud-radius terrain/building source and its named suites; consult its record for actual results and validation scope. The [P14](../plans/14-aircraft-panning.md) panning source candidate awaits real-engine/operated acceptance; revised [P07](../plans/07-destruction.md) destruction remains planned. R16 extends release traceability to authored terrain and three accessible multi-story buildings.

- P13: source-built 720-stud disk/equal perimeter orbit, versioned terrain elevation/material reconstruction, building/story/panel registry, actual stairs/upper-floor navigation, supported anchors, separate lobby and two launcher routes.
- P14: signed-direction/delta-time pan rules; full-orbit relative-angle and whole-view bounds at both zooms; elevated terrain/upper-floor projection, preserved local focus under weapon selection, recenter and role cleanup with two actual clients.
- P07: exact heavy-hit 3/6 boundaries, nine valid seconds of sustained 30mm fire and interruption/mixing defaults; visible interim progression, measured half-panel opening, pre-impact cover/thermal rays, actual fragment falling/static contact/ownership and collision exclusions, late join and repeated reset during damage/fragmentation.
- P11/P12: expanded-map travel/visibility and simultaneous fragment workloads in frame/memory/latency/soak measurements; repeat the revised level/panning/destruction demonstrations in real 6- and 10-player acceptance.

Record numeric tolerances and chosen defaults before running each suite. Test doubles cannot prove terrain loading, residual collision, camera coverage, rigid-body contact or replication. Earlier engine reports must not be relabeled as evidence for this expanded scope.
