# P25 — Weapon cooldowns, rocket damage and infinite M-7 ammunition

**Gameplay iteration.** Builds on P05, P06, P08, P18 and P19. Covers R07–R10, R12 and R13. [Roadmap](../roadmap.md) · [Requirements](../requirements.md)

| Weapon | Settings before P25 | P25 settings |
| --- | --- | --- |
| 105mm M102 Howitzer | One shell, ready again after 6 seconds | Ready **12 seconds** after each accepted shot |
| Ground rocket launcher | Ready after 4 seconds, 100 direct aircraft damage | Ready after **15 seconds**, **150 damage** per direct aircraft hit |
| M-7 rifle | 30-round magazine, 120 reserve | **Unlimited reserve** with the existing 30-round magazine, 2-second reload, 0.15-second cadence and 5 aircraft damage per hit |

## Implementation

- In `CombatService`, change the M102 single-shell automatic reload to 12 seconds. Measure from the accepted shot. The 30mm retains its own readiness across weapon switches. Preserve the existing M102 blast radius and panel rules.
- In `LauncherService`, track the 15-second ready time independently on each of the four round-owned launcher identities. Handovers, weapon switches and recovery after death preserve the fired launcher's ready time. Fresh launchers start loaded. Apply 150 once in the shared aircraft health path on an authoritative direct impact. Keep misses, occlusion, the remaining-health clamp and the locked maximum of 1,000 × deployment Ground count.
- In `GroundCombatService`, allow a living, equipped rifle user to refill a partial or empty magazine indefinitely. Replicate unlimited supply explicitly and show the loaded rounds and reserve together, for example **30 / ∞**. Keep the finite magazine and reload deadline server-owned. Update `GroundCombatController` and readiness copy for both desktop and touch.

## Acceptance

| ID | Check | Passing observation |
| --- | --- | --- |
| A1 | Extend `CombatService` and `LauncherService` clock tests | From an accepted shot at t=0 the M102 rejects at 11.999 seconds and accepts at 12. The fired launcher rejects at 14.999 and accepts at 15. Rejected early, stale and duplicate requests leave readiness unchanged. Switch away and back, transfer a cooling launcher to a teammate, and show another launcher still has its own ready time. |
| A2 | Extend `AircraftHealth` and damage integration tests | At 1,000 HP a rocket leaves 850 and one M-7 hit then leaves 845. Six rockets alone leave 100 and the seventh destroys the plane exactly once. Check a larger roster, a miss, solid cover, duplicate impact and a lethal mixed-damage batch at the deadline. |
| A3 | Extend `GroundCombatService` and presentation tests | Fire more than the former 150-round total with repeated legal reloads. An empty magazine cannot fire, a partial magazine refills correctly, and firing is rejected until the two-second reload completes. A stale request, elimination or round change cannot grant a shot or complete an old reload. |
| A4 | Extend the native gunship, Ground and launcher harnesses | In a shared Studio round, verify weapon-switch readiness, the cooling launcher after handover, 150 damage on both clients' aircraft health displays, and magazine/reload feedback with unlimited supply. Review timer legibility and restored equipment across round reset. |

Run `python3 scripts/verify.py` and the affected Studio combat and HUD suites. Update the root player guide, readiness and damage contracts, and tests that assert the former timings or reserve. Preserve earlier evidence under its tested revision.

## Completion record

### Initial candidate verification on 2026-11-25

The independent tester exercised `2b7c2a7ab2d6171bfa3b9358b12e02b72c629d28`, tree `de9203c7efe4aeb34d9fd75fdfcb5a14e37ba265`. GitHub candidate `be74bc1769c8ab3857bf0649471746b03f534042` has the same tree. The full `python3 scripts/verify.py` gate passed on macOS arm64 with Python 3.15.2, including 86 unit, 86 integration, 26 tooling and 70 asset tests, format, lint, strict analysis, expected rejection probes, both Rojo builds, geometry and release isolation. The independent Lune unit and integration runs both passed 86/86.

Roblox Studio `0.748.0.7481526` used the existing local `tests.rbxlx` in Edit mode with the `PlayersVsC130Tests` live mapping on port 34872. The Edit comparison matched 183 scripts and five authored poses. The Rojo test artifact SHA-256 was `27a7f50bd1695c1626fe78766f86eafd50569ac4f4a8c5489e6dbb4867c1bf0d`. [Edit parity receipt](../docs/evidence/p25/studio-parity-2b7c2a7.json)

| Criterion | Observed verification |
| --- | --- |
| A1 | `CombatService.spec.luau` checks exact 11.999/12.000 boundaries, independent chain-gun use, stale or duplicate fire and readiness after switching. `LauncherService.spec.luau` checks exact 14.999/15.000 boundaries after transfer, independent site readiness and unchanged rejected state. The three-client `P18` run observed the 12-second howitzer deadline across a chain-gun switch and the same 15-second launcher deadline on the first and second carrier. |
| A2 | `AircraftHealth.spec.luau` checks 1–9 Ground rosters, 1,000→850→845, six rockets leaving 100, one lethal clamped seventh hit and deduplication. `MatchService.spec.luau` checks a mixed lethal batch admitted before the deadline and resolved across the clock boundary. The native `Launcher.spec.luau` checks cover and misses. The `P18` run observed a real moving-aircraft hit from an actual client rocket and 1,850/2,000 on all three health HUDs. |
| A3 | `GroundCombatService.spec.luau` checks empty and partial magazines, more than 150 legal shots, exact reload timing and denial after stale or retired state. `PlayerPresentation.spec.luau` checks unlimited reserve and reload copy on both layouts. The `P18` run observed 30/∞, 29/∞ with reload feedback, early fire denial, and return to 30/∞. |
| A4 | `ExecuteMultiplayerTestAsync(3, { kind = "P18" })` passed all 13 cases with three actual clients initially and two after intentional carrier departure. Server smoke passed 208/208 and each of the three clients passed 23/23. The suite checked formatted timer fit, recovery after death, fresh equipment on replay and cleanup. [SDK report](../docs/evidence/p25/p18-sdk-2b7c2a7.json) · [Readiness and health observations](../docs/evidence/p25/p18-a4-observations-2b7c2a7.json) |

The P05 gunship regression passed 9/9 with two actual clients, including both weapon profiles, native impacts, 25-stud blast and building-panel behavior. Server smoke passed 208/208 and both clients passed 23/23. The rendered desktop operator view showed a readable 7.5-second howitzer countdown above the weapon selection controls. [P05 SDK report](../docs/evidence/p25/p05-sdk-2b7c2a7.json) · [P05 smoke reports](../docs/evidence/p25/p05-smoke-2b7c2a7.json) · [Desktop howitzer HUD](../docs/evidence/p25/desktop-howitzer-reload.jpg)

The independent tester found that the P24 arrival fixture still expected 900 HP after a direct hit on a 1,000-HP aircraft. P25 leaves 850 HP. The first GitHub Verify run also rejected the regenerated P17 metadata because it included an ignored `.DS_Store` file from the local Mac. [Verify #687](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/45669804608) · [PR #73](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/73)

### Arrival and provenance corrections

`e175ab8833f6a2db3e62123dc794a26fe7fcbcde`, tree `54cc1d2dba7d19ee76a43ca9e62752f464708e41`, updates the P24 fixture's health assertion and excludes Finder caches from the provenance binding. GitHub `945f60479de881016925e4b5268932733829ea0c` has the same tree. Runtime Luau and both client/server bodies of the passing P18 and P05 harnesses match the initial candidate. `python3 scripts/verify.py` passed with 86 unit, 86 integration, 27 tooling and 70 asset tests. It validated both Rojo builds, 13,975 release and 14,062 test part transforms, and isolation of the 70 runtime scripts in the release mapping. Release build SHA-256 is `2e88fb4081d3d7ef5774aa445348945fc4d576d4769058a63a4d46f9b7b97fe8`. The test build SHA-256 is `e83e87dbf143129aa78a73ed934e232a425e40784074bba0c33390910a0de58f`. [Corrected Studio Edit parity receipt](../docs/evidence/p25/studio-parity-e175ab8.json) · [Passing Verify #689](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/45670731177)

The tester reran `ExecuteMultiplayerTestAsync(2, { kind = "P24" })`. All nine cases and the server's 208 smoke cases passed. Both clients passed 23 smoke cases with zero failures, skips or errors. The first two rounds preserved fire gating during Scatter and verified a fresh direct rocket from 1,000 to 850 health after arrival, followed by successful gunship combat. The two clients exchanged roles on replay. [P24 SDK report](../docs/evidence/p25/p24-sdk-e175ab8.json)

The independent iPhone 17 Pro LandscapeRight review at a logical 750×381 viewport found that the rifle readiness row fit, while the existing 66×18-pixel **RELOAD** text overflowed its 54×42-pixel touch button. Native `TextFits` was false. [Initial phone report](../docs/evidence/p25/phone-overflow-e175ab8.json)

The first widened-button candidate, `560215734b748e0782cbe1f1ef35e0d0dac697c6`, passed the host gate. Each of its three Studio clients passed 22/23 smoke cases. The 568×320 layout with a 58-pixel inset exposed a Reload and Drop overlap, so the P18 run ended at smoke startup without exercising the round. [Edit parity receipt](../docs/evidence/p25/studio-parity-5602157.json) · [Failed Studio report](../docs/evidence/p25/p18-native-smoke-failure-5602157.json)

### Final gameplay and touch layout

`5270dc04b42dd25ff88e52d0bc7e4c9dcfbfb65a`, tree `b34d3958c8a5f6ff634def7c59b41dd94a342435`, gives the 78×44-pixel Reload button clearance from Drop at compact sizes. GitHub `a7196806a6b4048bb4f4dd4fa4c349266df4ca5f` has the same tree. `GroundAimGui.spec.luau` checks text fit, padding and control clearance across the compact viewports with measured GUI origins. The test build SHA-256 is `e7dc0756c58a00e6f3ac922b5b3180036b445032a7e889bec6042b699784422b`. The release build SHA-256 is `e0a6238592b65fde9e547baf806d287f475d0b114daca89754f1be1b0d3dbe13`. [Final Studio Edit parity receipt](../docs/evidence/p25/studio-parity-5270dc0.json)

The final gameplay candidate passed `python3 scripts/verify.py` on macOS arm64 with Python 3.15.2. It passed 86 unit, 86 integration, 27 tooling and 70 asset tests, plus strict analysis, format, lint, expected rejection probes, both Rojo builds, artifact isolation and authored geometry verification. GitHub passed the same gate on Ubuntu. [Verify #693](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/45672159834)

The final `P18` SDK run passed 13/13 with three actual clients, two remaining after the intentional departure, and zero failures or skips. Server smoke passed 208/208, and every client passed 23/23, including the compact touch layout. The round again exercised the howitzer switch, a direct rocket hit against the moving aircraft, the inherited launcher deadline, the rifle reload and equipment restoration. The last two source corrections are confined to touch Reload geometry and its test/provenance. The earlier P05 and P24 reports retain their tested desktop source identities. [Final P18 SDK report](../docs/evidence/p25/p18-sdk-5270dc0.json) · [Final combat observations](../docs/evidence/p25/p18-a4-observations-5270dc0.json)

In an ordinary two-client round, the iPhone 17 Pro simulator showed the 66×18-pixel Reload text within its 78×44-pixel button and readable health, launcher and rifle readiness at logical 750×381 and 568×320. Operating the rendered Fire control spent three rounds. Pressing **R** on that same emulated client triggered production reload, displayed `27 / ∞` with a countdown and restored `30 / ∞`. The simulator mouse injection reached the Reload button but did not emit its activation event. Physical touchscreen activation remains unverified. The tester left the original document in Edit, stopped the simulator, and cleared temporary run attributes. [Phone observations](../docs/evidence/p25/phone-hud-5270dc0.json) · [Reload countdown](../docs/evidence/p25/phone-rifle-reloading.jpg) · [Compact layout](../docs/evidence/p25/phone-rifle-568x320.jpg) · [Studio cleanup](../docs/evidence/p25/studio-cleanup-5270dc0.json)

The documentation review updated the player guide, branch and Studio setup, weapon and readiness contracts, and package/test references. The root guide retains the selected P16 Blender viewport as its only image.

### Main integration

The integration update points routine setup to `main` and records the final checks and merge commit on the pull request. The gameplay source and Studio evidence are carried forward from the tested P25 candidate above. [PR #73](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/73)
