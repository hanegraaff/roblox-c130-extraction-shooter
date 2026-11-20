# Native MeshPart reconstruction

Use this guide for batch imports retained in source or when an assembly has correct names or IDs but incorrect visual size, collision or materials.

## Record a representative native import first

Record source object IDs, expected size and transform, actual loaded asset/package IDs, actual owner and access, native local transform, public intrinsic `MeshSize`, target placed `Size`, effective collision/render fidelity and texture-slot mapping. Use stable source-to-native identity even if import names or nesting change. Verify known dimensions against actual native geometry and check at least one asymmetric landmark.

For a first-piece comparison, use the same object and final transform in the native import and managed build. Record placed Size, both intrinsic MeshSize values, the visible extent of a known landmark such as a door jamb or anchor bolt, and a representative collision hit. This shows whether a mismatch begins at import, reconstruction or placement.

When format or exporter settings change, recheck transforms, hierarchy, winding, UV conventions and material-to-object mapping. For a material-split glTF derivative of an FBX or OBJ export, retain deterministic source object/material keys and verify equivalent triangle and corner-UV data through the conversion. Compare loaded textures in Studio, including orientation, opacity and intended lighting. Blender procedural materials, scalar metadata and review lights cannot by themselves produce an equivalent Roblox surface.

## Preserve engine-created data

Use the genuinely imported MeshPart or build a supported engine template, for example with `AssetService:CreateMeshPartAsync()` where permitted. Apply legitimate native mesh data through supported tooling when appropriate, then place, resize and configure the instance. A synthesized tuple of `MeshId` and `Size` is insufficient evidence that the part contains the correct intrinsic dimensions or collision data.

When a project serializes native assets, retain the native export or a hash-bound receipt and allowed template bank. Preserve opaque serialized constructor and collision data from genuine engine output. Match native profiles by asset identity and required fidelity, then apply the separately recorded placement. Raw field names and availability are serialization details. Avoid fabricating physics payloads, coercing protected runtime properties, or substituting unverified IDs. See [MeshPart](https://create.roblox.com/docs/reference/engine/classes/MeshPart) and [AssetService](https://create.roblox.com/docs/reference/engine/classes/AssetService#CreateMeshPartAsync).

For protected material slots, verify actual `SurfaceAppearance` channels in Studio authoring or a supported source audit. Replicated readable metadata can communicate intended identity or checksums, while loading and visual checks must exercise the actual assets. Use the exact approved image bytes and verify actual experience permission for every required asset. See [SurfaceAppearance](https://create.roblox.com/docs/reference/engine/classes/SurfaceAppearance) and [asset privacy](https://create.roblox.com/docs/projects/assets/privacy).

## Test what the measurements cannot show

| Observation | Check in native Studio |
| --- | --- |
| Correct pivot and target part bounds, visibly oversized or distorted model | Compare a known detail and rendered extents with the native import. Recheck intrinsic geometry and reconstruction payloads before adjusting target scale. |
| Clear-looking window that blocks traversal, visibility or hits | Exercise actual avatar movement and representative game rays through the opening and against the remaining solid faces. Inspect native fidelity and explicit proxies. |
| Successful ID or metadata match, missing or flat surface | Inspect loaded texture permissions, actual channel slots, client loading, UV orientation and intended finish. Document meaningful appearance compromises. |
| Correct local rendering, inconsistent clean rebuild | Verify the managed mapping, binding hashes and native template round-trip in a fresh Play session. Inspect model and child counts plus observed placement across the relevant clients. |

When the intended client, cloud scope, native capability or asset access is unavailable, preserve the diagnostics and identify the exact check still pending.
