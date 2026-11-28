# C-130 exports

The painted revision adds `c130-painted-skin.glb` with three mesh regions and an embedded 2,048 × 2,048 atlas, the original `c130-camouflage.png`, the `c130-painted-layout.json` source replacement list and `c130-painted-preview.png`. Studio's native import and shared color map are bound in the [native receipt](../../imports/c130/native-receipt.json).

| File | Use |
| --- | --- |
| [c130.glb](c130.glb) | Portable geometry and solid-color materials for independent reimport and inspection. The package uses original meshes with no external texture files. |
| [ground-approach.png](ground-approach.png) | Blender review render from beneath the starboard nose, with translucent propeller sweeps. |
| [package-audit.json](package-audit.json) | Bounds in studs, source and game axes, four rotor axes, both muzzle centers, geometry and query-volume counts, and source hashes. |
| [C130.model.json](../../models/C130.model.json) | Managed Roblox export. Rojo loads the built-in shapes, rounded visual meshes and inset query volumes into `ServerStorage.Assets.C130`. |

Regenerate all four files from the saved C-130 master. The geometry and material audit and the clean Rojo place build use the same committed input. At runtime the server binds the rigid assembly and clients animate the four hubs. [Editable source and exact commands](../../blender/c130/README.md) · [Native verification](../../../docs/testing.md#verify-the-c-130-flight-model)
