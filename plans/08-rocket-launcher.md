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

The launcher implementation is present on `plan/08-rocket-launcher`; acceptance
is not complete. [Draft PR #32](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/32)
contains source and evidence pushed at `5dae4b6`; its
[Verify CI run](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/43503117593)
passes. Latest tested runtime/test source is
`ef7826bc80310c17be4bcde93fe7607620303289`, tree
`db1f4e50296a2620d13e36839525c7562220a629`, based on integrated P07 main
`c7210be`. The [verification record](../docs/evidence/p08-launcher.md) preserves
exact commands, source-bound reports, earlier failures and cleanup.

| Criterion | Named tests / environment | Observed result and remaining work |
| --- | --- | --- |
| A1 | `LauncherService.spec` raced pickup/snapshot tests; full `python3 scripts/verify.py`; `Launcher.spec` representation engine case; ordinary native three-client E race | Host gate passes 55 unit / 65 integration and all static/build/geometry/isolation gates; fresh solo engine baseline passes. Native three-client pickup produces one owner/Tool with both rifles retained; full P08 harness remains pending |
| A2 | `LauncherService.spec` malformed/authority/reach/replay cases; shared movement/origin suites; P08 rejection harness | Deterministic rejection and shared engine checks pass. Actual three-client remote/ownership checks remain pending |
| A3 | Reload/transfer/recovery service cases; actual-Player `CharacterOwner.spec`; ordinary native three-client carrier death/removal/disconnect observations | Rules and fresh raw-character-destruction/cleanup engine tests pass. Actual death, raw Destroy and Kick followed by native teammate pickup preserve identity/reload, with replicated state agreement. Full P08 harness remains pending |
| A4 | Existing aircraft-health rules; launcher timing case; `Launcher.spec` first-solid/three-deduplicated-impact case; P08 fired-rocket scenarios | Rules and real engine sweep/health seam pass; player-fired three-rocket and mixed-fire multiplayer scenarios remain pending |
| A5 | Three-client `LauncherHarness`; real reconnect gate | Initial and staged SDK P08 launches connected only two and failed startup. Corrected ordinary native three-client observations verify raced acquisition and death/reset/disconnect recovery; they are separate from the full eleven-case harness. Actual same-identity reconnect remains required and unavailable through current helpers |
| A6 | Terminal/next-round service case; runtime cleanup/representation engine checks; P08 reset/teardown scenarios | Deterministic and engine baseline checks pass; actual multiplayer reset/late-intent assertions remain pending |

Independent fresh Studio 0.747.0.7471481 ordinary Play on `ef7826b` passes **156 server /
7 client** cases with one actual client, zero failures/skips/errors. The
eleven-case P08 harness and focused operated checks are distinct requirements.
The tester's original desktop HUD and raw character-removal defects are fixed
with semantic layout/inventory-clearance and exact lifecycle regressions, plus
actual three-client raw-destruction confirmation. An actual phone native-slot
overlap and later cross-ScreenGui inset collision prompted the final compact
touch header/common-coordinate correction. Actual 750×381, 568×320 and stricter
567×299 phone views at a 58-pixel inset pass collision, safe-bounds, text and
drawn-reticle checks. Native touch pickup/selection/fire/drop/re-pick/reload
passes; touch HIT readability is explicitly a client-only fixture, not damage
proof. Two bounded real rifle aiming attempts missed. Server/input rules are
unchanged from `75b1e88`, whose
fresh two-client P06/P05/P14 regressions pass 10/10, 8/8 and 6/6 respectively.
The intermediate fixture-isolation failure is preserved rather than called a
pass. The writer updated player/contributor/package docs and D55–D57 tuning
defaults (including D58) and refreshed the representative actual final-source
launcher capture. All material tester findings are resolved. Full eleven-case
P08 harness and actual same-identity reconnect remain pending; the original
test document is prepared for the user's stable native three-client handoff.
P09 has not started. No merge or Roblox publication is authorized by
this implementation work.
