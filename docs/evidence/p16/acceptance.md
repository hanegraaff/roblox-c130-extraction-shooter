# P16 candidate verification and human review

Review date: 2026-11-13 (America/New_York). P16 creates Blender assets; P17
owns gameplay integration. No Roblox upload, engine import, collision,
thermal, replication or runtime-performance pass is claimed here.

## Source and environment

- Dedicated branch: `plan/16-blender-military-outpost-assets`.
- Dependency base: `e6944cdf21f519bd10b748b5a794e764be2a6575`, matching
  fetched `origin/docs/military-outpost-blender-plans`, planning PR #34.
- Final authored source: `e8fb840a986969bdd3b7ac932469e3fa8cc99a9e`, tree
  `cfb4ed35a15f5a756b3ec86858841f41b7dba577`. Subsequent delivery commits
  add review evidence and documentation without changing these assets/scripts.
- Blender: `/Applications/Blender.app/Contents/MacOS/Blender`, version
  5.3.0, build `02f0899d78e3` (2026-11-10).
- Initial scale, triangle/texture budgets and ordinary-Git storage: D64 in
  [decisions](../../decisions.md). Budgets were selected before production.
- Reference images remain user-supplied reference illustrations; generated
  project meshes/textures must be original local authoring. No rights to the
  reference images are inferred beyond their supplied reference purpose.

## Preflight checks

`python3 scripts/verify.py` passed before the art package was added:
55 unit / 65 integration cases, zero ordinary failures/skips, plus the
existing deliberate negative probes and static/build/reconstruction/isolation
gates. This is a baseline, not final asset acceptance.

`python3 -m unittest discover -s tests/tooling -v` passed 10 manifest checks.
They cover complete source/export provenance, missing dependencies,
unrecorded texture files, changed hashes, required hashes, duplicate and
noncanonical paths, backups, file-size limits and path escape rejection.
The first disposable-fixture run exposed macOS `/var` versus `/private/var`
path resolution in the new optional root adapter. Resolving the fixture root
fixed the validator; the repeated ten-case run passed. This was tooling
development, not a Blender/gameplay failure or visual-approval result.

Studio MCP returned `{"studios":[]}` at preflight. No Studio session was
launched or mutated. P16 changes no engine/player behavior; Blender asset
checks are its required environment. P17 must independently establish
actual imported behavior and engine cost.

## Acceptance ledger

| Criterion | Required evidence | Current result |
| --- | --- | --- |
| A1 | P16AssetInventory; P16Navigation; exterior and both furnished-floor saved-scene renders | Technical checks pass: 36 categories, two furnished floors; 185 body stations / 1,850 support rays on OBJ, saved source and clean FBX; independent 324/324 tread samples on source and another 324/324 on clean FBX |
| A2 | P16DamageCatalog; P16PanelGeometry; independent per-family Light parser; both-sided normal/grayscale material gallery | Six families / 24 states / 24 fragments; 25 retained legacy pivots plus one declared partition. Heavy opening 48.295–50%; no sampled invisible blockers, Light preserves apertures and Total is empty. All six have actual two-sided earned scars; complete 29-view review and targeted corrected garage review resolve all material findings |
| A3 | P16BlenderReopen; P16ExportAudit; full final host gate; source/export hashes | Clean Blender reopen / assembly, library and eight-kit imports pass. All 29 source/script/hash-bound PNGs pass. Full host: 55 unit / 65 integration, 10 manifest cases, 22 asset cases, seven asset suites and all existing gates pass |
| A4 | Explicit human approval of the identified saved asset revision after viewing all required scenes | Pending; no approval inferred |

The [independent review](independent-review.md) distinguishes initial failures,
corrected measured outcomes and subjective fidelity. P17 remains unstarted.

## Final review revision

Open the [saved Blender scene](../../../assets/blender/military-outpost/military-outpost.blend)
with the [inspection guide](../../../assets/blender/military-outpost/README.md).
The final `.blend` SHA-256 is
`4c1c5264020616b1af3b36c9dd37442919b386655149ee207591cd37da041d8c`;
assembly FBX SHA-256 is
`7cd7549dd8c8852e016e1e32f867a2a2626b6a8d5ef0f0f5d11095e6b44fd6d8`.
The [current render manifest](render-manifest.json) binds source `e8fb840`,
confirms `source_commit_matches_art=true`, and records all 29 images plus
review-script SHA-256
`cbd3144099c1ddfb2d784a86565e04243451cf97d2b1e153dea0457aa0666384`.
The repeated full render command below exited zero in **2m49.96s**. The five
assembly/kit views and all 24 material sheets are actual Blender renders.

The final [asset audit](asset-audit.json) passes **7/7**; final developer
regressions pass **22/22** (10.789s). The primary agent repeated the complete
`python3 scripts/verify.py` on this unchanged authored source and fresh
evidence: **55/55 unit, 65/65 integration, 10/10 manifest cases, 22/22 asset
cases and seven asset suites**, zero ordinary failures/skips, plus every
format/lint/type/build/reconstruction/isolation and expected rejection gate.
See the [final host log](host.txt). Subsequent prose/records are checked by
`python3 scripts/check_repository.py` and `git diff --check`.

The independent final [Light probe](independent-light-probe.py) uses its own
OBJ parser: [all six families pass](light-e8fb840.txt) actual two-sided scar
comparison. Garage Light has 1,068 triangles versus 780 Pristine, with 72
dark and 72 exposed-metal scar triangles on **each** face. This adds earned
visuals without changing the blocking/aperture masks. Independent targeted
review of its four final sheets confirms visible normal/grayscale distinction.
This closes the historical A2 failure, not the human taste/approval gate.

Fresh independent [source](navigation-e8fb840-source.txt) and
[clean-FBX](navigation-e8fb840-fbx.txt) traversal probes each pass 324/324;
[cross-format/texture parity](independent-fbx-e8fb840.txt) passes again with
2,225 assembly meshes / 89,024 triangles and all eight one-mesh prop exports,
maximum bounds difference 0.000007401 studs. The seven-suite audit includes
185 full-body stations / 1,850 support rays on saved source, OBJ and clean
FBX, plus three navigation corruption rejections. Geometry checks do not
claim native Roblox Humanoid traversal.

Final budgets: **89,024 assembled / 137,076 unique package triangles**, of
which 11,292 are reusable-kit triangles; 12 shared 512×512 PNG materials,
12 MiB decoded base data / 16 MiB estimated with mipmaps. Art is 31,876,595
bytes excluding its lock, **31,897,836 bytes including the lock** across 110
manifest files. The largest file remains the 8,466,076-byte assembly FBX.
All original D64 targets pass. The package lock covers 109 files and the
global manifest additionally hashes that lock; no cloud/LFS dependency exists.

The separate technical writer completed the player/setup, contributor,
architecture and source/export guides. The final repository checker passes
91 Markdown / 223 JSON files and `git diff --check` passes. The representative
README image is the still-current actual P08 capture, not a Blender preview.
The independent reviewer reports no unresolved reproduced technical defect;
its final audit passes 7/7 and asset regressions 22/22 (10.276s), with raw
[audit](independent-final-audit.txt) and [tests](independent-final-tests.txt).

The explicit human response, date, conditions and approved asset hash remain
**pending**. Draft [PR #35](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/35)
delivers the candidate; P16 remains in progress and P17 has not started.

Delivery commit `751f2ea16ea74e6a6de732b0ca6ab96978ea081c`, tree
`f990792a3c750aa6448a60ab1b77ecd4d4a7404d`, contains the corrected source,
all final views, report and guides.
[GitHub Verify 43541991864](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/43541991864)
passes on that exact commit. PR #35 is draft/open/mergeable against the
planning branch. The file-open command succeeded in a separate Blender
instance; the user was asked to inspect and approve or request changes for
source `e8fb840` / asset hash `4c1c5264…`. No response has been received or
inferred. The final records commit does not alter the tested art or scripts.

## Intermediate package checks and required commands

The 518a3b3 results in this section are historical, **not final A2 acceptance**.
After all 29 views were reviewed, the tester found `corrugated_garage` Light
identical to Pristine: both 780 triangles, equal vertices/triangles and only
`orange`/`teal` materials. All initial scar sample positions fell in the
authored garage opening and were skipped. The
[measured failure](garage-light-518a3b3-failed.json),
[seven-suite audit](asset-audit-518a3b3.json) and
[passing but insufficient-coverage host log](host-518a3b3.txt) preserve that
distinction. The developer is adding scars on both retained jambs plus
all-family actual scar-geometry rejection coverage. No other material defect
was found in the complete 29-view review; a new candidate needs fresh evidence.

Review file: [military-outpost.blend](../../../assets/blender/military-outpost/military-outpost.blend).
Its SHA-256 is
`08277437457c0538d0767c97bffa784a8b0e511d4f7bee2c1e37cf66a89b7c93`;
assembly FBX is
`8cb1910ec3dfd923683ffc3d4acd4f1e7ee622f2c10d3660944a1652cf91a2e8`.
The [render manifest](render-manifest.json) identifies source commit `518a3b3`,
confirms `source_commit_matches_art=true`, and binds review-script SHA-256
`cbd3144099c1ddfb2d784a86565e04243451cf97d2b1e153dea0457aa0666384`
plus all 29 PNG paths, hashes, dimensions and modes. Rendering completed with
exit zero in 3m29.9s using Cycles CPU / 24 samples / denoising and native PNG
BW grayscale. Review the [exterior](exterior.png), [workshop](floor-1.png),
[command room](floor-2.png), [cutaway](cutaway.png), [reusable kit](isolated-kit.png)
and the complete [two-sided gallery index](../../../assets/blender/military-outpost/README.md#saved-scene-previews).

Executed authoring/tool commands (repository root, macOS arm64, Blender 5.3.0):

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python-exit-code 1 --python scripts/p16_build.py
/Applications/Blender.app/Contents/MacOS/Blender --background assets/blender/military-outpost/military-outpost.blend --python-exit-code 1 --python scripts/p16_blender_review.py -- --audit --fbx-audit
/Applications/Blender.app/Contents/MacOS/Blender --background assets/blender/military-outpost/military-outpost.blend --python-exit-code 1 --python scripts/p16_blender_review.py -- --render
python3 scripts/p16_audit.py --write-lock
python3 scripts/refresh_outpost_manifest.py
python3 scripts/p16_audit.py --output docs/evidence/p16/asset-audit.json
python3 -m unittest discover -s tests/assets -p test_p16_assets.py -v
python3 scripts/verify.py
```

Intermediate results: [asset audit](asset-audit-518a3b3.json) **7/7**; asset regression **19/19**
(developer 9.363s, final full host 9.203s); manifest regression **10/10**
(intermediate full host 0.045s); [full host log](host-518a3b3.txt) records **55/55 unit,
65/65 integration**, zero ordinary failures/skips and all expected negative
probes, format/lint/types, builds, geometry and release isolation. Deliberate
failing/empty/corrupt fixtures are expected rejections, not ordinary failures.
The later garage Light correction changed this candidate and required the
fresh final evidence above; these intermediate successes do not prove A2.

The independent factory probes preserve [source traversal](navigation-518a3b3-source.txt),
[FBX traversal](navigation-518a3b3-fbx.txt) and [FBX/OBJ/texture parity](independent-fbx-518a3b3.txt).
Source and FBX traversal each pass 324/324 upward checks. Independent import
compares 2,225 assembly meshes / 89,024 triangles and all eight one-mesh prop
exports; maximum cross-format bounds error is 0.000007401 studs. These are
authored geometry/tool results, with no Roblox server or actual client count.

Measured package: **89,024 assembled triangles; 136,788 unique package
triangles**, including 11,292 reusable-kit triangles. Twelve shared 512×512
textures decode to 12,582,912 bytes (12 MiB), with 16,777,216 bytes estimated
including mipmaps. Art is 31,849,884 bytes excluding its lock, **31,871,125
bytes including the lock across 110 manifest files**. Largest file is the
assembly FBX at 8,466,076 bytes. These satisfy D64's original targets; actual
Roblox cost remains a P17/P11 measurement. The lock hashes 109 files; the
global manifest additionally hashes the lock itself. Markdown is prose and
is excluded from art hashes.

The human review guide discloses compressed reference proportions, extrapolated
rear elevations, fixed-open doors/windows, the new partition and v2 aperture
migration. Materials do not change durability; no shared damage timing,
runtime collision, thermal, fragment authority or map source was changed.

Delivery: [draft PR #35](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/35),
stacked on planning PR #34. No merge or Roblox publication occurred. Human
feedback was not requested for that intermediate revision; the final review
candidate and pending approval hash are identified above.

## Initial candidate findings (historical)

Source `9c0ac4275133831b1d6b1f5d2083c319c1a26933`, tree
`7c0e290a0deed0f51b50ebc4845fd224d790e9d3`, passed its full host gate
([log](host-9c0ac42.txt)) and [GitHub Verify 43539357514](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/43539357514).
Its Blender hash was
`22d668fff653832915868e09c25e25d2b4e24f92255394984bc1819ff9f2b8f8`.
Those successful checks did **not** establish usable stair routes: the
independent tester found two material authored-geometry defects, so this
candidate was not accepted or presented for human approval.

- Internal stair: source ray probes at `(-10,-0.3,5.145)` and
  `(-10,0.3,5.770)` met `Cross beam.001` after 2.980 and 2.355 studs.
  The beam interrupted the required six-stud upright headroom.
- External stair: the unbroken balcony slab intersected the flight; steps
  7–19 had insufficient headroom, down to 0.355 studs beneath its underside.
- Gallery: faint, tiny and partly reversed captions impaired review. Light
  scored metal/concrete cracks remained distinguishable at full image scale;
  the tester did not reproduce a separate material-damage blocker.

The [independent source probe](navigation-probe.py) and its
[initial measured output](navigation-9c0ac42-failed.txt) preserve these
observations. A separate factory-startup
[cross-format FBX/OBJ probe](independent-fbx-probe.py) passed on this source
([raw output](independent-fbx-9c0ac42.txt)); it cannot cancel the navigation
defects. The consolidated findings were returned to the developer for
correction and actual-geometry route regressions. New source needs fresh
checks and re-rendered views; old successes are not relabelled.

Earlier authoring probes also exposed nearly empty FBX output from hidden
library collections, stale hidden proxy transforms, underlit interior cameras,
repetitive concrete texture and mirrored/omitted lettering. These were corrected
before `9c0ac42`. A GPU compositor render aborted (exit 134) when Metal was
unavailable; the subsequent native CPU PNG BW path produced the 29 requested
views. These are historical tool/authoring failures, not gameplay or Studio
results. Final render metadata must match the corrected source revision.
