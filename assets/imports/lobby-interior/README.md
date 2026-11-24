# Waiting lobby import

P22 prepares the approved entrance hall, movie theater, and portrait gallery for Roblox. This package contains the import tools, collision fixture and [native Studio archive](LobbyArt.import.rbxm). The playable place still uses the original lobby deck, canopy and back wall while portrait image moderation is resolved. [P22 plan and completion record](../../../plans/22-integrate-lobby.md)

## Approved source and placement

| Input | Approved revision | SHA-256 |
| --- | --- | --- |
| [Lobby Blender scene](../../blender/lobby-interior/waiting-lobby.blend) | `ec431397c6047882dd85e2b46566645da8100ef0` | `377880e774377566ff3a83b763712376ca922ad235bcb3a544feb417c965f56c` |
| [Lobby GLB](../../exports/lobby-interior/waiting-lobby.glb) | `ec431397c6047882dd85e2b46566645da8100ef0` | `bf8387630baeec1a6677fb0394573c1900b3a635763bec6da3afc70cd120ed9e` |
| [Lobby placement catalog](../../blender/lobby-interior/assembly.json) | `ec431397c6047882dd85e2b46566645da8100ef0` | `0a77911fb3204b5a7f0f0daec506a0f390733ee1c5f072596d952ad9f9c512a4` |
| [Approved bust GLB](../../exports/lobby-bust/lobby-bust.glb) | `62cd82c27584da9c70b24d975e49cb1df646e3d6` | `842661e46702b8730fc334026941069bb1c34341a74fb3fcb280aaff1ee7ad90` |

The lobby GLB already contains the one approved bust. Its 34 meshes are placed around the foot pivot at Blender `(0, 31.5, 2.65)`. The six gallery canvases carry the approved JPEGs and UVs, including the 90° clockwise turn for portraits 2, 4, and 6. [Blender review views and portrait assignments](../../blender/lobby-interior/README.md)

One Blender unit is one stud. Blender `(x, y, z)` becomes Roblox `(520 + x, z, −y)`. The staged GLBs are already Y-up, so their site translation is `(520, 0, 0)` after correcting any transform introduced by the importer. The existing Lobby and Operator anchors remain at `(520, 3, 0)` and `(520, 3, −15)`. Face Roblox −Z from the waiting anchor to check the bust ahead, theater on the left, and gallery on the right. [Placement catalog](../../blender/lobby-interior/assembly.json)

## Stage the pilot and remaining rooms

Run from the repository root:

```sh
python3 scripts/lobby_interior/stage_import.py
python3 scripts/lobby_interior/native_config.py lobby-pilot.glb > build/lobby-import/lobby-pilot.native.json
python3 -m unittest discover -s tests/assets -p 'test_waiting_lobby_import.py' -v
```

The staging command writes 14 GLBs and `import-index.json` under ignored `build/lobby-import/`. The index binds every batch SHA-256 to the approved lobby GLB and records its part names, materials, and source transforms. Across the batches it preserves 2,432 mesh placements and 411,534 triangles. The 22-piece pilot contains portrait 4's canvas, stretcher, and frame. The canvas measures 7.65 studs wide and 10.20 studs high, centered at Roblox `(584.218, 9.1, −20.6)`. Its narrow dimension is along Roblox X. [Staging script](../../../scripts/lobby_interior/stage_import.py) · [Native configuration script](../../../scripts/lobby_interior/native_config.py)

1. Select the authorized Roblox import destination in Studio Edit mode. Confirm the asset owner, access, and required permissions for that destination. Keep the local Play test document separate. [Studio connection and import guidance](../../../docs/development.md#connect-roblox-studio-mcp) · [Import workflow](../../../.agents/skills/import-blender-to-roblox/SKILL.md)
2. Import only `lobby-pilot.glb` first. Record the actual model and version, mesh and image IDs, importer settings, and any warnings. Inspect the received pose and intrinsic `MeshSize` to establish the importer correction before applying the site translation. Compare the frame and complete, upright image from the gallery side with the approved Blender close-up. [Portrait 4 review view](../../../docs/evidence/p21/portrait-4.jpg)
3. Generate a native configuration for each authorized batch by running the same `native_config.py` command with its filename. In Studio Edit, evaluate [capture_native.luau](../../../scripts/lobby_interior/capture_native.luau) and invoke its returned function as `captureBatch(config, assetId, correction)`. Pass the decoded batch JSON, the numeric model ID, and the measured importer correction as a `CFrame`. The function adds the site translation after checking the corrected native poses. It returns an unparented Folder of cloned native MeshParts and a receipt that includes part identities, texture slots, and placement deltas. Check any `missingColor` entry and verify visible textures in Play.
4. Keep the actual engine-exported model and receipts together when wiring the lobby into both Rojo projects. Record actual owner and access, model versions, the importer correction, and the native model and receipt hashes in the manifest. Remove the full legacy `LobbyStation` node from `Battlefield.model.json` before each project defines its own `LobbyStation` folder with `LobbyCollision` and `LobbyArt` inside. Rojo 7.7.1 creates duplicate station folders if both inputs define the station. Update the P21 Blender verifier's historic deck lookup as part of that change. [Native reconstruction guide](../../../.agents/skills/import-blender-to-roblox/references/native-reconstruction.md)

## Check collision and play

Roblox approved all 14 model batches and rejected the Image assets for portraits 2, 3 and 6. The native archive contains all 2,432 mesh placements and preserves the captured textures for traceability. During actual activation, use the verified television image `rbxassetid://97488158099796` on `P22_Room04_757_01.TextureID` after removing its imported SurfaceAppearance. Keep the native color metadata consistent with the slot. Use actual in-scene renders for SurfaceAppearance textures. Roblox streams their processed texture data separately from ordinary preload callbacks. [Upload and texture receipt](../../../docs/evidence/p22/upload-operations.json)

Run `python3 scripts/lobby_interior/prepare_collision.py --check` to compare the generated [collision model](LobbyCollision.model.json) with its source recipe. It defines the three floor sections and independent wall, portal, and furnishing proxies. The test mapping exposes the fixture at `ServerStorage.Tests.Fixtures.LobbyCollision`. The server specs mount it in a disposable battlefield clone to exercise support beneath both anchors, clear doorways, furniture collision, protection from the combat disk, and the active Ground containment path. [Lobby geometry specs](../../../tests/studio/specs-server/LobbyGeometry.spec.luau)

Once native art is bound in both builds, exercise the furnished lobby in fresh solo Play and with two actual Studio clients. Record the visible portraits, avatar and camera clearance, operator hold, and two returns to the lobby with the same art and collision. [P22 acceptance steps](../../../docs/testing.md#verify-the-p22-waiting-lobby)
