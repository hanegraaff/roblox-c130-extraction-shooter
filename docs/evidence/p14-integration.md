# P14 main integration — 2026-11-12

The user authorized merging all open PRs and completing the loop. The P14
stack was merged into `main` in dependency order using merge commits:

| PR | Integrated change | Main merge commit |
| --- | --- | --- |
| [#18](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/18) | P14 targeting and surface-aware projection | `d28c6ebc9fb8b905d7e5e7ea63733ef067767629` |
| [#19](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/19) | WASD/mobile controls and future-level contract | `bd467211db362ff907556362a988f9c6c1a8926a` |
| [#20](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/20) | Plane-relative orbit framing | `2f069ace73437d5409593da03ed026bbd5d6c1c4` |
| [#21](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/21) | Visible level edges and visual backdrop | `8eb940afbd3ae2785537f9dd4ba67cb4af466793` |
| [#22](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/22) | Correct left/right and mobile aim, complete acceptance | `169cecd6f10f82569526c57d5c1aa30c178e3ffe` |

The P14 game stack at main merge commit
`169cecd6f10f82569526c57d5c1aa30c178e3ffe` has tree
`00499790b5707dbf4a4f9e4a69ee3efed60fd980`, identical to the verified PR #22 head
`50236e687a87ef9ae21952250d1befabc75d663f`. That head passed
[GitHub Verify 43273342746](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/43273342746).
The independently reviewed real-engine results remain applicable to the
identical integrated tree: P14 6/6, P04 6/6 and human controls 4/4 with two
actual clients; desktop/mobile full-orbit and multi-touch review; both target
cover comparisons; and actual 1280×720 / 1920×1080 layouts. Source revisions,
reports, captures and earlier fixture failures are in the
[P14 acceptance record](p14-horizontal-acceptance.md).

On the freshly fetched integrated tree,
`python3 scripts/verify.py > build/p14-main-integration-verify.txt 2>&1`
passed **50 unit / 18 integration**, format, lint, strict types, rejection
probes, both Rojo builds, 351 transforms per artifact, 7,146 surface-pair
checks and release isolation. The intentional corruption/rejection probes in
the [full log](p14-integration/host-verify.txt) include expected failing child
test output; the overall verification exited zero. No Studio test is implied
by that host command; the engine evidence is linked above.

The [documentation follow-up PR #23](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/23)
merged at `4e43fe64155ad6db2c43c57f7fe1ce8371fd8e18` and updated routine setup
to `main` without changing game or test source. P14 remains Complete; P05 is
Ready and has not been implemented. No Roblox experience was published.
