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

The revised P07 suites are under validation for persistent per-panel heavy/30mm credit, distinct Pristine/Light/Heavy/Total appearance, cosmetic query exclusion and the 187 candidate panels across all three formal buildings and the starting shelter. The two-client harness uses three separated 21-request 30mm bursts and actual heavy hits, traversal, replication and resets. D50 removes a real late-join gate from current P07 acceptance without changing runtime spectator authority. The stable candidate passes 55 unit/55 integration cases and a fresh 142-server/six-client solo engine baseline; its seven-scenario two-client harness, new captures and operated results remain pending. Earlier P07 counts and reports stay historical. See the [active procedure](../docs/testing.md#run-the-p07-destruction-harness) and [plan](../plans/07-destruction.md).
