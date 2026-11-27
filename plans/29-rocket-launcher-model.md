# P29 — Rocket launcher model in play

**Depends on** P25 and rocket launcher reference art. **Requirements** R27. [Roadmap](../roadmap.md#public-mvp-launch) · [Requirements](../requirements.md)

The same original launcher is recognizable on the ground and in a player’s hands.

## Work

- Use the approved [depot launcher references](../src/images/rocket-launcher/). Match the muted sand, graphite and teal exterior. Use the carried view to judge the prop's size against a Roblox avatar. Save one editable master at `assets/blender/rocket-launcher/rocket-launcher.blend`. Create pickup and equipped presentations from it with an avatar-sized grip and a consistent visual firing point.
- Use LauncherRuntime and LauncherGeometry for placement, equipping and transfer. Each of the four existing sites keeps its own identity, ready time and drop/recovery behavior. Register the export, materials and managed source in the manifest.

## Acceptance

1. **A1 · Asset and fit.** Verify a clean build and inspect all four pickup placements. Check grip, clipping, floor contact, scale and muzzle effect alignment from desktop and phone views.
2. **A2 · Transfer and fire.** Use three Studio clients to pick up, aim, fire, hand off while cooling, lose a carrier and recover a launcher. Check the visible held/dropped state on both Ground clients, one owner, the correct firing origin and independent readiness.
3. **A3 · Replay.** Check that each site resets with one loaded launcher and that old held models and effects disappear.

Run the applicable [project checks](../docs/testing.md) and record the source revision, environment and observed results for each criterion.

## Documentation

Document the shared master, the two presentations and how to check fit and attachments.

## Completion record

Planned checks have no results yet.
