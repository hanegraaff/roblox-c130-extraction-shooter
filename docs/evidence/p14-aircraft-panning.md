# P14 mouse-panned targeting candidate — 2026-11-09

Candidate `a32613376599b38f787fe6484dc3e93a840ba935`, tree
`6cd40a2507d554dc12fa7a731e121783314cde63`, is pushed on
`plan/14-aircraft-panning` in
[draft PR #18](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/18).
It branches from fully integrated P13 main `10327b4`. Implementation is present;
required Studio acceptance remains unrun. No engine result is inferred from host
tests or source review.

## Source behavior and declared defaults

The existing ThermalCameraController gains pure bounded edge-pan integration,
world-space focus, R recenter and geometry-aware reticle rays. Focus persists
across orbit motion and acknowledged 35°/60° zoom changes. A stable projected
canonical-right camera basis handles the exact disk-edge/vertical look case.
Role/new-round entry resets focus; teardown retains normal camera/input cleanup.
The default input provider samples real UserInputService, UI hover, text and
window focus; an optional constructor boundary supplies deterministic raw input
to engine fixtures without a production test flag, focus setter or pan remote.

Before testing, the plan records a 12% edge zone, 120 studs/second maximum speed,
0.1-second update cap, central-70% display reticle and R recenter. Raw pointer
edges drive pan before the display clamp. Battlefield/AimEnvelope authors −1 to
32 stud elevation bounds; server aim validation rays from the selected weapon's
actual muzzle. This seam validates geometry and does not fire or grant damage.
The envelope adds three nodes: 334 world parts / 360 nodes, with 351 authored
parts across world/models. No building geometry changed.

Declared engine tolerances remain 1 pixel / 0.5 stud projection agreement,
horizontal inward dot at least −0.000001 and at most 2 studs live origin
discrepancy between Heartbeats. Automated steering separately permits a 3-stud
target neighborhood while requiring actual nonflat Terrain or the requested
building's StoryId `02` panel. These are planned acceptance bounds, not measured
engine results.

## Actual verification

- `python3 scripts/verify.py > build/p14-developer-verify.txt 2>&1` exits zero:
  **43 unit / 18 integration**, format, lint, strict types, required rejection
  probes, both builds, 351 transforms, 111 panel pivots, 7,146 surface pairs and
  release isolation. Ten new unit cases cover production AircraftPanRules.
  Artifacts contain 414 release / 477 test Instances and 25 release runtime
  scripts. [Full host log](p14/host-verify.txt),
  [source/build manifest](p14/source-manifest.json).
- Independent source review covers the actual rules, production controller,
  input/lifecycle, authored envelope, selected-muzzle seam and both harness sides.
  No material source defect was established. The tester did not repeat the
  unchanged full host gate. [Independent report](p14/tester-report.md).
- Independent Lune probe exercises **73,205** clamp combinations through DBL_MAX:
  **9,360 explicit rejections, zero nonfinite outputs**. Sixty-four extremely
  translated-map cases have tiny roundoff overshoot (about 0.0000008 studs in
  the cited 1e10-center/radius-360 case); the current origin-centered map is
  unaffected. This is retained as a numeric limitation, not silently counted as
  exact mathematical boundary proof. [Actual probe JSON](p14/overflow-probe.json).
  For reproduction, copy the [literal probe archive](p14/overflow-probe.luau.txt)
  to `build/p14-overflow-probe.luau`, then run
  `~/.rokit/bin/lune run build/p14-overflow-probe.luau` from the repository root.

## Acceptance still required

| Criterion | Pending actual engine evidence |
| --- | --- |
| A1 | Execute native camera-basis assertions: the harness contains 585 CFrame samples over 65 phases and nine focuses; none has run in Studio. |
| A2 | Actual camera-ray/surface projections at both FOVs over full orbits, 28 targets, terrain slopes and every building upper floor; authored envelope/muzzle-obstruction engine cases. |
| A3 | Two actual clients, unchanged canonical aircraft/Ground camera, acknowledged keys/buttons/zoom and rejection coherence while panned. |
| A4 | Native default-provider mouse/key/button operation, rendered thermal cover on slopes/upper floors, UI blocking/window focus, actual 1280×720 and 1920×1080 layout, comfort review and representative gameplay capture. |
| A5 | Actual reset/new-round/new-role/operator departure, repeated preview/role entry, singleton camera/effect/listener ownership and normal camera/input restoration; applicable P04 and human-controls regressions. |

The new `{kind="P14"}` two-client harness expects six scenarios, both FOVs and
full 90-second orbit coverage. The expected new baseline is 79 server / 2 client.
These are discovery expectations only: **no P14 Studio test was started** and no
passing real-client, viewport or rendered result is claimed. Automated fixtures
use an injected input provider; native wiring/feel requires a fresh ordinary
session with the default provider, as the tester explicitly checked.

## Concrete connection blocker

The original confirmed test instance `21f6fc11-4429-4148-9764-89a36987e5e9`
disconnected during repository development. Subsequent MCP inventory shows only
`3115533b-a162-4a3b-a453-24ba1a187070`, name null; both state and Edit execution
report **Place is not open**. No new process was launched or existing Studio
closed by the agents. The Rojo server is independently confirmed listening on
127.0.0.1:34872, project PlayersVsC130Tests, version 7.7.1.

The user confirmed signed-in/open/Rojo-connected state. MCP still reports the
unnamed unopened instance, so a second question requests enabling Studio's MCP
server/ChatGPT Quick Connect in the loaded document. That response/connection is
pending. Before any engine acceptance, identify the actual project, confirm Edit,
verify all mapped candidate source signatures and only then start a fresh test.
Do not retry OS launches or count a stale-source run.

The still-current building/world image is accurately retained; it is not a P14
gameplay/panning capture. The required refreshed image remains part of A4.
P05 has not started. This candidate is not complete, and neither merge nor Roblox
publication occurred.

## Documentation and delivery checks

The technical writer updated 16 player, design, contributor and package documents
to describe the candidate controls/API, branch setup, defaults and expected test
counts while keeping engine/native/UI/capture acceptance explicitly pending.
`python3 scripts/check_repository.py` passes **64 Markdown / 59 JSON files**;
`git diff --check` passes. Source and tests are unchanged after candidate
`a326133`. [GitHub Verify 42720211427](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/42720211427)
passes on that exact source commit. PR #18 remains draft until required Studio
evidence and the new actual gameplay capture exist.
