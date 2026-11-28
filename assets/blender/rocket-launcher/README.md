# Editable depot launcher

Open [rocket-launcher.blend](rocket-launcher.blend) in Blender 5.3.0 to inspect the sand armor, graphite shell, teal stripe, top carry handle and segmented rear pad. The original sealed prop follows the approved references and uses one master for the four pickups and the equipped Tool. The file contains 126 visual pieces and ten materials without linked library or texture dependencies. [Concept views](../../../src/images/rocket-launcher/README.md) · [Blender review render](../../exports/rocket-launcher/three-quarter.png)

## Axes, parts and attachments

One Blender unit equals one stud. The Blender scene uses a 0.28-metre unit scale. Its **+X** is right, **+Y** is forward and **+Z** is up. Roblox and GLB preserve **+X** and use **−Z** for forward and **+Y** for up. The visible model measures about **1.12 studs wide**, **1.97 studs tall** and **3.68 studs long**. [Exact bounds and transforms](../../exports/rocket-launcher/package-audit.json)

Change dimensions and orientation at the object level. Each visual piece uses a centered unit-size `Block` or `Wedge` mesh profile, one material and a positive scale. The export reads each object's `NativeShape` and Principled BSDF base color to generate the matching Roblox Part or WedgePart. Keep the mesh profiles and the three attachment names so both exports reproduce the same silhouette and placement frames.

| Frame on the invisible `Handle` | Use |
| --- | --- |
| `CarryGrip` | Positions the lower grip in the native Tool hand joint. |
| `GroundContact` | Rests the pickup on its side. Its up axis points from the contact surface toward the body so the artwork sits above the floor. The gameplay pivot stays at the pickup position. |
| `Muzzle` | Starts the visible rocket at the nose when the nearby path is clear. The effect blends onto the server's head-origin sweep over 16 studs. |

## Rebuild and verify

Save the master and run from the repository root. If `blender` is unavailable on `PATH`, use the Blender executable path.

```sh
blender -b assets/blender/rocket-launcher/rocket-launcher.blend --python-exit-code 1 -P scripts/rocket_launcher/export.py -- --render
blender -b --python-exit-code 1 -P scripts/rocket_launcher/reimport.py
```

Export writes the native model, portable GLB, package audit and review render. Reimport opens the saved master and loads its GLB into a fresh scene to check mesh counts, materials, bounds, outward normals and the position of two asymmetric landmarks. After an intended art or export change, update the affected SHA-256 entries in the asset manifest, refresh the test-source binding with `python3 scripts/p17_harness.py --write` and run `python3 scripts/verify.py`. [Export inventory](../../exports/rocket-launcher/README.md) · [Manifest](../../manifest.json)

Use the synced local Studio test place to check pickups at the four sites. Look at the lower grip and body clearance while equipped, and check the visible effect against the nose from desktop and phone views. Run the three-client transfer and replay checks on the same build. [P29 Studio procedure](../../../docs/testing.md#verify-the-depot-launcher-model)
