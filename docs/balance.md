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

The experience owner controls the tester list. For a group-owned experience, sign in as the group owner. In **Balance → Game & lobby**, enter the tester’s numeric Roblox user ID and select **Give panel access**. Select **Remove panel access** with the same ID to remove them. The owner and trusted testers can save presets, apply them across the game and restore the previous live settings. For a private experience, testers also need permission to join it.

## Change a setting

1. Use **Choose preset** to pick a saved preset. **Shipped** contains the original values. Enter a new preset name to save your own copy.
2. Choose **Player**, **C-130**, **Buildings** or **Game & lobby**. Drag a slider or type an exact number beside it. Values stay in your draft when you switch tabs. Building damage shows the hits or firing time needed to break a wall or roof panel.
3. Select **Save preset** to store the values. Select **Apply saved preset** to make that saved version live. For example, give a preset a 30-second lobby intermission, save it as `Short breaks`, then apply it before the next result.
4. Check the live preset shown at the top. **Game & lobby** also shows the saved change number and the change used by the current round. Each server picks up changes when notified or when it next checks storage.
5. To undo an applied change, select **Undo last apply**. To return to the original values, select **Shipped**, then **Apply saved preset**.

If another tester edits while your panel is open, select **Refresh**, review their values and re-enter your change. If a save cannot be confirmed, refresh before trying again. Servers keep their last confirmed settings when storage is unavailable. A new server can start with the shipped defaults.

## What you can tune

| Setting | Shipped preset |
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
