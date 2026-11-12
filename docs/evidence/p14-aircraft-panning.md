# P14 aircraft panning evidence — 2026-11-09

Source candidate **`8bbab8e50f8d177a06910851f1afcc423486aa74`**, tree
`c445a376c14645868a52f81868c59730955b9f6d`, is pushed on
`plan/14-aircraft-panning` in [draft PR #18](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/18).
Base/main is `10327b43638897aeacc6bc86187d8a31a392ce38`, containing completed P13.
Implementation and focused engine corrections are delivered; **required full
acceptance is incomplete**. Roadmap owns status. P05 has not started.

## Source and host verification

The existing thermal camera owns bounded raw-edge pan, persistent world-space
focus, R/button recenter, acknowledged 35°/60° zoom and geometry-aware reticle
rays. Defaults are 12% edge zones, 120 studs/second, 0.1-second update cap and the
central 70% displayed reticle. A stable projected canonical-right basis handles
looking directly below the aircraft at the disk edge. UI hover/text/window focus
blocks input; GUI hit queries alone subtract GuiInset. Raw pointer coordinates
still drive edge pan. Production now rasterizes once to an integer pair shared
by the displayed reticle, ray and attributes. No pan remote, firing or damage is
implemented.

The authored −1..32-stud aim envelope and selected actual weapon muzzle constrain
server aim. The envelope adds three nodes; building geometry is unchanged:
334 world parts / 360 world nodes, 351 authored parts across world/models.

- `python3 scripts/verify.py > build/p14-raster-fix-verify.txt 2>&1` exits zero:
  **46 unit / 18 integration**, format, lint, strict types, rejection probes,
  both builds, 351 transforms, 111 panel pivots, 7,146 surface pairs and release
  isolation (414 release / 478 test Instances, 25 release runtime scripts).
  Thirteen pure AircraftPanRules cases include three raster regressions.
  Lint used its cached Roblox API definitions after the upstream dump fetch
  failed; actual lint completed with zero errors/warnings/parse errors.
  [Full log](p14/host-verify.txt), [source/build hashes](p14/source-manifest.json).
- [GitHub Verify 42729968970](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/42729968970)
  passes on exact source candidate `8bbab8e`. Later delivery changes are prose,
  evidence and the actual preview image. Both current artifacts were rebuilt
  and `python3 scripts/inspect_build.py` passes after source freeze.
- Independent tester reviewed production, harness and fixes and exercised the
  actual Studio candidate. [Chronological report](p14/tester-report.md) records
  checkpoints, failures and superseded handoffs; final cleanup is recorded below.
- Independent Lune probe exercises **73,205** clamp combinations through DBL_MAX:
  **9,360 explicit rejections, zero nonfinite outputs**. Sixty-four extremely
  translated-map cases have tiny boundary roundoff (about 0.0000008 studs at
  center 1e10/radius 360); the current origin map is unaffected. This is a retained
  numeric limitation, not exact mathematical boundary proof.
  [Probe JSON](p14/overflow-probe.json). Reproduce by copying the
  [literal archive](p14/overflow-probe.luau.txt) to `build/p14-overflow-probe.luau`
  then running `~/.rokit/bin/lune run build/p14-overflow-probe.luau`.

## Actual engine checkpoints

Studio version is 0.746.0.7461269. Latest source preflight matches all **63**
first-party mapped scripts; current ordinary Play has **one actual client**.
A baseline pass does not establish the separate six-case multiplayer suite.

| Source / invocation | Actual result |
| --- | --- |
| Initial `a326133` | Two actual clients, 79/79 server and 2/2 each client; 585 native camera CFrames pass. Full suite stops at second projection target: 3 discovered / 1 cleanup pass / 2 failures including completion. Steering threshold/wait sequencing was wrong. [Report](p14/first-engine-report.json), [diagnosis](p14/first-engine-diagnosis.json). |
| Arrival fix `f16e695` | Explicit consistent 0.25-stud arrival, stop-steering and committed pointing frame. `ExecuteMultiplayerTestAsync(2,{kind="P14ArrivalRegression"})` passes 2/2 with two actual clients. Target (220,0,220) has zero world error and 0.000153-pixel projection error; teardown passes. [Report](p14/arrival-regression-report.json), [preflight](p14/arrival-fix-preflight.json). |
| Native hover defect, `f16e695` | Real pointer (495,674) visually hovers GAU23 but raw query misses with GuiInset (0,58); InputBlocked=false and focus drifts over 3.517 seconds. Adjusted GUI query finds the control. [Report](p14/native-hover-failure.json). |
| GUI fix `25b44e7` | Ordinary 79/3 passes. Real default-input hover blocks and holds exact focus; weapon buttons preserve focus; R/button recenter works; actual TextBox focus blocks input and release untraps it. Numeric 1280×720 and 1920×1080 layouts have controls in bounds/TextFits and zero drawn error at sampled coordinates. Two preview exit/reentry cycles restore Custom camera/FOV70/default mouse and remove effects, then create one HUD/effect on reentry. [Report](p14/native-inset-fix-report.json). These are focused checks, not complete rendered/full-orbit acceptance. |
| Manual native full suite, `e6ff4e7` | Native Server & Clients eventually starts two actual clients. 79 server / 3 each client pass, 585 native frames pass. First projection fails ≤1-pixel drawn-reticle agreement: 3 discovered / 1 cleanup pass / 2 failures including completion. [Actual context](p14/manual-first-context.json), [report](p14/manual-first-report.json). |
| Raster diagnosis | Actual UDim2 GUI probe at viewport 1081×618/inset 58 requests (540.994995,309.994995) but stores/draws (540,309), error **1.4071356px**. Earlier fixture lost exact failing-frame diagnostics; this independent observation establishes the same material mismatch. [Probe](p14/manual-drawn-probe.json). |
| Raster fix `8bbab8e` | Current ordinary Play passes **82/82 server, 3/3 client**, zero failures/errors/skips. Four real raster samples draw/ray/store at identical integer pixels, error 0. Actual default-input production ThermalHUD raw (540.994995,309.994995) → (541,310), drawn and world projection error 0; odd center → (541,290), error 0. Diagnostics are committed before fixture assertions; declared tolerances unchanged. [Engine report](p14/raster-fix-engine-report.json). |

Tolerances were declared before engine runs: projection ≤1 pixel / 0.5 studs,
steering neighborhood ≤3 studs with mandatory actual slope/building panel
identity, horizontal inward dot ≥−0.000001 and live origin discrepancy ≤2 studs.
No thresholds were widened to conceal findings. A separate uncommitted-frame
observer saw 2.217 studs origin discrepancy; it was not phase-aligned acceptance
or a confirmed production defect. Full same-frame assertions remain required.

## Current external blockers and bounded attempts

The initial unnamed **Place is not open** connection blocker was resolved before
these engine checks. It is not the current blocker. Supported SDK full launches
subsequently produce one client or divert StartServer into EditFile before a
server DataModel exists. Metadata/login succeeds in the relevant native logs;
these are not diagnosed as current OAuth failures.
[One-client failure](p14/multiplayer-launch-failure.json),
[SDK sequential failure](p14/sequential-launch-failure.json),
[bounded diagnosis](p14/native-launch-diagnosis.json),
[post-inset SDK failure](p14/inset-fix-sdk-launch-failure.json).

A test-only native UI fallback was then implemented: only Studio, nil SDK args
and a temporary server-only `DevelopmentSettings.ManualHarness="P14"` select the
same six strict cases. Git defaults contain no selector. Completion publishes
`workspace.ManualP14Report` and invocation in the actual server. This route
successfully exposed the raster defect with two clients; it does not guarantee
that later native client launches connect.

On current `8bbab8e`, native UI requests **two** StartClient processes; both reach
metadata/login, first accepts localhost, second logs Joining localhost but never
accepts or appears as a connected client. At 114.58 server seconds actual clients
remain 1, server baseline 82 passes, roster rendezvous has timed out, no RoundState
or report exists and **zero P14 scenario cases execute**. The lone client reports
2 pass / 1 fail / 1 error from downstream deferred runtime startup. This is neither
projection failure nor a passing/skipped full suite.
[Current failure](p14/raster-manual-launch-failure.json),
[bounded native logs](p14/raster-manual-launch-logs.json).

The final distinct attempt uses one native initial client followed by exactly one
`StudioTestService:AddPlayers(1)` on the confirmed running server. Studio rejects
that API as requiring an SDK-owned running test session; this manually started
session has nil SDK args. Actual client count remains 1. The two-player requirement
and timeout were preserved. [Exact result](p14/serial-manual-api-failure.json).
No additional launch variants are attempted after this capability limit.

Native full rendered review also became unavailable after the game viewport lost
focus. Focus blocking behaved correctly, but MCP/existing-process activation did
not restore native GameViewWindowFocused. A black 3D capture cleared after focus;
a reversible own-aircraft transparency A/B did not change it. Neither permanent
blind-strip absence nor rendered exposed/covered thermal correctness is proven.
No automation permission or private focus bypass was enabled.

## Acceptance matrix and remaining work

| Criterion | Verified | Required evidence still open |
| --- | --- | --- |
| A1 | Full host gate, 13 pure pan cases, 585 historical native camera frames, current82/3 ordinary smoke and raster checks. | Current full-suite phase-aligned camera assertions. |
| A2 | Real focused arrival regression; server aim-envelope/muzzle baseline tests; fractional raster defect corrected and rechecked in production. | Complete 28 slope/upper-floor/edge target probes over a full 90-second orbit at each FOV, same-frame bounds and rendered combat-area visibility. |
| A3 | Native solo zoom keys/buttons preserve focus and coherent profiles. | Current two-actual-client aircraft/Ground-camera isolation, selection/rejection coherence and applicable P04/human multiplayer regressions. |
| A4 | Real hover/text blocking, raw-coordinate preservation, recenter, numeric layouts at both resolutions, actual panned preview. | Complete rendered slope/upper-floor thermal cover, both-FOV full-orbit comfort and operated resolution review. Partial numeric/capture checks do not replace it. |
| A5 | Two native preview exit/reentry cleanup cycles, historical focused/full-failure teardown checks, all owned simulations cleaned. | Full current round reset/new operator/departure/kick and repeated ownership scenarios, plus applicable multiplayer regressions. |

The harness expects **six** P14 cases, two actual clients, 14 surfaces at each FOV
and full 90-second coverage per weapon. Earlier partial passes are not six-case
acceptance. Automated fixture input uses the ordinary constructor boundary;
actual native default UserInputService wiring/feel is evaluated separately.

## Cleanup, documentation and delivery

After reports were preserved, `StudioTestService:EndTest` on each actual running
manual **server** closes its owned server/clients. Generic MCP Stop did not end
manual Server & Clients; EndTest in an Edit context is invalid. Final inventory
contains only original `ab521a9d-50ef-49e7-a9c4-f56e2a88f5c5`, tests.rbxlx,
place 0, **Edit**, with nil SDK args and **ManualHarness=nil**.
[Cleanup proof](p14/serial-manual-cleanup.json). Rojo remains on localhost:34872 /
PlayersVsC130Tests. Owned fixtures, observers and temporary roof changes were
removed/restored; device settings were restored to default/LandscapeRight/
ScaleToPhysicalSize.

The [representative real preview](p14/current-progress.jpg) is from 2026-11-09,
source f16, Waiting/Lobby Operator preview, actual Camera 1280×720 and capture
raster 1920×1080. Subsequent fixes preserve this visible scene/layout, so it remains
representative; it is not latest-source multiplayer or 1920-viewport proof.
The technical writer updated player/contributor/package prose for current
behavior, raster API, counts and the guarded manual procedure, explicitly keeping
full acceptance open. Final documentation is checked with
`python3 scripts/check_repository.py` and `git diff --check` before delivery.

Draft PR #18 preserves source and evidence for review. Main remains unchanged.
No merge, Roblox publication or next-plan implementation occurred. Resume only
with a working two-client session path and native rendered-review access; do not
mark P14 complete from current partial results.
