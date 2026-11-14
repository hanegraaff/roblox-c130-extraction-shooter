# P17 — Replace the smaller Outpost with the approved asset

**Milestone:** M4 / Outpost integration. **Dependencies:** P16, P07, P13, P14. **Requirements:** R01, R05, R06, R09, R10, R12, R15, R16, R19, R20. Status: [roadmap](../roadmap.md).

**Sequence (D63):** Implement immediately after the approved P16 package, before continuing P09. This plan sits between P07 and P08 in roadmap order and does not require P08 to start; preserve the already completed launcher implementation when present in the selected source.

## Capability and player experience

Walk through the detailed military outpost approved in P16, including its storage/workshop downstairs, command room upstairs, exterior stairs/balcony and rooftop details. Aircraft fire produces persistent damage appropriate to each panel's material, real openings and bounded physical debris. Replace **only the existing smaller Outpost** in the current battlefield. Foundry and Warehouse remain the two larger buildings; this does not introduce a second level or level selection.

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
