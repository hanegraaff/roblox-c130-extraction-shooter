# P26 — Live balance panel

**Depends on** P25. **Requirements** R25. [Roadmap](../roadmap.md#public-mvp-launch) · [Requirements](../requirements.md)

You and trusted testers can save balance changes from inside the published game. This panel is required for public launch. Ship it once, then tune the supported settings without editing files or publishing another build.

## Settings in the panel

| Control | What you change |
| --- | --- |
| Airplane health | Health per deployed Ground player. Show the total for the current roster. The starting value is 1,000 per player. |
| Airplane damage | Separate damage to Ground players for the 30mm and 105mm. |
| Airplane weapon cooldown | Time between shots and reload time for the 30mm. Show only reload time for the howitzer. |
| Player health | Starting and maximum health for a deployed Ground player. |
| Player damage | Separate damage to the aircraft for the M-7 and the rocket launcher. Start at 5 and 150. |
| Player weapon cooldown | M-7 shot interval and magazine reload, plus launcher reload per launcher. Start at 0.15, 2 and 15 seconds respectively. |
| Medkit health amount | Health restored by a kit, capped at the player’s maximum. P30 connects the pickup to this setting. |
| Panel damage | Low, Medium or High damage to building panels. Show how many direct 105mm hits and how much sustained 30mm fire will open a fresh panel. Medium starts at one hit or two earned seconds. High shortens the 30mm time. Low makes cover last longer. |
| Round duration | Length of combat, starting at aircraft arrival. Default 10 minutes. |
| Lobby intermission | Wait between rounds, measured from the result. Default 120 seconds. Use the latest confirmed value when an intermission starts and show the same countdown to everyone. |
| Minimum players | Eligible players needed to deploy, from 2 to 10 including the operator. Default 2. A waiting lobby checks the new minimum as soon as its server receives the revision. |

## Work

- Group controls under Player, C-130, Buildings and Game & lobby. Use sliders with exact number entry, simple labels and clear panel hit/time requirements. Keep Save and Apply visible while scrolling.
- Put the panel in the lobby. Let the owner manage trusted Roblox user IDs. Both the owner and trusted testers can save, apply and delete named presets. Show units, allowed ranges, who saved a change, and the active and pending revisions.
- Start from the shipped settings. Wire all eleven controls to the server systems that use them. Expose only the medkit healing amount for P30. Kits are single-use per round. Keep the four launcher identities and their independent clocks.
- The server checks permissions on every read of private admin data and every write. Validate finite values, bounds and relationships, including panel stage order and durations. Keep ordinary players’ HUD values in sync with the server. Ship the restricted panel separately from the Studio-only test controls.
- Save versioned settings with a conditional DataStore update. Detect concurrent edits, retain the last good live settings. Loading and editing a named preset stays separate from applying it. Deleting a preset preserves live settings and clears the name field. Keep the read-only Default preset available. Enable Save after editing a custom preset or entering a different valid custom name. Load Settings lists saved presets. Notify other servers after saving and refresh from storage during lobby waits and before deployment to recover missed messages, including a lowered minimum in a waiting server. Capture one validated preset for the whole round. If storage is unavailable, show the last confirmed revision and retry. New servers can fall back to the shipped values. [Roblox data stores](https://create.roblox.com/docs/cloud-services/data-stores) · [Cross-server messaging](https://create.roblox.com/docs/cloud-services/cross-server-messaging)

Use the same preset in MatchRuntime, the character and aircraft health owners, CombatService, GroundCombatService, LauncherService and PanelDamageRules. Keep persistent partial panel damage and covered-player protection at every setting. Apply the selected panel damage to direct hits and the existing eligible splash contacts. A higher setting must never require more hits or firing time.

## Acceptance

1. **A1 · Settings and permissions.** Unit and service tests cover baseline equivalence, each setting family at both limits, malformed values, owner grants/revocations, an ordinary player attempting a write, and two testers saving from the same revision. Rejected writes leave the saved revision intact.
2. **A2 · Round behavior.** In Studio, run Ground and operator clients. Apply a preset mid-round, then replay. Confirm old and new damage, health, cooldown and panel thresholds on the correct rounds, including actual server damage and HUD values. Check interrupted panel credit and independent launcher cooldowns. Cover failed persistence, missed notifications and rollback with controlled adapters.
3. **A3 · Published panel.** Use two Roblox players on a new server for the authorized private test experience. Play multiple rounds and verify that updated balance settings take effect on subsequent deployments. Record the tested build and observed results with account details redacted. The broader published checks for cross-server propagation, restart persistence and rollback belong to R25 public release verification. [Owner decision D119](../docs/decisions.md)

4. **A4 · Lobby and clock.** With two clients waiting and a minimum of three, lower the minimum to two. Verify ordinary deployment starts after the lobby wait. Raise it again once deployed and finish the match. Reject 1, 11 and fractional counts. Set a short combat duration and verify the deadline from arrival, independent of Scatter and intermission. Change intermission to 30 seconds before the result. Check that both clients count down from the committed result time, deployment waits at least 30 seconds, and the population rule still applies. Edit again during that countdown and observe the new duration on the following intermission.
5. **A5 · Setting coverage.** For each table row, save a non-default value, read it back and measure the gameplay effect. Exercise all four weapons, all three panel presets and both health values. Verify medkit values persist in P26 and observe actual healing in P30. Test local defaults and a saved revision after restart.

Run the applicable [project checks](../docs/testing.md) and record the source revision, environment and observed results for each criterion.

## Documentation

Add a short owner guide covering tester access, live edits, when changes apply, and rollback.

## Completion record

### 2026-11-27 · Tested candidate

[Draft PR #75](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/75) targets the roadmap branch in PR #74. The corrected gameplay source is `55650a414373b9108a0a978f7e251b06b081c361`, tree `57e93faeda0b17dbebd24e41bf69bd3b11a14a15`. The owner guide covers all eleven controls, trusted testers, the local panel preview and rollback. [Owner guide](../docs/balance.md)

| Criterion | Verification | Observation |
| --- | --- | --- |
| A1 · Settings and permissions | `BalanceSchema.spec`, `BalanceRecord.spec`, `BalanceService.spec`, two-client P26 access cases | The server validated field bounds and the complete preset, rejected ordinary and revoked users, prevented stale writes, and let the owner grant a tester who saved and applied a preset. |
| A2 · Round behavior | P26 multiplayer in Roblox Studio on macOS, two actual clients across three rounds | The selected settings took effect at deployment. Ground health fell from 123 to 13 after 35 and 75 damage. M-7 and rocket hits reduced aircraft health from 777 to 494. Both clients saw the updated health. Cover retained interrupted credit, applied all three tiers and opened on both clients. |
| A3 · Published panel | Private Roblox live test with owner, trusted tester and ordinary player over two servers and a fresh instance | Open. The private destination is C130 P17 Import, universe 10776653720, place 72732833195348. The owner authorized corrected build `e5ae85eb1599` for invited testers. A follow-up using the cloud place succeeded and confirmed private access. The earlier denials came from the local test document because MCP permissions are per place. The cloud document reports version 58 and capacity 60. The approved release opened separately, but native Studio window control repeatedly timed out before Publish As. Publication, capacity ten, destination asset/access checks and the live two-server test remain pending. No P26 cloud version was observed. [Authorization and preflight](../docs/evidence/p26/private-test-authorization.json) |
| A4 · Lobby and clock | `MatchService.spec` and two-client P26 | Both clients saw the full 30-second intermission. With only 2 of 3 players, the lobby was still waiting 1.198 seconds after its deadline. Lowering the minimum to 2 started the next round. Its 35-second combat clock expired naturally. Both clients then received the new 3-second intermission deadline measured from that result. |
| A5 · Settings in play | P26 multiplayer, per-weapon and panel rule suites, isolated restart and rollback | Tuned values affected both health pools, all four weapons, launcher readiness, firing intervals, the clock and panel damage. Medkit settings survived save and reload. P30 owns healing a player with a pickup. |

**Host verification.** A clean checkout ran `python3 scripts/prepare_release.py`, including `python3 scripts/verify.py`. On macOS arm64 with Python 3.15.2, 89 unit, 96 integration, 27 tooling and 70 asset tests passed. Formatting, lint, strict types, geometry reconstruction, failure probes and release isolation passed. The release contains 75 runtime scripts, 27,284 instances and 157,122,691 bytes. SHA-256 is `e5ae85eb1599481c50a461ebc1fe76cd605dc4c0e23465baf84018659dd793da`. [Clean release receipt](../docs/evidence/p26/release-receipt.json) · [Release source CI #713](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/46064815097) · [Final fixture CI #715](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/46065530547)

**Studio and independent review.** Studio 0.748.0.7481526 ran `StudioTestService:ExecuteMultiplayerTestAsync(2, {kind = "P26"})` from the local test mapping. The six cases passed with zero skips. The final fixture commit is `37ef530ff8099e20205e3f155ebfa78711a24e0b`, tree `29412c345f7b28b6d49e38e32ec6ffe743fc3212`. All 178 tracked scripts and 16 installed dependency scripts in the synced test document matched. A fresh `python3 scripts/verify.py` run on that commit passed all four suites again. The resulting test build SHA-256 was `9262d16e06cbb35ca36798651652aff1f5d8e3c6f12f3af26f6eed8b098be8f1`. The release build reproduced the authorized SHA-256. In a separate one-client preview the tester used the mouse and keyboard to save 840 aircraft HP, apply it, then restore 1,000. [Studio report](../docs/evidence/p26/studio-multiplayer.json) · [Source binding](../docs/evidence/p26/studio-source-binding.json) · [Operated editor](../docs/evidence/p26/lobby-editor.json)

**Shipped preset regression.** On the corrected gameplay source, two Studio clients ran the existing P05 weapon and cover regression using shipped values. All nine cases passed. The server also passed 215 smoke checks and each client passed 23. [Regression report](../docs/evidence/p26/shipped-preset-regression.json)

**Corrections.** Early testing identified a request interval that limited fast launcher and howitzer presets. The clients now use server readiness, and the launcher request budget admits the supported cadence. The initial tracked fixture also waited for client reports before creating their round state. After that boot-order fix, native panel impacts exposed callbacks bound to an obsolete ledger. Deployment now refreshes settings on the existing ledger. The corrected native run above exercised the resulting openings. [First fixture failure](../docs/evidence/p26/initial-selector-failure.json) · [Panel regression](../docs/evidence/p26/panel-regression-before-fix.json) · [Initial isolated two-client timing check](../docs/evidence/p26/initial-two-client.json)


### 2026-11-27 · Owner panel follow-up

[PR #77](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/77) adds the requested simple wording, Player/C-130/Buildings/Game & lobby tabs, sliders with exact entry and persistent Save/Apply buttons. Building damage shows the howitzer hits or seconds of 30mm hits needed to break one panel. Medkits have one healing control and are single-use per round. The howitzer has one reload control. Legacy presets normalize to these rules.

The tested source is `9b6dd182bf894ef6bea07afb2ca2252d28e0b6d8`, tree `10ce284c7cbdfe6b566bee3b64e7b845596053a1`. `python3 scripts/verify.py` passed 90 unit, 96 integration, 27 tooling and 70 asset tests, formatting, lint, strict types, reconstruction, rejection probes and release isolation. A fresh two-client P26 run passed all six cases across three rounds with zero failures or skips.

The local preview exercised the health slider, exact-value focus parsing, input bounds, tab retention and saving/applying 321 HP through the production UI and remote. Desktop and simulated iPhone 17 Pro landscape renders were reviewed. Physical keyboard typing and touch gestures remain unverified by the available input tools. The device simulator was reset.

The updated release is `build/balance-panel-polish.rbxlx`, SHA-256 `9087b9500b309bd15be8e089fabdd926029d0b030a7d5ff959263ba429385e79`. This follow-up has no observed published version. P26 A3 remains pending. [Follow-up evidence](../docs/evidence/balance-panel-polish.json)

### 2026-11-27 · Final settings and merge authorization

The owner requested the final tuning ranges, preset deletion, dropdowns, separate live/editor presentation, and merging the changes. [PR #79](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/79) targets main after dependency PRs #74, #75, #77 and #78 were merged.

Tested source `d8ac680155a48a2d180d6de1d09c6663cfa11ef1`, tree `63728b7fffe14555e3ccb94458bab44207294deb`, passed `python3 scripts/verify.py` with 92 unit, 99 integration, 27 tooling and 70 asset tests. Strict types, lint, formatting, reconstruction, failure probes and release isolation passed. A fresh two-client P26 Studio run passed six cases across three rounds with zero failures or skips.

The new regression cases cover requested endpoints, migration from earlier stored ranges, deletion permission/revision rejection, deletion across two independent services and restart, live snapshot retention, and zero aircraft reload at clock zero. The preview showed the separate live heading and preset library. Editing 321 HP disabled Apply, and Save enabled it while the live preset stayed Shipped. Later pointer requests stalled, including after restarting the preview, and Computer Use returned `cgWindowNotFound`. Full manual Apply/Delete/New Preset and dropdown interaction checks remain unverified. The test document returned to Edit with its selector cleared.

The stable release is `build/game.rbxlx`, SHA-256 `842b78e12f1c30093bfda2e35d2d6e38265e02e0108c7ca5a6029b352d2f9e67`. README and the public MVP roadmap explicitly identify it as the file for publication. `build/tests.rbxlx` remains the local test mapping. These checks grant no new publication facts, and A3 remains pending. [Final settings evidence](../docs/evidence/balance-settings-final.json)

### 2026-11-27 · Default preset and named copies

[PR #81](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/81) displays the protected built-in preset as Default, enables Save only after the loaded name changes to a valid custom name, and removes the generated New Preset entry. Saving disables Save again. Deletion clears the name field. Load Settings keeps its exact label. The stored built-in identifier stays compatible with existing presets and active selections.

Source `3941aaaadedc66c3c28a0593a3836de1e3ba421b`, tree `a03a2f2346301c4dfc3f399117fb8b46d8e4ad71`, passed `python3 scripts/verify.py` with 94 unit, 100 integration, 27 tooling and 70 asset tests. Strict types, lint, formatting, source binding, reconstruction, failure probes and release isolation passed. The new named regressions cover legacy display identity, Save eligibility before/after renaming and saving, protected names, and retained active selections. Both stable place builds were regenerated. Documentation passed `python3 scripts/check_repository.py`. No new native pointer or live publication evidence is claimed for this follow-up.

### 2026-11-27 · Production Settings save fix

Editing a custom preset enables Save under its existing name. Reopening the panel loads the saved values for the selected active preset and prompts the user to apply them when they differ from the live values. The built-in Default remains protected.

`BalanceSchema.spec` covers same-name Save eligibility and protected names. `BalanceService.spec` saves and overwrites Production Settings, reloads it in a new service, applies it and checks round capture. The aircraft health rules then use the captured settings to initialize the aircraft at 1,800 HP for two Ground players and deduct 175 HP for a rocket and 7 HP for a rifle hit. This uses isolated storage and deterministic gameplay rules. Studio pointer input and production DataStore persistence remain unverified for this fix. Medkit healing remains planned under P30.

### 2026-11-28 · Apply edits and restore the lobby button

**Save & apply** stores an edited preset and selects it for live use in one revision. **Save preset** updates the library and **Apply preset** selects a saved snapshot. The client shows Balance on lobby return and rebuilds the editor if its GUI is removed. An owner lookup outage retains the last confirmed button hint. Each request still verifies the sender's authority.

`BalanceService.spec` checks the combined action, including invalid and stale edits, permissions, round capture, restart and rollback. The two-client P26 fixture checks that Balance is hidden during combat, returns in the lobby and recovers after the editor GUI is removed. The owner edits the minimum and duration through the editor. The next round uses the resulting revision with a two-player minimum, 35 seconds of combat, 193 Ground HP and 901 aircraft HP.

The first Studio run passed the lobby and application checks. The final follow-on match timed out because the fixture reused the pre-edit three-player minimum. The fixture now carries forward the values confirmed after the editor transaction.

`python3 scripts/verify.py` passed on macOS with 97 unit tests and 102 integration tests, zero failures or skips, and both Rojo builds inspected. Roblox Studio 0.748.0.7481526 ran `StudioTestService:ExecuteMultiplayerTestAsync(2, {kind = "P26"})` with two actual clients and isolated storage. The rerun passed all six cases with zero failures or skips. The test document's 199 mapped script checksums matched the source before Play. The release document remained in Edit mode. Published cross-server verification remains pending under A3. [Verified source](https://github.com/hanegraaff/roblox-c130-extraction-shooter/commit/8efdb4da16aff78426e2c87be538e71eb2e5fd58)

### 2026-11-28 · Published owner playtest

The owner reported playing multiple rounds with two players on one new Roblox server and verified that changes to the balance settings took effect. They also confirmed the balance fix worked and accepted this scope for the P26 published playtest. The supplied `build/game.rbxlx` candidate included **Save & apply** and restoration of the **Balance** button after a round. Its SHA-256 was `b749a75732baa25cb15bbadd7445579d28b721ca1956b3605788f0bc0f4e191d`. The Roblox place version and active preset revision are unreported. [Balance fix PR #87](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/87)

The owner report satisfies the revised A3 alongside the recorded automated and Studio evidence. Published propagation across servers, persistence through a server restart and rollback remain unverified for the public release. PR #87 remains open for integration. [R25 release evidence](../requirements.md#public-launch-requirements)
