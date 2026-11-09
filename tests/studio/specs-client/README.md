# Client engine specs

`Foundation.spec.luau` is mapped to `ReplicatedStorage.ClientSpecs` only in the test place, so the automatic client runner can load it through TestEZ.

It checks real replicated **Test** status, character/HumanoidRootPart availability and environment text in the status GUI. It exercises two explicit start/stop cycles of an independent StatusPanel while preserving the entrypoint panel, then restores the original name. Readiness is staged: successful server fixture completion within 60 seconds, RoundState/role rendezvous within 35 seconds, then a real ready avatar or explicit characterless late-spectator state within 25 seconds. This avoids racing character creation against server-owned fixtures. Timeout diagnostics preserve phase/role/life/load-lease and character/root presence; `ClientTests.StartupReadiness` records actual elapsed and avatar-stage time. These are test-only budgets, not production timing changes.

These two cases are P01/R01 shell checks. P03 role/deadline/UI replication, no-respawn behavior and spectator camera observations live in the separate client RoundHarness after these specs; separate aircraft/thermal probes live in AircraftHarness; combat checks remain planned. Follow the [testing guide](../../../docs/testing.md) for actual client-context reports and separate stop/restart runs.
