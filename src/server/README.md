# Authoritative server code

Server bootstrap, application services, server-only rules and Roblox/network adapters belong here. Rojo maps this folder to `ServerScriptService.Server`. It currently contains no executable modules.

The bootstrap wires small components explicitly. MatchService owns the result and lifecycle; combat, objectives, extraction and destruction own their respective state. Services use pure rules where possible and expose explicit lifecycle cleanup. They may depend on shared modules; shared/client modules must never import server modules.

Validate network intent before state changes. Link integration and engine suites as each service is implemented. Keep service contracts, resources owned, and teardown behavior documented in code and in this package overview.
