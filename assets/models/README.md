# Server-owned model templates

Rojo maps this folder to `ServerStorage.Assets`. [`CoverPanel.model.json`](CoverPanel.model.json) is an original anchored, collidable 16×8×2-stud primitive panel, centered at `(0,4,0)`. It reserves a template for later cover replacement; no current service clones or damages it. Its pose is authored with a twelve-component canonical `CFrame`; use the [asset authoring rules](../README.md) rather than `Position`/`Orientation` aliases. Its provenance is recorded in the [asset manifest](../manifest.json), with no external asset or script dependency.

`AircraftService` clones the C-130 template and its imported skin into `Workspace.Aircraft`. The transparent, nonqueryable 12×10×46-stud `Hitbox` sits at local origin and is the canonical PrimaryPart and pivot. Local **−Z** is forward, **+Y** is up and **+X** is starboard. On the live clone, the Hitbox anchors the rig and rigid joints carry the flight geometry. Native solids and inset cylinder bands in `RoundedQueries` supply Ground hit surfaces. Three nonqueryable textured MeshParts supply the camouflage and painted markings. Aircraft parts have collision and touch disabled. [Generated template](C130.model.json) · [Painted skin source](../blender/c130/README.md) · [Native receipt](../imports/c130/native-receipt.json)

`Hitbox.GAU23Muzzle` is at local `(−7.06, −1.96, −8.90)` studs and `Hitbox.M102Muzzle` is at `(8.46, −2.21, 6.65)` studs. Both attachments align with their visible bores and supply server-derived firing origins. The M102 projects to starboard. Four rotor attachments locate the hubs for client animation. The artifact gate compares authored pose, shape and query flags in the two place builds. The native tests exercise the loaded rig, aircraft queries, attachment alignment and orbit. [Aircraft tests](../../docs/testing.md#verify-the-c-130-flight-model)

[`PanelResidual.model.json`](PanelResidual.model.json) is an original two-Part server-only template with no external asset/scripts. Left/Right are anchored, collidable/queryable, nontouching normalized strips: X width 0.25, Y/Z size 1 and X centers −0.375/+0.375. PanelGeometry reads their X width/offset and scales pristine panel clones along the longest face axis. The result preserves the original pivot/thickness and leaves a central 50% opening on walls or roofs. The current material/color comes from the original panel and its progress cue, not the normalized template. Destroyed panels retain their identity Model without BaseParts. All active primitive building panels share this contract, including 76 starting-shelter pieces and 86 Foundry/Warehouse panels on the integrated candidate; static floors/stairs/frames and generic cover are outside it.

`LauncherGeometry` clones [`DepotLauncher.model.json`](DepotLauncher.model.json) for all four floor pickups and for the held Tool. Its 126 visible Parts and WedgeParts share an invisible `Handle` with the `GroundContact`, `CarryGrip` and `Muzzle` attachments. All parts are noncolliding, nonqueryable and nontouching. `LauncherService` owns the round identity and cooldown. `LauncherRuntime` owns the replicas and cosmetic rocket Parts and removes obsolete instances on transfer, reset and stop. [Editable master and rebuild](../blender/rocket-launcher/README.md) · [Launcher server contract](../../src/server/README.md#landmark-launchers)

The M-7 uses a server-owned primitive held model. Panel fragments are generated at runtime and cleaned up with the round. Keep live pickups, projectiles, fragments and damage outside pristine authored templates. [Asset manifest](../manifest.json) · [Destruction owner](../../src/server/README.md#progressive-panel-destruction)

The primitive path generates original crack/scar marks in `PanelGeometry`, with no imported texture, mesh or script dependency. Light/Heavy use Concrete/Slate and D54’s slate/charcoal/pale-fracture defaults instead of glowing CrackedLava. Marks are cosmetic on both faces, clipped to residual solids, excluded from collision/queries and structural identity, and cleaned up with owned panel state. They are runtime presentation, not separate authored templates. The fresh solo engine baseline covers appearance/query assertions. Current Warehouse and starting-shelter native-input captures distinguish all four normal/thermal tiers, actual holes and solid residual occlusion, with disclosed QA markers. Their orbit pose and normal comparison camera are held. Resting debris captures and measured engine physics do not by themselves establish visual falling. The full seven-case two-client/reset check and six-case P14 regression pass. The separate [human demonstration](../../docs/evidence/p07-revision-human-fragments.json) confirms falling pieces under live clocks with an explicitly controlled close-up Ground watch camera. Current P07 acceptance checks pass; the earlier resting images retain their narrower scope.

## Imported Outpost and material templates

[`MilitaryOutpost.model.json`](MilitaryOutpost.model.json) and
[`MaterialPanels.model.json`](MaterialPanels.model.json) are managed definitions
compiled from the exact approved P16 package and observed native import receipts.
The pristine Outpost template contains 2,256 visible MeshParts, 26 registered
panel Models, stable supporting geometry, furnishings and navigation markers.
GameRuntime installs it at the original smaller-Outpost site before MapService
captures pristine reset state. All 25 legacy panel pivots remain; one partition
adds the 188th active map panel.

MaterialPanels holds six families with Pristine/Light/Heavy/Total Models and
four indexed fragment templates each. PanelAssetCatalog requires approved source
and import-receipt identities, valid asset references, bounded geometry and inert
cosmetics. Canonical family coordinates are mapped to legacy identity frames
through PanelAssetBasis. Exact rectangle Parts own collision/query behavior;
imported visual meshes cannot silently fill an earned opening. Panel-owned
dressing is removed at Heavy/Total and restored with pristine state.

Each SurfaceAppearance carries a compiled v1 material attribute contract.
Shared AssetMaterial reads it in ordinary server/client code without protected
map-property access. Compiler/artifact/Edit audits bind actual slots and source
receipts; runtime metadata checks do not establish availability or appearance.

Every generated MeshPart also retains genuine engine InitialSize and opaque
physical/collision payloads from the managed 407-profile native bank. Shared
AssetMesh compares public MeshSize/fidelity with five compiled native attributes;
MeshId and target Size alone are insufficient. The 2,332 uses preserve their
requested 87 Precise/320 Box profile policies. Public validity and host byte
binding do not establish rendered bounds, contacts or replication.

The [import package](../imports/military-outpost/README.md) identifies actual
mesh/texture packages, owner, derivative and deterministic regeneration. Twelve
PNG color maps are repaired; scalar roughness/metalness/emission remain metadata
and require explicit A6 review of the resulting finish. Managed source does not
by itself establish native loading, traversal, thermal cover, fragment safety,
replication/reset or performance. Never export damaged live state or fragments
as pristine templates. See the
[reconstruction guide](../../docs/development.md#reconstruct-the-approved-outpost)
and [server API](../../src/server/README.md#imported-material-panels-and-outpost-reconstruction-p17).
