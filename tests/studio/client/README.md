# Client TestEZ runner

This package’s `init.client.luau` maps to the test-only `StarterPlayerScripts.ClientTests` LocalScript and runs the [client specs](../specs-client/README.md) automatically during Play.

Read `Players.LocalPlayer.PlayerScripts.ClientTests:GetAttribute("ClientTestReport")` in the **client** context. JSON includes suite/environment/seed, discovered/passed/failed/skipped/errors and the actual client `userId`. A missing report, zero discovery or any failed/skipped/error case is incomplete or failed evidence. TestEZ also writes useful details to Studio Output.

Use the [Studio procedure](../../../docs/testing.md#run-the-studio-smoke-suites) to collect both context reports and stop/restart. A server report cannot replace client GUI/replication assertions. This runner and its dependencies never enter the release mapping.

After the foundational specs, `RoundHarness.run()` starts a bounded discovery task for the test-only P03 transport. Automated probes observe the actual LocalPlayer role/life/deadline, RoundHUD and spectator/lobby CameraSubject, send production surrender intent and disconnect through StudioTestService. The listener disconnects when its transport is removed. These observations supplement the two TestEZ cases; they are not additional foundation-case counts.
