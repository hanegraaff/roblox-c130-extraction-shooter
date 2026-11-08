# Server engine specs

The test project maps these specs to `ServerStorage.Tests.Studio`; the automatic server runner discovers both through TestEZ. They are absent from the release mapping.

`Foundation.spec.luau` registers the original ten shared rule cases and two lifecycle cases with actual Instance-loaded modules. It adds repeated bootstrap start/stop ownership and the anchored/collidable GroundSpawn raycast. It temporarily renames the entrypoint status while exercising an independent runtime, then restores it.

`Map.spec.luau` registers four shared MapRules cases plus five engine cases for P02/R01/R05/R10. These first assert loaded disk/spawn/roof transforms, then exercise the real MapService against disposable Workspace clones: invalid disk dimensions; invalid anchors/counts/clearance/elevation; both approaches with a 4×6×4-stud envelope sampled every 0.5 stud and floor rays; permanent/breakable cover IDs and rays, nine protected spawn anchors and eight future perimeter sight lines; authoritative containment/station exception/stop cleanup; and two pristine rebuilds restoring part names, poses and descendant counts after removal/transient content. Fixtures are destroyed even when an assertion fails.

The expected aggregate is 23 server cases. An expected count is not engine evidence: collect the actual structured report, failures/skips/errors, source/build and client count using the [testing guide](../../../docs/testing.md). Route clearance still needs focused actual walking and visual review. These suites do not establish combat, destruction, round reset orchestration or gameplay replication between multiple clients.
