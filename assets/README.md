# Authored assets

The current assets are the original primitive [expanded terrain/building battlefield](world/Battlefield.model.json), [C-130 template](models/C130.model.json) and [cover panel template](models/CoverPanel.model.json) and [normalized panel residual](models/PanelResidual.model.json), recorded in [manifest.json](manifest.json). They require no cloud asset IDs or external scripts. `world/` maps to `Workspace.World`; `models/` maps to server-only `ServerStorage.Assets`. Keep game-critical source here so a clean Git checkout can rebuild the place. The repository checker requires the manifest to cover every authored file under both directories, excluding Markdown.

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
| `kind` | World, model, mesh, texture, animation or audio |
| `source` | Original source URL or description of local authoring |
| `author` | Author/owner attribution |
| `license` | Actual license or project-owned statement; never guess |
| `local_path` | Repository-relative source/export path, or null for cloud-only material |
| `roblox_asset_id` | Actual uploaded numeric ID as a string, or null |
| `upload_owner` | Actual account/group owner, or null until uploaded |

At least one of `local_path` and `roblox_asset_id` must exist for an entry. World geometry, collision and gameplay-critical models require local reconstruction sources, even if a decorative asset is cloud-only. Track changes to cloud references as source changes. Keep dependencies accessible to the experience owner; a working personal asset ID is not proof that a group-owned release can use it.

The battlefield manifest also records the authored aircraft AimEnvelope values and its terrain recipe version, fixed seed, four-stud voxel resolution, descriptor path, server owner module, exact owned bounds, hill count and allowed materials. Terrain is reconstructed from these versioned descriptors at runtime; it is not an untracked Studio-only edit. See the [world contract](world/README.md) for reconstruction and panel metadata.

Generated place builds belong in ignored `build/`. Do not blanket-ignore authored model/place exports needed for reconstruction. Choose Git LFS or another documented versioned store before adding large binary source assets.
