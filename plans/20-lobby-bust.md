# P20 — Sculpt the oversized main-lobby bust in Blender

**Lobby redesign · Plan 1 of 3.** This plan uses the [Blender asset-authoring skill](../.agents/skills/author-roblox-assets/SKILL.md). It takes the supplied images as input and delivers a sculpture for [P21](21-lobby-interior.md). See R24 in [requirements](../requirements.md) and the [roadmap](../roadmap.md).

## What to sculpt

Use the [bust photograph](../src/images/redesigned-lobby/main-lobby-bust.jpeg) for the likeness. Preserve the swept-back hair, rectangular glasses, wide eyes, deeply downturned mouth, chin folds and buttoned shirt collar. Carry the pale carved finish down through the shoulders to the small round base. Use the [main-room image](../src/images/redesigned-lobby/lobby-main-room.png) for scale and staging. From waiting-player eye height the face should look out over the room, and the features should read from across the floor.

## Authoring and handoff

1. Block out the head, shoulders and base. In a simple staging scene, set the sculpture above floor level and compare its height and sightline against a stud scale. P20 owns the bust and its small base. P21 owns the wider stepped dais visible in the room image.
2. Refine the sculpture from the front, then resolve the profile and back for a player who can walk around it. Keep the glasses and mouth legible under ordinary room lighting. Use the depicted people only to estimate scale. The sculpture is a static prop.
3. Deliver the editable `.blend`, a clean game export, and a short asset guide under the repository’s [asset conventions](../assets/README.md). Give P21 the width, height, base diameter, base-center pivot, forward direction and Blender-unit conversion. Reopen the scene, reimport the export and check those measurements and the materials. Identify the exact source and export in the manifest.

## Acceptance by user visual inspection

| ID | What the user inspects |
| --- | --- |
| A1 | A front view beside the bust reference and a three-quarter view. The user judges the likeness, expression, cropped shoulders and stone finish. The editable scene allows inspection from any angle. |
| A2 | A floor-level view from across the staging space. The user judges whether the sculpture feels oversized and appears to watch over the people who will gather below it. |
| A3 | The user explicitly approves the identified bust revision after inspecting it. If they request changes, revise the sculpt or staging, show the affected views and obtain their approval on the revised asset. |

## Completion record

During authoring, record the review views, `.blend` and export paths and hashes, and the user’s decision against that revision. P21 takes the approved sculpture from this record. Technical checks prepare the artwork for review. The user’s visual decision closes the plan.
