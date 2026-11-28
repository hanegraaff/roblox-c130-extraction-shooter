# Tune the game from the lobby

After the build containing the balance panel is published, join the experience in the Roblox app and select **Balance** in the lobby. You can change the game across its servers without editing code or publishing another build. Ordinary Studio Play uses the shipped settings offline. The private two-server release check is tracked in the [panel plan](../plans/26-live-balance-panel.md).

## Try it in Studio

1. Follow the [local test setup](../README.md#run-local-automated-tests). In the **PlayersVsC130Tests** document, stop Play and enter this in Studio’s Command Bar.

   ```luau
   game.ServerStorage.DevelopmentSettings:SetAttribute("ManualHarness", "P26Panel")
   ```

2. Click **Play**. The first client is the test owner. Open **Balance** in the lobby, save a preset under a new name and apply it. These settings live only in this Studio session.
3. To try tester access, use **Server & Clients** with two clients. The test lobby initially waits for three. In the server’s Explorer, select the other Player and read its `BalanceFixtureUserId` attribute. Grant that ID from the owner’s panel. Lower the player minimum to two and apply the preset to start a match.
4. Stop the session. In Edit mode, run `game.ServerStorage.DevelopmentSettings:SetAttribute("ManualHarness", nil)` to return to ordinary tests.

## Give a tester access

The experience owner controls the tester list. For a group-owned experience, sign in as the group owner. In **Balance → Settings → Game & lobby**, enter the tester’s numeric Roblox user ID and select **Give panel access**. Select **Remove panel access** with the same ID to remove them. The owner and trusted testers can save presets, apply them across the game and delete saved presets. For a private experience, testers also need permission to join it.

## Change a setting

1. Check **Live in game** at the top. This names the settings currently selected for the game.
2. In **Saved presets**, open **Load Settings** and choose a saved preset. Loading fills the editor. Use **Settings** to choose Player, C-130, Buildings or Game & lobby, then drag sliders or enter exact values.
3. Select **Save preset** after editing to update the custom preset under its current name. Enter a new name to save a copy. **Default** requires a custom name. **Apply saved** becomes available once the editor matches a saved preset. Reopening the editor shows the saved values for the active preset, including edits awaiting **Apply saved**.
4. Select **Apply saved** to use that preset in the game. The live name at the top updates. Combat changes start next round. Medkit healing is saved for the planned pickup feature and currently has no gameplay effect.
5. Select **Delete preset** to remove the loaded preset. Live settings stay active. The name field clears. Enter a name to save another copy, or close. **Default** remains available as the built-in starting point.

To return to the original settings, load **Default** and select **Apply saved**.

If another tester edits while your panel is open, select **Refresh**, review their values and re-enter your change. If a save cannot be confirmed, refresh before trying again. Servers keep their last confirmed settings when storage is unavailable. A new server can start with the shipped defaults.

## What you can tune

| Setting | Default preset |
| --- | --- |
| Aircraft health | 1,000 HP per deployed Ground player. Three Ground players give the aircraft 3,000 HP. |
| Aircraft weapon damage | 25 HP for the 30mm and 100 HP for the 105mm. |
| Aircraft weapon timing | The 30mm fires every 0.15 seconds and reloads in 5. The howitzer fires one shell, then takes 12 seconds to reload. |
| Ground player health | 100 starting and maximum HP. |
| Ground weapon damage | Each M-7 hit deals 5 HP to the aircraft. A direct rocket deals 150 HP. |
| Ground weapon timing | M-7 shots are 0.15 seconds apart with a 2-second magazine reload. Each launcher has its own 15-second reload. |
| Medkit healing | 25 HP per kit. Each kit can be used once per round. The pickup arrives with P30. |
| Building panel damage | Medium. A panel breaks after 2 howitzer hits or 4 seconds of 30mm hits on Low, 1 hit or 2 seconds on Medium, and 1 hit or 1 second on High. |
| Combat duration | 600 seconds, starting when the aircraft arrives. |
| Lobby intermission | 120 seconds, starting when the result is announced. |
| Minimum players | 2, including the operator. The supported range is 2–10. |

**When changes take effect.** A waiting lobby uses the latest minimum player count. At deployment, the server locks combat duration, health, damage, weapon timing, panel damage and medkit settings for that round. At the result, it sets a deadline using the latest intermission length. Changing that length during a countdown takes effect at the following result.

## Slider ranges

| Setting | Allowed values |
| --- | --- |
| Rifle damage per hit | 1–50 HP |
| Time between rifle shots | 0.15–1 second |
| Rifle reload | 0.15–10 seconds |
| Rocket damage per hit | 1–5,000 HP |
| Wait between rounds | 1–300 seconds |
| Howitzer reload | 0–30 seconds |
| 30mm reload | 0–30 seconds |

Earlier saved presets load within these limits. Values outside the new ranges move to the nearest allowed value. Every new save must satisfy the current ranges.
