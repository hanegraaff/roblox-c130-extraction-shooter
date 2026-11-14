# Military outpost — game export package

These P16 exports accompany the editable
[Blender source and review guide](../../blender/military-outpost/README.md).
They are local integration inputs awaiting human asset approval and P17's
Roblox import/engine checks. The playable map still uses its original Outpost.

| Files | Contract |
| --- | --- |
| `outpost-assembly-v1.fbx`, `outpost-assembly-v1.obj` | Pristine building, furniture and outdoor dressing; named components preserve assembled placement |
| `panel-library-v1.fbx` | Canonical panel appearance meshes and collision proxies, identified by catalog names |
| `<family>-<state>.obj` | Six material/shape families in Pristine/Light/Heavy/Total; Total intentionally contains no panel triangles |
| `<family>-<state>-collision.obj` | Explicit authoritative-proxy candidates, separate from cosmetic detail |
| `<family>-fragment-1.obj` … `-4.obj` | Four material-matched bounded fragment meshes per family |
| `kit-<family>.fbx`, `kit-<family>.obj` | Eight semantic reusable props, each merged to one export mesh with a floor-centered local pivot |
| [materials.mtl](materials.mtl) | OBJ material names and relative base-color texture paths |
| [material-map.json](material-map.json) | Baked PNGs and explicit roughness/metalness/emission constants |
| `textures/*.png` | Twelve original 512×512 images, also packed into the source `.blend` |

The [panel catalog](../../blender/military-outpost/panel-catalog.json) supplies
dimensions, center pivots, state/proxy/fragment paths and the v2 identity
migration. It preserves all 25 original Outpost panel IDs/pivots while
declaring fixed apertures and one additional partition. Wall-family canonical
dimensions are 16×1×8 studs; layered roofing is 16×1×16. Face axes are X/Z,
thickness is Y. Assembly roof instances rotate those local face coordinates.
Do not infer a new panel identity from an FBX object name alone.

[reusable-kit.json](../../blender/military-outpost/reusable-kit.json) records
the utility lamp, louver vent, pallet, sealed case, stocked rack, complete
workbench/tool board, command console and chair. It maps each editable source
component to the one-mesh export and records dimensions and triangle counts.
Each reusable pivot is centered in X/Y at the evaluated bounds, with its base
at source `Z=0`.

One source unit equals one stud. OBJ retains source Z-up/front −Y coordinates.
FBX exports −Z forward/Y up; the intended Roblox local mapping is `(X, Z, −Y)`.
The assembly's intended world center is `(144, 0, 164)`. Clean Blender FBX
round trips check identities, dimensions, triangle/material assignments and
UVs; this is local format validation, not Roblox import acceptance.

Light preserves each family's pristine blocking surface, including authored
window/door apertures, while adding measurable earned-scar geometry on both
faces. Cosmetic weathering alone does not count as Light damage. Heavy removes roughly half the original blocking face
with material-specific torn/fractured/layered detail. Total has no panel solid.
Fragment bounds are at most 1.5 studs per axis, four per family. These exports
do not carry damage authority, hit timing or physics behavior. P17 must assign
safe collision/query properties, runtime fragment ownership and reset behavior
through shared systems, preserving the existing thresholds.

Base colors use original baked textures rather than Blender-only procedural
nodes. Recreate the explicit material constants from `material-map.json` as
appropriate for Roblox; Blender emission and review lights are not a promise
of engine appearance. Review-only ground, cameras, lights and scale mannequin
are excluded from the assembly export. Fixed-open doors and empty cosmetic
window apertures require the declared cover/navigation migration in P17.

Use the [source guide's rebuild commands](../../blender/military-outpost/README.md#rebuild-and-verify)
to regenerate all exports from the same source. `python3 scripts/p16_audit.py`
and the full verifier validate the committed dependencies, real OBJ geometry,
budget limits and hash-bound tool evidence. Fresh Blender and P17 Studio
checks remain separate. Hashes are in
[package-lock.json](../../blender/military-outpost/package-lock.json) and
[the asset manifest](../../manifest.json).

All meshes/textures were authored locally with seed 1601; supplied images were
visual references only. Creator/license information for those references was
not supplied. No reference pixels, third-party meshes, uploaded IDs or cloud
ownership are asserted. Binary source/exports use ordinary Git below the
documented file/package limits; backups and caches are excluded.
