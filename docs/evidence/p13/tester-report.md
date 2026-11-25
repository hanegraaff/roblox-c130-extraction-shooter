# Independent P13 verification

## Superseded initial source

Initial candidate `24af8f26dc4e8dcf4dd964fffcf8536cb96ab9df`, tree
`0f8d56b5bfbf2e31b4c82658be587fe77b1b6cfc`, on
`plan/13-terrain-and-buildings`.

- `python3 scripts/verify.py > build/p13-independent-verify.txt 2>&1`: exit 0,
  33 unit / 18 integration cases; 339 authored transforms per build; isolation passes.
- Existing Studio instance `21f6fc11-4429-4148-9764-89a36987e5e9`, document
  `p02-tests-5c809beff70b.rbxlx`, place 0, version `0.746.0.7461269`.
- Source-identity probe: 58 mapped first-party sources agree with local bytes/Adler32.
- Loaded geometry probe: all 339 parts agree in pose/size/shape/collision flags;
  maximum CFrame component error `0.000014292654839209718` against `0.001` tolerance.
- Preliminary single-client baseline: 66 discovered / 55 passed / 11 failed /
  11 errors / zero skipped server; 2/2 client. All 11 engine failures arise from
  `blocked building entry route` at fixture construction. Actual 4×6×4 sweep
  intersects first stair while entering all three buildings: Foundry at
  `(-188,3.5,-86)`, Warehouse at `(140,3.5,-62)`, Outpost at `(140,3.5,182)`.
  The fixture needs to follow actual standing support height at the legitimate
  stair transition. Session stopped; no multiplayer acceptance claimed.

## Consolidated review findings

1. High / A4, A6: first-stair clearance rejection prevents valid map startup.
2. Medium / A6: stopped-containment regression uses X=220, now inside radius 360;
   a leaked connection could pass. Use an exterior point and retain unchanged-pose
   assertion after stop.
3. Medium / A2, A4: `BuildingGeometry` checks nav count and Walk01/02/05 only.
   With five children, renaming Walk03 can throw at the cast's `.Position` instead
   of returning false/reason; renaming Walk04 can pass validation. Validate all
   five named BaseParts before use and cover malformed IDs.

## Revised source dec7dd5

Candidate `dec7dd5498210b7d7d6a5b6a88a99d83c8e4e4df`, tree
`d88aee1a7f7cd91919cf14ffe0a001b36d18944a`, resolves the three earlier findings
and adds room-bay/lobby-separation checks.

- Full host gate `python3 scripts/verify.py > build/p13-independent-final-verify.txt 2>&1`
  exits 0 with 33 unit / 18 integration cases and 351 transforms per build.
- All 58 sources agree in Studio; all 351 loaded parts agree with the source.
  Maximum CFrame component error remains `0.000014292654839209718`.
- Fresh one-client baseline: 67 discovered / 66 passed / 1 failed / 1 error /
  zero skipped server; 2/2 client. All new building/terrain/lobby/cleanup cases pass.
- High / A4, A5, A6: existing Map cover case fails `spawn unprotected: Ground01
  phase 5`. Independent actual engine rays find no obstacle at Ground01 phases
  5 and 6 and Ground03 phases 6 and 7, using the expanded radius 360 / altitude
  140 aircraft samples. The lower angular aircraft position now sees under old
  shelter geometry. Repair shelter coverage while preserving passable routes and
  the all-nine-spawn protection contract.
- Runtime/multiplayer are correctly prevented by the failed baseline. Session
  stopped and original document returned to Edit. Viewport 1081×619, saved graphics
  and rendering quality both Automatic; no performance claim.

## Final tested source and independent checks

Final test candidate `ea9cd4ee567e28d205841b093180cad3d0921110`, tree
`654ce450241698cc00353d9209a07a3e188654f8`. Product geometry/runtime behavior is
unchanged from `b157e8423ad8d745e97043fbc7bb8f6673e6d516`; subsequent changes affect
only the P13 test harness numeric observations.

Independent `python3 scripts/verify.py > build/p13-accepted-verify.txt 2>&1` exits 0:
33 unit / 18 integration cases, 351 part transforms per artifact, 111 stable panel
pivots, strict types/format/lint/isolation and required rejection probes pass. Final
Studio source check matches all 58 mapped first-party scripts. Loaded geometry
comparison matches all 351 parts, maximum CFrame component error 0.0000142927 against
0.001 tolerance. macOS arm64; Studio 0.746.0.7461269; original local test document,
place 0, existing test Rojo server 127.0.0.1:34872. No cloud publication or 6/10-player
capacity claims.

- Fresh ordinary Play baseline: 67/67 server and 2/2 client, zero errors/failures/skips,
  one actual client. Runtime and labelled solo preview start.
- `ExecuteMultiplayerTestAsync(2,{kind='P13'})`: three passing scenarios: both real
  clients observe matching geometry/terrain/aircraft; actual server-owned ground
  Humanoid traverses Foundry, Warehouse and Outpost from outside entries to upper
  floors without waypoint teleports; both clients agree after two perturbed resets.
  All six received client observations include fresh 2/2 client baselines, zero
  errors/failures/skips. Baseline server is 67/67 with initial clientCount=1, distinct
  from the harness's two actual participants.
- P13 fourth scenario fails: `AddPlayers(1)` does not produce a third connected
  player within 30 seconds. Final report is 3 passed / 2 failed / 5 discovered,
  zero skipped, peak 2 actual clients. Failed entries are late join and harness
  completion. The final resource-teardown case is not reached. This is incomplete
  acceptance, not five passing scenarios.
- `ExecuteMultiplayerTestAsync(2,{kind='P04'})`: fails first profile case on reticle
  bounds; 0 passed / 2 failed / 2 discovered, zero skipped, two actual clients and
  passing 67/67 server plus 2/2 per-client baselines. The report does not preserve
  numeric viewport/reticle values at failure. Full 90-second orbit, later selection,
  role-loss and reset assertions are not executed. No production camera source
  changed in P13; this remains an unresolved harness/viewport observation gap.
- `ExecutePlayModeAsync({kind='HumanTestControls'})`: 6/6, zero errors/failures/skips,
  one actual client. `ExecutePlayModeAsync({kind='LobbyControls'})`: 4/4 likewise.
  The four-case actual two-client human-settings suite remains unrun after the
  external launch blocker.

## Defect resolution and external gap

The first-step validation, stopped-heartbeat assertion, navigation marker checks,
room bays/lobby separation and shelter coverage findings are resolved. The final
cover case strengthens protection to all nine anchors at 64 orbit phases (576 rays).
Numeric server/client signature inspection found 15 boundary-part signed-zero
string differences, with exactly zero numeric error in the offending components.
The largest actual server/client CFrame component delta was 0.0000452548 on
Boundary33. The test-only comparator now uses 0.001 numeric tolerance plus exact
identity/class/shape/flags and rejects >tolerance/missing-ID/flipped-flag probes.

A bounded standalone late-join diagnostic could not start its initial two-client
server: owned StartServer PID22880 never connected MCP. Its Studio log records
repeated OAuth metadata/experimentation connection timeouts and LoginController
metadata failure. The documented AddPlayers argument and server context match the
previous successful P03 usage. Only PID22880 was terminated; original Studio PID73836
was preserved. This supports an external launch gap, not a second reproduced
AddPlayers failure. No further multiplayer retries were attempted.

## Operated and visual review

Both launcher routes were operated with actual `character_navigation` calls at
speed 1, four segments each, with no teleport between segments. The avatar was
staged only at each outside start. All eight calls succeeded. Actual W input for
0.7 seconds moved from (0,3.098,120) to (0,2.998,108.267). Hill04 was climbed from
(0,3,-205) to (0,20.906,-259.158), ending in Running state. The P13 harness separately
operated each building's real stairs and upper floor. These establish the recorded
avatar/fixture, not all avatar sizes/accessories.

Single Operator preview checks over three rendered frames observed viewport
1081×619, pixels (918.85,393), cross offsets (918,393), GAU23 FOV35; key2 selected
M102 FOV60 coherently. These in-process observations do not resolve the earlier
two-client P04 failure numerically. Saved graphics and rendering quality are both
Automatic; no frame-time/performance claim.

`build/p13-current-progress.jpg` is a real Studio Edit inspection overview on
2026-11-08, showing the expanded disk, eight terrain hills, three buildings, central
cover/routes and detached lobby. Camera (480,410,510), focus origin, FOV55. The
production TerrainRecipe reconstructed the actual terrain; prior owned terrain
and camera were preserved and restored. This is an Edit overview, not the operator
gameplay camera. Image 1886×1080; original actual viewport 1081×619. The low-detail
world and large central shelter are readable as a primitive construction stage;
ground travel remains short near the central launcher, with greater exposure toward
outlying buildings/hills. Balance and camera reach await later plans.

`build/p13-terrain-sample.luau` and `build/p13-terrain-original.json` preserve the
sorted eight-hill voxel-neighborhood signature: 1152 samples, 9513 canonical bytes,
Adler32 2054186319. Original apices match Grass/Rock and lie from 17.0566 to 18 studs.
Parent owns the fresh serialized-artifact load comparison and clean-checkout evidence.

## Acceptance disposition

A2 and the original-document A4 checks are verified. A1 host/artifact gates pass;
clean-checkout reconstruction is parent-owned. A3 two terrain rebuilds and unrelated
terrain preservation pass; required fresh file load remains parent-owned. A5 actual
two-client initial/reset agreement passes, but actual late join and full P04 orbit
remain incomplete. A6 engine pristine rebuild/teardown and single-client human
regressions pass; P13 final harness teardown and two-client human-settings regression
remain incomplete. Keep P13 incomplete/draft until required gaps are closed.

Bounded evidence: `build/p13-final-studio-reports.json`, `build/p13-focused-review.json`,
`build/p13-external-launch.txt`, `build/p13-spawn-cover-defect.json`,
`build/p13-signature-numeric-defect.json`, host logs and current-progress image.
Original Studio returned to Edit with terrain/camera restored; no further mutations
after handoff to the primary agent.
