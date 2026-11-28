# P32 — Compare balance across team sizes

**Depends on** MVP completion and testers for 2-, 6- and 10-player matches. **Requirements** R25, R28, R29. [Roadmap](../roadmap.md#after-mvp-completion) · [Requirements](../requirements.md)

The owner has limited testers for this MVP. Revisit balance in a future iteration when testers can rotate through both roles at each roster size. Use the MVP candidate’s recorded settings as the baseline.

## Work

- With the baseline preset loaded and the single-use kits in play, run private matches with small, middle and full rosters. Rotate the operator and include desktop and touch players. Record roster, device, preset revision, winner, duration, time to first launcher, kit use and whether each team had a chance to act.
- Change one group of settings at a time in the admin panel. Replay a comparable matchup before accepting a change. Look for specific problems such as short-handed Ground teams never reaching cover or full teams destroying the aircraft before the operator can respond.

## Acceptance

1. **A1 · Paired trials.** Record repeated matches at 2, 6 and 10 players with both roles represented by different testers. Summarize observed outcomes and feedback by roster, including losses. Report sample counts alongside any win percentages.
2. **A2 · Reproducible preset.** Record the selected numeric settings and rationale, demonstrate that both roles have a playable route to victory, and verify restoring the preset reproduces the same health, cooldown, panel and kit values. Identify the candidate that uses the selected revision so a later test can reproduce it.

Run the applicable [project checks](../docs/testing.md) and record the source revision, environment and observed results for each criterion.

## Documentation

Document how to repeat a balance trial and restore the selected preset. Keep participant identities out of the evidence.

## Completion record

Planned checks have no results yet.
