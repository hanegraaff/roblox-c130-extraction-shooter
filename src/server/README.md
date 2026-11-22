# Authoritative server runtime

Rojo maps this package to `ServerScriptService.Server`. Rules and authority stay server-only. The entrypoint starts `Bootstrap`, then `GameRuntime` with production defaults unless the test-only `DevelopmentSettings` marker is present. In the test mapping, the runner owns gameplay startup after foundational suites finish.

## Composition and character ownership

`GameRuntime.start(settings, groundDependencies?)` installs the managed Outpost before snapshotting the map, then starts the map, round, aircraft, destruction, gunship, ground-combat and launcher owners. It returns those owners (the map remains private), `resources()` for the frame connection count and idempotent `stop()`, or `nil, reason` after rolling back partial startup. Containment receives only active living ground characters. Stop disconnects the frame before releasing acquired owners in reverse order.

The runtime drives match, aircraft and combat through one Heartbeat. It samples synchronized server seconds, advances the aircraft pose, and calls `rounds.step(time, resolveDamage)`. The damage callback runs gunship sweeps, rifle rays and existing rocket sweeps against pre-impact cover, then flushes structural changes. The round commits its outcome and publishes state before launcher recovery and queued interactions. Standalone aircraft and combat adapters can own their own Heartbeat for focused tests. Production passes `externallyStepped = true` and drives them from the shared frame.

The current runtime owns one fixed battlefield. The future
[level contract](../../architecture.md#level-interchange-boundary-target-architecture)
will make a validated active level definition an explicit input to map, aircraft,
combat and destruction services. Every level retains one circling C-130; weapon,
health, panel progress and fragment rules stay shared rather than being copied
into level scripts. P15 owns selection/switch/reset/late-join behavior for a
second playable level.

`MatchRuntime.new(map, settings)` creates an inactive adapter exposing `start()`, `stop()`, `match`, `step(time, resolveDamage)` and `resources()`. `automaticDeployment` defaults true. With false, Lobby awaits an explicit server deployment. Production defaults are six players minimum, 600-second rounds, 8-second lobby, 15-second deployment, 5-second results and seed 1. Start rejects conflicting round/team/collision ownership or character tasks still draining. It disables automatic respawns and owns teams, a noncolliding character group, player listeners and `RoundState.Surrender`. Stop invalidates character work and removes owned replication, teams and listeners. In-flight avatar loads drain before ownership and automatic spawn policy transfer. `resources()` reports owned connections and load tasks.

`CharacterOwner.new(player, match)` owns explicit avatar loading for one Player. Its nonyielding `request(anchor, role, roundId)` queues the newest intent while a serialized `LoadCharacterAsync` finishes. Tokens reject stale completions and a load lease guards handoff between runtime owners. `clear()` invalidates queued intent, disconnects listeners and destroys the body; idempotent `stop()` prevents new work. An already-yielding engine load still has to drain. Ground death/reset, Player.CharacterRemoving or raw destruction of the owned Model consumes its active life once. The generation-scoped handler deduplicates Humanoid.Died, CharacterRemoving and Model.Destroying; direct Destroy is covered even if Player.Character still points at the unparented body. Internal clear disconnects before destruction. Deployment loss aborts; operator reset replaces only the protected placeholder body. Waiting bodies can walk and retain ForceField protection; only Gunship station bodies are anchored. All character parts use the noncolliding round group.

`MatchRuntime` publishes round ID, revision, phase, deadline, population, living ground count and result. `RoundState.Result` is one JSON attribute containing round ID, winner, reason and optional user, weapon and shot credit. It clears on replay. Player attributes carry round ID, role, life and revision. Revision is written last as a presentation marker. Surrender accepts exactly `{ roundId, sequence, action = "Surrender" }` from an active connected ground life with current round, increasing bounded integral sequence and unexpired deadline. The remote has a four-token budget refilling at two requests per second.

## Deterministic services

`RoleService.assign(candidates, minimumPlayers, previousOperatorId, seed)` returns a fresh `{ operatorId, groundIds }` or `nil, reason`. Candidates have unique integral UserIds and nonnegative completed-round wait counters. The configured minimum is an integer from 2–10; the seed is an integer from 0–2147483647. Valid population is the minimum through ten. It excludes the previous operator when alternatives exist, prefers longest wait, and breaks sorted ties deterministically. Negative IDs support Studio clients. It has no engine/network access.

`RoundRules.canTransition(from, to)` permits documented phase edges and deployment cancellation. `outcome(facts)` evaluates deadline first, then pre-deadline aircraft destruction before ground elimination, followed by participant departure policies. Empty/no-participant cleanup awards no competitive winner. These APIs neither mutate nor yield.

`MatchService.new(settings, adapters)` creates an independent owner. Settings contain minimum population, duration seconds and seed; adapters supply monotonic `now()` and nonyielding `releaseLife(userId, roundId, recover)`. Public calls never yield. Expected rejection returns `false, reason?`; invalid trusted configuration or a backward/nonfinite clock is an invariant failure.

| API | Contract |
| --- | --- |
| `join(userId)` / `leave(userId)` | Track connections by UserId. Departure cancels assigned deployment or removes an active life. Rejoin retains a tombstone; mid-round arrivals spectate. |
| `deploy()` / `ready(userId, roundId)` / `activate()` | Lock a valid roster, collect server character readiness, then activate everyone together with one deadline. Stale/duplicate readiness rejects. |
| `eliminate(userId, roundId)` | Confirm a ground death or surrender before the deadline. A confirmed death can refine a pending body-loss cause without consuming the life again. |
| `characterRemoved(userId, roundId)` | Revoke an active ground life immediately. A roster departure in the same step can account for the body loss. A body loss on its own counts as elimination. In Deploying, activation aborts for a lost body if the roster member is still connected. |
| `damageAllowed(roundId)` | Check for the active round strictly before the deadline. Within the damage callback it uses the frame's fixed server time. |
| `proposeAircraftDestroyed(roundId, credit?)` | Submit one server destruction fact, optionally copying lethal `{ userId, weapon, shotId }` credit. Stale, duplicate and expired proposals reject. |
| `step(resolveDamage?, atSeconds?)` | Run the optional damage callback strictly before expiry, then evaluate and commit at most one result. Terminal release suppresses launcher recovery. |
| `abort(roundId, reason)` | Commit a noncompetitive setup/runtime abort only in Deploying or Active. |
| `beginReset()` / `finishReset()` | Enforce reset transitions and clear roster/result/deadline, retaining rotation history and increasing round identities. |
| `command(userId, payload)` | Validate surrender shape, role, life, round, sequence and deadline. Rejection preserves match state. |
| `snapshot()` | Return fresh member/result records; callers cannot mutate authority. |

Deadline equality skips damage and awards timeout. Earlier in the round, aircraft destruction wins a same-step mutual elimination, then departure policy handles any unsettled outcome. The damage and cleanup callbacks must not throw, yield or reenter the service. The match stores one copy of terminal credit. Client intent and late combat work cannot alter it. [Timing and replay evidence](../../plans/09-match-outcomes.md)

## P06 ground combat

`GroundCombatService.new()` owns independent per-user rifle readiness and accepted sequences for the current round. `fire(userId, payload, eligible, now, originX, originY, originZ)` validates an exact bounded intent and returns a target/sequence or rejection without spending ammunition. `preflight` checks the same bounded fire intent and readiness without spending ammunition or sequence, allowing malformed or cooldown traffic to be rejected before movement, voxel and ray queries. `reload` validates active ownership and transfers reserve after the configured server-time deadline. Defaults are 30 rounds, 120 reserve, 0.15-second cadence, 2-second reload and 1200-stud range; reset clears round-local state.

`AircraftHealth.new()` owns round-scoped health and shot deduplication. Maximum health is three times direct rocket damage; current defaults are 300 and 100 units. Direct M-7 hits deal 5 units. Indirect rockets, duplicates, invalid/stale shots and post-destruction damage reject without mutation. `GroundCombatRuntime.start(match, dependencies?, externallyStepped?)` owns the rifle Tool per eligible living ground player, production fire/reload remotes, request budgets, engine world queries, shared health replication and effects. It derives the origin from the character, not the client; cover prevents aircraft damage and no ground friendly fire is awarded. The M-7 Tool includes a server-owned primitive held model that cannot collide, touch or be queried. The server resolves the first solid along the full bounded rifle ray, including cover and visible aircraft parts. Validated intent spends ammunition and queues a bounded ray. `resolveRifles()` applies the ray in the admitted combat batch. `maintain(serverSeconds)` synchronizes equipment, health and effects with the committed phase. A noninteractive visual tracer segment up to 3 studs long then travels from the server origin to the resolved endpoint at 1200 studs/second, with a 0.15-second minimum travel time (up to 1 second at maximum range) and a 0.1-second terminal hold. A brief muzzle flash appears at the held barrel. `GroundShot` records the server-awarded aircraft-hit fact and is cleared on reset. On `0ab3607`, user-operated firing and independent same-shot observations exercised visible tracers and aircraft damage; the P06 plan records that earlier source’s combat/regression evidence. The P07 plan records its separate current-source verification scope. `GroundMovementGuard.new()` samples the server-observed character root each Heartbeat and before fire; a 45-stud burst with 70 studs/second refill bounds displacement. A suspicious jump quarantines firing until the root returns within 8 studs of its last trusted point or a trusted server spawn/MapService correction resets the budget. The firing head must remain within 8 studs of the root. These are tunable defaults, not a ban or a complete movement anti-cheat; severe lag or unusual legitimate travel can temporarily block shots. `GroundOriginGeometry.new(parent)` owns an invisible nonqueryable probe; `allows(root, head)` rejects solid Battlefield BasePart overlaps at root or head and solid Battlefield/Terrain between them with rays in both directions. Terrain containment uses six-axis inward/outward collision rays plus an occupied 4-stud-voxel fallback for deep interiors. A failed Terrain query explicitly rejects firing. This conservative approach is not an exact signed-distance test for arbitrary caves; the caller must destroy the probe and unusual terrain merits further playtesting. Its server-only `validateGround(player)` shares live role, movement and origin checks with launcher pickup/fire. `rocketCast(roundId, shotId, origin, displacement, userId?)` returns the first level/aircraft collision position and whether a direct aircraft award applied. Cover stops the flight. Live rockets carry server-derived shooter credit. `rocketSweep` preserves the earlier boolean aircraft-hit fixture API, and `rocketImpact` remains a trusted server fixture seam; none is a client remote. `stop()` disconnects and destroys owned tools, remotes and effects; callers must not assume late or duplicate impacts are accepted.

These P06 capabilities are integrated on `main`. See [P06](../../plans/06-ground-combat.md) for source-specific host, two-/three-client, operated and regression evidence; the integrated P08 launcher composes player handling on the same authority.

## Aircraft ownership and selection

`AircraftService.start(match, clock?, externallyStepped?)` clones the versioned C-130 to `Workspace.Aircraft` and creates `ReplicatedStorage.AircraftState`. It rejects an existing owner, missing model or Hitbox, and invalid authored AimEnvelope with `nil, reason`. The envelope requires finite increasing limits between ground−4 and aircraft altitude and must include ground height. Startup captures those bounds for this owner. Production uses `GetServerTimeNow`. Engine fixtures can inject a finite monotonic clock. `match` remains caller-owned and calls are nonyielding.

| API | Contract |
| --- | --- |
| `step(serverSeconds)` | Update selection generation and canonical pose at trusted server time. The pose freezes once the deadline is reached or a result is committed. |
| `sample(elapsedSeconds)` | Return canonical tangent-facing CFrame from map geometry and AircraftRules. Invalid trusted time asserts. |
| `aimAllowed(endpoint)` | Reject nonfinite/exterior/invalid-height points, then raycast actual solid Battlefield geometry and Terrain from the currently acknowledged selected weapon’s server-owned muzzle attachment. Endpoints at the first surface allow 0.5-stud tolerance. No shot or damage is created. |
| `resources()` | Return owned live connection count for repeated-round/teardown checks. |
| `stop()` | Idempotently disconnect all ownership, destroy aircraft/state/remote and clear request budgets. |

The default 90-second orbit shares map radius/altitude, starts at phase zero and resets at deployment/Lobby. Results/Resetting freeze motion. Hitbox remains the canonical PrimaryPart/pivot; the P06 implementation also makes all 15 visible aircraft parts queryable while keeping every part anchored, noncolliding and nontouching. Named `GAU23Muzzle`/`M102Muzzle` attachments supply server-owned selected-weapon obstruction and firing origins. See the [model contract](../../assets/models/README.md). Shared aircraft health is provided by the P06 ground-combat owner; no cosmetic interpolation shell exists. The P06 plan records the revised aircraft query behavior’s source-specific engine, operated and regression evidence; P07 acceptance is separate.

`AircraftSelection.new()` is a server-only deterministic owner exposing `reset(roundId, force?)`, `command(userId, payload, eligible)` and copied `snapshot()` records. It owns round/revision/weapon and per-user accepted sequence. Same-ID reset is normally a no-op; forced Lobby reset restores GAU23 and clears sequences. Commands require exactly `{ roundId, sequence, weapon }`, current positive round, bounded increasing integral sequence and `GAU23`/`M102`. Expected rejection returns `false, reason` without mutation. The engine adapter derives living connected Active/unexpired operator eligibility and applies a six-token bucket refilling four/second before calling it.

`AircraftState.Selection` atomically publishes JSON round/revision/weapon. Clients never choose canonical pose or muzzle origin. Selection does not alter the independent ammunition, reload or cooldown state owned by combat.

## Gunship combat

`CombatService.new(map, minimumY, maximumY)` owns deterministic per-weapon readiness and fire sequences. `fire(userId, payload, selected, eligible, now, originX, originY, originZ)` accepts exactly `{ roundId, sequence, weapon, x, y, z }`; the caller supplies server-derived eligibility, selection, muzzle and monotonic seconds. Invalid shape, role, round, sequence, numeric bounds, target range or readiness rejects without spending ammunition or advancing the accepted sequence. `readiness(weapon, now)` returns a copy including completed automatic reload; `reset(roundId)` clears weapon state and accepted sequences when the round ID changes.

`CombatService.flight(profile, elapsed, remaining, deltaTime)` supplies the runtime with a bounded sweep distance and expiration decision from finite seconds, remaining studs and profile speed/lifetime; invalid inputs expire without movement. Host tests cover exact lifetime and distance boundaries but do not establish engine collision.

The default GAU23 profile holds 100 rounds, fires no faster than once per 0.15 seconds, reloads in 5 seconds, travels at 650 studs/second for at most 2 seconds and has 25 damage with a 4-stud blast. M102 holds one round, has a 1-second cadence, automatically reloads in 4 seconds, travels at 300 studs/second for at most 4 seconds and has 100 damage with an 18-stud blast. Both have 900-stud range limits. These are balance defaults and can change with testing. Selection changes neither weapon's independent state.

`CombatRuntime.start(match, aircraft, onImpact?, clock?, heartbeat?, structure?, externallyStepped?)` owns `AircraftState.FireWeapon`, request budgets and projectile/effect instances. `advance(serverSeconds, deltaSeconds)` resolves flights in the damage batch. `maintain(serverSeconds)` syncs round state and cancels inactive flights. `CombatViewRules.validate` first checks the request’s claimed local focus, aspect, replicated camera position and target against the permitted pan/reticle envelope. It allows a symmetric 1.25-second orbit-position tolerance plus one stud and a raster margin of 1% of the viewport per edge. This proves a view is permitted, not that it is the client’s actual view. The runtime derives the muzzle from the selected server-owned attachment and resolves flight through 0.05-stud-radius Workspace spherecasts against the level and living ground characters. A muzzle already overlapping solid Battlefield cover resolves conservatively with no splash; the BasePart overlap query does not detect Terrain containing the muzzle, a limitation for future levels. A flight with no hit is discarded. Each actual impact checks the current active round and deadline, then evaluates each living ground player through a fresh `DamageRules` shot-local ledger. `award(targetId, health, maximum, damage)` returns at most the target's current and maximum health once per target and rejects nonfinite, nonpositive or duplicate inputs without mutation. A later shot owns a fresh ledger. Direct hits damage their target; splash uses a single line-of-sight ray from just before impact to the player's root, against the level solids present before the batch flush. Initial overlaps join the same Heartbeat batch as moving projectiles; all sweeps and player-damage rays finish before structural geometry changes. Replicated `Readiness` and `Impact` are presentation facts, not client authority. Optional nonyielding `onImpact` receives round/shot ID, weapon, position, optional panel ID, server impact time and accepted `firedAt`. It must not yield, reenter or mutate colliders. When `structure` is supplied, every accepted hit/miss/expiration enters its ordered ledger and geometry is flushed only after the complete collision/damage batch. `resources()` reports owned listeners/projectiles; `stop()` disconnects, clears effects, remotes and replicated combat attributes idempotently. See the [P05 plan](../../plans/05-gunship-combat.md) for acceptance evidence and open checks.

## Progressive panel destruction

The persistent-damage revision is integrated on `main` with passing acceptance and [integration evidence](../../docs/evidence/p07-integration.md); older P07 results retain their original source scope.

`PanelDamageRules` is pure server-only arithmetic with independent `{ stage, heavySeconds, sustainedSeconds }` records. `new()` returns pristine state; `apply(state, heavy, seconds)` accepts valid nonnegative finite input and returns whether one stage advanced. `progress(state)` is stage-local (Destroyed = 1); `appearance(state)` returns Pristine, Light, Heavy or Total independently. Positive earned credit on Intact is Light. Structural stage 1 remains Heavy even with zero current-stage credit; stage 2 is Total. There is no rule API that heals earned credit on an interruption. Stage values 0/1/2 remain Intact/Damaged/Destroyed. Each stage costs nine equivalent seconds, each direct M102 hit adds three, and surplus at a completed stage is discarded. Threshold/readiness rounding tolerances remain 1e-7 / 1e-9 seconds. Calls are nonyielding.

`DestructionService.new(gapSeconds?)` owns an ordered accepted-shot ledger; the default maximum continuity gap is 0.225 seconds. `reset(roundId, panelIds)` opens a new generation and clears all earned damage, outcomes, barriers and timing anchors. `cancel()` closes the generation and discards unresolved outcomes/barriers while retaining already earned damage and appearance until reset. `resolve(outcome)` accepts server-resolved `{ roundId, shotId, weapon, firedAt, panelId? }`; malformed/stale/duplicate/unbounded outcomes return `false, reason` without mutation. Nil panel is an accepted miss/expiry/unregistered obstruction. Completion waits for earlier accepted shot IDs; at most 512 outcomes remain pending. `snapshot(id)` copies stage, appearance, credit and progress; `changed()` drains sorted changed IDs; `resources()` reports counts. No Instances, transport or global clock are used.

All earned heavy and 30mm credit persists **per panel** through pauses, misses, obstruction, changing target/weapon, reload and eligibility loss. Only same-panel consecutive GAU23 outcomes earn elapsed accepted `firedAt` intervals; every first/resumed hit earns zero. A gap above the default or an interruption breaks the continuity anchor without changing any panel’s earned credit. `interrupt(afterShotId?)` queues a barrier after the accepted prefix, allowing earlier valid in-flight outcomes to finish before breaking timing; repeated/stale barriers are idempotent and nil breaks timing immediately. Later fire cannot count paused/off-target time. Terminal cancellation rejects unfinished outcomes rather than waiting. D50–D54 define the revised acceptance, persistence, appearance and coverage; no client duration/panel ID/blast damage authorizes progression.

`DestructionRuntime.start(world, fragmentSettings?)` consumes the registry list returned by `BuildingGeometry.registries(world.Battlefield)`. This includes formal building `_Panels` folders and additional level-supplied registry descriptors, so the same thresholds apply to all structures. The integrated candidate registers 112 formal-building panels and 76 starting-shelter panels (188 total), including 26 Outpost panels. It returns an owner or `nil, reason`, without remotes or result authority. `sync(roundId)` reacquires a changed map by Instance identity and resets panel/fragment/outcome state, closing same-ID replacement to stale outcomes until a new generation. `identify(hit)` accepts only actual current registered collidable solids; visual marks, copied tags, model roots, supports and old maps return nil. Nonpanels consume miss outcomes rather than blocking ordered scoring. `resolve` changes rules only; `flush(nowSeconds)` installs geometry/appearance after all gunship, rifle and rocket collision queries in the combat frame. `cancel` closes the ledger; idempotent `stop` restores pristine panels and releases fragments/groups. Calls do not yield.

The primitive `PanelGeometry.capture(part, nil)` path keeps a pristine clone and creates a stable ID/pivot/IntactSize Model. `setStage` installs Intact, two-strip Damaged or no-solid Destroyed geometry; side strips preserve thickness and leave a central 50% opening along the longest face axis. Static supports are untouched. `publish(..., appearance)` publishes `PanelState`, `DamageAppearance`, `PanelProgress`, `HeavySeconds` and `SustainedSeconds`. Pristine retains the original material/color. Light uses slate tint and at least three charcoal face scars, increasing to seven with progress. Heavy uses a permanent darker slate base, seven pale fracture marks and real openings, including at zero local progress. D54 colors/mark dimensions are tuning defaults. Marks live in owned `DamageVisuals`, are clipped to both faces of each remaining solid, have no structural PanelId and cannot collide, touch, query or count as structural hits. Rebuild them only when the appearance/count bucket changes; stage/reset/stop remove them with the owner. Clients observe current state rather than replayed fragment events.

`PanelFragments.start(root, settings?)` owns exclusive global `PanelFragments`/`PanelStatic` collision groups and `Workspace.PanelFragments`; invalid settings or conflicting group ownership reject before mutation. `emit(pivot, size, color, nowSeconds, templates?)` creates four default server-network-owned Parts, capped at 48 with oldest-first retirement and eight-second expiry. Initial speed is at most 12 studs/second, angular speed at most 4 radians/second, dimensions at most 1.5 studs per axis and density 1, hence generated mass at most 3.375 and initial momentum at most 40.5 mass·studs/second; subsequent motion follows gravity/contact. `static(instance)` enrolls owned anchored scenery while retaining prior groups; Terrain is enrolled separately. Fragments collide only with `PanelStatic`, excluding characters and other debris, and have no damage callback. `step(nowSeconds)` expires without delayed tasks; `clear()` removes fragments; idempotent `stop()` also restores captured scenery/Terrain groups and unregisters owned groups.

Fragments set `CanQuery = false`, but a collidable Part can still participate in some query modes. Combat, movement-origin and thermal queries therefore also use explicit authoritative-world include filters and collision-group exclusions; keep those filters when adding consumers. Physical fragments never authorize cover or structural support. See [architecture](../../architecture.md#progressive-panel-destruction-p07), [asset provenance](../../assets/models/README.md) and the [P07 acceptance procedure](../../docs/testing.md#run-the-p07-destruction-harness). Required multiplayer/operated evidence is separate from module/API inspection.

## Imported material panels and Outpost reconstruction (P17)

The candidate replaces the smaller Outpost from managed imported templates and
retains primitive Foundry/Warehouse/starting-shelter panels. It registers 188
active panels. Actual native integration/performance and human approval remain
separate acceptance gates.

The generator `scripts/p17_assets.py` checks the approved Blender/catalog/lock
hashes and exports before producing trusted server-only `ApprovedOutpost` data.
The manifest binds that generated definition to its content hash.

`PanelAssetRules.geometry(size, pose, halfBounds, maximumDimensionStuds?)` accepts finite positive stud
dimensions, a rigid right-handed twelve-component CFrame and an enclosing
canonical envelope; invalid, scaled, sheared, reflected or out-of-bounds data
returns false without mutation. `receipt(value)` accepts a lowercase SHA-256
identifier. The dimension limit defaults to 40 studs and may be explicitly set
up to 64 for reconstruction support. Neither API yields or proves cloud availability.

`PanelAssetCatalog.load(root)` returns `Catalog` or `nil, reason` without writes.
The root is `ServerStorage.Assets.MaterialPanels`, with approved revision,
Blender hash and import-receipt hash attributes. It requires all six family
folders, four named appearance Models and four indexed fragment MeshParts per
family. Each source path/hash must match the generated definition. Canonical
Roblox face axes are X/Y, thickness Z. Cosmetic mesh/texture references must be
nonempty asset IDs, geometry must fit the approved bounds, and scripts,
unexpected content, duplicate names or colliding/queryable/touchable cosmetics
reject. Runtime material checks use shared `AssetMaterial.read`: exactly one
SurfaceAppearance and its readable compiled v1 attributes, with mesh/surface
MaterialKey agreement and bounded references/PNG digest. Ordinary game code never
reads protected SurfaceAppearance map slots or Content variants. Compiler and
artifact/Edit audits bind real serialized slots to the attributes and approved
receipt. Actual content loading, ownership/access and appearance remain separate
preload/import/render observations.

`MaterialPanelGeometry.validate(model, family)` checks the pristine Model's
canonical geometry and complete exact proxy set, rejecting phantom solids.
The larger attachment allowance applies only to a MeshPart explicitly marked
PanelAttachment with AttachmentPanelId equal to the owning panel's name: each
dimension is at most 64 studs and all canonical bounds fit a 32-stud half-envelope.
Ordinary panel geometry retains the 40-stud default and its family-specific bounds;
attachment allowance never makes dressing solid/queryable/touchable.
`basis(model)` validates the optional rotation-only `PanelAssetBasis` attribute;
`identitySize(family, basis)` computes its stable identity-frame dimensions.
`install(model, materialPivot, family, appearance, identityPivot?, attachments?)`
replaces caller-owned children with the selected cosmetic meshes and authoritative
rectangle proxies. It preserves a separate legacy identity pivot when supplied.
Pristine/Light restore panel-owned attachments from the captured original;
Heavy/Total remove that dressing, and Total leaves no solids.
`progress(model, fraction)` tints original imported colors within a stage without accumulating repeated tint or changing solidity.
These APIs are nonyielding and use already validated trusted family data.

`PanelGeometry.capture(partOrModel, family?)` preserves a primitive Part or
validated material Model in the same stable panel lifecycle. Material Models
require a family, identity/pivot and IntactSize. Publish selects their approved
appearance and replicates the same stage/progress/credit attributes; primitive
panels retain generic scars and two-strip residuals. `DestructionRuntime.start`
preflights registered IDs and the material catalog/proxies before acquiring
fragment collision groups. Shared `AssetMesh.validate` additionally requires
public native MeshSize/collision/render fidelity to match five compiled native
attributes; a MeshId/Size-only object cannot pass as reconstructed native art. Damage timing and ordering remain in the existing
shared rules and service; no new client remote selects materials or panels.

`PanelFragments.emit(pivot, size, color, nowSeconds, templates?)` optionally
clones validated material MeshParts through the existing count, mass, impulse,
query, ownership, expiry and reset/stop bounds. Captured pristine Models and
collision groups restore through the same owner teardown. The controlled
MaterialPanels fixtures use empty cosmetic meshes; separate
Outpost fixtures use the actual managed templates. Each needs fresh native
reports and remains distinct from operated texture/UV, navigation, rendered
cover and multiplayer acceptance.

`OutpostReconstruction.prepare(assets)` returns an unparented site-positioned
Model or `nil, reason`, without world writes. It validates imported catalog,
managed revision/receipt, exact floor/internal-stair support geometry, mesh/material
references, compiled material metadata and public native intrinsics/fidelities, inert content, unique component IDs
and 26 pristine panel Models.
`install(world, assets)` replaces only `Battlefield.Buildings.Outpost` and returns
`{ commit, rollback }` or `nil, reason`. Both closures are nonyielding/idempotent;
commit releases the original, rollback restores it before snapshot acceptance.
An already installed approved revision is preserved, including live damage.
`GameRuntime` installs before `MapService.new`, rolls back if map construction
rejects, then commits once the map owns its pristine snapshot. Subsequent resets
reconstruct that snapshot and require fresh panel references.

The managed templates contain twelve repaired base-color texture maps. Source
roughness/metalness/emission scalars are metadata rather than equivalent
SurfaceAppearance maps; the resulting material finish requires explicit A6 review.
The compiler also preserves genuine engine InitialSize, PhysicalConfigData,
PhysicsData and AeroMeshData from 407 managed native profiles across 2,332 uses.
It never invents payloads from target sizes. Public runtime checks remain separate
from host payload audits and actual rendered/contact/replication acceptance.
Import owner/IDs and deterministic reconstruction receipts are documented in the
[asset package](../../assets/imports/military-outpost/README.md).

## MapService

`MapService.new(world, adapters)` expects an authored Battlefield Model under `world`, following the [world contract](../../assets/world/README.md). Adapters provide `characters(): {Model}`, Heartbeat and optional `allowStations`. Construction validates `MapRules.defaults`, actual geometry/anchors, the separate lobby, buildings and terrain descriptors with Workspace queries, then retains a private unparented pristine clone. Invalid authoring returns `nil, reason` without writing the map. `validateMap(map, settings)` uses validated settings and returns `boolean, reason?`. All public calls are nonyielding.

| API | Responsibility |
| --- | --- |
| `start()` | Validate, reconstruct bounded terrain, assign cover/building/panel/circle attributes and connect containment. Repeated starts are safe; invalid/destroyed owners reject. |
| `enforce()` | Return exterior/below-threshold living characters to Ground05 and clear velocities. The optional bounded lobby-deck exception is disabled for active ground players. |
| `stop()` / `validate()` | Disconnect containment while retaining the snapshot / query current geometry validity. |
| `rebuild()` | Restore bounded terrain, replace Battlefield from the pristine snapshot and validate. Round reset invokes this; consumers must reacquire Instances. |
| `destroy()` | Stop containment, restore pristine map/terrain and destroy the private snapshot idempotently. Later start/rebuild rejects. |

One owner controls each Battlefield subtree and its manifest-defined terrain volume. Rebuild/teardown remove transient descendants and restore source geometry. Permanent/Breakable cover remains solid. MapService reconstructs all registered panels pristine, including the candidate starting shelter; DestructionRuntime consumes their registry and owns their live damage geometry. Containment is not a general movement anti-cheat system.

`BuildingGeometry.registries(map)` returns fresh `{ buildingId, panels, storyId? }` descriptors or `nil, reason`, without writes or yielding. Formal buildings use their named `_Panels` folder and infer story from stable IDs. Additional `Battlefield.PanelRegistries` StringValues use Name = building identity and Value = a **direct child Folder name** under Battlefield, with default StoryId `01`; values are not recursive paths. The candidate `SpawnShelter` descriptor names `SpawnShelterPanels`. Reject missing/nonfolder/empty roots and duplicate/malformed identities. Core damage consumers iterate these descriptors rather than naming/counting buildings themselves.

`BuildingGeometry.validate(map, overlap, rays)` is a nonyielding server adapter over real loaded Parts. It returns `false, reason` for malformed floors/stairs/markers/rooms, obstructed entry routes or invalid registries; it does not create Instances or own events. `decorate(map)` applies stable public building IDs, building-scoped `StoryId` (`01`/`02`), globally unique panel IDs, Intact state/pivot and variant metadata after validation. A story identity is the pair `(BuildingId, StoryId)`. Its pure count/dimension/pivot dependency is shared `BuildingLayout`.

`TerrainRecipe.validate(recipe)` checks the fixed, unrotated voxel-aligned ownership bounds, eight contained sphere descriptors and Grass/Rock material contract. `restore(terrain, recipe)` returns `false, reason` without writes for invalid authoring; otherwise it clears only the owned box and writes eight spheres. It owns no connections or tasks and does not yield. Actual collision/raycast readiness can follow later; callers needing physics evidence must wait for bounded engine convergence. See the [world contract](../../assets/world/README.md).

## Bootstrap and verification

`Bootstrap.new(environment)` creates a nonyielding [Lifecycle](../shared/README.md) controller. Starting validates defaults, creates one BootstrapStatus Folder and heartbeat. Attributes expose environment, running state and whole-second uptime. Stopping disconnects/destroys its resources; duplicate ownership is an invariant failure. The test-only marker selects **Test**; release uses **Development**.

[Pure/service suites](../../tests/README.md) cover deterministic policy. [Studio specs and harness](../../docs/testing.md) separately exercise Instances, replication, camera, character lifecycle and reset. Executed evidence belongs to [P03](../../plans/03-rounds-and-roles.md).


## Single launcher (P08)

`LauncherService.new()` creates a pure, nonyielding server-only owner. Coordinates are studs and time is injected monotonic server seconds. It owns one round identity, copied snapshots, accepted per-user sequences, owner, position, shot serial and reload deadline; clients never own these records.

| API | Contract |
| --- | --- |
| `reset(roundId, anchor)` / `clear()` | A different positive round creates one Available identity/readiness state. Same-round reset cannot refill it. Clear makes that identity Inactive and removes ownership. |
| `snapshot(now)` | Fresh copied round/identity/state/owner/position/revision/readiness view; callers cannot mutate authority. |
| `preflight(userId, payload, action, eligible, now)` | Exact bounded shape, current round/identity, integral increasing sequence and action ownership/readiness checks without mutation. Expected rejection returns nil. Caller supplies trusted eligibility/world checks. |
| `pickup(...)` / `drop(...)` | Atomic claim or Held → Recovering transition; expected rejection returns false without spending sequence/ownership/readiness. |
| `recover(userId)` / `place(position)` | Idempotently remove the matching carrier, then finish recovery at an adapter-validated position. Reload and replay history stay on the identity. |
| `fire(...)` | After caller-established equipped/origin authority, validate the finite bounded target, spend one rocket and set its four-second reload deadline. Returns accepted intent/unique shot ID, or nil on rejection. |

`LauncherRuntime.start(match, groundCombat, externallyStepped?)` requires the validated current level and existing ground authority; duplicate LauncherState ownership returns `nil, reason`. It owns `ReplicatedStorage.LauncherState` with Pickup/Drop/Fire remotes, one JSON Snapshot, LastShot/LastImpact observations and `Workspace.LauncherEffects`. Pickup/Drop require exactly `{roundId, sequence, launcherId}`; Fire adds exactly finite target `x`, `y`, `z`. A shared per-player eight-token budget refills six/second, and the pending queue caps at 32. `advance(serverSeconds)` sweeps existing flights within the damage batch. `interact(serverSeconds)` runs recovery and queued requests after outcome evaluation. Terminal state cancels pending work and suppresses transfers. All gameplay callbacks are nonyielding.

Pickup/fire reuse `groundCombat.validateGround`; pickup additionally checks eight-stud reach and a clear Battlefield/Terrain sight line. Fire requires the actual equipped held Tool and derives origin from the server-observed head. Linear rockets travel at 240 studs/second, sweeping a 0.2-stud sphere through the first solid via `rocketCast`; expiry is five seconds or 1200 studs. Only a direct aircraft collision applies the existing deduplicated 100-unit rocket award. A dead shooter’s flight can continue while the round remains active; terminal/new-round/stop cancels it.

`LauncherGeometry` constructs original primitive held/pickup representations and performs level-solid queries. Cosmetics cannot collide, touch or enter weapon queries. Recovery uses a last trusted supported position: bounded downward support ray, slope and upright 4×6×4-stud clearance checks, otherwise the authored anchor. Death, character removal, voluntary drop and disconnect preserve the same identity/reload. Anchors are reacquired after map reset. The runtime creates a fresh weapon for the next round; it never creates ammo items.

The runtime exposes fresh `snapshot()`, bounded `resources()` diagnostics and idempotent `stop()`. Stop disconnects observers, invalidates deferred work and destroys all owned transport, models, tools, flights and requests. `GameRuntime` stops it before the ground damage owner. The [P08 record](../../plans/08-rocket-launcher.md) links eleven passing native cases on harness `07e77ea` against production/UI `ef7826b`, with three actual initial/peak clients and two after intentional carrier Kick. D59 removes unsupported actual same-identity reconnect from acceptance; runtime rejoin protections remain covered by service tests. The supported P08 checks pass and the source is integrated on `main`; the [main integration record](../../docs/evidence/p08-p16-main-integration.md) identifies its matching tree.

## Combat workload diagnostics

Server-only, nonyielding `resources()` calls return fresh counts for Studio
observations. `GroundCombatRuntime` reports connections, tools, queued rifle
intents, lifetime queue peak and live tracers. `LauncherRuntime` reports
connections, representations, flights, queued requests, lifetime queue peak
and effect instances. Each queue is capped at its published
`queueCapacity` of 32. Queue peaks describe the runtime owner's lifetime,
so replay compares live counts to the Lobby baseline separately from peaks.

`CombatRuntime` counts connections, live projectiles and owned effect
instances. `DestructionRuntime` counts registered panels, fragments, queued
outcomes and interruption barriers. `DestructionService.outcomeWindow` is
512 accepted-shot positions beyond the next unresolved shot. The pending
outcome count is bounded at 512 and the barrier count at 513. The Studio
harness reads these snapshots at load and after cleanup.
[P11 procedure](../../docs/testing.md#run-the-p11-performance-harness)

`GameRuntime` owns the server-to-client `RoundState.WeaponAudio` transport. The combat runtimes emit shot and impact cues after admission or collision through a nonyielding callback. The event owns no client-request handler and has no role, damage or equipment authority.
