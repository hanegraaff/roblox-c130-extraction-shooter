# Client status, round HUD and spectating

Rojo maps this package to `StarterPlayer.StarterPlayerScripts.Client`. The entrypoint waits up to ten seconds each for PlayerGui and bootstrap status, then starts `StatusPanel`. It attaches one `RoundPanel` to RoundState and replaces it when the server owner changes. Removal/script destruction releases owned controllers and listeners. Missing initial readiness produces an assertion instead of silent startup.

`StatusPanel.new(playerGui, status)` returns an idempotent [Lifecycle](../shared/README.md) controller. Starting owns one FoundationStatus ScreenGui and attribute listener displaying environment/running state. Stopping disconnects and destroys both. ResetOnSpawn is false so character replacement cannot duplicate the panel.

`RoundPanel.new(player, playerGui, state)` returns a nonyielding lifecycle controller. Starting owns one RoundHUD, a **Surrender / spectate** button, heartbeat and destruction listener. The HUD displays phase, role/life, ground count, result and a countdown from the authoritative deadline using GetServerTimeNow. The button appears only for living active ground players and sends the current round ID with an increasing per-round sequence; server validation decides whether it takes effect.

During Active, eliminated players and late spectators follow the lowest-UserId living ground teammate. Without a target, the camera uses a fixed map overview. Lobby resumes the local character camera. Stop restores Custom camera mode and the local Humanoid when available, disconnects listeners and destroys the HUD. The entrypoint reattaches on server owner replacement rather than keeping stale state.

These controllers present server facts; they do not assign roles, grant lives or commit results. The operator still has a protected placeholder avatar camera. Aircraft/thermal cameras, weapon HUD/input, spectator target selection, effects and audio remain planned.

[Foundation client specs](../../tests/studio/specs-client/README.md) cover bootstrap replication and status-panel lifecycle. The test-only [RoundHarness](../../tests/studio/client/RoundHarness.luau) checks actual role/deadline/HUD replication and spectator/lobby CameraSubjects across clients. Follow the [testing guide](../../docs/testing.md) for execution and evidence requirements.
