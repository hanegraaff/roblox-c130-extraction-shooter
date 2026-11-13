# P07 damage revision — 2026-11-13

The user removed the real late-joining-player scenario from current P07
acceptance and reported three remaining issues: Light/Heavy damage was not
visually distinct, the battlefield starting shelter stayed immune, and 30mm
damage disappeared after stopping fire. The user clarified the shelter is the
battlefield spawn structure, not the outside waiting lobby.

Dedicated branch `fix/p07-progressive-persistent-damage` starts at
`ebf5bd4d19a1237ccc346479c0d5dea282616058`, containing unmerged dependency
[PR #29](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/29).
Main remains `e4c6e3a2506a9e9ac5574bdf42242f77f8200650`. No previous gate
count is a pass for this changed behavior. No merge/publication is authorized.

## Confirmed source causes

- `PanelDamageRules.interrupt` zeroed sustained credit. Idle, miss/target,
  selection/reload and eligibility barriers eventually called it, causing
  partial damage and its appearance to heal.
- `PanelGeometry.publish` based appearance only on stage-local progress.
  Completing a stage reset that progress to zero and restored the original
  color/material, despite a Heavy structural state.
- All nine Ground anchors deploy inside the legacy shelter. Its seven
  colliders were in `Battlefield.Permanent`, while DestructionRuntime captured
  only the three multi-story building registries. Every shelter impact was
  therefore nonstructural. The other 111 panels were registered correctly.

## Steering recorded before new tests

D50 waives the real late-join test without deleting runtime spectator authority
or relabeling old timeouts as passing. D51 selects persistent per-panel earned
credit and continuity-only interruptions. D52 selects distinct Pristine/Light/
Heavy/Total appearance, retaining three/six heavy-hit and nine-second stage
thresholds. D53 records faithful starting-shelter panelization: 42 roof and
34 wall panels replacing all seven old colliders, preserving union/entrances/
anchors and yielding 187 total panels. D54 records the proposed grayscale-safe
crack/luminance/material defaults before implementation tests. These dimensions,
colors and counts are tuning defaults; clear progressive damage and complete
building coverage are user requirements.

Required fresh checks include deterministic persistent damage across all break
causes and alternating targets, ordered in-flight/barrier/terminal/reset cases,
engine visual/collider/query distinctions, complete shelter union/registry and
spawn protection, actual two-client progression/replication/reset and focused
normal/thermal/native-firing review. The existing Edit document
`eea79821-d1ee-47bb-b6c6-cdf494d9ba94` and Rojo port 34872 are retained.

The old [P07 evidence](p07-destruction.md) remains historical and source-specific.
No revised implementation/test pass is claimed at this steering checkpoint.

## Development checks

The developer's first focused deterministic run on uncommitted revision source
passed 55 unit / 55 integration cases, including persistent per-panel credit,
alternating targets, burst accumulation to nine/eighteen seconds, terminal
retention and Heavy appearance at zero local progress. Asset/fixture/engine
work was still changing. These are development results only; no frozen full
host gate, new Studio pass or completed acceptance is inferred.

An interim artifact check rejected cloned shelter tile data with no explicit CanQuery flag. Authoring was corrected to CanQuery=true on the new panels; focused builds/artifact checks then passed with 422 authored Parts, including four deliberate shelter-union corruption rejections. The complete host gate was still running at that checkpoint. This authoring failure is retained separately from final results.

## Independent candidate checks and fixture findings

Source `583d82abebc32e0f43fc9d521b008ce6de1c3ace`, tree
`dd622b8684c371423905bda66e828ef25ae4d3e9`, froze the first implementation.
Developer and independent full host gates passed 55 unit / 55 integration,
422 authored Parts per artifact, 503 release / 586 test Instances and release
isolation. Independent review found a stale P07 manual invocation flag still
claiming `actualLateClientRequired=true`; the actual waiting case was removed.
The single metadata correction is `a92d704d13394c8947c6698637266faef2c0e1cd`,
tree `2cd238839145819b98136ef41a3fb0f6ba66316f`. P03 spectator tests remain.
Its independent full host gate also passed 55 / 55 and all non-Studio gates.
All 97 mapped scripts and 403 authored Battlefield Parts matched the existing
Edit source/geometry before a fresh ordinary solo Play.

That [fresh solo run](p07-revision-solo-a92-failure.json) FAILED: 142 discovered,
141 passed and one server failure/error; client 6 discovered, 5 passed and one
cascading Foundation failure. Bootstrap was clean/running (Uptime 16→73,
first actual client 0.171385 seconds). The failing appearance assertion demanded
different stored surface colors after 0.15→0.30 earned seconds. The other
registry, 187-panel geometry, cosmetic/query/physics and pre-impact cases passed.
Actual signed-in Studio identifiers are redacted in the saved report.

The [actual ledger/color probe](p07-revision-color-ledger-report.json) with
[exact replay source](p07-revision-color-ledger.luau.txt) isolated both a Foundry
wall and starting-shelter roof: earned 0.15 survives idle/resume-first-zero,
then 0.30 is correctly retained while BasePart.Color quantizes both mathematical
colors to RGB(149,141,127). At 0.45 the stored color changes. This establishes
a fixture sub-byte color assumption, not lost damage. The authorized correction
retains the exact 0.30 credit assertion and checks color plus added bounded
crack geometry over a declared larger valid interval sequence below nine
seconds. Production color, persistence, cadence and geometry rules stay fixed.
No passing revised engine gate is inferred from that diagnosis.

## Corrected frozen revision and passing baseline

The test-only quantization correction is frozen in
`4db45950a0516ac916299fbbd728a606e4c6e6f8`, tree
`4d9dc2e3bbd8bd1a6e91d01f60c15a2b6e5742bc`. It retains exact 0.30-second
credit, then checks 1.95 earned seconds for changed stored color AND an added
bounded crack; first/resumed-zero, persistence, Heavy-at-zero and real collider
checks remain. Production damage/color/geometry code is unchanged by this fix.
The [103-file identity record](p07-revision-source-identity.json) identifies
the actual code/assets/tests/tools, separately from changing prose.

Independent final `python3 scripts/verify.py` passed 55 unit / 55 integration,
zero candidate failures/skips and all format/lint/strict/build/probe/isolation
gates. Both artifacts have 422 authored Parts; 503 release / 586 test Instances,
40 release runtime scripts, the 720-stud map and 111+76=187 panel registry pass.
Four shelter-union corruption probes reject malformed authoring as intended.
The earlier intentional failing/empty/type probes remain expected rejection
controls, not actual candidate failures.

The [fresh ordinary solo report](p07-revision-solo-4db-pass.json) passes
**142 server / 6 client**, zero errors/failures/skips. Bootstrap Running remains
true and Uptime advances 26→51. The same original Editor had all 97 script
Sources and 403 Battlefield Part poses/sizes/collision/query/touch flags
compared before Play, with zero mismatches. Native metadata now correctly
states the real late-client gate is false. Actual signed-in solo identifiers
are redacted without changing counts/results.

The user then started the prepared two-client session. Its
[initial proof](p07-revision-native-initial.json) identifies actual server
`0742bf2c-7b68-4062-986f-d1f333afdce4`, operator client
`725ea0e9-e852-4b1b-8308-9faf5878f795` (-1) and Ground client
`0c353c9d-9d25-49a9-9879-d46f970b2d6b` (-2). Both are real Alive participants;
142 server and 6 per-client baseline cases pass, first client arrives at
6.363356 seconds and `actualLateClientRequired=false` is observed. The revised
seven-case report and focused visual/native-input checks are still pending
at this checkpoint; historical results are not substituted.
