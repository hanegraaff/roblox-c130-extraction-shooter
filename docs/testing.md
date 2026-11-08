# Testing and acceptance

## Current host checks

Run `python3 scripts/setup.py` once for the pinned dependencies, then `python3 scripts/verify.py`. The verifier is the full non-Studio gate for the foundation, map and round source. It fails on missing tools, type/lint/format errors, test failures, empty required suites or leaked test content. Future plans extend this entrypoint as their behaviors arrive.

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

The standalone runner discovers `*.spec.luau` modules and emits JSON with `suite`, `discovered`, `passed`, `failed` and `skipped`. The current unit suites have 24 cases across six modules: finite/payload/config/rate checks, map/orbit rules, roster boundaries/seeded rotation and phase/outcome policy. The 14 integration cases exercise the real lifecycle controller and `MatchService` with controlled time and life-cleanup adapters. Server-only role/round modules load from `src/server`, without replicating authoritative code to make it testable. The suites load production modules, not copies of their rules.

The verifier also copies source into disposable fixtures to inject a deliberately failing case and an empty unit suite. Both must exit nonzero with the intended diagnostic. A temporary strict-type fixture assigns strings to `Part.Anchored` and a number variable; analysis must reject it using real Roblox definitions. These are expected rejection probes, not shipped failing tests. The temporary fixtures are removed after the probes.

Artifact inspection parses the generated XML, checks the runtime-script allowlist and verifies the absence of test runners, TestEZ, fixtures and development overrides from the release DataModel. It also compares all authored `.model.json` Part/SpawnLocation entries with both generated builds: twelve finite canonical `CFrame` components, positive matching dimensions, shape, and Anchored/CanCollide/CanQuery/CanTouch flags. The current assets contribute 112 checked parts per build. `Position`/`Orientation` aliases in source or serialized output reject. Five disposable corruptions must fail the production geometry checker: a pose alias, wrong pose, wrong size, NaN pose component and missing CFrame. These expected rejections are artifact probes, separate from Luau suite counts.

Update the allowlist deliberately when adding runtime modules and keep canonical authoring rules in the [asset guide](../assets/README.md). Build success, byte-identical reconstruction and serialized-property checks do not establish actual engine-loaded geometry, navigation or raycasts. The Studio map suite separately asserts the loaded disk, spawn and roof transforms before testing world behavior.

## Run the Studio smoke suites

1. Build with the full verifier. Open `build/tests.rbxlx` as a separate local Studio document, or sync `test.project.json` into a separate test place. Preserve any unrelated open place and unsaved work.
2. Through Studio MCP, list connected instances, select the intended test document and inspect its state. Consult the connected server’s relevant skill guidance. Confirm that `ServerScriptService.ServerTests`, `StarterPlayer.StarterPlayerScripts.ClientTests`, `ReplicatedStorage.TestPackages` and `ServerStorage.DevelopmentSettings` belong to the test mapping.
3. Start **Play** with one actual client for the foundational TestEZ suites. The mapped server and client runners execute automatically. The server requires a player within ten seconds. Startup waits are bounded; a missing report or timeout is a failure requiring investigation. The round runtime starts only after the server suites pass, avoiding map rebuild/character races. Solo Play then waits for the test minimum of two players.
4. Read both structured JSON reports and the Studio Output log. In the **server** context:

   ```luau
   return workspace:GetAttribute("ServerTestReport")
   ```

   In the **client** context:

   ```luau
   return game:GetService("Players").LocalPlayer.PlayerScripts.ClientTests:GetAttribute("ClientTestReport")
   ```

5. The current candidate expects 45 server cases and two client cases; consult the [P03 record](../plans/03-rounds-and-roles.md) for actual execution evidence. For each run, collect fresh reports. Each must have `discovered > 0`, `passed == discovered`, and zero `failed`, `skipped` and `errors`. Reports include `suite`, `environment = "Studio"` and fixture `seed = 1`; the server adds actual `clientCount`, and the client adds its `userId`. Aggregate labels remain `P01-server` and `P01-client`; server discovery includes Foundation and Map specs plus the P03 shared cases. A report's client count and context must match the claim being made.
6. Stop Play and start it again. Collect fresh reports and verify one `ReplicatedStorage.BootstrapStatus`, one local `PlayerGui.FoundationStatus` and one round HUD after round startup, with no leftover `EntrypointStatus` or `EntrypointPanel`. The baseline suites also exercise two explicit stop/start cycles of the bootstrap owner and status controller.
7. In the separate development document, Play and confirm **Development** / **Bootstrap running**, a protected lobby character and a round panel waiting for six players. The test build reads **Test** and waits for two after its suites. Review actual viewport readability and Output, then stop when finished.

The server runner loads all 24 unit and 14 integration cases through actual Instance requires, plus two foundation and five map engine cases (45 expected total). Foundation checks cover bootstrap ownership and the anchored spawn raycast. [`Map.spec.luau`](../tests/studio/specs-server/Map.spec.luau) exercises actual `MapService` with disposable Instance fixtures:

- Assert actual loaded disk/spawn/roof transforms, then reject invalid disk dimensions, anchor identity/count and exterior/below-ground/floating/blocked anchors before restoring validity.
- Sample both launcher approaches every 0.5 stud with a 4×6×4-stud upright envelope and downward floor rays. This recorded envelope is a clearance fixture, not an avatar compatibility claim.
- Raycast permanent/breakable cover, all nine sheltered anchors and firing positions toward eight future perimeter aircraft samples.
- Correct exterior/below-threshold characters, preserve legal disk/station positions, and disconnect containment on stop.
- Rebuild twice after removed cover and transient debris; compare descendant counts, stable part names and poses, then exercise idempotent destruction.

The client TestEZ suite checks replicated bootstrap status, initial character availability and status GUI/controller cleanup. It does not prove round replication, no-respawn behavior or spectator cameras; the separate multiplayer harness below targets those. Prior P02 map/walking evidence is recorded in its plan. A new geometry candidate still needs engine checks; host success cannot satisfy them. The 4×6×4-stud clearance fixture and the operated R15 avatar are separate evidence, not proof for all avatar proportions or accessories.

For the focused review, walk from the southern shelter along the teal west route and ochre east route to the gold center marker, inspect the orange boundary, and review exposed sight lines toward sampled perimeter positions. Record whether routes are understandable, cover is readable and movement feels usable, with viewport/graphics settings and actual observations. There is no launcher pickup, aircraft or combat to exercise yet.

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

For focused player review, use an ordinary three-client **Server & Clients** session without harness args. After the foundational suites, this starts a two-player-minimum loop with 60-second rounds, explicit start and three-second results. Observe both role views, countdown, surrender/reset, teammate camera, result and fresh lobby. The operator view is a protected avatar placeholder; aircraft, thermal view, weapons and launcher are unavailable. Record readability and camera observations separately from automated pass counts. End the test session when finished.

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
- The orbit follows the map perimeter at all sampled phases; camera look tracks map center while model heading follows the tangent. Both aircraft weapon FOVs keep targeting coherent, distinct and inward-facing.
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

An ordinary one-client Play in `PlayersVsC130Tests` automatically enters a labelled solo map preview after the 45 server / 2 client foundational cases. WASD works in both the preview and the protected lobby. The preview keeps the player Waiting and the phase Lobby; it does not fabricate an operator, active life or match result. With two or more clients, use the human panel to choose roles and explicitly start the real round loop. See the [root guide](../README.md#run-local-automated-tests) for human test panel controls.

The explicit `ExecutePlayModeAsync({kind = "LobbyControls"})` scenario runs four TestEZ engine cases through `LocalTestControlsCheck`, then ends the session with structured results. Check `discovered = passed = 4`, no errors/failures/skips, and actual `clientCount = 1`. Focused operated WASD checks supplement unanchored-root assertions. No additional Studio client windows are required. [Fix evidence](evidence/lobby-preview.md) records actual execution.

For human-control regression, run `ExecutePlayModeAsync({kind = "HumanTestControls"})` and require six discovered/passing cases, zero failures/skips/errors, one actual client. Then `ExecuteMultiplayerTestAsync(2, {kind = "HumanTestMultiplayer"})` requires four passing cases and two actual clients, covering conflicting choices, requested real roles, changing next-round settings without mutating an active round, and reset/start applying the new choices. Both sessions end themselves; verify the original document is back in Edit and close only the session you launched. Operated test-panel button checks supplement the server decoder tests.
