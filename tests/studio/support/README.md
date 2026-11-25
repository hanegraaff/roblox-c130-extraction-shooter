# Shared Studio test support

These modules are mapped to ReplicatedStorage only by `test.project.json` and excluded from release artifacts. They provide no gameplay authority, remotes or runtime ownership.

| API | Contract |
| --- | --- |
| `HarnessCompatibility.reason(kind)` | Returns a descriptive reason for an archived pre-P18 selector, otherwise nil. Pure and nonyielding; no state mutation. |
| `HarnessCompatibility.assertCurrent(kind)` | Raises before an incompatible coordinator allocates runtime/listeners. Rejection is failed/unavailable validation, never a passing or skipped gameplay result. Reproduce historical evidence from its recorded Git revision. |
| `P11Metrics.frames()` | Creates an independent bounded frame histogram. `record(seconds)` counts positive finite samples and separately counts invalid/overflow values. `summary()` returns counts and upward-rounded nearest-rank p95 in milliseconds; an over-250-ms p95 is absent and cannot pass a budget. |
| `P11Metrics.retainedMemory(samples)` | Accepts 3–32 positive finite engine-reported MB observations at equivalent reset points, returning growth percent and monotonic-growth status; invalid input returns nil. |

Current rebalancing acceptance uses P18 with three actual clients and adapted P05 with two, plus ordinary smoke and focused operated checks. Archiving the old P11 local coordinator does not waive the pending live P12 capacity, performance or release gates. [Testing procedures](../../../docs/testing.md#staged-fixture-compatibility)
