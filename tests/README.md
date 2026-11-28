# Test suites

Use the [root walkthrough](../README.md#run-local-automated-tests) for the host and Studio smoke commands. The [testing guide](../docs/testing.md) documents the individual engine scenarios, their selectors and how to read their reports.

| Package | Runtime and responsibility |
| --- | --- |
| [unit](unit/README.md) | Lune: pure finite/payload/config/rate, expanded map/building layout/orbit, roster, phase/outcome and panel-stage rules |
| [integration](integration/README.md) | Lune: actual lifecycle/match, weapon/health/movement and ordered destruction services with controlled boundaries |
| [studio/server](studio/server/README.md) | Studio: automatic server TestEZ runner and scenario orchestration for multiple clients |
| [studio/specs-server](studio/specs-server/README.md) | Studio: native map and asset loads, collision and ray queries, combat, cover and rebuild checks |
| [studio/client](studio/client/README.md) | Studio: automatic client TestEZ runner and observers for replicated state, input, camera and profiling |
| [studio/specs-client](studio/specs-client/README.md) | Studio: avatar and HUD lifecycle, desktop and touch input adapters, thermal presentation and camera checks |
| [studio/support](studio/support/README.md) | Test-only shared fixture version guard and bounded frame/memory reducers |
| [fixtures](fixtures/README.md) | Server-only deterministic test settings |

Cases exercise production modules and state the requirement or behavior they cover. Host unit and integration case modules accept a registration callback and the implementation module. The Lune runner and the TestEZ server wrapper supply the imports for their respective environments. A required suite with zero discovered cases fails.

The verifier inspects the generated release artifact for test runners, fixtures, TestEZ and development overrides. Native smoke exercises Roblox objects and queries. Multiplayer scenarios require actual Studio clients to exercise replication, roles, equipment transfer, cover openings and replay. An operated session checks touch input and visual readability. Live Roblox-client capacity and performance have their own release procedure. [Required test levels](../docs/testing.md#required-test-levels) · [Live acceptance](../docs/release.md#run-the-6--and-10-player-acceptance-sessions)

Use the [harness compatibility table](../docs/testing.md#staged-fixture-compatibility) before running a saved selector. To reproduce an archived check, use the source recorded in its [plan or evidence record](../roadmap.md). Record new counts and observations with the source and the actual clients used.
