# Furnished waiting lobby

Open [waiting-lobby.blend](waiting-lobby.blend) in Blender 5.3.0. From the entrance, the approved stone bust faces you across an inlaid marble floor. The left doorway leads to the movie theater. The right doorway leads to the portrait gallery. This is the furnished Blender assembly for the planned Roblox lobby replacement. [P21 visual review and decision](../../../plans/21-lobby-interior.md#completion-record)

## Tour the rooms

| Stop | What to inspect |
| --- | --- |
| [Main room beside the reference](../../../docs/evidence/p21/arrival-comparison.jpg) | Look across the stepped dais at the bust, lit chandelier, fan banners and both signed doorways. The entrance composition is 7.6 studs behind the waiting anchor. The [exact anchor view](../../../docs/evidence/p21/spawn-view.jpg) shows the sightline a player would have at that point. Both cameras are 4.8 studs above the floor. |
| [Movie theater beside the reference](../../../docs/evidence/p21/theater-comparison.jpg) | Follow the teal aisle between 24 burgundy seats. A wood-cased television stands against the arch. Its green screen displays a static aerial scene of a mesa settlement. [Full theater view](../../../docs/evidence/p21/theater.jpg) |
| [Gallery beside the reference](../../../docs/evidence/p21/gallery-comparison.jpg) | Look past the low bench toward the [north and east walls](../../../docs/evidence/p21/gallery-east.jpg), then turn toward the [south wall](../../../docs/evidence/p21/gallery-south.jpg). Each painting has an individual brass light and a layered frame. Compare [all six framed works with their originals](../../../docs/evidence/p21/six-paintings.jpg). |
| [Furnished overhead](../../../docs/evidence/p21/plan.jpg) | Locate the main room between the two wings. The [horizontal section](../../../docs/evidence/p21/circulation.jpg) cuts at 6.1 studs above the floor so the actual door openings and the routes around furniture are visible. |

The supplied room references are available at full size. [Main room](../../../src/images/redesigned-lobby/lobby-main-room.png) · [Movie theater](../../../src/images/redesigned-lobby/theater-room.png) · [Art gallery](../../../src/images/redesigned-lobby/art-gallery.png)

The file opens at the entrance camera in Solid viewport shading with textures. Press **F12** or choose **Render → Render Image** for the intended Cycles lighting. The [entrance render](../../../docs/evidence/p21/arrival.jpg) shows it immediately. To choose another shot, expand **Review cameras and lighting** in the Outliner, select its camera, move the pointer over the 3D Viewport, press **F3** and choose **Set Active Object as Camera**. For the authored framing, set **Output Properties → Format → Resolution** to the selected camera’s **image_size** custom property.

Use **A1 | Entrance-height composition** or **A1 | Exact waiting anchor eye** for arrival. The A2 cameras cover the theater aisle, north/east gallery walls, the view across the bench and six framed close-ups. For **A3 | Connected halls** or **A3 | Horizontal section at six studs**, hide **Room ceilings** in the viewport and disable its camera icon in the Outliner for rendering. The overhead renders use a World Background strength of 0.65. Restore the ceilings and strength of 0.35 for the interior views. [Camera names and shots](assembly.json)

## Six paintings

Each canvas shows the full original JPEG. Portraits 2, 4 and 6 are stored sideways at 640 × 480 pixels. Their canvas UVs turn the image 90° clockwise so each face hangs upright in a 3:4 portrait frame. Portraits 1, 3 and 5 use the orientation of their source rasters. The stretcher and molding project from the wall. In Blender each two-digit number identifies its `Portrait NN | canvas`, the pieces named `Portrait NN | frame …`, its `Canvas NN | supplied portrait` material and its `A2 | Framed portrait NN` camera. [Image hashes and frame assignments](assembly.json)

| Supplied image | Gallery wall | Canvas width × height in studs | Framed view |
| --- | --- | --- | --- |
| [Portrait 1](../../../src/images/redesigned-lobby/portrait-1.jpeg) | East | 6.80 × 10.20 | [01](../../../docs/evidence/p21/portrait-1.jpg) |
| [Portrait 2](../../../src/images/redesigned-lobby/portrait-2.jpeg) | South | 7.65 × 10.20 | [02](../../../docs/evidence/p21/portrait-2.jpg) |
| [Portrait 3](../../../src/images/redesigned-lobby/portrait-3.jpeg) | North | 7.65 × 10.20 | [03](../../../docs/evidence/p21/portrait-3.jpg) |
| [Portrait 4](../../../src/images/redesigned-lobby/portrait-4.jpeg) | East | 7.65 × 10.20 | [04](../../../docs/evidence/p21/portrait-4.jpg) |
| [Portrait 5](../../../src/images/redesigned-lobby/portrait-5.jpeg) | North | 5.63 × 10.20 | [05](../../../docs/evidence/p21/portrait-5.jpg) |
| [Portrait 6](../../../src/images/redesigned-lobby/portrait-6.jpeg) | South | 7.65 × 10.20 | [06](../../../docs/evidence/p21/portrait-6.jpg) |

## Place the assembly

One Blender unit equals one stud. The lobby pivot is at floor level below the waiting anchor. Blender +Z is up and +Y is the arrival direction. In Roblox the proposed site transform maps Blender `(x, y, z)` to `(520 + x, z, −y)`. The existing Lobby and Operator anchors are at Roblox `(520, 3, 0)` and `(520, 3, −15)`. **Placement guides** holds the old deck outline and the two body envelopes.

The old deck is 60 × 60 studs. The new floor spans 135 × 63 studs across its widest extents. Its main room is 50 × 62, the theater is 45 × 41 and the gallery is 40 × 40. The two side doors are centered at Blender `(−25, 26, 0)` and `(25, 26, 0)`. With the finished trim, each passage measures 15.74 studs wide at body height and 14.375 studs high at its center. The theater aisle measures 8.98 studs between the armrests at the sampled row. The portrait close-up cameras stand 11.02 studs from the canvases.

The clearance probes use a 4 × 4 × 6-stud body and a camera six studs behind the player, 15° above eye level, with a 0.45-stud clearance radius. A tight turn at Blender XY `(−30, 36.9)` puts this camera against the theater’s east wall. Give the camera room by rounding the corner through `(−29.9, 32.2)`, `(−31.2, 35.7)`, `(−33.8, 37.8)` and `(−36.2, 38.1)`. This wider turn clears in both directions in Blender. Check the turn again with the Roblox camera during P22.

The [approved P20 bust](../lobby-bust/README.md) is already installed once on the dais. Its foot pivot is at Blender `(0, 31.5, 2.65)`, with zero rotation and unit scale. It faces −Y. The [static GLB](../../exports/lobby-interior/waiting-lobby.glb) includes all three room shells, furnishing meshes, the bust and embedded textures. The editable scene also carries the cameras, local area lights and placement guides. For P22, preserve continuous floors and both clear portals and fit collision around the dais, seating and television console. Native walking, camera behavior, lighting and round return belong to the [Roblox import plan](../../../plans/22-integrate-lobby.md).

## Verify or rebuild

Run the following from the repository root. The Blender verifier reopens the saved scene and reimports the GLB into an empty scene. It checks the bust against the approved GLB, each canvas against its supplied JPEG, and body and camera clearance in both copies. It prints `P21_REOPEN_REIMPORT_AND_CLEARANCE_PASS` on success. [Package verifier](../../../scripts/lobby_interior/verify.py)

```sh
blender_bin=/Applications/Blender.app/Contents/MacOS/Blender
"$blender_bin" -b --python-exit-code 1 --python scripts/lobby_interior/verify.py
```

To rebuild in a temporary directory while keeping the reviewed files intact, use a checkout containing P21. The builder writes the scene, GLB, placement catalog and manifest hashes in the temporary directory. Omit `-- --no-render` to regenerate the 13 camera images there as well.

```sh
lobby_dir=$(mktemp -d)
git archive HEAD scripts/lobby_interior assets/manifest.json assets/world/Battlefield.model.json assets/exports/lobby-bust/lobby-bust.glb assets/blender/lobby-interior/aerial-screen.png src/images/redesigned-lobby | tar -x -C "$lobby_dir"
"$blender_bin" -b --python-exit-code 1 --python "$lobby_dir/scripts/lobby_interior/build.py" -- --no-render
"$blender_bin" -b --python-exit-code 1 --python "$lobby_dir/scripts/lobby_interior/verify.py"
```

To regenerate the [television still](aerial-screen.png) from its original terrain and houses, run `"$blender_bin" -b --python-exit-code 1 --python "$lobby_dir/scripts/lobby_interior/aerial_screen.py"` before the temporary build. For an intentional replacement on a task branch, refresh the review views, then run `python3 scripts/p17_harness.py --write` and `python3 scripts/verify.py` after the manifest has been updated. [Asset manifest](../../manifest.json)
