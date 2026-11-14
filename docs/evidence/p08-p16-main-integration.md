# P08/P16 stack integration into main

Date: 2026-11-13 (America/New_York). The user's current request to merge the
remaining PR stack authorized integration into `main`. Earlier PRs #35/#36
had merged only into their planning-branch base; this record distinguishes
that checkpoint from the completed main integration.

## Observed merges

| PR | Destination | Merge commit |
| --- | --- | --- |
| [#34](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/34) | `docs/studio-supported-acceptance` | `5bb2d82f8928e46e2df5b16011d0ae01d70927c5` |
| [#33](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/33) | `plan/08-rocket-launcher` | `0eb60d7ef499eb9b7b17fea8f2b0fde90d57b3b9` |
| [#32](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/32) | `main` | `87df925b58ca2cb87d243dfc610702bb48563f0d` |

Every merge used its actual expected head SHA. After each merge, `git fetch
origin` and `git rev-parse <destination>^{tree}` confirmed tree
`bf7338aa50b15df6e1dbef605ff0ea73b965ed49`, exactly equal to combined
candidate `537a2ce1029a2259a6637c440dcd83e972457373`. No conflict resolution,
runtime-source edit or asset reconstruction change was needed. PR #32's draft
dependency was resolved by merging #33 before marking #32 ready and merging it.

## Verification

Before the merges, a fresh full `python3 scripts/verify.py` on candidate
`537a2ce` exited zero on the dedicated `chore/p08-p16-main-integration` branch.
The resulting main tree is identical. The [complete host log](p08-p16-main-integration-host.txt)
records 55/55 unit, 65/65 integration, seven asset suites, 22/22 asset
regression cases and 10/10 manifest cases, with zero ordinary failures/skips.
Format/lint/strict types, required rejection probes, both builds, authored
geometry/reconstruction and release isolation pass. Both builds reconstruct
422 authored Parts; release has 506 Instances / 43 runtime scripts, test 594
Instances. The source registry remains 187 panels.

[GitHub Verify 43546871288](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/43546871288)
also passes on the exact combined candidate. Generated build hashes from the
fresh local gate were:

- `build/game.rbxlx`: `645e5d039f008e7a1fdbe48de6279321452738da47e9ff9a6229f381494ec7f4`.
- `build/tests.rbxlx`: `7ac205426e8f3d29b00ddaff13f831e544e7ddfb3a428e9ebf1c43cae2eb426e`.

The runtime/mapping inputs (`src` Luau, `assets/world`, `assets/models`, both
project files and tool pins) are unchanged from P08 production/UI `ef7826b`;
only package prose/reference images differ under `src`. Source-bound P08
native 11/11 with three initial/peak clients, 156 server / seven per-client
smoke, operated input and regression evidence remain as recorded in
[P08](../../plans/08-rocket-launcher.md). D59's acceptance revision is included;
unsupported actual same-identity reconnect is not claimed as a passing network
test. No new Studio execution is claimed for this tree-equivalent integration.

Approved P16 Blender SHA-256 remains
`4c1c5264020616b1af3b36c9dd37442919b386655149ee207591cd37da041d8c`;
its existing clean Blender/export/29-render and explicit human-approval records
remain source-bound. The exact user-selected `blender_outpost.png` is on main,
SHA-256 `94ebc1333b183fb42c20c24249ff31109053b187255d380915dcafbb13f9165c`.
The actual P08 gameplay capture remains in the README. The earlier rejected
generated image is retained only in the historical showcase record.

## Current availability

Routine setup now selects `main`: it contains the recoverable launcher,
supported-Studio acceptance revision, approved Blender asset kit and selected
README image. The outpost assets remain outside runtime mappings; P17 must
still import and validate them in the existing battlefield. P08/P16 remain
Complete, P17 remains Ready/unstarted and P09 waits for P17. No next plan or
Roblox publication was started.

This closeout updates prose/evidence on the dedicated integration branch.
Subsequent documentation gets the repository checker/diff checks; the tested
runtime, approved assets and validation behavior remain unchanged.
