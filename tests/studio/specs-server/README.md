# Server engine specs

`Foundation.spec.luau` is mapped to `ServerStorage.Tests.Studio` only by the test project. The automatic server runner loads it through TestEZ.

It registers the shared unit/lifecycle cases with actual Instance-loaded production modules, then checks repeated bootstrap start/stop ownership and the authored anchored/collidable SpawnLocation using a real Workspace raycast. It temporarily renames the entrypoint status while exercising an independent runtime, then restores it. This is isolated test code, not a gameplay reset implementation.

The suite covers the P01 foundation portions of R01/R13/R15. Future gameplay raycast, collision, lifecycle and replication cases belong in focused suites when those features exist. See the [testing guide](../../../docs/testing.md) for execution and evidence limits.
