# Independent manual adapter review

Candidate `ee19deb5fe18090573ce0d9788b0c77555bca333`, tree `4f9798fe52f9bdd83af6a6f1b7dcab87c4727e6a`. This is review of ignored test scaffolding, not executed multiplayer evidence. No managed source was edited.

No blocking defect found in the manual adapter diff. The exact excluded v6 gameplay assertions, native fire thresholds, targeting/ray points and time budgets remain. Changes replace SDK launch/finish transport with an explicit required completion callback and manual session transport, retain ordinary 173-server/10-per-client raw baselines, and add AssetMesh validation to actual mesh loading and each stage/reset snapshot.

The runner requires Studio and the selected P17Manual test-only setting. It does not call SDK launch, GetTestArgs or EndTest. It retains failures/zero discovery, cleanup details and actual client baselines. ServerStorage evidence is bounded at 16 MB, with UTF-8-safe 60,000-byte StringValue chunks and Complete set last; the running manual session stays available for evidence collection and supported Stop.

Installer guards local Edit, zero place/universe, exact original dispatcher Sources, nil ManualHarness and absence of four owned modules before mutation. It records originals before applying the four modules/two dispatchers and has rollback. Restore targets only the owned state and returns Sources/selector/modules. External original entries are saved in `build/p17-manual-original-entries-ee19deb.json`. The primary independently proved `_G` persistence across separate MCP calls during native sync, satisfying the install/restore owner-state capability prerequisite.

Independent Python stdlib checks verified all 13 files in P17ManualPreparation.json, all four installer-embedded module Sources, and both embedded old/new dispatcher Sources against repository/prepared files. Installer SHA-256 `9d3334fc07585b635d5156465b59c6d1b15e06723d3afe5bd02380665a1ca269`; restore SHA-256 `696164d90500ad581c93f004917076d8d2815cd6ace4b0de7760ef4c3fb955c2`.

Required next evidence: supported two-actual-client session, fresh ordinary 173/10/10 reports, full material suite and current regressions. Review does not establish those outcomes.
