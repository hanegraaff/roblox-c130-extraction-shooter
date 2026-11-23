# Vesper Array Warehouse import

The selected site is Warehouse. The foundation center sits at Roblox `(160, 0.125, -80)` at floor finish. The foundation is 64 × 48 studs, and the offset south entrance sits at world X = 168 and faces +Z. In Edit, the named private C130 P17 Import place (`72732833195348`, universe `10776653720`) reported the same Warehouse site and owner `2227341845`. The Roblox Open Cloud universe reports Private and the `asset:read` and `asset:write` preflight probes returned 200.

## Asset handoff

The [Blender review](../../assets/blender/radar-outpost/README.md) and its [inspection record](../images/radar-outpost/inspection.json) bind source SHA-256 `f114c37ec45febbc6a2c91e18aecfac28d59bcacc836e6577709bce176b534b7` to the two reviewed GLBs. The source and reimport pass 1,188 panel rays each, with 54 matched pivots and separate pristine, light and heavy geometry. The catalog defines Total as empty.

Run `python3 scripts/radar_outpost/prepare_import.py` to produce the native import inputs in `build/vesper-import`. The preparation preserves source accessor bytes, materials, PNGs and transforms while assigning one stable name per object/material for Studio. To generate approval-bound inputs for Open Cloud, pass the approved folder to `--output-dir`. Keep the generated staging copies out of Git. Use the preflight JSON index generated alongside them to compare native object names, textures and extents.

| Batch | Purpose | Expected parts |
| --- | --- | ---: |
| `vesper-pilot.glb` | Foundation and offset south portal. Calibrate scale, facing, native intrinsics and material assignment | 8 |
| `vesper-assembly.glb` | Rest of the pristine building | 585 |
| `vesper-damage.glb` | Wall and roof states, native proxy sources and fragments | 824 |

The user authorized private imports under the place owner's account and approved
the staging folder in MCP Permissions. Roblox approved all three Model uploads.
Studio loaded all 1,417 expected source mesh pieces. The pilot foundation
measured 64 × 48 studs and the offset gate established that the native importer
reversed X and Z. The binder compensates with a 180° turn around Y and checks
the corrected position and size of every piece. The remaining discrepancies
from the Blender preview are the use of imported color maps and Roblox
materials for scalar roughness, metalness and emission.

In the private Studio Edit document, a detached native round trip found zero
assembly intrinsic-size or fidelity mismatches. ContentProvider reported 2,615
successful native dependency callbacks and no failures. The callback count
includes repeated references. Studio serialization preserves the 649 pristine
assembly meshes and 814 bank
meshes, including 54 pristine and 108 alternate-state proxy meshes. The
[hashed native receipt](../../assets/imports/radar-outpost/native-receipt.json)
records model versions and material texture IDs. The server reads both native
roots directly from ServerStorage.

## Native geometry and reconstruction evidence

The server mounts one managed `VesperArray` assembly and one private `VesperPanelVariants` bank before the map snapshot after validating both roots. Panel layout version 3 recognizes exactly 18 perimeter roof sections and 18 wall sections on each story. Roof and wall variants retain the same identity and pivot. Light shares pristine solid geometry, Heavy owns its remaining solids, and Total clears the existing panel Model. The frame, walking surfaces and exits stay under the map owner.

The Studio isolated WorldModel probes operated on the native serialized roots.
The four portal, two stair and gallery route checks all passed. The real
collision/query owner passed 792 sampled rays across all 54 panels and four
appearances. Pristine and Light stopped the sampled cover rays, authored
apertures stayed open, Heavy cleared the center and retained both sides, and
Total left all rays clear. A cloned battlefield accepted the replacement with
three buildings and 54 radar panels. Reinstallation preserved the active
generation, rollback restored the original Warehouse, and a reset snapshot
clone retained the south portal panel pivot. See the [native probe results](vesper-native-isolated.json).

`python3 scripts/verify.py` passed on macOS arm64 with 83 unit, 74 integration,
18 tooling and 49 asset regression cases. Both Rojo builds preserved 4,267
authored parts and passed the release isolation check.

## Local Play acceptance

The native Play session must confirm rendered materials, avatar traversal, camera behavior and combat queries. Keep the test mapping in a local Studio document. Exercise the representative wall and roof cases, real heavy and sustained fire, both stair flights and the four approaches, two-client replication and pristine reset. Attach native IDs, actual material slots, load and playtest evidence to this record after testing.
