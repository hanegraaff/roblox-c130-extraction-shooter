# Waiting-lobby bust

Open the Blender 5.3.0 sculpture master to inspect the limestone bust in the waiting lobby. It includes the head, cropped shirt and round foot. The wider platform, lighting and height gauges belong to the review scene. The supplied portrait guides the furrowed brow and swept-back hair. The eyes look down toward players on the lobby floor. The bust photograph guides the carved finish, shirt, shoulder crop and small round foot. [Sculpture master](lobby-bust.blend) · [Portrait 1](../../../src/images/redesigned-lobby/portrait-1.jpeg) · [Bust photograph](../../../src/images/redesigned-lobby/main-lobby-bust.jpeg)

## Inspect the sculpture

| View | What to look for |
| --- | --- |
| [Portrait 1 beside the first and revised sculpts](../../../docs/evidence/p20/portrait-comparison.jpg) | Compare how the hair lifts away from the forehead and how the wide eyes sit behind the frames. [Hair and gaze close-up](../../../docs/evidence/p20/hair-and-gaze.png) |
| [Front beside the supplied photograph](../../../docs/evidence/p20/front-comparison.jpg) | Follow the downturned mouth and chin folds into the buttoned collar. Compare the shoulder crop, stone finish and round foot against the bust photograph. |
| [Three-quarter view](../../../docs/evidence/p20/three-quarter.png) | Trace the hair from the forehead back over the crown. Check the projection of the nose and glasses and how the stone catches light under the jaw. Orbit behind the head to inspect the hair and shirt yoke. |
| [Waiting-player eye height](../../../docs/evidence/p20/player-eye.png) | Judge whether the face reads across the floor and the eyes look down toward arriving players. The camera is 4.5 studs above the floor, about 45 studs from the center. The two graduated posts are 5 studs tall. [Main-room reference](../../../src/images/redesigned-lobby/lobby-main-room.png) |

The scene opens with an orbitable front view. Drag with the middle mouse button to orbit and scroll to zoom. On a trackpad, drag the colored axis gizmo at the upper right of the viewport to orbit. To revisit a shot, expand **Atelier · cameras and lights** in the Outliner and select **A1 · Portrait**, **A1 · Three quarters**, **A1 · Hair roll and downward gaze** or **A2 · Player eye 4.5 studs above floor**. With the pointer over the viewport, press **F3** and choose **Set Active Object as Camera**. The front and three-quarter renders use 800 × 1000 pixels. In **Output Properties → Format → Resolution**, use 920 × 880 for the hair and eyes or 1120 × 740 for the floor view. Choose **Render → Render Image** to see the studio lighting and stone finish. [Full-size front render](../../../docs/evidence/p20/front.png)

## Placement in the waiting lobby

| Measurement or convention | Working value |
| --- | --- |
| Width × depth × height, including the foot | 13.400 × 9.680 × 19.824 studs |
| Round foot diameter | 9.680 studs |
| Insertion point | `Lobby Bust · base center` at (0, 0, 0), centered on the underside of the foot |
| Blender axes and scale | +Z up, face toward −Y, 1 Blender unit per stud |
| GLB axes | +Y up, face toward +Z, same numerical dimensions along the corresponding axes |

The lobby assembly places one instance of the approved sculpture from `62cd82c` on the dais facing the arrival route. The review platform raises the foot 2.65 studs above its floor for the sightline check. The editable lobby owns the final dais. The GLB contains the **Lobby Bust · export meshes** collection under one pivot. [Lobby assembly](../lobby-interior/README.md) · [Bust GLB](../../exports/lobby-bust/lobby-bust.glb)

The GLB contains 34 meshes with 78,524 triangles in total. The largest mesh has 18,800 triangles. Six materials distinguish honed stone, combed hair, polished spectacle rims, irises, pupil recesses and the shirt. Three original 384 × 384 color maps supply the stone grain, and one 1024 × 512 normal map follows the carved hair. The images are packed into the scene and embedded in the GLB. The authoring script uses light and shadow from the supplied photograph to guide shallow facial folds. The cheeks, eyes, nose, shirt and back of the head are modeled in three dimensions. [Supplied photograph](../../../src/images/redesigned-lobby/main-lobby-bust.jpeg) · [Source and export manifest](../../manifest.json)

## Verify or rebuild

Run these commands from the repository root. The verifier reopens the committed scene in a background Blender process, imports the GLB into an empty scene and checks mesh bounds, pivot, materials, packed maps, the facing of the collar and ears, pupil direction, hair sweep and review cameras. A successful run prints `P20_REOPEN_AND_REIMPORT_PASS` with the measured dimensions and both SHA-256 digests. The plan records the exact revision presented for visual approval. [P20 review record](../../../plans/20-lobby-bust.md#completion-record)

```sh
blender_bin=/Applications/Blender.app/Contents/MacOS/Blender
"$blender_bin" -b --python-exit-code 1 --python scripts/lobby_bust/verify.py
```

To regenerate from the committed authoring script while preserving the reviewed files, build in a temporary directory. This writes a new scene, GLB, four camera renders and updated manifest hashes under that directory.

```sh
bust_dir=$(mktemp -d)
git archive HEAD scripts/lobby_bust assets/manifest.json src/images/redesigned-lobby/main-lobby-bust.jpeg | tar -x -C "$bust_dir"
mkdir -p "$bust_dir/assets/blender/lobby-bust" "$bust_dir/assets/exports/lobby-bust" "$bust_dir/docs/evidence/p20"
"$blender_bin" -b --python-exit-code 1 --python "$bust_dir/scripts/lobby_bust/build.py"
"$blender_bin" -b --python-exit-code 1 --python "$bust_dir/scripts/lobby_bust/verify.py"
```

When preparing a revised package on its task branch, carry over the regenerated scene, export, manifest entries and review images. Refresh the reference comparisons for the new sculpture. Run `python3 scripts/p17_harness.py --write` to update the test-only asset fingerprint, then `python3 scripts/verify.py` for the repository gate. A material change to the sculpture requires a new visual review.
