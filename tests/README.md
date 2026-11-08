# Foundation test suites

The [testing guide](../docs/testing.md) owns exact commands and report interpretation. Run `python3 scripts/verify.py` for static, deterministic, rejection-probe and artifact gates. Real Studio server/client smoke suites are a separate required run.

| Package | Runtime and responsibility |
| --- | --- |
| [unit](unit/README.md) | Lune: pure finite/payload/config/rate rules |
| [integration](integration/README.md) | Lune: real lifecycle composition with controlled resource boundaries |
| [studio/server](studio/server/README.md) | Studio: automatic server TestEZ runner |
| [studio/specs-server](studio/specs-server/README.md) | Studio: Instance-based imports, bootstrap lifecycle and spawn raycast |
| [studio/client](studio/client/README.md) | Studio: automatic client TestEZ runner |
| [studio/specs-client](studio/specs-client/README.md) | Studio: replication, avatar and status-panel lifecycle |
| [fixtures](fixtures/README.md) | Server-only deterministic test settings |

Cases state their requirement/criterion and exercise production modules. Unit/integration case modules accept a registration callback and the actual implementation module; the Lune runner and TestEZ server wrapper supply the respective runtime imports. Required empty or failed suites fail rather than disappearing from the report.

All tests, fixtures, TestEZ packages and development settings are excluded from the release mapping and checked against the actual generated artifact. The current smoke verifies the development shell; it does not establish gameplay or multiplayer capacity.
