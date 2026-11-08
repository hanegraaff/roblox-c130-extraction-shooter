# Shared rules and lifecycle modules

Rojo maps this package to `ReplicatedStorage.Shared`. Its modules are strict, deterministic and nonyielding. They depend only on each other, with no services, global clock or mutable singleton authority state. Replication makes their code public; server adapters must still validate every action. Authoritative role/round services live in the [server package](../server/README.md).

| Module / API | Contract |
| --- | --- |
| `Validation.isFinite(value)` | Accepts finite numbers, including zero; rejects NaN, infinity and nonnumbers. |
| `Validation.inRange(value, minimum, maximum)` | Inclusive finite bounds; malformed bounds reject. |
| `Validation.flatPayload(value, maxFields, maxStringBytes)` | Accepts plain flat string-keyed tables of finite numbers, strings or booleans. Rejects metatables, nested/cyclic values and excess fields/bytes. Bounds must be integral: fields 0–1024, bytes 0–65536. |
| `Config.validate(value)` | Returns a fresh typed settings record or `nil, reason`, without mutating input. Integral population is 6–10 with minimum ≤ maximum; duration is 1–3600 seconds. Frozen defaults are 6/10/600. |
| `RateLimit.new(capacity, refillPerSecond, nowSeconds)` | Returns a full independent bucket or `nil, reason`. Capacity is 1–1000 tokens; refill is 0.001–1000 tokens/second; time must be finite. |
| `RateLimit.take(bucket, nowSeconds)` | Consumes one token when ready, using injected monotonic seconds. Rejected requests leave tokens and timestamp unchanged; no global timer or task is created. |
| `MapRules.validate(value)` | Returns a fresh typed map contract or `nil, reason`. Requires finite fields, radius >8 studs, altitude >16 studs, kill threshold below ground, matching map/orbit centers/radii and a focus at ground-level center. |
| `MapRules.inside(settings, x, z)` | Includes the exact disk edge and rejects nonfinite coordinates; the caller separately checks vertical position. Takes validated settings and does not mutate them. |
| `MapRules.orbit(settings, phaseRadians)` | Returns X/Y/Z for the matching perimeter at ground plus altitude. Requires validated settings and a finite phase in radians; spawns no aircraft. |
| `BuildingLayout.validate(buildings)` | Returns `boolean, reason?` without mutation for the exact two-large/one-small two-story layout, sixteen stair treads, unique IDs, finite twelve-component pivots and complete exterior/roof/interior panel counts. This pure authoring contract does not establish actual loaded clearance or navigation. |
| `AircraftRules.validate(value)` | Copies valid period/FOV settings or returns `nil, reason`. Period is 10–3600 seconds; FOVs satisfy `1 <= fov30mm < fov105mm <= 120` degrees. Defaults are 90 seconds, 35° and 60°. |
| `AircraftRules.pose(map, settings, elapsedSeconds)` | Returns perimeter X/Y/Z, tangent X/Z and wrapped phase in radians. Injected finite positive/negative times wrap periodically; invalid map/settings/time or derived nonfinite position returns nil. |
| `AircraftRules.fov(settings, weapon)` | Returns the validated profile FOV for `GAU23`/`M102`, or nil for an unknown ID. `names` contains their exact player-facing equipment names. |
| `AircraftRules.aimAllowed(map, x, y, z)` | Rejects nonfinite/overflowing geometry and endpoints outside the inclusive playable disk or ground−1 to aircraft-altitude vertical envelope. This pure geometry predicate does not prove line of sight; the server adapter adds actual rays. |
| `Lifecycle.new(components)` | Returns `start()`, `stop()` and `isRunning()` closures for an independent controller. Repeated starts/stops are safe. Partial start failure cleans earlier components in reverse order and returns `false, reason`. |

Lifecycle components are nonyielding functions that return nonthrowing cleanup callbacks. Keep their list stable, do not reenter the controller, and release every owned task/listener/Instance in cleanup. A component that allocates resources before throwing must clean its own partial allocation; the controller can only roll back callbacks it has received.

`Config`, `RateLimit`, `MapRules` and `AircraftRules` import their shared dependencies through `script.Parent` in Studio and a relative path under Lune. This explicit two-runtime branch is limited to dependency loading. The same [unit cases](../../tests/unit) run against filesystem-loaded modules in Lune and Instance-loaded modules in the Studio server wrapper. [Lifecycle integration cases](../../tests/integration/Lifecycle.spec.luau) use controlled resource adapters.

These helpers provide structural guards and rate accounting. MatchService/MatchRuntime add role, life, round, sequence and rate checks for surrender; AircraftSelection/AircraftService add them for operator profile changes and expose a server aim/solid-sight-line seam. Future firing adapters add equipment, range and damage checks; shared code is never a security boundary.
