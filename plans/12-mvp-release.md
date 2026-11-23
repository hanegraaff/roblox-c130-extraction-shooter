# P12 — Reconstructable release and multiplayer acceptance

**Milestone:** M6 / MVP. **Dependencies:** P11. **Requirements:** R01–R16. Status: [roadmap](../roadmap.md).

## Capability and player experience

The verified game runs in a named, explicitly authorized Roblox experience. Players can complete repeated 6- and 10-player matches with both roles, both aircraft weapons and zoom levels, M-7 fire, the single launcher, cover and aircraft destruction, spectating and results. The 720-stud battlefield includes terrain and three accessible multi-story buildings, including the approved detailed Outpost. Panning and progressive physical panel destruction are part of the release. The README supplies the verified play link and availability.

## Implementation

Prepare a clean-checkout release candidate using the release mapping. Record source commit, build hash, tool/dependency pins, asset manifest, actual universe/place IDs and intended audience. Inspect the artifact for test content/development overrides and check asset permissions. Prepare a rollback to a known-good build and a smoke checklist. Only then publish if authorization already exists, or request the remaining destination/access/publication decision with this concrete candidate.

## Acceptance criteria

- **A1:** Full gate passes from a clean checkout. Artifact contents match the committed source and manifest. Release builds exclude test dependencies, runners and development fixtures. Build hash and source commit are recorded.
- **A2:** Final Studio engine/multiplayer suite passes; every R01–R16 requirement links to actual test/evidence, with no required skipped or zero-count suite.
- **A3:** Exact experience/place/audience and explicit authorization are recorded before publication. Cloud asset permissions are verified for that owner. A published build/version is confirmed by the platform, not inferred from a tool attempt.
- **A4:** Real Roblox-client sessions at 6 and 10 players complete repeated aircraft-destruction, ground-elimination and timeout paths. Verify both roles, cover/destruction, supported late joins, launcher transfer, the three-rocket threshold, the inward perimeter camera at both zooms with WASD/touch panning and separate aim, enlarged terrain and all three multi-story buildings, 3/6-heavy-hit and nine-second 30mm panel progression, half-destroyed openings/physical fragments, weapon-switch timing and terrain/panel/debris reset. Record actual client counts without personal data. D59 excludes same-identity reconnect from this exercise. Deterministic service tests retain reconnect authority coverage. Run the 6/10-player checks in Roblox clients.
- **A5:** The 10-player candidate meets the performance/soak budgets in `docs/testing.md`, with logs/metrics and no unresolved material gameplay/replication defects. Studio's smaller simulated-client run is not a substitute.
- **A6:** Player README links to the actual authorized experience and states tested devices/current limitations. Release record identifies rollback steps and the verified candidate. Source and evidence are pushed and a reviewable PR is available.

## Release boundary

[P16/P17's Blender asset and smaller-Outpost refinement](17-integrate-military-outpost.md)
is scheduled before P09 and this plan by D63. Require the approved replacement's
source, complete exports/manifest, actual owner asset access and P17 acceptance
alongside the release checks above. Blender approval alone cannot establish
release readiness.

Missing Roblox destination, access, explicit publishing authorization or ten-client validation leaves this plan incomplete. Finish all local preparation and state precisely what remains; do not publish to an invented place, change audience silently or waive a capacity check. Merge authorization is separate from publication authorization.

## Completion record

### Candidate baseline

P12 starts from P11’s merged source (`5fa47e8a0251c12ea8639f0ae0a75c2c5409748e`),
tree `5521ef140c703183049058a28325eb64c69ff377`. The [P11 record](11-balance-and-performance.md#completion-record)
contains the native performance, cleanup, latency and balance results for its
recorded sources and client counts. P12 has separate final Studio and live
Roblox gates. The earlier [P17 owner-only approval](../docs/evidence/p17/private-upload-authorization.json)
covers its recorded import build, experience and asset uploads.

D74 changes the release build's match minimum to two. The authorization and
artifact hashes recorded below apply to the earlier release candidate.

### Requirement traceability

Use the listed suites and records when reconciling the final candidate. Each
plan links its dated results to the source that actually ran. Fresh P12 suite
results and release-session results are tracked below this mapping.

| Requirement | Named checks and existing evidence |
| --- | --- |
| R01 | Clean checkout `scripts/verify.py` and `scripts/inspect_build.py`, P16 package audit and P17 generated definition, material preservation and managed reconstruction. [Host and Outpost gates](../docs/testing.md#current-host-checks) |
| R02 | `RoleService.spec.luau`, `Lifecycle.spec.luau`, `Config.spec.luau` and P03 three-client deployment/late arrival. P12 covers the real 6- and 10-player rosters. [P03 harness](../docs/testing.md#run-the-p03-multiplayer-harness) |
| R03 | `RoundRules.spec.luau`, `Lifecycle.spec.luau`, `MatchService.spec.luau`, P03 deployment/reset and P09 outcome and replay scenarios. [P09 harness](../docs/testing.md#run-the-p09-match-outcome-harness) |
| R04 | `Lifecycle.spec.luau`, `MatchService.spec.luau`, P03 and P13 late-join state, and P10 spectating after life loss. [P13 harness](../docs/testing.md#run-the-p13-expanded-map-harness), [P10 harness](../docs/testing.md#run-the-player-experience-harness) |
| R05 | `AircraftRules.spec.luau`, `MapRules.spec.luau`, the P13 map/terrain suite and full-orbit P14 native camera rays. [P13 record](13-terrain-and-buildings.md), [P14 record](14-aircraft-panning.md) |
| R06 and R17 | `AircraftPanRules.spec.luau`, P04 thermal and view, P14 directional controls and both lenses, P07 damage-stage occlusion, and P10 touch/desktop HUD. [P04 harness](../docs/testing.md#run-the-p04-aircraft-harness), [P14 harness](../docs/testing.md#run-the-p14-panned-targeting-harness) |
| R07 | `CombatService.spec.luau`, `CombatViewRules.spec.luau`, `AircraftSelection.spec.luau` and P05 native weapons, cover, readiness and replica behavior. [P05 harness](../docs/testing.md#run-the-p05-gunship-combat-harness) |
| R08 | `AircraftHealth.spec.luau`, `GroundCombatService.spec.luau`, `LauncherService.spec.luau`, P06/P06Team rifle and aircraft health, P08 three direct rockets and P09 result attribution. [P06 harness](../docs/testing.md#run-the-p06-ground-combat-harness), [P08 harness](../docs/testing.md#run-the-p08-launcher-harness) |
| R09 | `PanelDamageRules.spec.luau`, `DestructionService.spec.luau`, P07 native sight lines, fragments and resets, and P17 imported material stages. [P07 harness](../docs/testing.md#run-the-p07-destruction-harness), [P17 harness](../docs/testing.md#run-the-managed-p17-multiplayer-harness) |
| R10 | `LauncherService.spec.luau`, P08 pickup, drop, transfer and reset, P13 anchor/routes and P09 live replay. [P08 record](08-rocket-launcher.md) |
| R11 | `MatchService.spec.luau` and P09 result priority, attribution, departure and replay. All three competitive endings repeat in the P12 live sessions. [P09 record](09-match-outcomes.md#completion-record) |
| R12 | `PlayerPresentation.spec.luau`, `WeaponSoundRules.spec.luau`, P10 native presentation and P07/P14 cover and view. [P10 record](10-player-experience.md#completion-record) |
| R13 | `Validation.spec.luau`, `RateLimit.spec.luau`, combat and launcher service rejection checks, and P11 native Replay. [P11 harness](../docs/testing.md#run-the-p11-performance-harness) |
| R14 | P11 Replay, Soak, Profile and Latency, plus the distinct P12 live roster, performance and soak gates. [P11 record](11-balance-and-performance.md#completion-record), [release budgets](../docs/testing.md#objective-release-budgets) |
| R15 | Repository checker, StyLua, Selene, strict Roblox-aware analysis, independent tester and technical-writer review. [Host gate](../docs/testing.md#current-host-checks) |
| R16 | `BuildingLayout.spec.luau`, native P13 terrain, buildings and traversal, P07 openings, P17 Outpost, and P11 load/route review. [P13 record](13-terrain-and-buildings.md), [P17 record](17-integrate-military-outpost.md) |
| R19–R21 | P16 approved `.blend` and exports, P17 native integrated-art and reset review, `GroundCameraRules.spec.luau` and native indoor-camera acceptance. [P16 record](16-blender-military-outpost-assets.md), [P17 record](17-integrate-military-outpost.md#final-native-outpost-acceptance-2026-11-20) |

### Authorization and destination access

On 2026-11-22 the user approved the release artifact at SHA-256
`266c2322717eebc081b110eba391cde626edb65bcbe245dc4a25404b70022cf7` for
**C130 P17 Import**, universe `10776653720`, place `72732833195348`, with
access limited to invited playtesters. Studio's connected document was the
local test place. Its Open Cloud token request rejected `universe:read` and
`asset:read`, and browser control could not reach Creator Dashboard. Current
owner, place capacity, destination asset grants, rollback version and audience
settings await destination access. Roblox publication and live-player evidence
are pending. [P12 authorization receipt](../docs/evidence/p12/playtest-publication-authorization.json), [release procedures](../docs/release.md)

The committed mesh capture and all twelve texture records identify owner
`2227341845`, the same owner identified by the historical P17 workspace
receipt. These are source-side provenance. Destination-specific availability
and permissions require a fresh cloud check.

### Invited playtest approval for the merged build

On 2026-11-23 the user approved publication of the merged `982d3e7` build to
the same **C130 P17 Import** place for invited playtesters. The authorized
release artifact has SHA-256
`4b13d8b864e248d6ac469c68cf04df9fb8ffe9a813d699a379ba1a06463b123d`.
The user reported a satisfactory two-player test and accepted that scope for
the invited playtest. Full P12 acceptance still tracks the final Studio suite,
six- and ten-player live rounds, and the live performance and soak evidence.

The destination preflight again found the connected Studio document was a
local place. Studio MCP denied `universe:read`, `universe.place:read`, and
`asset:read`, and the browser access host was unavailable. The destination
audience, asset grants and rollback version still need verification in Roblox.

### Clean-checkout verification

`python3 scripts/setup.py` installed the pinned tools, TestEZ and Roblox types
in a full-history local clone. `python3 scripts/prepare_release.py` ran
`python3 scripts/verify.py` from a clean, detached checkout at
`6d1a352196277a89a5b7dec41181035707f766c7`, tree
`397296697c02caac615bacd0102c1b41715a28e6`, on macOS arm64 with Python 3.10.4.
The checkout stayed clean. The initial implementation required a generated P17
provenance refresh. Independent review also found that an ignored file under a
Studio test mapping could enter the test build. The corrected preparation gate
checks authored inputs of both mappings and the focused tooling case checks both
release and test probes. [Passing candidate CI](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/45076381222)

- **Host gate:** 82/82 unit cases, 74/74 integration cases, 18/18 tooling cases,
  48/48 asset regressions and 7/7 P16 audits. P17 reconstruction and provenance,
  format, lint, strict types, and deliberate rejection probes passed.
- **Release artifact:** `default.project.json` produced `build/game.rbxlx`,
  10,154,160 bytes, SHA-256
  `266c2322717eebc081b110eba391cde626edb65bcbe245dc4a25404b70022cf7`.
  The authorized build from `7c04172` is byte-identical. Artifact inspection
  verified 5,306 release Instances, 58 runtime scripts and release isolation
  from test dependencies, runners, fixtures and two-player settings.
- **Studio artifact:** `test.project.json` produced `build/tests.rbxlx`,
  11,418,054 bytes, SHA-256
  `8b419cb8d9e42d0f62f1e99bbad1c2cb5e014b9b47442acb7fa02ce063ea6f5f`.
  Both artifacts passed 2,804 authored transform comparisons and their 58
  runtime scripts matched committed source. Independent repeat builds were
  byte-identical.
- **Asset inventory:** manifest schema 1, 407 mesh IDs, 12 textures and 3
  Creator Store audio IDs. The receipt lists the pinned inputs and exact
  artifact and manifest hashes. [Release receipt](../docs/evidence/p12/6d1a352-release-receipt.json)

### Independent Studio verification

The tester used macOS Studio `0.748.0.7481526` and the local `tests.rbxlx`
document with both cloud IDs zero. The initial and corrected candidate's 159
mapped source containers matched their corresponding builds. The release file
remained byte-identical throughout. Native reports record the actual fixture
source and client counts for each run.

| Studio scenario | Observed result |
| --- | --- |
| Ordinary Play and fresh restart | 192/192 server and 13/13 client tests in each one-client run, with one status owner and one visible round HUD after startup. [Smoke report](../docs/evidence/p12/5fa47e8-studio-smoke.json) |
| P03 deployment and late join | The first run reached three clients and timed out on a replicated role/phase/deadline acknowledgement before late join. The second had two of three requested clients. A staged attempt brought up only one of two initial clients and timed out before the three-client harness. [Initial run](../docs/evidence/p12/5fa47e8-p03-initial.json), [retry](../docs/evidence/p12/7c04172-p03-retry.json), [staged attempt](../docs/evidence/p12/6d1a352-p03-staged-launch.json) |
| P07 destruction, first attempt | Four of five started checks passed with two clients, including shelter damage and 9.1618 earned seconds for the 30mm Heavy transition. Traversal failed before replication and reset checks. The Ground avatar was still near its prior spawn after a server-only placement. `6d1a352` makes the test confirm the actual client's replicated start before client-owned movement, retaining the same opening, arrival thresholds and server replication check. [Original run](../docs/evidence/p12/7c04172-p07-opening-attempt.json) |
| P07 destruction, corrected fixture | Two actual clients passed request authority and the six heavy-hit thresholds. Two successive accepted 30mm shots arrived 0.231936 seconds apart against the 0.225-second rule, stopping the fixture before the corrected traversal or reset. The final retry stalled before a Server DataModel or client joined. [Cadence report](../docs/evidence/p12/6d1a352-p07-cadence-attempt.json), [startup failure](../docs/evidence/p12/6d1a352-p07-launch-blocked.json) |
| P09 outcomes and departures | Two three-client runs passed 5/5 and 2/2, including aircraft destruction, elimination, timeout, replay and operator forfeit. LastGround stalled before a reported client start and ended with no suite result. Empty then passed 2/2 with two actual clients. [P09 reports](../docs/evidence/p12/p09-studio-outcomes-and-departures.json) |
| P14 full-orbit native panning | 6/6 with two actual clients on `6d1a352`, after 192/192 server and 13/13 per-client smoke. Both 90-second weapon profiles passed targeting, cover and near-edge projection, role reset and teardown. [P14 native report](../docs/evidence/p12/6d1a352-p14-native.json) |
| P17 managed Outpost | 10/10 with two actual clients on `6d1a352`, after 192/192 server and 13/13 per-client smoke. Both stair routes, six material families, a Heavy stage at 9.167355 earned 30mm seconds, a replicated opening traversal, and two pristine 188-panel resets passed. The SDK launched the native fixture through its server-only manual selector. [P17 native report](../docs/evidence/p12/6d1a352-p17-native.json) |

The original local document returned to Edit with its temporary selectors
cleared after the final P03 attempt. The final P07 SDK launch remained pending
in its alternate local document, and its owned child opened in Edit. Neither
reported a running test. P04, P05, P06/P06Team, P08, P10, P11, P13, human test
controls and operated layout, thermal and mobile checks retain their
source-specific earlier evidence and await fresh release acceptance.

### Release gates

| Criterion | Evidence and remaining work |
| --- | --- |
| A1 | Passed from clean Git with repeat-build checksum agreement and a release-only artifact. The committed receipt records inputs and hashes. |
| A2 | The linked Studio reports record fresh results and failures. P03 late join, full P07 traversal and reset, P09 LastGround, and the remaining fresh scenarios above stay open. |
| A3 | The user granted publication for the exact hash and invited audience. Destination access and verification of a published version are pending. The final Studio listing contained only local test documents. |
| A4 | Six- and ten-player Roblox client rounds require an accessible published candidate and confirmed player rosters. |
| A5 | The live ten-player five-minute workload and 30-minute soak require the published candidate and a ten-player roster. The P11 Studio baseline remains recorded above. |
| A6 | The technical writer reviewed the player and contributor guides and added smoke, rollback and live acceptance steps. The player experience link and live limitations await platform verification. [Runbook](../docs/release.md), [draft PR #46](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/46) |
