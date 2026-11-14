# Military Outpost import reconstruction

This P17 package retains the actual native import receipts and deterministic
construction inputs used by the candidate's managed Outpost/material templates.
The original approved P16 Blender, FBX, OBJ, PNG and package-lock bytes remain
unchanged. Source revision `e8fb840` / Blender SHA-256
`4c1c5264020616b1af3b36c9dd37442919b386655149ee207591cd37da041d8c`
retains its [P16 approval](../../../docs/evidence/p16/human-approval.json).
The integrated in-game result has a separate pending A6 approval.

| Record | Purpose |
| --- | --- |
| `assembly-fbx-receipt-v1.json` | Observed assembly MeshIds, native transforms, dimensions and actual package/owner identity |
| `library-glb-receipt-v2.json` | Observed material-split library nodes, MeshIds, transforms and package revision |
| `panel-library-materials-v2.glb` / `.json` | Equivalent derivative and measured source/node/material/UV/texture mapping |
| `material-textures-v2.json` | Twelve actual source-bound PNG color-map references and owner IDs |
| `construction-v2.json` | Normalization fits, object classification, panel counts, receipt hashes and remaining native acceptance |
| `native-mesh-requests-v1.json` | Exact mesh/fidelity profile requests and use counts |
| `native-mesh-profiles-v1.rbxm` / `.json` | Genuine engine constructor payload bank and public native roundtrip receipt |

Roblox user **2227341845** owns assembly package **73311045122621 revision 1**
and material-library package **126055228085421 revision 2**. The latter uses a
material-split GLB derivative after the FBX import lost material boundaries.
Its generator preserves every approved triangle and corner UV, maps source
`(X, Y, Z)` to Roblox `(X, Z, −Y)`, and converts UV `(U, V)` to `(U, 1−V)` for glTF.
Each source-object/material split remains identifiable. Native receipts record
actual importer transforms; normalization fits their scale/rotation/translation.
Do not infer scale from a format convention or substitute new IDs.

The twelve repaired PNG color maps preserve original texture bytes and are
assigned to white MeshParts through SurfaceAppearance. Source roughness,
metalness and emission scalar values remain attributes/metadata; equivalent
SurfaceAppearance scalar maps are not supplied. Material finish therefore needs
explicit A6 review. Source equivalence and reference validation do not prove
actual Roblox texture loading, UV orientation or identical PBR appearance.

The compiler also writes a readable material contract onto each
SurfaceAppearance: MaterialMetadataVersion 1, MaterialKey, CompiledColorMap,
CompiledNormalMap, CompiledRoughnessMap, CompiledMetalnessMap and
CompiledColorPngSha256. Ordinary server/client code uses shared `AssetMaterial`
for those attributes and never reads protected map slots/Content variants.
Compiler and artifact/Edit audits compare the real slots, metadata and approved
receipt. Actual Instance-based preload remains separate loading evidence.

MeshId and target Size alone do not reconstruct MeshPart intrinsic size or
collision data. The managed native bank contains 407 genuine engine-created
profiles: 87 PreciseConvexDecomposition and 320 Box, all with Automatic render
fidelity, covering 2,332 template uses. The compiler preserves actual InitialSize,
PhysicalConfigData, PhysicsData and AeroMeshData bytes. Pinned Lune decodes the
local RBXM without fetching cloud data; Python verifies request/receipt/bank
hashes and exact profile coverage before writing model definitions. Opaque bytes
are copied, not synthesized from normalized dimensions or source-format units.

Five readable attributes (NativeGeometryVersion, NativeMeshId, NativeMeshSize,
NativeCollisionFidelity and NativeRenderFidelity) bind public runtime checks to
that construction data. Shared AssetMesh validates public MeshSize and fidelity;
that does not prove rendered bounds, UV appearance, actual collision contacts or
replication. The current constructor correction still requires fresh native
acceptance, and previous pre-constructor observations remain historical.

Check the committed reconstruction without uploading or changing files:

```sh
python3 scripts/p17_assets.py
python3 scripts/p17_library_glb.py
python3 scripts/p17_compile_outpost.py
python3 scripts/verify.py
```

To reproduce the derivative and managed templates from these same receipts:

```sh
python3 scripts/p17_library_glb.py --write
python3 scripts/p17_compile_outpost.py --write-managed
python3 scripts/check_repository.py
python3 scripts/verify.py
```

`p17_normalize.py --assembly <receipt> --output build/<report>.json` separately
exposes assembly normalization for review. Regeneration does not upload assets,
change the approved P16 source or authorize publication. New import receipts or
art revisions need matching manifest provenance and source-specific validation.

The output models live in [`assets/models`](../../models/README.md). Stable
structure, material panels, panel attachments and non-cover cosmetics have
explicit classifications. Panels retain 25 original pivots and add one partition;
the resulting building has 26 panels and the active map has 188. Pristine/Light
keep panel dressing; Heavy/Total remove it. Only correctly owned PanelAttachment
MeshParts receive the 64-stud dimension / 32-stud canonical half-envelope
construction allowance, while ordinary geometry retains the 40-stud default. Exact rectangle proxies own cover,
and material fragments use the shared bounded lifecycle. The operator thermal
owner locally hides only non-cover art; ground views retain furnishings.

The private `C130P17Import` workspace is universe **10776653720**, place
**72732833195348**. Clean integrated draft 11 (source `010289d`) is saved there
without publication; newer local constructor corrections have not replaced that
recorded draft.
The last verified published version 5 contains older primitive `03c9c06` release
source; saving the current draft did not update that published build.
Tests and development overrides belong only in separate local test documents.
Native navigation, damage/openings, fragment contact, thermal readability,
two-client/reset, performance and human approval remain separate
[P17 acceptance checks](../../../plans/17-integrate-military-outpost.md).
