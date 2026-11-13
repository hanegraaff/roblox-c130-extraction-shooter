# P07 — Progressive building-panel destruction and physics

**Milestone:** M4. **Dependencies:** P06, P13, P14. **Requirements:** R06, R07, R09, R13, R15, R16. Status: [roadmap](../roadmap.md).

## Capability and player experience

Shooting any battlefield building, including the starting shelter, produces persistent and clearly distinct Light, Heavy and Total damage. Three direct heavy-cannon hits create roughly half destruction; three further hits remove the panel. Nine earned valid 30mm seconds create Heavy damage. Partial 30mm damage stays when fire stops; pauses do not add elapsed credit. New openings change movement, protection and thermal visibility. Real bounded fragments fall; supporting floors/stairs/frames remain usable.

## Implementation

Build Intact/Damaged/Destroyed templates using the P13 building/story/panel registry and approximate two-panels-wide/one-panel-tall room proportions. Author the Damaged variant with actual holes exposing roughly half its original face (D32 tolerance); do not leave an invisible full collider. Include destructible wall panels on every story and roof panels on all three buildings; aircraft fire must be able to open overhead cover. Expose progressive chips/cracks or equivalent cues after individual heavy hits and during sustained 30mm accumulation, not only when swapping models.

DestructionService owns state, deduplicated shot IDs and stage progress. Heavy thresholds remain 3/6 direct hits from pristine. Nine earned seconds of server-validated same-panel 30mm fire advance the first structural stage, never early; another nine advance the next. D51 preserves every panel's partial earned credit through stopping, misses, obstruction, target/weapon changes and reload. Break only the continuity anchor; the first resumed impact earns zero, with no paused/off-target elapsed credit. Keep proportional mixed-fire credit and ordered accepted outcomes/barriers. Keep structural impact credit separate from player blast damage. Clients cannot claim panel IDs, durations or damage.

Publish Pristine/Light/Heavy/Total appearance independently of the retained structural Intact/Damaged/Destroyed state. Light must have visible persistent scars on both faces without fake holes; Heavy keeps its visibly stronger treatment and real 45–55% opening even when stage-local progress is zero. Marks cannot collide, enter gameplay queries or identify as structural colliders. D54 records tuning before tests. Register the starting shelter's entire exterior using the same core owner, remove the old duplicate colliders and preserve the original union/entrances/anchors. D53 proposes 76 shelter panels plus the existing 111; separate waiting-lobby geometry is unchanged.

Panel damage and fragment limits are core rules. Read stable panel IDs, pivots,
variants and supporting geometry from the active level registry; do not fork the
thresholds or service per map. P07 proves this contract on the MVP level. P15
later verifies reconstruction and identical rules on a second playable level.

Apply damage against pre-impact batch geometry, then atomically transition panel/colliders at the stable pivot and ID. Only later shots can exploit new holes. Replicate current stage/progress for late joiners; don't replay old debris bursts. Generate a capped set of server-owned unanchored fragments with bounded impulses/lifetime, actual gravity and collision against static scenery. Collision groups exclude characters and debris; combat/thermal queries ignore fragments. Fragments cannot harm/push players, block required routes, chain-destroy panels or become structural supports (D34 defaults). Overflow may retire older fragments without changing cover state. Reset cancels work, removes fragments/listeners and restores all terrain/panels/progress.

## Acceptance criteria

- **A1:** Full gate passes. Named `PanelDamageRules` tests trace heavy hits 0–6: 0 is Pristine, 1/2 show persistent Light damage, 3 creates Heavy damage with a real opening, 4/5 stay Heavy and 6 removes the panel. Stage-local progress zero cannot restore pristine Heavy appearance. Duplicate/replayed events do not count twice; static supporting structure stays immune; progression is monotonic and destruction idempotent.
- **A2:** `SustainedPanelFire` tests cover below/exactly/above nine earned seconds, second-stage nine seconds, zero first/resumed-impact credit, cadence/gap/rounding tolerance and persistent PER-PANEL credit across pauses, misses, obstruction, target changes, switches, reload and operator loss. Alternating panels cannot earn off-target time; rejected requests cannot mutate credit. Test mixed fire, ordered in-flight/barrier outcomes, terminal cancellation and pristine reset. Valid bursts accumulate to the threshold without healing, paused-time credit or duplicate awards.
- **A3:** Studio `PanelGeometryStates` proves persistent Light/Heavy visual distinction and a 45–55% Heavy opening. Real raycasts/overlaps distinguish cosmetic marks, remaining solids and genuine holes. Total has no collider. Every wall/roof panel in all three multi-story buildings AND the battlefield starting shelter takes real fire. The shelter's old collider union/entrances/anchors are preserved without hidden duplicate solids. IDs/pivots survive swaps; floors/stairs/frames and both routes stay usable; an authored opening is traversable.
- **A4:** Studio `PreImpactCoverAndThermal` proves an impact creating a hole does not retroactively damage a protected target through it; a later shot can. Test both weapon profiles, Pristine/Light/Heavy residual/hole/Total sight lines, cosmetic-query exclusion and actual rendered thermal occlusion from ground/operator viewpoints, including the starting shelter.
- **A5:** Studio `PanelFragmentPhysics` observes unanchored fragments falling and contacting static scenery, server ownership, collision/query groups, bounded impulses/count/lifetime and cap behavior under repeated simultaneous destruction. Actual characters are not pushed/harmed or blocked; fragment placement cannot alter authoritative shot/thermal queries. A particle burst or mocked physics call does not satisfy this criterion.
- **A6:** Two actual clients agree on persistent stage/credit/appearance/openings within declared replication bounds. Wrong-role/malformed/flooded requests cannot alter cover. Reset during live fragmentation and partial/in-flight 30mm work restores pristine terrain/building/panel state through multiple rounds; old projectiles cannot advance fresh panels. Per user D50, a real late-joining-client scenario is not a P07 acceptance gate; runtime spectator restrictions remain.
- **A7:** Actual native fire visibly demonstrates persistent Light/Heavy/Total damage on normal and thermal views, third/sixth heavy hits, earned 30mm damage across stopped/resumed bursts, real holes and falling fragments. Include the starting shelter and other battlefield buildings. Both launcher approaches and required upper-floor access remain usable without demolition. Record automated evidence separately from operated readability.

## Focused human check

Fire at each panel stage from operator and ground viewpoints, including an upper story. Time sustained 30mm fire, distinguish intact/half-destroyed/gone states, inspect interim progress and watch fragments fall/contact scenery. Confirm readable cover and stable access. Refined art is not a prerequisite for accepting the mechanics; placeholder graphics cannot excuse missing physics or real openings.

## Documentation changes

Document panel IDs/variants, heavy/sustained/mixed damage contracts, measured opening area, physics ownership/groups/caps, impact order, cleanup and player's cover cues. Refresh the representative README screenshot using actual implemented destruction. Add refined assets only through separately scoped later plans.

## Completion record

### Active user revision — 2026-11-13

The user explicitly removed real late joining from P07 acceptance and reported
three remaining defects: insufficient Light/Heavy visual distinction, an
immune battlefield starting shelter, and partial 30mm damage disappearing
when firing stops. Work resumes on dedicated dependent branch
`fix/p07-progressive-persistent-damage` from `ebf5bd4`; main remains unchanged.
D50–D54 record the waiver, persistent credit, distinct appearance, full shelter
coverage and proposed visual/construction defaults before new tests. The old
passing/failing records below describe the earlier source and do not validate
the revised behavior. The revised candidate must pass its own gates and
operated review before completion.

Dedicated follow-up [PR #30](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/30)
targets the original unmerged PR #29 branch. Production damage/geometry/assets
are frozen from `583d82a`; final test source is
`8053c8f73c5700161e7b87d8e87824742165f3cd`, tree
`a1e0e2e5405b0fd30e5e5b88b712d59431c608ea`. Test-only corrections address
color quantization, future target visibility, assertion forwarding and a
measured 28ms Part-to-Model reset reconstruction boundary. The
[103-input identity](../docs/evidence/p07-revision-source-identity-8053.json)
and independent source comparison preserve the unchanged production core.
The [revision evidence](../docs/evidence/p07-damage-revision.md) retains all
failed runs separately from the final passing reports.

| Criterion | Revised verification and remaining scope |
| --- | --- |
| A1 | Independent final `python3 scripts/verify.py`: 55 unit / 55 integration; exact 0–6 stage/appearance boundaries, monotonic/idempotent/mixed rules pass. GitHub Verify run 271 also passes. |
| A2 | Persistent `DestructionService` timing/barrier/rejection/reset tests pass. Final native three-burst run accepts all 63 shots, earns 11.001190 seconds and reaches Heavy at 9.168631; stopped Light credits remain 3.667306 / 7.334313. Actual native shelter stop/resume adds zero for a 47.866-second gap. |
| A3 | Fresh actual Studio baseline: 142 server / 6 client, including every one of 187 panels, real residual/query/cosmetic geometry and stable supports. Shelter union/anchors and artifact reconstruction pass. Final actual two-client suite passes Ground Humanoid wall traversal. |
| A4 | Fresh geometry/pre-impact tests and actual two-player blast-health 2/2 pass. Unedited Warehouse and shelter normal/thermal four-tier comparisons reveal the QA hole control while hiding residual-solid control under Heavy; Total exposes both. Held aircraft clock and controlled normal comparison cameras are disclosed. |
| A5 | Actual Studio fragment gravity/contact, ownership/groups/query exclusion, real-avatar safety, cap/lifetime and cleanup tests pass in the 142-case baseline. GPU captures show resting fragments; they do not establish the separate A7 visual-fall observation. |
| A6 | Final native suite passes 7/7 with two actual clients, zero failures/skips. Both resets have actual partial GAU credit, two pending projectiles and four live fragments. Server and each client verify all 187 pristine panels, pivots, credit, cosmetics and queries; stale outcomes reject and work clears. Real late join is waived under D50. |
| A7 | Native Warehouse/shelter firing, stopped/resumed scars, third/sixth M102 Heavy/Total, real holes and normal/thermal distinction pass focused review. In an additional ordinary live-orbit two-player round, native M102 shot 4 creates Heavy damage and four fragments on the third target hit; the user directly confirms, “Yes, I saw pieces fall,” in the labelled controlled Ground close-up. The recorded 61-Heartbeat trajectory independently corroborates real gravity/contact. Current-core regressions pass P05 8/8 and P14 6/6, including two full 90-second orbits and operator departure. |

All revised A1–A7 acceptance passes; P08 is eligible for Ready without starting
implementation. The [human observation and native proof](../docs/evidence/p07-revision-human-fragments.json)
distinguish the user's factual answer from readiness and prior settled-frame
captures. Final source remains 8053; no production changes were needed for the
human review. PR #30 delivers the revision to the unmerged PR #29 dependency;
integration into main remains separate and unauthorized. No Roblox publication
occurred. The current README uses an actual revised Heavy capture and labels
its QA camera/marker setup. Final cleanup retains the original Edit document
and Rojo connection with no QA runtime/camera pollution.

Source, reviewed documentation and full acceptance evidence were committed and
pushed at `8642ec0bb9fc6751f10c768434adbe49d79386c3` (tree
`a072b9fc866f227ef2fcc9a7ebdce45498d0406e`). GitHub Verify run 273 passes;
the final local repository/whitespace checks pass (80 Markdown / 189 JSON).
PR #30 is open, ready for review and unmerged, targeting `plan/07-destruction`.
Remote verification confirms main remains `e4c6e3a` and the original dependency
branch remains `ebf5bd4`; PR #29 stays draft until the follow-up integrates.
This delivery records complete acceptance independently of main integration.

### Earlier candidate record (historical)

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
`18c28e9a6f2d333b90e74a6a96da4a06d40d57d1`. Subsequent fixture snapshots
and actual results are preserved in the verification record; runtime/core/assets
remain unchanged from `cb530a0`. P08 has not started. No P07 merge or Roblox
publication is authorized or claimed.

| Criterion | Recorded evidence and current limit |
| --- | --- |
| A1 | `PanelDamageRules` and full independent host gates pass 54 unit / 53 integration; native actual M102 hits 1–6 produce the required stages/progress. |
| A2 | Named `SustainedPanelFire` integration cases cover thresholds, accepted-shot ordering, interruptions, invalid/stale inputs and cleanup. Actual native 61-shot fire proves zero first-hit credit and a transition after at least nine accepted seconds. The initial failed timing fixture and causal reproduction are retained separately. |
| A3 | Studio `PanelGeometryStates` checks all 111 panels, 50% residual opening, real rays/overlaps, identity/pivots and static supports. The e45 native run also passed actual client-and-server-observed Ground Humanoid traversal. |
| A4 | `PreImpactCoverAndThermal` engine geometry checks pass. Separate actual-player blast checks pass both profiles, protecting health on the creating impact and damaging the same in-radius target through the later hole. Actual Ground opening view is captured; clean rendered thermal comparison remains unverified. |
| A5 | Real Studio `PanelFragmentPhysics` passes fall/contact, server ownership, groups/query controls, actual-avatar exclusion, mass/velocity, cap/lifetime and cleanup assertions. |
| A6 | Two actual clients passed role/rejection, stage/progress/opening agreement and debris-expiry checks. The e45 run passed five of six discovered cases, then late join timed out. A separate reset-only probe passes 2/2 actual rounds with positive partial credit, live fragments and pending flights: all 111 server panels/334 map parts restore, 576 voxel samples match, both clients verify 30 roofs/no debris, and stale outcomes reject. True late reconstruction remains unverified. |
| A7 | Automated actual heavy/30mm progression and real wall traversal passed. The actual Ground opening capture replaces the README hero. Clean thermal comparison, Destroyed/falling-fragment visual review, native firing feel and complete operated readability remain open. |

The specific late-join capability gap is confirmed in the installed Studio
0.747 manual session: both the client-count control and Quick Open Actions →
Start are disabled while the native server runs. The historical staff
workaround could not be used here. The SDK launcher previously stalled and
AddPlayers rejected manual sessions; those attempts were not repeated without
changed conditions. Restarting with three initial clients does not prove a
genuine post-damage join. A working mid-round join route is needed to finish
that required evidence; no acceptance waiver or fake spectator is substituted.

The new bounded late-cohort fixture (`ebca51e`, full host gate passing) supports
one or two real late clients in the same Active round, within the original
240-second deadline. Its optional batch path remains unrun. P05 regression
found a grazing Terrain fixture mismatch; `873f0f6` retains the original
five-stud actual-impact assertion while selecting a stable sloped scenario.
Its actual rerun passed 8/8 with zero failures/skips. Independent host gate on
the final executable candidate passes 54 unit / 53 integration. The final
actual P14 regression passes 6/6 with both weapon full orbits, new-round focus,
operator departure and repeated teardown. The verification record retains
exact source hashes, separate scopes and actual failed runs.

The remaining conditions for completion are a real post-damage join in the
same Active round and the focused rendered/operated items identified in A4/A7.
The tested native UI cannot add that client; restarting with three initial
players does not clear this condition. The SDK path also needs changed
capability/state before a justified retry. The next review must establish clean
thermal sight lines through the opening, Destroyed/falling-fragment visibility
and actual firing/readability with the current candidate. No acceptance
requirement was silently waived, and an incomplete plan is not marked Complete.

Final delivery checkpoint: branch/evidence head `4f3fbeb` is pushed;
[source CI](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/43451965908)
and [evidence/media CI](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/43456880127)
pass. Repository checking passes 77 Markdown / 166 JSON files; the final
103-file executable manifest has zero mismatches. Native tests ended cleanly,
only the original Edit document remains, ManualHarness is nil and the existing
Rojo connection is retained. Main remains `e4c6e3a`; PR #29 is draft/unmerged.
