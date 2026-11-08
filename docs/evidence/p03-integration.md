# P03 and human-testing integration

2026-11-08. The user explicitly authorized merging both PRs and completing delivery.

- [P03 PR #6](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/6)
  merged into `main` at `031c7dc1735b3ed6f0f8a2ed49a8d042576e23cc`.
- [Human-testing PR #7](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/7)
  was retargeted from the P03 branch to `main`, then merged at
  `6cf0f1ee29e4c122f2d7d68164a2d93ff2408238`.
- Both expected heads had successful GitHub Verify runs and no review submissions
  or unresolved review threads. Merges used expected-head SHA guards. Their passing
  runs were [P03 42518744632](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/42518744632)
  and [human controls 42523565922](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/42523565922).

The [structured integration record](p03-integration.json) identifies the merged
source, exact Git tree and artifact hashes. Integrated `main` has the identical
tree `f38d438c1153ee3bc8783f4e13a7914264967607` as checked PR #7 head `939e890`:
`git diff --stat 939e890 6cf0f1e` is empty. No runtime, test, asset or configuration
change was introduced by integration.

`python3 scripts/verify.py > build/p03-integrated-verify.log 2>&1` passes on that
integrated source in macOS arm64: 24 unit / 14 integration cases, zero failures
or skips; formatting, lint, strict types, deliberate rejection probes, both builds,
112 authored part checks per artifact, corruption probes and release isolation all
pass. The [complete bounded log](p03-integrated-verify.txt) records the commands.
Both generated build hashes match the previously engine-tested human-control
candidate. Existing [P03 engine evidence](p03-rounds-and-roles.md) and
[human-control engine evidence](lobby-preview.md) remain attributable to identical
runtime/test source. No new Studio execution is implied by the host gate.

Integration records and the README are updated on the dedicated
`chore/complete-p03-integration` branch. Routine source selection now uses `main`.
The current representative screenshot remains valid because visible code is
unchanged. The original Rojo-connected test document was confirmed in Edit;
no Studio process, document or player window was launched for this integration.

P04 has not been implemented. Both prerequisites and
the human-testing controls are now on `main`. No Roblox publication occurred.
