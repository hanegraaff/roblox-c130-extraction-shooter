# Furnished waiting lobby

Open the furnished lobby in Blender 5.3.0. From the entrance, the stone bust faces you across an inlaid marble floor. The left doorway leads to the movie theater. The right doorway leads to the gallery, where two photographs and four oil portraits hang in individual frames. [Editable lobby](waiting-lobby.blend) · [Roblox import guide](../../imports/lobby-interior/README.md)

## Tour the rooms

| Stop | What to inspect |
| --- | --- |
| [Main room beside the reference](../../../docs/evidence/p21/arrival-comparison.jpg) | Look across the stepped dais at the bust, lit chandelier, fan banners and both signed doorways. The entrance composition is 7.6 studs behind the waiting anchor. The [exact anchor view](../../../docs/evidence/p21/spawn-view.jpg) shows the sightline a player would have at that point. Both cameras are 4.8 studs above the floor. |
| [Movie theater beside the reference](../../../docs/evidence/p21/theater-comparison.jpg) | Follow the teal aisle between 24 burgundy seats. A wood-cased television stands against the arch. Its green screen displays a static aerial scene of a mesa settlement. [Full theater view](../../../docs/evidence/p21/theater.jpg) |
| [Gallery's north and east walls](../../../docs/evidence/p22/blender-oil-gallery-east.jpg) | Look past the low bench, then turn toward the [south wall](../../../docs/evidence/p22/blender-oil-gallery-south.jpg). Each portrait has an individual brass light and a layered frame. [Approved oil comparisons](../../../docs/evidence/p22/blender-oil-comparison.jpg) |
| [Furnished overhead](../../../docs/evidence/p21/plan.jpg) | Locate the main room between the two wings. The [horizontal section](../../../docs/evidence/p21/circulation.jpg) cuts at 6.1 studs above the floor so the actual door openings and the routes around furniture are visible. |

The supplied room references are available at full size. [Main room](../../../src/images/redesigned-lobby/lobby-main-room.png) · [Movie theater](../../../src/images/redesigned-lobby/theater-room.png) · [Art gallery](../../../src/images/redesigned-lobby/art-gallery.png)

The file opens at the entrance camera in Solid viewport shading with textures. Press **F12** or choose **Render → Render Image** for the intended Cycles lighting. The [entrance render](../../../docs/evidence/p21/arrival.jpg) shows it immediately. To choose another shot, expand **Review cameras and lighting** in the Outliner, select its camera, move the pointer over the 3D Viewport, press **F3** and choose **Set Active Object as Camera**. For the authored framing, set **Output Properties → Format → Resolution** to the selected camera’s **image_size** custom property.

Use **A1 | Entrance-height composition** or **A1 | Exact waiting anchor eye** for arrival. The A2 cameras cover the theater aisle, north/east gallery walls, the view across the bench and six framed close-ups. For **A3 | Connected halls** or **A3 | Horizontal section at six studs**, hide **Room ceilings** in the viewport and disable its camera icon in the Outliner for rendering. The overhead renders use a World Background strength of 0.65. Restore the ceilings and strength of 0.35 for the interior views. [Camera names and shots](assembly.json)

## Six paintings

Each canvas shows the complete approved image. Portraits 1 and 5 use the supplied JPEGs. Portraits 2, 3, 4, and 6 use the approved oil renditions at 1,086 × 1,448 pixels. These four PNGs are upright and use the full canvas UV rectangle. Exact copies are in `src/images/redesigned-lobby`, with the four original photographs under `reference-photos`. The stretcher and molding project from the wall. In Blender each two-digit number identifies its `Portrait NN | canvas`, the pieces named `Portrait NN | frame …`, its `Canvas NN | supplied portrait` material and its `A2 | Framed portrait NN` camera. [Image hashes and frame assignments](assembly.json)

| Canvas image | Gallery wall | Canvas width × height in studs | Framed view |
| --- | --- | --- | --- |
| [Portrait 1](../../../src/images/redesigned-lobby/portrait-1.jpeg) | East | 6.80 × 10.20 | [01](../../../docs/evidence/p21/portrait-1.jpg) |
| [Portrait 2, oil](oil-portraits/portrait-2-oil.png) | South | 7.65 × 10.20 | [02](../../../docs/evidence/p22/blender-oil-portrait-2.jpg) |
| [Portrait 3, oil](oil-portraits/portrait-3-oil.png) | North | 7.65 × 10.20 | [03](../../../docs/evidence/p22/blender-oil-portrait-3.jpg) |
| [Portrait 4, oil](oil-portraits/portrait-4-oil.png) | East | 7.65 × 10.20 | [04](../../../docs/evidence/p22/blender-oil-portrait-4.jpg) |
| [Portrait 5](../../../src/images/redesigned-lobby/portrait-5.jpeg) | North | 5.63 × 10.20 | [05](../../../docs/evidence/p21/portrait-5.jpg) |
| [Portrait 6, oil](oil-portraits/portrait-6-oil.png) | South | 7.65 × 10.20 | [06](../../../docs/evidence/p22/blender-oil-portrait-6.jpg) |

## Place the assembly

One Blender unit equals one stud. The lobby pivot is at floor level below the waiting anchor. Blender +Z is up and +Y is the arrival direction. The Roblox site transform maps Blender `(x, y, z)` to `(520 + x, z, −y)`. The Lobby and Operator anchors are at Roblox `(520, 3, 0)` and `(520, 3, −15)`. **Placement guides** holds the old deck outline and the two body envelopes.

The old deck is 60 × 60 studs. The new floor spans 135 × 63 studs across its widest extents. Its main room is 50 × 62, the theater is 45 × 41 and the gallery is 40 × 40. The two side doors are centered at Blender `(−25, 26, 0)` and `(25, 26, 0)`. With the finished trim, each passage measures 15.74 studs wide at body height and 14.375 studs high at its center. The theater aisle measures 8.98 studs between the armrests at the sampled row. The portrait close-up cameras stand 11.02 studs from the canvases.

The clearance probes use a 4 × 4 × 6-stud body and a camera six studs behind the player, 15° above eye level, with a 0.45-stud clearance radius. A tight turn at Blender XY `(−30, 36.9)` puts this camera against the theater’s east wall. Give the camera room by rounding the corner through `(−29.9, 32.2)`, `(−31.2, 35.7)`, `(−33.8, 37.8)` and `(−36.2, 38.1)`. This wider turn clears in both directions in Blender. Check the turn again with the Roblox camera during P22.

One approved P20 bust sits on the dais at Blender `(0, 31.5, 2.65)`, with zero rotation and unit scale. It faces −Y. The editable scene packs its textures and includes cameras, local area lights and placement guides. The static GLB holds the three room shells, furnishing meshes, bust and 15 embedded textures. Four relative PNG links retain the exact oil images while keeping the GLB under 20 MiB. Preserve the repository layout when opening the GLB. The Roblox staging tool embeds those PNGs into its batches. [Bust source](../lobby-bust/README.md) · [Static GLB](../../exports/lobby-interior/waiting-lobby.glb) · [Roblox staging and placement](../../imports/lobby-interior/README.md)

## Verify or rebuild

Run the following from the repository root. The verifier reopens the saved scene and reimports the GLB. It checks the bust against the approved sculpt, the six canvases against their exact image files, and body and camera clearance in both copies. It prints `P22_OIL_REOPEN_REIMPORT_AND_CLEARANCE_PASS` on success. [Package verifier](../../../scripts/lobby_interior/verify.py)

```sh
blender_bin=/Applications/Blender.app/Contents/MacOS/Blender
"$blender_bin" -b --python-exit-code 1 --python scripts/lobby_interior/verify.py
```

To rebuild in a temporary directory while keeping the reviewed files intact, use a checkout containing the approved P22 artwork. The builder writes the scene, GLB and placement catalog and refreshes their hashes in the temporary manifest. Drop `--no-render` to generate the camera renders there as well.

```sh
lobby_dir=$(mktemp -d)
git archive HEAD scripts/lobby_interior assets/manifest.json assets/world/Battlefield.model.json assets/exports/lobby-bust/lobby-bust.glb assets/blender/lobby-interior/aerial-screen.png assets/blender/lobby-interior/oil-portraits src/images/redesigned-lobby | tar -x -C "$lobby_dir"
"$blender_bin" -b --python-exit-code 1 --python "$lobby_dir/scripts/lobby_interior/build.py" -- --no-render
"$blender_bin" -b --python-exit-code 1 --python "$lobby_dir/scripts/lobby_interior/verify.py"
```

To regenerate the [television still](aerial-screen.png) from its original terrain and houses, run `"$blender_bin" -b --python-exit-code 1 --python "$lobby_dir/scripts/lobby_interior/aerial_screen.py"` before the temporary build. For an intentional replacement on a task branch, refresh the review views, then run `python3 scripts/p17_harness.py --write` and `python3 scripts/verify.py` after the manifest has been updated. [Asset manifest](../../manifest.json)
