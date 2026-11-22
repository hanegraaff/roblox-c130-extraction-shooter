# P12 — Reconstructable release and multiplayer acceptance

**Milestone:** M6 / MVP. **Dependencies:** P11. **Requirements:** R01–R16. Status: [roadmap](../roadmap.md).

## Capability and player experience

The verified game runs in a named, explicitly authorized Roblox experience. Players can complete repeated 6- and 10-player matches with both roles, both aircraft weapons/zoom levels, M-7 fire, the single launcher, cover/aircraft destruction, spectating and results. The 720-stud battlefield, terrain, three accessible multi-story buildings, panning and progressive physical panel destruction are required even with simple graphics. Refined assets can follow in dedicated later plans. The README supplies the real play link and accurate availability.

## Implementation

Prepare a clean-checkout release candidate using the release mapping. Record source commit, build hash, tool/dependency pins, asset manifest, actual universe/place IDs and intended audience. Inspect the artifact for test content/development overrides and check asset permissions. Prepare a rollback to a known-good build and a smoke checklist. Only then publish if authorization already exists, or request the remaining destination/access/publication decision with this concrete candidate.

## Acceptance criteria

- **A1:** Full gate passes from a clean checkout. Artifact contents match the committed source and manifest; test dependencies, runners and two-player override are absent. Build hash and source commit are recorded.
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
