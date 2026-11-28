# Field medkit exports

| File | Purpose |
| --- | --- |
| [field-medkit.rbxmx](field-medkit.rbxmx) | Rojo's `FieldMedkit` template. Its visual parts are anchored, noncolliding, nonqueryable and nontouchable. The model has an explicit floor-center pivot. |
| [field-medkit.glb](field-medkit.glb) | Portable review geometry with 120 pieces, 1,264 triangles and eight flat-color materials. |
| [package-audit.json](package-audit.json) | Blender version, axis convention, exact bounds, inventory and SHA-256 values. |
| [Front view](front-three-quarter.png) and [rear view](rear-three-quarter.png) | Blender renders from the saved master. |

Both geometry exports use matching native Block and Wedge profiles. The server places an instance of the native model with the level's authored floor pose. Rojo reconstructs the template from this checkout with no Roblox asset ID. [Editable master and rebuild steps](../../blender/medkit/README.md)
