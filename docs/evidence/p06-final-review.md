# P06 final independent verification

The feature tester reviewed runtime/test source
`0ab360775bdd7d97a2654aa3b6857ddbc3d6157e`, tree
`3d6bb3fd49629f66d12e31f921975a151607714f`; gameplay is unchanged from
`59252c9`. The primary agent recorded this consolidated report from the
tester's final results. Later changes are documentation and evidence only.

| Check | Actual result and environment |
| --- | --- |
| [Fresh P06](p06-final-0ab.json) | Native Server & Clients, two real clients; 10/10, zero failed/skipped. Fresh server smoke 118/118 with two players and 6/6 on each client. First arrival 7.320930 seconds. |
| [P06Team](p06-team-0ab-restart.json) | Three actual clients; 7/7, fresh server 118/118 and 6/6 per client. Distinct controlled exact-source runner restart with already-connected players after prior owners stopped. |
| [P05 regression](p06-p05-0ab.json) | Full unchanged suite, two real clients; 8/8, zero failed/skipped. |
| [P14 regression](p06-p14-0ab.json) | Full unchanged suite, two real clients; 6/6, zero failed/skipped, including two complete 90-second weapon orbits and actual operator departure. |
| [Desktop user review](p06-user-0ab.json) | User reports visible tracers, crosshair alignment, aircraft damage and no issues. Twelve paired real requests include health 195→155; actual current screenshot committed. |
| [Simulated phone](p06-phone-0ab.json) | iPhone 17 Pro landscape: touch fire/reload, separate camera swipe, centered reticle and nonoverlapping HUD. Simulator restored; no physical-device claim. |
| [Host gate](p06-final-host.json) | Primary agent's complete `python3 scripts/verify.py`: 50 unit / 43 integration, plus required static/build/geometry/isolation and deliberately rejected negative probes. |

The current P06 run verifies both actual callback orders in the same simulation
frame with equal Heartbeat deltas, resolving Ground/AircraftDestroyed. Pristine
rocket sweeps produce 300→200→100→0; mixed damage, replay/miss rejection, cover,
visual rifle/tracer, origin/query failure without mutation, same-sequence
recovery, reset and teardown pass. Actual server-initiated operator departure
uses the separate forfeit result and leaves one client.

Material findings are resolved: the false GUI-inset assumption was replaced
by independent native/world pixel oracles and corrected production projection;
the user accepted shot/health feedback and held rifle; current collision,
same-step results, mobile layout and cleanup checks pass. The original failed
tests and contaminated native three-client launch remain separately preserved
in the [chronological evidence](p06-ground-combat.md). The passing controlled
restart does not relabel that original launch as a pass.

The actual server ended the final simulation after reports were saved. MCP
confirmed only the original `tests.rbxlx` document in Edit, test selector and
SDK arguments nil, diagnostic Workspace startup/report attributes nil, and no
retained live test/runtime owners.

Remaining scope limits are documented rather than acceptance failures: movement
budgets bound endpoints without sweeping intervening walls; unusual terrain and
severe latency need broader later playtests; delayed first arrival beyond ten
seconds under the revised budget was not exercised. Physical phones, production
6/10-player capacity, release publication, the map launcher and panel/fragment
destruction belong to later work. No merge or Roblox publication is part of
this verification.
