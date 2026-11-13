# Testing and acceptance

## Current host checks

Run `python3 scripts/setup.py` once for the pinned dependencies, then `python3 scripts/verify.py`. The verifier is the full non-Studio gate for the foundation, map, round, aircraft/view, gunship/ground combat, panel-destruction and P08 launcher source. It fails on missing tools, type/lint/format errors, test failures, empty required suites or leaked test content. Future plans extend this entrypoint as their behaviors arrive.

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

The standalone runner discovers `*.spec.luau` modules and emits JSON with `suite`, `discovered`, `passed`, `failed` and `skipped`. The P08 mapping has **55 unit and 65 integration cases**. Corrected source `75b1e88` passes the independent full gate with those counts and all static/build/probe/isolation checks; exact source and historical first-candidate results are recorded in the [P08 evidence](evidence/p08-launcher.md). The earlier P07 55/55 result remains historical. Coverage includes validation/config/rate, map/building layout, orbit/pan/zoom, roles/outcomes, weapon readiness, shared aircraft health, movement-origin checks, ordered panel destruction and single-launcher identity/reload/recovery. These suites load production modules with deterministic boundaries. They do not establish real collision, rigid-body contact, actual traversal or multiplayer replication. Server-only policy stays under `src/server`.

The verifier also copies source into disposable fixtures to inject a deliberately failing case and an empty unit suite. Both must exit nonzero with the intended diagnostic. A temporary strict-type fixture assigns strings to `Part.Anchored` and a number variable; analysis must reject it using real Roblox definitions. These are expected rejection probes, not shipped failing tests. The temporary fixtures are removed after the probes.

Artifact inspection parses the generated XML, checks the runtime-script allowlist and verifies the absence of test runners, TestEZ, fixtures and development overrides from the release DataModel. It also compares all authored `.model.json` Part/SpawnLocation entries with both generated builds: twelve finite canonical `CFrame` components, positive matching dimensions, shape, and Anchored/CanCollide/CanQuery/CanTouch flags. The revised artifact contract includes the manifest terrain recipe, three formal footprints/stairs and all registered panels, including the starting shelter. The stable build checks **422 authored Parts**, including **403 Battlefield Parts** and all **187 panels**; the earlier 353-part/111-panel artifact result is historical. `Position`/`Orientation` aliases in source or serialized output reject. Five disposable corruptions must fail the production geometry checker: a pose alias, wrong pose, wrong size, NaN pose component and missing CFrame. These expected rejections are artifact probes, separate from Luau suite counts. A separate building-surface guard checks visible-part pairs in the current source for exposed coplanar faces, allowing ordinary edge/contact joins and intersections hidden inside opaque supports. Three corruption probes reject a floor on the battlefield plane, an overlapping floor/frame face and a duplicate wall panel; these are also artifact probes, not extra Luau cases.

Update the allowlist deliberately when adding runtime modules and keep canonical authoring rules in the [asset guide](../assets/README.md). Build success, byte-identical reconstruction and serialized-property checks do not establish actual engine-loaded geometry, navigation or raycasts. The Studio map suite separately asserts the loaded disk, spawn and roof transforms before testing world behavior.

## Run the Studio smoke suites

1. Build with the full verifier. Open `build/tests.rbxlx` as a separate local Studio document, or sync `test.project.json` into a separate test place. Preserve any unrelated open place and unsaved work.
2. Through Studio MCP, list connected instances, select the intended test document and inspect its state. Consult the connected server’s relevant skill guidance. Confirm that `ServerScriptService.ServerTests`, `StarterPlayer.StarterPlayerScripts.ClientTests`, `ReplicatedStorage.TestPackages` and `ServerStorage.DevelopmentSettings` belong to the test mapping.
3. Start **Play** with one actual client. The mapped server/client runners execute automatically. The server waits up to ten seconds for bootstrap status and separately up to 60 seconds for its first actual client. `ServerTestStartup` JSON records status, elapsed/budget seconds and actual client count roughly every second and on arrival/timeout. No client produces a failed zero-discovery report and an error, never a pass. The client waits up to 60 seconds for a successful server fixture report, then up to 35 seconds for RoundState/role rendezvous and 25 seconds for an actual ready avatar or explicit characterless late-spectator state. These are distinct stages with bounded diagnostic failures. The actual round runtime starts after server suites pass, preventing fixture/map rebuild races. Ordinary solo Play then enters labelled map preview; a real test round requires at least two actual players and an explicit start.
4. Read both structured JSON reports and the Studio Output log. In the **server** context:

   ```luau
   return {
       startup = workspace:GetAttribute("ServerTestStartup"),
       report = workspace:GetAttribute("ServerTestReport"),
   }
   ```

   In the **client** context:

   ```luau
   return game:GetService("Players").LocalPlayer.PlayerScripts.ClientTests:GetAttribute("ClientTestReport")
   ```

5. The corrected P08 mapping expects **156 server cases and seven cases per actual client**: 55 unit, 65 integration and 36 server engine cases, plus the separate client suite. Corrected source `75b1e88` passed a fresh ordinary one-client Play with **156 server / seven client**, zero failures/errors/skips. That solo result does not establish three-client launcher replication or operated input. The [P08 record](../plans/08-rocket-launcher.md) identifies the actual tested candidate and passing/unavailable checks. Initial candidate `88732d4` passed 155 server/six client before its character-removal and GUI-intersection corrections. Require every current report to have `discovered > 0`, `passed == discovered`, and zero `failed`, `skipped` and `errors`. Reports identify `suite`, `environment = "Studio"`, fixture `seed = 1`, and actual server `clientCount` or client `userId`. Aggregate labels remain `P01-server`/`P01-client`. Preserve exact source/build and actual contexts; historical P06/P07 counts below apply only to their recorded source.
6. Stop Play and start it again. Collect fresh reports and verify one `ReplicatedStorage.BootstrapStatus`, one local `PlayerGui.FoundationStatus` and one round HUD after round startup, with no leftover `EntrypointStatus` or `EntrypointPanel`. The baseline suites also exercise two explicit stop/start cycles of the bootstrap owner and status controller.
7. In the separate development document, Play and confirm **Development** / **Bootstrap running**, a protected lobby character and a round panel waiting for six players. The test build reads **Test** and waits for two after its suites. Review actual viewport readability and Output, then stop when finished.

The P08 aggregate includes launcher geometry/reload lifecycle and owned-character removal alongside panel/appearance, persistent-credit, shelter-geometry and shared host cases. A passing one-client baseline establishes only those assertions, not P07's required two-client/reset or operated checks. Foundation checks cover bootstrap ownership and the anchored spawn raycast. [`Map.spec.luau`](../tests/studio/specs-server/Map.spec.luau) exercises actual `MapService` with disposable Instance fixtures:

- Assert actual loaded disk/spawn/roof transforms, then reject invalid disk dimensions, anchor identity/count and exterior/below-ground/floating/blocked anchors before restoring validity.
- Sample both launcher approaches every 0.5 stud with a 4×6×4-stud upright envelope and downward floor rays. This recorded envelope is a clearance fixture, not an avatar compatibility claim.
- Raycast permanent/breakable cover, all nine sheltered anchors and firing positions toward 64 perimeter aircraft samples.
- Correct exterior/below-threshold characters, preserve legal disk/station positions, and disconnect containment on stop.
- Rebuild twice after removed cover and transient debris; compare descendant counts, stable part names and poses, then exercise idempotent destruction.

The client TestEZ suite includes Foundation, P14 PointerGui and GroundAimGui cases; the current candidate expects seven. The added P08 case checks actual HUD rectangle separation/containment across desktop and phone-sized layouts; it does not establish native touch input. `PointerGui.spec.luau` calls the production default-input adapter against actual normal/full-bleed GUI buttons and an actual focused TextBox, verifies window-focus blocking and unchanged raw pointer coordinates, then releases focus and destroys its fixtures. `ClientTests.PointerGuiInset` records the observed inset. GroundAimGui checks rifle reticle/ray agreement and touch layout. Prior reports are source-specific; each new multiplayer session needs fresh reports. It does not prove round replication, no-respawn behavior or spectator cameras; the separate multiplayer harness below targets those. Prior P02 map/walking evidence is recorded in its plan. A new geometry candidate still needs engine checks; host success cannot satisfy them. The 4×6×4-stud clearance fixture and the operated R15 avatar are separate evidence, not proof for all avatar proportions or accessories.

### Preserve Edit state around a zero-client Run

Prefer ordinary Play/Stop and the supported SDK test modes. A direct low-level `RunService:Run()` may execute against the original Edit DataModel. The P06 zero-client negative probe left **both** Workspace report attributes and `ReplicatedStorage.BootstrapStatus` in Edit after stopping. A later bootstrap can then fail with “bootstrap already owned”; clearing only reports does not repair that contamination.

Before such a negative probe, snapshot the exact existence, class, attributes and owned contents of every runtime-created Editor Instance that the run can affect, including `BootstrapStatus` and any `EntrypointStatus`, plus Workspace `ServerTestReport`/`ServerTestStartup` attributes and their nil state. After collecting the intended timeout failure, stop only that owned run, confirm `RunService:IsRunning()` is false, and compare against the snapshot. Remove only confirmed probe-created stale objects; restore pre-existing objects/values exactly, including nil, and verify equality before the next session. Preserve unfamiliar objects and diagnose them instead of deleting by name. If complete restoration cannot be established, do not treat the next launch as clean.

The [P06 startup record](evidence/p06-ground-combat.md) distinguishes its contaminated cold start, expected zero-client timeout and later controlled three-client run. The [P07 record](../plans/07-destruction.md) records its separate stale-folder diagnosis and subsequent clean baseline. These outcomes must retain their actual source and launch conditions. Normal Play/Stop is the routine workflow; this low-level probe is not needed to play or validate destruction.

For the focused review, walk from the southern shelter along the teal west route and ochre east route to the gold center marker, inspect the orange boundary, and review exposed sight lines toward sampled perimeter positions. Record whether routes are understandable, cover is readable and movement feels usable, with viewport/graphics settings and actual observations. Watch the perimeter aircraft from the ground and inspect the inward thermal view in solo Operator preview or a real two-client round. The P08 candidate provides launcher pickup during a real active round; solo preview remains noncompetitive. The P06 implementation supplies active-round M-7 ground fire; gunship combat also requires an active round.

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

For focused player review, use an ordinary three-client **Server & Clients** session without harness args. After the foundational suites, this starts a two-player-minimum loop with 60-second rounds, explicit start and three-second results. Observe both role views, countdown, surrender/reset, teammate camera, result and fresh lobby. The operator avatar remains at a protected station while its camera uses the inward thermal view. Check keys 1/2 and named buttons for coherent 30°/40° profiles, then confirm role loss restores the normal camera. Exercise active gunship and M-7 firing and cover separately; launcher gameplay is available in the P08 candidate during a real active round. Record readability and camera observations separately from automated pass counts. End the test session when finished.

## Run the P05 gunship combat harness

Use the same confirmed `tests.rbxlx` Edit document synced to `PlayersVsC130Tests`, and check the candidate source identity before starting. In Edit/plugin context, run the two-client harness without blocking Studio:

```luau
task.spawn(function()
    local report = game:GetService("StudioTestService")
        :ExecuteMultiplayerTestAsync(2, { kind = "P05" })
    workspace:SetAttribute("P05LastReport", game:GetService("HttpService"):JSONEncode(report))
end)
return "P05 gunship test started"
```

After the self-ending session returns to Edit, inspect `workspace:GetAttribute("P05LastReport")`. Confirm two actual clients connected, all eight named P05 cases ran and passed, and no case or harness completion failed or skipped. A launch timeout, missing result, early exit or zero discovered cases is not a pass. Preserve the actual report, source commit/tree, Studio environment and separate server/client baseline reports; the server baseline may complete while clients are still joining. The harness uses a test-only transport and disposable fixtures. It targets forged/stale/nonfinite/flood requests, actual swept cover, collisionless flight, weapon-switch reload, replicated combat observations, terminal/next-round cleanup and terrain/upper-floor geometry; consult the current test source and [P05 plan](../plans/05-gunship-combat.md) for exact coverage and observed results.

The embedded-cover case uses a disposable wall outside the registered building-panel ledger. Its replicated structural `panelId` must therefore be nil, even if the fixture has a copied tag. Establish the actual containing wall independently through overlap/initial-collision positive controls, bounded impact position, no remaining projectile flight and unchanged protected-player health. A nil panel ID by itself does not prove collision. Model-aware panel helpers in the P05/P14 regressions inspect the live identity Model and its current solids; fixture edits need fresh source-specific reports. The prior candidate’s [P07 P05 regression report](evidence/p07-p05-873f0f6-report.json) preserves its actual source, two-client context and eight-case result; P14 has its separate [passing two-client regression report](evidence/p07-p14-regression-report.json), and full P07 acceptance remains incomplete.

### Manual Studio Server & Clients fallback for P05 regression

The SDK route above remains the default. When it cannot launch the requested clients, the P06 test mapping supplies a separate test-only native route for the P05 regression; it does not guarantee client connection or a passing result. The selector is absent from Git defaults and release artifacts and cannot be set by a client remote.

1. In the confirmed, synced `tests.rbxlx` **Edit** document, with Play stopped, verify the selector is absent and set it to `"P05"`:

   ```luau
   local settings = game:GetService("ServerStorage"):FindFirstChild("DevelopmentSettings")
   assert(settings and settings:IsA("ModuleScript"), "test settings unavailable")
   assert(settings:GetAttribute("ManualHarness") == nil, "selector already in use")
   settings:SetAttribute("ManualHarness", "P05")
   return settings:GetAttribute("ManualHarness")
   ```

2. Start Studio's native **Server & Clients** mode with **2 clients**. Confirm both actual clients connect and collect fresh server/client smoke reports. Once at least one client has joined, a missing second client yields a structured harness-startup failure. With no clients, the outer smoke can exhaust its separate 60-second first-client budget before the harness runs and publish an explicit failed, zero-discovery server report; the separate bootstrap-status wait remains ten seconds. Neither outcome is a pass. A separate zero-client Studio `Run` verified the negative 60-second timeout on `0ab3607`; a delayed first client remains unverified; P06Team later passed 7/7 after a controlled same-session runner restart with three already-connected actual players; that does not establish a clean cold start.
3. Before ending the session, read and preserve `workspace:GetAttribute("ManualP05Invocation")` and `workspace:GetAttribute("ManualP05Report")` from the actual **Server** DataModel, together with the candidate commit/tree, mode, actual client count and smoke reports. The manual report is not the Edit document's SDK `P05LastReport`. Require two actual clients, all eight P05 cases and zero failures/skips; a missing report or early error remains incomplete.
4. After preserving the report, end the owned manual session from the actual **Server** context:

   ```luau
   game:GetService("StudioTestService"):EndTest({ reason = "P05 manual cleanup after report collection" })
   ```

   Confirm the original document returns to Edit. In that original **Edit** document, clear the temporary `ServerStorage.DevelopmentSettings.ManualHarness` attribute and verify it is nil. Do not carry it into ordinary testing or a cloud/release place. This fallback is available on the current P06 source; the actual P05 regression result must be recorded separately and is not claimed by the route's existence.

The harness does not substitute for operating native desktop and touch controls. In an ordinary real two-client round, fire each weapon while aiming and panning, switch away and back during reload, and inspect warnings, impacts, exposed/covered targets, both thermal views and mobile layout. Record actual device, view and observed behavior, then stop the owned session. Do not infer successful replication or playability from a screenshot.

## Run the P06 ground-combat harness

Use updated `main` in the confirmed `tests.rbxlx` Edit document, synced to `PlayersVsC130Tests` on port 34872. In Studio MCP Edit context, start two real clients using the same bounded asynchronous pattern as P05:

```luau
task.spawn(function()
    local report = game:GetService("StudioTestService")
        :ExecuteMultiplayerTestAsync(2, { kind = "P06" })
    workspace:SetAttribute("P06LastReport", game:GetService("HttpService"):JSONEncode(report))
end)
return "P06 started"
```

After the owned session returns to Edit, collect `P06LastReport`, actual client counts and fresh baseline reports: 118 server/six per client on integrated P06, or the current candidate counts above when running this as a candidate regression. Require discovered cases to be nonzero and all passing with zero failures, skips and errors; a launch timeout or a harness-completion error is not a pass. Run the companion three-client fixture with `ExecuteMultiplayerTestAsync(3, { kind = "P06Team" })` and store its separate result to verify teammate/friendly-fire scenarios. These fixtures exercise server-only rocket seams; they do not add a launcher to player inventory or prove native input by themselves. Follow [P06](../plans/06-ground-combat.md) for source-specific evidence and remaining gaps.

### Manual Studio Server & Clients fallback for P06

If the SDK launcher cannot establish the required clients, the test-only runner also supports a native **Server & Clients** route. It invokes the same P06 cases through a temporary server-only selector, with no client authority over the selector and no change to release mapping. The SDK route above remains the default. A manual launch does not guarantee client connection or establish a passing result.

1. In the confirmed test document's **Edit** DataModel, with Play stopped and the candidate fully synced, verify `ServerStorage.DevelopmentSettings` is the test ModuleScript and its `ManualHarness` attribute is nil. Set it to `"P06"` for the two-client suite, or `"P06Team"` for the three-client suite. For example, through Studio MCP in Edit:

   ```luau
   local settings = game:GetService("ServerStorage"):FindFirstChild("DevelopmentSettings")
   assert(settings and settings:IsA("ModuleScript"), "test settings unavailable")
   assert(settings:GetAttribute("ManualHarness") == nil, "selector already in use")
   settings:SetAttribute("ManualHarness", "P06") -- use P06Team for the separate three-client run
   return settings:GetAttribute("ManualHarness")
   ```

2. In Studio's Play dropdown, choose **Server & Clients**, select **2 clients** for `P06` or **3 clients** for `P06Team`, and start Play. Wait for the actual server and requested number of real simulated clients; collect their fresh server/client smoke reports. Once at least one client has joined, a missing required client is reported as a structured harness startup failure. With zero clients, the outer server smoke can exhaust its separate 60-second first-client budget and publish an explicit failed, zero-discovery server report before the harness starts; the separate bootstrap-status wait remains ten seconds. Either outcome is incomplete acceptance. A separate zero-client Studio `Run` verified the negative 60-second timeout on `0ab3607`; a delayed first client remains unverified; P06Team later passed 7/7 after a controlled same-session runner restart with three already-connected actual players; that does not establish a clean cold start.
3. Before ending the session, read the actual **Server** DataModel's workspace attributes `ManualP06Invocation` and `ManualP06Report`, or `ManualP06TeamInvocation` and `ManualP06TeamReport` for the companion run. Preserve their JSON, candidate commit/tree, actual client counts, mode, departure method and separate smoke reports. Require the requested client count, nonzero discovery, all cases passing and zero failures/skips; a missing report, failed startup, early exit or completion error is not a pass.
4. The manual two-client operator-departure case uses a **server kick** to cause actual Player removal; the SDK route uses the client's `LeaveTest`. Record that difference. The three-client team variant does **not** exercise operator departure. Do not treat it as evidence of SDK departure behavior.
5. After collecting the result, use **End Session** to stop the owned simulation. In the original **Edit** document, clear the selector and verify it is nil before starting any other session:

   ```luau
   local settings = game:GetService("ServerStorage"):FindFirstChild("DevelopmentSettings")
   assert(settings and settings:IsA("ModuleScript"), "test settings unavailable")
   settings:SetAttribute("ManualHarness", nil)
   assert(settings:GetAttribute("ManualHarness") == nil, "selector not cleared")
   return "P06 manual selector cleared"
   ```

   Repeat with the other selector and requested client count if both P06 variants are required. Never apply this test-only selector to a cloud or release place.

The [P06 plan](../plans/06-ground-combat.md) and linked source-specific evidence preserve the actual two-/three-client runs, native startup failures, controlled restarts, same-shot desktop aim checks and simulated-phone review. Use their original counts and conditions; the revised P07 source expects 142 server/six cases per client, with fresh reports for each session. Operate both sides of a real round separately: equip/aim/fire/reload the M-7, inspect aircraft health and cover, and observe the team result. Check moving-aircraft reticle/ray agreement and simulated-phone FIRE/RELOAD/layout alongside ground movement. A simulator is not a physical device; fixtures are not operated input. Changes to shared outcome or query handling also require the relevant P05/P14 regressions.

## Run the P08 launcher harness

Use the existing confirmed local `tests.rbxlx` Edit document, fully synced from `plan/08-rocket-launcher` through `test.project.json` on port 34872. Verify mapped source signatures and the current smoke counts before attributing results to the candidate. P08 needs **three actual clients**: one operator and two ground players. Solo smoke, fake roster records and an SDK request for three do not establish that population.

Start the SDK route from MCP Edit/plugin context without blocking the call:

```luau
task.spawn(function()
    local report = game:GetService("StudioTestService")
        :ExecuteMultiplayerTestAsync(3, { kind = "P08" })
    workspace:SetAttribute("P08LastReport", game:GetService("HttpService"):JSONEncode(report))
end)
return "P08 launcher test started"
```

After the session ends, preserve `P08LastReport`, source commit/tree, build, Studio version and each actual baseline report. The corrected fixture has **11 named cases**, including teardown. Require all cases discovered/passing with zero failures/skips/completion errors, three actual clients before intentional departure, and consistent identity, reload and health observations. `requestedClients`, `initialClientCount`, `peakClientCount` and `currentClientCount` distinguish requested population from connection/departure facts. A successful outer invocation with a failing inner report is a failure. The first candidate's SDK run requested three but connected two and failed startup; keep that historical result separate from any later native run.

The server/client `LauncherHarness` uses production GameRuntime and real remote intent. It covers M-7-only initial loadouts and one available launcher; invalid/wrong-role/stale/flood/implausible-movement rejection; raced acquisition; miss/drop/selection/transfer with unchanged reload; carrier death with an already-flying direct rocket; explicit character removal while reloading and teammate recovery without restored life/equipment; pristine reset and stale intent; three real rockets yielding 200, 100 and zero aircraft health; earlier real rifle damage followed by two lethal remaining rockets; actual carrier disconnect; and drained idempotent teardown. Trusted fixture poses isolate these rules and collision checks; they are not operated route traversal or native input evidence.

**A5 also requires actual same-identity reconnect.** The current harness reports `actualReconnectVerified = false` and lists it in `requiredUnverified`, because available Studio helpers add a different test identity. Eleven passing cases would not close that requirement. The deterministic MatchService tombstone case is complementary rule evidence. D50's real-late-join waiver applies only to P07; do not transfer it to P08 or relabel synthetic rejoin as real networking.

If the SDK cannot connect three clients, prepare the native fallback once, with Play stopped in the same test document:

```luau
local settings = game:GetService("ServerStorage"):FindFirstChild("DevelopmentSettings")
assert(settings and settings:IsA("ModuleScript"), "test settings unavailable")
assert(settings:GetAttribute("ManualHarness") == nil, "selector already in use")
settings:SetAttribute("ManualHarness", "P08")
return "P08 native three-client selector ready"
```

Choose Studio **Server & Clients**, set **3 clients**, and start the session. Capture actual Server workspace `ManualP08Invocation`, `ManualP08Report` and `P08MultiplayerReport`, plus each client's fresh smoke report. Native departure uses a server kick; SDK departure uses the client's LeaveTest. Preserve the mode and method. After report collection, end only the owned simulation from its actual Server context with `StudioTestService:EndTest({reason = "P08 manual cleanup after report collection"})`. Confirm the original document is back in Edit, then clear `ServerStorage.DevelopmentSettings.ManualHarness` and verify nil. This temporary server-only selector is absent from Git defaults and release artifacts. Do not restart the runner on top of an existing runtime or launch extra Studio processes to refresh source.

Separately operate both painted approaches, E/PICK UP, native tool selection, M-7/rocket firing and reload, G/DROP and teammate recovery in an ordinary real round. Check ground movement and mouse aim; use a simulator/device for touch pickup, M-7/ROCKET/DROP and FIRE while aiming. Review desktop/phone status readability, real rocket travel/cover, ownership agreement and shared aircraft-health feedback without a fixed remaining-hit promise. Refresh the representative README capture from the actual candidate, disclosing any fixture pose/camera. Rerun affected P05/P06/P14 and character/lifecycle scenarios after shared authority or cleanup changes; preserve each result separately. The [P08 plan](../plans/08-rocket-launcher.md) and [evidence](evidence/p08-launcher.md) own actual results and remaining limitations.

## Run the P07 destruction harness

Use updated `main` in the confirmed local **Edit** test document, synced from `test.project.json` on port 34872. This revision has passed its P07 acceptance checks on the recorded source. Candidate `8053c8f` passes the full 55/55 host gate. Its production core is unchanged from the [142-server/six-client solo baseline on `4db4595`](evidence/p07-revision-solo-4db-pass.json); retain that baseline separately from the [passing seven-case two-client/reset run](evidence/p07-revision-native-8053-pass.json) on `8053c8f`. Earlier 54/53 host and 137/6 Studio reports, including earlier P05/P14/reset/blast probes, remain source-specific historical evidence. D50 waives a real late-joining-player scenario for this P07 gate. Keep runtime spectator/rejoin/security behavior, but start only **two actual clients**; there is no four-minute late-join checkpoint or mid-session Start-control requirement.

For an SDK-owned session, launch from MCP Edit/plugin context and retain its returned report:

```luau
task.spawn(function()
    local report = game:GetService("StudioTestService")
        :ExecuteMultiplayerTestAsync(2, { kind = "P07" })
    workspace:SetAttribute("P07LastReport", game:GetService("HttpService"):JSONEncode(report))
end)
return "P07 destruction test started"
```

The revised candidate pipeline covers deployment/rejected traffic; six real M102 hits through Light, Heavy and Total; persistent 30mm damage across separated bursts; the starting shelter’s same-rule six-hit progression; actual ground traversal of an authored Heavy opening; agreement on current credit/appearance/openings and debris expiry; and two resets during live fragmentation and partial/in-flight work. Require all **seven named scenarios** in the stable fixture to be discovered and pass with zero failures/skips/completion errors. The current [P05 regression](evidence/p07-revision-p05-report.json) passes all eight cases with two actual clients. The full native seven-case run passes with zero failures/skips on `8053c8f`, including both resets begun during live fragments, partial credit and pending flights. Server and both actual clients verify all 187 panels. The current [P14 report](evidence/p07-revision-p14-report.json) also passes all six cases, beginning with two actual clients and ending with one after its operator-kick case. These are three separate reports: P07 7/7, P05 8/8 and P14 6/6, each retaining its own source and environment.

The 30mm fixture uses **three bursts of 21 requests**, each request built from the current permitted view, at a **0.18-second test send interval**. Production cadence remains **0.15 seconds**, with a **0.225-second maximum continuity gap**. Drain actual flights, then pause longer than that gap between bursts. Require earned per-panel credit and Light appearance to stay unchanged through the pause. The first accepted impact of every burst earns zero elapsed credit; sum only accepted same-panel `firedAt` intervals inside each continuous burst. The sum, not wall time or trigger duration, must reach nine valid seconds before Heavy appears (1e-7 comparison tolerance). Test resumed fire, misses, target/weapon changes and reload without healing or paused-time credit. Preserve bounded send/receipt/view/impact diagnostics. Exact client comparisons include structural state and `DamageAppearance` independently of stage-local progress.

If the SDK cannot establish two clients, use native **Server & Clients**. With Play stopped in the confirmed test document, verify `ServerStorage.DevelopmentSettings.ManualHarness` is nil, set it to `"P07"`, and start **two** clients. Preserve actual Server workspace `ManualP07Invocation`, `ManualP07Report` and `P07MultiplayerReport`, all client reports, UserIds, round IDs and source/build identity. Use **End Session** after collecting reports, then restore the original Edit selector to nil and verify it. Never persist the selector to source/release. No additional clients are required for revised P07 acceptance. The earlier timeout and disabled-control evidence remain failed historical outcomes; the waiver does not turn them into passes.

Geometry and world checks must cover all **187 candidate registered panels**: 111 in Foundry/Warehouse/Outpost plus 76 starting-shelter panels (42 roof, 34 wall). Confirm that the seven old shelter colliders are replaced without hidden duplicate solids, the exact original union/entrances/anchors and pristine spawn protection remain, and the outside waiting lobby is unchanged. Verify Pristine/Light/Heavy/Total in both normal and grayscale views. Cosmetic face scars cannot collide, enter weapon/thermal queries or identify as structural hits; Heavy keeps its 45–55% opening and dark style at zero stage progress. Static floors, stairs and frames stay usable.

Real-engine rays, collision, fragment fall/contact/ownership, character safety, pre-impact player-blast protection and fresh two-client/reset reports remain separate from operated readability. Run both weapon profiles against all visual tiers, including shelter walls and roof, then review actual native firing, pause/resume feedback, removed panels and falling fragments. The previous [ground QA image](evidence/p07/panel-opening.png) and [operator QA image](evidence/p07/operator-damaged-qa.png) show the prior candidate; they do not validate revised Light/Heavy styling or shelter damage. The fresh solo engine baseline is recorded separately. The current [revision evidence record](evidence/p07-damage-revision.md), [Warehouse report](evidence/p07-revision-fixed-render-report.json) and [starting-shelter report](evidence/p07-revision-shelter-render-report.json) record native mouse firing, persistent damage and all four appearance tiers in both normal and thermal views. Each structure received six real M102 hits, with Heavy at the third and Total at the sixth; true holes and residual-solid occlusion were reviewed with disclosed QA markers. Warehouse’s six initial GAU23 hits earned 0.981612921 seconds that survived 31.366 seconds idle. Shelter’s initial six earned 0.999981880 seconds, unchanged after 43.449 seconds idle; the first resumed hit added zero across a 47.866-second gap, and six resumed hits added only 0.999809027 valid seconds, reaching 1.999790907. These are partial persistence checks, separate from the nine-second three-burst harness gate.

The canonical aircraft orbit clock was held for these comparisons; actual match/combat/physics clocks and native input continued, and the normal-color comparison camera was explicitly controlled. This is not live-orbit, focus/touch or route-feel evidence. All eight normal/thermal stage frames for each structure were reviewed; the shelter has an additional stopped-Light capture. Visible resting debris does **not** by itself prove a visual fall; the earlier MCP captures occurred after landing. The engine baseline measures actual falling/contact. The separate [human-observed fragment demonstration](evidence/p07-revision-human-fragments.json) now closes the focused visual check: a third direct native M102 hit on `Shelter_Roof_R01_C03` made Heavy damage, a real opening and four unanchored fragments while the ordinary private HumanTestSession and Operator camera ran with live aircraft/match/combat/physics clocks. The user watched the Ground client through a labelled **FRAGMENT WATCH** close-up camera at `(−16,8,68)`, looking toward `(−16,12,76)`, FOV 55°. That watch camera was explicitly controlled; no clock or physics takeover was used. The user answered **“Yes, I saw pieces fall.”** This is direct falling-motion evidence, distinct from the earlier settled frames. The full seven-case/reset and six-case P14 reports pass in their documented contexts, completing the current P07 acceptance checks. The [active P07 plan](../plans/07-destruction.md) owns exact criteria and current results; prior reports stay in its historical record.

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

After the self-ending session returns to Edit, inspect `workspace:GetAttribute("P04LastReport")`. Require the inner `P04-multiplayer` report to have `clientCount = 2`, `discovered = passed = 6`, zero failed/skipped cases, and passing baseline reports of 86 server and 3 per actual client on the historical P14 source; use 118 server/six client cases for integrated P06 or the current candidate counts above for a candidate regression. A failure can append a failed harness-completion case; never treat an early exit or missing client acknowledgement as six passing scenarios. Keep actual baseline client counts distinct from the harness's two-client count: the baseline server may finish while clients are still joining.

The pose convergence bound is **8 studs** (approximately 0.32 seconds of motion at 25.13 studs/second on the expanded orbit), measured against the server pose sent to each client. Engine canonical tests use **0.01 studs** and heading dot tolerance `1e-5` for CFrame precision; the live server comparison permits **2 studs** between Heartbeat updates. Record observed errors separately from these permitted bounds. There is no smoothing shell or second gameplay pose.

`Aircraft.spec.luau` additionally samples 17 canonical phases using injected engine time, verifies Hitbox/attachment/collision/query contracts and reset, and tests actual clear/solid-obstructed/exterior/nonfinite aim endpoints. P14 adds authored-envelope rejection and selected-muzzle obstruction cases, making four aircraft cases in the expected 82-case baseline. Thermal automation combines real obstruction rays with occluded Highlight configuration. It must be supplemented by actual rendered review of exposed and fully covered targets, both FOVs, reticle stability, full-orbit ground visibility and role-loss cleanup. A screenshot or Highlight property alone cannot establish correct visual occlusion.

Use the [P04 record](../plans/04-aircraft-and-thermal.md) for original aircraft acceptance and the [P13 record](../plans/13-terrain-and-buildings.md) for the expanded-map regression source, reports and scope. Ordinary Play supports solo Operator preview for inspection, but that cosmetic preview is not two-client replication evidence. Keep unrelated sessions untouched and return the session you launched to Edit.

## Run the P14 panned-targeting harness

The verified horizontal-direction source is integrated on `main`; [P14 acceptance evidence](evidence/p14-horizontal-acceptance.md) records the actual multiplayer and operated results. Earlier orbit and edge candidates have source-specific [correction](evidence/p14-orbit-relative-view.md) and [edge](evidence/p14-edge-overscan.md) evidence. Use the same confirmed test document in Edit with the selected source synced, including Battlefield/AimEnvelope NumberValues. Match mapped source signatures and loaded geometry/configuration before starting. The historical P14 ordinary server/client baselines were 86 / 3; integrated P06 expects 118 / 6; use the current candidate counts above for the candidate. Retain actual counts and client identities.

From MCP Edit/plugin context, start two actual clients and preserve the self-ending result without blocking the MCP call:

```luau
task.spawn(function()
    local report = game:GetService("StudioTestService")
        :ExecuteMultiplayerTestAsync(2, { kind = "P14" })
    workspace:SetAttribute("P14LastReport", game:GetService("HttpService"):JSONEncode(report))
end)
return "P14 panned-targeting test started"
```

The current revised-core [P14 regression report](evidence/p07-revision-p14-report.json) records six discovered/passing cases, zero failures/skips, two initial actual clients and full 90-second orbits at both FOVs. The final operator-departure case uses a server kick and correctly leaves one actual player. Keep the initial two-client requirement separate from that intentional end state; it is not a claim that both clients remain through departure. The current report retains its own tested source/environment and does not replace earlier records.

The prior candidate’s [P07 P14 regression report](evidence/p07-p14-regression-report.json) records all six cases passing with two actual clients, full production orbits at both FOVs and an actual operator departure through a server kick. Its controlled input and Highlight-configuration checks remain separate from focused native firing and rendered destruction/thermal review. Consult the report for exact source and invocation; the departure leaves one actual player, not a new client-count requirement for startup.

Read `workspace:GetAttribute("P14LastReport")` after the original document returns to Edit. Require inner suite `P14-multiplayer`, two actual initial clients, six discovered/passing scenarios, zero failures/skips and passing actual baseline reports. An early error or harness-completion case cannot replace the complete six scenarios. The cases cover:

- Real camera-ray projection to center, four quadrants, useful near-boundary surfaces, nonflat terrain slopes and StoryId `02` panels in Foundry, Warehouse and Outpost: 14 targets at each acknowledged FOV, with at least one full production orbit per FOV.
- A finite inward camera basis over 325 native CFrames (65 orbit phases × five orbit-local held views), actual quarter-screen centerline containment and downward corner rays at every projection probe, plus rendered orbit statistics covering 16 phase bins at each FOV.
- Orbit-local pan preservation through acknowledged/rejected selections, concurrent operator panning and real Ground humanoid movement with unchanged Ground camera ownership, and no change to the canonical aircraft pose.
- Blocked/outside input, recenter, slope/upper-floor occluded Highlight configuration, result/reset/new-operator entry, actual operator departure and drained idempotent runtime/transport teardown.

Declared tolerances are at most 1 pixel / 0.5 studs for same-frame reticle/raycast agreement, plus at most 1 pixel between the actual drawn reticle center (AbsolutePosition + half size + current GuiInset) and its raw ray pixels; 3 studs between the actual reticle hit and requested target; horizontal inward dot at least −1e-6; and at most 2 studs for live canonical camera origin between updates. Target identity remains mandatory: terrain probes require a real nonflat Terrain hit, and building probes require the requested building’s second-story panel. These are distinct from the unchanged 0.01-stud canonical engine pose and 8-stud two-client pose-convergence bounds. Preserve observed maxima separately.

The fixture stops the ordinary client entrypoint through owned cleanup, then constructs the same production RoundPanel with a nonyielding injected directional-pan/aim-pointer/recenter/profile-intent provider. It never assigns focus or adds production test flags/remotes. This proves engine behavior through controlled input, not native input wiring. Run a fresh ordinary human/preview session using the normal UserInputService constructor path for actual WASD, mouse aiming without pan, keys 1/2/R and buttons. Use a mobile emulator or device for held and simultaneous touch-pad directions, a second aiming touch, recenter/profile taps, safe-area layout and lifecycle cleanup. Check active operator and repeated solo Operator/Ground preview entry, text/UI hover, viewport exit/window focus loss, restored mouse/camera state and singleton ownership. Hold each pan bound through orbit motion and confirm the local angle remains stable, the 25%/75% centerline rays remain within the level and corner rays point downward.

For the touch-ownership regression, hold a directional-pad finger and verify it changes pan without claiming or shifting the existing aim. While it remains down, place and move a separate finger on the world view: pan must continue, and the reticle/ray must follow the second finger after applying the current GUI inset. Compare the actual GUI-content `ScreenPointToRay` and converted viewport `ViewportPointToRay`; do not assume a fixed inset. Release each finger in both orders and check no direction remains held. Repeat with GUI-processed input, focused text and window focus loss so UI touches do not claim world aim and interrupted holds do not persist. Record the actual device/simulator, focus/inset state, touch sequence, reticle/ray observations and failures; a simulated input fixture alone is not proof of real simultaneous touch.

### Manual Studio Server & Clients route

A test-only invocation route is available when SDK child launch fails. It runs the same six-case P14 harness with the same assertions; it does not guarantee clients will connect. An earlier native manual attempt launched two client processes but only one joined, so that attempt is not complete multiplayer evidence. Preserve source-specific launch reports and stop that owned session before trying another method.

1. In the confirmed test document’s **Edit** DataModel, with Play stopped, verify the entire candidate and `ServerStorage.DevelopmentSettings` are synced. Its `ManualHarness` attribute must start absent. Set the temporary trusted server-only selector:

   ```luau
   game:GetService("ServerStorage").DevelopmentSettings:SetAttribute("ManualHarness", "P14")
   ```

2. Start Studio’s native **Server & Clients** mode with **2 clients**. The dispatcher requires Studio, nil SDK test arguments and that exact selector before ordinary HumanTestSession startup. No client remote can set the marker; it is absent from Git defaults and the release mapping. `StudioTestService:AddPlayers` is an SDK-owned-session capability and is not a supported way to populate this manual context.
3. In the actual **Server** DataModel, confirm that two actual Players joined at harness startup (one should remain after the operator-departure case), then collect `workspace:GetAttribute("ServerTestReport")`, `workspace:GetAttribute("ManualP14Invocation")` and, when present, `workspace:GetAttribute("ManualP14Report")`. The last value is JSON with `invocation` and the same six-case `result`; it is not the Edit DataModel’s SDK `P14LastReport`. Require the selected source's current baselines and all six cases, zero failures/skips. A missing second player, timeout, early failure or first-case diagnostic remains failed/incomplete evidence.
4. Save the report before cleanup. The manual finish callback writes it to the actual Server workspace rather than self-ending through the SDK return path. End the owned manual session from that actual Server context with `game:GetService("StudioTestService"):EndTest({ reason = "P14 manual cleanup after report collection" })` after preserving evidence, then confirm the original document is back in Edit. Generic MCP Stop was a no-op for this manual context; do not treat its return as proof of teardown.
5. In the restored Edit document, remove the temporary selector with `game:GetService("ServerStorage").DevelopmentSettings:SetAttribute("ManualHarness", nil)`. Verify it is nil even after failure, and do not commit it or carry it into ordinary preview/testing. No human End Session action is required once actual-server EndTest has closed the owned children and Edit is confirmed.

The default SDK route above still uses its normal self-ending EndTest/return behavior. Manual and SDK invocation metadata must remain distinct; neither a delivery callback nor a marker changes client-count or acceptance requirements.

Separately operate both zooms over a full orbit and inspect exposed/covered thermal targets on slopes and upper floors. Verify layout at actual 1280×720 and 1920×1080 viewports, recording simulator/graphics settings and restoring prior state. Record directional responsiveness, off-axis movement, motion comfort, zoom-preserved orbit-local angle and recenter. At the upper/lower/side pan limits, verify that the level edge is visible near the outer quarter of each centerline at wide zoom, and inspect for sky and near-vertical motion. Confirm that the visual backdrop cannot collide or be hit by rays and is removed on role loss. Capture a representative actual panned gameplay image for the root README. The earlier integrated P14 source’s P14/P04 and HumanTestMultiplayer suites pass; rendered cover, desktop/mobile full orbits at both zooms, both desktop viewport layouts, and simultaneous mobile arrows were reviewed. Numerical fixture or property checks alone do not establish the rendered/operated review.

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

Read `workspace:GetAttribute("P13LastReport")` after the session self-ends in Edit. Require five discovered/passing scenarios, zero failures/skips, two initial actual clients, peak three actual clients and all three named buildings in the walked list. Collect the separate baseline reports (the current candidate counts above for this candidate; integrated P06 expects 118/6 and historical P14 expected 86/3); their actual startup client counts can differ from the harness count. A first-case failure or harness-completion error is incomplete acceptance. The teardown/resource assertion runs independently after earlier scenario failure, including a failed third-client launch; its own result is retained without erasing that earlier failure.

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

Require `passed = true`, five passing named cases, `fixtureRemoved = true` and an empty `cleanupErrors` array. Use the current probe’s generated authored counts; the earlier P14 contract had 334 world parts and 360 nodes. The revised shelter changes those totals. Require exact current-source identities/classes/flags and numeric poses/sizes within 0.001. Initial terrain and two perturbed rebuilds must each reproduce eight hills and the fixed 1152-voxel sample (9513 encoded bytes, Adler-32 2054186319), with matching apex materials/elevations. Each rebuild removes a deleted-panel/transient mutation, restores source geometry and preserves an unrelated terrain fixture exactly. Teardown is idempotent; cleanup restores the saved terrain volume, unrelated fixture voxels and removes all probe models.

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
- The orbit follows the map perimeter at all sampled phases while model heading follows the tangent. The P14 camera holds a bounded WASD/touch-panned angle relative to that aircraft; the earlier integrated baseline tracks map center. Both aircraft weapon FOVs keep targeting coherent, distinct and inward-facing, including elevated surfaces and the current quarter-screen level-edge allowance.
- Rapid 30mm/105mm switching cannot reset weapon timers, refill ammunition or bypass reload. Rejected/stale selection restores the correct weapon/FOV/reticle combination.
- Deadline first, then aircraft destruction before ground elimination within the same pre-deadline step: test boundary/mutual-kill cases and late in-flight rockets explicitly.

## Negative network tests

For each mutating action, exercise malformed payloads, NaN/infinity, oversized data, unknown weapon/launcher IDs, unowned equipment, wrong role, spectator/eliminated state, excessive rate, stale round ID, repeated sequence, impossible range/origin and blocked line of sight. Assert rejection **and unchanged ammo/health/launcher-ownership/result state**. Valid traffic must still succeed after a rejected request.

Character movement is client-simulated in normal Roblox play. P06 uses a server-observed, character-scoped movement budget for firing origins: defaults 45-stud burst, 70 studs/second refill, quarantine recovery within 8 studs of the last trusted point or a trusted server correction, and an 8-stud head/root bound. Test ordinary movement, delayed replication, nonfinite data, untrusted teleports, return/recovery and MapService correction; host cases do not prove live networking. It never bans players. Unusual legitimate movement or severe latency may temporarily block shots and require tuning. `GroundOriginGeometry` also checks root/head overlaps, the solid segment in both directions, and six-axis Terrain containment with a voxel fallback; Terrain query errors reject firing. Use real Studio wall, buried-head, slope and ordinary movement cases. The conservative approach is not an exact signed-distance query for arbitrary caves; unusual terrain needs continued operated review. The P08 candidate shares that guard for pickup and rocket fire, and also requires pickup reach and solid-world line of sight. Proximity alone does not grant authority; the guard retains its documented movement limitations.

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

An ordinary one-client Play in `PlayersVsC130Tests` automatically enters a labelled solo map preview after the current source's expected server/client baseline cases listed above. WASD works in both the preview and the protected lobby. The preview keeps the player Waiting and the phase Lobby; it does not fabricate an operator, active life or match result. With two or more clients, use the human panel to choose roles and explicitly start the real round loop. See the [root guide](../README.md#run-local-automated-tests) for human test panel controls.

The explicit `ExecutePlayModeAsync({kind = "LobbyControls"})` scenario runs four TestEZ engine cases through `LocalTestControlsCheck`, then ends the session with structured results. Check `discovered = passed = 4`, no errors/failures/skips, and actual `clientCount = 1`. Focused operated WASD checks supplement unanchored-root assertions. No additional Studio client windows are required. [Fix evidence](evidence/lobby-preview.md) records actual execution.

For human-control regression, run `ExecutePlayModeAsync({kind = "HumanTestControls"})` and require six discovered/passing cases, zero failures/skips/errors, one actual client. Then `ExecuteMultiplayerTestAsync(2, {kind = "HumanTestMultiplayer"})` requires four passing cases and two actual clients, covering conflicting choices, requested real roles, changing next-round settings without mutating an active round, and reset/start applying the new choices. Both sessions end themselves; verify the original document is back in Edit and close only the session you launched. Operated test-panel button checks supplement the server decoder tests.

## Expanded-map, panning and destruction acceptance

Historical P02/P04 evidence establishes the prior 180-stud-radius, fixed-focus prototype. [P13](../plans/13-terrain-and-buildings.md) supplies the current 360-stud-radius terrain/building source and its named suites; consult its record for actual results and validation scope. The [P14](../plans/14-aircraft-panning.md) panning implementation completed real-engine and operated acceptance and is integrated on `main`; the revised [P07](../plans/07-destruction.md) destruction implementation is integrated on `main`, with source-specific acceptance and [integration evidence](evidence/p07-integration.md) recorded separately. R16 extends release traceability to authored terrain and three accessible multi-story buildings.

- P13: source-built 720-stud disk/equal perimeter orbit, versioned terrain elevation/material reconstruction, building/story/panel registry, actual stairs/upper-floor navigation, supported anchors, separate lobby and two launcher routes.
- P14: signed-direction/delta-time pan rules; full-orbit relative-angle and quarter-screen edge bounds at both zooms; elevated terrain/upper-floor projection, preserved local focus under weapon selection, recenter and role cleanup with two actual clients.
- P07: exact heavy-hit 3/6 boundaries, nine earned valid 30mm seconds with persistent per-panel credit across timing breaks; distinct Pristine/Light/Heavy/Total appearance, shelter coverage, measured real openings, pre-impact cover/thermal rays, actual fragment physics/query exclusions and repeated two-client resets. D50 waives real late joining for this gate only.
- P11/P12: expanded-map travel/visibility and simultaneous fragment workloads in frame/memory/latency/soak measurements; repeat the revised level/panning/destruction demonstrations in real 6- and 10-player acceptance.

Record numeric tolerances and chosen defaults before running each suite. Test doubles cannot prove terrain loading, residual collision, camera coverage, rigid-body contact or replication. Earlier engine reports must not be relabeled as evidence for this expanded scope.
