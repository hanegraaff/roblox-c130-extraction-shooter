# P13 terrain and multi-story building acceptance

## Candidate and environment

Date: 2026-11-08. Source `ea9cd4ee567e28d205841b093180cad3d0921110`, tree
`654ce450241698cc00353d9209a07a3e188654f8`, on `plan/13-terrain-and-buildings`.
Base is integrated main `2f509efc3ae9e6657f22536b79b6faa83749d10d`, containing P04
and the MVP steering revision. Product geometry is unchanged since `b157e84`;
the final source commit corrects test-only numeric replication comparisons.

Environment: macOS arm64, Python 3.10.4, pinned tools, Studio 0.746.0.7461269, local
place 0. The existing document `p02-tests-5c809beff70b.rbxlx`, instance
`21f6fc11-4429-4148-9764-89a36987e5e9`, received `test.project.json` through the
existing Rojo server on 127.0.0.1:34872. Its historical filename is not source identity.
The final inventory confirms that sole document in Edit, terrain/camera restored,
with no owned test session running.

## Observed checks

- Independent and primary full `python3 scripts/verify.py` gates pass **33 unit /
  18 integration**, format/lint/strict types, rejection probes, both builds, **351
  authored transforms per artifact**, **111 panel pivots** and isolation of tests
  from 24 release runtime scripts. [Independent log](p13/independent-verify.txt),
  [final current log](p13/final-verify.txt), [source/build manifest](p13/source-manifest.json).
- Clean archived-source builds match SHA-256 release
  `04361780b42e2cf63f9ece356732361b3563dfd5534fe6311edef4f65c47d5d6` and test
  `b78abbab64fb7adb3b6715340eec27e88de806ad8ab2900deb25052360cc8ea2`.
  Existing pinned Wally dependencies were copied into the disposable checkout;
  this is not a fresh dependency-install or engine file-load claim.
  [Exact reconstruction commands/results](p13/clean-reconstruction.json).
- All **58 mapped sources** and **351 loaded parts** match source. Maximum loaded
  CFrame component error is 0.0000142927 against numeric tolerance 0.001.
- Fresh Studio baseline passes **67 server / 2 client**, zero errors/failures/skips,
  one actual client. Building/terrain/navigation/lobby/cleanup cases include two
  terrain rebuilds preserving unrelated terrain, malformed recipe/marker rejection,
  exact geometry/ID restoration and 576 sheltered-spawn rays across 64 phases.
- P13 passes two actual clients' initial geometry/terrain/panel/aircraft agreement,
  a real Humanoid walking into Foundry, Warehouse and Outpost upper floors, and
  agreement after **two perturbed round resets**. Six client observations include
  passing 2/2 baselines. Startup server clientCount=1 is distinct from the harness's
  two actual participants.
- Single-client `HumanTestControls` passes **6/6**, `LobbyControls` **4/4**, zero
  errors/failures/skips. Operated WASD, both launcher routes (eight navigation
  segments), and Hill04 ascent pass. A solo operator preview observes coherent
  35°/60° profiles and an in-bounds reticle over three frames; this does not resolve
  the separate multiplayer failure below.

See [actual structured reports](p13/studio-reports.json), [independent tester report](p13/tester-report.md),
[focused review](p13/focused-review.json), and [mapped-source signatures](p13/source-signatures.json).
The [original terrain sample](p13/terrain-original.json) covers 1,152 voxels / eight
hills, 9,513 canonical bytes, Adler32 **2054186319**. Its [executed probe](p13/terrain-sample.txt)
can compare a future fresh load. Grass/Rock apices lie at 17.0566–18 studs against
nominal Y=16 with three-stud voxel-surface tolerance.

## Findings and remaining acceptance

Resolved findings include spawn-pad contact, continuous doorway sweeps, legitimate
first-tread clearance, missing marker validation, stopped-containment probe coverage,
lobby separation, room bays, terrain collision readiness, terrain aim obstruction
and expanded-map spawn shelter coverage. The [signed-zero diagnosis](p13/signed-zero-diagnosis.json)
found 15 formatted-string differences with zero numeric error in those components;
maximum overall server/client component delta was 0.0000452548. The corrected test
harness uses 0.001 numeric tolerance, exact identities/classes/shapes/flags and
negative probes. Product geometry did not change for this correction.

Required gates remain open:

1. **Late join and final P13 teardown:** `AddPlayers(1)` did not connect a third
   client within 30 seconds. P13 reports **3 passed / 2 failed / 5 discovered**,
   peak **2 actual clients**, zero skipped. Failed entries are late join and harness
   completion; final resource-teardown was not reached. A bounded subsequent
   diagnostic could not launch its initial two-client server because Roblox OAuth
   and experimentation metadata requests timed out. Only owned diagnostic PID22880
   was terminated; original PID73836 was preserved. [Bounded launch facts](p13/external-launch.txt).
   This supports an external launch gap, not a second reproduced AddPlayers failure.
   The two-client human-settings regression remains unrun after that blocker.
2. **Complete P04 regression:** the first two-client profile case failed `reticle
   escaped view bounds`: **0 passed / 2 failed / 2 discovered**. Both client baselines
   and the server baseline pass, but no numeric failure snapshot exists. The full
   90-second orbit and later assertions did not execute. The solo observations
   cannot distinguish a multiplayer viewport race from a product defect. Resume
   numeric diagnosis after reliable multiplayer launch returns.
3. **Fresh serialized place load:** the prepared artifact is
   `build/p13-tests-b78abbab64fb.rbxlx`, with the test SHA-256 above. Automatic approval
   review rejected the proposed separate Studio-process launch before execution,
   citing duplicate-instance/unsaved-work risk. No new process or workaround was
   attempted. An earlier read-only macOS System Events query was denied, and MCP's
   local-asset loader lacks RobloxScript capability. Open the artifact through the
   existing Studio application's File → Open from File, or obtain explicit approval
   for one separate-document launch, then collect source/loaded-transform, fresh
   67/2 baseline and terrain-signature comparisons. Live sync and clean host builds
   do not satisfy this criterion.

## Documentation and delivery

The writer updated 16 player/contributor/package documents. The representative
[actual Studio Edit overview](p13/current-progress.jpg), captured 2026-11-08 at
1886×1080, shows the source-defined map/terrain/buildings and detached lobby.
Terrain was reconstructed from the production recipe for inspection, then prior
owned terrain and camera were restored. It is not the operator gameplay camera or
multiplayer evidence. Focused viewport was 1081×619, graphics quality Automatic;
no performance claim is made. Primitive art, fixed-center framing, no firing,
damage, launcher gameplay or physical fragments remain explicit limitations.

Source is pushed in [draft PR #12](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/12).
[GitHub Verify 42533469132](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/42533469132)
passes on tested source `ea9cd4e`. The [plan criterion mapping](../../plans/13-terrain-and-buildings.md)
records partial and missing evidence; only the [roadmap](../../roadmap.md) owns status.
P13 is not Complete; P14 has not started. No merge or Roblox publication occurred.

## Subsequent building-flicker integration

PR #13 merged into the P13 candidate at `4d329a0c28e33a709321755b89a7a46af2d362b3` with user authorization. [The integration record](building-flicker.md#merge-and-integration--2026-11-08) preserves reviewed-tree equality, fresh host verification and unchanged engine-source coverage. The original `b78abbab64fb` artifact above is historical; current prepared fresh-load artifact is `build/p13-tests-0a374bff6bb1.rbxlx`, SHA-256 `0a374bff6bb144ef5049ec708449ebac4b7f79417c728daa37e01bdc214c6780`. P13's required open checks remain unresolved; this merge does not make P13 Complete.
