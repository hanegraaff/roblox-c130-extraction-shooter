# P05 combat candidate: verification record

These observations concern the unmerged P05 branch and do not establish plan
acceptance. The independent tester used the existing local `tests.rbxlx` Studio
document (`2e0d8288-c6fb-428d-9b98-a2ab2110c775`) and two actual clients when
the multiplayer launcher successfully connected both. Source hashes below are
candidate commits, not claims about later changes.

## Host and Studio observations

| Candidate | Environment and result | Scope and limitation |
| --- | --- | --- |
| `b4e8d61` | `python3 scripts/verify.py`: 50 unit, 22 integration, all non-Studio gates passed. Studio smoke: server 90/90 with one client, client 3/3. Two-client P05 harness: 3/3. | Review found a material defect: an endpoint with no world collision could detonate. The three multiplayer cases did not establish all P05 criteria. |
| `5a83732` | Full host gate and Studio smoke: 50/22 and 90/3 respectively. Two two-client P05 attempts each returned 2 passing, 2 failing including harness completion. | The new no-airburst test compared a previously wounded character's health for exact equality. The enabled built-in `Health` script can regenerate that health; the report did not capture enough values to establish whether the failure was healing or damage. Later scenarios did not execute. |
| `96f0fae` | The fixture disabled the test character's built-in `Health` script and recorded health, ray and impact values. Host gate: 50/22. | A multiplayer launch connected only one client and timed out before scenarios; server smoke passed 90/90. A single clean retry stalled before Play, leaving an SDK-created read-only Edit document open. No acceptance result exists for this candidate. |
| `03eaacf` | Full host gate passed: 50 unit, 22 integration, builds, geometry and artifact-isolation checks. In one-client Studio, a disposable production-runtime/remote probe found no impact from an unobstructed airborne endpoint; a shot 0.1 studs above a real Part hit its top through the 0.25-stud sweep continuation. Server smoke: 90/90. | The probe used a fake match and fixed muzzle, not real roles or multiplayer. The pending SDK retry contaminated ordinary Play arguments; client smoke failed 2/3 with the round runtime absent. Updated two-client scenarios, actual player damage and feel are unverified. |
| `b039156` | Independent `python3 scripts/verify.py` passed: 50 unit, 27 integration and all non-Studio gates. The tester also ran `lune run scripts/run_tests.luau integration`: 27/27. | Added deterministic damage clamping/deduplication and cadence/reload boundary tests. The tester found no new material defect by source review. This revision has no Studio evidence. |
| `f1982bb` | Full `python3 scripts/verify.py` passed after documentation updates: 50 unit, 28 integration, all non-Studio gates. Independent `lune run scripts/run_tests.luau integration`: 28/28, zero failures or skips. | Adds deterministic lifetime and distance boundaries for both profiles. The tester found no regression in the delta, but live projectile expiry and the latest damage integration have not been exercised in Studio. |

## Focused single-client collision probe

On `03eaacf`, the tester started production `CombatRuntime` with a disposable
fake active match, fixed muzzle `(100, 140, 0)`, a real `RemoteEvent` and a
6×2×6 anchored Part centered at `(0, 20, 0)`. A client fired GAU23 at an
unobstructed airborne endpoint `(20, 30, 0)`: ammo decreased from 100 to 99,
with no impact callback and no remaining effects. Its second request targeted
`(0, 21.1, 0)`; ammo fell to 98 and server impact shot 2 was reported at
approximately `(-0.0841, 21, 0)`, on the Part's top face. Preflight rays to
both requested endpoints found no obstacle. The fixture was removed when its
owned Play session ended. These checks do not prove player health, real role
authorization, or replication between two clients.

## Outstanding evidence

The current candidate still needs a successful full two-client P05 run, both
weapon profiles against real cover, slopes and upper floors, terminal and
next-round cleanup, and matching shot/health/result observations. The actual
operator must also exercise panning, firing, switching and thermal readability,
including touch controls. Live projectile expiry, actual damage/clamping and
the server-side view envelope need complete acceptance coverage. A fresh
representative screenshot of the visible combat candidate is also required.
The pending SDK launch has no documented Edit-mode cancellation; do not open
additional Studio documents to work around it.
