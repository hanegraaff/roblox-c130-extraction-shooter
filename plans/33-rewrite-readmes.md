# P33 — Rewrite the README guides

**Depends on** P26–P32. **Requirements** R15, R30. [Roadmap](../roadmap.md#public-mvp-launch) · [Requirements](../requirements.md)

A developer new to Roblox can understand the game, run it locally and find how each part works.

## Work

- Inventory every tracked first-party README. Rewrite the root around play, controls, availability, local setup and testing. Define Studio, place, Rojo and Luau when first used. Keep the selected Blender Outpost image immediately after the title, its authoring caption, and that single embedded image.
- Add a **Graphics and models** section near the top of the root README with a link to an illustrated gallery in `docs/images/showcase/README.md`. Use in-game screenshots from the tested build to show the battlefield and landmark interiors, the furnished lobby, and the C-130 and equipment in play. Include a thermal view so readers can see how the two roles differ.
- Capture Blender viewport screenshots of selected editable models and pair them with matching in-game views where practical. Choose comparable angles for pairs such as the Outpost, Prism Seedship or lobby, and use a close-up to show model details that are hard to see in play. Label each image **Blender viewport**, **Blender render**, or **In-game screenshot** as appropriate. Record the source scene or game revision, include useful alt text and link the editable source. Reuse existing captures when they meet the same standard and share suitable gameplay captures with P34.
- Explain branch selection, dependencies, both build mappings, ports, Rojo connection in Edit mode, starting a match, host and Studio tests, and updating the same document. Give a command and visible result for each setup step.
- Rewrite package, asset, test and evidence index READMEs around purpose, inputs, operation and where to look next. Keep exact commands, public APIs, provenance and evidence links. Keep dated delivery history in plans and the roadmap. Leave original evidence files intact.

## Acceptance

1. **A1 · Coverage.** Compare a tracked README inventory with the reviewed files, including nested packages. Verify local links, heading links, commands, paths and the root image/caption. Each guide answers what this part does and how to use it.
2. **A2 · Newcomer walkthrough.** Follow only the root guide in a clean checkout. Build the playable and test places, sync in Edit mode, play both roles, make and sync a reversible local edit, and run both test paths. Record steps that required guessing, fix the text and repeat them.
3. **A3 · Graphics showcase.** Open the gallery from the root README on desktop and phone. Verify that images load, labels and alt text identify their source, and at least one Blender viewport and in-game pair shows the same asset. Check that gameplay screenshots match the tested build and that the original Outpost hero remains the root README’s single embedded image.

Run the applicable [project checks](../docs/testing.md) and record the source revision, environment and observed results for each criterion.

## Documentation

Deliver the rewritten guides, the linked graphics gallery and a short verification record.

## Completion record

Planned checks have no results yet.
