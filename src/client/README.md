# Client foundation

Rojo maps this package to `StarterPlayer.StarterPlayerScripts.Client`. The entrypoint waits up to ten seconds each for PlayerGui and the replicated server status, then starts a `StatusPanel`. Missing readiness data produces a useful assertion instead of silently continuing.

`StatusPanel.new(playerGui, status)` returns a [Lifecycle](../shared/README.md) controller. Construction/start do not yield. Starting owns one `FoundationStatus` ScreenGui and one `AttributeChanged` listener on the supplied status Instance. The panel displays the server’s environment and running state and labels the experience as a development shell. Stopping disconnects the listener and destroys the GUI; repeated starts/stops are idempotent. The entrypoint also stops its controller when its script is destroyed.

The GUI uses `ResetOnSpawn = false`, so normal avatar respawn does not duplicate it. It is presentation only and cannot change server authority. Input, camera, thermal, role HUD, spectating, effects and audio controllers are still planned.

[Client Studio specs](../../tests/studio/specs-client/Foundation.spec.luau) check actual replicated status, character availability, rendered environment text and two controller restart cycles. Follow the [Studio instructions](../../docs/testing.md#run-the-studio-smoke-suites) to collect the client-context report separately from the server report.
