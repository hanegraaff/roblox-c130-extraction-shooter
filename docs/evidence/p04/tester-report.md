# Independent P04 verification

2026-11-08, macOS arm64, pinned repository tools, Roblox Studio 0.746.0.7461269. Full orbit/network acceptance ran on source `33e7b1da953809c57a42bf4c47166eaca917d753`, tree `f3b5db0a210617104e64519c63e4e95bfd42ef9f`. Final focused presentation/renderer acceptance ran on `b27f738e84c2f87eb25ff402c235b7a91ad82458`, tree `13617b93d55381683ebbdaae027b08e7c32cbae9`. The latter changes only two presentation strings and module comments; core logic/model/tests/harness are unchanged.

Used existing local test document `p02-tests-5c809beff70b.rbxlx`, place 0, original instance `21f6fc11-4429-4148-9764-89a36987e5e9`, Rojo test.project.json on 127.0.0.1:34872. Before both runs, all 51 mapped first-party sources matched local byte counts and Adler32, zero mismatches. The old document filename is not candidate identity. Original/final signatures and sync results are in build/p04-orbit-source-signatures.json, p04-orbit-source-sync-result.json, p04-final-source-signatures.json and p04-final-source-sync-result.json.

## Commands and observed results

- Independent `python3 scripts/verify.py > build/p04-independent-verify.txt 2>&1`: passes 30 unit / 18 integration, zero failures/skips, all repository/format/lint/strict-type gates, intentional failing/empty/type probes, both builds, 128 authored part geometry checks per artifact, five corruption rejection probes and release isolation. Release contains 21 runtime scripts. Intentional disposable rejection probes are expected failures, not production-suite failures.
- Independent `$HOME/.rokit/bin/lune run build/p04-adversarial.luau`: 5/5 disposable probes pass on actual rule/service modules. Translated/elevated map and forward tangent; extreme finite times; FOV/config boundaries; cyclic, 10,000-key and 100,000-character malformed selection requests with unchanged authority; forced same-ID profile reset and fresh sequence.
- MCP Edit task `StudioTestService:ExecuteMultiplayerTestAsync(2,{kind='P04'})`: 6/6 named scenarios pass, no failures/skips, two actual network clients and two rounds. Fresh baseline is 57/57 server, 2/2 on each actual client, zero errors/failures/skips. Server baseline started with one connected client; separate P04 harness waited for two. The complete returned sanitized report is build/p04-studio-report.json.
- Nine paired client samples span a full real 90-second production orbit. Maximum observed pose difference is 0.4237336218357086 studs against declared 8-stud convergence bound. These comparisons include movement between the server snapshot and sequential client response; they are not direct latency measurements. Both clients assert perimeter/altitude/tangent; operator additionally asserts inward Scriptable camera at canonical origin. No local smoothing shell or second gameplay pose exists.
- Final b27f738e fresh ordinary Play passes 57/57 server and 2/2 client, zero errors/failures/skips, one actual client. Actual testing-panel clicks enter Operator preview. Actual keyboard 2/1 and both named GUI buttons select M102/60 degrees and GAU23/35 degrees; selection, caption, FOV and reticle remain coherent, central inward dot measured 1 within 1.2e-7 float error.
- Independent real rendering fixture has one exposed body and one body enclosed by solid walls/roof. Both receive Occluded highlights. Actual rays first hit exposed body / WallS respectively; capture p04-thermal-occlusion.jpg shows exposed white and no covered-body highlight through the enclosure. Removing that same cover changes first hit to the covered body; p04-thermal-cover-removed.jpg shows both bodies white. These are temporary validation fixtures, removed before stopping, not authored gameplay assets or combat/destruction evidence.
- Actual Role button back to Ground restores Custom, 70-degree FOV, Default MouseBehavior, visible mouse icon, zero highlights, no ThermalHUD and no OperatorThermal effect. Reentry and singleton ownership are separately asserted in multiplayer. Client listener disconnection is source-inspected; server aircraft teardown reports zero owned connections and destroys aircraft/state after actual operator departure.
- Primary reports final `python3 scripts/verify.py > build/p04-final-verify.txt 2>&1` passes on b27f738e after final source/prose/capture changes; tester did not duplicate that exact gate.

## Criterion mapping

| Criterion | Actual evidence | Outcome |
| --- | --- | --- |
| A1 / R05,R15 | Full host gate; 6 AircraftRules unit cases and 5 independent adversarial probes | Pass |
| A2 / R05 | Engine Aircraft.spec samples 17 full-orbit canonical poses, tangent/muzzles/reset; real 90-second multiplayer camera/orbit assertions; initial-view reset | Pass |
| A3 / R05 | Two real clients, nine paired full-orbit samples, max 0.4237336218357086 studs versus 8-stud bound; no smoothing shell | Pass |
| A4 / R06,R12 | Ordered distinct finite FOV unit coverage; actual authorized selection, wrong-role/stale/replayed/unknown/malformed rejection and subsequent valid traffic; profile/HUD/reticle checks; actual keyboard/buttons on final source | Pass |
| A5 / R06,R12 | Engine bounds/nonfinite/solid-ray aim rejection; actual exposed/covered Occluded effects and rendered before/after cover fixtures; role reset, singleton reentry, actual departure and teardown | Pass |

## Findings and resolution

1. P2, R12: stable candidate's StatusPanel incorrectly stated aircraft was planned while an aircraft/thermal controller was active. Reproduced in p04-operator-narrow-automated.jpg. Corrected in b27f738e; final fresh Play and p04-current-progress.jpg show current availability accurately. No material finding remains open.
2. Pre-acceptance harness review requested actual singleton GUI/effect/highlight assertions and restoration of captured MouseBehavior/icon/FOV, rather than counting operator roles alone. Developer tightened these before frozen 33e7b1d acceptance; all checks passed.

## Focused observations and limits

Multiplayer viewport was 1081x658, graphics Automatic; final ordinary Play viewport 1081x619, Automatic. Both magnifications are understandable, the reticle remains stable within the fixed inward view, and exposed thermal bodies are legible. Representative p04-current-progress.jpg is the actual final Operator solo preview with chat hidden only in that client and no disposable target fixture. It is not multiplayer evidence.

At 60 degrees an opaque piece of the local aircraft appears in the upper-left sky. Across observed orbit phases it did not obscure the central battlefield or reticle; p04-operator-wide-orbit.jpg preserves it. The central round card covers part of the upper battlefield, and the test-only human panel overlaps portions of the thermal controls at the smaller viewport. The remaining controls and central/lower aiming area are usable. These are presentation limitations for later polish, not failed core P04 criteria.

Ground-level rendering inspection at (0,8,0) confirms the actual replicated primitive aircraft silhouette is visible against the sky (p04-ground-aircraft-inspection.jpg). The camera was temporarily bound to look at the aircraft and HUD temporarily hidden for this controlled inspection; it is not a normal-camera framing claim. The binding was removed and HUD restored before Stop. No source/asset was changed for these temporary observations.

Fresh multiplayer server Output contains all 57 baseline passes and a pre-existing avatar asset warning for rbxassetid://203785492 (asset type mismatch). No first-party runtime failure appeared. This is local Studio evidence, not cloud publication, 6/10-player capacity, firing/damage, balance or performance acceptance.

Every launched session ended. Final inventory is only the original confirmed Studio document in Edit. Temporary fixtures and inspection bindings were removed; no additional Studio process was launched. Source remains unchanged after b27f738e apart from primary/writer prose/evidence. Studio mutation ownership returned to primary.
