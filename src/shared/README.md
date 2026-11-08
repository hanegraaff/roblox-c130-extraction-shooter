# Shared foundation modules

Rojo maps this package to `ReplicatedStorage.Shared`. Its modules are strict, deterministic and nonyielding. They depend only on each other, with no services, global clock or mutable singleton authority state. Replication makes their code public; future server adapters must still validate every action.

| Module / API | Contract |
| --- | --- |
| `Validation.isFinite(value)` | Accepts finite numbers, including zero; rejects NaN, infinity and nonnumbers. |
| `Validation.inRange(value, minimum, maximum)` | Inclusive finite bounds; malformed bounds reject. |
| `Validation.flatPayload(value, maxFields, maxStringBytes)` | Accepts plain flat string-keyed tables of finite numbers, strings or booleans. Rejects metatables, nested/cyclic values and excess fields/bytes. Bounds must be integral: fields 0–1024, bytes 0–65536. |
| `Config.validate(value)` | Returns a fresh typed settings record or `nil, reason`, without mutating input. Integral population is 6–10 with minimum ≤ maximum; duration is 1–3600 seconds. Frozen defaults are 6/10/600. |
| `RateLimit.new(capacity, refillPerSecond, nowSeconds)` | Returns a full independent bucket or `nil, reason`. Capacity is 1–1000 tokens; refill is 0.001–1000 tokens/second; time must be finite. |
| `RateLimit.take(bucket, nowSeconds)` | Consumes one token when ready, using injected monotonic seconds. Rejected requests leave tokens and timestamp unchanged; no global timer or task is created. |
| `Lifecycle.new(components)` | Returns `start()`, `stop()` and `isRunning()` closures for an independent controller. Repeated starts/stops are safe. Partial start failure cleans earlier components in reverse order and returns `false, reason`. |

Lifecycle components are nonyielding functions that return nonthrowing cleanup callbacks. Keep their list stable, do not reenter the controller, and release every owned task/listener/Instance in cleanup. A component that allocates resources before throwing must clean its own partial allocation; the controller can only roll back callbacks it has received.

`Config` and `RateLimit` import `Validation` through `script.Parent` in Studio and a relative path under Lune. This explicit two-runtime branch is limited to dependency loading. The same [unit cases](../../tests/unit) run against filesystem-loaded modules in Lune and Instance-loaded modules in the Studio server wrapper. [Lifecycle integration cases](../../tests/integration/Lifecycle.spec.luau) use controlled resource adapters.

These helpers provide structural guards and rate accounting. They do not establish role, life state, round identity, sequence freshness, equipment ownership, range or line of sight; future gameplay adapters own those checks.
