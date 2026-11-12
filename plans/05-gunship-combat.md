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

The source under review is `232889f04a848f145231009e2be21c0ffcb6442e`
(tree `b29b274f2c612ede1855dd056f6da012b3960274`) on
`plan/05-gunship-combat`, based on integrated main `79336f17d76717408351978b4a9925418361670e`.
[PR #25](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/25)
contains the candidate; it has not been merged or published.

| Criterion | Evidence |
| --- | --- |
| A1 | `python3 scripts/verify.py`: 50 unit / 33 integration passed, including `CombatService.spec.luau` and `DamageRules.spec.luau` timing, reload, damage clamp, deduplication and bounded-flight cases. Studio `CombatCollision.spec.luau` plus the two-client injected-clock expiry case exercise real swept queries and Instance cleanup at the lifetime boundary. |
| A2 | Host readiness tests and the two-client switch/reload case passed. Native desktop switching retained panning, acknowledged 30°/40° FOV and retained the heavy reload. |
| A3 | Host view-intent and combat tests plus the two-client rejected-traffic and airburst cases passed for forged fields, role, sequences, nonfinite/outside targets, view claims and recovery. `CombatView.spec.luau` compares 600 actual CFrame rays across both zooms and orbit phases, including a valid downward-ray case. View claims are bounded rather than attested; the allowance is symmetric at 1.25 seconds of orbit travel. |
| A4 | Studio smoke passed 104/104 server cases and 3/3 on each of two actual clients. The eight-case two-client suite passed thin-cover, embedded-cover player protection and both-profile real slope and Foundry second-story panel impacts. The M102 slope impact was 4.27 studs from target against the 5-stud limit. |
| A5 | The two-client suite passed matching selected weapon, shot, health and result observations; lethal elimination, no respawn/result once, terminal cancellation, next-round stale requests and projectile expiry cleanup. |

The [detailed record](../docs/evidence/p05-gunship-combat.md) preserves earlier
failures, fixes and source-specific reports. The independent operated review
exercised native desktop and iPhone-simulator multitouch, both weapons and their
rendered effects. The rapid 30mm warning and projectile phases are difficult to
separate during a burst, and the pre-existing ground HUD is large on a phone.
For future levels, validate that voxel Terrain cannot intersect the aircraft
muzzle or add Terrain-overlap handling; the present BasePart overlap guard does
not cover voxels. The technical writer updated the player and contributor docs
and captured current gameplay. No Roblox publication occurred.
