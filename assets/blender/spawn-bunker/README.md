# Sandbreak bunker

The [editable Blender source](sandbreak-bunker.blend) contains the 62.5 × 50-stud bunker, three vehicle wrecks, the relay tower and hut, and the sand banks. Frame 1 shows the site. Frames 21 and 41 show the interior and roof breach. Frames 121, 141, 161 and 181 show the exterior props. The visual references are in [src/images/spawn-building](../../../src/images/spawn-building/).

## Stage an import

Run these commands from the repository root with Blender 5.3.

```sh
BLENDER=/Applications/Blender.app/Contents/MacOS/Blender
"$BLENDER" -b assets/blender/spawn-bunker/sandbreak-bunker.blend --python-exit-code 1 -P scripts/sandbreak/prepare_import.py
"$BLENDER" -b --python-exit-code 1 -P scripts/sandbreak/verify_import.py
```

Approve the repository's `build/sandbreak-import` folder under **Upload folders** in the intended Studio place's MCP permissions. This is the folder where the scripts write the GLBs and their receipts. [Roblox MCP permissions](https://create.roblox.com/docs/studio/mcp-open-cloud#upload-folders)

Start with `pilot.glb`, which has one wall panel and one roof panel. Use **Studs**, retain imported pivots, and leave **Merge Meshes** off so each structural panel remains addressable. Use the pilot to verify axis signs, dimensions and material loading in the target Studio document before importing the remaining batches. The pilot duplicates two panels in the production batches. [Roblox Importer settings](https://create.roblox.com/docs/studio/importer#file-geometry)

`import-index.json` contains the source and output hashes, per-object pivots and bounds, support-panel associations, and the 103 panel identifiers with their appearances and query forms. Dimensions and poses are in the GLB axis basis. One Blender unit is one stud. Blender `(X, Y, Z)` maps to asset-local `(X, Z, -Y)`. The candidate map pivot is Roblox `(0, 0, 120)` at the hall floor. Check the northeast roof breach and relay, the southwest tank, and the nine existing spawn anchors at that placement. `round-trip.json` records the Blender reimport checks.

The export bakes procedural base color into repeating 256 × 256 tiles. The source retains world-position shader variation, bump and glass transmission. The staging GLBs preserve the modeled weathering, glass fractures and panel geometry. Verify surface color and glass appearance during the native pilot. Review cameras, presentation lights and the backdrop are outside the package.

## Native integration checks

- Use `panel-pristine`, `panel-light` and `panel-heavy` for visuals, `query-solid` and `query-residual` for the corresponding query shapes, and clear both at Total. Bind the assets and panel-owned dressing by ID using the receipt. Verify weapon rays and actual walkable openings in Studio. The current runtime expects the primitive shelter's 76 panels, so the candidate's 103 need a separate native binding change.
- Stage `structure`, `hall-dressing`, `attached-art` and the `yard` batches separately. Verify the native floor, portal frames, terrain fit and surrounding routes. The salvage and relay art are independent visual props. Use deliberate proxies for any object designated as cover and assign thermal behavior by role.
- Verify the live camera, spawn protection, thermal sight lines, progressive damage and round reset after binding. The source and staging receipts cover file and geometry verification. Studio import, asset ownership and native gameplay evidence are pending.
