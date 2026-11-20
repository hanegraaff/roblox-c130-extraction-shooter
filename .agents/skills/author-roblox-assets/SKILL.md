---
name: author-roblox-assets
description: Create original, editable Roblox-ready 3D assets from a written description, a folder of reference images, or both. Use for props, modular environment kits, and walkable buildings that need reference fidelity, avatar and camera fit, and clean engine exports. Use an import workflow to place finished Blender assets into a Roblox experience.
---

# Author Roblox assets

Deliver editable source and an export package sized for the target experience. Use the project's art, character, and asset conventions where they exist. For substantial references or room layouts, resolve the requirements in a blockout before adding detail.

## Establish the reference and game scale

- **Description only.** Extract the silhouette, important parts, intended use, style and placement. Identify dimensions already fixed by the game. Make reversible choices for unspecified visual details and record choices that affect scale, fidelity or gameplay.
- **Images only.** Inventory the supplied image folder and actually inspect the relevant files. Match the elevations, viewpoints, repeated landmarks and material cues. Resolve contradictions by identifying which views govern which features. Treat dimensions and unseen surfaces as estimates unless there is a scale anchor.
- **Both.** Use the images for visual fidelity and the brief for style, purpose and explicit changes. Flag conflicts that materially affect appearance or play. Carry distinctive silhouettes, proportions, openings, layout and material transitions into review views taken from comparable angles. Reconstruct original textures when images are visual references. Use supplied pixels or meshes in the deliverable only when authorized.
- Measure in target studs. Choose an explicit Blender-unit conversion, source up and front axes, target pivot and insertion transform. Confirm a known dimension in a round trip. Preserve anchored site bounds, neighboring routes and other fixed geometry when replacing an existing asset.

## Design for use before detail

For walkable assets, read the [avatar and camera clearance guide](references/walkable-clearance.md). Fit the real game avatar, controls and third-person camera to the blockout before locking the facade. If the reference proportions leave too little room, preserve its visible character while adjusting interior layout or clearances when the game permits. Record any intentional camera assist and the areas that need it.

- Keep stable structure, visual dressing, playable collision and optional damage pieces identifiable. Give reusable props functional pivots, such as the floor-level center for a freestanding crate.
- Model openings in both the visible shell and the geometry that owns collision and queries. Separate prop details that should have no game interactions. For destructible pieces, agree on stable IDs, aligned origins, stage visibility and residual blocking geometry with the game's integration contract.
- Set asset limits from the target experience and devices. Track assembled and unique triangles, object and material counts, and texture dimensions and decoded memory where relevant. Reuse repeated meshes and materials. Preserve UVs and the cues players use for navigation and recognition when simplifying.

## Package and inspect

1. Save the editable source with textures packed or resolvable by relative paths. Keep review cameras, lights, scale rigs and helper overlays out of the runtime export.
2. Export the approved objects and dependencies in a format the target importer supports. Bake intended material channels that depend on Blender-only nodes. Record names, version, dimensions, axes, pivots, texture source and rights, and proxy or variant relationships when applicable.
3. Open the saved source and reimport the clean export. Check bounds, pivots, orientation, normals, UVs, materials and visual detail from review viewpoints. Report what was inspected in Blender and what still needs native Studio evidence.
4. Provide a short review guide, representative exterior and interior views when relevant, and a manifest sufficient to reproduce the approved package. Bind any requested approval to the reviewed revision and reopen it when the art materially changes.

For current upload limits and formats, consult the [Roblox Importer guide](https://create.roblox.com/docs/studio/importer).
