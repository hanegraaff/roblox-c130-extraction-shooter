# P06 main integration

With the user's authorization to merge the PR and complete the loop,
[PR #27](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/27)
merged into `main` as `1d71c63a4d8daea5d3f1526f3e02e6be6de6d2c6`.
Its tree `27f09a58fcae8955ffb37259f3216c1ffbb295df` is identical to final
reviewed head `dce058d8da5c088491f93bdd97c8688cda9cada9`, which passed
[GitHub Verify 43344198328](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/43344198328).
`git diff --exit-code` between those commits reported no differences.

Before editing integration documentation, a fresh complete
`python3 scripts/verify.py` on that merged commit passed 50 unit and 43
integration tests, formatting, lint, strict analysis, both builds, authored
geometry and release isolation. Deliberately failing/empty suites, invalid
types and artifact corruptions were rejected as expected. The [structured
host report](p06-integration-host.json) records the source/environment and
build hashes; the [complete gate log](p06-integration-host.log) preserves
commands and output.

The exact tree preserves the [final independent P06 review](p06-final-review.md):
fresh native two-client P06 10/10, 118 server and 6 per-client smoke; controlled
three-client P06Team 7/7; current P05 8/8 and full P14 6/6; accepted desktop
aim/tracer/damage feedback and simulated-phone controls. The three-client
result retains its controlled-restart qualification and original failed run.
No extra Studio run is claimed for this documentation-only integration update.
The actual current README capture remains representative of this unchanged code.

Routine setup now selects `main`. P06's completed acceptance is unchanged;
P07 remains the next eligible increment and has not been implemented. The map
launcher is still P08 work, and production capacity/release checks remain later
work. No Roblox experience was published.
