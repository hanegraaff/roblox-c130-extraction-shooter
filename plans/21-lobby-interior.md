# P21 — Build the complete waiting lobby in Blender

**Lobby redesign · Plan 2 of 3.** Use the [Blender asset-authoring skill](../.agents/skills/author-roblox-assets/SKILL.md) and the sculpture approved in [P20](20-lobby-bust.md). Deliver one editable, connected lobby for [P22](22-integrate-lobby.md). See R24 in [requirements](../requirements.md) and the [roadmap](../roadmap.md).

## Rooms and artwork

| Reference | What a waiting player sees |
| --- | --- |
| [Main lobby](../src/images/redesigned-lobby/lobby-main-room.png) | From the arrival view, the approved bust rises on a tiered circular dais. The signed Movie Theater entrance is on the left and the Art Gallery entrance is on the right. Preserve the polished pale floor and inlays, wood and brass trim, teal fan banners and benches, plants and the circular light above the bust. |
| [Movie theater](../src/images/redesigned-lobby/theater-room.png) | Rows of burgundy seats flank a clear teal-carpeted center aisle. A wood-cased television with knobs and twin aerials sits on a table against the arched front wall. Warm sconces and a static green aerial image give the front of the room its character. |
| [Art gallery](../src/images/redesigned-lobby/art-gallery.png) | Dark coffered wood, cream walls, brass picture lights and a low teal bench define the room. Continue the hanging arrangement around the walls to give all six supplied portraits their own framed painting and a clear viewing position. |

Use these six files as the faces of the wall-mounted paintings, one file per frame. Preserve the image proportions and keep each face and its distinctive details visible. The frames and canvases have depth. The portrait subjects appear only on the canvases. [Portrait 1](../src/images/redesigned-lobby/portrait-1.jpeg) · [Portrait 2](../src/images/redesigned-lobby/portrait-2.jpeg) · [Portrait 3](../src/images/redesigned-lobby/portrait-3.jpeg) · [Portrait 4](../src/images/redesigned-lobby/portrait-4.jpeg) · [Portrait 5](../src/images/redesigned-lobby/portrait-5.jpeg) · [Portrait 6](../src/images/redesigned-lobby/portrait-6.jpeg)

## Authoring and handoff

1. Block out the three connected rooms around the arrival sightline. Use the current protected site, deck and two spawn anchors as scale and placement guides. Keep both anchors clear of the dais, walls and seats. Measure the proposed footprint, door widths, headroom, theater aisle, gallery viewing distance and camera clearance in studs. Leave room for waiting players to pass. Use the [clearance guide](../.agents/skills/author-roblox-assets/references/walkable-clearance.md).
2. Place one instance of the P20 bust. Furnish the three rooms and light them for the views above. Exclude all people, audience figures and background avatars pictured in the room references from modeling and export. Use the theater screen as set dressing. A live spectator feed or an interaction prompt would require separate gameplay work.
3. Package the editable assembly, relative or packed textures, and game exports under the [asset conventions](../assets/README.md). Identify each portrait file, frame and material in the manifest. Record the referenced bust revision, its transform on the dais, assembly pivot, stud scale, doorway positions, collision guides and export selection. Reopen the scene and reimport the package to catch broken links, missing paintings or a duplicated bust before review.

## Acceptance by user visual inspection

| ID | What the user inspects |
| --- | --- |
| A1 | An entrance-height view beside the main-room reference. The user judges the bust’s placement and scale, the left and right entrances, the materials and the lighting. |
| A2 | A theater view down the aisle and gallery views from beside the bench, set beside their room references. Show every wall needed to see all six distinct paintings, plus close views where the user can compare them to the originals. |
| A3 | A cutaway or overhead view and the editable scene show how the rooms connect. The user can follow both routes from the main room and inspect the furnished spaces without modeled characters. |
| A4 | The user explicitly approves the identified complete lobby revision after inspecting the three rooms and paintings. Address requested art changes and present the revised views for approval. A material change to the P20 sculpture also goes back through its own visual review. |

## Completion record

Record the review views, scene and export paths and hashes, portrait-to-frame mapping, P20 revision and the user’s decision on this assembly. P22 uses the two approved revisions together. The user’s visual decision closes this plan.
