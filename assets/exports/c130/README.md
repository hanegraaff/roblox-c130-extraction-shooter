# C-130 exports

| File | Use |
| --- | --- |
| [c130.glb](c130.glb) | Portable geometry and solid-color materials for independent reimport and inspection. The package uses original meshes with no external texture files. |
| [ground-approach.png](ground-approach.png) | Blender review render from beneath the starboard nose, with translucent propeller sweeps. |
| [package-audit.json](package-audit.json) | Bounds in studs, source and game axes, four rotor axes, both muzzle centers, geometry counts and source hashes. |
| [C130.model.json](../../models/C130.model.json) | Managed Roblox export. Rojo loads the native shape assembly into `ServerStorage.Assets.C130`. |

Regenerate all four files from the saved C-130 master. The geometry and material audit and the clean Rojo place build use the same committed input. At runtime the server binds the rigid assembly and clients animate the four hubs. [Editable source and exact commands](../../blender/c130/README.md) · [Native verification](../../../docs/testing.md#verify-the-c-130-flight-model)
