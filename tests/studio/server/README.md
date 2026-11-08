# Server TestEZ runner

This package’s `init.server.luau` maps to the test-only `ServerScriptService.ServerTests` Script. During Play it waits for the actual bootstrap and at least one real player, then runs the [server specs](../specs-server/README.md) through locked TestEZ. Startup requires a player within ten seconds.

Read `workspace:GetAttribute("ServerTestReport")` in the **server** context. Its JSON includes suite/environment/seed, discovered/passed/failed/skipped/errors and actual `clientCount`. Zero discovery, any skip/failure/error, missing readiness or a missing report is not a pass. The runner also asserts on invalid totals and sends TestEZ details to Studio Output.

Follow the [run and restart procedure](../../../docs/testing.md#run-the-studio-smoke-suites). The release mapping excludes this runner, all specs, fixtures and TestEZ.
