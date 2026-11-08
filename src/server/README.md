# Server runtime and map ownership

Rojo maps this package to `ServerScriptService.Server`. The entrypoint constructs/starts one `MapService`, then one `Bootstrap`, and registers their cleanup with `BindToClose`. There are no gameplay remotes, roles or round/combat services yet.

## MapService

`MapService.new(world, adapters)` expects an authored `Battlefield` Model under `world`, with the [world contract](../../assets/world/README.md). Adapters supply `characters(): {Model}` and a Heartbeat signal. Construction validates the public `MapRules.defaults` and actual geometry/anchors using Workspace queries (a 4×5.5×4-stud anchor box and a four-stud downward support ray), then retains a private unparented pristine clone. Invalid authoring returns `nil, reason`; construction does not write to the authored map. `validateMap(map, settings)` uses already-validated map settings and returns `boolean, reason?` without changing the map. All APIs are nonyielding and server-only.

The controller exposes:

| API | Responsibility |
| --- | --- |
| `start()` | Validate the current map, assign cover ID/kind and circle attributes, then connect one containment listener. Repeated starts are safe; invalid/destroyed owners return `false, reason`. |
| `enforce()` | Inspect injected living characters; return exterior or below-threshold characters to the captured Ground05 pose and clear root velocities. Permit the bounded authored lobby deck station. Does nothing after destruction. |
| `stop()` | Disconnect containment idempotently; retain geometry/snapshot for a later start. |
| `validate()` | Query current owned map validity and return `boolean, reason?`. |
| `rebuild()` | Destroy the current Battlefield subtree, clone the pristine snapshot, restore attributes and validate. Consumers must reacquire Instance references. No automatic round reset exists yet. |
| `destroy()` | Stop containment and destroy the private snapshot idempotently. Keep authored world geometry; future start/rebuild calls reject. |

Use one owner per Battlefield subtree. Temporary content inside that subtree is intentionally removed by rebuild; unrelated objects outside it are not owned. The station exception is provisional until role/deployment logic arrives and is not a general movement anti-cheat system. Cover labels reserve future behavior: both Permanent and Breakable parts remain solid today.

## Bootstrap

`Bootstrap.new(environment)` creates a nonyielding [Lifecycle](../shared/README.md) controller. Starting validates `Config.defaults`, creates one `ReplicatedStorage.BootstrapStatus` Folder, and connects one Heartbeat listener. Attributes expose `Environment`, `Running` and elapsed whole `UptimeSeconds`. Stopping disconnects the listener and destroys the Folder. Another owner with the same status name is an internal invariant failure; stop the current owner before replacing it.

The entrypoint chooses **Test** only when server-only `ServerStorage.DevelopmentSettings` is present in the test mapping; otherwise it chooses **Development**. The fixture's future two-player minimum is unused. No client request selects this environment, and the release artifact excludes that fixture.

[Server Studio specs](../../tests/studio/specs-server/README.md) cover shared imports, bootstrap lifecycle, real map queries, containment and rebuilds. [Testing instructions](../../docs/testing.md) distinguish those required engine runs from the host gate and explain the automatic JSON reports.
