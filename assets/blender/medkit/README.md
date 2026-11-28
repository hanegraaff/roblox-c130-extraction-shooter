# Editable field medkit

Open [medkit.blend](medkit.blend) in Blender 5.3.0. The pickup is an original hard-shell rescue case based on the supplied front, rear and avatar-scale views. The front has an ivory cross on rust-orange enamel. The back has a stone-gray inset and two graphite hinges. The four bumpers, latch clips and ribbed handle are modeled in geometry. [Reference views](../../../src/images/medkit/README.md) · [Front render](../../exports/medkit/front-three-quarter.png) · [Rear render](../../exports/medkit/rear-three-quarter.png)

The case measures 2.14 studs wide, 1.7185 high and 1.0605 deep. Blender uses one unit per stud at a scene unit scale of 0.28 metres. Blender's +X is right, +Y is front and +Z is up. In Roblox and the GLB, +X remains right, −Z is front and +Y is up. The pivot is the resting surface at the horizontal center of the case. The reference with an avatar establishes scale. In play the case stays on the floor until someone uses it.

## Rebuild and inspect

Edit the visual pieces at the object level. Leave each Block or Wedge mesh profile unmodified, with positive scale and one material. Set its surface color on the Principled BSDF. Keep the bottom of the feet at Blender Z = 0. The native model's pivot records that floor plane. Review cameras, lighting and the backdrop stay in their own Blender collection.

From the repository root, run the following with Blender available on `PATH`.

```sh
blender -b assets/blender/medkit/medkit.blend --python-exit-code 1 -P scripts/medkit/export.py -- --render
blender -b --python-exit-code 1 -P scripts/medkit/reimport.py
```

The export script writes a GLB, a Rojo model, an audit and, with `--render`, both review views. The reimport checks the saved master's dimensions, outward normals and front and rear landmarks against a clean GLB import. After a deliberate asset revision, refresh the affected SHA-256 values in the asset manifest and run the full host gate. Use the synced test place to review the reachable floor placements and prompt. [Export inventory](../../exports/medkit/README.md) · [Asset manifest](../../manifest.json) · [P30 acceptance](../../../plans/30-single-use-medkits.md#acceptance)
