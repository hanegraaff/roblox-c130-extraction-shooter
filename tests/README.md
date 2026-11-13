# Test suites

The [testing guide](../docs/testing.md) owns exact commands and report interpretation. Run `python3 scripts/verify.py` for static, deterministic, rejection-probe and artifact gates. Real Studio server/client smoke suites are a separate required run.

| Package | Runtime and responsibility |
| --- | --- |
| [unit](unit/README.md) | Lune: pure finite/payload/config/rate, expanded map/building layout/orbit, roster, phase/outcome and panel-stage rules |
| [integration](integration/README.md) | Lune: actual lifecycle/match, weapon/health/movement and ordered destruction services with controlled boundaries |
| [studio/server](studio/server/README.md) | Studio: automatic server TestEZ runner, three-round lifecycle, two-client aircraft and expanded-map orchestration |
| [studio/specs-server](studio/specs-server/README.md) | Studio: Instance-based imports, bootstrap lifecycle, spawn/building/terrain queries, containment/rebuild, aircraft/solid aim, residual panels and fragment rigid-body checks |
| [studio/client](studio/client/README.md) | Studio: automatic client TestEZ runner and actual-client round/aircraft/camera/profile observations |
| [studio/specs-client](studio/specs-client/README.md) | Studio: replication, avatar and status-panel lifecycle |
| [fixtures](fixtures/README.md) | Server-only deterministic test settings |

Cases state their requirement/criterion and exercise production modules. Unit/integration case modules accept a registration callback and the actual implementation module; the Lune runner and TestEZ server wrapper supply the respective runtime imports. Required empty or failed suites fail rather than disappearing from the report.

All tests, fixtures, TestEZ packages and development settings are excluded from the release mapping and checked against the actual generated artifact. The current suites target foundation, map, round lifecycle, aircraft/view and initial gunship combat behavior. The test-only multiplayer harness uses actual clients for role/deadline/UI replication, death, spectating, departures and three resets. Required Studio execution is separate from host success; see the P03 record for actual outcomes. P04 adds six two-client scenarios spanning a full orbit, profile rejection/coherence, thermal fixtures, resets and departure. See its plan record for actual rendered review and execution evidence. The P05 test-only harness exercises actual gunship fire with two clients; its coverage and execution results are tracked separately in the P05 plan. P06 adds ground rifle and aircraft-health host fixtures and two- and three-client Studio harnesses; the P06 plan records its verified two-/three-client acceptance and integration separately from later release checks. These suites do not establish release capacity.

P13 adds the three-building/terrain source contracts and five-scenario expanded-map harness with two initial clients and a third actual late joiner. Real Humanoid movement exercises the authored entry/stair/upper-floor routes. See [P13](../plans/13-terrain-and-buildings.md) for actual candidate results; the harness definition alone is not evidence that it passed.

P07 adds four pure stage cases, ten ordered accepted-shot ledger cases and five baseline engine cases for all-panel geometry, pre-impact cover rays, actual fragment physics/avatar exclusion and repeated reset. Its separate seven-scenario `DestructionHarness` requires two initial actual clients and a genuinely late third spectator. It uses normal gunship remotes for firing and includes actual opening traversal; rendered thermal and operated readability remain separate acceptance. The [P07 procedure](../docs/testing.md#run-the-p07-destruction-harness) explains SDK/native launch, checkpoints, reports and cleanup. The [plan](../plans/07-destruction.md) owns actual results; the presence of these suites is not evidence they passed.
