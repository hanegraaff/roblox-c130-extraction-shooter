# P07 — Progressive building-panel destruction and physics

**Milestone:** M4. **Dependencies:** P06, P13, P14. **Requirements:** R06, R07, R09, R13, R15, R16. Status: [roadmap](../roadmap.md).

## Capability and player experience

Shooting building panels visibly degrades them. Three direct heavy-cannon hits replace an intact panel with a roughly half-destroyed variant; three further hits remove it entirely. Sustained on-panel 30mm fire takes nine seconds to damage it. New openings change movement, protection and thermal visibility for every player. Real falling fragments demonstrate physics even with primitive art; static floors/stairs/frames preserve usable buildings without full collapse.

## Implementation

Build Intact/Damaged/Destroyed templates using the P13 building/story/panel registry and approximate two-panels-wide/one-panel-tall room proportions. Author the Damaged variant with actual holes exposing roughly half its original face (D32 tolerance); do not leave an invisible full collider. Include destructible wall panels on every story and roof panels on all three buildings; aircraft fire must be able to open overhead cover. Expose progressive chips/cracks or equivalent cues after individual heavy hits and during sustained 30mm accumulation, not only when swapping models.

DestructionService owns state, deduplicated shot IDs and stage progress. Heavy thresholds are 3/6 direct hits from pristine. Nine seconds of server-validated same-panel 30mm fire must advance Intact → Damaged, never early; D33 defaults specify another nine seconds for Destroyed, cadence-aware gap tolerance, interrupted-fire reset of uncommitted 30mm contribution and proportional mixed-fire credit. Choose and record numeric cadence/gap/rounding tolerances before testing; no elapsed credit before the first accepted impact or across rejected/missed/off-target shots. Keep structural direct-impact credit separate from player blast damage. No client panel ID/duration/damage claim is authoritative.

Panel damage and fragment limits are core rules. Read stable panel IDs, pivots,
variants and supporting geometry from the active level registry; do not fork the
thresholds or service per map. P07 proves this contract on the MVP level. P15
later verifies reconstruction and identical rules on a second playable level.

Apply damage against pre-impact batch geometry, then atomically transition panel/colliders at the stable pivot and ID. Only later shots can exploit new holes. Replicate current stage/progress for late joiners; don't replay old debris bursts. Generate a capped set of server-owned unanchored fragments with bounded impulses/lifetime, actual gravity and collision against static scenery. Collision groups exclude characters and debris; combat/thermal queries ignore fragments. Fragments cannot harm/push players, block required routes, chain-destroy panels or become structural supports (D34 defaults). Overflow may retire older fragments without changing cover state. Reset cancels work, removes fragments/listeners and restores all terrain/panels/progress.

## Acceptance criteria

- **A1:** Full gate passes. Named `PanelDamageRules` tests trace heavy hits 0–6: 1/2 do not swap, 3 swaps to Damaged, 4/5 retain Damaged and 6 removes the panel. Duplicate/replayed events do not count twice; permanent structure is immune; states are monotonic and destruction idempotent.
- **A2:** `SustainedPanelFire` deterministic tests cover just below/exactly/above nine valid seconds, second-stage nine seconds, no credit before the first impact, cadence/gap/rounding tolerance, misses/obstruction/target changes, weapon switch/reload gaps, rejected shots, operator disconnect, mixed credit, same-step impacts and stale-round cancellation. Mere trigger time and off-target fire cannot advance a panel. Uninterrupted valid P05 cadence can actually reach the threshold.
- **A3:** Studio `PanelGeometryStates` measures 45–55% opening in the Damaged face; real raycasts/overlaps show remaining solids block shots/movement and holes permit appropriate rays. Destroyed has no panel collider, and a suitable authored opening is traversable. Stable panel IDs/pivots survive swaps on every story and roof of all three buildings; floors/stairs/frames stay usable.
- **A4:** Studio `PreImpactCoverAndThermal` proves an impact creating a hole does not retroactively damage a protected target through it; a later shot can. Test both weapon profiles, intact/residual/hole/destroyed sight lines and actual rendered thermal occlusion from ground/operator viewpoints.
- **A5:** Studio `PanelFragmentPhysics` observes unanchored fragments falling and contacting static scenery, server ownership, collision/query groups, bounded impulses/count/lifetime and cap behavior under repeated simultaneous destruction. Actual characters are not pushed/harmed or blocked; fragment placement cannot alter authoritative shot/thermal queries. A particle burst or mocked physics call does not satisfy this criterion.
- **A6:** Two actual clients and a late-joining spectator agree on panel stage/progress/openings within declared replication bounds without replaying prior debris. Wrong-role/malformed/flooded requests cannot alter cover. Reset during active fragmentation/sustained fire removes work and restores exact terrain/building/panel state through multiple rounds; no old projectile advances a fresh panel.
- **A7:** Actual fire with primitive assets visibly demonstrates per-hit/prolonged-fire progression, third/sixth heavy hits, nine-second 30mm damage, holes and falling fragments. Two launcher approaches and all required upper-floor access remain usable without requiring destruction. Record automated observations separately from operated readability review.

## Focused human check

Fire at each panel stage from operator and ground viewpoints, including an upper story. Time sustained 30mm fire, distinguish intact/half-destroyed/gone states, inspect interim progress and watch fragments fall/contact scenery. Confirm readable cover and stable access. Refined art is not a prerequisite for accepting the mechanics; placeholder graphics cannot excuse missing physics or real openings.

## Documentation changes

Document panel IDs/variants, heavy/sustained/mixed damage contracts, measured opening area, physics ownership/groups/caps, impact order, cleanup and player's cover cues. Refresh the representative README screenshot using actual implemented destruction. Add refined assets only through separately scoped later plans.

## Completion record

Implementation started on 2026-11-13 on `plan/07-destruction`, based on
integrated main `e4c6e3a2506a9e9ac5574bdf42242f77f8200650`, which contains
P06, P13 and P14. Acceptance requires A1–A7: deterministic progression and
sustained-fire rules, real residual geometry and pre-impact cover, actual bounded
fragment physics, two-client/late-join/reset evidence and operated readability.
The [verification record](../docs/evidence/p07-destruction.md) will distinguish
source-specific checks from the earlier baseline. No P07 test pass is claimed
at selection; no later plan has started.

Before new tests, D46–D48 record the initial continuity/numeric, geometry and
fragment defaults: 0.225-second accepted-shot gap, first impact zero credit,
1e-7 threshold tolerance, 50% central opening, four fragments per transition,
48 live fragments, eight-second lifetime and bounded 12-stud/second / 4-radian/
second launch. These are tunable defaults, not newly selected user rules.


The corrected source candidate is `cb530a0175f683f933d93fa7546b377614788c39`
(tree `9bfcf88f9c52dbfd57db77858ed7ad56ebc337eb`). Developer and independent
full gates pass 54 unit / 53 integration tests, and clean actual solo Studio
runs pass 137 server / 6 client tests. Independent review's four initial
findings were corrected and affected deterministic/engine paths rechecked.
See the verification record for hashes, failed first-candidate evidence,
environments and scope limits.

[Draft PR #29](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/29)
is open from `plan/07-destruction` to `main`, initially at documentation head
`18c28e9a6f2d333b90e74a6a96da4a06d40d57d1`. Native two-client/late-join,
actual-player blast, rendered thermal/readability, multiplayer regressions
and the new README capture remain required. The roadmap remains In progress;
P08 has not started. No P07 merge or Roblox publication is authorized or claimed.
