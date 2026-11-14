# P16 — Detailed military-outpost assets in Blender

**Milestone:** M4 / Blender authoring. **Dependencies:** P07, P13. **Requirements:** R01, R09, R15, R16, R19. Status: [roadmap](../roadmap.md).

**Sequence (D63):** Next implementation increment, placed after P07 and before P08 in roadmap order. Complete this plan and obtain human approval before P17; P09 waits for both asset increments. Plan IDs remain stable.

## Capability and human experience

Open a detailed, editable two-story military outpost in Blender, inspect its furnished interior and exterior, and compare material-specific damage variants. Closely match all three user-supplied references. The user must like the result and explicitly approve the delivered asset revision before this plan can finish. P17 then replaces the current smaller Outpost with that approved revision.

This plan creates real 3D meshes, materials, textures and a reusable asset kit, an assembled building and rendered previews. Renders alone do not satisfy it. The existing playable battlefield stays in place during authoring; runtime replacement and multiplayer demolition acceptance belong to P17.

## Reference and scope contract

The actual directory is `src/images/military-outpost/`, rather than the prompt's `military-outpust` spelling. Preserve these filenames:

| Reference | Required interpretation |
| --- | --- |
| [Exterior](../src/images/military-outpost/outpust-exterior.png) | Weathered concrete frame, teal corrugated cladding, orange stripe, two stories, garage and pedestrian entrances, windows, external stairs/balcony, rooftop utilities and surrounding outpost props |
| [Floor 1](../src/images/military-outpost/outpost-interior-floor-1.png) | Furnished storage/workshop with shelving, stacked cases, workbench/tools, service infrastructure and a clear central circulation route |
| [Floor 2](../src/images/military-outpost/outpost-interior-floor-2.png) | Furnished command room with consoles, screens, server/radio equipment, chairs, central tactical table and storage |

The user confirmed on 2026-11-13 that all three should be matched closely and that the **smaller Outpost** is the eventual replacement target. Retain the references' worn, detailed industrial style and recognizable silhouette, palette and room functions. Adapt inconsistent perspective or unspecified rear elevations into a coherent building; record those interpretations. Reference characters establish avatar scale; they do not request NPCs. Background desert/sky is presentation context, not a second level or a terrain replacement. Display the references' pre-existing wall breach in a damage preview, with a complete pristine counterpart for round start.

Inventory all visible outpost assets before production. Include the following, with reusable variants where appropriate:

- **Exterior/building kit:** foundations, stable concrete frame, both usable floors, wall and roof modules, parapets, garage/door frames, doors, window frames, external stairs, balcony, railings, awnings, vents, pipes, conduits and lamps; rooftop HVAC/ducts, aerial mast and satellite dish.
- **Outdoor dressing:** concrete barriers, bollards, crates/cases, pallets, tanks/containers, markings and material-matched rubble. Keep dressing inside the agreed Outpost site envelope.
- **Ground-floor kit:** racks, cases/containers, workbench, tool board/tools, drawers, stool, lights, ducts, wiring and floor markings.
- **Upper-floor kit:** desks/consoles, monitor and radio equipment, server racks, chairs, tactical table, shelving/cases, lamps, cables and floor details. Screens and tactical graphics are visual props; interactive computers are outside this plan.

## Implementation

### 1. Establish scale, assembly and asset organization

Inspect the installed Blender version and available authoring/export tools at execution time; record the actual version and workflow. Work on `plan/16-blender-military-outpost-assets`, including dependency source. Use a saved project scene with named collections for structure, destructible panels, each furnished floor, exterior dressing, damage samples and preview cameras/lights. Provide an assembled view, isolated asset view and a cutaway or hideable roof/walls for inspecting both interiors.

Start from the smaller Outpost's current 32×48-stud footprint and two accessible stories. Record Blender-to-stud scale, up/forward axes, origins, dimensions and export transforms; include an avatar-scale guide. Plan stairs, balcony and dressing within a surveyed site envelope so P17 preserves map routes. D62 identifies these as construction defaults, not user-selected dimensions. If faithful proportions require changes, document their navigation/aim-envelope impact before accepting a final assembly. Retain stable floors, stairs and supporting structure under the existing destruction contract.

### 2. Model and texture the complete asset set

Build actual detailed meshes with intentional topology, UVs, consistent material scale and original or appropriately licensed textures. Model silhouette and close-view features; use baked textures for suitable fine detail. Keep editable source separate from game exports and simple collision proxies. Record mesh/triangle counts, material/texture counts and estimated texture memory for the assembled building, including all damage variants. Select initial budgets before production and record them as tuning defaults, then measure exports; P17 must validate actual engine cost.

Use material families that follow the references: weathered concrete, painted corrugated steel, structural metal, roof surfacing and prop materials. Share reusable materials without making concrete fracture look like torn sheet metal. Do not rely on Blender-only procedural shading for the Roblox appearance: provide baked texture equivalents and an export material map. Record any engine-visible compromise before human approval.

### 3. Author destructible panels and matching damage

Use a versioned panel-asset catalog linking each panel family/material to its source collection, dimensions, pivot, pristine mesh, Light appearance, Heavy residual geometry, Total state, collision proxies and fragment set. Include exterior and interior wall panels and roof panels; produce separate shapes for corners, doors/windows or materials when a single variant cannot fit correctly. Preserve a mapping to the existing Outpost panel IDs/pivots or explicitly version any necessary migration for P17.

For **every destructible material/shape family**, provide side-by-side, two-sided previews of:

| Appearance | Authored result and gameplay constraint |
| --- | --- |
| Pristine | Complete original panel with matching material and intact blocking surface |
| Light | Clearly visible, persistent material-specific scars below the first structural threshold; no gameplay opening |
| Heavy | Material-specific fractured/torn residuals with a real roughly half-face opening; target the existing 45–55% opening default and compatible collision proxies |
| Total | Panel and its blocking proxies absent; stable supporting frame remains |
| Fragments | Bounded export pieces that match the damaged material and fit the existing debris safety/size/count limits |

Concrete should chip/fracture, corrugated metal should tear/bend, and roof damage should expose the roof's actual layered construction. Apply this requirement to the final material inventory rather than merely recoloring one universal cracked panel. Show readable geometry/luminance cues in neutral and grayscale previews. Cosmetic weathering must remain distinguishable from earned combat damage.

Preserve core rules: third direct 105mm hit produces Heavy, sixth produces Total; nine valid 30mm seconds advances each stage, with earned damage retained and interrupted timing broken. Materials change appearance, not durability. Blender previews illustrate these states; they do not prove server timing, collision, thermal occlusion or fragment physics. Do not add full building collapse, destructible support frames or new door/glass gameplay implicitly. D62 records proposed prop/window handling; P17 assigns and tests actual collision/query behavior.

### 4. Save a self-contained review and export package

Use these proposed managed paths, creating them during implementation:

| Path | Deliverable |
| --- | --- |
| `assets/blender/military-outpost/military-outpost.blend` | Editable assembled building, reusable meshes/materials, damage gallery and review views |
| `assets/blender/military-outpost/README.md` | Blender version, open/inspect instructions, collection map, scale/axes, export recipe, budgets and known compromises |
| `assets/blender/military-outpost/` | Packed dependencies or versioned relative texture sources, asset inventory and panel catalog; authoring scripts if used |
| `assets/exports/military-outpost/` | Versioned game meshes, baked textures, collision proxies and catalog needed by P17; proposed FBX/PNG route validated against installed tools |
| `docs/evidence/p16/` | Exterior and both furnished-floor renders, material damage contact sheets, technical audit, candidate hashes and human feedback/approval |

Extend the asset manifest/checker deliberately to cover the new source/export directories, retain provenance and reject missing dependencies; the current manifest checker covers `assets/world` and `assets/models` only. Agree a documented versioned storage/LFS approach before adding large binaries. Exclude render caches, `.blend1` backups and temporary files. Keep all required source and exports accessible from a clean checkout; never invent uploaded asset IDs, owners or licenses.

Reopen the saved `.blend` in a clean Blender process and verify every material/texture dependency, collection and review camera. Produce actual Blender exterior, floor-1, floor-2 and damage-gallery renders from this saved revision. Give the user the exact file path and simple instructions to orbit the building, hide the roof, inspect each floor and inspect damage variants. Open the candidate for inspection when tooling permits without discarding their unsaved Blender work. Iterate on their feedback, regenerate affected exports/renders, and request approval of the final concrete revision.

## Acceptance criteria

- **A1 — Complete detailed kit:** The inventory accounts for all outpost assets in the three references, with an assembled furnished exterior and two usable interiors. The `.blend` contains editable 3D assets, materials and organized review views; substitutions/interpretations are disclosed. Verify with `P16AssetInventory` and the three saved-scene renders.
- **A2 — Material-correct destruction assets:** `P16DamageCatalog` audits every destructible material/shape family, stable identity/pivot mapping, all four appearances and bounded fragment exports. `P16PanelGeometry` measures the Heavy opening and validates transforms/proxy coverage against the intended silhouettes; Light remains whole and Total has no panel solid. Human damage-gallery review covers both sides, normal and grayscale. Runtime destruction is still P17 acceptance.
- **A3 — Reopenable and reconstructable:** `P16BlenderReopen` opens the saved source with no missing dependencies and renders exterior, both interiors and damage views. `P16ExportAudit` validates named assets, UVs/material mapping, scale/axes and measured budgets. The full existing `python3 scripts/verify.py` gate plus the added asset validators pass; exact Blender/audit commands, counts and source/export hashes are recorded. No gameplay or Studio pass is inferred from Blender renders.
- **A4 — Human likes the result (mandatory final gate):** After receiving the actual `.blend` and reviewing exterior, both interiors and material-specific damage, the user explicitly confirms they like/approve that identified revision. Record their response, date, candidate hash and any conditions. Pending feedback, silence, automation or an agent's opinion cannot satisfy this criterion. Requested material changes require a new review of the affected result.

## Delivery and completion record

Implementation started on 2026-11-13 on `plan/16-blender-military-outpost-assets`,
from `e6944cdf21f519bd10b748b5a794e764be2a6575`. This includes P07/P13
dependency source and the unmerged P08/acceptance/planning stack through PR #34.
Remote fetch confirmed the dependency branch at that same hash before edits;
no integration or publication is authorized by this work.

Installed authoring tool: Blender **5.3.0**, build `02f0899d78e3` (2026-11-10),
via `/Applications/Blender.app/Contents/MacOS/Blender`. D64 records the scale,
initial budgets and ordinary-Git storage decision chosen before production.
All three supplied references were visually inspected. The separate developer
owns source/assets/tests, followed by independent tester and technical-writer
review of the actual candidate. No live building replacement is part of P16.

Final authored source is `e8fb840a986969bdd3b7ac932469e3fa8cc99a9e`, tree
`cfb4ed35a15f5a756b3ec86858841f41b7dba577`. The editable scene is
[`military-outpost.blend`](../assets/blender/military-outpost/military-outpost.blend),
SHA-256 `4c1c5264020616b1af3b36c9dd37442919b386655149ee207591cd37da041d8c`.
Assembly FBX SHA-256 is
`7cd7549dd8c8852e016e1e32f867a2a2626b6a8d5ef0f0f5d11095e6b44fd6d8`.
The [review guide](../assets/blender/military-outpost/README.md) explains
orbiting, camera selection, interior/roof inspection and both-sided
normal/grayscale damage review. [PR #35](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/35)
is stacked on planning PR #34, preserving the dependency source without merging it.

| Criterion | Named evidence and environment | Outcome |
| --- | --- | --- |
| A1 | `P16AssetInventory`, `P16Navigation`, saved-scene exterior/both-floor/cutaway/kit renders; Blender 5.3.0 / local OBJ/FBX | 36 inventory categories; two furnished floors; 185 body stations / 1,850 support rays across both routes on actual OBJ, saved source and clean FBX. Independent source and FBX probes each pass 324/324 tread samples |
| A2 | `P16DamageCatalog`, `P16PanelGeometry`, independent per-family Light parser and two-sided normal/grayscale review | Six families, 24 appearances, 24 bounded fragments; all 25 legacy IDs/pivots retained plus one declared partition. Heavy opening 48.295–50%; zero sampled invisible blocker cells; Light keeps pristine apertures, Total is empty. All six families have actual earned scar geometry on both faces; full 29-view and corrected garage review pass with no remaining material finding |
| A3 | `P16BlenderReopen`, `P16ExportAudit`, `P16Dependencies`, full `python3 scripts/verify.py`; macOS arm64 / Blender 5.3.0 | Clean reopen / assembly, library and eight semantic-kit imports pass; all dependencies local. Final 29 source/script/image-bound views pass. Full gate: 55 unit / 65 integration, seven asset suites, 22 asset cases, 10 manifest cases and every existing static/build/probe/isolation gate pass |
| A4 | Explicit human review of the exact `.blend` hash above, exterior, both interiors and every material family | **Pass.** On 2026-11-13 (America/New_York), the user answered “Approve this asset revision” to the revision-specific review question. No conditions were specified; [approval record](../docs/evidence/p16/human-approval.json) |

The [acceptance ledger](../docs/evidence/p16/acceptance.md) records commands,
source-bound measurements, test counts, actual tool failures and feedback.
The [independent report](../docs/evidence/p16/independent-review.md) preserves
the initial navigation/proof defects and intermediate missing garage Light
appearance, with corrections/rechecks distinguished from the old passing but
insufficient-coverage gates. Historical failures are not relabelled.

Final measured art: 89,024 assembled / 137,076 unique package triangles
(11,292 reusable-kit triangles), 12 shared 512×512 textures, 12 MiB decoded
base texture data / 16 MiB estimated with mipmaps, and 31,897,836 bytes
including the package lock across 110 manifest files. Largest file is the
8,466,076-byte assembly FBX. These satisfy the original D64 targets; actual
Roblox runtime cost remains P17/P11 work. Source/export provenance, hashes,
scale/axes, fixed-open aperture migration and reference-proportion compromises
are documented with the package. Material appearance does not alter durability.

The technical writer updated the whole player/setup narrative and contributor,
architecture and package guides after source stabilization. The actual P08
gameplay screenshot remains current because no playable geometry changed.
Studio MCP listed no connected instances at preflight; no Studio session was
launched or mutated. P16 requires Blender checks, with no new engine/player
behavior or Studio pass claimed. P17 and Roblox publication have not started.
Review source, all 29 renders, historical failures, independent report and
documentation were committed/pushed at
`751f2ea16ea74e6a6de732b0ca6ab96978ea081c`, tree
`f990792a3c750aa6448a60ab1b77ecd4d4a7404d`. GitHub
[Verify 43541991864](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/43541991864)
passes on that exact delivery head. The final prose checker passes 91 Markdown /
223 JSON files and diff checks were clean at delivery. PR #35 is now ready for review, open and mergeable,
targeting `docs/military-outpost-blender-plans`; no merge was performed.
The verified file was launched with `open -n -a /Applications/Blender.app`
for inspection in a separate instance. An explicit approval/change request
was presented for source `e8fb840` / `.blend` hash `4c1c5264…`.

On 2026-11-13 (America/New_York), the user explicitly replied **“Approve this
asset revision”**. This satisfies A4 for the exact source/asset identified
above, including exterior, both furnished interiors and the two-sided
normal/grayscale material gallery. No conditions were specified. The
[machine-readable record](../docs/evidence/p16/human-approval.json) preserves
that response and identity. The `.blend`, exports, lock and render bytes were
not changed to record approval; future visual revisions need their own review.
All A1–A4 evidence is satisfied. P17 is eligible but unstarted. This approval
does not authorize merging PR #35 or publishing to Roblox.

The pre-approval records head `8b469e240a9d6f7b69c4b4e4231cfc13092d11f7`
also passes [Verify 43542134119](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/43542134119).
Approval/completion updates are prose and evidence only, checked with the
repository checker and unchanged-asset audit rather than repeating gameplay
or Blender execution.
The approval identity check confirms the current Blender bytes match the
approved full hash. `python3 scripts/p16_audit.py` passes 7/7 with no failures
or skips; `python3 scripts/check_repository.py` passes 91 Markdown / 224 JSON
files and `git diff --check` passes. Only the P16/P17 roadmap statuses changed;
P17 implementation files, runtime source and asset bytes are unchanged.
