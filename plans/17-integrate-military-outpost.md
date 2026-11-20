# P17 — Replace the smaller Outpost with the approved asset

**Milestone:** M4 / Outpost integration. **Dependencies:** P16, P07, P13, P14. **Requirements:** R01, R05, R06, R09, R10, R12, R15, R16, R19, R20. Status: [roadmap](../roadmap.md).

**Sequence (D63):** Implement immediately after the approved P16 package, before continuing P09. This plan sits between P07 and P08 in roadmap order and does not require P08 to start; preserve the already completed launcher implementation when present in the selected source.

## Capability and player experience

Walk through the detailed military outpost approved in P16, including its storage/workshop downstairs, command room upstairs, exterior stairs/balcony and rooftop details. Aircraft fire produces persistent damage appropriate to each panel's material, real openings and bounded physical debris. Replace **only the existing smaller Outpost** in the current battlefield. Foundry and Warehouse remain the two larger buildings; this does not introduce a second level or level selection.

**2026-11-15 clarification (D65–D66):** finish this current integration without
resizing the Outpost, changing existing world dimensions or adding automatic
interior zoom. Larger clearances (about 50%) and interior-camera adaptation are
future-plan observations. After completing P17, finalize the requested reusable
asset-creation and Blender-import skills from its complete lessons. Creation
accepts a description, an image folder, or both; these tooling deliverables do
not add new P17 gameplay acceptance criteria or start another roadmap plan.

## Input and boundaries

The user approved P16 source `e8fb840a986969bdd3b7ac932469e3fa8cc99a9e`
on 2026-11-13: `.blend` SHA-256
`4c1c5264020616b1af3b36c9dd37442919b386655149ee207591cd37da041d8c`.
The [approval record](../docs/evidence/p16/human-approval.json) binds that input.
P16's source and approval are now integrated on `main` through the remaining
PR #34 → #33 → #32 stack, ending at `87df925`. Start P17 from updated `main`.
The [main integration record](../docs/evidence/p08-p16-main-integration.md)
identifies the exact merges and matching tested tree. No P17 implementation
is delivered by this record.

Use the exact P16 source/export revision the user approved, with its asset inventory, scale/axes, panel catalog, collision proxies, budgets and review conditions. Record its hash before implementation. P16 approval is a real dependency: draft renders or an unapproved later asset revision cannot substitute. Include the completed P07/P13/P14 destruction/map/view source through dependencies or their eventual merges; do not branch from stale main while required source is unmerged. P08 is not a prerequisite. Integrated `main` already contains completed P08 source; retain that work and run its applicable regressions rather than removing it to mimic the revised table order.

Work on `plan/17-integrate-military-outpost`. Inspect the intended Studio instance/place ID and version-specific MCP guidance, reuse the matching Rojo-connected document, and coordinate mutations. Retain the original source in Git history so the replacement is reviewable and reversible. Roblox publication is a separate authorized release action.

## Implementation

### 1. Import and register the approved asset

Use P16's validated export recipe. Retain meshes/textures and import/reconstruction descriptors in managed repository paths; record any required Roblox asset IDs and actual owner/access in the manifest. Confirm access for the intended experience owner and reimportability from the local exports. Do not make an unavailable cloud mesh or texture look like a successful reconstruction. Inspect imported content for unintended scripts. Export deliberate Studio-authored model definitions into `assets/models/` or `assets/world/` and update mappings/manifest together; a Studio-only placement is not delivery.

Replace the current smaller Outpost at its existing site/orientation, starting from its 32×48-stud footprint, two stories and site envelope surveyed in P16. Integrate the approved stairs/balcony and furnishing while retaining avatar clearance, safe entry, traversable upper-floor routes, spawn/launcher anchors and both launcher approaches. Keep the total at two large and one smaller formal building, all with at least two accessible stories. Record any justified dimensional/panel-layout revision as a versioned construction change and update validation data; do not weaken building-count or accessibility checks to make an import pass.

Classify every object as stable structure, destructible panel, cosmetic prop or deliberate solid cover. Stable floors, stairs and supporting frames retain their contract. Decorative screens, cables and material effects cannot silently become weapon/thermal blockers. Any actual solid prop cover must participate consistently in server obstruction and thermal presentation. Window/door treatment and attached dressing must agree with the panel catalog; no invisible full-wall proxy or detached floating facade may remain after damage.

### 2. Connect material variants to shared destruction

The current `PanelGeometry` clones primitive authored Parts and generates generic Slate scars/two-strip residuals; importing an intact mesh alone cannot render P16's material-specific stages. Add a small explicit, validated asset-catalog boundary to the existing shared reconstruction/presentation modules so registered panels can select approved meshes, textures, proxies and fragments. Keep `PanelDamageRules`, `DestructionService`, ordered shot outcomes, weapon selection/readiness and damage authority shared. Do not create an Outpost-specific combat/destruction service or implement P15 level switching.

Preserve stable building/panel IDs, pivots, story/roof registration and reset identities where possible. If P16 requires a different panel arrangement, version its migration and update all registry, map-layout, artifact and engine fixtures using actual counts and coverage. Validate missing/unknown material keys, variants, duplicate IDs, invalid geometry and out-of-budget assets before mutating the active world; define an explicit error or compatible fallback. Existing primitive Foundry/Warehouse/starting-shelter panels must retain their current behavior and appearance.

For every new wall/roof panel family, map Pristine/Light/Heavy/Total appearance and stage-local progress onto the authoritative state. Retain three/six direct 105mm hit thresholds, nine valid 30mm seconds per stage, persistent earned credit and interruption barriers. Material changes never alter durability. Light is visibly damaged but intact; Heavy shows a measured roughly half-face real opening and distinct material damage; Total removes the panel and blocking proxies. Use residual query/collision geometry that agrees with the visible opening. Texture alpha alone does not create an opening. Remove or transition attached lights/conduits/dressing consistently when their supporting panel disappears.

Instantiate the material-matched fragment set through the existing bounded server-owned fragment lifecycle. Preserve or explicitly justify tuning within the safety contract: static-scenery contact only, no player harm/pushing, no gameplay query or route obstruction, bounded counts/mass/impulse/lifetime and reset/stop cleanup. Keep all template selection and stage changes server-authoritative; clients cannot choose materials, variants, damage or panel IDs through a new trusted remote.

### 3. Reconstruct, exercise and review the candidate

Rebuild from a clean checkout and sync the committed source into the confirmed Studio test document. Verify actual loaded transforms, dimensions, render materials, UVs, collision/query flags, asset availability and complete panel registration. Exercise actual avatar walking through both floors and external stairs/balcony. Inspect close ground views and the operator's grayscale view over a full orbit at both weapon-linked zooms, including rooftop height against the authored aim envelope. Adapt lower-priority details if needed to preserve readability and measured performance; material visual compromises require user review.

Use named deterministic/catalog and service tests for new asset-boundary validation, same-rule progression, invalid/stale request rejection without mutation, queued impact/reset ordering and cleanup. Use real Studio rays, overlap/collision and thermal observations to establish actual wall/roof openings, residual solidity, initial window/door apertures and fragment contact. Actual two-client checks must establish replicated appearance/current geometry and repeated pristine reconstruction. Do not rely on duplicated rule code, screenshots or Blender simulations as engine evidence.

Profile the added art relative to the primitive baseline on the same recorded device/settings with actual client counts. Record mesh/material/texture/Instance counts, memory and frame times, including mass panel transitions and debris. Preserve the [testing budgets](../docs/testing.md); P11/P12 retain their broader soak/capacity gates. Keep tests, preview galleries, Blender cameras/lights and development overrides out of the release place.

## Acceptance criteria

- **A1 — Exactly the intended replacement:** `P17OutpostReconstruction` and `P17AssetCatalog` pass alongside the full `python3 scripts/verify.py` gate. A clean checkout reconstructs the approved smaller-Outpost asset with the manifest, exports, actual asset references and no unintended scripts/test content. Foundry, Warehouse, terrain, the starting shelter, protected waiting lobby, 720-stud boundary and canonical orbit are preserved. Building/story/panel counts and registered IDs match the revised source; missing/invalid imports fail clearly.
- **A2 — Playable interior and exterior:** `P17OutpostNavigation` uses real Studio floor/support/clearance checks and an actual avatar walkthrough to reach the furnished ground floor, upper floor and approved external stairs/balcony without blocked circulation or falling through decorative floors. Both launcher approaches and all deployment anchors remain valid. `P17OutpostTargeting` verifies authored height/range, full-orbit reach and reticle rays at both zooms; operated desktop/touch review covers normal and thermal readability.
- **A3 — Material-aware authoritative demolition:** `P17MaterialPanelStates` covers every new material/shape family on walls and roofs: Pristine, persistent Light, Heavy after exactly three direct M102 hits or nine valid GAU23 seconds, and Total after the next equivalent stage. Include stopped/resumed and alternating-panel fire, mixed fire, ordered in-flight outcomes, duplicate/stale/unauthorized rejection and no paused-time credit. `P17OutpostOpenings` uses actual rays/collision/thermal checks through Heavy/Total openings and against remaining solids, with no phantom full-panel collider. Runtime thresholds and appearance must agree; attached props cannot hide or block an earned opening.
- **A4 — Replication, reset and fragment safety:** `P17OutpostMultiplayer` runs with at least two actual clients and fresh server/per-client baseline reports. Both clients agree on panel identity, stage, progress, material appearance and real geometry. Across at least two damaged-to-pristine resets with live fragments/pending work, restore the exact approved pristine building once, clear all damage/old effects and reacquire fresh panel references. `P17MaterialFragments` verifies actual falling/static contact, bounds, expiry, stop/reset cleanup and no character/query interference. Keep supported spectator/late-join regressions where their existing suites require them; do not add unsupported same-identity reconnect acceptance (D59).
- **A5 — Measured regression and presentation:** Required current P07/P05/P14 regression suites pass on the final source, including primitive-building damage and launcher-anchor accessibility. When completed P08 source is present, its launcher/recovery regressions also pass; this preserves existing behavior without making P08 a start prerequisite. Record nonzero discovered/passed counts, actual clients and source/build identity. `P17OutpostPerformance` records baseline/candidate workload metrics and complies with applicable testing budgets; missing engine evidence or placeholder cloud assets cannot pass. P11/P12 still own full soak and real 6/10-player release acceptance.
- **A6 — Human approves the in-game result:** The user inspects the actual integrated smaller Outpost from ground and operator views, both furnished floors, stairs/roof details and each material's damage progression, and explicitly likes/approves the identified candidate. Revisit P16 approval if integration materially changes the approved art. Record response, date, source/package hashes and conditions; silence or an agent's judgment is not approval.

## Documentation and completion record

Update the root player README with the implemented building. Preserve the user's selected `blender_outpost.png` as its first and only embedded image immediately after the title, with an accurate Blender-authoring caption, as required by the current `AGENTS.md`. Keep actual Studio/playtest captures in linked P17 evidence; do not present Blender images as gameplay. Update asset/package READMEs, reconstruction instructions, manifest, architecture and named test/evidence links together. Record A1–A6, dependency/package hashes, source/PR, actual import ownership, tool commands, test counts, clients, navigation/normal/thermal observations, performance metrics, reset/cleanup and human feedback here when executed. Status remains in the roadmap.

### Implementation preflight — 2026-11-14

Selected P17 under D63 on dedicated `plan/17-integrate-military-outpost`, based
on updated `origin/main` / `db17aba07c8e90212a2f021b89093d476e1b6f09` (tree
`38023cd6760b2fa19ea8e59db0ae608995d7a3b3`). The checkout was clean and the
GitHub connector reported no open PRs. P16/P07/P13/P14 dependency source and the
completed P08 source are present. The approved `.blend` still hashes to
`4c1c5264020616b1af3b36c9dd37442919b386655149ee207591cd37da041d8c`.

Required evidence remains A1–A6 above: named host/catalog/service suites; actual
Studio import/reconstruction, navigation, targeting, material openings and
fragments; two actual clients and two damaged-to-pristine resets; current
P07/P05/P14/P08 regressions; measured candidate/baseline performance; and explicit
human approval of the identified integrated candidate. P16 approval does not
satisfy A6. No replacement, cloud import or new engine pass is claimed by this
preflight record.

### Preparation candidate and access boundary — 2026-11-14

Source `16ea1664d9d15b113fc9244c187a772969f54bc3`, tree
`6f7efcff83e232c532d4c2cc404e9e9a19c0f2d1`, adds generated approved panel
definitions, `PanelAssetRules` / `PanelAssetCatalog` validation and
`MaterialPanelGeometry` to the existing shared panel/destruction/fragment path.
The primitive path remains active: the world still has 187 panels and the
original smaller Outpost. There are no imported cloud asset IDs, runtime
material templates, assembly normalizer or integrated replacement yet.

Both the [developer host gate](../docs/evidence/p17/developer-host-16ea166.txt)
and [independent host gate](../docs/evidence/p17/independent-host-16ea166.txt)
pass `python3 scripts/verify.py`: 59 unit / 65 integration, seven P16 audits,
one P17 generated-definition check, 26 asset regression cases, ten manifest
regressions and all format/lint/type/build/geometry/isolation checks. These
counts apply to this source before the approval-lock correction below.
Earlier [lint](../docs/evidence/p17/host-lint-failure.txt) and
[allowlist](../docs/evidence/p17/host-allowlist-failure.txt) failures were fixed
before that passing candidate; they remain historical failures.

Fresh ordinary Play in local `tests.rbxlx`, Studio `0.747.0.7471481`, passes
164 server / seven client cases with one actual client and no failures,
errors or skips ([raw report](../docs/evidence/p17/solo-16ea166.json)). Eight
changed/new server modules were compared with repository source after Rojo
sync. The four new server fixtures cover missing/duplicate catalog preflight,
six-family shared progression/proxies, actual Heavy/Total proxy rays and
bounded fragment-template lifecycle. Their cosmetic MeshParts are deliberately
empty test fixtures; they do not prove approved mesh rendering, UVs, thermal
legibility, avatar navigation or integrated Outpost acceptance. The fixture
families bypass actual import validation and cannot substitute for real assets.

The independent reviewer found an approval-provenance defect in this source:
changing an OBJ UV and refreshing its mutable package lock/derived runtime hash
passed both P16 and P17 checks. The
[historical probe](../docs/evidence/p17/historical-export-trust-16ea166.json)
preserves the failure. It requires a pinned approved lock before generation
and a coordinated export/lock rejection regression; the passing original host
gate does not establish that later correction.

Cloud import is currently inaccessible. The first Studio listing was empty,
then an existing unnamed instance reported **Place is not open**; the guarded
launcher refused a duplicate process. After the user opened the document and
re-enabled MCP, local `game.rbxlx` connected as
`0716c7b4-b2bb-47d2-80cb-2efa104e03c9`. Read-only `asset:read` and `asset:write`
probes each returned **Scope has not been granted**. The user reports that
Studio requires saving to Roblox to manage MCP settings: a local document cannot currently
grant the needed asset permissions. The user subsequently opened separate
local `tests.rbxlx` (`e8a5a6d7-8d8c-4326-ab03-c3185048e07f`) and connected
`PlayersVsC130Tests` through Rojo on port 34872. Local engine tests can run;
cloud imports still require a suitable cloud-saved workspace, permission and
permanent-asset consent. No such cloud save, upload or game publication has
been performed. Never save the test mapping to Roblox.

| Criterion | Available groundwork | Required work still open |
| --- | --- | --- |
| A1 | Host source/catalog/provenance groundwork and missing-input rejection | Real import/access receipt, managed templates/assembly, actual smaller-Outpost replacement and clean reconstruction |
| A2 | Approved source geometry retained | Integrated avatar routes, floors/stairs/balcony, anchors, full-orbit targeting and operated normal/thermal/touch review |
| A3 | Shared rules and six-family proxy/ray fixtures | Real material appearance/progress, native fire, attached dressing, physical/thermal opening checks on the actual replacement |
| A4 | Shared cleanup and bounded fragment-template fixture | Two actual clients observing imported art/geometry, two live-work pristine resets, actual material-fragment fall/contact/safety |
| A5 | Current host gate and source-bound primitive regressions when recorded | Integrated-art baseline/candidate workload, memory/frame metrics and all final-source regressions |
| A6 | P16 source approval remains bound to its original revision | Explicit human approval of the identified integrated in-game candidate |

None of A1–A6 is complete on preparation fixtures alone. P09 remains dependent
on the actual replacement; no later plan has started.

### Approved-export correction and final host gate — 2026-11-14

Correction `03c9c06c88b25d7d85fceed881ef8b25cc4e7e59`, tree
`e3ee056df1dca3928fe3d53465f00480c9daf8fb`, pins the approved `e8fb840`
package-lock SHA-256
`eda4926391d6c1f19d35186a4b8d56db13a6e3e36cda256e43be0e414210b3b2`
before reading any export. The developer and tester independently compared
that lock with the approved commit. A fifth Python P17 case coordinates the
export/lock/descriptor/manifest mutation and requires rejection before generation.
The [independent recheck](../docs/evidence/p17/independent-export-fix.txt)
confirms the original bypass now fails. The generated Luau changes only the
header word `immutable` to `trusted`; its executable data/code matches
`16ea166`. This establishes the scope of earlier engine evidence rather than
claiming the old host gate tested the new provenance check.

The [developer](../docs/evidence/p17/developer-host-03c9c06.txt) and
[primary final](../docs/evidence/p17/primary-host-03c9c06.txt) full gates both
pass `python3 scripts/verify.py` on this code/tooling candidate: **59 unit /
65 integration, 27 asset regression cases, ten manifest cases, seven P16
audits and one P17 definition check**, with zero required failures/skips and
all static/type/build/geometry/isolation gates. The
[build record](../docs/evidence/p17/candidate-builds-03c9c06.json) binds both
generated artifacts to their hashes. Release isolation finds 47 runtime scripts
and 510 Instances, with no tests/fixtures/development overrides; the separate
test artifact has 600 Instances. Both reconstruct 422 authored Parts.

Technical-writer review updates eight prose files: root README, development
and testing guides, architecture, server/shared package and asset/model READMEs.
It documents the actual primitive experience, preparation branch, generated
definition, catalog/proxy APIs and unfulfilled import/acceptance requirements.
The chosen `blender_outpost.png` remains the root README's first and only
embedded image, immediately after the title with its Blender-authoring caption.
No current gameplay screenshot or human in-game approval is invented.

Fresh SDK-owned regression sessions in the same local test document have the
following separately preserved results:

| Runtime/test source | Suite / invocation | Actual clients | Result / scope |
| --- | --- | --- | --- |
| `16ea166` | `ExecuteMultiplayerTestAsync(2, {kind = "P07"})` | Two | [P07 7/7](../docs/evidence/p17/p07-16ea166.json), zero failures/skips; fresh 164 server / seven per client. Both live-work resets start with four fragments and two pending projectiles; server and both clients compare all 187 primitive panels. |
| `03c9c06` | `ExecuteMultiplayerTestAsync(2, {kind = "P05"})` | Two | [P05 8/8](../docs/evidence/p17/p05-03c9c06.json), zero failures/skips; fresh 164 server / seven per client. Existing gunship intent, sweep, cover, readiness and cleanup regressions. |
| `03c9c06` | `ExecuteMultiplayerTestAsync(2, {kind = "P14"})` | Two initially; one after intentional operator kick | [P14 6/6](../docs/evidence/p17/p14-03c9c06.json), zero failures/skips; fresh 164 server / seven per initial client. Both full orbits pass (90.99 seconds GAU23 / 90.93 seconds M102, 16 phase bins each), followed by actual operator-departure cleanup. |
| `03c9c06` | `ExecuteMultiplayerTestAsync(3, {kind = "P08"})` | Three initial/peak; two after actual client `LeaveTest` | [P08 11/11](../docs/evidence/p17/p08-03c9c06.json), zero failures/skips; 149 retained traces / zero dropped. Only one client's seven-case smoke report was directly captured before the automatic session end; server/other client baselines were not preserved in this session. |

These checks preserve existing primitive gameplay. They are not imported-art
replication/reset evidence or approval of the actual replacement.

The P14 report exceeded the MCP single-return limit. The tester recovered all
eight bounded chunks and parsed the complete JSON before preserving the report;
the earlier truncated extraction is not used as evidence. An additional
[real-Instance preflight probe](../docs/evidence/p17/missing-import-preflight-03c9c06.json)
registers a material Model with matching identity/size but no imported catalog.
It returns `nil, "missing approved material-panel assets"` with unchanged private
tree and collision-group state, then removes its disposable fixture.

The complete P08 JSON also exceeded the single-return limit and was recovered
in six bounded chunks before parsing/preservation. Its passing eleven-case
report does not include baseline reports. The missing P08-session server/two
client reports remain an evidence limitation; other source-bound sessions or
a separately recorded three-client smoke cannot retrospectively supply them.

One focused separate `ExecuteMultiplayerTestAsync(3, {kind = "P17Baseline"})`
attempt on `03c9c06` connected only two actual clients. The
[baseline report](../docs/evidence/p17/separate-baseline3-03c9c06.json) records
164 server / seven on each observed client, `requestedClients = 3`,
`observedClients = 2` and `complete = false`. No third report exists. Its
[return/cleanup report](../docs/evidence/p17/separate-baseline3-return-03c9c06.json)
is separate from the passing P08 harness. The missing P08-session raw reports
and this unavailable third baseline remain open A5 evidence; a supported
operation's temporary startup/capture failure does not waive it. The green
eleven-case harness was not rerun merely to replace already passing scenarios.

The [independent final review](../docs/evidence/p17/independent-review.md)
finds no unresolved material defect in the bounded preparation after the
approval-lock correction. It retains the access and baseline gaps. All owned
Play/SDK sessions ended; only the original confirmed test document remains
in Edit, RunService is stopped, `ManualHarness` is nil, `BootstrapStatus` is
absent and Workspace attributes are restored to their initial empty state.
The Rojo server remains available on port 34872 for source iteration.

The [pending access request](../docs/evidence/p17/import-access-request.json)
identifies the proposed owner-only **C130 P17 Import** experience / **P17 Import
Workspace** place on user account `2227341845`, the exact release-mapped build,
approved model exports and required asset scopes/upload directory. This is a
proposal, with no assigned cloud IDs or consent inferred. The initial cloud
save and permanent asset uploads await explicit authorization. Test mappings
must stay local; public release remains separate.

### GitHub review delivery

[Draft PR #39](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/39)
targets `main` from `plan/17-integrate-military-outpost`. Initial source,
documentation and evidence delivery is
`916713e64451c5620c416b29d722f6b4eca2ff9f`, tree
`d86bc3a7834a06d8beb2cc13c545e042bd38004c`. Its
[GitHub Verify run #335](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/43605942429)
completed successfully. Runtime/tooling evidence remains tied to `03c9c06`,
with the explicitly equivalent `16ea166` runtime reports above. Delivery-only
prose/evidence records do not change gameplay or tests.

P17 retains the concrete import-access blocker in the roadmap. No A1–A6
completion, next-plan promotion, merge, cloud save, asset upload or Roblox
publication is claimed by this draft.

### Private upload authorization — 2026-11-14

The user explicitly replied **“Yes, upload the game, but make sure to keep it
private.”** to the identified release-build / owner-only **C130 P17 Import**
workspace and approved model/texture-upload proposal. The
[authorization record](../docs/evidence/p17/private-upload-authorization.json)
binds that response to code `03c9c06`, release build SHA-256
`47a8a8f3934f9b21d70ecfb56b56771f59740b865a89335aae80ad6ffb489338`,
user account `2227341845`, private audience and the approved asset scope.
Consent is now granted; do not request it again for this same destination,
build and scope. It does not make an upload, privacy verification or P17
acceptance complete.

Rechecked local `build/game.rbxlx` matches the authorized hash; the artifact
inspection passes with 510 release Instances / 47 runtime scripts and no
tests/fixtures/development overrides. Studio still has local `tests.rbxlx`
open. A harmless `universe:write` scope probe still returns **Scope has not
been granted**. The connected `save_place` tool saves a local document back
to its file and cannot create the initial cloud experience or open another
file. Browser control also reports **browser access host is unavailable**.
The user has been asked to open `build/game.rbxlx` in Studio and complete the
initial **Publish to Roblox** dialog as **C130 P17 Import**, keeping **Audience:
Private**. Never cloud-save the test mapping. Actual cloud IDs, a verified
private audience and asset scopes remain pending; the roadmap's access blocker
therefore remains. No upload or public release is claimed at this checkpoint.

### Private upload verified and implementation resumed — 2026-11-14

The user created **C130 P17 Import**, universe `10776653720`, root place
`72732833195348`, on account `2227341845`. Open Cloud Get Universe returns
`visibility = PRIVATE` and the expected owner. The initial cloud document
contained the test mapping, so it was not accepted as the release upload.
Rojo 7.7.1 served the release project on loopback port 34873; both localhost
and explicit IPv4 plugin connections failed despite a responding server. The
installed plugin is also 7.7.1 / protocol 5; no version mismatch was inferred.

The primary agent instead compared the native document with the already
verified release/test artifacts: 504 release nodes plus 90 test-only nodes,
all 47 script byte-count/Adler-32 fingerprints, and all 422 authored Part
poses/sizes/shapes/physical flags. Only the six matching test-only roots were
removed; gameplay code and world geometry were unchanged. An initial
post-removal counter omitted the two entrypoint roots and failed at 45; the
inclusive count was corrected to 47 and all 504 release-node comparisons
reran successfully. The [comparison receipt](../docs/evidence/p17/private-release-comparison.json)
preserves both that diagnostic failure and the passing checks.

Studio `save_place` saved clean cloud version **5**. After the user's Publish
click, `GET /assets/v1/assets/72732833195348` independently returns Place
revision **5**, `isPublished = true`, moderation `Approved`. A fresh Get Universe
still returns `PRIVATE`. The legacy version-history endpoint required a broader
all-resources scope; no broad grant was requested because scoped asset metadata
proved the published revision. The [cloud receipt](../docs/evidence/p17/cloud-import-progress.json)
records the exact source, IDs, privacy and publication facts. No public release
or P12 capacity acceptance is claimed.

Two actual Model/package uploads are approved on the same owner account:

| Approved source export | Package ID / revision | Upload operation |
| --- | --- | --- |
| `outpost-assembly-v1.fbx` | `73311045122621` / 1 | `4a9773e8-40a3-4819-8687-60a8c963ba8e` |
| `panel-library-v1.fbx` | `126055228085421` / 1 | `a32a10ad-8119-4a9f-86c2-eb0ecd186d30` |

The manifest records these actual references and owner. Native insertion into
temporary server-only `P17ImportStaging` confirms exactly 2,225 assembly and
260 library MeshParts, no scripts, but **zero imported texture maps and default
gray colors throughout**. Thus upload success is not material appearance
acceptance. Full raw mesh receipts were captured in 51 bounded calls for
source-bound normalization; material repair continues without changing the
approved P16 files. The access blocker is cleared and implementation resumes;
all actual replacement and A1–A6 gates remain open.

### Integrated material candidate — 2026-11-14

Source `f3787331f34ba5623506a239f9d6660044a957b7`, tree
`bbe1dd533f7a9bf18d15bf61688a78ee0adbac1b`, activates the smaller-Outpost
replacement through `OutpostReconstruction` before the map's pristine snapshot.
Managed `MilitaryOutpost.model.json` and `MaterialPanels.model.json` reconstruct
the actual imported meshes. The versioned construction retains all 25 legacy
panel identity pivots, adds the approved internal partition and registers 26
Outpost / 188 battlefield panels. Foundry, Warehouse and shelter still use the
shared primitive path. This source has been pushed to the existing draft PR;
it has not been published to Roblox.

The unchanged approved P16 source/package lock is still the input. A managed,
material-split GLB derivative updates library package `126055228085421` to
revision 2, rather than creating a duplicate package. Its SHA-256 is
`a1a69c05867ebb02c776614bf44db2eef72893e3a777df1df556af640d452a1e`.
The derivative decoder verifies equivalent triangle corners/winding, UVs and
original embedded PNGs: 76 one-material primitives, 34,144 triangles, 42
nonempty source objects and six explicit empty Total definitions. Native
insertion confirms 76 textured MeshParts with no scripts. Actual assembly and
library receipts, normalization, texture references and construction migration
are managed under `assets/imports/military-outpost/`; all package references
belong to user `2227341845`.

The original native assembly remains the geometry source; its missing material
references are repaired with seven imported color maps and five uploaded
original PNGs. The [texture availability receipt](../docs/evidence/p17/texture-availability.json)
records successful typed-instance preload of all 12 images plus a real textured
MeshPart dependency. An earlier raw-string-only preload returned Failure; it
was not treated as evidence of an asset permission failure. Native scalar
roughness, metalness and emission maps are absent, so exact PBR equivalence is
not claimed. That material compromise requires actual in-game A6 review.

Imported panel variants use an explicit `PanelAssetBasis` to retain identity
pivots while aligning canonical faces and authored fragments. Panel-owned
dressing remains on Pristine/Light and is removed on Heavy/Total, then restored
on reset. `ThermalCosmetics` hides explicitly non-cover art/fragments locally
for the operator's thermal view; actual solid cover continues to occlude
highlights. Ground views retain the furnishings. This presentation policy also
requires operated review on the integrated scene.

The [developer full gate](../docs/evidence/p17/developer-host-f378733.txt) passes
`python3 scripts/verify.py`: **59 unit / 65 integration, 41 asset regressions,
ten manifest regressions**, seven P16 audits and the P17 definition, derivative
and reconstruction gates, plus format/lint/types/build/geometry/isolation.
Expected-failure corruption probes are intentional gate assertions. The
[build record](../docs/evidence/p17/candidate-builds-f378733.json) binds both
generated files to this source. Each contains 2,804 authored Parts; release
isolation finds 5,294 Instances / 49 runtime scripts and no test content. The
separate local test artifact has 5,386 Instances. Its expected native baseline
is 168 server / eight per client, not yet an observed passing result.

Independent integrated-source review is underway. The user has been asked to
open the fresh local `build/tests.rbxlx` in the existing Studio application;
the private cloud import document must remain free of tests. The published
private version 5 is still the earlier clean `03c9c06` source. All previous
primitive preparation reports above remain historical and cannot establish
this candidate's native acceptance.

| Criterion | Current integrated evidence | Required evidence still open |
| --- | --- | --- |
| A1 | Actual owner-bound import receipts, equivalent derivative, managed reconstruction and passing host gates | Independent clean reconstruction and native source/template verification |
| A2 | Approved furnished geometry, preserved anchors and preflighted supports/stairs | Real avatar routes, targeting/orbit and operated desktop/touch normal/thermal review |
| A3 | Shared authority/progression, material templates, native proxy fixtures in the test mapping | Actual six-family state/fire/opening/attachment/thermal checks on this candidate |
| A4 | Shared bounded fragment/reset lifecycle and imported fragment geometry | Two actual clients, fresh raw baselines, two live-work resets and physical fragment safety/contact/expiry |
| A5 | Full host gate on the integrated source | Current P07/P05/P14/P08 native regressions and controlled baseline/candidate performance |
| A6 | Original P16 approval remains valid for its source package | Explicit human approval of this identified integrated in-game result, including material/presentation compromises |

No A1–A6 completion or P09 start is claimed by this checkpoint.


### Independent integrated review and portability failure — 2026-11-14

The [independent macOS full gate](../docs/evidence/p17/independent-host-f378733.txt)
also passes unchanged `f378733`: 59 unit / 65 integration, 41 asset regressions,
ten manifest regressions and all static/type/build/isolation gates. Native
Studio testing has not begun on this integrated candidate.

Fresh [GitHub Verify #341](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/43623002662)
on Ubuntu 26.04.1 / CPython 3.12.16 fails the deterministic reconstruction gate:
`assets/models/MaterialPanels.model.json` differs from regeneration. The
[bounded failure receipt](../docs/evidence/p17/ci-failure-f378733.json)
preserves the actual failure; a local pass does not waive it.

Independent source review also identifies two material defects for correction:
missing/mismatched `LocalIdentityPivot` is not rejected before cloning, and the
thermal cosmetic predicate excludes server-owned physical fragments because
they deliberately retain static-scenery collision. These findings have been
returned to the developer as one batch with the portability failure. A corrected
candidate, explicit rejection/fragment regressions, source synchronization and
native acceptance are still required. No historical passing fixture is relabeled
as proof of these corrections.

### Corrected integrated candidate — 2026-11-14

Source `b1a67341100e8f72ab87e7fb44166ec8b807fa32`, tree
`7c22149fb8d1be70383bdf25f5904f71862d2837`, corrects the three findings above.
Python 3.12's compensated floating-point `sum` changed tiny normalized values
relative to Python 3.10's ordered reduction. Explicit ordered reductions make
the compiler independent of that built-in change. The real-receipt regression
simulates compensated summation and requires byte-identical generated outputs;
exact receipt/provenance validation has not been relaxed. Both model JSONs,
the construction report and every approved P16 input remain byte-identical to
`f378733`.

Outpost preparation now rejects missing/mismatched local identity pivots and
non-archivable content before cloning. Thermal hiding additionally accepts only
explicitly marked, unanchored, non-querying, non-touching visual fragments in
the owned fragment collision group. It watches replicated marker/group/physics
changes and restores real-cover opacity. The new native fixtures cover those
contracts; their actual Studio results remain unrun.

The [developer final full gate](../docs/evidence/p17/developer-host-b1a6734.txt)
passes on macOS / Python 3.10: **59 unit / 65 integration, 42 asset regressions,
ten manifest regressions**, all seven P16 audits, all P17 source/derivative/
reconstruction gates and format/lint/type/build/geometry/isolation checks.
The [independent focused recheck](../docs/evidence/p17/independent-portability-fix-recheck.txt)
passes all six reconstruction Python cases. The tester's
[integrated review](../docs/evidence/p17/independent-integrated-review-f378733.md)
records the original findings and corrected source inspection, with no further
material source finding. This does not substitute for Linux CI or native
positive/rejection/thermal checks.

The [corrected build record](../docs/evidence/p17/candidate-builds-b1a6734.json)
binds fresh release/test artifacts. Counts remain 2,804 authored Parts each,
5,294 release / 5,386 test Instances and 49 runtime scripts. The expanded
native mapping now expects **169 server / nine per actual client**, not yet
observed. Documentation describes the actual integrated branch, reconstruction,
texture/PBR limitation and narrow thermal policy across the player guide,
development/testing/architecture and package guides. The chosen README image
is preserved. All A1–A6 native/performance/human checks remain open, and the
private published version is still the older clean primitive source.

### Cross-platform delivery checkpoint — 2026-11-14

Documentation/evidence delivery `821bfd52e08764f31e6fd83a52b3a599a8322e4a`
(tree `3268c8a75fd2f0e6ce393ba0dd08f053595ee9ab`) contains the unchanged
`b1a6734` runtime/test/assets/config candidate. Fresh
[GitHub Verify #343](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/43624006036)
passes the full gate on actual Ubuntu 26.04.1 / CPython 3.12.16. The
[CI receipt](../docs/evidence/p17/ci-pass-b1a6734.json) preserves environment,
source, counts and bounded log excerpts. Its real suites pass 59 unit / 65
integration, 42 asset and ten manifest cases; expected-failure verifier probes
are separate. This closes the observed Linux portability failure without
changing the approved or managed art bytes.

The technical writer reviewed twelve player/contributor/package prose files.
The primary's final repository checker passes 97 Markdown / 251 JSON
files including this CI receipt. Root README retains only the selected Blender
image and distinguishes the detailed candidate, accepted primitive `main`
and older private published build.

The connected Studio remains the private cloud import document, not the new
local test artifact. The user has been asked to open the freshly built local
`build/tests.rbxlx` in the existing Studio application and enable its MCP server.
No integrated Play, multiplayer, navigation, thermal, fragment or performance
result exists yet. Native mapping counts 169 server / nine per client are
expectations only. The draft PR remains reviewable, unmerged and incomplete;
actual A1–A6 evidence and explicit human in-game approval are still required.

### Local Studio identity and first native failure — 2026-11-14

The user opened fresh local `tests.rbxlx`, Studio
`d26e7b2c-23eb-4007-9db2-3dae43e5ee33`, with PlaceId/GameId zero and engine
`0.747.0.7471481`. The [read-only identity receipt](../docs/evidence/p17/source-identity-b1a6734.json)
matches all 131 runtime/test script byte-count/Adler-32 fingerprints and the
actual imported template references/classes: 2,256 meshes in the Outpost Model
and 76 in the material Folder, with no imported executable content. Two primary
probe assumptions initially failed: XML Source tags were parsed too narrowly,
and the material registry was incorrectly assumed to be a Model. Both probe
errors were corrected; no place content changed and the final identity check
passed. The private cloud document remained untouched.

Independent ordinary Play on exact `b1a6734` does **not** pass: **169 server
discovered / 165 passed / four failed / four errors**, and **nine client
discovered / eight passed / one failed**, one actual client, zero skips. The
[raw baseline](../docs/evidence/p17/native-baseline-b1a6734-failed.json) and
[full console](../docs/evidence/p17/native-baseline-b1a6734-console.txt)
preserve the failure. All four Outpost cases reach a protected
`SurfaceAppearance.ColorMap` read in `PanelAssetCatalog`; ordinary script
threads lack Plugin capability. The client Foundation failure propagates that
server-fixture failure, so the runtime never starts. Passing host gates and
privileged MCP inspection did not establish ordinary runtime API access.

The [official SurfaceAppearance API](https://create.roblox.com/docs/reference/engine/classes/SurfaceAppearance)
also restricts the Content variants; changing only the property name would not
resolve this. The developer is correcting the runtime boundary to use compiled
readable metadata plus actual SurfaceAppearance presence, retaining exact
serialized-property validation in the compiler/artifact/native-Edit checks.
Instance-based preload must establish actual availability without reading
protected properties. Native probes must distinguish readable metadata from
actual protected-map inspection. No broader permissions are requested.

The tester stopped the owned session cleanly: the same local document is back
in Edit, ManualHarness is nil, BootstrapStatus is absent and Workspace
attributes are restored. No temporary probe modules/hooks had been installed.
The corrected source must be synced into this same document and exercised by
fresh ordinary server/client scripts before any native pass is claimed.

### Runtime-safe material correction and second native run — 2026-11-14

Source `010289d3945f862a2af377455a62a950e76d3e45`, tree
`5e7a5d86e336054ed4bdb970a7a314aa0d543245`, introduces shared
`AssetMaterial.read(mesh)`. It validates one actual SurfaceAppearance and
versioned readable material-key/map/PNG-hash attributes, without protected
property reads in ordinary server/client code. Compiler and artifact checks
bind all seven attributes on each of 2,332 surfaces to the actual serialized
slots and original receipt. Actual texture IDs, art, poses, flags and approved
P16 inputs are unchanged.

The [developer full gate](../docs/evidence/p17/developer-host-010289d.txt) and
[GitHub Verify #347](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/43626378313)
pass: **59 unit / 65 integration, 43 asset regressions, ten manifest cases**
and all static/type/build/isolation gates. The
[independent seven-case material recheck](../docs/evidence/p17/independent-material-recheck-010289d.txt)
includes actual serialized-slot/metadata drift and missing-metadata rejection.
The [build record](../docs/evidence/p17/candidate-builds-010289d.json) binds
2,804 Parts each, 5,295 release / 5,387 test Instances and 50 runtime scripts.

Rojo connected the test mapping to the private cloud import document as well
as the local test document. The user subsequently identified the accidental
connection. The primary stopped the owned test server immediately, verified
all 132 mapped sources and 9,328 protected-slot/metadata comparisons in the
cloud editor, removed exactly six verified test-only roots / 92 nodes, and
checked 50 release scripts with no tests remaining. Clean **draft 11** was
saved; no Publish operation occurred. Get Universe still returns `PRIVATE`.
The latest asset metadata reports revision 11 without an `isPublished` field;
it does not establish a new published revision. The prior version-5 publication
proof remains historical. The [correction receipt](../docs/evidence/p17/cloud-sync-correction-010289d.json)
preserves actual observations. The saved draft now contains the new source,
while no new playable-version publication is claimed.

The local document already received the final source updates. A guarded manual
sync refused its old-`b1a6734` precondition before mutation; the new
[read-only identity check](../docs/evidence/p17/source-material-identity-010289d.json)
then matches all 132 sources, every 2,332 mesh path/ID/material identity and
all **9,328 actual protected-slot / compiled-attribute / approved-palette**
comparisons. No manual source write was needed. This is Edit-mode property
evidence, distinct from ordinary runtime reads and actual dependency loading.

Fresh ordinary Play still fails: **170 server discovered / 168 passed / two
failed / two errors / zero skipped**, one actual client. The ordinary material
metadata fixture passes, closing the original PluginSecurity defect. Two
Outpost cases fail `invalid material panel geometry`: the default 40-stud
per-panel validator rejects genuine 42/44-stud roof attachments, although the
approved whole-source contract permits 64. Client test discovery aborts before
any cases/report because the ThermalCosmetics fixture immediately indexes a
not-yet-replicated `PlayerScripts.Client`. No ten-case client pass is claimed.
The [raw reports](../docs/evidence/p17/native-baseline-010289d-failed.json),
[console](../docs/evidence/p17/native-baseline-010289d-console.json) and
[independent review](../docs/evidence/p17/native-review-010289d-failed.md)
preserve both findings. The developer is correcting the scoped attachment
bound and bounded client prerequisites together. The tester restored the same
local document to clean Edit with no temporary hooks installed; P17 remains
open for corrected ordinary Play and all integrated acceptance.

### Corrected ordinary initialization and SDK fixture findings — 2026-11-14

Source `51f8440ee728e641ec47b85a3b95370981fdc813`, tree
`d280d1cfd941e17646d900f76a84a18a8a8b2530`, changes only three source/spec
files. Material geometry grants the approved 64-stud dimension / 32-stud
canonical half-envelope only to MeshPart dressing marked `PanelAttachment`
with the correct owning panel ID; ordinary visual/proxy/fragment limits remain
40. The [independent envelope check](../docs/evidence/p17/attachment-envelope-010289d.json)
verifies all 274 actual attachments across 26 panels. Client tests acquire
runtime modules inside callbacks with bounded waits and wait for actual imported
replacement/metadata before checking it. Assets, maps and P16 inputs are unchanged.

The [developer full gate](../docs/evidence/p17/developer-host-51f8440.txt) and
[Linux Verify #349](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/43627282453)
pass unchanged host counts 59 unit / 65 integration, 43 asset / ten manifest
regressions and all static/type/build/isolation gates. The
[build record](../docs/evidence/p17/candidate-builds-51f8440.json) pins both
artifacts. A guarded one-way sync changed only three local Script Sources;
the [post-sync identity](../docs/evidence/p17/source-material-identity-51f8440.json)
again matches all 132 sources, 2,332 mesh identities and 9,328 actual material
slot comparisons. Neither cloud document nor asset data was changed by that sync.

Fresh ordinary Play now **passes 171/171 server and 10/10 client cases**, one
actual client, zero failures/errors/skips. The real imported Outpost initializes;
ordinary server/client material access, approved attachments and reconstruction
pass. Preserve the [raw baseline](../docs/evidence/p17/native-baseline-51f8440.json)
and [console](../docs/evidence/p17/native-baseline-51f8440-console.json) as this
bounded ordinary result, not full A1–A6 acceptance.

The first excluded P17Material SDK session starts two actual clients, operator
`-1` and Ground `-2`, with 171/171 server and 10/10 Ground. Operator baseline
is 9/10, so its test entrypoint stops before attaching the acceptance listener.
The derived suite fails its one startup case; **no P17 acceptance case runs**.
The [raw session result](../docs/evidence/p17/material-51f8440-attempt1.json)
and [all actual-client baseline captures](../docs/evidence/p17/material-session-baselines-51f8440.json)
are separate from the earlier passing solo smoke.

A focused diagnostic attempt retains operator 8/10, Ground 10/10 and server
171/171. It identifies a test-only thermal ownership conflict: the disposable
fixture under Workspace is also owned by the live operator thermal controller,
which correctly keeps it hidden after the nested fixture stops. An identical
unparented fixture restores opacity/resources correctly. The
[actual isolation proof](../docs/evidence/p17/thermal-fixture-isolation-51f8440.json)
supports isolating both fixtures, without changing product thermal policy.
This attempt also hits the existing P06 reticle-projection assertion; its old
diagnostic lacks current drawn/expected/origin/viewport/inset values. That
remains an unresolved validation concern. One-pixel assertions must remain.
The [diagnostic baselines](../docs/evidence/p17/material-diagnostic-baselines-51f8440.json),
[consoles](../docs/evidence/p17/material-diagnostic-consoles-51f8440.json) and
[independent SDK review](../docs/evidence/p17/native-sdk-review-51f8440.md)
preserve these distinct observations; neither attempt passes imported-art
multiplayer acceptance.

Both temporary dispatchers are restored byte-for-byte, the two owned modules
and report attributes removed, and the local document is back in clean Edit.
The [restoration proof](../docs/evidence/p17/material-hooks-restoration-51f8440.json)
again passes all 132 source / 2,332 mesh / 9,328 slot checks. The developer is
correcting fixture isolation and collecting concise P06 readiness/projection
diagnostics before the next controlled native run. Performance probes remain
excluded and unexecuted; actual A1–A6 acceptance is still open.

### Stable two-client baseline and partial native acceptance — 2026-11-14

Test-only correction `48eae4b2f0ebb4b0f069fb21a41973b9a37a297a`, tree
`7c75a118c6f887c3bf4f995448635dbfca895d5c`, isolates disposable thermal
fixtures from the production Workspace owner. P06 fixture sampling now waits
for layout and retries only a measured camera/viewport/inset/origin change;
stable mismatches still fail unchanged one-pixel/ray limits. Concise current-frame
telemetry is preserved before assertion. Product source, assets and the release
artifact are byte-identical to `51f8440`.

The [developer full gate](../docs/evidence/p17/developer-host-48eae4b.txt) and
[Linux Verify #351](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/43628420492)
pass 59 unit / 65 integration, 43 asset / ten manifest cases and every required
host/static/build gate. The [build record](../docs/evidence/p17/candidate-builds-48eae4b.json)
pins the unchanged release and revised test artifacts. The
[source/material sync receipt](../docs/evidence/p17/source-material-identity-48eae4b.json)
verifies both changed client Sources and all 132 source / 2,332 mesh / 9,328
material-slot identities in the same local document.

Fresh SDK sessions now preserve **171/171 server and 10/10 on each of two
actual clients** (`-1`, `-2`), zero failures/errors/skips. The
[complete first raw bundle](../docs/evidence/p17/material-48eae4b-attempt1.json)
and [subsequent baseline/telemetry bundle](../docs/evidence/p17/material-corrected-probe-baselines-48eae4b.json)
establish this scope. Their later excluded-probe failures are not an overall
acceptance pass. The performance fixture's prerequisite pins SHA-256
`f8d47d0f7dcc5d212351e001f091a3167bac940c319b7a2e29407e8535daeacd`
of the real first bundle and checks all source/config/assets against its commit;
the fixture remains prepared, not executed.

The first availability probe incorrectly treated `GetAssetFetchStatus` of
compiled SurfaceAppearance image IDs as a preload test. Official
[ContentProvider documentation](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/ContentProvider.yaml)
excludes SurfaceAppearance/MaterialVariant textures from `PreloadAsync`; their
processed packs stream at runtime. `None` for those aliases is not evidence of
an unavailable asset. Corrected probes retain actual callback IDs/statuses and
separate mesh loading from still-unverified rendered texture appearance.

The [complete third SDK report](../docs/evidence/p17/material-48eae4b-attempt3.json),
recovered in 16 bounded chunks and parsed in full, records **three passing of
four discovered cases**: authority/rejection, actual mesh availability and
Humanoid navigation. Both clients receive 2,332 successful actual MeshPart
callbacks covering all 407 unique expected mesh IDs, with zero callback
failures. One real Ground avatar completes the internal 19-waypoint and external
29-waypoint routes using only one initial placement per route and ordinary
Humanoid MoveTo thereafter, reaching upper-floor root Y=13.123. This is actual
controlled locomotion, distinct from desktop/touch input or subjective review.

The fourth case initially uses a generic primitive residual ray inside the
approved garage Heavy opening. Detailed
[field-level comparison](../docs/evidence/p17/material-48eae4b-attempt4-panel-mismatch.json)
shows state/progress/identity and all 35 children agree exactly, with zero mesh,
metadata, color, pose, size or physical-flag differences. The excluded ray
fixture is corrected to use approved residual rectangle centers and a point
solid in Pristine/Light but newly absent in Heavy; primitive checks and thresholds
remain unchanged. No candidate replication defect is assigned from that failed
assumption. Material/texture appearance, full six-family/native-fire/reset,
fragments, regressions, performance and human A6 remain open.

The following approved-ray SDK attempt does not start a server/client: Studio
opens an extra read-only local test document instead. No candidate code is run
there. The [startup-unavailable receipt](../docs/evidence/p17/material-48eae4b-attempt5-startup-unavailable.json)
records zero running contexts, the pending launch and owned child identity.
One supported Stop request does not resolve the pending RPC. No additional
process launch/reopen retry occurs; the user is asked to close only that extra
read-only window because MCP exposes no document-close operation. Original
temporary hooks/backups remain owned until recovery and exact restoration.
This temporary SDK failure does not waive any supported acceptance check.

The [fourth full report](../docs/evidence/p17/material-48eae4b-attempt4.json)
was also recovered completely (345,470 characters / 18 bounded chunks). The
[independent checkpoint](../docs/evidence/p17/native-integrated-checkpoint-48eae4b.md)
consolidates supported passes, excluded-probe mistakes and open evidence.
During launcher recovery the user closed both local test documents, leaving
only the private import document open. Consequently the original pending RPC
and its final result are unavailable; no post-restoration check is claimed on
that closed document. The [disconnection receipt](../docs/evidence/p17/material-48eae4b-startup-recovery-disconnected.json)
confirms the on-disk test artifact still matches SHA-256
`53e8fb79fa034a2d0fdb51631bee74e77a1d34300c4184442b7ae2d0e78aa4ad`,
with no saved temporary hooks. The user is asked to open that unchanged local
file once in the existing Studio application with Rojo disconnected. A new
intended Studio ID/source verification is required before further tests.

### Render reconstruction defect isolated — 2026-11-14

The reopened local document source/material identity passes again, and the
recovery SDK runs with two actual clients and 171/10/10 passing baselines.
The [full recovery report](../docs/evidence/p17/material-48eae4b-recovery-v5.json)
preserves four of five discovered passing cases: rejection/authority, actual
mesh loading, avatar routes and all six material families' replicated states
and independent earned-opening/residual rays. All 42 family/stage records
agree on both clients; a pristine reset/redeploy succeeds. Native M102 roof
fire reaches direct hits one through five and Heavy on the third, then times
out awaiting the sixth. This is incomplete native-fire acceptance, not a
changed threshold. A [focused diagnostic launch](../docs/evidence/p17/material-48eae4b-v6-partial-return.json)
starts only one actual client and self-ends at 60.403 seconds; the shot
diagnostic does not run. Its child contexts close, exact hooks/attributes are
restored and the [identity proof](../docs/evidence/p17/material-hooks-restoration-48eae4b-recovery.json)
passes. Repeated SDK startup trouble is preserved, with a supported manual
Server & Clients route being prepared rather than more launch loops.

Ordinary one-client visual review on the same source passes 171/10 but exposes
a **P1 reconstruction defect**. At verified outside cameras the imported art
renders as giant planes, while actual Part bounds report a 48×62×31-stud
building. With the camera fixed, hiding only the 2,256 imported Outpost meshes
reveals the normal map; restoring their exact local transparency restores the
giant planes. The [prioritized render review](../docs/evidence/p17/native-render-review-48eae4b.md),
[camera/geometry metadata](../docs/evidence/p17/native-render-metadata-48eae4b.json),
[original diagnostic images](../docs/evidence/p17/render-capture-files-48eae4b.json)
and [cleanup proof](../docs/evidence/p17/native-render-cleanup-48eae4b.json)
preserve this actual observation. Original viewport is 1153×579, capture output
1920×964, graphics Automatic with FRM enabled; these are not performance-budget
settings. Actual operator-preview UI and zoom respond, but the building cannot
be meaningfully inspected. No visual/A6 or performance pass is claimed.

Inspected reconstructed MeshParts have public `MeshSize = (0,0,0)` despite
nonzero Size/MeshId. A supported unparented AssetService comparison loads the
same actual IDs: the floor's intrinsic MeshSize is approximately
1365.333×42.667×2048 while its intended placed Size is 32×1×48. Applying that
native mesh to a clone preserves its target Size/CFrame and restores the real
intrinsic size. Native serialize/deserialize preserves the loaded mesh data.
The [comparison receipt](../docs/evidence/p17/native-mesh-create-apply-comparison-48eae4b.json)
records three positive samples and cleanup without touching source templates.

A [controlled paired render](../docs/evidence/p17/native-payload-render-isolation-48eae4b.json)
then compares the two same-position floor clones: missing native payload
produces giant planes, while supported `ApplyMesh` from the actual asset
produces the intended 32×48 textured slab. Original templates and all
diagnostic nodes are restored/removed. This establishes incomplete native
constructor payload as a render reconstruction problem; a persistent native
field/bank pipeline and roundtrip checks must now be implemented. No hidden
property access, synthetic intrinsic-size guess or renderer fallback is used.
Correct declared collision fidelity must also survive native reconstruction.
The approved art, pivots, IDs and original P16 package remain the input.

### Genuine native mesh reconstruction — 2026-11-14

Source `ee19deb5fe18090573ce0d9788b0c77555bca333`, tree
`4f9798fe52f9bdd83af6a6f1b7dcab87c4727e6a`, preserves genuine engine-authored
`InitialSize`, `PhysicalConfigData`, `PhysicsData` and `AeroMeshData` in the
existing managed model definitions. The managed native profile bank contains
407 actual mesh/fidelity profiles (320 Box / 87 PreciseConvexDecomposition),
captured through supported AssetService construction and native serialization.
The compiler applies their exact fields to all 2,332 template uses; it does not
derive intrinsic size from the intended placed Size. Original P16 art, mesh IDs,
target Size/CFrame, material maps and classification remain unchanged.

Shared `AssetMesh.validate` checks ordinary public MeshSize and fidelities
against versioned readable identity metadata, before installation and in native
regressions. Host audits bind those attributes to the actual native payload.
The test-only missing-payload fixture reproduces the former malformed constructor
and is absent from the release mapping. No runtime cloud fetch is introduced.

The [developer full gate](../docs/evidence/p17/developer-host-ee19deb.txt) and
[Linux Verify #355](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/43634221984)
passes **59 unit / 65 integration / 48 asset / ten manifest cases**, plus all
required static/type/build/isolation checks. The
[candidate build record](../docs/evidence/p17/candidate-builds-ee19deb.json)
pins 5,296 release / 5,389 test Instances, 51 release scripts and 2,804 authored
Parts. The [independent host review](../docs/evidence/p17/independent-native-constructor-review.md)
confirms all 407 profiles, 2,332 uses, preserved payload bytes and unchanged art.
Its [five focused rejection cases](../docs/evidence/p17/independent-native-regressions-recheck.txt) pass after
correcting the negative fixture's positive control. Expected native counts are
173 server / ten client; these are **not yet observed on this source**.
Fresh actual rendering, fidelity/physics, client reconstruction and the
remaining A1–A6 gates must run before closing the P1 or claiming acceptance.

The corrected asset bundle is then synced only into local `tests.rbxlx`
(`61a9a1b7-8b1d-4834-8adb-1df099229ce3`, GameId/PlaceId zero). The guarded
transaction checks the four transferred base64 chunks and decoded native bytes,
all old sources/material identities, and unparented corrected templates before
any managed write. It changes five ModuleScript sources, adds the negative
fixture and replaces the two private template roots using bounded parent batches.
Original roots/sources remain available until independent verification passes.

The [complete sync/identity receipt](../docs/evidence/p17/native-sync-and-identity-ee19deb.json)
records passing transaction checks, the independent main probe and **all ten**
target-geometry chunks: 133 source identities, 2,332 native mesh uses, 9,328
actual material slots, 11,660 native metadata fields, 6,996 public native
properties, 6,996 target Size and 27,984 target CFrame components. Explicit
finalization repeats source/native checks before destroying the retained old
templates. The transfer buffer and rollback owner are removed. This is native
Edit reconstruction evidence; ordinary Play, rendered bounds and actual physics
remain separate. The private cloud document and published version are untouched.

### Fresh native correction recheck — 2026-11-14

Fresh ordinary Play on `ee19deb5` passes **173/173 server / 10/10 client**,
one actual client, zero failures/errors/skips. New constructor/preflight and
bounded floor-collision regressions pass. All **2,256** actual-client Outpost
meshes independently pass `AssetMesh.validate` (2,000 Box / 256 Precise).
The [raw baseline and console](../docs/evidence/p17/native-ordinary-baseline-ee19deb.json)
retain the exact observations; this is distinct from two-client acceptance.

The [independent render review](../docs/evidence/p17/native-render-review-ee19deb.md)
closes the prior giant-plane P1 in its actual tested scope. The same prior
outside camera now shows a correctly sized textured Outpost; both furnished
floors, command screens, workshop wood, lamps, stairs/balcony and roof details
render coherently. The [eight original JPEGs and hashes](../docs/evidence/p17/render-capture-files-ee19deb.json)
are native captures without image manipulation. Independent
[floor queries and camera metadata](../docs/evidence/p17/native-render-metadata-ee19deb.json)
pass 13 positions on each Server and Client: five inside hits / eight outside
misses. Real contacts, avatar routes and fragments remain separate. An existing
low-priority “launcher planned” status-label inconsistency is retained as a
nonblocking presentation finding; no new material defect is assigned here.

The [cleanup proof](../docs/evidence/p17/native-render-cleanup-ee19deb.json)
restores the camera and all seven saved GUI values, removes the temporary
binding/attributes, stops Play and passes the main identity plus all ten target
geometry chunks again. Actual viewport is 1153×579, native captures 1920×964,
quality Automatic / FRM enabled: these are not benchmark settings. No complete
thermal/input/full-orbit, multiplayer, performance or human A6 pass is claimed.

Following repeated SDK read-only-document launches, the supported native UI
adapter is [independently reviewed](../docs/evidence/p17/independent-manual-adapter-review-ee19deb.md).
It preserves the v6 gameplay/ray/timing assertions and adds actual native mesh
checks, with explicit completion and full bounded server-only report chunks.
The [installation/readiness receipt](../docs/evidence/p17/manual-start-ee19deb.json)
guards local Edit and exact original Sources, installs four temporary modules /
two dispatchers (137 scripts), verifies the owner survives separate MCP calls,
and selects only the local manual harness. The user confirms two native client
windows, but read-only identity shows both clients/server belong to the cloud
document and have no test reports or manual evidence. **Zero candidate cases
ran.** The local document stays prepared; an actual local launch is required.

The [wrong-document startup receipt](../docs/evidence/p17/manual-ee19deb-wrong-cloud-start.json)
retains the actual server/two-client cloud IDs and empty test reports. One
supported Stop request returns `GameStopped`, but subsequent state/list still
show all three contexts playing; the [Stop discrepancy](../docs/evidence/p17/manual-ee19deb-wrong-cloud-stop.json)
is preserved without a retry loop or cloud Source write. The user is asked to
End Session in Studio, select `tests.rbxlx` through the Window menu and start
the local two-client run. This does not waive the supported multiplayer gate.

### Source-bound two-client continuation and reopen — 2026-11-14–15

The [actual local ordinary reports](../docs/evidence/p17/manual-ee19deb-local-ordinary-baselines.json)
pass **173 server / ten on each of two actual clients**, all zero failures,
errors and skips. The [client aggregate](../docs/evidence/p17/manual-ee19deb-local-client-native-corrected.json)
validates all 2,256 Outpost meshes on both clients. After
[saving the local driver](../docs/evidence/p17/manual-persisted-ee19deb.json), a
fresh native UI launch [confirms source, roster and 173/10/10](../docs/evidence/p17/manual-ee19deb-saved-initial.json).

The [complete raw attempt](../docs/evidence/p17/manual-ee19deb-full-attempt1.json)
is recovered in full: 382,662 bytes / seven chunks, **five discovered / four
passed / one failed / zero skipped**. Passing scopes are authority/rejection,
2,332 native mesh checks and successful callbacks per client over 407 IDs,
actual Humanoid internal 19 / external 29 waypoint routes, and six families'
replicated geometry/earned openings across 42 stage records. Family progression
uses controlled accepted service outcomes, separate from native-fired roof
acceptance. One pristine reset/redeploy passes. The
[summary](../docs/evidence/p17/manual-ee19deb-attempt1-summary.json) does not
convert the later undiscovered cases to passes.

The native M102 case times out at its sixth expected panel hit. Its
[six-shot diagnostic](../docs/evidence/p17/manual-ee19deb-native-heavy-diagnostic.json)
shows five actual panel impacts, Heavy on the third and progress 2/3 after the
fifth. The sixth valid intent fires, but launch/receipt production sweeps first
hit stable `Outpost_Imported1005` (`Roof parapet.002`) as the orbit moves; its
impact has no panel ID. This is legitimate obstruction, not a failed six-hit
rule. A bounded current-geometry selector is prepared without changing orbit,
cover or damage rules. This attempt remains failed pending the actual retest.

After the user restarts Studio, the [reopen audit](../docs/evidence/p17/studio-reopen-audit-2026-11-15.json)
identifies local `f6c61b54-ab35-466b-ab8a-bf51c446b300` and separate cloud
`c3b46f1d-6b93-4fe3-bda8-71c57a1999d2`. The persisted local file has 137
scripts but its in-memory restoration owner is gone. Source/file-backed guards
restore exactly two entries, remove four matched modules and clear the selector.
The [saved normal-mode proof](../docs/evidence/p17/normal-restoration-identity-2026-11-15.json)
passes 133 sources, all native/material checks and all ten target-geometry chunks
in clean Edit. The cloud still has the older 50-script / zero-MeshSize
reconstruction; reported place version 14 does not prove publication and is not
this candidate. D65 now explicitly defers clearance/zoom changes. Reusable
test-only harness promotion and full A1–A6 acceptance remain required.

### Managed native acceptance candidate — 2026-11-15

Test-only source `221d1a824529855db110712d61f0b1f8be5f68e8`, tree
`e75df24d61a8fed9c15d3f8b2f7240f1b03c0305`, promotes the reviewed native
material harness into the local test mapping. Its bounded roof selector checks
current registered residual geometry and the production shot sweep before each
of exactly six M102 intents; each must produce a new same-panel impact. It does
not change orbit, cover, damage or cooldown rules. Manual client dispatch starts
only the selected public harness, preventing old waiting listeners from issuing
duplicate intents during a retained multiplayer session.

The [full host gate](../docs/evidence/p17/developer-host-221d1a8.txt) passes
59 unit / 65 integration / 48 asset / 14 tooling cases, plus required
format/lint/type/reconstruction/isolation checks. The
[preparation](../docs/evidence/p17/managed-harness-preparation-221d1a8.json),
[source manifest](../docs/evidence/p17/managed-harness-source-manifest-221d1a8.json)
and [build record](../docs/evidence/p17/candidate-builds-221d1a8.json) bind 137
test Sources. Production is unchanged from `ee19deb5`; the release still hashes
to `b9e0d6eb851586c9989248ce169968c24228f6c8eab5afe1ae8554500bf10fea`.
The [independent review](../docs/evidence/p17/independent-managed-review-221d1a8.md)
passes the focused host gates and confirms the launch and teardown guards.

[Verify #363](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/43731333059)
failed because its shallow checkout omitted the pinned production tree. The
[failure receipt](../docs/evidence/p17/ci-363-shallow-history-failure.json)
preserves the actual error and local shallow/full-history reproduction.
Commit `bc3e3f980d92d4f3380d32d0df2ba2549854c019` fetches full history;
[Verify #365](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/43731755351)
then passes. No product change is attributed to this CI correction.

The [local sync proof](../docs/evidence/p17/managed-source-sync-221d1a8.json)
guards every old Source, replaces three entries/modules and adds four modules,
then independently verifies all 137 Sources, 2,332 native meshes, 9,328 material
slots and all ten target-geometry chunks in the same local Edit document. It
preserves every world/asset object. The selected P08 three-client startup is
saved locally for the next native session; no cloud document is modified.
New managed V7 gameplay acceptance remains unexecuted at this checkpoint.

The separate `build/preview.rbxlx` remains a normal, unselected standalone test
build, SHA-256 `b3c378607be999da3175b9df6908385b8001d3d5d8dfab344f503eb345fe6d11`.
It includes the corrected native mesh payload and current managed source, opens
directly in Studio and needs neither VS Code nor Rojo for previewing. Larger
clearances and automatic interior zoom remain deferred under D65.

### Reopened local test place — 2026-11-19

The [fresh Edit audit](../docs/evidence/p17/managed-reopen-2026-11-19.json)
confirms the same managed candidate in local `tests.rbxlx` after Studio updated
to `0.748.0.7481526`. It verifies all 137 script sources, 2,332 native meshes,
9,328 protected material slots and all ten target-geometry chunks. The saved
P08 selector and exact P17 harness commit were verified in the local place.
The independent reviewer reran the harness binding and all 14 tooling tests
and verified the 137 script hashes in both local test and standalone builds.
The Edit audit leaves the native gameplay and human approval gates open.

### Three-client startup failure and focused fragment proof — 2026-11-19

In native Server & Clients on Studio `0.748.0.7481526`, candidate `221d1a8`
reported 173/173 server checks and client results of 9/10, 9/10 and 10/10.
The two failed clients computed correct world points and viewport rays. Their
disposable reticle had a zero absolute position after startup character spawn.
The [P08 report and GUI control](../docs/evidence/p17/native-p08-221d1a8-startup-failure.json)
record 1 passed / 2 failed / 0 skipped. P08 timed out waiting for the failed
clients to start their listeners. Teardown passed and all three clients
remained, so the retained two-client P17 stage could not start.

An actual spawn on one failing client removed a resettable GUI and preserved
the otherwise identical persistent GUI and its layout. Test-only correction
`711c5a86729e2fb2805dad473345936ba22d015e` / tree `3d6911e7ccbcfe9ff49df45acc6c9a0b2ed7158a` matches the production HUD's spawn lifetime.
The two attachment checks bracket native samples. The independently reviewed
fix retains all ray, input and 1-pixel assertions. This fix needs a fresh
three-client run with passing baselines and a complete P08 report.
The [full host gate](../docs/evidence/p17/reticle-host-711c5a8.txt) passed on
macOS from a separate checkout of the correction, with 59 unit, 65 integration,
48 asset and 14 tooling tests. The rebuilt test place SHA-256 is
`4f34d8d7a78285aae5d28ebd0582d1c33ca45b36d936d31d9178a29508d370a9`.
The release SHA-256 is still
`b9e0d6eb851586c9989248ce169968c24228f6c8eab5afe1ae8554500bf10fea`.
The [local Edit sync receipt](../docs/evidence/p17/reticle-fix-edit-sync-711c5a8.json)
confirms both changed Sources, the new harness commit, all 137 loaded Sources,
2,332 native meshes and 9,328 material slots. The separate play-session
processes stayed active after the MCP stop response, so the next run starts
through Studio's native End Session and Server & Clients controls.

The [focused imported fragment run](../docs/evidence/p17/imported-fragment-contact-221d1a8.json)
uses the unchanged production source and all 24 approved fragments across six
families through the production owner, with three actual clients connected.
All 24 descended and settled on an actual static surface. The isolated floor
and one temporary spawned avatar provided the contact and interference
controls. The avatar overlapped a fragment without losing health or moving
horizontally. The default ray and sweep reached the floor, while a static-only
query found the fragment. Expiry, the 48-piece cap, clear, stop and fixture
cleanup passed. The first invocation had no avatar after P08 teardown and
rejected before allocation. A4 still requires the live multiplayer replication
and both reset iterations.

### Launcher regression passes on the corrected fixture — 2026-11-19

Fresh native Server & Clients on `711c5a8` passes **173/173 server and 10/10
on each of three actual clients**, with zero failures, errors and skips.
The [full P08 launcher report](../docs/evidence/p17/native-p08-711c5a8-pass.json)
passes **11/11**, with 152 retained traces, zero dropped traces, and two
clients remaining after the stock carrier disconnect. The transport, round,
aircraft and launcher owners are gone at teardown. This closes the P08
regression portion of A5 on the current production source.

The [retained-session diagnostic](../docs/evidence/p17/p17-retained-session-711c5a8-failure.json)
then recorded 168/173 server and 7/10 on each remaining client. The ordinary
tests need fresh startup state, including the automatic characters and
pre-installation Outpost. Those fixtures fail when rerun in the P08 DataModel
after carrier departure, runtime teardown and Outpost installation. P17 was
never started in that DataModel. The original local Edit document now selects
P17 for a fresh two-client session.

### Fresh two-client Outpost run and obstruction diagnosis — 2026-11-19

Fresh native Server & Clients on `711c5a8` passes **173/173 server and 10/10
per client**, with two distinct actual clients and zero failures, errors or
skips. The [full P17 report](../docs/evidence/p17/native-p17-711c5a8-attempt1-raw.json)
contains 500,030 bytes recovered from all nine chunks. It records **5 passed,
1 failed, 0 skipped**. Actual clients passed authority/rejection, asset
availability, internal and exterior Humanoid routes, six-family replicated
states and physical geometry, and all six direct native M102 impacts. The
third hit opened the roof and the sixth removed the selected panel.

The [impact and cleanup summary](../docs/evidence/p17/native-p17-711c5a8-attempt1-summary.json)
identifies the next failure. The fixture completed all 21 first-burst GAU23
launches, but its fixed point on `Outpost_S02_Roof_01_02` put the approved
stable roof parapet `Outpost_Imported1005` first in every production sweep.
All 21 genuine impact outcomes therefore had no registered panel ID. The
first-resumed-credit assertion fired before the fixture checked the actual
hit IDs. The trace establishes the obstruction and leaves native earned
30mm credit and every later case open. Runtime and transport cleanup passed.

The same two actual clients then completed the stock
[P07 destruction regression](../docs/evidence/p17/native-p07-711c5a8-pass.json)
at **7/7** and the [P05 combat regression](../docs/evidence/p17/native-p05-711c5a8-pass.json)
at **8/8**, both with zero failures and skips. Each regression began from
188 pristine registered panel inputs and reused the original fresh two-client
startup reports. P07 reached Heavy through valid sustained 30mm hits on
primitive cover and completed two damaged-to-pristine resets. Those scopes
are separate from the imported Outpost's failed 30mm fixture.

Test-only correction `dd7bb18a59988666874b604005e111cd5a622704` selects an approved point that remains solid
through Light and Heavy. It checks genuine first hit and allowed view across
the canonical orbit for each complete 21-shot window, then rechecks the current
launch position. The fixture requires 63 actual same-panel outcomes and the
original cadence, persistent credit, pause and nine-second assertions.
Its independently reviewed client and all production bytes are unchanged.
The [full host check](../docs/evidence/p17/burst-host-dd7bb18.txt) passed from
a clean macOS checkout with 59 unit, 65 integration, 48 asset and 14 tooling
cases, plus artifact isolation. The release SHA-256 still matches `ee19deb5`.
The [local Edit proof](../docs/evidence/p17/burst-fix-edit-sync-dd7bb18.json)
verifies the three changed modules, all 137 loaded Sources and the existing
2,332 native meshes and 9,328 material slots. A fresh native run is pending.

### Primitive performance preflight and incomplete run — 2026-11-19

The [primitive workload receipt](../docs/evidence/p17/primitive-performance-711c5a8-attempt1-summary.json)
records two actual 1920×1080 desktop-simulator clients at fixed
`QualityLevel10` on a MacBook Pro with M1 Pro and Studio `0.748.0.7481526`.
The [raw report](../docs/evidence/p17/primitive-performance-711c5a8-attempt1-raw.json)
records 300 seconds of server sampling and all six 187-panel demolition batches.
The fixture recorded 253 GAU23, 28 M102 and 193 impacts, including 74 Outpost
impacts. It stopped before obtaining the client reports because it measured
zero rifle shots. The temporary client had looked for the rifle remotes under
ReplicatedStorage, while production parents them to AircraftState. No
benchmark comparison or performance budget pass is claimed from this run.
Runtime and effect ownership returned to zero after completion.
