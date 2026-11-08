# Authoritative server runtime

Rojo maps this package to `ServerScriptService.Server`. Rules and authority stay server-only. The entrypoint starts `Bootstrap`, then `GameRuntime` with production defaults unless the test-only `DevelopmentSettings` marker is present. In the test mapping, the runner owns gameplay startup after foundational suites finish.

## Composition and character ownership

`GameRuntime.start(settings)` starts one `MapService`, one `MatchRuntime` and one `AircraftService`, returning `{ rounds, aircraft, stop }` or `nil, reason`. Partial startup rolls back acquired owners. It injects only active living ground characters into containment with `allowStations = false`. Its idempotent `stop()` stops aircraft, rounds and then destroys the map's private snapshot. Dependencies remain explicit; there is no runtime registry.

`MatchRuntime.new(map, settings)` creates an inactive adapter exposing `start()`, `stop()`, `match` and `resources()`. `automaticDeployment` defaults true; false keeps Lobby until an authoritative explicit deploy. Settings use seconds: production defaults are minimum 6, duration 600, lobby 8, deployment 15, results 5 and seed 1. `start()` rejects conflicting round/team/collision ownership or earlier character work still draining. It disables automatic respawns and owns teams, a noncolliding character group, heartbeat, player listeners and `RoundState.Surrender`. `stop()` invalidates character work, removes owned replication/teams/listeners and returns the service to Lobby. In-flight avatar loads must drain before ownership and automatic spawning policy can safely transfer. `resources()` exposes owned connection/load counts for tests.

`CharacterOwner.new(player, match)` owns explicit avatar loading for one Player. Its nonyielding `request(anchor, role, roundId)` queues the newest intent while a serialized `LoadCharacterAsync` finishes. Tokens reject stale completions and a load lease guards handoff between runtime owners. `clear()` invalidates queued intent, disconnects listeners and destroys the body; idempotent `stop()` prevents new work. An already-yielding engine load still has to drain. Ground death/reset removes the active life; deployment death aborts; operator reset replaces only the protected placeholder body. Waiting bodies can walk and retain ForceField protection; only Gunship station bodies are anchored. All character parts use the noncolliding round group.

`MatchRuntime` publishes `RoundState` attributes for ID, revision, phase, deadline, population, living ground count and result; Player attributes carry round ID, role, life and revision. Revision is written last as a presentation marker. Surrender accepts exactly `{ roundId, sequence, action = "Surrender" }`, with an active connected ground life, current round, increasing bounded integral sequence and unexpired deadline. The remote has a four-token budget refilling at two requests/second. Clients never set roles, deadlines or results.

## Deterministic services

`RoleService.assign(candidates, minimumPlayers, previousOperatorId, seed)` returns a fresh `{ operatorId, groundIds }` or `nil, reason`. Candidates have unique integral UserIds and nonnegative completed-round wait counters. The configured minimum is an integer from 2–10; the seed is an integer from 0–2147483647. Valid population is the minimum through ten. It excludes the previous operator when alternatives exist, prefers longest wait, and breaks sorted ties deterministically. Negative IDs support Studio clients. It has no engine/network access.

`RoundRules.canTransition(from, to)` permits documented phase edges and deployment cancellation. `outcome(facts)` evaluates deadline first, then pre-deadline aircraft destruction before ground elimination, followed by participant departure policies. Empty/no-participant cleanup awards no competitive winner. These APIs neither mutate nor yield.

`MatchService.new(settings, adapters)` creates an independent owner. Settings contain minimum population, duration seconds and seed; adapters supply monotonic `now()` and nonyielding `releaseLife(userId, roundId, recover)`. Public calls never yield. Expected rejection returns `false, reason?`; invalid trusted configuration or a backward/nonfinite clock is an invariant failure.

| API | Contract |
| --- | --- |
| `join(userId)` / `leave(userId)` | Track connections by UserId. Departure cancels assigned deployment or removes an active life. Rejoin retains a tombstone; mid-round arrivals spectate. |
| `deploy()` / `ready(userId, roundId)` / `activate()` | Lock a valid roster, collect server character readiness, then activate everyone together with one deadline. Stale/duplicate readiness rejects. |
| `eliminate(userId, roundId)` | Remove one living ground life before the deadline. Stale, duplicate and wrong-role calls reject. |
| `proposeAircraftDestroyed(roundId)` | Queue a server destruction fact for the next pre-deadline batch. P03 has no damage source; later combat connects this seam. |
| `step()` | Commit at most one batch result and release life resources once. Terminal cleanup suppresses recovery; nonterminal loss may request recovery for the future launcher adapter. |
| `abort(roundId, reason)` | Commit a noncompetitive setup/runtime abort only in Deploying or Active. |
| `beginReset()` / `finishReset()` | Enforce reset transitions and clear roster/result/deadline, retaining rotation history and increasing round identities. |
| `command(userId, payload)` | Validate surrender shape, role, life, round, sequence and deadline. Rejection preserves match state. |
| `snapshot()` | Return fresh member/result records; callers cannot mutate authority. |

Batch callers submit accepted events, call `step()`, then publish. Deadline equality is too late for destruction; otherwise destruction wins a same-step mutual elimination. Cleanup adapters must not throw, yield or reenter. Current cleanup removes equipment; P08 connects actual launcher ownership/recovery.

## Aircraft ownership and selection

`AircraftService.start(match, clock?)` clones the versioned C-130 template to one `Workspace.Aircraft`, creates `ReplicatedStorage.AircraftState` and owns three connections. It rejects an existing aircraft/state owner or missing model/Hitbox with `nil, reason`. Production clock uses `GetServerTimeNow`; engine fixtures may inject finite monotonic seconds. `match` remains caller-owned. Calls do not yield.

| API | Contract |
| --- | --- |
| `sample(elapsedSeconds)` | Return canonical tangent-facing CFrame from map geometry and AircraftRules. Invalid trusted time asserts. |
| `aimAllowed(endpoint)` | Reject nonfinite/exterior/invalid-height points, then raycast actual solid Battlefield geometry and Terrain from the server Hitbox. Endpoints at the first surface allow 0.5-stud tolerance. No shot or damage is created. |
| `resources()` | Return owned live connection count for repeated-round/teardown checks. |
| `stop()` | Idempotently disconnect all ownership, destroy aircraft/state/remote and clear request budgets. |

The default 90-second orbit shares map radius/altitude, starts at phase zero and resets at deployment/Lobby. Results/Resetting freeze motion. Hitbox is the sole queryable canonical pose; named `GAU23Muzzle`/`M102Muzzle` attachments reserve server firing origins. See the [model contract](../../assets/models/README.md). No cosmetic interpolation shell, health or damage exists yet.

`AircraftSelection.new()` is a server-only deterministic owner exposing `reset(roundId, force?)`, `command(userId, payload, eligible)` and copied `snapshot()` records. It owns round/revision/weapon and per-user accepted sequence. Same-ID reset is normally a no-op; forced Lobby reset restores GAU23 and clears sequences. Commands require exactly `{ roundId, sequence, weapon }`, current positive round, bounded increasing integral sequence and `GAU23`/`M102`. Expected rejection returns `false, reason` without mutation. The engine adapter derives living connected Active/unexpired operator eligibility and applies a six-token bucket refilling four/second before calling it.

`AircraftState.Selection` atomically publishes JSON round/revision/weapon. Clients never choose canonical pose or origin, and profile selection creates no cooldown/ammunition state. P05 connects firing and must retain independent weapon readiness.

## MapService

`MapService.new(world, adapters)` expects an authored Battlefield Model under `world`, following the [world contract](../../assets/world/README.md). Adapters provide `characters(): {Model}`, Heartbeat and optional `allowStations`. Construction validates `MapRules.defaults`, actual geometry/anchors, the separate lobby, buildings and terrain descriptors with Workspace queries, then retains a private unparented pristine clone. Invalid authoring returns `nil, reason` without writing the map. `validateMap(map, settings)` uses validated settings and returns `boolean, reason?`. All public calls are nonyielding.

| API | Responsibility |
| --- | --- |
| `start()` | Validate, reconstruct bounded terrain, assign cover/building/panel/circle attributes and connect containment. Repeated starts are safe; invalid/destroyed owners reject. |
| `enforce()` | Return exterior/below-threshold living characters to Ground05 and clear velocities. The optional bounded lobby-deck exception is disabled for active ground players. |
| `stop()` / `validate()` | Disconnect containment while retaining the snapshot / query current geometry validity. |
| `rebuild()` | Restore bounded terrain, replace Battlefield from the pristine snapshot and validate. Round reset invokes this; consumers must reacquire Instances. |
| `destroy()` | Stop containment, restore pristine map/terrain and destroy the private snapshot idempotently. Later start/rebuild rejects. |

One owner controls each Battlefield subtree and its manifest-defined terrain volume. Rebuild/teardown remove transient descendants and restore source geometry. Permanent/Breakable cover and all 111 building panels remain solid; IDs reserve future destruction behavior. Containment is not a general movement anti-cheat system.

`BuildingGeometry.validate(map, overlap, rays)` is a nonyielding server adapter over real loaded Parts. It returns `false, reason` for malformed floors/stairs/markers/rooms, obstructed entry routes or invalid registries; it does not create Instances or own events. `decorate(map)` applies stable public building IDs, building-scoped `StoryId` (`01`/`02`), globally unique panel IDs, Intact state/pivot and variant metadata after validation. A story identity is the pair `(BuildingId, StoryId)`. Its pure count/dimension/pivot dependency is shared `BuildingLayout`.

`TerrainRecipe.validate(recipe)` checks the fixed, unrotated voxel-aligned ownership bounds, eight contained sphere descriptors and Grass/Rock material contract. `restore(terrain, recipe)` returns `false, reason` without writes for invalid authoring; otherwise it clears only the owned box and writes eight spheres. It owns no connections or tasks and does not yield. Actual collision/raycast readiness can follow later; callers needing physics evidence must wait for bounded engine convergence. See the [world contract](../../assets/world/README.md).

## Bootstrap and verification

`Bootstrap.new(environment)` creates a nonyielding [Lifecycle](../shared/README.md) controller. Starting validates defaults, creates one BootstrapStatus Folder and heartbeat. Attributes expose environment, running state and whole-second uptime. Stopping disconnects/destroys its resources; duplicate ownership is an invariant failure. The test-only marker selects **Test**; release uses **Development**.

[Pure/service suites](../../tests/README.md) cover deterministic policy. [Studio specs and harness](../../docs/testing.md) separately exercise Instances, replication, camera, character lifecycle and reset. Executed evidence belongs to [P03](../../plans/03-rounds-and-roles.md).
