# P26 — Live balance panel

**Depends on** P25. **Requirements** R25. [Roadmap](../roadmap.md#public-mvp-launch) · [Requirements](../requirements.md)

You and trusted testers can save balance changes from inside the published game. This panel is required for public launch. Ship it once, then tune the supported settings without editing files or publishing another build.

## Settings in the panel

| Control | What you change |
| --- | --- |
| Airplane health | Health per deployed Ground player. Show the total for the current roster. The starting value is 1,000 per player. |
| Airplane damage | Separate damage to Ground players for the 30mm and 105mm. |
| Airplane weapon cooldown | Time between shots and reload time for each aircraft weapon. Show the resulting wait to fire. |
| Player health | Starting and maximum health for a deployed Ground player. |
| Player damage | Separate damage to the aircraft for the M-7 and the rocket launcher. Start at 5 and 150. |
| Player weapon cooldown | M-7 shot interval and magazine reload, plus launcher reload per launcher. Start at 0.15, 2 and 15 seconds respectively. |
| Medkit health amount | Health restored by a kit, capped at the player’s maximum. P30 connects the pickup to this setting. |
| Panel damage | Low, Medium or High damage to building panels. Show how many direct 105mm hits and how much sustained 30mm fire will open a fresh panel. Medium starts at one hit or two earned seconds. High shortens the 30mm time. Low makes cover last longer. |
| Round duration | Length of combat, starting at aircraft arrival. Default 10 minutes. |
| Lobby intermission | Wait between rounds, measured from the result. Default 120 seconds. Use the latest confirmed value when an intermission starts and show the same countdown to everyone. |
| Minimum players | Eligible players needed to deploy, from 2 to 10 including the operator. Default 2. A waiting lobby checks the new minimum as soon as its server receives the revision. |

## Work

- Put the panel in the lobby. Let the owner manage trusted Roblox user IDs. Both the owner and trusted testers can save, apply and restore named presets. Show units, allowed ranges, who saved a change, and the active and pending revisions.
- Start from the shipped settings. Wire all eleven controls to the server systems that use them. Include single-use mode and optional respawn delay alongside the medkit heal amount for P30. Keep the four launcher identities and their independent clocks.
- The server checks permissions on every read of private admin data and every write. Validate finite values, bounds and relationships, including panel stage order and durations. Keep ordinary players’ HUD values in sync with the server. Ship the restricted panel separately from the Studio-only test controls.
- Save versioned settings with a conditional DataStore update. Detect concurrent edits, retain the last good preset and make rollback a new revision. Notify other servers after saving and refresh from storage during lobby waits and before deployment to recover missed messages, including a lowered minimum in a waiting server. Capture one validated preset for the whole round. If storage is unavailable, show the last confirmed revision and retry. New servers can fall back to the shipped values. [Roblox data stores](https://create.roblox.com/docs/cloud-services/data-stores) · [Cross-server messaging](https://create.roblox.com/docs/cloud-services/cross-server-messaging)

Use the same preset in MatchRuntime, the character and aircraft health owners, CombatService, GroundCombatService, LauncherService and PanelDamageRules. Keep persistent partial panel damage and covered-player protection at every setting. Apply the selected panel damage to direct hits and the existing eligible splash contacts. A higher setting must never require more hits or firing time.

## Acceptance

1. **A1 · Settings and permissions.** Unit and service tests cover baseline equivalence, each setting family at both limits, malformed values, owner grants/revocations, an ordinary player attempting a write, and two testers saving from the same revision. Rejected writes leave the saved revision intact.
2. **A2 · Round behavior.** In Studio, run Ground and operator clients. Apply a preset mid-round, then replay. Confirm old and new damage, health, cooldown and panel thresholds on the correct rounds, including actual server damage and HUD values. Check interrupted panel credit and independent launcher cooldowns. Cover failed persistence, missed notifications and rollback with controlled adapters.
3. **A3 · Published panel.** In an authorized private test experience, use an owner, a trusted tester and an ordinary player across two server instances. Save a visibly different preset, verify it at the next deployment in both servers and after a fresh server starts. Restore the previous preset and verify another deployment. Record build and revision numbers with account details redacted.

4. **A4 · Lobby and clock.** With two clients waiting and a minimum of three, lower the minimum to two. Verify ordinary deployment starts after the lobby wait. Raise it again once deployed and finish the match. Reject 1, 11 and fractional counts. Set a short combat duration and verify the deadline from arrival, independent of Scatter and intermission. Change intermission to 30 seconds before the result. Check that both clients count down from the committed result time, deployment waits at least 30 seconds, and the population rule still applies. Edit again during that countdown and observe the new duration on the following intermission.
5. **A5 · Setting coverage.** For each table row, save a non-default value, read it back and measure the gameplay effect. Exercise all four weapons, all three panel presets and both health values. Verify medkit values persist in P26 and observe actual healing in P30. Test local defaults and a saved revision after restart.

Run the applicable [project checks](../docs/testing.md) and record the source revision, environment and observed results for each criterion.

## Documentation

Add a short owner guide covering tester access, live edits, when changes apply, and rollback.

## Completion record

Planned checks have no results yet.
