# Deterministic fixtures

`DevelopmentSettings.luau` is a frozen server-only test record with `minimumPlayers = 2`, reserved for future roster tests. The current shell uses only the presence of the separately mapped `ServerStorage.DevelopmentSettings` ModuleScript to choose its **Test** label; no round or minimum-player logic exists yet.

The fixture is mapped under `ServerStorage.Tests.Fixtures` and separately as `ServerStorage.DevelopmentSettings` in the test project. Neither copy is in the release build or replicated to clients. Artifact inspection enforces that exclusion. Never use this record to relax a published build’s player requirements.

Add seeded rosters, clocks and small authored maps only when consuming tests need them. Document what each fixture models; a fake player record is not a real network client.
