# P35 — Verify and open the public MVP

**Depends on** P32–P34. **Requirements** R14, R25–R31. [Roadmap](../roadmap.md#public-mvp-launch) · [Requirements](../requirements.md)

Release the tested candidate to the named Roblox audience and verify that new players can join and finish a match.

## Work

- Follow the [release runbook](../docs/release.md). Pin the build, place ID, asset permissions and launch preset. Prepare a rollback for the place, listing and balance revision. Use a named, authorized private audience for preflight and the owner’s explicit authorization for the public switch.
- Test the release artifact with ordinary accounts and actual Roblox clients. Check platform access, asset loading, panel restrictions, both roles, mobile controls, kits and replay. Record the prior version and exact launch candidate.
- Apply the reviewed listing and audience, smoke-test a fresh public join and a complete match, verify the listing on desktop and phone, and update the root guide with the verified play link and limitations.

## Acceptance

1. **A1 · Private qualification.** Run the complete release preparation gate. In real 6- and 10-player sessions exercise aircraft destruction, Ground elimination and timeout, with resets. Use the actual launch preset for expected damage, durability and healing.
2. **A2 · Performance.** Meet the runbook’s two-role frame-time, server, latency/convergence and 30-minute memory/replay gates on the named candidate. Record counts, devices, measurements and resolution of failures.
3. **A3 · Public launch.** Record the approved destination, public place version, enabled devices, listing and preset revision. Verify a fresh account can discover or open the page, join and play. Verify a trusted tester can access the panel and an ordinary player cannot change settings. Record the observed result and rollback outcome if needed.

Run the applicable [project checks](../docs/testing.md) and record the source revision, environment and observed results for each criterion.

## Documentation

Update the release record and current availability only after observing the public experience.

## Completion record

Planned checks have no results yet.
