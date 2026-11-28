# Server engine specs

The test mapping places these specs in `ServerStorage.Tests.Studio` for automatic TestEZ discovery. Each suite exercises production modules against Roblox Instances. Use the [Studio smoke procedure](../../../docs/testing.md#run-the-studio-smoke-suites) for current reports.

## Startup and world

- [Foundation.spec.luau](Foundation.spec.luau) runs rule and match cases through Instance-loaded modules, checks bootstrap ownership across start and stop, and raycasts against the anchored Ground spawn. It restores the entrypoint status after exercising an independent runtime.
- [Map.spec.luau](Map.spec.luau) checks loaded disk, roof and spawn transforms, then uses disposable Workspace clones for invalid anchors, elevated or obstructed routes, containment and pristine rebuilds. It checks route clearance with a 4×6×4-stud envelope sampled every 0.5 studs, covers nine protected spawn anchors and samples 64 perimeter positions.
- [ExpandedMap.spec.luau](ExpandedMap.spec.luau) checks building and panel identities, invalid floors and routes, protected lobby separation and native terrain write and restoration. The terrain check uses a five-second readiness budget and a three-stud tolerance around four-stud voxels. Navigation with avatars and clients uses the [expanded map scenario](../../../docs/testing.md#run-the-p13-expanded-map-harness).

## Aircraft, equipment and outcomes

- [Aircraft.spec.luau](Aircraft.spec.luau) samples perimeter, altitude and tangent pose with injected time, checks hit and muzzle geometry and exercises clean resets and teardown. [CombatView.spec.luau](CombatView.spec.luau) and [CombatCollision.spec.luau](CombatCollision.spec.luau) cover legal view claims and native obstruction. A [multiplayer orbit run](../../../docs/testing.md#run-the-p04-aircraft-harness) checks shared motion and role-local thermal behavior.
- [Launcher.spec.luau](Launcher.spec.luau) checks native pickup and held models, support, reach and fallback geometry, movement and muzzle rules, and first-solid rocket collision. Aircraft health and result checks use the shipped 150 damage per direct hit. [CharacterOwner.spec.luau](CharacterOwner.spec.luau) exercises actual character removal and raw Model destruction, then restores the player’s previous avatar.
- [MatchOutcome.spec.luau](MatchOutcome.spec.luau) checks the exact deadline and mixed-damage result ordering. The [multiplayer outcome procedures](../../../docs/testing.md#run-the-p09-match-outcome-harness) verify shared results and replay.

## Cover and building materials

[PanelDestruction.spec.luau](PanelDestruction.spec.luau) exercises the native registry, persistent panel credit, distinct structural and appearance tiers and real Heavy openings. It checks shelter entrances and anchors, reuses the seven-collider shelter union and excludes cosmetic marks from weapon queries. Supporting specs cover [blast exposure](BlastGeometry.spec.luau), [material panels](MaterialPanels.spec.luau), [Vesper panel geometry](VesperPanels.spec.luau) and the [imported Outpost](Outpost.spec.luau). Use the [destruction scenario](../../../docs/testing.md#run-the-p07-destruction-harness) to check client agreement and replay. See individual [plan records](../../../roadmap.md) for source-bound counts, renders and results.
