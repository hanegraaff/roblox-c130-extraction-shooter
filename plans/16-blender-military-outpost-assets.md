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

This document defines future work; it does not deliver a Blender asset or human approval. No live building replacement is part of P16. Record A1–A4 outcomes, exact tool versions/commands, source/export hashes, budgets, reference provenance, feedback iterations, explicit human approval, committed asset paths and PR/commit delivery here when executed. P17 consumes that approved package revision. Status remains in the roadmap.
