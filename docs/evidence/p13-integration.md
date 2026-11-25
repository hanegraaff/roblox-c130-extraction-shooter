# P13 source integration on main — 2026-11-08

With explicit user authorization, [PR #12](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/12)
merged into `main` at `19b70082b69f00f3901359403f39ba51b67a0506`, including the
expanded terrain/building map, building surface-flicker fix and their evidence.
The source is integrated; required P13 engine acceptance remains open.

## Verified source

- Reviewed PR head: `2e3e4d55a8b0e480ae08f637f261a7f3236e777b`.
- Both reviewed and merged trees: `e659c9073870975a9d148a19fbd047c8927bb7b3`.
  `git diff --exit-code` confirms identical full content.
- [GitHub Verify 42536588227](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/42536588227)
  passes on the reviewed head. No review requests or unresolved review threads
  were present at merge.
- A fresh `python3 scripts/verify.py > build/p13-main-integrated-verify.txt 2>&1`
  on the merged source passes **33 unit / 18 integration**, format/lint/strict types,
  required rejection probes, both builds, **351 authored transforms per artifact**,
  **111 panel pivots**, **7,146 building-surface pair checks**, and release isolation.
  [Full log](p13/main-integrated-verify.txt), [source/build manifest](p13/main-integration.json).
- Rebuilt release SHA-256 is
  `ec90c71046a1f9a7434b00848792100a58edc58931ec320c9949009d69372c14`;
  test SHA-256 is
  `0a374bff6bb144ef5049ec708449ebac4b7f79417c728daa37e01bdc214c6780`.
  Both match the previously checked integrated flicker candidate.

Existing [building-flicker engine evidence](building-flicker.md) and the
[source-specific P13 observations](p13-terrain-and-buildings.md) retain their stated
scope. Runtime/assets/tests are unchanged by this integration; no new Studio
session, fresh-file interpretation, multiplayer pass or capacity result is claimed.
The existing representative screenshot remains current because no visible geometry
changed during the merge.

## Setup and outstanding acceptance

Routine local setup now selects `main`, which reconstructs the expanded map and
surface fix. The root guide, contributor guide, roadmap introduction and plan
integration record reflect that destination. The dedicated
`chore/complete-p13-integration` follow-up changes documentation/evidence only.

P13's late-join/final teardown, P04 reticle/full-orbit, two-client human-control and
fresh serialized-place checks remain open. The roadmap keeps P13 Blocked and P14
Planned. The current prepared fresh-load artifact remains
`build/p13-tests-0a374bff6bb1.rbxlx`, matching the test SHA-256 above. The merge
does not waive these checks or mark P13 Complete. No next plan or Roblox publication
was started.
