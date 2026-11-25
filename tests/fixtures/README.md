# Deterministic fixtures

`DevelopmentSettings.luau` is a frozen server-only test record with `minimumPlayers = 2`. Its separately mapped presence selects the **Test** bootstrap label and defers gameplay startup to the test runner. RoundHarness supplies its own runtime settings after baseline suites finish. Production reads `MatchRuntime.defaults` for its two-player minimum.

The fixture is mapped under `ServerStorage.Tests.Fixtures` and separately as `ServerStorage.DevelopmentSettings` in the test project. Neither copy is in the release build or replicated to clients. Artifact inspection enforces that exclusion. Never use this record to relax a published build’s player requirements.

Add seeded rosters, clocks and small authored maps only when consuming tests need them. Document what each fixture models; a fake player record is not a real network client.
