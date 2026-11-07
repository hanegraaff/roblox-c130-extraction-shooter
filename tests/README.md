# Game test suites

These directories reserve the test boundaries described in [testing.md](../docs/testing.md). No executable gameplay tests exist in the initial scaffold. Plan 01 adds and proves the runners; subsequent plans add named behavior suites.

`unit/` and engine-independent `integration/` run quickly under a standalone Luau runtime. `studio/server/` and `studio/client/` exercise real engine contexts through the test project. `fixtures/` holds deterministic inputs and small maps. The release mapping excludes all tests.

Each suite states purpose and requirement IDs, uses actual implementation modules, and tests observable results. Required tests must not be silently skipped. Keep a failed or unavailable engine test distinct from a passed host-side test.
