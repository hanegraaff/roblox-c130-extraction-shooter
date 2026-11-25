# Building and player readability in thermal view

The military Outpost compiler keeps 124 additional exterior attachments visible
in the C-130 view. The set covers the rooftop dish, antenna, HVAC and exterior
wall details. Freestanding dressing and window mullions retain their thermal
mask. Comparing the old and new model definitions found only the 124 tag changes.

Vesper uses a local thermal brightness multiplier of `0.68`. Its palette
references the 18 original color maps and leaves the ground textures intact.
The operator's depth-occluded player highlight uses a white fill and outline.

## Verification

`python3 scripts/verify.py` passed on macOS arm64 with 83 unit, 74 integration,
18 tooling and 49 asset tests. Both Rojo builds checked the palette against the
approved import receipt and reconstructed 4,267 authored part poses, dimensions
and physics flags. The named local test build used
`rojo build test.project.json --output build/outpost-thermal-tests.rbxlx`.

Studio `0.748.0.7481526` rendered a controlled preview in the existing Vesper
test document. Its 195 server checks passed. The probe applied the generated
Outpost tag changes and ran the new thermal cosmetics module against the loaded
assets. It used the same camera pose and tagged R15 avatar for the Vesper
brightness comparison. The dish sample's median grayscale value dropped from
162 to 120 on a 0–255 scale. The exposed avatar sample retained a median of
241. When the test avatar moved beneath the gallery, a ray hit its solid floor
and the white silhouette disappeared. Stopping the tint owner removed its
surfaces and left the original texture ID. An isolated native ray hit the
military Outpost wall above the window and passed through the aperture itself.

The preview applied the changes in Play while the existing Edit document awaited
Rojo sync. A clean Play run of the new place, including the new client regression,
is pending. [Vesper with exposed avatar](../images/radar-outpost/studio-thermal-muted.jpg) ·
[Military Outpost details](p17/outpost-thermal-detail.jpg)

## Integration

The Warehouse replacement and both thermal follow-ups merged into `main` in
dependency order. The relevant merge commits are `e8c57a0`, `218465f`, and
`2fe2a59`. [Warehouse replacement](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/50) ·
[Vesper thermal visibility](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/51) ·
[Building and player contrast](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/52)
