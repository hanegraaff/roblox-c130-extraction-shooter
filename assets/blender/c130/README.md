# Editable C-130

Open `c130-painted.blend` in Blender 5.3.0 to inspect the game livery from below the starboard nose. The packed UV atlas carries the olive-and-gray camouflage, panel wear, stencil markings and brushed red shark mouth. Thinner cambered wing sections refine the flight silhouette. The four translucent propeller sweeps show motion in the still render. [Reference views](../../../src/images/c130/README.md) · [Painted Ground-angle render](../../exports/c130/c130-painted-preview.png)

`c130.blend` supplies the original P28 native shape template and flight markers. To regenerate the coating, open that base master and run the following command. This writes a painted Blender master, embedded-texture GLB, atlas, review render and a list of the source pieces replaced by the three skin meshes.

```sh
blender -b assets/blender/c130/c130.blend --python-exit-code 1 -P scripts/c130/paint_livery.py -- build/c130-livery-upload
```

The managed skin uses the three Studio-imported MeshParts and their shared texture. A changed atlas or geometry requires an authorized new import and an updated native receipt. Use the recorded per-mesh transforms to convert Blender's stage to the flight frame. The server hides the covered native solids, removes the original raised markings and welds the textured skin to the flight root. [Native receipt](../../imports/c130/native-receipt.json) · [Managed template contract](../../models/README.md)

## Flight frame and editable parts

One Blender unit equals one stud. The scene uses a unit scale of 0.28 metres. Blender **+X** is starboard, **+Y** is forward and **+Z** is up. Roblox and GLB retain starboard **+X** and convert up to **+Y** and forward to **−Z**. The flight origin is `(0, 0, 0)`. The authored art measures about **58.02 studs across**, **57.60 studs nose to tail** and **18.46 studs tall**. [Exact bounds, markers and source hashes](../../exports/c130/package-audit.json)

Work in Object Mode when changing the size, rotation or position of a native piece. Keep its centered, unit-sized mesh profile and use its object transform for the fit. For a new piece, choose a supported `NativeShape` of `Ball`, `Block`, `Cylinder` or `Wedge` and assign one material. The exporter reads the Principled BSDF base color and expects finite positive scale without shears or mirrored transforms. A `Cylinder` has local X along its length and equal Y and Z diameters. Overlapping circular cylinders form the cargo cabin cross section.

A `Ball` profile can scale independently along all three axes. Its Roblox appearance uses the built-in Sphere `SpecialMesh` on a one-stud carrier with queries disabled. Set `NativeQuery` for a rounded piece that should take hits. The exporter fits circular cylinder bands inside the curved surface, so queries can sit slightly inside the finest edge. Supported solid shapes such as the cabin cylinders can carry their own query flags. Leave paint, translucent sweeps and spinning blades out of queries.

Keep the origin and the two named muzzle markers when replacing artwork. If a barrel moves, align its marker to the visible bore and recheck the server firing origin. Keep `GAU23Muzzle` with its port-side bore and `M102Muzzle` with the howitzer on the lower starboard fuselage behind the wing. Keep the four named rotor markers and their corresponding rotor groups so the spinning blades stay centered on their hubs. [Managed template contract](../../models/README.md)

## Regenerate and inspect

Save the master and run from the repository root. Use the Blender executable path if `blender` is unavailable on `PATH`.

```sh
blender -b assets/blender/c130/c130.blend --python-exit-code 1 -P scripts/c130/export.py -- --render
blender -b --python-exit-code 1 -P scripts/c130/reimport.py
```

The first command writes the portable mesh, the review render, the package audit and `assets/models/C130.model.json`. The second opens the saved master and reimports the GLB into a fresh Blender scene. It checks bounds, material names, mesh counts and outward faces, and audits for external file dependencies. Review the render, update the affected SHA-256 entries in the asset manifest and run `python3 scripts/verify.py` to rebuild both Rojo mappings and check the authored template. [Export inventory](../../exports/c130/README.md) · [Manifest](../../manifest.json)

Verify the flying model in the synced local Studio test place after regeneration. Check the visible silhouette and propellers from Ground, both muzzle origins, a hit and miss at the hull boundary, self-masking at both operator zooms, and replay after destruction. [Two-client model checks](../../../docs/testing.md#verify-the-c-130-flight-model)
