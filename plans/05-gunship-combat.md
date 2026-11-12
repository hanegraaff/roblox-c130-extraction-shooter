# P05 — 30mm and 105mm gunship combat

**Milestone:** M3. **Dependencies:** P04, P14. **Requirements:** R03, R06, R07, R13, R15. Status: [roadmap](../roadmap.md).

## Capability and player experience

The operator can engage exposed ground players with the 30mm GAU-23/A Chain Gun or 105mm M102 Howitzer. Their firing cadence, blast footprint and zoom differ; intact cover protects players. Eliminating the whole ground team ends the round.

## Implementation

Introduce common combat orchestration, explicit configurations for both aircraft weapons, validated selection/fire intent, per-weapon readiness, server-derived muzzle paths and bounded swept projectile collision. The 30mm offers faster precise fire with tighter view; the 105mm offers slower heavy shells with wider view and readable warning/travel time. Resolve blast against pre-impact geometry; keep breakable cover intact until P07. Switching never resets ammo, cooldown or reload. Add health/elimination and deduplicated cosmetic feedback. Expose a typed server-resolved impact seam with round/shot ID, weapon profile, hit position/panel identity and server timing for P07; do not award panel damage yet. Record and test cadence assumptions so nine seconds of sustained valid 30mm fire is achievable without a forced reload interruption. Revalidate weapon range/travel limits against the enlarged map; use authored maximum target height instead of a flat-ground aim restriction. Use the confirmed 105mm M102 name and its new P07 panel-damage contract (D31).

Keep weapon/damage rules in the core combat modules. Obtain playable bounds,
aim envelope, queryable cover and panel identities from the active level context
rather than embedding this industrial map's coordinates in shot logic. P05 tests
the current level and an injected alternate boundary; P15 later validates two
fully playable level packages without changing the weapon rules.

## Acceptance criteria

- **A1:** Full gate passes. For both named weapons, tests cover damage/cadence/reload boundaries, bounded flight lifetime, clamping and one damage award per shot/target.
- **A2:** Switching selects the configured FOV and active weapon coherently, including under rejected/stale requests. Rapid alternating selection cannot reset either weapon's cooldown/reload or refill ammo; remaining readiness survives switch-away/switch-back.
- **A3:** Remote tests reject forged muzzle/hit/damage, wrong role, stale/replayed sequence, impossible aim/range, out-of-disk endpoints, NaN/infinity and floods without health/readiness mutation. Valid shots still succeed afterward.
- **A4:** Engine fixtures show swept queries hit thin cover; exposed targets take configured damage and protected targets take none. Both weapons use authoritative world geometry and respect the panned inward camera/aim envelope, including expanded-map edges, sloped terrain and second-floor targets. Camera-visible but muzzle-obstructed shots cannot bypass cover.
- **A5:** Ground death eliminates once without respawn; all-ground elimination commits C-130 victory once. Deadline/result stops later damage, and a shot from a previous round cannot damage the next. Two clients observe consistent selected weapon, shot, health and result; reset clears resources.

## Focused human check

Operate both weapons, switch while reloading and inspect warning/impact/thermal frames. Verify readable differences, useful cover and stable zoom changes. Ground counterfire arrives in P06.

## Documentation changes

Document both weapon contracts, per-weapon timing, zoom mapping, blast cover approximation and actual controls.

## Completion record

The candidate is on `plan/05-gunship-combat`, based on integrated main
`79336f17d76717408351978b4a9925418361670e`. The developer implemented
server-authorized gunship firing, per-weapon readiness, swept collision and
cover-limited damage; the independent tester found an endpoint-airburst defect,
which was corrected before the narrow engine probe below. Full acceptance and
player-feel review remain open. [Draft PR #25](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/25)
contains the candidate and is not an integration or publication claim.

| Criterion | Evidence and remaining work |
| --- | --- |
| A1 | Full host `python3 scripts/verify.py` passed 50 unit and 28 integration cases on `f1982bb`; an independent integration run also passes 28/28. Tests cover both lifetime boundaries, distance clamp, cadence/reload, damage clamps and per-shot/target deduplication. Live projectile expiry and actual Humanoid damage remain unverified on the latest source. |
| A2 | Host tests exercise independent weapon readiness and switch-away/switch-back. The expanded two-client switching scenario exists but has not completed on the corrected candidate. |
| A3 | Host tests reject forged fields, stale round/sequence, wrong role, nonfinite and outside bounds. On `03eaacf`, a one-client real-engine probe confirmed a collisionless endpoint caused no impact. Flood/recovery, impossible view, and the expanded multiplayer probes remain open. |
| A4 | The first two-client candidate exercised narrow cover scenarios; it predates the collision correction. On `03eaacf`, a disposable Part probe verified the 0.25-stud surface continuation. Both-profile real slopes, second floors, panned aiming, muzzle obstruction and damage/cover cases still need a current-candidate run. |
| A5 | The updated two-client fixture includes result, no-respawn, terminal projectile and next-round cases but has not finished on the corrected candidate. Consistent replicated shot, health and result, reset cleanup and operated play remain unverified. |

The [detailed record](../docs/evidence/p05-gunship-combat.md) identifies
source-specific runs, the earlier test failure, the pending Studio SDK launch,
and the independent tester's actual observations. A real current-combat
screenshot and operated desktop/touch weapon and thermal review are outstanding.
