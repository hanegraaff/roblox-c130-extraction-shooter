# P08 independent verification — 07e77ea

Delivered candidate harness: 07e77ea5b57fba359ab611ea39e2c42c7b977881; tree 032f7b162bcc8bba6e48c002b2ca0da30939b444.
Production runtime/UI: ef7826bc80310c17be4bcde93fe7607620303289; tree db1f4e50296a2620d13e36839525c7562220a629.
Observed Git HEAD at test collection: c3b155d6a34f79fc8ae0360d37267aed7a392fbb, tree ab80a42deff1965ca485386dc2d77aa6ea8ac969 (documentation only after harness candidate).
No tester source, test, asset, documentation, roadmap or commit changes. Reports/disposable probes only under ignored build/. Parent subsequently copied report evidence into docs.

## Prioritized remaining findings

1. MATERIAL VALIDATION GAP — P08 A5 / R13, reconnect cannot restore carried launcher or active life.
   Reproduction needed: in one continuing actual multiplayer round, disconnect a live carrier and rejoin the SAME identity; verify elimination/spectator tombstone, no carried launcher restoration, no active actions, and living teammate keeps recovered identity/readiness.
   Expected: same identity cannot regain active life or launcher.
   Observed: actual three-client carrier Kick and teammate recovery pass; pure/service tombstone checks pass. Actual same-identity reconnect was NOT performed. Current StudioTestService AddPlayers accepts a count and offers no same-identity reconnect operation; a new simulated Player is not proof.
   Evidence: final report actualReconnectVerified=false, requiredUnverified A5 actual same-identity reconnect.
   Required action: run this exact scenario using an actual same-account rejoin path/private test environment and preserve server/client identities and snapshots. Do not waive under P07 D50 or mark P08 complete.
2. No unresolved reproducible production defect found in the exercised candidate. Earlier raw character destruction, desktop inventory/readiness overlap, phone hotbar overlap and distinct ScreenGui-origin overlap were reproduced, fixed, and rechecked. Historical failures remain failures in earlier evidence.

## Current gates and actual engine results

Primary final command python3 scripts/verify.py on 07e77ea: exit0, 55 unit / 65 integration, all static/build/geometry/type/probe/isolation gates pass. Logs build/p08-primary-host-harness-followup.txt and docs/evidence/p08/host-07e77ea.txt. This primary run counts for current source because no runtime/test changes followed; tester independently inspected harness-only diff and confirmed synced source. Prior tester full verify on 75b1e88 also passed 55/65; later production changes were UI only and had fresh primary full gates and independent Studio checks.

Studio 0.747.0.7471481, local tests.rbxlx placeId0, test.project.json Rojo port34872. Existing original document e45b78d9-003f-45ad-b35e-00e5a5ed494a reused.
Final invocation: trusted test-only ManualHarness=P08 armed in original Edit; user started native Server & Clients with3; actual Server a928a0af-a7cf-415c-a9eb-80c880e985b5, SDK args=nil, native/manual-server-clients route. One Operator and two Ground actual Players, UserIds -1,-2,-3. No competing Studio owner.

Exact synced signatures bytes/Adler32:
- LauncherHarness 35814 /3441968132.
- GroundCombatController 27198 /135501963.
- RoundPanel 12118 /2584866562.
- LauncherRuntime 18750 /3629527672.
- CharacterOwner 8749 /1462459928.

Fresh automatic suites: 156/156 server; 7/7 on EACH of all three actual clients, collected before intentional Kick; zero failed/errors/skips. Initial/peak/clientCount3; final/current2 after server-kick.
Final P08 harness: 11 discovered,11 passed,0 failed/skipped. Full115010-byte JSON saved;150 trace records retained,0 dropped (192 cap). Cases:
- A1/A5 initial single launcher and M7-only loadouts.
- A2 malformed/wrong-role/stale/flood/impossible-travel rejection.
- A1/A2 actual raced pickup, one owner, carrier retains M7.
- A3 actual miss/drop/transfer/switch/early-fire exact reload continuity.
- A3/A4 actual carrier death preserves nonterminal in-flight direct rocket.
- A3 actual raw character removal during reload, one recoverable identity/no respawn.
- A6 real round reset, anchor replacement and delayed old-round intent rejection.
- A4 actual fired pristine three-rocket health200,100,0/Ground AircraftDestroyed result.
- A4 actual earlier21 rifle hits produce195 health, rockets95 then0/Results.
- A3/A5 actual carrier Kick, surviving teammate recovery and replicated state agreement.
- A6 teardown invalidates callbacks/removes owned resources.

Fresh trace inspection:
Moving-direct target age at derived acceptance ranged0.033848–0.283879seconds; post-transfer death shot rocket:1:2 age0.033848seconds. Before death: health300, shooterAlive/Humanoid100, two flights. After actual Humanoid0 and lifecycle processing: shooterEliminated, same launcherAvailable/exact readyAt1794608272.343909, phaseActive, two flights still present; matching rocket:1:2 aircraftHit=true then health200. The other flight is the prior intentional miss; do not confuse total flight count with number of direct shots.
Observed pristine health300→200→100→0/Results and mixed rifle300→195→rocket95→0/Results; health progression is in trace, final ground result is asserted by passing real harness case.

## A1–A6 outcome

A1, A2, A3, A4, A6 verified by combined host, fresh actual Instances/sweeps, final three-client harness and relevant operated review.
A5 three-client acquisition/death/disconnect/recovery/replication portion verified. Actual same-identity reconnect remains OPEN. Thus full plan acceptance remains incomplete.

## Source-bound affected regressions and focused review

On unchanged authority/input core75b1e88, separate fresh actual two-client SDK suites passed P06 10/10, P05 8/8, P14 6/6 (both90second orbit scenarios). Server156 in each; P05/P14 both client7 explicitly captured. P06 strict client transport baseline asserted by runner, individual client JSON not separately captured before self-ending. Files build/p08-p06-regression-75b1e88.json, build/p08-p05-regression-75b1e88.json, build/p08-p14-regression-75b1e88-summary.json and -raw.json. Subsequent production changes only Ground HUD/RoundPanel layout; harness-only07 changes no production.
Fresh solo ef7826b156/7 and ordinary SDK2 ef156/7each pass.
Actual ef phone750x381,568x320 plus stricter567x299 at58pixel GUI inset: measured native inventory/jump/thumbstick/topRoundHUD/reticle clearance, fitting text, zero outside-safe controls and drawn-reticle error0px. Native touch M7/ROCKET/DROP/PICKUP/FIRE/RELOAD work, exact rocket deadline preserved and early fire denied; rifle25→30 reserve120→115. Evidence build/p08-final-phone-review-ef7826b.json.
Desktop natural D walking and actual Humanoid traversal of both authored approaches passed; native E race,1/2,G/fire/reload worked; ownership/ready/ammo readable. Actual desktop/inventory bounds checked numerically because screen_capture omits CoreGui.
Representative current capture build/p08-current-held-ef7826b.jpg uses natural walking/default camera; test-only Studio panel hidden/restored. Touch screenshots build/p08-phone-750-ef7826b.jpg and -567x299-ef7826b.jpg.
Confirmed HIT readability used a disclosed client-only GroundShot presentation fixture, restored afterward. It did not damage aircraft. Two bounded native M7 QA-camera attempts missed; server health stayed300. Full final harness independently proves actual fired damage. Temporary camera/input observers removed.
Subjective: launcher ownership and reload status are legible at tested landscape sizes; primitive model/art and compact phone text remain the current stage. No broader balance/latency/full5–9ground usability claim is made.

## Evidence and cleanup

Current:
- build/p08-native-07e77ea-pass.json: all fresh baseline metadata, source identity, full report.
- build/p08-native-07e77ea-raw.json: exact full115010-byte native report.
- build/p08-native-07e77ea-summary.json: selected diagnostic traces and cleanup.
- build/p08-native-07e77ea-console.txt: actual server console/smoke output.
- build/p08-independent-final-07e77ea.md: this report.

Historical failures retained: initial SDK3 only2clients, staged SDK2+AddPlayers1 only2, initial GUI/rawDestroy defects;273611f fixture avatar isolation failure;75b phone/native slot overlap;0cd separate-origin overlap;ef native harness stale lead failure5/7 with2failed. These are not counted as passing current results.

After report capture actual native Server StudioTestService:EndTest({reason='P08 07e77ea native three-client report preserved; tester cleanup'}) closed children. List confirmed only original e45b Edit. Removed own ManualHarness=P08 marker; verified nil, RunService:IsRunning=false, ReplicatedStorage.BootstrapStatus absent. StudioDeviceSimulatorService getters confirm default/LandscapeLeft. Studio reset to default viewport. No owned active session or fixture remains. Studio mutation ownership returned to primary.
