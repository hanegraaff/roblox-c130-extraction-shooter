# Independent integrated P17 review checkpoint — f378733

Source `f3787331f34ba5623506a239f9d6660044a957b7`, tree
`bbe1dd533f7a9bf18d15bf61688a78ee0adbac1b`, reviewed on 2026-11-14.
No Studio operation or native acceptance run has been performed for this source.
The only connected place currently belongs to the private cloud workspace;
the tester is awaiting the coordinator's explicit local test-document handoff.
Earlier preparation reports are not evidence for this integrated candidate.

Independent `python3 scripts/verify.py` on this exact checkout passes on this Mac:
59 unit / 65 integration, 41 asset regressions, ten manifest regressions,
P16/P17 asset/reconstruction gates, static/format/lint/types, both Rojo builds,
artifact rejection probes and release isolation. It verifies 2,804 authored
Parts in both builds, 5,294 release / 5,386 test Instances and 49 runtime scripts.
Full log: `/tmp/p17-independent-integrated-f378733.txt`.
The separately reported Linux/Python 3.12 CI failure remains a real portability
defect despite that Mac pass; this checkpoint does not call CI successful.

## Consolidated source findings for the developer's correction batch

1. **P1/A1 portability — coordinator-confirmed external failure:** GitHub Verify
   run 43623002662 rejects generated MaterialPanels.model.json reconstruction
   on Linux/Python 3.12 while this Mac passes. Generated numeric construction
   must be deterministic across supported environments. Developer owns the fix;
   no candidate or expected data has been changed by the tester.
2. **P2/A1 malformed pivot preflight — source-proven path; native reproduction
   pending:** OutpostReconstruction.prepare validates panel geometry using the
   Model's pivot but never validates LocalIdentityPivot on the source. It clones
   the assembly, then asserts that attribute's type. Removing the attribute can
   reach an assertion and leave the private clone unreleased instead of the
   documented nil/reason rejection. A wrong valid CFrame can be installed as the
   identity pivot even when it differs from the pivot used during validation.
   Repro: clone Assets, remove or alter one Outpost_Panels child's
   LocalIdentityPivot, then pcall prepare. Require explicit nil/reason before
   cloning/replacing, matching canonical pivots and unchanged active world.
3. **P2/A3–A4 fragment thermal policy — source-proven condition; rendered proof
   pending:** PanelFragments marks actual debris ThermalNonCover=true but emits
   it with CanCollide=true and CanQuery=false. ThermalCosmetics only hides parts
   when both collision and query are false, so that marker has no effect on
   physical fragments. They remain render-depth occluders even though gameplay
   queries exclude them. Fix/test the explicit owned-fragment case while
   preserving visible real solid cover and static-scenery physics. The client
   fixture must use actual fragment flags and the owned collision group; native
   rendered thermal inspection remains separate.

No additional material source defect has been confirmed. Fixed-open doors and
portal meshes are retained as floor-supported cosmetic props; their appearance
after demolition should be inspected before calling them detached/floating art.
The twelve absent native scalar PBR maps are an explicitly recorded A6 visual
review limitation, not grounds to pretend the original materials imported fully.

The tester changed no source, tests, assets, baselines, documentation, Git state
or Studio state. All A1–A6 native navigation/material/replication/reset/fragment/
performance/operated/human gates remain open at this checkpoint.
