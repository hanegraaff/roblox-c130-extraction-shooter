# P25 — Weapon cooldowns, rocket damage and infinite M-7 ammunition

**Gameplay iteration.** Builds on P05, P06, P08, P18 and P19. Covers R07–R10, R12 and R13. [Roadmap](../roadmap.md) · [Requirements](../requirements.md)

| Weapon | Integrated settings | Planned settings |
| --- | --- | --- |
| 105mm M102 Howitzer | One shell, ready again after 6 seconds | Ready **12 seconds** after each accepted shot |
| Ground rocket launcher | Ready after 4 seconds, 100 direct aircraft damage | Ready after **15 seconds**, **150 damage** per direct aircraft hit |
| M-7 rifle | 30-round magazine, 120 reserve | **Unlimited reserve** with the existing 30-round magazine, 2-second reload, 0.15-second cadence and 5 aircraft damage per hit |

## Implementation

- In `CombatService`, change the M102 single-shell automatic reload to 12 seconds. Measure from the accepted shot. The 30mm retains its own readiness across weapon switches. Preserve the existing M102 blast radius and panel rules.
- In `LauncherService`, track the 15-second ready time independently on each of the four round-owned launcher identities. Handovers, weapon switches and recovery after death preserve the fired launcher's ready time. Fresh launchers start loaded. Apply 150 once in the shared aircraft health path on an authoritative direct impact. Keep misses, occlusion, the remaining-health clamp and the locked maximum of 1,000 × deployment Ground count.
- In `GroundCombatService`, allow a living, equipped rifle user to refill a partial or empty magazine indefinitely. Replicate unlimited supply explicitly and show the loaded rounds and reserve together, for example **30 / ∞**. Keep the finite magazine and reload deadline server-owned. Update `GroundCombatController` and readiness copy for both desktop and touch.

## Acceptance

| ID | Planned check | Passing observation |
| --- | --- | --- |
| A1 | Extend `CombatService` and `LauncherService` clock tests | From an accepted shot at t=0 the M102 rejects at 11.999 seconds and accepts at 12. The fired launcher rejects at 14.999 and accepts at 15. Rejected early, stale and duplicate requests leave readiness unchanged. Switch away and back, transfer a cooling launcher to a teammate, and show another launcher still has its own ready time. |
| A2 | Extend `AircraftHealth` and damage integration tests | At 1,000 HP a rocket leaves 850 and one M-7 hit then leaves 845. Six rockets alone leave 100 and the seventh destroys the plane exactly once. Check a larger roster, a miss, solid cover, duplicate impact and a lethal mixed-damage batch at the deadline. |
| A3 | Extend `GroundCombatService` and presentation tests | Fire more than the former 150-round total with repeated legal reloads. An empty magazine cannot fire, a partial magazine refills correctly, and firing is rejected until the two-second reload completes. A stale request, elimination or round change cannot grant a shot or complete an old reload. |
| A4 | Extend the native gunship, Ground and launcher harnesses | In a shared Studio round, verify weapon-switch readiness, the cooling launcher after handover, 150 damage on both clients' aircraft health displays, and magazine/reload feedback with unlimited supply. Review timer legibility and restored equipment across round reset. |

Run `python3 scripts/verify.py` and the affected Studio combat and HUD suites. Update the root player guide, readiness and damage contracts, and tests that assert the former timings or reserve. Preserve earlier evidence under its tested revision.

## Completion record

Planning only. Implementation and acceptance checks are unrun.
