# Shared code

Public Luau types, replicated configuration/view models and genuinely shared pure rules belong here. Rojo maps this folder to `ReplicatedStorage.Shared`. It currently contains no executable modules.

Do not place secret/server-only state here. Shared rules cannot import server services or client controllers. Keep deterministic rules independent of Instances; accept clock/random/world results as data. Clients may use rules for presentation, but the server revalidates every gameplay decision.

Document exported module/type contracts and link their unit suites here as they arrive in Plan 01 and later features.
