# Studio-supported acceptance revision — 2026-11-13

The user requested: “remove anything from the accpetance criteria that roblox
studio does not support. there is no point in keeping it”. D59 records the
resulting scope change, rather than claiming previously missing evidence passed.

The dedicated `docs/studio-supported-acceptance` branch starts at P08 delivery
`532968e8fd015bbc33fa02d982642155c940b91c`. Its review PR targets the unmerged
`plan/08-rocket-launcher` dependency ([PR #32](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/32)).
GitHub integration and Roblox publication remain separate.

| Reviewed scenario | Revised acceptance |
| --- | --- |
| Actual same-identity disconnect/rejoin | Removed from real-session acceptance in P08 and future plans. Current Studio helpers add/remove clients but cannot reconnect the departed identity |
| No restored active life, equipment or authority on rejoin | Runtime contract retained; MatchService and LauncherService deterministic service tests remain required |
| Late join | Supported by AddPlayers; retain applicable Studio gates. Prior P03/P13 evidence includes actual added clients. D50's older P07-specific scope stays historical |
| One operator/two ground clients | Supported native Server & Clients session; retain P08's three-actual-client gate |
| 6/10-player release sessions | Retain explicit Roblox-client P12 gates in their required environment; these are not Studio requirements |
| Startup/access failures or skipped supported checks | Still failures/incomplete evidence; temporary unavailability does not remove a supported operation |

Only test-report metadata changes: future LauncherHarness reports retain
`actualReconnectVerified=false`, list reconnect in informational
`unsupportedChecks`, and leave `requiredUnverified` empty. Production source,
eleven gameplay assertions and deterministic rejoin tests are unchanged.
Historical raw reports, failed runs and the independent pre-revision report
retain their original reconnect gap and are not rewritten.

The revised A5 is satisfied by the preserved native `07e77ea` run against
production/UI `ef7826b`: 11/11 cases, zero failures/skips, three actual
initial/peak clients, 156/156 server smoke and 7/7 on each actual client.
Other criteria retain their named host/engine/operated evidence in the
[P08 completion record](../../../plans/08-rocket-launcher.md) and
[verification ledger](../p08-launcher.md). No new engine execution is claimed
for this scope-only revision. The current actual README screenshot remains
representative because gameplay is unchanged.

`python3 scripts/verify.py` passes on this revision: 55 unit / 65 integration,
zero failures, plus format/lint/strict-type, repository, corruption probes,
release/test builds, authored geometry reconstruction (422 transforms each)
and release isolation (43 runtime scripts). The host log is
[studio-acceptance-host.txt](studio-acceptance-host.txt). Engine evidence above
is reused only for unchanged production code and gameplay assertions.

`git diff --check` passes. No production files or historical raw reports change.
The only Luau change is the excluded harness report schema/metadata. P08's
revised criteria are satisfied; P09 is Ready and unstarted in the roadmap.
