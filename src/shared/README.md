# Shared rules and lifecycle modules

Rojo maps this package to `ReplicatedStorage.Shared`. Its rule modules are strict, deterministic and nonyielding, with no services, global clock or mutable singleton authority state. `AssetMaterial` and `AssetMesh` are nonyielding Instance adapters shared by ordinary server/client code. Replication makes all of this code public; server adapters must still validate every action. Authoritative role/round services live in the [server package](../server/README.md).

| Module / API | Contract |
| --- | --- |
| `AssetMesh.validate(mesh)` | Returns `boolean, reason?` by comparing public MeshSize/collision/render fidelity with five compiled native attributes. It does not fetch assets, read protected payloads, mutate Instances or prove rendered bounds/physics contacts. |
| `AssetMaterial.read(mesh)` | Returns a compiled material record or `nil, reason` from exactly one SurfaceAppearance and readable v1 attributes. It never reads protected map properties, yields, caches, mutates Instances or proves content availability. |
| `Validation.isFinite(value)` | Accepts finite numbers, including zero; rejects NaN, infinity and nonnumbers. |
| `Validation.inRange(value, minimum, maximum)` | Inclusive finite bounds; malformed bounds reject. |
| `Validation.flatPayload(value, maxFields, maxStringBytes)` | Accepts plain flat string-keyed tables of finite numbers, strings or booleans. Rejects metatables, nested/cyclic values and excess fields/bytes. Bounds must be integral: fields 0–1024, bytes 0–65536. |
| `Config.validate(value)` | Returns a fresh typed settings record or `nil, reason`, without mutating input. Integral population is 6–10 with minimum ≤ maximum; duration is 1–3600 seconds. Frozen defaults are 6/10/600. |
| `RateLimit.new(capacity, refillPerSecond, nowSeconds)` | Returns a full independent bucket or `nil, reason`. Capacity is 1–1000 tokens; refill is 0.001–1000 tokens/second; time must be finite. |
| `RateLimit.take(bucket, nowSeconds)` | Consumes one token when ready, using injected monotonic seconds. Rejected requests leave tokens and timestamp unchanged; no global timer or task is created. |
| `MapRules.validate(value)` | Returns a fresh typed map contract or `nil, reason`. Requires finite fields, radius >8 studs, altitude >16 studs, kill threshold below ground, matching map/orbit centers/radii and a focus at ground-level center. |
| `MapRules.inside(settings, x, z)` | Includes the exact disk edge and rejects nonfinite coordinates; the caller separately checks vertical position. Takes validated settings and does not mutate them. |
| `MapRules.orbit(settings, phaseRadians)` | Returns X/Y/Z for the matching perimeter at ground plus altitude. Requires validated settings and a finite phase in radians; spawns no aircraft. |
| `BuildingLayout.validate(buildings)` | Returns `boolean, reason?` without mutation for the exact two-large/one-small two-story layout, sixteen stair treads, unique IDs, finite twelve-component pivots and complete exterior/roof/interior panel counts. An explicitly versioned Outpost v2 descriptor permits the approved additional partition while retaining the existing exterior/roof count contract. The base world retains v1; candidate Outpost reconstruction installs the approved v2 descriptor. This pure authoring contract does not establish actual loaded clearance or navigation. |
| `AircraftRules.validate(value)` | Copies valid period/FOV settings or returns `nil, reason`. Period is 10–3600 seconds; FOVs satisfy `1 <= fov30mm < fov105mm <= 120` degrees. Current orbit/view defaults are 90 seconds, 30° and 40°. |
| `AircraftRules.pose(map, settings, elapsedSeconds)` | Returns perimeter X/Y/Z, tangent X/Z and wrapped phase in radians. Injected finite positive/negative times wrap periodically; invalid map/settings/time or derived nonfinite position returns nil. |
| `AircraftRules.fov(settings, weapon)` | Returns the validated profile FOV for `GAU23`/`M102`, or nil for an unknown ID. `names` contains their exact player-facing equipment names. |
| `AircraftRules.aimAllowed(map, x, y, z, minimumY?, maximumY?)` | Rejects nonfinite/overflowing geometry, invalid height limits and endpoints outside the inclusive playable disk/envelope. Optional bounds default to ground−1 / ground+32 studs; the server supplies validated authored values. This geometry predicate does not prove line of sight. |
| `AircraftPanRules.raster(pointerX, pointerY, width, height)` | Returns fresh integer pixel coordinates inside the central 70%, or nil for nonfinite inputs or viewport dimensions below two pixels. Clamps to ceil(15%) / floor(85%) and rounds once; the renderer uses this viewport pixel pair for the camera ray/diagnostic attributes and converts it to GUI-local drawing coordinates using the measured safe-area origin. Mouse/touch aim pixels do not command camera pan. |
| `AircraftPanRules.viewFits(map, localFocus, aspect, fovDegrees)` | Requires the four centerline rays at 25%/75% of the viewport to intersect the flat playable disk with a two-stud inset. Corner rays must point downward and camera pitch cannot exceed the 80° tuning limit. Invalid input rejects. Terrain/roofs may intercept rays earlier; curved edges can appear farther inside the corners. |
| `AircraftPanRules.backdropHalfExtent(map)` | Returns the half-size in studs for the camera-only visual ground backdrop, or nil for an invalid map. The inscribed disk contains the bounded corner rays at every orbit phase. |
| `AircraftPanRules.recenter(map, aspect, fovDegrees)` / `supportedFov(map, aspect, requestedDegrees)` | Return a fresh safe orbit-local reset focus and the largest usable wide lens (down to 15° for unusual ultra-wide viewports), or nil when no safe view exists. Current desktop/phone layouts retain the configured 40° wide lens. |
| `AircraftPanRules.step(map, localFocus, right, up, deltaSeconds, blocked, aspect, wideFovDegrees)` | Integrates signed WASD/touch axes in the aircraft's rotating local frame. Positive right follows the rendered camera's RightVector and decreases orbit-local Z; negative right increases it. Positive up looks farther across the level. Axes are finite −1…1; diagonals normalize, negative time rejects, and each update caps time at 0.1 seconds and speed at 120 studs/second. Each axis clips at the quarter-screen edge limit. Blocked/neutral input holds local focus. |
| `AircraftPanRules.worldFocus(map, localFocus, aircraftX, aircraftZ)` | Rotates held local X/Z focus into a world ground point using the server-owned aircraft orbit position; it does not change aircraft pose. As the C-130 circles, the same relative view reveals a new part of the level without the near-vertical world-target spin. |
| `Lifecycle.new(components)` | Returns `start()`, `stop()` and `isRunning()` closures for an independent controller. Repeated starts/stops are safe. Partial start failure cleans earlier components in reverse order and returns `false, reason`. |

Lifecycle components are nonyielding functions that return nonthrowing cleanup callbacks. Keep their list stable, do not reenter the controller, and release every owned task/listener/Instance in cleanup. A component that allocates resources before throwing must clean its own partial allocation; the controller can only roll back callbacks it has received.

`Config`, `RateLimit`, `MapRules`, `AircraftRules` and `AircraftPanRules` import their shared dependencies through `script.Parent` in Studio and a relative path under Lune. This explicit two-runtime branch is limited to dependency loading. The same [unit cases](../../tests/unit) run against filesystem-loaded modules in Lune and Instance-loaded modules in the Studio server wrapper. [Lifecycle integration cases](../../tests/integration/Lifecycle.spec.luau) use controlled resource adapters.

These helpers provide structural guards and rate accounting. MatchService/MatchRuntime add role, life, round, sequence and rate checks for surrender; AircraftSelection/AircraftService add them for operator profile changes and expose a server aim/solid-sight-line seam. The P05 server combat adapters add role, selection, aim/range, cadence, collision and damage checks; shared code is never a security boundary.


## Compiled material metadata

`AssetMaterial.read(mesh: MeshPart)` works in ordinary server and client contexts.
It requires exactly one real SurfaceAppearance, `MaterialMetadataVersion = 1`,
and matching nonempty `MaterialKey` on the mesh/surface. The surface carries
`CompiledColorMap`, `CompiledNormalMap`, `CompiledRoughnessMap`,
`CompiledMetalnessMap` and `CompiledColorPngSha256`. Color is a required canonical
`rbxassetid://` reference; the other maps may be empty strings. The PNG digest is
64 lowercase hex characters. Missing, duplicated or malformed contracts return
`nil, reason`; valid output has `key`, `colorMap`, `normalMap`, `roughnessMap`,
`metalnessMap` and `colorPngSha256`. There is no cleanup ownership or hidden state.

These are public compiled attributes, not an authority or secrecy boundary.
SurfaceAppearance map properties and their Content variants are protected and
must not be read by ordinary game code. The compiler and artifact/Edit audits
bind actual serialized map slots to this metadata and the approved source PNGs.
Metadata matching, authoring-slot comparison, Instance-based preload and rendered
appearance are separate observations. Neither metadata nor a successful return
proves asset ownership/access, loading, UV orientation or visual approval.


## Compiled native mesh construction

`AssetMesh.validate(mesh: MeshPart)` requires NativeGeometryVersion 1,
NativeMeshId matching the actual MeshId, a positive finite Vector3 NativeMeshSize,
NativeCollisionFidelity Box or PreciseConvexDecomposition, and
NativeRenderFidelity Automatic. It compares the public MeshSize with metadata
within 0.0001 studs and checks the actual collision/render fidelities. Missing,
zero or mismatched data returns `false, reason`; success returns true. It never
yields, loads cloud assets, reads protected bytes, caches state or owns cleanup.

NativeMeshSize describes asset intrinsics independently of target Size.
MeshId/Size alone cannot recreate those intrinsics or collision data. The
compiler preserves genuine engine-authored InitialSize and opaque payloads from
the managed native profile bank; host/native authoring audits bind the five
attributes to those bytes. Runtime validity, rendered bounds/UVs, contact
behavior and replication are separate checks. Public metadata is not an authority
or secrecy boundary.
