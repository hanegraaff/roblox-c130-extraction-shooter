# P20 — Sculpt the oversized main-lobby bust in Blender

**Lobby redesign · Plan 1 of 3.** This plan uses the [Blender asset-authoring skill](../.agents/skills/author-roblox-assets/SKILL.md). It takes the supplied images as input and delivers a sculpture for [P21](21-lobby-interior.md). See R24 in [requirements](../requirements.md) and the [roadmap](../roadmap.md).

## What to sculpt

Use the [bust photograph](../src/images/redesigned-lobby/main-lobby-bust.jpeg) for the sculpture and [portrait 1](../src/images/redesigned-lobby/portrait-1.jpeg) as an additional likeness reference. The hair lifts off the forehead and combs back over the crown. The wide eyes look down toward the players below. Preserve the rectangular glasses, deeply downturned mouth, chin folds and buttoned shirt collar. Carry the pale carved finish down through the shoulders to the small round base. Use the [main-room image](../src/images/redesigned-lobby/lobby-main-room.png) for scale and staging. From waiting-player eye height the face should look out over the room, and the features should read from across the floor.

## Authoring and handoff

1. Block out the head, shoulders and base. In a simple staging scene, set the sculpture above floor level and compare its height and sightline against a stud scale. P20 owns the bust and its small base. P21 owns the wider stepped dais visible in the room image.
2. Refine the sculpture from the front, then resolve the profile and back for a player who can walk around it. Keep the glasses and mouth legible under ordinary room lighting. Use the depicted people only to estimate scale. The sculpture is a static prop.
3. Deliver the editable `.blend`, a clean game export, and a short asset guide under the repository’s [asset conventions](../assets/README.md). Give P21 the width, height, base diameter, base-center pivot, forward direction and Blender-unit conversion. Reopen the scene, reimport the export and check those measurements and the materials. Identify the exact source and export in the manifest.

## Acceptance by user visual inspection

| ID | What the user inspects |
| --- | --- |
| A1 | A front view beside the bust reference and a three-quarter view. The user compares the hair sweep and downward gaze with portrait 1 and judges the likeness, expression, cropped shoulders and stone finish. The editable scene allows inspection from any angle. |
| A2 | A floor-level view from across the staging space. The user judges whether the sculpture feels oversized and appears to watch over the people who will gather below it. |
| A3 | The user explicitly approves the identified bust revision after inspecting it. If they request changes, revise the sculpt or staging, show the affected views and obtain their approval on the revised asset. |

## Completion record

### Approved bust for the P21 lobby

The review scene and export are pinned to `62cd82c27584da9c70b24d975e49cb1df646e3d6`, tree `7b721c62454e296a2dade64f6344c4562e684105`. The task branch includes the supplied references and lobby plans from `894d848` and the integrated P19 source from `main` at `2300fba`. [PR #68](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/68) · [Open and inspect the bust](../assets/blender/lobby-bust/README.md)

| File for P21 | SHA-256 |
| --- | --- |
| [Editable Blender scene](../assets/blender/lobby-bust/lobby-bust.blend) | `02690030fdbfcb487480a3f0f965c08ebd26c6b2b001720cb6d3974075ac2624` |
| [Static GLB](../assets/exports/lobby-bust/lobby-bust.glb) | `842661e46702b8730fc334026941069bb1c34341a74fb3fcb280aaff1ee7ad90` |

| Criterion | Evidence for the revised bust |
| --- | --- |
| A1 · Likeness and finish | [Portrait 1 beside the first and revised sculpts](../docs/evidence/p20/portrait-comparison.jpg), [hair and gaze close-up](../docs/evidence/p20/hair-and-gaze.png), [front beside the bust photograph](../docs/evidence/p20/front-comparison.jpg) and [three-quarter view](../docs/evidence/p20/three-quarter.png). The original three cameras retain their framing. The new close view shows the forelock rising off the hairline and turning back over the crown. |
| A2 · Scale and sightline | In the [player-eye view](../docs/evidence/p20/player-eye.png), the camera sits 4.5 studs above the floor and about 45 studs in front of the bust. Two five-stud gauges flank the stand. The small round base sits 2.65 studs above the floor. The left and right pupil surfaces point down 16.49° and 16.45° respectively. |
| A3 · User decision | On 2026-11-24, after reviewing `7b8a155` and requesting the hair and gaze changes, the user inspected `62cd82c` and selected “Approve the revised bust.” This decision covers the two files and hashes above. |

**P21 placement.** The sculpture measures 13.400 studs wide, 9.680 deep and 19.824 tall. The foot is 9.680 studs in diameter. Insert at its bottom-center pivot. Blender uses one unit per stud, +Z up and −Y toward the room. The GLB uses +Y up and +Z toward the room. P21 supplies the wider stepped dais.

### Technical verification

- On macOS with Blender 5.3.0, `/Applications/Blender.app/Contents/MacOS/Blender -b --python-exit-code 1 --python scripts/lobby_bust/verify.py` reopened the saved scene, then reimported the GLB in an empty scene. The 34 mesh bounds agreed within 0.001 stud. Both contain six materials, three color maps and one hair normal map. The GLB has 78,524 triangles across the sculpture, with 18,800 in its largest mesh. Four cameras and the staging are confined to the editable scene. [Blender measurements](../docs/evidence/p20/blender-reimport.json)
- The first independent test on `7b8a155` found inward-facing shirt collars and localized back-facing folds on the nape and ears. The corrected package has 11,637 outward first hits across those five pieces in each format in the seven-direction regression test. A separate independent sweep of the visible sculpture from front, three-quarter, both profiles and rear found zero back-facing first hits in either format.
- The independent tester matched triangle counts, centroids and signed volumes for all 34 meshes, then rendered the reopened scene and reimport under identical CPU Cycles settings. Mean absolute linear RGB difference was 0.000000746 at 500 × 620 pixels and 12 samples. In front view the revised pupil centers sit 23% and 29% of the way up the eye openings, previously 44% and 51%. The three measured forelock sections each rise in front of the hairline and recede toward the crown.
- The initial repository gate rejected the stale P17 source inventory after the two bust binaries were added. `python3 scripts/p17_harness.py --write` refreshed the test-only binding. Verification matched all 224 production and 114 fixture inputs.
- On the revised art, `python3 scripts/verify.py` passed on macOS with 83 unit, 78 integration, 26 tooling and 58 asset tests. Both Rojo builds passed. The artifact inspection verified 11,459 part transforms in each build and the release/test isolation checks passed. The final repository check after documentation changes passed for 132 Markdown and 526 JSON files.
- The technical writer followed the [asset guide](../assets/blender/lobby-bust/README.md) using a temporary archive of `62cd82c`. Blender regenerated both artifacts and all four full-size camera renders from that checkout. The rebuilt pair passed the same reopen/reimport verification.

The required visual environment for P20 is Blender. P22 will verify the approved asset in the playable lobby.
