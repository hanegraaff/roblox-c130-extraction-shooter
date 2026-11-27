# P28 — C-130 model in flight

**Depends on** P24, P25 and C-130 reference art. **Requirements** R27. [Roadmap](../roadmap.md#public-mvp-launch) · [Requirements](../requirements.md)

Ground players see an original C-130 model that reads clearly as it arrives and circles the battlefield.

## Work

- Use the [C-130 reference folder](../src/images/c130/). Save the editable master at `assets/blender/c130/c130.blend`. Match the approved silhouette and proportions at the current model size. Use dark gunmetal charcoal with readable slate military markings and the brushed red shark face. Show the prominent M102 barrel projecting from the lower starboard fuselage aft of the wing. Show all four propellers spinning in flight and represent their motion with translucent blur in still renders. Render a preview from the Ground viewing angle.
- Build a managed Roblox export. Fit it to the existing C130 template, canonical Hitbox, pivot, named muzzle attachments and query contract. Align the M102 attachment and firing effects with the approved starboard barrel. Keep orbit, camera, damage and arrival owned by their existing systems. Record export settings, provenance, scale and reconstruction in the asset manifest and package guide.

## Acceptance

1. **A1 · Rebuild.** Open the Blender master, audit its dependencies and rebuild the release place from a clean checkout. Check hull bounds, scale, flight direction, muzzle locations and asset loading.
2. **A2 · Fly and fight.** In two-client Studio play, capture reveal and a full orbit from Ground. Check silhouette, heading, livery readability and propeller motion at gameplay distance. Verify both gunship muzzles, operator self-masking at both zooms and a Ground hit/miss at the visible hull boundary.
3. **A3 · Replay.** Trigger aircraft destruction, then replay. Check that the next aircraft appears once with the correct pose, geometry, health and targeting view.

Run the applicable [project checks](../docs/testing.md) and record the source revision, environment and observed results for each criterion.

## Documentation

Record source, export and import paths and how to replace the visual while preserving gameplay attachments.

## Completion record

Planned checks have no results yet.
