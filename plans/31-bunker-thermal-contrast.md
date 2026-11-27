# P31 — Darker starting bunker

**Depends on** P18 and the integrated Sandbreak bunker. **Requirements** R22. [Roadmap](../roadmap.md#public-mvp-launch) · [Requirements](../requirements.md)

From the aircraft, the starting bunker reads as dark cover beside the other buildings. An exposed player remains easy to spot.

## Work

- Compare the bunker and a neighboring landmark at the same operator zoom and lighting. Identify the bright wall, roof or material contributions. Adjust the bunker’s operator-side thermal treatment and retain the existing normal Ground materials.
- Keep the structure and attached damage surfaces visible. Preserve real openings, white exposed targets and cover occlusion through the full damage sequence. Follow the [building thermal checklist](../assets/README.md#thermal-presentation-for-buildings).

## Acceptance

1. **A1 · Side-by-side captures.** Record before/after scenes at both weapon zooms using repeatable camera positions. Compare representative wall and roof brightness with nearby structural surfaces. Review the actual rendered result with an exposed, covered and doorway target.
2. **A2 · Two-client regression.** Exercise both roles in Studio. Check pristine and damaged panels, line of sight through an earned opening, normal Ground colors, role switch and reset. Verify the local thermal change never alters server collision or damage.

Run the applicable [project checks](../docs/testing.md) and record the source revision, environment and observed results for each criterion.

## Documentation

Record the reference scene and the material rule in the bunker asset guide.

## Completion record

Planned checks have no results yet.
