# Testing and acceptance

The P25 checks build on the three-client P18 harness for weapon switching, launcher handover, shared damage, rifle reload feedback and replay. P24 checks the Ground head start and transition to combat. P23 checks lobby return, theater interaction and the two-minute intermission. Collect native evidence from the synced source under test. Use the recorded Git revision to reproduce earlier evidence. `HarnessCompatibility` rejects archived balance and camera selectors before allocating the runtime or listeners. [P25 weapon balance](#verify-p25-weapon-balance) · [P24 aircraft arrival](#run-the-p24-aircraft-arrival-harness) · [P23 lobby](#run-the-p23-lobby-and-intermission-harness)

P12’s legacy implementation handoff is closed by user direction. Live platform/access, capacity, performance and soak checks remain unverified in the [future release checklist](release.md).

## Staged fixture compatibility

| Current source path | Actual clients | Scope |
| --- | --- | --- |
| Ordinary Play smoke | At least 1 | Current deterministic and engine/client baseline; collect every actual client report |
| `P29` | 3 | Four supported pickups, equipped model and muzzle, timed handoff, recovery after carrier death and replay cleanup |
| `P28` | 2 | Aircraft reveal, full orbit and rotor movement, weapon zoom masks and firing origins, visible hit surfaces and replay after destruction |
| `P26` | 2 | Owner and tester permissions, all four weapons, both health pools, panel damage, minimum players and consecutive intermissions. Use `P26Panel` for the hands-on lobby preview |
| `P24` | 2 | Production-length Scatter, both countdown views, real launcher transfers and fire gating, aircraft reveal, role rotation and canceled arrival |
| `P23` | 3 initially, 4 after late join | Protected lobby return, theater interaction, result and production-length intermission, and two battlefield resets |
| `P18` | 3 initially, 2 after intentional departure | Roster health, panel/thermal/camera state, four-site ownership/recovery and replay. On P25, this selector also exercises weapon cooldowns, launcher damage and M-7 magazine feedback |
| `P05` | 2 | Actual client fire/remotes and physical flights, both weapons, one-howitzer native opening, authority and cleanup. P19 adds four empty-ground surface witnesses, exposed, shielded and out-of-range player checks, ground contacts beside all five buildings and a direct roof hit |
| `P19Profile` | 2 | Candidate-branch five-minute mixed weapon workload, render and scheduler frame timing, local impact readiness and resource peaks. SDK scenario `Replay` runs five resets and observes empty-air rocket expiry |
| `P03`, `P04` | Their documented rosters | Compatible lifecycle and canonical aircraft/orbit regression paths |
| `P06`, `P06Team`, `P07`, `Sandbreak`, `P08`, `P09`, `P10`, `P11`, `P14`, `P14ArrivalRegression`, `P17` | Historical only | Explicit pre-P18 version rejection; run the recorded source to reproduce prior evidence |

`Workspace.HarnessCompatibilityReport` identifies a rejected selector, reason and replacement before the archived server coordinator starts. The shared test-only compatibility guard also protects direct fixture entry. No archived gameplay assertion is relabelled as passing current behavior. P17 asset reconstruction/provenance checks remain active; its frozen old staged body is preserved separately.

Ordinary multiplayer test rounds and the P24 and P28 selectors exercise the 20-second head start. The named P03, P04, P05, P18 and P23 regressions use zero Scatter time to isolate their existing checks.

## Current host checks

Run `python3 scripts/setup.py` once for pinned dependencies, then `python3 scripts/verify.py`. The full non-Studio gate exercises the match and its underlying map, view, weapons, launcher, panel destruction and Outpost reconstruction. It fails on missing tools, type/lint/format errors, failed or empty required suites and test content in release builds.

| Gate | Command used by the verifier |
| --- | --- |
| Repository inputs | `python3 scripts/check_repository.py` |
| Asset provenance, native harness and release preparation tooling tests | `python3 -m unittest discover -s tests/tooling -v` |
| P16 committed asset package | `python3 scripts/p16_audit.py` |
| P17 generated approved-source definition | `python3 scripts/p17_assets.py` |
| P17 equivalent material-split GLB | `python3 scripts/p17_library_glb.py` |
| P17 managed import reconstruction | `python3 scripts/p17_compile_outpost.py` |
| P17 managed native harness source binding | `python3 scripts/p17_harness.py` |
| Asset audit regression tests | `python3 -m unittest discover -s tests/assets -v` |
| Format | `stylua --check src tests scripts/run_tests.luau scripts/p17_native_mesh_xml.luau` |
| Lint | `selene src tests scripts/run_tests.luau scripts/p17_native_mesh_xml.luau` |
| Roblox sourcemap | `rojo sourcemap test.project.json --output build/sourcemap.json` |
| Strict types | `luau-lsp analyze --platform=roblox --sourcemap=build/sourcemap.json --definitions=@roblox=.tools/globalTypes.d.luau src tests scripts/run_tests.luau scripts/p17_native_mesh_xml.luau` |
| Unit rules | `lune run scripts/run_tests.luau unit` |
| Lifecycle integration | `lune run scripts/run_tests.luau integration` |
| Release/test builds | `rojo build default.project.json --output build/game.rbxlx` and `rojo build test.project.json --output build/tests.rbxlx` |
| Authored geometry, corruption probes and artifact isolation | `python3 scripts/inspect_build.py` |

Direct tool commands require `$HOME/.rokit/bin` on PATH; setup and verify arrange that internally. The [development guide](development.md) lists versions and installation requirements.

The standalone runner discovers `*.spec.luau` modules and reports `suite`, `discovered`, `passed`, `failed` and `skipped`. The unit, integration, tooling and asset runners each report their own discovered counts. Record the exact final gate counts in the plan under test, including rejection probes and artifact checks. Client frame measurements, physical fragments, collision, rendered readability and multiplayer replication require separate engine evidence. [Release runbook](release.md#prepare-the-candidate-from-git)

The verifier also copies source into disposable fixtures to inject a deliberately failing case and an empty unit suite. Both must exit nonzero with the intended diagnostic. A temporary strict-type fixture assigns strings to `Part.Anchored` and a number variable; analysis must reject it using real Roblox definitions. These are expected rejection probes, not shipped failing tests. The temporary fixtures are removed after the probes.

Artifact inspection parses the generated XML, checks the runtime-script allowlist and excludes test runners, TestEZ, fixtures and development overrides from the release DataModel. It compares every authored `.model.json` Part/SpawnLocation in both builds: twelve finite canonical CFrame components, matching positive dimensions, shape and collision/query/touch flags. It also checks the terrain recipe, primitive building/panel contract, imported templates and test-only harness mappings. Take current Part/Instance/script counts from the actual inspector output; older Outpost-only counts do not describe all installed landmarks. Runtime imports and native-loaded fidelity remain separate checks.

Five deliberate corruptions check rejection of a pose alias, wrong pose, wrong size, nonfinite pose component and missing CFrame. A separate building-surface guard checks visible-part pairs for exposed coplanar faces. It allows ordinary edge/contact joins and intersections hidden inside opaque supports. Its three corruption probes reject a floor on the battlefield plane, an overlapping floor/frame face and a duplicate wall panel. These are artifact probes outside Luau suite totals.

Update the allowlist deliberately when adding runtime modules and keep canonical authoring rules in the [asset guide](../assets/README.md). Build success, byte-identical reconstruction and serialized-property checks do not establish actual engine-loaded geometry, navigation or raycasts. The Studio map suite separately asserts the loaded disk, spawn and roof transforms before testing world behavior.

## Verify the live balance panel

From the candidate checkout run `python3 scripts/verify.py`. The balance schema, record and service suites exercise field bounds, permissions, concurrent edits, rollback and storage failure. The match, weapon, health and panel suites exercise the gameplay effects of changing settings. Use the [panel plan](../plans/26-live-balance-panel.md) for acceptance criteria and observed results.

To use the panel yourself, follow the [local walkthrough](balance.md#try-it-in-studio). To run the two-client acceptance fixture, sync the local test document to `PlayersVsC130Tests` on port 34872. With Play stopped, run this from Studio’s Edit context.

```luau
task.spawn(function()
    local report = game:GetService("StudioTestService"):ExecuteMultiplayerTestAsync(2, {kind = "P26"})
    workspace:SetAttribute("P26LastReport", game:GetService("HttpService"):JSONEncode(report))
end)
```

Read `workspace:GetAttribute("P26LastReport")` after the run. For manual **Server & Clients**, set `game.ServerStorage.DevelopmentSettings:SetAttribute("ManualHarness", "P26")` in Edit, start two clients and read the server’s `Workspace.P26MultiplayerReport` attribute before stopping. Clear the selector in Edit afterward. The fixture exercises real Roblox clients and game systems with a session-only settings store.

The P26 published check uses two players in one new Roblox server. Apply a change in the balance panel, play multiple rounds and observe the new values on a subsequent deployment. [Owner playtest](../plans/26-live-balance-panel.md#2026-11-28--published-owner-playtest)

For R25 public release verification, use an authorized private experience containing the release candidate. Start two Roblox servers and use the owner, a trusted tester and an ordinary account. Save and apply a distinctive preset on one server. Record the revision and measure the effect on the next round in both servers. Start a fresh server, check it loads the same settings, then restore the previous preset and repeat. Verify that only the owner manages tester access and that an ordinary player cannot edit settings. Record anonymous roles, server and build versions, observed values and rollback results. [Operating the panel](balance.md)

## Verify P25 weapon balance

Run `python3 scripts/verify.py` on the P25 source. The deterministic combat and launcher specs check rejection just before 12 and 15 seconds, acceptance at the exact deadlines, independent readiness, and stale and duplicate rejection. Aircraft health and match specs cover 1,000 → 850 → 845 health, the seventh rocket destroying a pristine 1,000-health aircraft, roster scaling, and mixed damage at the deadline. The rifle and presentation specs cover repeated reloads beyond the former 150 rounds, partial and empty magazine behavior, cancellation, and desktop and touch copy. The ordinary server smoke also exercises native cover and damage gates. [P25 acceptance criteria](../plans/25-weapon-cooldowns-and-rifle-ammo.md#acceptance)

Follow the three-client P18 procedure below, using SDK `{ kind = "P18" }` or the local `ManualHarness = "P18"` selector. The P25 suite uses one operator and two Ground players in a shared round. Collect `P18LastReport` from the Edit context in SDK mode, or `P18Report` and `ManualP18Report` from the server before ending a manual session. Require all 13 cases on the normal path, three initial client reports, and two clients remaining after the deliberate departure. Look for the 12-second M102 countdown surviving a switch through the chain gun, a real rocket hit bringing all three HUDs to 1,850 of 2,000 health, unchanged Seedship launcher readiness at handover, and the M-7 HUD going from 30 to 29 to 30 loaded rounds while showing ∞. Replay checks the new round's full rifle magazines and four loaded launchers. [P18 launch, parity and reporting](#run-the-p18-rebalancing-harness)

Run the two-client P05 and P24 regressions for the 25-stud blast, panel openings, early-fire gating and post-arrival combat. On P25, a direct rocket in the P24 one-Ground fixture takes shared health from 1,000 to 850. Collect each suite's smoke and native result separately. [P05 gunship procedure](#run-the-p05-gunship-combat-harness) · [P24 arrival procedure](#run-the-p24-aircraft-arrival-harness)

Review actual desktop and phone HUDs in a local round. Read the howitzer and launcher timers after firing, then switch away and back. For the M-7, fire a round, reload with **R** or **RELOAD**, and check that the loaded count, ∞ and the timer fit the readiness row during reload. Check the health and launcher rows for overlap and confirm the next round shows ready equipment. Record viewport and input mode with the observations, and restore the simulator and the Edit selector when finished. `GroundAimGui.spec.luau` uses synthetic presentation inputs with the production layout. It checks the touch Reload button’s native text fit, padding and clearance from adjacent controls across compact viewports. Native observation of live readiness and multiplayer handover uses the separate sessions above.

## Run the P18 rebalancing harness

Use the same confirmed local test document in Edit mode with `test.project.json` synced through **PlayersVsC130Tests** on port **34872**. Require `PlaceId = 0` and `GameId = 0`; keep the cloud/release document separate. Run the full host gate and identify the exact source commit/build before Play.

After a fresh test build, generate the read-only source/anchor comparison:

```sh
python3 scripts/p18_studio_probe.py
```

Execute `build/p18-studio-probe.luau` through Studio MCP in the selected **Edit** DataModel. Save its result with `build/p18-studio-probe.json`. The probe compares loaded script UTF-8 lengths/djb2 checksums and the four pickup/platform poses; the receipt binds the complete artifact with SHA-256. It does not synchronize source, cryptographically prove loaded Sources or establish gameplay. Fix any mismatch through Rojo before starting a fresh session.

P18 needs **three actual clients**: one operator and two Ground players. Start asynchronously from MCP Edit context so inspection remains available:

```luau
assert(game.PlaceId == 0 and game.GameId == 0)
assert(not game:GetService("RunService"):IsRunning())
assert(workspace:GetAttribute("P18LastReport") == nil)
task.spawn(function()
    local report = game:GetService("StudioTestService")
        :ExecuteMultiplayerTestAsync(3, { kind = "P18" })
    workspace:SetAttribute("P18LastReport", game:GetService("HttpService"):JSONEncode(report))
end)
return "P18 started"
```

The excluded `RebalanceHarness` starts production runtime after the ordinary server suite. `Workspace.P18Stage` names the active check. The coordinator waits for three distinct players and fresh client smoke reports, then checks shared 2,000 health, fixed damage/no resize after Ground death/departure, panel openings and interrupted timing, camera frames, thermal state, contested pickup/one-carrier ownership, recovery/reload and replay. A local server Kick exercises actual carrier departure, so the run starts with three clients and intentionally ends with two; retain all initial smoke reports and the separate final count. Structural fixtures enter at the trusted accepted-outcome boundary; they do not exercise the gunship input/projectile path. Run the adapted two-client P05 harness as the required supplement: actual client fire/remotes and physical flights must show both weapon profiles, including a one-howitzer Total opening on a pristine registered upper-story panel observed by both clients. Preserve this distinction alongside actual launcher intent/native collision observations.

For **Server & Clients**, set local Edit `ServerStorage.DevelopmentSettings.ManualHarness = "P18"`, start **3 clients**, and collect `Workspace.P18Report` / `ManualP18Report` in the actual Server context before ending the session. Restore the original selector, normally nil, after returning to Edit. For SDK mode, retain `P18LastReport` after owned teardown. Require the `P18-rebalancing` report to identify three initial actual clients and the intentional two-client end state, nonzero discovered cases with all passed and zero failures/skips, plus passing ordinary server and every-client reports. A report missing after startup, an early failure or unavailable client is incomplete evidence.

`OperatorControlLayout.spec.luau` exercises the production Recenter placement adapter against actual GUI Instances, negative/positive canvas origins, resized viewports and the native device-safe root. It checks the button’s bounds and that its center resolves to the actionable button in the native GUI registry. The pure `controlTopRight` cases cover pixel intersection, reduced padding and invalid/insufficient-space rejection. Collect those current-source results, then perform an actual tap at the visible Recenter center in phone emulation and confirm focus returns to map center while the controls remain reachable after resizing. Record that operated tap separately from layout/hit-registry assertions.

A separate operated check must use the normal input path for WASD/touch arrows, edge/corner reversal, independent aim, both zooms/recenter and role cleanup. Walk an actual Ground avatar into the Seedship and onto its launcher platform without breaking cover. Review white exposed/covered/earned-opening targets against darker grayscale Terrain, textured landmarks and the independent dark backdrop at both FOVs, recording viewport/graphics/input settings. Confirm imported texture colors are desaturated in the rendered world while the Ground view keeps its normal palette; capture the scene rather than inferring monochrome appearance solely from Highlight or ColorCorrection properties. Confirm the operator’s own aircraft cannot mask its targeting view while a Ground client still sees the plane and its shots retain server-resolved hits. Native lifecycle assertions must cover exact transparency/color restoration through role loss, aircraft replacement and late SurfaceAppearance arrival/removal. Changes to these visuals require fresh source-bound checks; earlier input/route/cover probes retain their recorded source scope. Numeric finite-frame and Highlight-property assertions cannot establish comfortable movement or rendered contrast. Use [P18 A1–A6](../plans/18-game-rebalancing.md#acceptance-criteria) to map each required check and retain failures as well as passing results.

## Verify the integrated P17 Outpost

The Outpost gate includes 48 asset regression cases, native harness tooling,
seven P16 audits and the P17 definition, GLB, reconstruction and source-binding gates.
`p17_assets.py` pins the approved Blender/catalog/lock
identity. `p17_library_glb.py` decodes the material-split derivative and compares
its triangles, corner UVs, materials and embedded PNGs with the approved sources.
`p17_compile_outpost.py` reconstructs the managed templates from native import
receipts and repaired texture references, rejecting missing/changed data.
`p17_harness.py` checks the frozen fixture bodies and fingerprints current
production and test inputs. The pinned reference commit and tree in Git history
identify the historical P17 provenance separately. If a bound source change
stales the generated metadata, review the change and refresh with
`python3 scripts/p17_harness.py --write` before rerunning the host gate. Native
acceptance still requires the Studio checks below.

The candidate installs 26 detailed Outpost panels, preserving 25 legacy pivots
and adding one partition, for 188 active panels overall. The source-built
pristine template has 2,256 visible MeshParts. Source-specific host results and
native acceptance status belong to the [P17 record](../plans/17-integrate-military-outpost.md).
The original P16 package and its human approval are unchanged.

The compiler now preserves genuine engine constructor data, not only MeshId and
target Size. A managed native RBXM/receipt covers 407 profiles (87 PreciseConvexDecomposition
and 320 Box) across 2,332 template uses. InitialSize and opaque PhysicalConfigData,
PhysicsData and AeroMeshData bytes must match the source-bound capture. Shared
`AssetMesh.validate` checks public MeshSize/fidelities against readable v1
metadata in ordinary server/client contexts. Host checks bind payload bytes and
metadata; a valid public check does not prove rendered bounds, UVs, actual
collision contacts or multiplayer fidelity. Those need fresh native acceptance.

Run a fresh source-confirmed local test document. The recorded P17 camera mapping expected
**179 server cases and twelve per actual client**. Earlier ordinary local Studio Play
on `ee19deb5` passes 173/173 server and 10/10 client, one actual client, with zero
errors, failures or skips. Native constructor/preflight/floor-collision fixtures
pass. That actual client also validates all 2,256 Outpost MeshParts with
AssetMesh: 2,000 Box and 256 PreciseConvexDecomposition uses. This is runtime
intrinsic/fidelity validity, separately from the 407-profile authoring-bank count.
A bounded exterior camera review now shows a correctly scaled, textured Outpost
without the earlier giant planes; it does not approve all art or damage states.

The managed P17 suite passed all ten cases on `f565aed` with two actual
clients and zero failures or skips. Its ordinary 173/10/10 baselines were
collected at `5fc5f0b` startup. Production and the ordinary smoke inputs match
the passing candidate. The suite exercised native avatar routes, real weapon
impacts, replicated material stages and openings, and both live-work resets of
all 188 panels. A separate native probe on the same production source verified
descent and static contact for all 24 approved fragments across six families,
plus character/query isolation, expiry and owner cleanup.
[Managed suite report](evidence/p17/native-p17-f565aed-pass-summary.json), [imported fragment probe](evidence/p17/imported-fragment-contact-221d1a8.json).

| Suite / file | Intended native assertions |
| --- | --- |
| [`MaterialPanels.spec.luau`](../tests/studio/specs-server/MaterialPanels.spec.luau) | Controlled empty-cosmetic fixtures for catalog rejection, shared damage/proxies, real Heavy/Total rays and bounded fragment-template lifecycle |
| [`Outpost.spec.luau`](../tests/studio/specs-server/Outpost.spec.luau) | Actual managed template validation, ordinary-server material/native-intrinsic reads, invalid-support/pivot rejection before mutation, exact site/legacy identities/rollback, material-family heavy thresholds and real openings |
| [`ThermalCosmetics.spec.luau`](../tests/studio/specs-client/ThermalCosmetics.spec.luau) | Ordinary-client material/native-intrinsic reads; local non-cover/own-aircraft masking, solid-cover retention, late-surface retint and exact transparency/color/listener cleanup |
| [`P17MaterialHarness`](../tests/studio/server/P17MaterialHarness.luau) | Two-client native checks for rejection, mesh availability, avatar traversal, all six material families, actual weapon fire, earned openings, fragment expiry and two damaged-to-pristine resets |

Client readiness waits run inside bounded test callbacks, after the actual
Outpost replacement and descendant compiled-material metadata are available.
Module loading does not block waiting for GameRuntime to start. Record the ready
revision and actual client identity with each fresh report.

Empty-cosmetic fixtures remain useful isolation checks; they do not prove
imported art. Managed-template tests require the actual catalog/mesh references
but still do not establish successful texture loading, UV appearance, rendered
thermal cover, native avatar traversal or complete multiplayer reconstruction.
Ordinary server/client code reads compiled material metadata through shared
`AssetMaterial.read`, never SurfaceAppearance's protected map slots (including
Content variants). The compiler and artifact/Edit audits separately bind those
readable attributes to actual serialized slots and approved PNG receipts.
Metadata validation is not asset-loading proof. Real-Instance preload and
rendered review remain separate. Twelve working color-map preload results do
not establish the missing scalar roughness/metalness/emission appearance.
That compromise requires explicit A6 review.

### Run the managed P17 multiplayer harness

> Historical pre-P18 procedure: this selector is archived and rejects before allocating runtime/listeners on the current candidate. Reproduce old evidence from its recorded Git revision. Use current P18 plus adapted P05 for rebalancing acceptance; preserve the report below as historical evidence.

1. Build from the selected source and use the separate local `tests.rbxlx`
   document (`PlaceId` and `GameId` both zero). Confirm its identity through
   Studio MCP in Edit mode. Match its script Sources, 2,332 managed
   template meshes, 9,328 serialized material slots and target Size/CFrame
   values to the test artifact before Play. The generated harness metadata
   supplies provenance. The Edit comparisons verify what Studio loaded.
2. With the local test place stopped and no other test owner active, set these
   temporary attributes on `ServerStorage.DevelopmentSettings`. Use the full
   commit of the test build being exercised. Historical P17 runs record their
   own source. [P17 evidence record](../plans/17-integrate-military-outpost.md)

   ```luau
   local settings = game:GetService("ServerStorage"):FindFirstChild("DevelopmentSettings")
   assert(game.PlaceId == 0 and game.GameId == 0 and not game:GetService("RunService"):IsRunning())
   assert(settings and settings:IsA("ModuleScript"))
   assert(settings:GetAttribute("ManualHarness") == nil)
   assert(settings:GetAttribute("P17HarnessCommit") == nil)
   settings:SetAttribute("P17HarnessCommit", "<full test-build commit>")
   settings:SetAttribute("ManualHarness", "P17")
   ```

3. In Studio choose **Server & Clients**, set **2 clients**, and start. The
   ordinary TestEZ reports must show nonzero discovery, current-source case counts,
   all cases passed and zero failures, errors and skips. Check the actual server
   report counted two clients and the two client reports identify distinct
   players. P17 starts through the local selector and keeps the session open
   for collection. A roster or owner conflict can fail preflight before a
   harness report exists.
4. Read `P17ManualInvocation`, `P17ManualStage` and `P17ManualSummary` in the
   actual Server DataModel. When `ServerStorage.P17ManualEvidence` has
   `Complete=true`, collect the `Chunk0001`, `Chunk0002`, etc. StringValues
   in order. Verify `ChunkCount` and the combined UTF-8 byte count against
   `TotalBytes` and parse the complete JSON. Preserve the actual reports,
   source/build and Studio identity, including any wrapper error. Require ten
   discovered and ten passed with zero failures and skips, two distinct actual
   clients, clean baselines, and passing cleanup observations. Review the
   same-panel impact diagnostics, stage and opening checks, and both resets.
   The fixture reports the six-family controlled stage outcomes and actual
   fire as separate cases. Its printed case prefixes are fixture labels.
   Use the plan's criteria for acceptance, including A6 human approval.
5. Use **End Session** after collecting evidence. In the original local Edit
   document restore both temporary attributes to their prior values, normally
   nil, and check that the session, runtime and test transports are gone.
   Keep selector attributes out of committed definitions and published places.

Run P08 and P17 in separate native sessions. P08 starts with three clients.
Archive its reports, including the stock carrier departure and cleanup, then
use **End Session**. The original local Edit document supplies the fresh
world for P17. The surviving P08 clients and their world have already run
through character lifecycle and Outpost installation, which prevents the
ordinary startup fixtures from passing again in that DataModel.

### Review P17 gameplay evidence and collect approval

The native P08 launcher, P07 destruction, P05 combat and P14 panning
regressions passed 11/11, 7/7, 8/8 and 6/6 respectively on the integrated
production source. The [P14 rerun](evidence/p17/native-p14-8ccdc37-pass-summary.json)
verifies two full 90-second orbits, both zooms and current thermal occlusion.
Use the [P17 record](../plans/17-integrate-military-outpost.md) for
source-specific results and previous attempts.

The [operated Studio preview](evidence/p17/operated-preview-2026-11-20.json)
records ground navigation and desktop and simulated-touch operation. For the
final in-game review, inspect the furnished floors, stairs/balcony, roof and
each material family's openings and damage in normal and thermal views.
Record explicit human approval of the identified in-game result under A6.

For A7, use the source-confirmed Studio test place. In Ground preview, choose
an outdoor zoom, then walk through the workshop entrance and through the upper
door from the exterior balcony. Rotate the view near walls and angle it toward
the ceiling. Check that the view moves closer indoors, tolerates pausing on a
threshold, and returns to the chosen distance on exit. Repeat after choosing a
near zoom outside. Manual zoom input still updates the player's preferred
distance. Check camera cleanup after changing roles or resetting the test. In a
normal active round, verify Ground aim follows the displayed camera and the
operator and spectator can take ownership. Record native camera distances and
avatar routes with their source and context.

The paired workloads used the same device and graphics settings at 1920×1080
with two actual clients, a 30-second warmup and a 300-second sample per scene.
The server scheduler p95 was 0.8 ms for each scene. Client render-frame p95 was
70.4–71.3 ms for the primitive scene and 70.4–71.0 ms for the detailed scene.
Both exceeded the [33.3 ms client budget](#objective-release-budgets). D67
waives the paired performance run and its threshold for P17. The measurements
are historical diagnostics. The idle diagnostic also measured roughly 15 FPS
on both clients at their ordinary viewport settings with the gameplay runtime
stopped. [Paired workload evidence](evidence/p17/native-performance-comparison-711c5a8.json), [idle diagnostic](evidence/p17/native-performance-idle-diagnostic.json).

## Verify and review the P16 Blender package

P16 is an asset-authoring increment outside Rojo's runtime mappings. Its
[acceptance record](evidence/p16/acceptance.md) binds commands, measurements,
failures, independent review and explicit human approval to exact source/export
hashes. Use the [source guide](../assets/blender/military-outpost/README.md) for
inspection and the full copyable rebuild/reopen/render sequence; the
[export guide](../assets/exports/military-outpost/README.md) documents consumers.
The candidate reconstructs the smaller Outpost from that package; its native acceptance remains separate from the P16 asset audits.

The full host gate now includes Python manifest and asset regression suites and
`python3 scripts/p16_audit.py`. Require nonzero discovery, all named cases
passing and no skips/failures. P16 expects seven asset-audit suites and 22 asset regression
cases; P17 adds its separate definition and rejection checks. The manifest suite
has ten cases. These counts are separate from the Luau unit/service totals;
source-bound outcomes remain in the acceptance records. The portable asset audit checks the actual exported
triangle data rather than accepting catalog opening fractions as proof:

| Named audit | Evidence it checks |
| --- | --- |
| `P16AssetInventory` | Required reference features, editable named components, furnished assembly, declared scale/site and reusable asset mapping |
| `P16DamageCatalog` | Six material/shape families, four appearances, material-matched fragment exports and retained legacy pivot/identity mapping |
| `P16PanelGeometry` | Rasterized actual mesh/proxy face coverage; Light retains pristine coverage with actual earned-scar faces on both sides, Heavy removes 45–55% of original blocking face, Total has no solid; proxies cannot fill visible holes |
| `P16Navigation` | Actual stair/floor/beam/balcony geometry at 185 route stations (98 internal / 87 external), with 1,850 support rays and 4×6×4-stud body checks across treads, landings, turns and the upper door; checked in OBJ, saved-source and clean-FBX geometry; actual Humanoid traversal remains P17 |
| `P16ExportAudit` | Finite triangulated OBJ data, UV/material/texture references, named exports and measured file/triangle/texture budgets |
| `P16BlenderReopen` | Checked-in clean Blender reopen and FBX-import reports match the source/export hashes and record no missing dependencies |
| `P16Dependencies` | Exact package file set, sizes and SHA-256 values against its lock |

The Python rejection tests use disposable copies to exercise invisible Heavy
colliders, invalid Light/Total solids, shifted pivots, invalid UV indices,
oversized fragments, missing baked textures and empty FBX files. Added
regressions restore the obstructing internal beam/full balcony deck and a
side obstruction missed by a center ray, and reject stale panel/kit import
proof, missing/changed render images, stale source receipts and changed review
scripts even after package hashes are refreshed. Light-scar regressions reject
Pristine geometry substituted for Light, renamed/permuted copies and unused
dark-material declarations; the audit requires actual measurable earned-scar
triangles on both faces.
`tests/tooling` separately checks manifest coverage, changed/missing hashes,
duplicate/noncanonical/escaping paths, backups and file-size limits. Refer to
the actual reports for discovered counts and precise cases; never combine
these with Luau counts or report them as Studio execution.

Portable CI checks committed geometry and hash-bound tool evidence; it does
**not** freshly open Blender. A new authoring revision additionally needs a
clean Blender 5.3.0 reopen, actual FBX imports of assembly/panels/all eight
reusable props, and saved-source exterior, both furnished-floor, cutaway/kit
and all six families' two-sided color/grayscale renders. Required proof binds
the saved `.blend`, review script, every FBX and all 29 review images to
their actual hashes; missing or stale proof is incomplete acceptance. `p16_blender_review.py` performs
those tool checks without saving changes back into the source. Run its audit
and render commands in separate fresh processes after final source save, then
refresh the package lock/manifest and run the full gate. Include
`--python-exit-code 1` on every Blender script command so a Python exception
returns a failed process status. Full `--render` writes its complete metadata
automatically. Once the identical tested art/review script is committed, the
optional `--render-manifest-only` step records HEAD from verified unchanged
receipts; it rejects stale/incomplete receipts and does not rerender or approve
changed source. Repeated render work
cannot turn an earlier failed source into passing evidence; retain failure
scope and identify the replacement source.

Human approval is an additional required P16 gate: the user must explicitly
approve the identified saved revision after inspecting exterior, both interiors
and material damage. Automation, reviewer preference and silence cannot satisfy
it. Blender geometry, grayscale previews and FBX round trips do not establish
Roblox Humanoid navigation, collision/query behavior, thermal occlusion,
fragment physics, replication/reset or runtime budgets. Those require P17's
actual imported candidate and its separate Studio/player evidence.

## Verify the P22 waiting lobby

Run the focused asset tests and collision recipe check from the repository root. The source tests compare the staged GLBs with the approved artwork. The compiled tests cover native model and texture bindings. [Import package guide](../assets/imports/lobby-interior/README.md)

```sh
python3 -m unittest discover -s tests/assets -p 'test_waiting_lobby_import.py' -v
python3 -m unittest discover -s tests/assets -p 'test_waiting_lobby_compiled.py' -v
python3 scripts/lobby_interior/prepare_collision.py --check
```

Run the ordinary Studio smoke suites in the separate local test document. The [lobby geometry specs](../tests/studio/specs-server/LobbyGeometry.spec.luau) mount the collision fixture in a disposable battlefield clone. Real engine raycasts and bounds queries cover anchor support, connected floors, threshold clearance, furnishing contact, and combat-disk separation. The spec also exercises the optional station exemption and active Ground containment. The [lobby art client spec](../tests/studio/specs-client/LobbyArt.spec.luau) checks the mounted mesh count and preloads the six portraits and television on each actual test client. Capture the server and client reports, then exercise the managed builds as follows.

For native art acceptance, start from a directly opened build or a local document with the exact native archive mounted and verified. Rojo live sync produced the expected instance count with empty `MeshId` and zero `MeshSize` in one test document. Check engine-visible IDs and sizes against the receipt in Edit mode before starting Play. [Native lobby receipt](evidence/p22/native-oil-assembly.json) · [P22 completion record](../plans/22-integrate-lobby.md#completion-record)

| Check | Procedure |
| --- | --- |
| A1 · Source reconstruction | Run `python3 scripts/verify.py` from a clean checkout. Record the source revision and the release and test artifact hashes. Inspect both built lobbies for one assembly, one bust and six source-bound canvases. Verify removal of `LobbyDeck`, `OperatorCanopy` and `OperatorBack`, absence of imported characters, and release exclusion of the test fixture. |
| A2 · Solo waiting | Start one client in a fresh **Play** session from the release-mapped local build. Confirm the player remains Waiting and spawns facing the bust. Walk through both doorways to the television and each portrait, then return to the hall. Exercise the default third-person camera on a tight turn around the theater entrance and around the aisle, bench and dais. Capture eye-height views of all three rooms and the six loaded canvases. Compare the whole images, upright orientation and readable details against the approved Blender views. |
| A3 · Protection | Check support and clearance at both authored anchors and the outer floor extent of both wings. Confirm every lobby part lies outside the 360-stud combat disk and the lobby has no registered damage panels. Verify free movement when Waiting, the assigned operator's anchored body after deployment and the Ground character's normal battlefield containment. |
| A4 · Replication and return | Use the current local test build with no named manual harness. Start **Server & Clients** with two actual clients. Collect the native server smoke report and both clients' fresh reports. Confirm both clients see the same bust, furnished rooms and six loaded paintings. Use **Start round now** on the test panel, observe one operator and one Ground player, and finish the round through the normal result and reset flow. Let both avatars return and walk, then repeat another round and reset. Compare assembly, art and floor counts and placement on both clients before deployment and after each reset. |

The one-client test mapping automatically enters map preview after smoke tests. The release-mapped solo session is the evidence for the default waiting behavior. An asset ID or reported preload status can help diagnose a missing surface. The passing observation for the paintings is the rendered image on each client. [P22 acceptance](../plans/22-integrate-lobby.md#acceptance-in-roblox-studio) · [Approved Blender views](../assets/blender/lobby-interior/README.md#tour-the-rooms)

## Run the Studio smoke suites

1. Build with the full verifier. Reuse the existing local test document; for initial setup, open `build/tests.rbxlx` separately from the game/cloud document or sync `test.project.json` into a separate test place. Preserve any unrelated open place and unsaved work.
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

5. Compare discovery with the selected source’s expected mapping and plan record. Require `discovered > 0`, `passed == discovered` and zero `failed`, `skipped` and `errors` in every fresh report. Reports identify `suite`, `environment = "Studio"`, fixture `seed = 1` and actual server `clientCount` or client `userId`. Aggregate labels remain `P01-server` and `P01-client`. Keep each report tied to the source, build and actual session.
6. Stop Play and start it again. Collect fresh reports and verify one `ReplicatedStorage.BootstrapStatus`, one local `PlayerGui.FoundationStatus` and one visible round HUD after startup. The round HUD hides the locally owned bootstrap panel after startup. Check for leftover `EntrypointStatus` or `EntrypointPanel` Instances. The baseline suites also exercise two explicit stop/start cycles of the bootstrap owner and status controller.
7. In the separate development document, use **Play** to confirm one client stays in the protected lobby with a HUD waiting for two players. Then use **Server & Clients** with two actual clients. Confirm automatic deployment, one C-130 operator, one Ground player and a shared Active phase. Stop when finished. The release bootstrap shows **Development**. The test build shows **Test** and opens solo preview or offers an explicit match start.

The P08 aggregate includes launcher geometry/reload lifecycle and owned-character removal alongside panel/appearance, persistent-credit, shelter-geometry and shared host cases. A passing one-client baseline establishes only those assertions, not P07's required two-client/reset or operated checks. Foundation checks cover bootstrap ownership and the anchored spawn raycast. [`Map.spec.luau`](../tests/studio/specs-server/Map.spec.luau) exercises actual `MapService` with disposable Instance fixtures:

- Assert actual loaded disk/spawn/roof transforms, then reject invalid disk dimensions, anchor identity/count and exterior/below-ground/floating/blocked anchors before restoring validity.
- Sample both launcher approaches every 0.5 stud with a 4×6×4-stud upright envelope and downward floor rays. This recorded envelope is a clearance fixture, not an avatar compatibility claim.
- Raycast permanent/breakable cover, all nine sheltered anchors and firing positions toward 64 perimeter aircraft samples.
- Correct exterior/below-threshold characters, preserve legal disk/station positions, and disconnect containment on stop.
- Rebuild twice after removed cover and transient debris; compare descendant counts, stable part names and poses, then exercise idempotent destruction.

The client suite covers camera input, material metadata, thermal-cosmetic behavior and Ground aim layout. The layout case constructs production RoundPanel and GroundCombatController in distinct ScreenGuis with measured origins/insets, then checks actual HUD rectangle separation/containment at desktop and phone sizes. Source `ef7826b` aligns the compact active-Ground touch header in shared GUI-content coordinates and tests client-only presentation state representing confirmed rifle/rocket feedback, text fit, native inventory/thumbstick reserves, centered aim, actionable controls and cleanup. The current layout fixture exercises the shared aircraft health bar at several damage levels and verifies that the old hit overlays are absent. These fixtures do not establish native touch input or prove actual CoreGui placement; inspect native inventory independently because Studio captures omit it. `PointerGui.spec.luau` calls the production default-input adapter against actual normal/full-bleed GUI buttons and an actual focused TextBox, verifies window-focus blocking and unchanged raw pointer coordinates, then releases focus and destroys its fixtures. `ClientTests.PointerGuiInset` records the observed inset. GroundAimGui checks rifle reticle/ray agreement and touch layout. Prior reports are source-specific; each new multiplayer session needs fresh reports. It does not prove round replication, no-respawn behavior or spectator cameras; the separate multiplayer harness below targets those. Prior P02 map/walking evidence is recorded in its plan. A new geometry candidate still needs engine checks; host success cannot satisfy them. The 4×6×4-stud clearance fixture and the operated R15 avatar are separate evidence, not proof for all avatar proportions or accessories.

### Preserve Edit state around a zero-client Run

Prefer ordinary Play/Stop and the supported SDK test modes. A direct low-level `RunService:Run()` may execute against the original Edit DataModel. The P06 zero-client negative probe left **both** Workspace report attributes and `ReplicatedStorage.BootstrapStatus` in Edit after stopping. A later bootstrap can then fail with “bootstrap already owned”; clearing only reports does not repair that contamination.

Before such a negative probe, snapshot the exact existence, class, attributes and owned contents of every runtime-created Editor Instance that the run can affect, including `BootstrapStatus` and any `EntrypointStatus`, plus Workspace `ServerTestReport`/`ServerTestStartup` attributes and their nil state. After collecting the intended timeout failure, stop only that owned run, confirm `RunService:IsRunning()` is false, and compare against the snapshot. Remove only confirmed probe-created stale objects; restore pre-existing objects/values exactly, including nil, and verify equality before the next session. Preserve unfamiliar objects and diagnose them instead of deleting by name. If complete restoration cannot be established, do not treat the next launch as clean.

The [P06 startup record](evidence/p06-ground-combat.md) distinguishes its contaminated cold start, expected zero-client timeout and later controlled three-client run. The [P07 record](../plans/07-destruction.md) records its separate stale-folder diagnosis and subsequent clean baseline. These outcomes must retain their actual source and launch conditions. Normal Play/Stop is the routine workflow; this low-level probe is not needed to play or validate destruction.

For the focused review, walk from the southern shelter along the teal west route and ochre east route to the gold center marker, inspect the orange boundary, and review exposed sight lines toward sampled perimeter positions. Record whether routes are understandable, cover is readable and movement feels usable, with viewport/graphics settings and actual observations. Watch the perimeter aircraft from the ground and inspect the inward thermal view in solo Operator preview or a real two-client round. The P08 candidate provides launcher pickup during a real active round; solo preview remains noncompetitive. The P06 implementation supplies active-round M-7 ground fire; gunship combat also requires an active round.

Do not manually invoke another TestEZ run while the automatic runners are active. Rebuild or sync after source changes and run a fresh Play session to avoid require-cache and stale-document ambiguity. Keep engine reports tied to the tested source tree and build hash; required engine gaps remain open even if the host gate passes.

## Verify P27 aim and mobile HUD

Run the host gate from the source under test and collect a passing server report and each client report from the synced local `PlayersVsC130Tests` place. The P27 cases in `GroundAimGui.spec.luau` exercise upright facing and compare the production Ground and round HUDs in common coordinates, including 568×320, 567×299 and an asymmetric cutout fixture. They measure text, control and reticle bounds through phase changes, including every countdown value from 20 through 0. [Studio smoke procedure](#run-the-studio-smoke-suites)

Use one operated match and its replays to collect the observations shared by the P27 criteria. Link each observation where it applies. Reuse a matching P24 report for the same candidate to cover arrival timing and cancellation. [P27 criteria and evidence](../plans/27-ground-aim-and-mobile-controls.md#acceptance) · [P24 arrival harness](#run-the-p24-aircraft-arrival-harness)

1. Begin with two actual clients. On desktop, move the mouse, strafe and check upright facing on the other client. Check yaw wrap, pitch limits and the crosshair above the avatar at ordinary third-person zoom. Match both the M-7 and launcher aim to the raised reticle and check cover rejection.
2. Open and close Settings and check cursor capture and movement. Use the mouse wheel outdoors, walk into and out of the Outpost workshop or upstairs command room, and verify that the previous zoom returns. Use a replay to switch roles, check independent operator pan and aim, and follow the lobby return and TV interaction.
3. Use a compact landscape phone layout and a wider one with a cutout. Record the actual safe area, text and control bounds, including chat, inventory and movement. Compare before-and-after Ground Scatter captures. Follow the lobby, Scatter, combat, results and spectator views and check the operator's blackout until the thermal frame is ready.
4. Operate the controls on a phone. On Ground, combine the stick, world drag and fire, then use a launcher pickup, switch weapons, reload and drop. On the operator, combine direction, aim and fire, then switch profiles and return to the lobby. Record the device and actual simultaneous gestures separately from simulator layout observations.

Record the source, Studio or Roblox client version, actual client count, device and viewport with the shared evidence. Restore the device preview and return the owned Studio session to Edit when finished.

## Verify the C-130 flight model

From a clean checkout of the candidate, run `python3 scripts/verify.py` to audit the committed aircraft package and rebuild both places. Open the editable master and run the Blender reopen and reimport audit. Check the recorded axes, size and muzzle locations against the loaded Roblox template. `Aircraft.spec.luau` checks one anchored flight assembly, the loaded muzzle positions and the native query behavior at solid and empty parts of the silhouette. [Blender commands and package contract](../assets/blender/c130/README.md)

Sync `test.project.json` to the confirmed local **PlayersVsC130Tests** document. Keep the release document separate. With Play stopped, use the Studio MCP Edit context to start two actual clients.

```luau
task.spawn(function()
    local report = game:GetService("StudioTestService")
        :ExecuteMultiplayerTestAsync(2, { kind = "P28" })
    workspace:SetAttribute("P28LastReport", game:GetService("HttpService"):JSONEncode(report))
end)
return "P28 multiplayer test started"
```

Allow about three minutes for the initial head start, a full 90-second orbit and replay. Read `workspace:GetAttribute("P28LastReport")` in Edit when the run ends. Preserve the `P28-multiplayer` report, the server smoke report and both client reports. Check the actual client and completed round counts, nonzero discovery and zero failures or skips. The scenario checks all four rotating hubs, both weapon zoom masks and firing origins, an authoritative rifle hit and miss, direct rocket sweeps to destruction, and a single correctly posed replica at full roster health in the replay.

Capture the first reveal and representative angles through the orbit from the Ground client. The fixture follows the aircraft from the avatar's eye position. If a tall accessory obscures the view, use a temporary upward offset for the capture and record it with the viewport. Check heading, propeller motion and camouflage readability at gameplay distance. Review the painted teeth and mouth on both sides of the nose from close enough to see how they follow the skin. Inspect the operator at both zooms for an unobstructed targeting view. Use the native report for firing, query and replay results. [P28 acceptance](../plans/28-c130-model.md#acceptance) · [P24 arrival and fire gating regression](#run-the-p24-aircraft-arrival-harness)

## Verify the depot launcher model

From a clean candidate checkout, run `python3 scripts/verify.py` to audit the launcher package, rebuild both places and check test isolation. Reopen the Blender master and reimport the portable GLB. The package guide gives the commands and the three attachment frames to compare against the native template. [Blender rebuild and audit](../assets/blender/rocket-launcher/README.md) · [P29 acceptance](../plans/29-rocket-launcher-model.md#acceptance)

Sync `test.project.json` on port 34872 to the confirmed local **PlayersVsC130Tests** document. With Play stopped, run the following through Studio MCP in its Edit context.

```luau
task.spawn(function()
    local report = game:GetService("StudioTestService")
        :ExecuteMultiplayerTestAsync(3, { kind = "P29", reviewSeconds = 0 })
    workspace:SetAttribute("P29LastReport", game:GetService("HttpService"):JSONEncode(report))
end)
return "P29 multiplayer test started"
```

Read `workspace:GetAttribute("P29LastReport")` in Edit after the run. For manual **Server & Clients**, set the local Edit `ServerStorage.DevelopmentSettings` attributes `ManualHarness` to `P29` and `P29ReviewSeconds` to a number from 0 to 25. Start **three** clients and read `workspace:GetAttribute("P29Report")` in the Server context before ending the session. Restore both attributes to their previous values in Edit.

Collect the `P29-depot-launcher` report and its server and three client smoke reports. Require all six cases, three actual clients and two completed rounds, with zero failures and skips. The cases exercise floor support at Radar, Hangar, Depot and Seedship, the held model seen by both Ground clients, firing, a handoff during cooldown, carrier death and teammate recovery. Replay checks one loaded launcher at each site and removal of prior held models and projectiles. Launch trace and damage assertions exercise the visual muzzle and server sweep separately. The `Launcher.spec.luau` smoke fixture also checks the presentation fallback when cover blocks the short cosmetic path.

For the rendered review, use a positive `reviewSeconds` or `P29ReviewSeconds` up to 25. `Workspace.P29ReviewStage` identifies pauses at all four pickup sites and the equipped Radar launcher. Use both desktop and simulated landscape phone views. Inspect floor contact and any clipping against surrounding scenery at each pickup, and body clipping, grip and proportion while equipped. In an operated match, fire into clear space and watch the effect start at the modeled nose, then compare the held and dropped views on both Ground clients. Save the source and build identifiers, Studio version, actual client count, viewports and observations with the report. Restore device simulation and return the local test place to Edit.

## Run the P24 aircraft arrival harness

From the source under test, run `python3 scripts/verify.py`. Sync `test.project.json` to the confirmed local **PlayersVsC130Tests** document on port 34872. With Play stopped, run the following in the connected Studio MCP Edit context.

```luau
task.spawn(function()
    local report = game:GetService("StudioTestService")
        :ExecuteMultiplayerTestAsync(2, { kind = "P24" })
    workspace:SetAttribute("P24LastReport", game:GetService("HttpService"):JSONEncode(report))
end)
return "P24 multiplayer test started"
```

Read `workspace:GetAttribute("P24LastReport")` in Edit when the run ends. For manual launch, set the `ManualHarness` attribute on `ServerStorage.DevelopmentSettings` to `P24` while in Edit, then start **Server & Clients** with **two** clients. Read `Workspace.P24MultiplayerReport` in the server context before ending the session. Restore the previous selector in Edit.

Expect `P24-multiplayer` with two actual initial clients, two completed round IDs, nine passing cases and zero failures or skips. Keep the server and both client smoke results with the report. Each complete round uses the full 20-second Scatter interval and checks the fresh ten-minute clock at reveal. The second round rotates roles. The third cancels arrival after a Ground death. The harness uses a short test intermission to reach those replays. P23 separately checks the full intermission.

The harness checks elapsed readiness time, matching client countdowns, opaque operator cover, inactive thermal and fire controls, and missing aircraft ray surfaces. It moves the real Ground avatar and tests launcher transfers through production remotes. It checks that early rifle, launcher and operator requests leave combat state untouched. After reveal it verifies the orbit start, the same Ground avatar and equipment, a direct rocket collision and a fresh operator shot. Controlled-time tests cover the boundary at 19.999 and 20 seconds, operator and last-Ground departure, late entry and reset authority. [Plan acceptance](../plans/24-ground-scatter-and-aircraft-arrival.md#acceptance)

For operated review, start two actual clients through ordinary **Server & Clients** and use **Start round now** from the Studio testing panel. Check both countdown views on desktop and under phone emulation. Move as Ground while reading the timer and check for overlap with chat and touch controls. On the operator client, confirm the black cover fills the viewport and that thermal controls only appear at arrival. Then confirm both players can use their normal combat controls. Record viewport and input mode with the observations, and restore the emulator and test place to their original settings.

## Run the P23 lobby and intermission harness

From the source under test, run `python3 scripts/verify.py` and sync `test.project.json` to the confirmed local `PlayersVsC130Tests` document on port 34872. With Play stopped, use the connected Studio MCP Edit context to launch three actual Studio clients. The harness starts the first deployment after the initial clients pass their smoke suites. It uses 85-second combat rounds and adds one actual late-arriving client during the first round. Automatic replay uses the production 120-second intermission from result commit.

```luau
task.spawn(function()
    local report = game:GetService("StudioTestService")
        :ExecuteMultiplayerTestAsync(3, { kind = "P23" })
    workspace:SetAttribute("P23LastReport", game:GetService("HttpService"):JSONEncode(report))
end)
return "P23 multiplayer test started"
```

Read `workspace:GetAttribute("P23LastReport")` in Edit after the session ends. The server also writes `P23MultiplayerReport` during the run. Expect the suite `P23-multiplayer`, three initial and four peak clients, two distinct completed round IDs, seven passing cases, and zero failures or skips. Capture the separate server smoke report and each actual client's report. Allow time for the full intermission and the second round and reset.

The harness checks assigned roles and shared HUD state, the late player's protected body, lobby return after Ground death, an out-of-range interaction, theater entry and exit, and rejected combat commands. It checks spectator target loss, restored desktop movement, the winner, a single theater prompt, the preserved lobby floor and avatar identities, and the deployment block before the deadline. The second round exercises operator reset, timeout and another map reset. Current launcher regression checks cover drop location when a carrier returns to the lobby. The deterministic `MatchService` integration suite covers the clock boundary, changing population, departures, aborts, and same-identity reconnect. The [P23 plan record](../plans/23-lobby-return-and-intermission.md#completion-record) tracks actual acceptance evidence.

For a focused theater regression, use `{ kind = "P23Theater" }` with the same three initial clients. Expect suite `P23-theater`, three cases and one completed round. It exercises replicated roles, actual Ground elimination, the native prompt and guidance visibility, entry and exit, lobby return and the first reset. The full `P23` selector provides the actual late join, complete intermission and second-round evidence. [P23 run evidence](evidence/p23/studio.md)

For operated review, use a fresh **Server & Clients** session with an operator and two Ground players. Eliminate one Ground player. Confirm arrival at the lobby with the normal camera. Walk past the TV without interacting, then walk up and press the prompt to follow the surviving Ground player. Confirm that the TV still shows its aerial image, and that **Exit spectating** restores movement to the same avatar. Exercise entry and exit on a touch layout. With a fourth initial client, try cycling between two living targets and removing the current target. End a round while a client is watching and check that the local lobby view resumes, the result stays readable while walking, and the theater floor still supports players through reset. The ordinary test panel uses short replay timing. Use a development build with production defaults or the P23 selector for the actual two-minute interval.

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

The test-only server harness starts `GameRuntime` with a two-player minimum and 30-second rounds. Three initial clients provide an operator and two Ground players. The harness waits for all three to pass their smoke suites, then explicitly starts the first deployment. `AddPlayers(1)` adds a fourth actual client during combat. Automatic replay uses a test-only ten-second wait from result commit, including the two-second Results phase. The client harness reports its actual attributes, round HUD and CameraSubject, sends production surrender requests and uses `LeaveTest` for real disconnects. The separate transport is excluded from release artifacts. [Server RoundHarness](../tests/studio/server/RoundHarness.luau) · [Client RoundHarness](../tests/studio/client/RoundHarness.luau)

The scenarios check replicated roles, phase, timer and HUD, late-join lobby return, Ground elimination and theater camera flow, and rejection of stale or ineligible combat commands. They also cover protected operator reset, elimination, timeout, actual departures, three map and character resets, and teardown while avatar loads drain. Each round perturbs cover and adds transient map content before checking pristine restoration. The [P03 record](../plans/03-rounds-and-roles.md) describes previously executed checks and their source.

For focused player review, use an ordinary three-client **Server & Clients** session without harness args. After the foundational suites, this starts a two-player-minimum loop with 60-second rounds, explicit start and three-second results. Observe both role views, the countdown, character reset, teammate camera, result and fresh lobby. The operator avatar remains at a protected station while its camera uses the inward thermal view. Check keys 1/2 and named buttons for coherent 30°/40° profiles, then confirm role loss restores the normal camera. Exercise active gunship and M-7 firing and cover separately; launcher gameplay is available in the P08 candidate during a real active round. Record readability and camera observations separately from automated pass counts. End the test session when finished.

## Run the P09 match outcome harness

> Historical pre-P18 procedure: this selector is archived and rejects before allocating runtime/listeners on the current candidate. Reproduce old evidence from its recorded Git revision. Use current P18 plus adapted P05 for rebalancing acceptance; preserve the report below as historical evidence.

Use the Rojo-synced local `tests.rbxlx` in Edit mode. Run one scenario per fresh session. The runner starts production `GameRuntime` after server TestEZ and waits in the lobby for every initial client to pass its smoke tests before beginning the scenario. It uses shortened rounds, actual clients and production remotes. Trusted fixture positions make impact and cover cases reproducible.

| Scenario | Initial clients | Expected cases | Coverage |
| --- | --- | --- | --- |
| `Outcomes` | 3 | 5 | Three back-to-back wins by destruction, elimination and timeout. Client results, friendly fire, delayed lethal rocket credit, Outpost/equipment/camera restoration, stale work, invalid deployment and teardown |
| `Departures` | 3 | 2 | Carrier departure, one launcher recovered by the teammate, operator forfeit and teardown |
| `LastGround` | 2 | 3 | Raw model removal leaves the client connected and ends the round by elimination. Last ground departure with operator present ends by departure. Terminal launcher cleanup and teardown |
| `Empty` | 2 | 2 | Same-step participant departures, empty server without winner and teardown |

From the confirmed Studio MCP Edit context, start a session and retain the return report while it runs:

```luau
local scenario, clients = "Outcomes", 3
local reportKey = "P09LastReport"
assert(not game:GetService("RunService"):IsRunning())
assert(workspace:GetAttribute(reportKey) == nil)
task.spawn(function()
    local report = game:GetService("StudioTestService"):ExecuteMultiplayerTestAsync(clients, {
        kind = "P09",
        scenario = scenario,
    })
    workspace:SetAttribute(reportKey, game:GetService("HttpService"):JSONEncode(report))
end)
return scenario .. " started"
```

In the Server DataModel, `Workspace.P09Stage` reports the current case. The SDK run returns the result to Edit after owned teardown. It includes the original server and per-client smoke reports in `smoke`, including clients that disconnected during the scenario. Preserve the `P09LastReport` JSON and clear that temporary attribute before the next scenario.

For native Studio **Server & Clients**, set the temporary `ManualHarness = "P09"` and `ManualP09Scenario = "Outcomes"` attributes on `ServerStorage.DevelopmentSettings` in the local Edit DataModel. Change the scenario name and client count using the table. Collect `Workspace.ManualP09Report` and the smoke reports before **End Session**. In Edit, restore both selector attributes to their prior values, normally nil. Native runs use server kicks for departures. SDK runs also use grouped server kicks for `Empty` to initiate simultaneous departures from one server callback. Individual SDK departures use `LeaveTest`.

Check each report's scenario, actual distinct client IDs, final client count, cases, observations and cleanup before recording a pass. Preserve failed launches and legitimate timing failures separately. The exact deadline and same-step damage ordering have an injected-clock native spherecast fixture in the ordinary server suite. Deterministic service tests cover same-identity reconnect authority under D59. [Native outcome fixture](../tests/studio/specs-server/MatchOutcome.spec.luau), [P09 evidence record](../plans/09-match-outcomes.md)

Review the experience in an ordinary multiplayer test session or observe the active harness clients through Results and into the lobby. Check winning-team and reason text, equipment restoration, and return from the operator or spectator camera. Record the actual viewport and any controlled fixture positions. Keep operated observations distinct from automated case totals.

## Run the player experience harness

> Historical pre-P18 procedure: this selector is archived and rejects before allocating runtime/listeners on the current candidate. Reproduce old evidence from its recorded Git revision. Use current P18 plus adapted P05 for rebalancing acceptance; preserve the report below as historical evidence.

Use the confirmed local `tests.rbxlx` document in Edit mode, synced through
Rojo to **PlayersVsC130Tests** on port **34872**. Confirm the source commit and
build before starting. The P10 harness needs four actual clients so one
eliminated Ground player can cycle between two living teammates while the
operator remains active. The fixture waits in the lobby for the clients'
ordinary TestEZ reports before deploying.

Start the SDK run asynchronously from the Studio Edit context.

```luau
local reportKey = "P10LastReport"
assert(not game:GetService("RunService"):IsRunning())
assert(game.PlaceId == 0 and game.GameId == 0)
assert(workspace:GetAttribute(reportKey) == nil)
task.spawn(function()
    local report = game:GetService("StudioTestService")
        :ExecuteMultiplayerTestAsync(4, { kind = "P10" })
    workspace:SetAttribute(reportKey, game:GetService("HttpService"):JSONEncode(report))
end)
return "P10 started"
```

During the run, `Workspace.P10Stage` names the current server case. The
SDK returns `P10LastReport` to Edit after session teardown. For the native
**Server & Clients** route, set `ManualHarness = "P10"` on the local Edit
document's `ServerStorage.DevelopmentSettings`, then start **4 clients**.
Read `Workspace.ManualP10Report` in the Server context before **End Session**.
Preserve reports, then clear the temporary SDK attribute or restore the
manual selector in Edit before subsequent sessions.

Require eight discovered and passing harness cases, four distinct initial
client IDs and a final count of four, clean [current-source smoke](#run-the-studio-smoke-suites),
and zero reported skips, failures
or errors. Record source and Studio version, observations, and cleanup. The
test-only client uses Studio virtual keyboard input for production actions
and samples real GUI and camera Instances. The harness checks the role HUD,
weapon zoom and readiness, known rejected reload, spectator selection and
authority, settings and warning text, result views and reset cleanup. Its
controlled warning and aircraft-destruction fixtures exercise presentation
from authoritative facts. The P09 harness separately exercises the actual
match-ending projectile and competitive result loop. [Client harness](../tests/studio/client/PlayerExperienceHarness.luau), [server harness](../tests/studio/server/PlayerExperienceHarness.luau), [P10 plan](../plans/10-player-experience.md)

Use live desktop Studio viewports of **1280×720** and **1920×1080** for layout
evidence. In a rendering Client DataModel, select the **HD 720** or
**HD 1080** simulator preset with **Actual Resolution** scaling. Verify the
client's `workspace.CurrentCamera.ViewportSize`, since the simulator setting
and the rendered viewport can differ. Restore default simulation when done.
Inspect readable, bounded HUD rows, weapon controls and the Settings menu.
Use a live round to compare aircraft health and fill on both clients after
server-confirmed hits. Check the green full bar, red depleted bar and readable
numeric or destroyed state. Fire both gunship weapons, the M-7 and the launcher.
Record the loaded, playing positional cues and the difference between server
emission and client playback time. Check the exhaust trail, warning text with
effects off, and cleanup after Results and replay. Keep audio telemetry and
listening observations separate. [Revision evidence](evidence/p10/combat-presentation-revision.json)

## Run P19 weapon impact checks

Build and sync the selected P19 source into the confirmed local
`PlayersVsC130Tests` document on port 34872. Stop Play before syncing. Use
the [source parity procedure](#run-the-p18-rebalancing-harness) and collect
fresh server and client smoke in each session. Run the full host gate, the
[two-client P05 regression](#run-the-p05-gunship-combat-harness) and the
[P19 acceptance criteria](../plans/19-weapon-impacts.md#acceptance-criteria).
The native smoke includes the server's registered-solid distance and cover
fixture and the client's impact admission and cleanup fixture. The server
fixture supplies a contact and the client fixture injects cues. The active
round checks below exercise projectile flight and actual delivery. On P19,
the P05 battlefield matrix fires at four empty-ground surfaces (desert sand, forest
floor, depot pavement and the red basin's Mud terrain), once beside each
registered building, and once directly at an elevated roof panel. It sends
production fire requests and checks both clients' impact location and a
representative opened panel at each building. The harness supplies aim and
avatar placement. A Terrain-only ray classifies the authored ground material
independently of the shot's collision surface. Where the backup `GroundDisk`
and Terrain coincide, either can register the real ground contact. Keep the
recorded surface and authored Terrain material separate when reading the
report.

The same case places the actual Ground avatar in the open more than 18 studs
and at most 25 studs from the confirmed contact. It repeats the shot with
the avatar behind a temporary solid shield within that band, then in the open
beyond 25 studs. The fixture temporarily raises the avatar's health and
disables its stock regeneration script if present so a 100-point hit can be
measured without ending the round. It records the confirmed
contact-to-avatar distance, cover ray and health before and after each shot.
Expect a 100-point loss only for the exposed, in-range avatar. Review normal
controls and cover in a separate operated session.

- **A2 battlefield coverage.** Use normal targeting and fire controls in **Server & Clients** to check an empty-ground strike and a ground strike beside a building. Compare the contact and opening from both roles. Use the staged P05 field matrix for the exposed, shielded and out-of-range controls, and for direct wall and roof checks. Check real ray clearance after the flush, protected supports and lobby, the fragment cap and pristine reset.
- **A3 flight and cues.** Observe 105mm and repeated 30mm contact effects on terrain and walls and rockets striking terrain, buildings and the aircraft. Exercise a rocket that expires without a collision. Check one burst per valid contact, smoke onset and fade, the direct aircraft damage for the tested source, unchanged 30mm earned credit, and rejection of duplicate, delayed and previous-round cues. The P19 source awards 100 damage and the P25 source awards 150. Check the fixture's cleanup result and observe the live effects clear on replay.
- **A4 visual and listening review.** Inspect Ground and the 30° and 40° thermal views in Studio. Check the reticle, white targets, real openings, readable warnings and impact placement while smoke clears. Compare Full, Reduced and Off. Listen in the local session for the M-7, launcher, 30mm and howitzer and use the automated timing tests for nearby and distant playback. Check that Off clears visible effects and keeps warnings readable. Written observations are sufficient. The existing clips and matched audio are optional aids. The separate mute and fallback checks are deferred.
- **A5 workload and reset.** Use the profile below on baseline and candidate. Observe normal and reduced effects and five resets, recording active transients at each fresh lobby and whether the pools remain bounded.

### Profile the current battlefield

`P19Profile` adapts the P11 workload for the P18 map and four launcher sites.
It fires against real panels where available and falls back to terrain to
keep impact load after openings exhaust the preferred targets. Start a fresh
session for each build. Use the same profiling fixtures on the pre-P19
gameplay baseline and the candidate, and record both source identities and
test artifacts. Keep the Studio version, both actual clients, hardware and
workload settings matched. Use an actual **1920×1080** viewport with graphics
quality **8** in each playing client. The harness allows 75 seconds for both
clients to reach these settings before measuring. Log the reported viewport/quality and
restore temporary simulator, graphics and harness settings afterward.

From the confirmed local Edit context, launch the SDK session with
`StudioTestService:ExecuteMultiplayerTestAsync(2, { kind = "P19Profile" })`
inside a detached task and preserve the returned report. For native
**Server & Clients**, set the temporary
`ServerStorage.DevelopmentSettings.ManualHarness = "P19Profile"` attribute
in Edit and choose two clients. Check `Workspace.P19ProfileStage` on the
server. Preserve `Workspace.ManualP19ProfileReport` before ending a native
session, then restore the original selector in Edit. Save startup and smoke
reports for failed or incomplete attempts.

Review the report's accepted weapon traffic, wall-opening and fragment peaks,
elapsed time, frame sample counts and final resource counts. Require server
scheduler p95 at or below 16.7 ms. The harness still evaluates both clients
against 33.3 ms p95 and reports any miss. D99 retains the local timings as
diagnostics and carries the client budget to the [future release workload](release.md#measure-the-live-10-player-workload).
The client probe measures on-screen contacts within 400 studs
from receipt to the first `PreRender` frame with the matching burst ready.
For Full Effects, require at least 95% of sampled contacts to be ready within
two frames. Count missing samples beyond the target. Preserve first-frame,
second-frame, later and missing samples along with peak burst and trail
counts. The pre-P19 gameplay baseline has no contact stream, so report client
impact readiness as unavailable on that build. Review visible impacts in
Studio under A4. A passing profile covers its own load and cleanup.
Keep the five-reset and low-effects checks with the separate A5 evidence.
[Server profile harness](../tests/studio/server/PerformanceHarness.luau) · [Client profile harness](../tests/studio/client/PerformanceHarness.luau)

### Run P19 impact replay

In the same local Edit document, start a fresh SDK session with
`StudioTestService:ExecuteMultiplayerTestAsync(2, { kind = "P19Profile", scenario = "Replay" })`.
This test-only scenario reports as `P19Replay`. It fires a howitzer and a
rocket in each of five active rounds. The first four rockets hit the ground.
The fifth expires in empty air, with no server-reported world impact.
Each round is ended by the fixture after the panel opens. The report tracks
both clients' opened and restored panel and verifies a fresh battlefield and
drained local and server resources after each reset. Retain both actual
client smoke reports and the replay report. Use the separate Profile scenario
for frame timing and the operated review for Reduced and Off coverage.

For native **Server & Clients**, set `ManualHarness = "P19Profile"` and
`ManualP19Scenario = "Replay"` on `ServerStorage.DevelopmentSettings` in the
local Edit document. Start two clients and collect
`Workspace.ManualP19ReplayReport` in the Server context. End the session and
restore the original selector attributes in Edit.

For a same-session follow-up after manual P05, preserve `ManualP05Report` and
confirm that the P05 runtime has shut down. Keep both clients connected and
the private native test session open. In each actual Client context, start
the committed `PerformanceHarness.profile()` listener from
`Players.LocalPlayer.PlayerScripts.ClientTests`. Start the committed Replay
fixture in the Server context.

```luau
local harness = require(game:GetService("ServerScriptService").ServerTests.PerformanceHarness)
task.spawn(harness.impactReplay, function(report)
    workspace:SetAttribute("ManualP19ReplayReport", game:GetService("HttpService"):JSONEncode(report))
end)
```

Collect the Replay report separately before ending the session. Label it as
same-session evidence and retain both actual client IDs.

## Run the P11 performance harness

> Historical pre-P18 procedure: this selector is archived and rejects before allocating runtime/listeners on the current candidate. Reproduce old evidence from its recorded Git revision. Use current P18 plus adapted P05 for rebalancing acceptance; preserve the report below as historical evidence.

From the selected candidate commit, build with the full verifier and sync
`test.project.json` to the local **PlayersVsC130Tests** document on port
**34872**. Confirm the candidate source commit or tree, the installed Outpost
templates and the local document through Studio MCP. Leave the document in
Edit before starting each scenario. Use two actual clients for the reference
runs. The harness accepts 2–8 and checks the connected count. Record initial
client IDs and the final count from each report.

### Start a scenario and collect evidence

Use the Studio Edit/plugin context for the SDK route. Change `scenario` to
`Replay`, `Latency`, `Profile` or `Soak`. The SDK call yields until the
test ends. The detached task keeps Edit available for the result.

```luau
local scenario, clients = "Replay", 2
local reportKey, errorKey = "P11LastReport", "P11LastError"
assert(not game:GetService("RunService"):IsRunning())
assert(game.PlaceId == 0 and game.GameId == 0)
assert(workspace:GetAttribute(reportKey) == nil and workspace:GetAttribute(errorKey) == nil)

task.spawn(function()
    local sdk = game:GetService("StudioTestService")
    local ok, result = pcall(function()
        return sdk:ExecuteMultiplayerTestAsync(clients, {
            kind = "P11",
            scenario = scenario,
            clients = clients,
        })
    end)
    if ok then
        workspace:SetAttribute(reportKey, game:GetService("HttpService"):JSONEncode(result))
    else
        workspace:SetAttribute(errorKey, tostring(result))
    end
end)
```

For native **Server & Clients**, record the original attribute values on
`ServerStorage.DevelopmentSettings` in the local Edit document. Set
`ManualHarness` to the string `P11`, `ManualP11Scenario` to the scenario
name and `ManualP11Clients` to the number `2`. Start **Server & Clients**
with the same client count. Collect `workspace.ManualP11Report` from the
Server context before using **End Session**. Restore the original selector
values in Edit, including absent attributes.

Watch `workspace.P11Stage` in the running Server context. On SDK return,
collect `P11LastReport` or `P11LastError` in Edit and clear the temporary
attribute after capture. A startup timeout or missing roster may stop the
test before a P11 report exists. Collect `workspace.ServerTestStartup`,
the smoke reports that arrived, and Studio Output for those attempts.

| Scenario | Passing cases | Required observations |
| --- | ---: | --- |
| Replay | 8 | Five accelerated rounds. Repeated requests preserve one launcher, one rifle damage award and one heavy panel credit per accepted shot. Each round produces a fresh map and fresh mobile lobby bodies before comparing live owned resources with the baseline. |
| Latency | 5 | Seven real echoes per client. Each client's median falls within 100–200 ms around the 150 ms target. Both clients observe the correct aircraft health, launcher owner, weapon and result at the replay checkpoints. |
| Profile | 4 | Five loaded minutes, both gunship weapons, accepted M-7 and rocket fire, opened Outpost panels and live imported fragments. Both client render p95 values are ≤33.3 ms and server scheduler p95 is ≤16.7 ms. |
| Soak | 4 | One warmup round and ten 180-second loaded windows. Allow at least 33 loaded minutes including warmup, plus setup, results and resets. Each server and client process supplies 11 equivalent post-reset memory samples, with ≤10% endpoint growth and a series that levels off or drops at least once. |

Require the full case count, every case passing, zero failures/skips, 192
clean server smoke cases and 13 clean smoke cases from each actual client.
Check the report's `seed = 11021`, mode and cleanup. Record the source,
Studio version, final resource counts and any missing diagnostics. Under
`observations`, read `actualRoundTripMs` for latency, `profile` for frame
and load measures, and `soakSamplesMb` and `retainedMemory` for soak.
The queue limits are 32 accepted rifle intents and 32 pending launcher requests. Structural
processing allows 512 queued outcomes and 513 barriers, and live debris is
capped at 48. Review the peaks and effect counts alongside each workload.
[P11 server harness](../tests/studio/server/PerformanceHarness.luau),
[client harness](../tests/studio/client/PerformanceHarness.luau)

### Configure profiling and latency runs

The [reference machine](../plans/11-balance-and-performance.md#local-performance-reference)
is an Apple M1 Pro MacBook Pro with 16 GiB RAM, macOS 26.6.2 and Studio
`0.748.0.7481526`. For Profile, set both rendering clients to **HD 1080**
with **Actual Resolution** and verify graphics quality **8 of 10**.
Verify `CurrentCamera.ViewportSize = Vector2.new(1920, 1080)` and
`SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel8` on each
client. The harness waits up to 40 seconds for the two clients to reach
those settings after smoke readiness. Keep viewport, quality and background
load stable during sample collection. Record focus or any environment changes
that affect rendering. Restore the previous simulator and graphics settings
after the run.

Record p95, elapsed seconds, sample counts and invalid or overflow counts
for each role's `PreRender` frames and the server's `Stats.HeartbeatTime`
samples. The server's observed Heartbeat interval is reported separately.
The fixed histograms round p95 upward to 0.1 ms. Each budget requires at
least 3,000 valid samples with zero invalid samples. For Soak, record each
process's `Stats:GetTotalMemoryUsageMb()` after warmup and after each later
reset. Keep those engine MB readings with the separately counted game-owned
resources at the same Lobby checkpoints. [Roblox Stats reference](https://create.roblox.com/docs/reference/engine/classes/Stats)

Use a separate fresh session for Latency. Save both directions' original
simulator values. Start with 65 ms added inbound and outbound, zero jitter
and zero loss, then confirm the applied values on each actual client. Compare
the harness echo samples and their medians with live client ping measurements.
Record both measurements and all six applied delay, jitter and loss settings.
Inspect the full convergence case even if the ping is in range. Restore and
verify all six original simulator values after the run, including on a failed
launch. Use zero-added-delay settings for the reference Replay, Profile and
Soak. [Roblox Network Simulator](https://create.roblox.com/docs/studio/network-simulator)

### Review multiplayer balance

In a separate ordinary local multiplayer session, record time to reach and
pick up the launcher from each painted route, launcher recovery between
teammates, and time to destroy the aircraft. Use both gunship weapons and
compare pan reach at both zooms. Observe counterfire from covered and upper
floor positions, mixed-weapon damage, actual Outpost openings and fragment
load. Record how the roles stay engaged through each round. Local balance
observations and the instrumented workloads supplement the prior engine
regression suites. The future release checklist retains actual Roblox client sessions at 6 and 10
players. [P11 plan](../plans/11-balance-and-performance.md),
[Legacy P12 handoff record](../plans/12-mvp-release.md)

## Run the P05 gunship combat harness

P05 is adapted for the current P18 source and remains a required supplement to the three-client rebalancing suite. Its actual client input/remotes and swept projectile paths include one real M102 impact opening a pristine registered upper-story panel to Total on the server and both clients. Earlier execution reports below remain tied to their recorded source; collect a fresh current report.

Use the same confirmed `tests.rbxlx` Edit document synced to `PlayersVsC130Tests`, and check the candidate source identity before starting. In Edit/plugin context, run the two-client harness without blocking Studio:

```luau
task.spawn(function()
    local report = game:GetService("StudioTestService")
        :ExecuteMultiplayerTestAsync(2, { kind = "P05" })
    workspace:SetAttribute("P05LastReport", game:GetService("HttpService"):JSONEncode(report))
end)
return "P05 gunship test started"
```

After the self-ending session returns to Edit, inspect `workspace:GetAttribute("P05LastReport")`. Require two actual clients and all discovered cases passing with zero failures or skips. Expect nine cases on P19 and P25, or eight on the earlier P18 revision. P25 waits for the current howitzer reload deadline in the repeated-shot cases. A launch timeout, missing result, early exit or zero discovered cases is incomplete evidence. Preserve the actual report, source commit/tree, Studio environment and separate server/client baseline reports. The server baseline may complete while clients are still joining. The harness sends production fire intent through a test-only transport and disposable fixtures. It checks malformed, stale and flood rejection, actual swept cover, collisionless flight, weapon-switch reload, replicated combat observations, terminal and next-round cleanup, and terrain and upper-floor geometry. [P05 acceptance record](../plans/05-gunship-combat.md)

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
3. Before ending the session, read and preserve `workspace:GetAttribute("ManualP05Invocation")` and `workspace:GetAttribute("ManualP05Report")` from the actual **Server** DataModel, together with the candidate commit/tree, mode, actual client count and smoke reports. The manual report is not the Edit document's SDK `P05LastReport`. Require two actual clients, all P05 cases and zero failures or skips. Expect nine cases on P19 and eight on integrated P18. A missing report or early error remains incomplete.
4. After preserving the report, end the owned manual session from the actual **Server** context:

   ```luau
   game:GetService("StudioTestService"):EndTest({ reason = "P05 manual cleanup after report collection" })
   ```

   Confirm the original document returns to Edit. In that original **Edit** document, clear the temporary `ServerStorage.DevelopmentSettings.ManualHarness` attribute and verify it is nil. Do not carry it into ordinary testing or a cloud/release place. This fallback is available on the current P06 source; the actual P05 regression result must be recorded separately and is not claimed by the route's existence.

The harness does not substitute for operating native desktop and touch controls. In an ordinary real two-client round, fire each weapon while aiming and panning, switch away and back during reload, and inspect warnings, impacts, exposed/covered targets, both thermal views and mobile layout. Record actual device, view and observed behavior, then stop the owned session. Do not infer successful replication or playability from a screenshot.

## Run the P06 ground-combat harness

> Historical pre-P18 procedure: this selector is archived and rejects before allocating runtime/listeners on the current candidate. Reproduce old evidence from its recorded Git revision. Use current P18 plus adapted P05 for rebalancing acceptance; preserve the report below as historical evidence.

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

> Historical pre-P18 procedure: this selector is archived and rejects before allocating runtime/listeners on the current candidate. Reproduce old evidence from its recorded Git revision. Use current P18 plus adapted P05 for rebalancing acceptance; preserve the report below as historical evidence.

Use the existing confirmed local `tests.rbxlx` Edit document, fully synced from updated `main` through `test.project.json` on port 34872. Verify mapped source signatures and the current smoke counts before attributing results to the candidate. P08 needs **three actual clients**: one operator and two ground players. Solo smoke, fake roster records and an SDK request for three do not establish that population.

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

The native `ef7826b` P08 run is a preserved failure: server smoke passed 156 cases and each of three actual clients passed seven, but only four gameplay cases passed before the death/in-flight case timed out waiting for aircraft health 200. A duplicate Harness completion failure and passing teardown produced **seven discovered / five passed / two failed**; that is not full acceptance. The [failed report](evidence/p08/native-ef7826b-failed.json) and [console](evidence/p08/native-ef7826b-console.txt) retain the original result.

Test-only correction `07e77ea` prepares moving-aircraft lead through a lazy provider **after** client readiness and the identity-owned reload wait at all three direct-fire sites. Previously the lead was evaluated before that wait and could be seconds stale. Health assertions are unchanged. The death scenario also requires a genuine pre-death flight and an active living teammate afterward, and checks that nonterminal death retains an unfinished flight. Production/UI remains `ef7826b`. The corrected test source passes the primary full host gate at 55 unit/65 integration and all checks, and its fresh native run now passes all eleven cases. The earlier failure remains historical.

Preserve the report's JSON-safe `traces` and `droppedTraceRecords` alongside case results. The test observer retains at most 192 records, retiring the oldest and counting losses, before runtime cleanup removes live state. Records include case/stage, server/wall time, launcher readiness/resources, health/life, head/aircraft/target positions, bounded live rocket positions, LastShot/LastImpact and dispatch/derived acceptance timing. Use prepared target age and pre-/post-death flight observations to distinguish stale fixture aim from rejected fire, obstruction, canceled flight or missed impact. Diagnostics neither award hits nor relax assertions and remain available after owned cleanup.

The final [native `07e77ea` report](evidence/p08/native-07e77ea-pass.json) passes **11/11**, zero failures/skips, against unchanged production/UI `ef7826b`. It starts with three actual clients, peaks at three and ends with two after intentional carrier Kick. Fresh server smoke passes 156/156 and each of UserIds −3/−2/−1 passes 7/7. Races, rejection, misses/transfers/reload, death/in-flight damage, raw character reset, next-round stale intent, direct/mixed destruction, disconnect recovery and teardown all pass. D59 subsequently removed unsupported actual same-identity reconnect from acceptance. It remains unverified, while the eleven passing cases satisfy the revised Studio gate.

The [full report](evidence/p08/native-07e77ea-full.json) retains 150 trace records with zero dropped; accepted moving aim age ranges 0.033848–0.283879 seconds. Shot `rocket:1:2` is live before death, remains while its shooter is Eliminated, the launcher Available and the round Active, then records matching `aircraftHit=true` and health 200. Pristine damage is 300→200→100→0/Results; real rifle damage reaches 195 before rockets take 95→0/Results. Cleanup returns only the original Edit document, stopped with nil manual selector, no BootstrapStatus and the simulator at default LandscapeLeft. These observations belong to this source/run and do not relabel earlier failures as passes.

On runtime/test source `75b1e88`, the independent full host gate passes 55 unit/65 integration; ordinary solo Play passes 156 server/seven client; separate two-actual-client SDK P06, P05 and P14 regressions pass 10/10, 8/8 and 6/6 respectively, including both 90-second P14 orbits. A corrected ordinary native three-client session also passes 156 server/seven cases per actual client. That ordinary session verifies native D walking, both authored approaches through actual Humanoid movement, raced native E pickup producing one carrier, native 1/M-7 and 2/launcher selection, and separation from the actual inventory. These are bounded positive observations, not an eleven-case P08 harness pass. That earlier three-client capture is retained in evidence. The README capture at that P08 delivery checkpoint was from an ordinary two-client SDK session on `ef7826b`, showing one Ground carrier after natural walking with the default camera. The test-only panel was hidden for review and restored afterward. The capture tool omits native CoreGui, whose hotbar bounds were separately measured. See the [P08 evidence](evidence/p08-launcher.md) for the exact source-bound reports, operated fire/drop/reload/touch/recovery observations and the D59 acceptance revision.

The earlier phone correction `0cd6545` passed host and smoke checks but failed actual simulator review: GroundCombatHUD and RoundHUD had different content origins, allowing header overlap despite the shared-coordinate fixture. Preserve that failure. The client-only correction `ef7826b` aligns measured ScreenGui origins/insets, compacts the active Ground touch RoundPanel header and exercises both production controllers together with confirmed feedback. Server authority, input/ray rules and desktop/operator behavior remain unchanged. Fresh `ef7826b` execution passes 156 server/seven client in solo Play and 156 server/seven per actual client in an ordinary two-client SDK session. Actual iPhone-simulator 750×381 and 568×320 views with a 58-pixel inset pass the layout observer: zero owned/native/top-RoundHUD/reticle overlaps, zero controls outside CoreGui-safe bounds, fitting status TextBounds and zero-pixel drawn-reticle error. A stricter actual 567×299 view also passes. At exact 568×320, native touch M-7/ROCKET/DROP/PICK UP/FIRE/RELOAD also works: rocket fire/drop/re-pick preserves the exact reload deadline and denies early fire, while M-7 reload changes 25→30 rounds and reserve 120→115. HIT readability is a separately disclosed client-only GroundShot presentation fixture: inline text fits, floating text stays hidden and server aircraft health stays 300. Two real M-7 aim attempts using QA-controlled cameras missed; they are not actual damage proof. The final eleven-case native P08 run passes on test source `07e77ea`; D59 excludes unsupported actual same-identity reconnect from acceptance. Historical `0cd6545` positives do not establish this correction.

The server/client `LauncherHarness` uses production GameRuntime and real remote intent. It covers M-7-only initial loadouts and three available landmark launchers; invalid/wrong-role/stale/flood/implausible-movement rejection; raced acquisition of one launcher, independent pickups by two carriers and rejection of a second weapon for the same carrier; miss/drop/selection/transfer with unchanged reload; carrier death with an already-flying direct rocket; explicit character removal while reloading and teammate recovery without restored life/equipment; pristine reset and stale intent; three real rockets yielding 200, 100 and zero aircraft health; earlier real rifle damage followed by two lethal remaining rockets; actual carrier disconnect; and drained idempotent teardown. Trusted fixture poses isolate these rules and collision checks; they are not operated route traversal or native input evidence.

**D59 limits Studio acceptance to supported operations.** Same-identity reconnect is excluded: current helpers add a different test identity. Runtime MatchService tombstone/rejoin rules remain covered by deterministic service tests. The historical report's `actualReconnectVerified=false` and `requiredUnverified` remain unchanged; subsequent reports list it in informational `unsupportedChecks` with no required reconnect gap. Supported late joins and three-client sessions stay required. Supported checks temporarily blocked by access or startup failures remain incomplete. Future 6/10-player Roblox-client release sessions retain their separate environment and remain unverified at legacy P12 closeout. Do not relabel service tests as network reconnect evidence.

If the SDK cannot connect three clients, prepare the native fallback once, with Play stopped in the same test document:

```luau
local settings = game:GetService("ServerStorage"):FindFirstChild("DevelopmentSettings")
assert(settings and settings:IsA("ModuleScript"), "test settings unavailable")
assert(settings:GetAttribute("ManualHarness") == nil, "selector already in use")
settings:SetAttribute("ManualHarness", "P08")
return "P08 native three-client selector ready"
```

Choose Studio **Server & Clients**, set **3 clients**, and start the session. Capture actual Server workspace `ManualP08Invocation`, `ManualP08Report` and `P08MultiplayerReport`, plus each client's fresh smoke report. Native departure uses a server kick; SDK departure uses the client's LeaveTest. Preserve the mode and method. After report collection, end only the owned simulation from its actual Server context with `StudioTestService:EndTest({reason = "P08 manual cleanup after report collection"})`. Confirm the original document is back in Edit, then clear `ServerStorage.DevelopmentSettings.ManualHarness` and verify nil. This temporary server-only selector is absent from Git defaults and release artifacts. Do not restart the runner on top of an existing runtime or launch extra Studio processes to refresh source.

Separately walk the circuit from each bunker exit and operate all four landmark approaches, including the Seedship interior, E/PICK UP, native tool selection, M-7/rocket firing and reload, G/DROP and teammate recovery in an ordinary real round. Check ground movement and mouse aim; use a simulator/device for touch pickup, M-7/ROCKET/DROP and FIRE while aiming. Review desktop/phone status readability, real rocket travel/cover, ownership agreement and shared aircraft-health feedback without a fixed remaining-hit promise. Keep captured gameplay in the linked evidence and disclose any controlled fixture poses or cameras. Rerun affected P05/P06/P14 and character/lifecycle scenarios after shared authority or cleanup changes; preserve each result separately. The [P08 plan](../plans/08-rocket-launcher.md) and [evidence](evidence/p08-launcher.md) own actual results and remaining limitations.

## Run the P07 destruction harness

> Historical pre-P18 procedure: this selector is archived and rejects before allocating runtime/listeners on the current candidate. Reproduce old evidence from its recorded Git revision. Use current P18 plus adapted P05 for rebalancing acceptance; preserve the report below as historical evidence.

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

Geometry and world checks on the integrated P17 candidate must cover all **188 registered panels**: 112 in Foundry/Warehouse/Outpost (26 in Outpost) plus 76 starting-shelter panels (42 roof, 34 wall). Historical primitive-source reports cover 187 panels and cannot satisfy that updated count. Confirm that the seven old shelter colliders are replaced without hidden duplicate solids and that the original union, entrances, anchors, and pristine spawn protection remain. The separate waiting lobby stays protected outside the battlefield. Verify Pristine/Light/Heavy/Total in both normal and grayscale views. Cosmetic face scars cannot collide, enter weapon/thermal queries or identify as structural hits; Heavy keeps its 45–55% opening and dark style at zero stage progress. Static floors, stairs and frames stay usable.

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

> Historical pre-P18 procedure: this selector is archived and rejects before allocating runtime/listeners on the current candidate. Reproduce old evidence from its recorded Git revision. Use current P18 plus adapted P05 for rebalancing acceptance; preserve the report below as historical evidence.

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

Separately operate both zooms over a full orbit and inspect exposed/covered thermal targets on slopes and upper floors. Verify layout at actual 1280×720 and 1920×1080 viewports, recording simulator/graphics settings and restoring prior state. Record directional responsiveness, off-axis movement, motion comfort, zoom-preserved orbit-local angle and recenter. At the upper/lower/side pan limits, verify that the level edge is visible near the outer quarter of each centerline at wide zoom, and inspect for sky and near-vertical motion. Confirm that the visual backdrop cannot collide or be hit by rays and is removed on role loss. Keep any current gameplay captures in linked evidence; preserve the root README’s selected P16 Blender image. The earlier integrated P14 source’s P14/P04 and HumanTestMultiplayer suites pass; rendered cover, desktop/mobile full orbits at both zooms, both desktop viewport layouts, and simultaneous mobile arrows were reviewed. Numerical fixture or property checks alone do not establish the rendered/operated review.

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

For focused review, operate the actual avatar along all three landmark routes, onto terrain and into all upper floors; inspect building scale, room/stair clearance, ground/aircraft cover readability and travel time. Record viewport/graphics settings and capture the actual candidate. Fixture clearance, Humanoid automation and subjective operated review are distinct evidence. These map suites do not establish panning, firing or physical panel damage. The separate P14 procedure exercises the new bounded view/projection contract.

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
| Unit | Rules: transitions, timers, damage, ammo, circular orbit math, weapon-linked zoom, per-site launcher ownership and one weapon per player | Standalone Luau under Lune; deterministic clock/random inputs |
| Service integration | Real services connected through fakes for transport, clock and world queries | Lune where engine-independent; TestEZ in Studio for Instance-dependent adapters |
| Engine integration | Raycast/cover, Humanoid death, collision swaps, Instances, camera state | TestEZ in the test place, with assertions and a structured pass/fail summary |
| Multiplayer | Replication, roles, input rejection, late joins, visibility, cleanup | Two distinct client contexts for gameplay claims; P01 only requires its one-client smoke; future actual 6/10 capacity sessions remain unverified |
| Experience | Readability, camera feel, sound, balance, fairness | Focused operated playtest and captured observations; supplements automated evidence |

Unit tests use observable invariants and boundary examples, not implementation-specific call order unless order is the contract. Integration tests use real services and fake boundaries, not fake services calling each other. Engine checks assert real world state. A client screenshot cannot establish server authority.

## Determinism and fixtures

- Inject the clock and seed; use a tiny map fixture with one exposed target, one solid wall, one breakable wall, a clear projectile path, circular map bounds and one launcher anchor.
- Include minimum/maximum population, a two-client development fixture, and seeded 10-player roster data. Ten fake player records do not count as ten network clients.
- Include source/target inside and outside every boundary, exact deadlines, duplicate messages, two launcher claims in one step, carrier death during reload, simultaneous aircraft/last-player destruction, disconnect/reconnect, and a stale projectile after reset.
- Every suite states which requirement it proves, which values are fixtures, and why tolerances exist. Keep random balance tests reproducible by printing their seed.
- Avoid real-time sleeps in rule tests. Engine tests may wait for bounded replication/physics conditions with explicit timeout and useful diagnostics.

## Core gameplay invariants

- Deployment sets aircraft maximum/current health to 1,000 × the Ground roster, excluding the operator. Direct rockets deal 100 and M-7 hits 5, capped at remaining health. Deaths/departures/late arrival do not resize or heal it; duplicate, indirect and stale impacts cannot award damage.
- Four site launchers each own one available or held identity per active round, including the Seedship pickup. A player carries at most one. Simultaneous claims, loss/recovery and reset cannot duplicate a weapon or refresh reload early.
- The aircraft follows the unchanged circular perimeter orbit with tangent heading. Operator focus covers the world-aligned square, clamps each axis independently and reverses without trapped input at edges/corners. Both lenses preserve the held map target and independent aim; server shots remain limited by the combat disk/envelope and solid cover.
- One direct 105mm impact destroys one registered panel. Two earned valid same-panel 30mm seconds destroy it, with the intermediate Heavy opening at one second. Interruptions retain credit without counting paused time; real openings, pre-impact batch ordering and bounded safe fragments remain authoritative.
- Operator scenery/terrain is darker and living Ground targets contrast clearly. Native occlusion hides covered players; a genuine opening exposes only its sight lines. Color/transparency changes restore on role loss and do not alter normal Ground presentation or collision.
- Rapid weapon switching cannot reset readiness or ammunition. Deadline takes precedence, then aircraft destruction precedes ground elimination within the same admitted pre-deadline step. Replays clear stale damage, effects and equipment.

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

These targets apply to future Roblox release validation. P11’s recorded local measurements remain source-specific. P12’s user-directed legacy implementation closeout does not claim the live capacity, performance or soak checks passed. Use the [future release checklist](release.md) and record the actual source, destination, clients and measurement environment. Changing a budget needs a documented reason, not a quieter test.

- Test at 1920×1080 with a recorded graphics quality. Target client frame time p95 ≤33.3 ms for both roles during a scripted five-minute combat workload.
- Target server frame time p95 ≤16.7 ms for the same workload. Record the sampling method, active clients, projectile/cover/effect counts and Studio/cloud environment.
- Complete five consecutive accelerated deterministic rounds with no stale damage, launcher ownership, results, listeners or map state. Server-owned temporary instance/connection counts must return to the baseline after each reset.
- Run a 30-minute multiplayer soak. After warmup and equivalent reset points, retained memory growth must be ≤10%, with no monotonic leak; record actual samples and separate engine caches from owned allocations.
- Exercise a controlled latency scenario near 150 ms round-trip, recording actual simulator settings/measurements, and confirm state converges without duplicated damage/rewards.
- Run the 6-player and 10-player sessions in actual Roblox clients in the authorized test experience. Follow the release runbook for roster, measurement and evidence collection. [Live acceptance procedure](release.md#run-the-6-and-10-player-acceptance-sessions)

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

- P13: source-built 720-stud disk/equal perimeter orbit, versioned terrain elevation/material reconstruction, building/story/panel registry, actual stairs/upper-floor navigation, supported anchors, separate lobby and connected launcher routes.
- P14 historical scope: orbit-relative/quarter-screen pan acceptance remains tied to its recorded source. P18 replaces those bounds with square edges and world-fixed focus, requiring fresh direction, reversal, projection, recenter and cleanup evidence.
- P07 historical scope: its 3/6-hit and nine-second results remain source-specific. P18 requires one-hit/two-earned-second boundaries with retained interrupted credit, all-building coverage, real openings, safe physics and fresh multiplayer/reset evidence. D50’s P07 late-join waiver does not waive replication/reset checks.
- Future release validation: exercise expanded-map travel/visibility and simultaneous fragment workloads in live frame/memory/latency/soak measurements, including the revised level/panning/destruction demonstrations at real 6- and 10-player capacity. These checks remain unverified; the legacy P11/P12 records preserve their original source and environment.

Record numeric tolerances and chosen defaults before running each suite. Test doubles cannot prove terrain loading, residual collision, camera coverage, rigid-body contact or replication. Earlier engine reports must not be relabeled as evidence for this expanded scope.
