# Test suites

The [testing guide](../docs/testing.md) owns exact commands and report interpretation. Run `python3 scripts/verify.py` for static, deterministic, rejection-probe and artifact gates. Real Studio server/client smoke suites are a separate required run.

| Package | Runtime and responsibility |
| --- | --- |
| [unit](unit/README.md) | Lune: pure finite/payload/config/rate, map/orbit, roster and phase/outcome rules |
| [integration](integration/README.md) | Lune: real lifecycle, MatchService and AircraftSelection with controlled time/resource boundaries |
| [studio/server](studio/server/README.md) | Studio: automatic server TestEZ runner, three-round lifecycle and two-client aircraft orchestration |
| [studio/specs-server](studio/specs-server/README.md) | Studio: Instance-based imports, bootstrap lifecycle, spawn/map queries, containment/rebuild and canonical aircraft/solid aim checks |
| [studio/client](studio/client/README.md) | Studio: automatic client TestEZ runner and actual-client round/aircraft/camera/profile observations |
| [studio/specs-client](studio/specs-client/README.md) | Studio: replication, avatar and status-panel lifecycle |
| [fixtures](fixtures/README.md) | Server-only deterministic test settings |

Cases state their requirement/criterion and exercise production modules. Unit/integration case modules accept a registration callback and the actual implementation module; the Lune runner and TestEZ server wrapper supply the respective runtime imports. Required empty or failed suites fail rather than disappearing from the report.

All tests, fixtures, TestEZ packages and development settings are excluded from the release mapping and checked against the actual generated artifact. The current suites target foundation, map, round lifecycle and aircraft/view behavior. The test-only multiplayer harness uses actual clients for role/deadline/UI replication, death, spectating, departures and three resets. Required Studio execution is separate from host success; see the P03 record for actual outcomes. P04 adds six two-client scenarios spanning a full orbit, profile rejection/coherence, thermal fixtures, resets and departure. See its plan record for actual rendered review and execution evidence. These suites do not establish combat or release capacity.
