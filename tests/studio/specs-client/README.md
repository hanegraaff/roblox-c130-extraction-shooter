# Client engine specs

The test mapping places these specs in `ReplicatedStorage.ClientSpecs` for discovery by the local TestEZ runner. The specs use actual client-side Roblox objects and their production controllers. Use the [Studio smoke procedure](../../../docs/testing.md#run-the-studio-smoke-suites) to collect reports.

## Startup and cleanup

[Foundation.spec.luau](Foundation.spec.luau) waits up to 60 seconds for the server fixtures to complete, 35 seconds for the round state and assigned role, and 25 seconds for a ready avatar. A late spectator needs a protected lobby avatar. Timeout diagnostics report phase, role, life, character-load lease and root availability. `ClientTests.StartupReadiness` records the elapsed timings. The lifecycle case starts and stops an independent StatusPanel twice while preserving the entrypoint panel.

[SpectatorCamera.spec.luau](SpectatorCamera.spec.luau) checks the neutral camera’s inert subject and idempotent cleanup with a fixture round ID outside the current roster. The [player experience harness](../../../docs/testing.md#run-the-player-experience-harness) separately verifies following and cycling living teammates.

## Aim and interface

- [PointerGui.spec.luau](PointerGui.spec.luau) uses actual normal, full-bleed and device-safe GUI buttons to check mouse viewport coordinates and touch content coordinates. It compares `ScreenPointToRay` with the converted `ViewportPointToRay`, exercises processed and nonfinite touch rejection, tests focus blocking and checks cleanup. `ClientTests.PointerGuiInset` records the inset used by the case.
- [GroundAimGui.spec.luau](GroundAimGui.spec.luau) checks rendered reticle alignment and rays, input-mode changes, control cleanup and desktop and phone placement. It constructs the production HUDs under distinct ScreenGui origins and checks compact health/readiness text and touch controls against inventory and movement reserves. The readiness fixtures include loaded M-7 rounds, unlimited reserve and rifle and launcher reload deadlines.
- [OperatorControlLayout.spec.luau](OperatorControlLayout.spec.luau) checks native center-hit registration for Recenter across safe-area origins and viewport changes. Visible-center taps and separate pan and aim touches belong in an operated phone session. [Touch review](../../../docs/testing.md#verify-p27-aim-and-mobile-hud)

## World and camera presentation

[GroundIndoorCamera.spec.luau](GroundIndoorCamera.spec.luau) covers role-local automatic framing and restoration. [ThermalCosmetics.spec.luau](ThermalCosmetics.spec.luau) checks marked surface tint and restoration. [LobbyArt.spec.luau](LobbyArt.spec.luau) and [WeaponImpactEffects.spec.luau](WeaponImpactEffects.spec.luau) cover lobby presentation and impact-effect lifecycle. For source-bound capture and replication evidence, use the [client scenario guide](../client/README.md) and [plan records](../../../roadmap.md).
