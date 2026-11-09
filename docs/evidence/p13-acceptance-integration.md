# P13 acceptance integration on main — 2026-11-08 local / 2026-11-09 UTC

With explicit user authorization to merge and complete the loop,
[PR #16](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/16)
merged into `main` at `de1eb9b3bcf400dc0168067a1e2d9694e26ca22f`.
It integrates the test-startup corrections, diagnostic retention, independent
teardown, native-world probe and passing P13 engine evidence.

## Source and verification

- Reviewed head: `545e6cd62016d7efaf91b2b04d4342f89c6f5976`.
- Reviewed and merged full tree: `2b330414db5c1e2bd89bbf86f9968b41e419dc57`.
  `git diff --exit-code 545e6cd62016d7efaf91b2b04d4342f89c6f5976 de1eb9b3bcf400dc0168067a1e2d9694e26ca22f`
  passes, proving the merge preserves the verified content.
- [GitHub Verify 42544610250](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/42544610250)
  passes on the reviewed final PR head.
- Fresh integrated `python3 scripts/verify.py > build/p13-acceptance-main-verify.txt 2>&1`
  exits zero: **33 unit / 18 integration**, format/lint/strict types, required
  rejection probes, both builds, **351 authored transforms per artifact**,
  **111 panel pivots**, **7,146 building-surface pair checks** and release isolation.
  [Full host log](p13-acceptance/main-integrated-verify.txt),
  [exact source/build manifest](p13-acceptance/main-integration.json).

The unchanged source retains the independent [P13 acceptance evidence](p13-acceptance.md):
fresh native-world load 5/5, expanded-map multiplayer 5/5 with two initial / three
actual peak clients, full 90-second aircraft regression 6/6 and two-client human
controls 4/4. Baselines pass 67 server / 2 per actual client with zero
failures/errors/skips. Those actual engine sessions predate this identical-tree
merge; no new engine or capacity session is claimed here. The native-world load
does not claim a fresh full-place boot. The original Studio document remains the
intended working session; no new document launch is needed for integration.

## Local setup and delivery

Routine setup and probe commands now select updated `main`. Integration prose and
these records are maintained on dedicated branch
`chore/complete-p13-acceptance-integration`; no task edits were made on main.
The existing representative Studio screenshot remains current because visible
gameplay/world source is unchanged.

P13 remains Complete and P14 remains Ready but unimplemented. Acceptance and
integration are both recorded; no combat, panning, destruction, 6/10-player release
acceptance or Roblox publication is claimed by this merge.

Integration documentation passes `python3 scripts/check_repository.py` (62 Markdown / 57 JSON files) and `git diff --check`. The full host gate above ran before these prose/evidence-only changes; runtime, world, tests and build tooling are unchanged.

The dedicated documentation/evidence follow-up is
[PR #17](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/17).
