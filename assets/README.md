# Authored assets

The current runtime assets are the original primitive [expanded terrain/building battlefield](world/Battlefield.model.json), [C-130 template](models/C130.model.json) and [cover panel template](models/CoverPanel.model.json) and [normalized panel residual](models/PanelResidual.model.json), recorded in [manifest.json](manifest.json). They require no cloud asset IDs or external scripts. `world/` maps to `Workspace.World`; `models/` maps to server-only `ServerStorage.Assets`. Keep game-critical source here so a clean Git checkout can rebuild the place. The repository checker requires the manifest to cover every authored file under `world/`, `models/`, `blender/` and `exports/`, excluding Markdown. The Blender source/export package below remains outside runtime mappings.

Prefer `.model.json` for simple primitives and text `.rbxmx` exports for Studio-authored models. Export only authored objects after stopping play mode. Keep scripts in `src/`; inspect imported models for unintended scripts. For meshes, textures, animations and audio, retain original sources when rights and size permit, and record uploaded asset references and ownership.

Author every Part/SpawnLocation pose in `.model.json` with a twelve-component `CFrame`: translation X/Y/Z followed by the 3×3 rotation matrix in row order. Use finite values and a valid rotation matrix. For example, an unrotated panel at `(0,4,0)` uses:

```json
"CFrame": [0, 4, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1]
```

Do not author `Position` or `Orientation` properties in these files. They are runtime aliases rather than the canonical serialized pose and can be ignored when Studio loads the generated place. Rojo build success or byte-identical rebuilds alone cannot establish that Studio interpreted the map correctly. The [artifact checker](../scripts/inspect_build.py) compares every authored part's canonical pose, dimensions, shape and collision/query/touch flags in both builds; actual loaded transforms and world behavior still require Studio checks.

Add every imported/authored asset to `manifest.json`. The schema is version 1; each asset entry uses these fields:

| Field | Meaning |
| --- | --- |
| `id` | Unique stable internal name |
| `kind` | World, model, mesh, texture, animation, audio, editable source, material or catalog |
| `source` | Original source URL or description of local authoring |
| `author` | Author/owner attribution |
| `license` | Actual license or project-owned statement; never guess |
| `local_path` | Repository-relative source/export path, or null for cloud-only material |
| `roblox_asset_id` | Actual uploaded numeric ID as a string, or null |
| `upload_owner` | Actual account/group owner, or null until uploaded |
| `sha256` | Required lowercase content digest for every Blender source/export file; optional for legacy primitive assets |

At least one of `local_path` and `roblox_asset_id` must exist for an entry. World geometry, collision and gameplay-critical models require local reconstruction sources, even if a decorative asset is cloud-only. Track changes to cloud references as source changes. Keep dependencies accessible to the experience owner; a working personal asset ID is not proof that a group-owned release can use it.

The battlefield manifest also records the authored aircraft AimEnvelope values and its terrain recipe version, fixed seed, four-stud voxel resolution, descriptor path, server owner module, exact owned bounds, hill count and allowed materials. Terrain is reconstructed from these versioned descriptors at runtime; it is not an untracked Studio-only edit. See the [world contract](world/README.md) for reconstruction and panel metadata.

Generated place builds belong in ignored `build/`. Do not blanket-ignore authored model/place exports needed for reconstruction. Choose Git LFS or another documented versioned store before adding large binary source assets.

## Blender outpost review package

[P16](../plans/16-blender-military-outpost-assets.md) now provides editable
[source and inspection instructions](blender/military-outpost/README.md),
[game exports](exports/military-outpost/README.md), a complete feature inventory,
material/shape panel catalog and saved-scene review renders. Human visual
approval is pending. [P17](../plans/17-integrate-military-outpost.md) will consume
the approved revision to replace only the smaller Outpost; these files do not
yet change the playable map.

The [three supplied illustrations](../src/images/military-outpost/README.md)
are visual references outside runtime mappings. All packaged meshes and baked
textures are original local authoring from `scripts/p16_build.py`, seed 1601;
the illustrations' pixels are not textures and their unspecified creator/license
is not guessed. Twelve original PNGs are packed in the source and retained at
versioned relative paths. No Roblox upload IDs or owners exist for this package.

`assets/blender/military-outpost/` retains the compressed `.blend`, inventory,
panel catalog, reusable-kit mapping and package hash lock.
`assets/exports/military-outpost/` retains FBX/OBJ meshes, collision-proxy
candidates, bounded fragments, baked PNGs and the material map. Source and
review lighting stay outside Rojo mappings. Ordinary Git stores the complete
package, with each file below 20 MiB and an initial combined art-package target
of 45 MiB (D64); no LFS dependency is required. Backups, caches and temporary
files are excluded. Revisit storage deliberately if measured assets grow.

The checker enforces exact four-root manifest coverage, unique canonical paths,
SHA-256 for Blender source/export records, binary file budgets and cache/backup
rejection. After a deliberate re-export, refresh the package lock/tool evidence
and run `python3 scripts/refresh_outpost_manifest.py`, then the full verifier.
The [package rebuild recipe](blender/military-outpost/README.md#rebuild-and-verify)
gives the required order; hashes alone do not establish new visual approval.
Runtime navigation, openings, collision/query behavior, thermal readability,
fragment physics, multiplayer/reset and engine cost remain P17 checks.

The current P07 revision also versions the starting battlefield shelter’s panelization in the world source/manifest. It replaces the old seven collider envelopes with 76 wall/roof panels while preserving the pristine union/entrances/anchors; the revised source passes its reconstruction and acceptance checks. Runtime Light/Heavy scars and fragments are original code-generated primitives and must not be exported as pristine world assets. Keep registry descriptors, manifest coverage and reconstruction checks aligned; the separate outside lobby is unchanged.
