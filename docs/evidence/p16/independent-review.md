# P16 independent candidate review

Date: 2026-11-13 (America/New_York). Reviewer: separate `feature_tester` agent.
Scope: Blender source, local exports, technical acceptance and reference review.
No Roblox gameplay, import, collision, thermal, replication or runtime cost pass
is claimed. Those belong to P17. Human approval A4 remains required.

**Final technical review: passed on `e8fb840a986969bdd3b7ac932469e3fa8cc99a9e`
and the source/export hashes in the final section. All reproduced technical
findings are resolved. The package is ready for the user's actual asset review;
this report does not grant A4 approval.** Earlier failures below remain
historical evidence and are not passing evidence for their old candidates.

## Reviewed source

Initial frozen candidate: commit `9c0ac4275133831b1d6b1f5d2083c319c1a26933`,
tree `7c0e290a0deed0f51b50ebc4845fd224d790e9d3`.

- `.blend`: `22d668fff653832915868e09c25e25d2b4e24f92255394984bc1819ff9f2b8f8`.
- Assembly FBX: `cfca0ce6e37986169f7932fbc06e73b23b0b9a5f4a2eaa9f6a785c13984fc949`.
- Blender 5.3.0, build `02f0899d78e3`, macOS arm64; factory-startup/headless
  processes. All three supplied reference PNGs were independently viewed.

This candidate has material navigation findings below. Its passing initial
checks must not be relabelled as acceptance of a corrected later asset revision.

## Consolidated findings on the initial candidate

| Priority | Criterion | Reproduction and observation | Required correction |
| --- | --- | --- | --- |
| P1 | A1 / R16 / R19 | Internal staircase intersects a new mid-building beam. In the saved Blender scene, upward rays at `(-10,-0.3,5.145)` and `(-10,0.3,5.770)` hit `Cross beam.001` after **2.980** and **2.355** studs. Tread-center-only sampling misses it. | Preserve the stairwell's usable headroom; add actual-geometry checks across tread interiors and route width. |
| P1 | A1 / R16 / R19 | External stairs run below an uninterrupted balcony slab. Centerline rays from steps 7–19 hit `Exterior balcony`; clearances range **5.855 → 0.355** studs, and the last treads intersect the deck. | Provide an actual opening or clear rerouted ascent within the declared site; test the source and exports. |
| P2 | A2 / R19 | At the actual 1600×440 damage-sheet size, embedded state captions are tiny and low contrast against the plinth; some opposite-face text overlaps/reverses. Front/back columns reverse order. | Make the source gallery's state captions readable from both sides; retain explicit column order in the review guide. |
| P2 | A3 / R01 | Portable evidence checking binds only the assembly FBX report hash; panel-library/kit report hashes and the required render-set hashes/source are unchecked. An intentional lock refresh could conceal stale evidence for those files. | Bind every FBX report and the complete required saved-scene render set, with rejection tests. |

These are source geometry and evidence findings. Blender rays do not establish
Roblox avatar collision behavior. The initial geometry itself crosses the
intended six-stud upright route, so it requires correction before P16 approval.

## Initial verification that actually ran

- `python3 scripts/p16_audit.py`: **6/6**, zero failed/skipped. Actual exported
  triangle projections measured Heavy removal **48.295–50.000%**, with zero
  sampled proxy-only blocker cells. All six Light silhouettes retain pristine
  apertures; Total contains no panel mesh or collision solid. Four bounded
  fragments exist for each family. These tests initially missed navigation.
- `python3 -m unittest discover -s tests/assets -v`: **9/9**. Includes actual
  package control plus invalid UV, invisible collider, Light opening, Total
  solid, shifted identity, oversized fragment, missing texture and empty FBX
  rejection. No required case skipped.
- `python3 -m unittest discover -s tests/tooling -v`: **10/10** manifest cases.
- The primary agent's exact current `python3 scripts/verify.py` run on unchanged
  initial candidate passed **55 unit / 65 integration**, the above asset/tooling
  checks and all existing static/type/build/reconstruction/isolation and
  deliberate rejection gates. The reviewer inspected its actual completion
  log; it was not unnecessarily repeated. See [initial host log](host-9c0ac42.txt).
- Independent read-only clean Blender source probe decoded all **12 packed
  512×512 images**, found all **11 named collections**, and measured 48 internal
  tread/intermediate upward samples plus 20 external tread-center samples.
  Two internal and thirteen external samples exposed the failures above.
- Independent **factory-startup** FBX-vs-OBJ probe loaded no authored source
  datablocks and cleared objects/materials/images between imports. The assembly
  had **2,241 meshes / 89,440 triangles**; eight reusable FBXs each had one mesh.
  Identity, triangle, finite UV and cross-format bounds checks passed; largest
  bounds difference was **0.000007401 studs**. Every imported image dependency
  resolved inside the exported package and decoded as 512×512. The final
  command included `--python-exit-code 1` and exited zero with its positive
  structured completion marker.

The disposable probes were `/tmp/p16_independent_probe.py` and
`/tmp/p16_independent_fbx.py`. The primary agent preserved the
[navigation probe](navigation-probe.py), [cross-format probe](independent-fbx-probe.py)
and [initial cross-format output](independent-fbx-9c0ac42.txt). Commands were:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background assets/blender/military-outpost/military-outpost.blend --python-exit-code 1 --python /tmp/p16_independent_probe.py
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python-exit-code 1 --python /tmp/p16_independent_fbx.py
```

The source probe samples actual scene rays from the tread surface plus 0.02
stud, upward for six studs, including offsets ±0.7 along each internal tread.
The export probe compares actual OBJ vertex bounds/triangle counts with imported
FBX geometry, normalizing OBJ underscores versus FBX spaces in names, then
decodes the actual imported texture files. Initial probe drafting corrected a
lazy-image assumption by forcing actual pixel decoding; that was a probe issue,
not missing asset data.

## Visual and scope observations

The initial exterior and both furnished rooms visibly preserve the concrete/
teal/orange vocabulary, two-story silhouette, external stairs, rooftop HVAC,
mast/dish, storage/workshop and command-room functions. The source contains
editable detailed components rather than only renders. The 32×48 footprint
compresses the reference proportions; fixed apertures and a new partition are
explicit migration data. Surface detail and lighting are an interpretation of
the references, not a pixel-identical rendering. Only the human can accept that
interpretation under A4.

At full sheet size, metal Light scoring and concrete/roof cracks are visible
in the viewed normal and grayscale sheets, while Heavy/Total are unambiguous.
Light is deliberately subtler; source caption legibility still needs the
reported correction. No agent conclusion substitutes for the user's required
review of both sides and all material families.

## Corrected-candidate recheck

Corrected source checkpoint: `518a3b30a3a752c4d71bc715f91bc6c01a626fd5`,
tree `39da2785cc3ac5ec22b055142bdae33ccfaf3900`.

- `.blend`: `08277437457c0538d0767c97bffa784a8b0e511d4f7bee2c1e37cf66a89b7c93`.
- Assembly FBX: `8cb1910ec3dfd923683ffc3d4acd4f1e7ee622f2c10d3660944a1652cf91a2e8`.
- Independent source and clean-imported FBX probes both pass **324/324**
  upward samples over every tread at three widths and three longitudinal
  positions, with **zero blocked samples**. The revised external tread top
  matches the declared step height; probes start 0.02 stud above each surface.
  The source probe also independently decodes all 12 packed 512×512 textures,
  verifies all 11 collections and seven named cameras. See the
  [preserved probe](independent-navigation-probe.py),
  [saved-source result](navigation-518a3b3-source.txt) and
  [factory-FBX result](navigation-518a3b3-fbx.txt).
- Independent factory-startup cross-format checks again pass for **2,225
  assembly meshes / 89,024 triangles** and all eight one-mesh kit exports.
  Largest FBX/OBJ bounds difference remains **0.000007401 studs**; actual UVs
  and package-contained decoded texture dependencies are valid. See the
  [corrected import output](independent-fbx-518a3b3.txt).
- The two P1 navigation findings are resolved in actual source/export geometry.
  The implementation also adds `P16Navigation`: actual triangle/AABB tests for
  185 upright 4×6×4-stud stations plus 1,850 support rays across both complete
  routes. Its floor-profile tolerance permits legitimate rising treads; the
  old beam, old full slab and a side-body obstacle each have rejection probes.
  These source geometry checks still do not replace P17 native avatar walking.
- Evidence checking now binds panel-library and all eight reusable import
  hashes plus the exact required 29 PNGs, source and review script. Rejection
  coverage includes stale proof after lock refresh and missing/corrupt/stale
  render metadata. Independent current receipt/geometry audit passed **7/7**;
  the independent asset rejection suite passed **19/19** in 9.558 seconds.
  The primary agent's matching full host gate also passed 10 tooling cases,
  7 asset audits, 19 asset regressions, 55 unit / 65 integration cases and all
  other existing gates. See the preserved [518 host log](host-518a3b3.txt) and
  [asset audit](asset-audit-518a3b3.json). That evidence still missed the visual
  case below.
- The reviewer viewed **all 29 actual corrected PNGs**: five scene/kit views
  and all 24 family/side/color sheets. Caption cards are now legible from both
  sides, including grayscale; that P2 finding is resolved. No additional
  assembly-view or navigation defect was found.

### Additional A2 finding exposed by complete gallery review

**P1 / A2 / R19:** `corrugated_garage` Light has no earned visual change.
The actual Pristine/Light OBJ files each have **780 triangles**, identical
vertex and triangle arrays and identical `{orange, teal}` material sets. Only
the object names differ. Its four normal/grayscale/front/back sheets likewise
show no scars; this is not simply a subjective preference for stronger damage.
The other five families contain additional scar geometry/materials.
The [exact identity result](garage-light-518a3b3-failed.json) and
[historical front sheet](historical-518a3b3/damage-corrugated_garage-front-normal.png)
preserve this failure separately from any corrected later gallery.

Reproduce by loading the two files with `p16_audit.parse_obj` and comparing
`vertices`, `triangles` and `materials`. The original silhouette-preservation
test correctly accepts Light's intact collision but does not require earned
appearance. Place marks on the retained garage jamb/header surfaces on both
sides, and reject per-family Pristine/Light visual identity while retaining
equal blocking masks. This finding was consolidated with the primary agent
and developer before any approval request.

At that checkpoint, no user had approved the asset and the garage Light fix
and affected visual/data recheck remained required for A2. The following final
section records the actual correction and recheck rather than changing that
failed historical result.

## Garage Light correction

Final source checkpoint: `e8fb840a986969bdd3b7ac932469e3fa8cc99a9e`,
tree `cfb4ed35a15f5a756b3ec86858841f41b7dba577`.

- `.blend`: `4c1c5264020616b1af3b36c9dd37442919b386655149ee207591cd37da041d8c`.
- Assembly FBX: `7cd7549dd8c8852e016e1e32f867a2a2626b6a8d5ef0f0f5d11095e6b44fd6d8`.
- An independent OBJ parser, importing no production auditor, passes **6/6**
  family checks for actual changed Pristine/Light visual data and added scar
  triangles on both faces. Garage Light now has **1,068 versus 780 triangles**,
  including 72 dark plus 72 exposed-metal scar triangles on each face. All
  other five authored damage styles are unchanged.
  See the preserved [independent parser](independent-light-probe.py) and
  [six-family result](light-e8fb840.txt).
- Lightweight final-source checks again pass **324/324 source and 324/324
  clean-FBX headroom samples**, 12 decoded packed source textures, 11
  collections and seven cameras. Factory cross-format import remains
  **2,225 assembly meshes / 89,024 triangles** plus eight valid one-mesh kit
  imports, with maximum bounds difference **0.000007401 studs**.
  The [source result](navigation-e8fb840-source.txt),
  [FBX result](navigation-e8fb840-fbx.txt) and
  [cross-format output](independent-fbx-e8fb840.txt) bind these observations to
  the final artifact hashes.
- The reviewer inspected the four newly regenerated garage sheets, both sides
  in normal and grayscale. Light jamb scores are now clearly present and
  distinct from Pristine; the aperture remains intact. Heavy/Total and the
  corrected captions remain readable. This resolves the remaining A2 technical
  finding. Other five families and assembly geometry are unchanged from the
  complete 29-view review above.
- Independent final `python3 scripts/p16_audit.py` passes **7/7**, zero
  failed/skipped. It binds the saved source, all library/kit imports and the
  complete **29/29** required PNG/source/script receipts, tests all six actual
  Light visual distinctions and Heavy opening masks, validates fragments,
  stable pivots, navigation, UV/materials, dependency hashes and budgets.
- Independent final `python3 -m unittest discover -s tests/assets -v` passes
  **22/22** in **10.276 seconds**, no failures/skips. The added negative cases
  reject Pristine substituted as garage Light, renamed/permuted pristine
  geometry, and an unused dark-material declaration; none creates earned scars.
- The reviewer inspected the primary agent's final complete
  `python3 scripts/verify.py` output on the same unchanged source/art and fresh
  receipts: **10 tooling / 7 asset audits / 22 asset regressions / 55 unit /
  65 integration**, plus all pinned-tool, format/lint/type, deliberate-failure,
  build, reconstruction and release-isolation gates pass. It was not repeated
  unnecessarily. See the [final host log](host.txt).

| Criterion | Final technical outcome | Remaining boundary |
| --- | --- | --- |
| A1 | Inventory/source/exports, two furnished rooms, source navigation and five saved scene/kit views verified | User judges the reference interpretation; actual Roblox walking is P17 |
| A2 | Six families, four states, both-sided scars, actual Heavy openings/proxies, bounded fragments and both-sided normal/grayscale review set verified; all reproduced defects resolved | Mandatory human visual acceptance remains part of A4; runtime behavior is P17 |
| A3 | Clean source reopen, independent factory import parity, self-contained dependencies, all 29 source-bound renders, measured budgets and complete host gate verified | No Blender check is represented as Roblox import/performance evidence |
| A4 | **Pending explicit user approval of the identified final `.blend` revision** | Agent opinion, automation and silence cannot satisfy it |

There are no unresolved reproduced technical findings on this final candidate.
The initial and intermediate failed candidates above remain separately
identified. No merge, upload, publication or user approval was performed by
the tester.
