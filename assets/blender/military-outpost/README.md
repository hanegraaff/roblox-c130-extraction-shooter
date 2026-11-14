# Military outpost — Blender review source

Open [military-outpost.blend](military-outpost.blend) in **Blender 5.3.0**.
This P16 candidate contains editable meshes, materials, packed textures,
the assembled two-story outpost, furnished rooms, damage samples and reusable
props. **The user explicitly approved revision `e8fb840` on 2026-11-13**
([exact asset hash and response](../../../docs/evidence/p16/human-approval.json)). P17 has not replaced the
playable smaller Outpost with these assets.

The [acceptance record](../../../docs/evidence/p16/acceptance.md) identifies
the tested source and feedback. The approval covers the saved exterior,
both interiors and material-specific damage views. A later visual revision
requires a new review; this record does not approve changed asset bytes.

## Open and inspect

Save any unrelated Blender work first, or open a separate instance. From the
repository root on macOS, this opens a new instance without replacing an
existing document:

```sh
open -n -a /Applications/Blender.app assets/blender/military-outpost/military-outpost.blend
```

In the 3D viewport, drag the middle mouse button to orbit, Shift-drag the middle
button to pan, and scroll to zoom. Select a mesh and use **View → Frame Selected**
to inspect its details. Keep camera locking off while orbiting so inspection
does not move a saved camera. [Blender's navigation guide](https://docs.blender.org/manual/en/5.2/editors/3dview/navigate/navigation.html)
describes the controls.

Press **Numpad 0** for the active `Exterior` camera. To use another saved camera,
select it in the Outliner, move the pointer over the viewport and choose
**View → Cameras → Set Active Object as Camera** (Ctrl-Numpad 0). The menu works
without a numeric keypad. Camera switching changes the view; it does not hide
walls or the roof. These controls follow [Blender's camera-view documentation](https://docs.blender.org/manual/en/5.3/editors/3dview/navigate/camera_view.html).

| Camera | Inspect |
| --- | --- |
| `Exterior` | Complete pristine building, balcony/stairs, rooftop utilities and site props |
| `Floor_1` | Ground-floor storage/workshop, racks, cases, workbench and tools |
| `Floor_2` | Command room, consoles, chairs, tactical table, radio/server equipment |
| `Cutaway` | Overhead inspection after hiding the roof and rooftop equipment |
| `Isolated_kit` | Reusable props after enabling their collection and hiding the assembly |
| `Damage_front`, `Damage_back` | Damage samples; use the per-family renders below for framed, labelled comparisons |

Collections are named by responsibility:

| Collection | Contents and default visibility |
| --- | --- |
| `01_Stable_Structure` | Foundation, floors, supporting frame, internal stairs and guardrail |
| `02_Destructible_Panels` | Assembled pristine walls, partition and roof |
| `03_Exterior_Dressing` | Balcony/external stairs, doors/frames, utilities and outdoor props |
| `04_Floor_1_Workshop` | Furnished storage/workshop |
| `05_Floor_2_Command` | Furnished command room |
| `06_Damage_Gallery` | Labelled appearance/fragment samples; hidden initially |
| `07_Panel_Library` | Origin-centered canonical panel meshes; hidden initially |
| `08_Collision_Proxies` | Technical proxy geometry; hidden initially |
| `09_Review_Cameras_Lights` | Cameras, review lighting and presentation ground |
| `10_Scale_Guide` | Labelled 5.5-stud neutral mannequin; scale reference only |
| `11_Reusable_Kit` | Separated reusable prop samples; hidden initially |

For an overhead cutaway, expand `02_Destructible_Panels` and hide objects whose
names contain `Roof`. Hide roof parapets in `01_Stable_Structure` and rooftop
utilities in `03_Exterior_Dressing` if they obscure the view. The two interior
cameras work inside the complete building without removing its walls.

For the isolated kit, enable `11_Reusable_Kit`, hide collections `01`–`05` and
`10`, and hide `Review ground` in collection `09`. For the gallery, enable `06`
and hide the assembly and kit. Keep `07`/`08` hidden during appearance review;
their meshes overlap at the canonical origin. A disabled collection may need
its **Disable in Viewports** monitor toggle enabled in the Outliner's filter
menu before it can be shown. Reopen the saved source without saving inspection
changes to restore the initial view.

## Saved-scene previews

These are Blender art-review renders, not Roblox gameplay captures:

- [Exterior](../../../docs/evidence/p16/exterior.png)
- [Floor 1 — storage/workshop](../../../docs/evidence/p16/floor-1.png)
- [Floor 2 — command room](../../../docs/evidence/p16/floor-2.png)
- [Cutaway](../../../docs/evidence/p16/cutaway.png)
- [Isolated reusable kit](../../../docs/evidence/p16/isolated-kit.png)

Each damage sheet shows Pristine, Light, Heavy, Total and matching fragments.
Read its state labels: the back view reverses the spatial order. Window/door
apertures already present in Pristine are authored openings, separate from
earned combat damage. Light must add visible earned scars on both faces while
preserving those pristine openings; cosmetic weathering alone is insufficient.
Inspect both sides in color and grayscale.

| Material/shape | Front | Back | Front grayscale | Back grayscale |
| --- | --- | --- | --- | --- |
| Corrugated solid wall | [View](../../../docs/evidence/p16/damage-corrugated_wall-front-normal.png) | [View](../../../docs/evidence/p16/damage-corrugated_wall-back-normal.png) | [View](../../../docs/evidence/p16/damage-corrugated_wall-front-grayscale.png) | [View](../../../docs/evidence/p16/damage-corrugated_wall-back-grayscale.png) |
| Corrugated window | [View](../../../docs/evidence/p16/damage-corrugated_window-front-normal.png) | [View](../../../docs/evidence/p16/damage-corrugated_window-back-normal.png) | [View](../../../docs/evidence/p16/damage-corrugated_window-front-grayscale.png) | [View](../../../docs/evidence/p16/damage-corrugated_window-back-grayscale.png) |
| Corrugated personnel door | [View](../../../docs/evidence/p16/damage-corrugated_door-front-normal.png) | [View](../../../docs/evidence/p16/damage-corrugated_door-back-normal.png) | [View](../../../docs/evidence/p16/damage-corrugated_door-front-grayscale.png) | [View](../../../docs/evidence/p16/damage-corrugated_door-back-grayscale.png) |
| Corrugated garage | [View](../../../docs/evidence/p16/damage-corrugated_garage-front-normal.png) | [View](../../../docs/evidence/p16/damage-corrugated_garage-back-normal.png) | [View](../../../docs/evidence/p16/damage-corrugated_garage-front-grayscale.png) | [View](../../../docs/evidence/p16/damage-corrugated_garage-back-grayscale.png) |
| Concrete partition | [View](../../../docs/evidence/p16/damage-concrete_partition-front-normal.png) | [View](../../../docs/evidence/p16/damage-concrete_partition-back-normal.png) | [View](../../../docs/evidence/p16/damage-concrete_partition-front-grayscale.png) | [View](../../../docs/evidence/p16/damage-concrete_partition-back-grayscale.png) |
| Layered roof | [View](../../../docs/evidence/p16/damage-layered_roof-front-normal.png) | [View](../../../docs/evidence/p16/damage-layered_roof-back-normal.png) | [View](../../../docs/evidence/p16/damage-layered_roof-front-grayscale.png) | [View](../../../docs/evidence/p16/damage-layered_roof-back-grayscale.png) |

## Scale, identity and export boundary

One Blender unit is **one stud**. The source is Z-up with its front at −Y.
FBX uses −Z forward/Y up; the intended Roblox local-coordinate mapping is
`(Blender X, Blender Z, −Blender Y)`. The building's intended Roblox center is
`(144, 0, 164)`. The footprint remains 32×48 studs; floor surfaces are at
0.125/10.125 studs and the roof center at 20.625. Utilities stay below the
32-stud aim ceiling. The external balcony/stair extends about 6.4 studs east
within the recorded site envelope; P17 must validate actual avatar clearance,
routes and aim/cover behavior.

[panel-catalog.json](panel-catalog.json) records six material/shape families: five
16×8-stud wall shapes and a 16×16 roof panel, with center pivots, appearances, proxies and
four ≤1.5-stud fragments per family. Its v2 identity migration retains all
25 existing panel IDs/pivots and declares one new concrete partition plus
fixed window, garage and east upper-door apertures. The upper personnel door
uses the north-east `Outpost_S02_East_01` bay (source Y=+16), with open leaves
folded clear of its balcony approach. Those changes are proposed integration
data, not a silent change to the live map's cover.

[asset-inventory.json](asset-inventory.json) maps reference features and named
meshes. [reusable-kit.json](reusable-kit.json) maps eight semantic prop groups
to their component names and one-mesh exports. Each reusable export has an
X/Y-centered, floor-level origin (`Z=0`); assembly exports preserve placement.
See the [game export guide](../../exports/military-outpost/README.md) for files
and material mapping.

The 32×48 footprint and ten-stud stories compress the illustrations' room
proportions. Unshown rear elevations use the same concrete/teal vocabulary.
Doors are fixed open and windows have empty apertures with metal frames;
interactive doors, glass durability and computers are outside this package.
The reference breach appears in the damage gallery; the assembly starts
pristine. The mannequin is a scale guide, and the review ground/lighting are
presentation aids outside the game export.

All mesh and texture content is original local authoring from
[p16_build.py](../../../scripts/p16_build.py), seed 1601. Supplied illustrations
are visual references only; their creator/license was not supplied, and their
pixels are not bundled as materials. Twelve original 512×512 baked PNGs are
packed in the `.blend` and retained at relative export paths. Materials use
those images with explicit constant roughness/metalness/emission values;
Roblox appearance, lighting and emissive treatment still need P17 validation.

## Rebuild and verify

The source was authored with Blender **5.3.0**, build `02f0899d78e3`. From the
repository root, a deliberate rebuild replaces this package's source/exports:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python-exit-code 1 --python scripts/p16_build.py
/Applications/Blender.app/Contents/MacOS/Blender --background assets/blender/military-outpost/military-outpost.blend --python-exit-code 1 --python scripts/p16_blender_review.py -- --audit --fbx-audit
/Applications/Blender.app/Contents/MacOS/Blender --background assets/blender/military-outpost/military-outpost.blend --python-exit-code 1 --python scripts/p16_blender_review.py -- --render
python3 scripts/p16_audit.py --write-lock
python3 scripts/refresh_outpost_manifest.py
python3 scripts/verify.py
```

The `--python-exit-code 1` flag makes a Python audit/render exception fail the
Blender command. The review script opens the saved source and writes evidence
without saving changes back into the `.blend`. Full `--render` automatically writes
`render-evidence.json` and `render-manifest.json`, binding all 29 image files
to the saved source and review script. To render one prepared view, replace `--render`
with `--render --view Floor_1` (also `Exterior`, `Floor_2`, `Cutaway`,
`Isolated_kit` or `damage`). Rendering `damage` produces all 24 family/side/color
comparisons. A partial view run retains earlier receipts only when source,
review script and image bytes still match. After the tested art and review
script are committed, `--render-manifest-only` can update the recorded source
commit from those verified receipts without rendering again:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background assets/blender/military-outpost/military-outpost.blend --python-exit-code 1 --python scripts/p16_blender_review.py -- --render-manifest-only
```

That operation rejects incomplete or stale receipts. It cannot approve changed
art or replace a new render. A changed source needs refreshed reports, affected
renders and human review; refreshing hashes alone is not acceptance.

The portable `python3 scripts/p16_audit.py` checks the committed package without
Blender. It verifies actual OBJ triangle projections, proxy coverage, bounded
fragments, UV/material references, budgets, authored stair clearance and
hash-bound Blender/FBX/render reports. Stair auditing samples the internal and
external routes through treads, landings, turns and the upper door using actual
mesh support rays and a 4×6×4-stud upright body. This geometric contract is
separate from P17's actual avatar traversal.
It cannot run a fresh Blender reopen/render or prove Roblox runtime behavior.

Initial D64 targets are 250,000 assembled / 400,000 package triangles, 18
materials, 12 textures, 16 MiB decoded base textures and a 45 MiB art-package
target. The [inventory](asset-inventory.json) records the current measured assembly,
variant and reusable-kit triangle counts, material/texture counts and decoded
texture-memory estimate. The [hash lock](package-lock.json) supplies exact file
sizes and digests. Use those source-bound measurements when evaluating a new
revision; updated art requires refreshed audits and review.

Compressed source, FBX/OBJ exports and PNGs use ordinary Git, with each file
below 20 MiB; no LFS download is needed. `.blend1` backups, caches and temporary
working renders are excluded. The manifest covers source/exports and their SHA-256
hashes. No Roblox asset IDs, upload owner or publication are implied.
