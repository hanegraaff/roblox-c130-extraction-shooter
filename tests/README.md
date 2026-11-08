# Test suites

The [testing guide](../docs/testing.md) owns exact commands and report interpretation. Run `python3 scripts/verify.py` for static, deterministic, rejection-probe and artifact gates. Real Studio server/client smoke suites are a separate required run.

| Package | Runtime and responsibility |
| --- | --- |
| [unit](unit/README.md) | Lune: pure finite/payload/config/rate, map/orbit, roster and phase/outcome rules |
| [integration](integration/README.md) | Lune: real lifecycle and MatchService with controlled time/resource boundaries |
| [studio/server](studio/server/README.md) | Studio: automatic server TestEZ runner and three-round multiplayer orchestration |
| [studio/specs-server](studio/specs-server/README.md) | Studio: Instance-based imports, bootstrap lifecycle, spawn/map queries, containment and rebuild |
| [studio/client](studio/client/README.md) | Studio: automatic client TestEZ runner and actual-client round/camera observations |
| [studio/specs-client](studio/specs-client/README.md) | Studio: replication, avatar and status-panel lifecycle |
| [fixtures](fixtures/README.md) | Server-only deterministic test settings |

Cases state their requirement/criterion and exercise production modules. Unit/integration case modules accept a registration callback and the actual implementation module; the Lune runner and TestEZ server wrapper supply the respective runtime imports. Required empty or failed suites fail rather than disappearing from the report.

All tests, fixtures, TestEZ packages and development settings are excluded from the release mapping and checked against the actual generated artifact. The current suites target foundation, map and round lifecycle behavior. The test-only multiplayer harness uses actual clients for role/deadline/UI replication, death, spectating, departures and three resets. Required Studio execution is separate from host success; see the P03 record for actual outcomes. These suites do not establish combat or release capacity.
