# P12 — Reconstructable release and multiplayer acceptance

**Milestone:** M6 / MVP. **Dependencies:** P11. **Requirements:** R01–R16. Status: [roadmap](../roadmap.md).

## Capability and player experience

The verified game runs in a named, explicitly authorized Roblox experience. Players can complete repeated 6- and 10-player matches with both roles, both aircraft weapons/zoom levels, M-7 fire, the single launcher, cover/aircraft destruction, spectating and results. The 720-stud battlefield, terrain, three accessible multi-story buildings, panning and progressive physical panel destruction are required even with simple graphics. Refined assets can follow in dedicated later plans. The README supplies the real play link and accurate availability.

## Implementation

Prepare a clean-checkout release candidate using the release mapping. Record source commit, build hash, tool/dependency pins, asset manifest, actual universe/place IDs and intended audience. Inspect the artifact for test content/development overrides and check asset permissions. Prepare a rollback to a known-good build and a smoke checklist. Only then publish if authorization already exists, or request the remaining destination/access/publication decision with this concrete candidate.

## Acceptance criteria

- **A1:** Full gate passes from a clean checkout. Artifact contents match the committed source and manifest; test dependencies, runners and two-player override are absent. Build hash and source commit are recorded.
- **A2:** Final Studio engine/multiplayer suite passes; every R01–R16 requirement links to actual test/evidence, with no required skipped or zero-count suite.
- **A3:** Exact experience/place/audience and explicit authorization are recorded before publication. Cloud asset permissions are verified for that owner. A published build/version is confirmed by the platform, not inferred from a tool attempt.
- **A4:** Real Roblox-client sessions at 6 and 10 players complete repeated aircraft-destruction, ground-elimination and timeout paths. Verify both roles, cover/destruction, supported late joins, launcher transfer, three-rocket guarantee, inward mouse-panned perimeter camera at both zooms, enlarged terrain and all three multi-story buildings, 3/6-heavy-hit and nine-second 30mm panel progression, half-destroyed openings/physical fragments, weapon-switch timing and terrain/panel/debris reset; record actual participants/client counts without personal data. Same-identity reconnect is excluded under D59; deterministic service tests retain reconnect authority coverage. These 6/10-player checks run in Roblox clients, not Studio.
- **A5:** The 10-player candidate meets the performance/soak budgets in `docs/testing.md`, with logs/metrics and no unresolved material gameplay/replication defects. Studio's smaller simulated-client run is not a substitute.
- **A6:** Player README links to the actual authorized experience and states tested devices/current limitations. Release record identifies rollback steps and the verified candidate. Source and evidence are pushed and a reviewable PR is available.

## Release boundary

[P16/P17's Blender asset and smaller-Outpost refinement](17-integrate-military-outpost.md)
is scheduled before P09 and this plan by D63. Require the approved replacement's
source, complete exports/manifest, actual owner asset access and P17 acceptance
alongside the release checks above. Blender approval alone cannot establish
release readiness.

Missing Roblox destination, access, explicit publishing authorization or ten-client validation leaves this plan incomplete. Finish all local preparation and state precisely what remains; do not publish to an invented place, change audience silently or waive a capacity check. Merge authorization is separate from publication authorization.

## Completion record

Not implemented. Record A1–A6, tested/published source, artifact hash, universe/place/version/link/audience, authorization reference, real session evidence, CI/PR and remaining limitations. This is the MVP completion record.
