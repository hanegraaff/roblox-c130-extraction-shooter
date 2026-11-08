# Client TestEZ runner

This package’s `init.client.luau` maps to the test-only `StarterPlayerScripts.ClientTests` LocalScript and runs the [client specs](../specs-client/README.md) automatically during Play.

Read `Players.LocalPlayer.PlayerScripts.ClientTests:GetAttribute("ClientTestReport")` in the **client** context. JSON includes suite/environment/seed, discovered/passed/failed/skipped/errors and the actual client `userId`. A missing report, zero discovery or any failed/skipped/error case is incomplete or failed evidence. TestEZ also writes useful details to Studio Output.

Use the [Studio procedure](../../../docs/testing.md#run-the-studio-smoke-suites) to collect both context reports and stop/restart. A server report cannot replace client GUI/replication assertions. This runner and its dependencies never enter the release mapping.

After the foundational specs, `RoundHarness.run()` starts a bounded discovery task for the test-only P03 transport. Automated probes observe the actual LocalPlayer role/life/deadline, RoundHUD and spectator/lobby CameraSubject, send production surrender intent and disconnect through StudioTestService. The listener disconnects when its transport is removed. These observations supplement the two TestEZ cases; they are not additional foundation-case counts.

`HumanTestPanel.start()` discovers the test-only session and creates one bottom-right Studio panel. Its role/duration/start/reset/location buttons send bounded server intent tagged with sequence and generation. Server feedback and authoritative attributes drive labels. The GUI persists through character respawn; stopping or removing the session disconnects listeners, cancels pending discovery and destroys the panel. It is never mapped into release builds.

`AircraftHarness.run()` adds P04 actual-client probes through its own excluded transport. It measures replicated canonical pose error, map presence/tangent/altitude, inward operator view, acknowledged weapon/FOV/reticle coherence, singleton ThermalHUD/effect/highlights, original FOV/mouse restoration and real LeaveTest departure. Its transport listener disconnects on removal. These observations supplement the two client TestEZ cases; rendering occlusion still requires actual visual review. Follow the [P04 procedure](../../../docs/testing.md#run-the-p04-aircraft-harness).
