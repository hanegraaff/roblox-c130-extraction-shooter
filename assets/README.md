# Authored assets

The current assets are the original primitive [greybox battlefield](world/Battlefield.model.json) and [cover panel template](models/CoverPanel.model.json), recorded in [manifest.json](manifest.json). They require no cloud asset IDs or external scripts. `world/` maps to `Workspace.World`; `models/` maps to server-only `ServerStorage.Assets`. Keep game-critical source here so a clean Git checkout can rebuild the place. The repository checker requires the manifest to cover every authored file under both directories, excluding Markdown.

Prefer `.model.json` for simple primitives and text `.rbxmx` exports for Studio-authored models. Export only authored objects after stopping play mode. Keep scripts in `src/`; inspect imported models for unintended scripts. For meshes, textures, animations and audio, retain original sources when rights and size permit, and record uploaded asset references and ownership.

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

Generated place builds belong in ignored `build/`. Do not blanket-ignore authored model/place exports needed for reconstruction. Choose Git LFS or another documented versioned store before adding large binary source assets.
