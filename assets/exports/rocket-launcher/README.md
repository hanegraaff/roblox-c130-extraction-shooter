# Depot launcher exports

Generate the portable and native models from the same saved [Blender master](../../blender/rocket-launcher/README.md). The geometry uses project-authored shapes and materials. Rojo builds the native template without a cloud mesh asset or texture.

| File | Use |
| --- | --- |
| [rocket-launcher.glb](rocket-launcher.glb) | Portable geometry and solid-color materials for inspection and reimport. |
| [package-audit.json](package-audit.json) | Scale, axes, bounds, attachment frames, geometry counts and source hashes. |
| [three-quarter.png](three-quarter.png) | Blender review render of the depot prop. |
| [DepotLauncher.model.json](../../models/DepotLauncher.model.json) | Native template mapped to `ServerStorage.Assets.DepotLauncher` in both Rojo builds. |

The portable files and review render stay outside the Rojo mappings. The loaded game creates the pickup and Tool representations from the native template. [Native fit and lifecycle checks](../../../docs/testing.md#verify-the-depot-launcher-model)
