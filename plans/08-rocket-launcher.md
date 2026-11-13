# P08 — One recoverable map rocket launcher

**Milestone:** M5. **Dependencies:** P07. **Requirements:** R08, R10, R13, R15. Status: [roadmap](../roadmap.md).

## Capability and player experience

One rocket launcher is available at its map anchor. A ground player can reach it, carry it alongside their M-7 and land the three direct hits needed to destroy a full-health C-130. Teammates can recover it when its carrier drops it, dies or disconnects.

## Implementation

Add LauncherService with one round-owned identity and Available/Held/Recovering transitions. Validate pickup range/life/role and plausible movement; claim atomically without yielding. Keep reload readiness on the weapon identity across transfers. Implement single-round replenishing reload, explicit drop, death/disconnect recovery and fallback to the original anchor for invalid/unreachable positions. Add ownership/readiness HUD and bounded dropped models. Use P06 rocket damage/projectile rules, not a new health system. Do not introduce other items, ammo pickups or a collection counter.

## Acceptance criteria

- **A1:** Full gate passes. Exactly one launcher exists in the round across available/held/recovery states. Two simultaneous pickup requests, duplicate messages and rapid transfer cannot create a second owner or weapon representation.
- **A2:** Wrong role, dead/spectator, invalid ID, impossible travel/reach, stale round and flood requests reject without ownership/ammo mutation. A valid pickup works afterward; M-7 remains available to the carrier.
- **A3:** During an active round, drop, death, character reset and disconnect preserve reload state and produce one recoverable weapon. Terminal cleanup takes precedence after a result. Invalid/out-of-bounds positions return it to its anchor. Switching/re-picking cannot fire before reload finishes; replenishment never creates ammo items.
- **A4:** Real launcher impacts apply the P06 contract: two direct hits alone leave a pristine plane alive, the third ends the round as ground win, and earlier rifle damage reduces remaining health. Miss/obstruction/duplicate impacts do not add a full direct hit. Configured timing permits at least three shots during the round.
- **A5:** A Studio session with one operator and two ground clients demonstrates raced acquisition, carrier death/disconnect and teammate recovery. Clients agree on ownership, reload and aircraft health; reconnect cannot restore a carried launcher or active life.
- **A6:** Reset removes old held/dropped/projectile state and spawns exactly one launcher at the original anchor. A delayed prior-round callback cannot grant ownership or damage the next aircraft.

## Focused human check

Traverse both launcher approaches, pick up, switch between M-7 and launcher, fire/miss/reload, drop and recover it. Check that the team can tell whether it is available or carried and how many damaging hits remain without implying a false fixed count after rifle damage.

## Documentation changes

Explain the single launcher, recovery/default replenishment and actual controls. Document ownership, reload continuity and recovery contracts.

## Completion record

Implemented on `plan/08-rocket-launcher` and delivered through
[draft PR #32](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/32).
Full acceptance remains incomplete **only because A5's actual same-identity
reconnect scenario is unverified**. No waiver applies to P08. See the
[verification record](../docs/evidence/p08-launcher.md) and
[independent final review](../docs/evidence/p08/independent-final-07e77ea.md).

Production/UI source is `ef7826bc80310c17be4bcde93fe7607620303289`, tree
`db1f4e50296a2620d13e36839525c7562220a629`. Tested harness revision is
`07e77ea5b57fba359ab611ea39e2c42c7b977881`, tree
`032f7b162bcc8bba6e48c002b2ca0da30939b444`; it contains no production change.
The native run observed delivery head `c3b155d`, based on integrated P07 main
`c7210be`. [CI Verify](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/43517470871)
passes on that delivery. Subsequent changes are documentation/evidence only.

| Criterion | Named tests / environment | Observed result |
| --- | --- | --- |
| A1 | `LauncherService.spec` raced pickup/snapshot cases; `Launcher.spec` representations; P08 initial/raced-pickup cases | Pass: one round identity, owner and representation; both ground players retain their M-7. Full host gate and actual three-client race pass |
| A2 | `LauncherService.spec` malformed/authority/reach/replay; shared movement/origin suites; P08 rejection/flood/movement and later valid pickup | Pass: rejected shape/role/life/ID/round/replay/rate/movement requests cannot change ownership/ammo; valid traffic works afterward |
| A3 | Reload/transfer/recovery rules; `CharacterOwner.spec`; P08 miss/drop/transfer/switch/early-fire, death/in-flight, raw-removal and Kick/recovery cases | Pass: exact reload deadline and identity persist; reset player stays eliminated; a real accepted rocket survives nonterminal shooter death and damages the aircraft |
| A4 | Health/timing rules; first-solid engine sweep; P08 pristine three-rocket and mixed-fire cases | Pass: actual pristine health 300→200→100→0 and Ground/AircraftDestroyed result; 21 real rifle hits give 195, then two rockets give 95→0. Miss/cover/duplicate rules and feasible reload timing pass |
| A5 | Native P08 actual one-operator/two-ground session and replicated observations; composed MatchService tombstone tests | Three-client acquisition/death/disconnect/recovery/ownership/readiness/health agreement passes. Actual same-identity reconnect remains required and unverified; `actualReconnectVerified=false` / `requiredUnverified` explicitly retain the gap |
| A6 | Terminal/next-round rules; runtime cleanup; P08 real reset/anchor/old-intent and teardown | Pass: old state/work cannot own or damage the next round; one fresh anchor weapon; idempotent teardown drains all owned resources |

Final `python3 scripts/verify.py` passes **55 unit / 65 integration** and all
static, strict-type, build, corruption-probe, geometry and release-isolation
gates ([log](../docs/evidence/p08/host-07e77ea.txt)). Studio
0.747.0.7471481 native Server & Clients passes **11/11 P08** cases, zero
failures/skips. Requested/initial/peak population is three actual players;
final population is two after the intentional carrier Kick. Fresh smoke is
**156/156 server and 7/7 on each of all three clients**, captured before
intentional departure. The [summary/baselines](../docs/evidence/p08/native-07e77ea-pass.json),
[full report](../docs/evidence/p08/native-07e77ea-full.json) and
[trace/cleanup audit](../docs/evidence/p08/native-07e77ea-audit.json) preserve
150 trace records, zero dropped, source signatures and environment.

The earlier native failure exposed fixture aim being prepared before reload;
the correction calculates it after readiness and retains the original damage
assertions. Current moving-direct aim age is 0.033848–0.283879 seconds. The
post-death shot's matching ID/flight/impact and health 200 are preserved.
Earlier failed SDK starts, raw-character/HUD defects, fixture isolation and
phone inset failures remain historical evidence, not passing new results.

Independent focused review verifies both walked approaches, native E race,
1/2 selection, G/drop/recovery, touch pickup/fire/switch/reload and actual native
inventory clearance. Final 750×381, 568×320 and stricter 567×299 phone views at
58-pixel inset pass bounds/text/reticle checks. Touch HIT readability used a
disclosed client-only fixture; two bounded real rifle aiming misses remain
misses. Actual fired damage is separately established by the passing P08
harness. Source-bound P06/P05/P14 regressions on unchanged core `75b1e88` pass
10/10, 8/8 and 6/6, including both full orbits. All reproduced production
findings are fixed and independently rechecked. The writer updated player,
contributor and package docs, current actual screenshot and D55–D58 defaults.

A5 would require disconnecting and rejoining the same actual identity in a
continuing round, verifying no restored life/equipment/actions while a teammate
retains the recovered launcher. Current helpers add another identity; service
tombstone tests cannot replace this real adapter/network check. D50 is P07-only.
The remaining gate needs real evidence or an explicit user-directed acceptance
revision. P09 is not promoted or implemented.

After collection, owned native sessions/fixtures were removed. The original
`tests.rbxlx` is Edit/not running, ManualHarness=nil, BootstrapStatus absent,
default simulator/LandscapeLeft restored. No merge or Roblox publication
occurred.
