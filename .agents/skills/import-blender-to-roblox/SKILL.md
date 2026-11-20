---
name: import-blender-to-roblox
description: Integrate finished Blender assets into a Roblox experience with verified scale, pivots, materials, collision, placement and source reconstruction. Use for Studio imports, replacements, environment kits and walkable or destructible buildings that need native playtest evidence.
---

# Import Blender assets into Roblox

Deliver a native, playable import that the project can rebuild from managed source. Preserve existing gameplay contracts and permissions. Read the [native reconstruction guide](references/native-reconstruction.md) when retaining MeshPart data in source or diagnosing mismatched dimensions, collision or materials.

## Preflight the package and destination

1. Identify the exact Blender source/export revision and the object's intended position, dimensions, source up/front axes and pivots. Record the unit conversion and intended Roblox transform. Reopen a clean export and use at least one asymmetric landmark and a known dimension to check axis signs and scale. Capture the active map's adjacent routes, existing anchors and IDs if replacing an asset.
2. Identify the intended Studio document, target experience/place and asset owner or group. Inspect active Studio instances first, select the exact target and consult its connected Studio skill guidance where available. Preserve unsaved changes and use an isolated test document for experimental imports and test overrides.
3. Identify rights and expected access for source assets and textures. Use the project's authorized local or cloud import route. Confirm any required external asset creation, permission changes, place save and publication against their actual destination and existing authorization. Verify access for the experience, including its meshes and image dependencies. See [Roblox asset privacy](https://create.roblox.com/docs/projects/assets/privacy).

## Import and bind the assembly

1. Try a representative piece through the target [Studio Importer](https://create.roblox.com/docs/studio/importer) before a large batch. Inspect the native hierarchy, owned MeshParts and texture slots. Record actual import warnings, asset and package identities, local transforms and native dimensions. If an import loses material boundaries, use a material-split export or a supported alternate format and verify vertex, UV and material equivalence.
2. Keep intended world `Size`, pivot and transform separate from engine mesh identity, intrinsic `MeshSize` and collision fidelity. Verify the loaded render and collision after placement. For scripted/source reconstruction, retain genuine supported native MeshParts and their engine data as described in the reconstruction guide.
3. Assign visual dressing, stable structural collision and deliberate cover explicitly. Use deliberate `CanCollide`, `CanQuery`, `CanTouch` and collision-group settings. Ensure door and window apertures remain open in the applicable render, movement and gameplay queries. Inspect imported scripts and remove unintended code before using the assembly.
4. Attach authored parts and optional damage states to the game's existing systems. Keep authoritative cover, damage rules, fragments and reset in shared game code. For destructible imports, use stable IDs and aligned poses, match each appearance to its residual query and collision geometry, bind obstructing dressing to its owner, and verify resets restore pristine references.

## Walkable interiors and camera

Walk representative avatars through actual furnished routes, thresholds, both floors and any stairs or balconies. Check the normal outdoor camera at representative zooms and pitch angles inside. Improve geometry when avatar movement is constrained and scope permits such a change.

When compact rooms need camera assistance, author interior regions in the project's managed level data. For example, a level can use per-floor oriented bounds and a positive camera distance cap. Follow the project's schema and lifecycle, express positions and distances in studs, and keep interior bounds from bleeding onto exterior balconies and roofs. Use the shared local ground-camera owner to smoothly shorten camera distance on entry, preserve a player's nearer zoom, and restore the previous outdoor preference on exit. Keep gameplay cover opaque, validate actual obstructions with the project's camera policy, and release ownership across death, role changes, camera replacement, region removal and teardown. Regions serve presentation only and must leave collision, queries and authority intact.

## Rebuild and verify

- Persist approved source, exports, texture provenance, measured import receipts, required IDs/access, model data and deterministic placement in the project's source-of-truth paths. Update the manifest and mapping together. In a Rojo project, sync the correct project into the same confirmed document in Edit mode, then start a fresh test. Export intended Studio-authored changes before relying on them. A new Studio process is unnecessary for normal source refresh.
- Load a clean build. Check visible geometry and material channels on a real client, bounds/pivots in the place, movement, collision and relevant game queries. Compare actual camera entry, exit and stair transitions. Verify repeatable reset and client replication when the game requires them. Inspect render appearance separate from bounds and collision accuracy.
- If tools disconnect or return an unnamed or unavailable place, recheck the current document, mode, Studio MCP connection and matching Rojo sync. Recover the existing valid document or follow its documented setup. Preserve independent source work and report any native evidence or cloud access still pending.
- Record the tested source/export revisions, real owner and asset IDs, test environment and actual evidence. Separate clean Blender/export checks, native Studio observations and review of the in-game result. Keep test assets and test controls out of release mappings.
