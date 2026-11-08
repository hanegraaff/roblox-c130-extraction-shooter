# Static battlefield source

Rojo maps this folder to `Workspace.World`. [`Battlefield.model.json`](Battlefield.model.json) reconstructs the entire original primitive greybox without a cloud asset or unsaved Studio edit. [`manifest.json`](../manifest.json) records its provenance. `MapService` owns runtime attributes, containment and pristine rebuild; static source stays here. Every part uses the twelve-component canonical `CFrame` described in the [asset authoring rules](../README.md). `Position`/`Orientation` aliases are forbidden in these model files. Generated XML property checks and actual Studio loaded-transform assertions are separate gates.

## Coordinates and anchors

Distances are studs, with Y up. Ground is Y = 0 and the disk center/camera focus is `(0,0,0)`. The default playable/orbit radius is 180; future aircraft altitude is 140 above ground. `MapRules.defaults` validates that circle/orbit/focus agree. Changing those defaults requires corresponding authored geometry changes. The orange segmented perimeter is 24 studs high; server containment returns exterior or below Y = −30 characters to Ground05.

| Authored object | Contract |
| --- | --- |
| `GroundDisk` | Anchored cylinder, top at Y = 0, radius 180. |
| `GroundSpawn` | Neutral development SpawnLocation at `(0,0.05,120)` in the southern shelter; ordinary Roblox respawning remains enabled. |
| `Anchors/Ground01`–`Ground09` | Invisible noncolliding/nonqueryable 3×3 arrangement: X = −20/0/20, Z = 108/120/132, Y = 3. Ground05 is the safe return pose. |
| `Anchors/Launcher` | Exactly one future launcher anchor at `(0,3,0)`, above the gold center marker. No pickup/weapon exists. |
| `Anchors/Lobby`, `Anchors/Operator` | `(400,3,0)` and `(400,3,−15)` on the separate lobby deck. No role assignment or transport exists yet. |
| `Permanent`, `Breakable` | Stable unique part names become runtime `CoverId`; folder kind becomes `CoverKind`. Both block collision/queries; neither takes damage yet. |
| `Routes` | Teal west and ochre east approach markings through X = −60/+60 toward the center. |
| `LobbyStation/LobbyDeck` | Bounds define the explicit containment exception for the separate noncombat station. |

All descendant names must be unique, all BaseParts anchored, and ground/launcher anchors must be inside the disk at ground +3. `MapService` checks a 4×5.5×4-stud box centered on each anchor and downward floor support; the shortened anchor envelope avoids touching the floor. The separate Studio route case samples a 4×6×4-stud envelope every 0.5 stud; cover rays sample eight perimeter phases. These required engine checks and focused walking review must be recorded before claiming map acceptance; source/build success alone is insufficient.

Do not export transient simulation state, projectiles, debris or playtest changes as authoring. Rebuild replaces the entire Battlefield subtree from the private pristine snapshot, so external consumers must reacquire its Instances. Keep both routes usable without destruction as future cover systems are introduced.
