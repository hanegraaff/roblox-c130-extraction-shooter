# P22 — Replace the protected Roblox waiting lobby

**Lobby redesign · Plan 3 of 3.** Use the [Blender-to-Roblox import skill](../.agents/skills/import-blender-to-roblox/SKILL.md). Inputs are the exact [P20 bust](20-lobby-bust.md) and [P21 lobby](21-lobby-interior.md) revisions the user approved. See R01–R03 and R24 in [requirements](../requirements.md) and the [roadmap](../roadmap.md).

## Replacement and source ownership

1. Match each export to its approval record. Select the intended local Studio document with `list_roblox_studios`, consult that instance’s skill guidance and use the matching Rojo project. Trial-import one framed portrait. Compare its native size, orientation, proportions and visible texture to Blender before importing the full assembly. Record mesh and texture ownership and access for the target experience where IDs are required.
2. Import the approved rooms, furnishings, six paintings and one bust. Exclude scene helpers and every reference character, rig or NPC. Compare the native placement to the Blender arrival view, using the theater-left/gallery-right entrances to check handedness. Confirm portrait materials load on the client. Retain genuine native mesh data and document the transforms and collision settings. [Native reconstruction guide](../.agents/skills/import-blender-to-roblox/references/native-reconstruction.md)
3. Replace the visible deck, canopy and back wall at `Battlefield/LobbyStation` in the same place. Preserve supported, unobstructed `Anchors/Lobby` at `(520, 3, 0)` and `Anchors/Operator` at `(520, 3, −15)`. The current 60 × 60 stud deck also supplies bounds to map validation and optional station containment. Reconcile those bounds and floor collision with the approved room footprint. Check the nearest edge of the whole lobby to the 360-stud combat disk. Keep the entire lobby outside the disk and its structure outside the panel registry. [Authored world](../assets/world/Battlefield.model.json) · [Map validation and containment](../src/server/MapService.luau)
4. Bind the native assembly, textures and placement to managed asset paths, the manifest and the release and test mappings. Build both places from a clean checkout. Document reconstruction in the asset guide and update the player guide with the lobby players can visit. Publishing the experience is a separate release action.

## Acceptance in Roblox Studio

| ID | Check | Passing observation |
| --- | --- | --- |
| A1 | Clean reconstruction and host gate | Run `python3 scripts/verify.py`. Add an artifact check for one lobby assembly, one bust, all six source-to-frame mappings and exclusion of imported characters and legacy visible geometry. Both builds reproduce the placement. Test-only objects stay in the test mapping. |
| A2 | Visual comparison and walking routes | In fresh Play, a solo waiting player spawns safely, sees the bust and both signs, and walks to the TV, to all six paintings and back. Compare eye-height views of all three rooms with the approved P21 views. Each painting is distinct, upright and legible. Check doorway, aisle, bench and dais collision and third-person camera turns for snags or clipping. |
| A3 | Protection and containment | Exercise map validation at both anchors and at the outer extent of each wing. The actual lobby footprint is outside the battlefield. Waiting movement is free, the assigned operator body is secured at its station, and lobby geometry is excluded from battle damage. Active Ground players retain battlefield containment. |
| A4 | Replication and round return | Use two actual Studio clients. Verify both receive the same bust, furnished rooms and paintings. Exercise deployment with one operator and one Ground player, finish a round and observe both players return to a walkable lobby. Repeat the reset and check that the assembly, floor collision and art counts stay stable. |

## Completion record

Record the two source approvals, native import receipts, asset IDs or local reconstruction inputs, tested commit and build hashes. For A1–A4, record commands or Studio session, client count, observed results and representative room views. Record fixes and retests against the same candidate. The [testing guide](../docs/testing.md) covers release-default solo waiting and test-only multiplayer controls.
