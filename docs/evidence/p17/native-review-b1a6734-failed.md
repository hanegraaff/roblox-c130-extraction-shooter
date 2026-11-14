# P17 first integrated native review — b1a6734 failure

Exact runtime/test candidate `b1a67341100e8f72ab87e7fb44166ec8b807fa32`, tree
`7c22149fb8d1be70383bdf25f5904f71862d2837`; source-equivalent delivery db628e9.
Fresh ordinary Play in confirmed **local** tests.rbxlx, studio
`d26e7b2c-23eb-4007-9db2-3dae43e5ee33`, PlaceId/GameId zero, Studio
`0.747.0.7471481`, one actual client UserId 2227341845. The coordinator had
already verified all 131 mapped runtime/test scripts and both imported templates.
No temporary probe, dispatcher, production Source or asset mutation preceded Play.

## P1 — ordinary runtime cannot read protected SurfaceAppearance maps

Server smoke discovers **169**, with **165 passed / four failed / zero skipped /
four errors**. All four Outpost cases fail:

- P17MaterialPanelStates actual material families share exact heavy thresholds and real openings.
- P17OutpostIdentityPreflight rejects missing mismatched and non-archivable source identities before cloning.
- P17OutpostReconstruction actual repaired source retains legacy identities exact site and clean rollback.
- P17OutpostReconstruction invalid imported support rejects before any active world mutation.

The common root is `PanelAssetCatalog.meshContent`, line 49: **“The current
thread cannot read 'ColorMap' (lacking capability Plugin)”**. The identity
negative test reports its generic expected-rejection assertion because the
catalog throws before it reaches that negative input. This does not establish
a separate remaining LocalIdentityPivot defect.

The server runner then asserts `server suite failed or empty` and does not
start the actual integrated GameRuntime. No successful replacement, actual
integrated traversal, material acceptance, replication/reset or performance
result is claimed.

Client smoke discovers **nine**, with **eight passed / one failed / zero skipped /
one error**. Foundation's server-rendezvous case fails explicitly on the failed
server report. Both new ThermalCosmetics cases pass, including genuine
collidable/nonquery fragment handling and real-cover/impostor preservation.
Those scoped client passes do not turn the overall native smoke into a pass.

The [official SurfaceAppearance API](https://create.roblox.com/docs/reference/engine/classes/SurfaceAppearance)
marks ColorMap **and ColorMapContent**, NormalMap/MetalnessMap/RoughnessMap and
their Content variants as Plugin Security. This is a runtime API-boundary
defect, not a missing MCP permission or a temporary asset access problem.
Changing to ColorMapContent alone cannot resolve ordinary-script access.

Required correction: an explicit ordinary-runtime-safe metadata/SurfaceAppearance
presence boundary, while retaining actual protected-property checks in the
native Edit/source/artifact import validation. Actual Instance preload and
rendered inspection must establish asset availability/appearance separately.
Do not silently omit validation or claim readable metadata proves the protected
native properties. Prepared P17 probes also need this contract adaptation.

## Evidence and cleanup

- Raw startup/server/client reports: `build/p17-native-baseline-b1a6734-failed.json`.
- Complete Output and error stacks: `build/p17-native-baseline-b1a6734-console.txt`.

After preservation, ordinary Play was stopped. The original local document is
Edit with RunService stopped, nil ManualHarness, absent BootstrapStatus and
empty Workspace attributes, matching its initial state. PlaceId/GameId remain
zero. No test hooks were installed, no new Studio process was launched and the
private cloud instance was never operated. Studio ownership was returned to
the primary agent for the developer correction/sync.
