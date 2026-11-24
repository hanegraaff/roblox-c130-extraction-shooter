# Waiting lobby import

The P22 release and test mappings put the furnished entrance hall, movie theater, and portrait gallery at `Workspace.World.Battlefield.LobbyStation`. The station contains the [native art assembly](LobbyArt.rbxm) and [collision model](LobbyCollision.model.json). A clean build uses the engine-exported meshes and recorded Roblox asset IDs from Git. Check the plan for the current Studio acceptance record. [P22 plan](../../../plans/22-integrate-lobby.md)

## Approved inputs and placement

| Input | SHA-256 |
| --- | --- |
| [Lobby Blender scene](../../blender/lobby-interior/waiting-lobby.blend) | `f2769d2323296bd4ae175d4e273a6b04d7afeb529125a76b475952bbd4688452` |
| [Lobby GLB](../../exports/lobby-interior/waiting-lobby.glb) | `c4be55228c48be218e54b4a305197750ae14c40560d61a0dc114d5ae1312ffcf` |
| [Lobby placement catalog](../../blender/lobby-interior/assembly.json) | `c54b2367c4ec1a7e419cdc382f861e0285c4de9d5f685d1a360ec0602a08bf34` |
| [Bust GLB at `62cd82c`](../../exports/lobby-bust/lobby-bust.glb) | `842661e46702b8730fc334026941069bb1c34341a74fb3fcb280aaff1ee7ad90` |
| [Native lobby model](LobbyArt.rbxm) | `9b4e2fbf9a3c84b3c4ea6459b6f20b655f371f6b4cd6537d63556a5ecdb8932c` |

The room layout comes from the approved P21 assembly at `ec43139`. The current canvases show the original photographs for portraits 1 and 5 and the approved oil renditions for 2, 3, 4, and 6. All four oils are upright 1,086 × 1,448 PNGs on 7.65 × 10.20-stud canvases. The GLB includes one 34-part bust around the foot pivot at Blender `(0, 31.5, 2.65)`. [Blender reimport report](../../../docs/evidence/p22/blender-oil-reimport.json) · [Portrait comparison](../../../docs/evidence/p22/blender-oil-comparison.jpg)

One Blender unit is one stud. Blender `(x, y, z)` becomes Roblox `(520 + x, z, −y)`. The staged GLBs are already Y-up. Apply the measured importer correction before the site translation `(520, 0, 0)`. The Lobby and Operator anchors are at `(520, 3, 0)` and `(520, 3, −15)`. Face Roblox −Z from the waiting anchor to see the bust ahead, theater on the left, and gallery on the right. [Placement catalog](../../blender/lobby-interior/assembly.json)

## Rebuild and inspect

Run from the repository root:

```sh
python3 scripts/lobby_interior/stage_import.py
python3 scripts/lobby_interior/native_config.py lobby-pilot.glb > build/lobby-import/lobby-pilot.native.json
python3 scripts/lobby_interior/prepare_collision.py --check
python3 scripts/verify.py
```

Staging validates the approved source and hashes, then embeds the exact four PNGs referenced by the GLB. It writes 14 GLBs and `import-index.json` under ignored `build/lobby-import/`. The index binds batch hashes to the approved art and lists part names, materials, and transforms. The batches preserve 2,432 mesh placements and 411,534 triangles. The 22-piece pilot contains portrait 4, its stretcher and frame. The canvas center is Roblox `(584.218, 9.1, −20.6)`, and its narrow dimension is along Roblox X. [Staging tool](../../../scripts/lobby_interior/stage_import.py) · [Native configuration tool](../../../scripts/lobby_interior/native_config.py)

Both Rojo builds read the engine-native `LobbyArt.rbxm`. The host artifact check compares mesh identities and native data with the archived original capture, checks the six canvas bindings and screen, and checks that both builds carry the same art and collision. Keep a single `LobbyStation` declaration in each Rojo project. Adding the station to the base `Battlefield.model.json` as well creates a duplicate during the Rojo 7.7.1 build. [Artifact checks](../../../scripts/inspect_build.py)

During P22 validation, Rojo live sync created the 2,432 visual instances in the local test document with empty `MeshId` and zero `MeshSize`. The generated place files still serialized their expected IDs and native sizes. For native art acceptance, open the built place directly or use the documented native archive mount in the local test document. Confirm loaded mesh IDs and sizes in Studio before Play. [P22 validation and source record](../../../plans/22-integrate-lobby.md#completion-record)

The collision recipe generates three floor sections and separate walls, thresholds, ceiling, and furnishing colliders. The anchored visual meshes leave physical contact to those colliders. The test build also exposes collision at `ServerStorage.Tests.Fixtures.LobbyCollision` for isolated Workspace tests. [Lobby geometry specs](../../../tests/studio/specs-server/LobbyGeometry.spec.luau) · [Studio acceptance procedures](../../../docs/testing.md#verify-the-p22-waiting-lobby)

## Native capture and texture provenance

The [original capture](LobbyArt.import.rbxm) and upload ledger record the 14 P21 geometry batches and the first portrait pilot. The current staging command generates new batches for the approved oil revision. The original batch asset IDs identify the earlier uploads. [Upload ledger](../../../docs/evidence/p22/upload-operations.json)

For a new calibration, select the authorized Roblox import workspace in Edit mode, confirm the owner and access, and import the framed pilot first. Measure a known dimension and orientation before calibrating the other batches. Use the hash-checked JSON from `native_config.py` and call the Edit-only capture function with the decoded configuration, numeric model ID, and calibrated correction `CFrame`. The function checks the native centers and intrinsic `MeshSize`, adds the site translation, and returns an unparented folder of cloned native parts and a receipt. The caller owns cleanup and export. [Native capture function](../../../scripts/lobby_interior/capture_native.luau) · [Native reconstruction guide](../../../.agents/skills/import-blender-to-roblox/references/native-reconstruction.md)

The current model was assembled from the existing calibrated native meshes. In Studio Edit, `finish_native.luau` takes the folder of 14 captured batches, a table mapping oil portrait number to `{ assetId, sha256 }`, and the same pair for the screen. It uses those images as direct `MeshPart.TextureID` bindings. For portraits 2, 4, and 6, the native canvas turns a quarter turn about its inward normal and swaps its local display extents to retain the framed position while displaying the new PNG upright. The native mesh IDs and intrinsic data are preserved. The finalizer returns an unparented `LobbyArt` folder and receipt for an authorized export. [Native finalizer](../../../scripts/lobby_interior/finish_native.luau) · [Native assembly receipt](../../../docs/evidence/p22/native-oil-assembly.json)

The receipt records native owner and destination evidence alongside the image IDs and hashes in the asset manifest. The oil images were also checked visibly on their native canvases in a separate one-client Studio preview. Check loaded images in both managed builds during acceptance, since a preload result alone cannot establish the rendered canvas appearance. [Asset manifest](../../manifest.json) · [Studio oil texture proof](../../../docs/evidence/p22/roblox-oil-texture-test.json)

Studio Edit views show the placed entrances, fixtures and walls in the native assembly. [Arrival](../../../docs/evidence/p22/roblox-oil-arrival-edit.jpg) · [Theater](../../../docs/evidence/p22/roblox-oil-theater-edit.jpg) · [Gallery east](../../../docs/evidence/p22/roblox-oil-gallery-east-edit.jpg) · [Gallery south](../../../docs/evidence/p22/roblox-oil-gallery-south-edit.jpg)
