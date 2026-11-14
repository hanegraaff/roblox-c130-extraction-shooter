# P16 showcase and PR integration

Date: 2026-11-13 (America/New_York). The user requested: “generate a new image showcasing the blender creation, add it to the readme and merge the PR”.

## Subsequent user-selected replacement

The user subsequently said: “don't like it, use blender_outpost.png, and merge
the PR”. The README now uses the supplied
[Blender viewport capture](../../../blender_outpost.png) instead of the
generated board, with an accurate capture caption. The supplied PNG is retained
byte-for-byte: 1988×1314, 3,583,569 bytes, SHA-256
`94ebc1333b183fb42c20c24249ff31109053b187255d380915dcafbb13f9165c`.
The generated image below is historical; the actual P08 gameplay screenshot
and approved Blender source are unchanged. PR #35 was already merged, so the
replacement is delivered through a new small PR into the same planning base.

## Showcase

For the original request, the built-in `image_gen` tool produced the
[1672×941 showcase](../../images/military-outpost-showcase.png), using the
actual approved exterior/workshop/command-room Blender renders as subject
references. The [exact prompt and provenance](../../images/military-outpost-showcase.md)
are committed. At that merge, the README displayed it in the Blender inspection section and
explicitly identified it as an AI-generated illustration. The representative
actual P08 gameplay capture remains near the top of the README.

Image SHA-256:
`885ada1fba4a17a5d50846093cee2cf343671e7dfb0b7fb908eea106c87c3e8f`.
PNG signature, dimensions, checksum and the retained gameplay link were
verified. The image is outside runtime asset mappings and the required
29-image acceptance set. The approved Blender source remains exactly
`4c1c5264020616b1af3b36c9dd37442919b386655149ee207591cd37da041d8c`.

The work was authored on dedicated branch `docs/p16-blender-showcase` and
fast-forwarded into PR #35 so that the requested merge included the image.
Showcase candidate: `e5486a2eb2d7878ddfd1e91f07a1dd9efe1f64de`, tree
`5ae21805ba8c90c60ae7a90acd84f4c3f6787694`.
`python3 scripts/check_repository.py` passed 92 Markdown / 224 JSON files;
diff checks passed. [GitHub Verify 43546042230](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/43546042230)
passed on that exact candidate, including the existing full host gate.

## Observed merge

With the user's explicit merge authorization,
[PR #35](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/35)
was merged with the expected-head guard set to `e5486a2…`. GitHub returned
`merged=true` and merge commit
`3f1116a533ce0dd6b046d7f5ea815706851ee483`.

The configured destination was **`docs/military-outpost-blender-plans`**.
After fetching, its merge tree was
`5ae21805ba8c90c60ae7a90acd84f4c3f6787694`, exactly equal to the passing
candidate. `main` remained `c7210bed7e28938640c04b450d827cd727d6215d`.
Parent PRs #32–#34 were not merged by this request; the remaining dependency
stack's integration into `main` is separate. P17 remains unstarted and must
include the approved source now present on the planning branch or a descendant.
No Roblox publication occurred.

This follow-up integration record changes documentation only; no approved
source, export, render, runtime module or test behavior changed after the
passing candidate. The repository checker and diff checks are rerun for the
records before their push.
