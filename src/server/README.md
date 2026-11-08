# Server foundation

Rojo maps this package to `ServerScriptService.Server`. The `init.server.luau` entrypoint starts one `Bootstrap` and registers its stop callback with `BindToClose`. There are no gameplay remotes or round/combat services yet.

`Bootstrap.new(environment)` creates a nonyielding [Lifecycle](../shared/README.md) controller. Starting validates `Config.defaults`, creates one `ReplicatedStorage.BootstrapStatus` Folder, and connects one Heartbeat listener. Attributes expose `Environment`, `Running` and elapsed whole `UptimeSeconds`. Stopping disconnects the listener and destroys the Folder. Another owner with the same status name is an internal invariant failure; stop the current owner before replacing it.

The entrypoint chooses **Test** only when server-only `ServerStorage.DevelopmentSettings` is present in the test mapping; otherwise it chooses **Development**. The fixture’s future two-player minimum is not consumed by the shell. No client request selects this environment, and the release artifact excludes that fixture.

[Server Studio specs](../../tests/studio/specs-server/Foundation.spec.luau) load actual shared modules, exercise repeated bootstrap lifecycle, and check the authored spawn with a real raycast. [Testing instructions](../../docs/testing.md) explain the separate automatic server runner and JSON report. Gameplay services will be added with their plans, retaining server ownership of state and explicit cleanup.
