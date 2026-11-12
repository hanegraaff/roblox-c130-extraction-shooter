# P05 combat candidate: verification record

These source-specific observations trace P05's development, including failed
intermediate candidates and the independently verified final source. The
independent tester used local `tests.rbxlx` Studio documents and two actual
clients when the multiplayer launcher successfully connected both. The
[integration record](p05-integration.md) records the merge and fresh main gate;
the candidate hashes below describe the source actually tested in each run.

## Host and Studio observations

| Candidate | Environment and result | Scope and limitation |
| --- | --- | --- |
| `b4e8d61` | `python3 scripts/verify.py`: 50 unit, 22 integration, all non-Studio gates passed. Studio smoke: server 90/90 with one client, client 3/3. Two-client P05 harness: 3/3. | Review found a material defect: an endpoint with no world collision could detonate. The three multiplayer cases did not establish all P05 criteria. |
| `5a83732` | Full host gate and Studio smoke: 50/22 and 90/3 respectively. Two two-client P05 attempts each returned 2 passing, 2 failing including harness completion. | The new no-airburst test compared a previously wounded character's health for exact equality. The enabled built-in `Health` script can regenerate that health; the report did not capture enough values to establish whether the failure was healing or damage. Later scenarios did not execute. |
| `96f0fae` | The fixture disabled the test character's built-in `Health` script and recorded health, ray and impact values. Host gate: 50/22. | A multiplayer launch connected only one client and timed out before scenarios; server smoke passed 90/90. A single clean retry stalled before Play, leaving an SDK-created read-only Edit document open. No acceptance result exists for this candidate. |
| `03eaacf` | Full host gate passed: 50 unit, 22 integration, builds, geometry and artifact-isolation checks. In one-client Studio, a disposable production-runtime/remote probe found no impact from an unobstructed airborne endpoint; a shot 0.1 studs above a real Part hit its top through the 0.25-stud sweep continuation. Server smoke: 90/90. | The probe used a fake match and fixed muzzle, not real roles or multiplayer. The pending SDK retry contaminated ordinary Play arguments; client smoke failed 2/3 with the round runtime absent. Updated two-client scenarios, actual player damage and feel are unverified. |
| `b039156` | Independent `python3 scripts/verify.py` passed: 50 unit, 27 integration and all non-Studio gates. The tester also ran `lune run scripts/run_tests.luau integration`: 27/27. | Added deterministic damage clamping/deduplication and cadence/reload boundary tests. The tester found no new material defect by source review. This revision has no Studio evidence. |
| `f1982bb` | Full `python3 scripts/verify.py` passed after documentation updates: 50 unit, 28 integration, all non-Studio gates. Independent `lune run scripts/run_tests.luau integration`: 28/28, zero failures or skips. | Adds deterministic lifetime and distance boundaries for both profiles. The tester found no regression in the delta; the following row records subsequent Studio checks. |
| `f1982bb` | After closing both prior Studio windows, the guarded launcher opened the rebuilt `tests.rbxlx`; the sole new document matched the source. Fresh server smoke passed 96/96 and each of two actual clients passed 3/3. P05 multiplayer passed 6/6 with two actual clients, zero failures or skips. [Structured report](p05-studio-f1982bb.json). | Airburst, thin cover, rejected requests, heavy reload, result/reset, and both weapons on sloped Terrain and a second-story panel passed the named scenarios. Live expiry and complete view-envelope coverage remain separate questions. |

## Operated desktop and touch review

In a real two-client active round, native desktop input selected both weapon
profiles, fired the heavy weapon, held the 30mm for repeated shots, retained the
heavy reload across rapid switching, and panned with A. On iPhone 17 Pro Studio
simulation (landscape, 750×381), actual simulated touch on FIRE with an
independent aiming touch fired, and simultaneous FIRE + PanRight reduced 30mm
ammo from 85 to 78 while the orbit-local focus moved from `(220, 0)` to
`(220, -139.97)`; both touches ended and pan returned to neutral.

The independent tester reported material presentation problems: with default
afternoon Lighting, terrain/buildings were nearly black and 30mm/105mm warning
and impact effects looked like similar white dots/blobs; the central round HUD
obscured targeting on desktop. On the phone, the round and thermal HUDs
overlapped and the default joystick intersected the directional pad and weapon
button. These actual Studio captures show the [desktop](p05-presentation/desktop-before.jpg)
and [mobile](p05-presentation/mobile-before.jpg) state before correction. The
test-only session panel was hidden, while the product HUD remained visible.

Candidate `000ebe3` improved the thermal and operator HUD presentation. The
independent reviewer found the desktop view and 105mm warning readable, and
the simulated phone operator layout clear. Actual dual touch fired while panning
and separately while aiming; returning to Ground restored the original TouchGui.
The pre-existing Ground HUD remains large. However, the updated two-client P05
harness failed its heavy terrain impact wait: 5 cases passed, with that case and
the harness-completion case failing. [Structured report](p05-studio-000ebe3.json).

Diagnostic fixture `b47317a` then passed 6/6 in the developer's two-client
run, but the independent two-client run failed the first GAU23 slope impact.
The shot was accepted (ammo 100→99), spawned and traveled, then disappeared
without impact. Its preflight ray hit Terrain from muzzle `(363.8083, 138,
30.2909)` toward `(-263.99924, 13.56503, -159.99977)`; the actual launch
muzzle had moved to `(363.7364, 138, 31.1414)`. The
[two diagnostic reports](p05-studio-b47317a.json) preserve the samples. This is
an unresolved intermittent surface-shot defect, not a passing acceptance test.

Candidate `b53d683` attempted to address the miss with 0.5-stud GAU23 and
2-stud M102 swept spheres and added a real-engine collision regression. Fresh
Studio smoke failed 97/98 server cases because the GAU23 reproduced-terrain
case missed; client smoke was 2/3 after the server fixture failed. The
two-client suite did not run. A separate real Studio probe found a thin wall
already overlapping a sphere's start was ignored by Spherecast. On the grazing
terrain trajectory, these radii also hit approximately 8.7 and 14.8 studs early,
outside the existing 5-stud target-distance assertion. Smaller radii produced
5.552, 4.095, 2.118 and 0.844-stud errors at radii 0.2, 0.1, 0.05 and 0.02
respectively. This candidate is not accepted and requires correction.

On `0406805`, a narrower 0.05-stud sweep and initial-overlap check passed
98/98 Studio server smoke cases. Client smoke did not produce a report, and a
single two-client SDK launch stalled before Play. The tester identified a further
cover issue: a real Studio ray from inside a disposable 10-stud wall toward the
far side returned nil, whereas a ray from outside hit it. Since the overlap
impact's blast-visibility origin could remain inside the wall, that could permit
splash through cover; the actual player-damage path was not reproduced. Voxel
Terrain was also outside the BasePart overlap query. These observations need
correction and a fresh engine and multiplayer run.

On `5cff1b2`, host verification passed 50 unit / 32 integration and fresh
Studio smoke passed 103/103 server and 3/3 client, including 600 comparisons
with real CFrame rays. The independent two-client run passed its first four
cases and then failed its reset fixture's search for a permitted view, with a
second failure from harness completion. The subsequent slope, overlap-victim
and live-expiry cases did not run; see the [report](p05-studio-5cff1b2.json).
An independent phase-zero probe found the far elevated fixture target reachable
with M102 but not with the searched GAU23 view, suggesting its later reuse for a
stale GAU23 request is a fixture issue; the original run did not record enough
to prove which payload failed. The tester also measured an avoidable expensive
view calculation from an unauthorized extreme-aspect request; role validation
and cost need attention before acceptance. The view claim is bounded but remains
client supplied, with a symmetric 1.25-second orbit-pose tolerance.

On `232889f`, the independent reviewer confirmed the early role rejection and
bounded aspect cache changes, with host integration 33/33. The coordinator ran
the complete `python3 scripts/verify.py` gate: 50 unit / 33 integration, all
non-Studio checks passed. In fresh Studio, server smoke passed 104/104 (one
client present when it finished), and each of two actual clients passed 3/3.
The [two-client P05 report](p05-studio-232889f.json) passed all eight cases,
including both weapons on slopes and second-floor panels, no airburst, thin and
embedded cover, real ground-player health protection, stale/reset behavior and
the injected-clock real-Instance projectile expiry boundary and cleanup. The
M102 slope impact was approximately 4.27 studs from its target, within the
declared 5-stud limit.

Native desktop input on `232889f` panned with A and fired GAU23 (ammo 100→94);
switching to M102 preserved pan, acknowledged 40° FOV and produced an impact.
On a simulated iPhone 17 Pro in landscape (750×381), actual FIRE + independent
world touch spent five rounds and moved the aim pointer; FIRE + PanRight spent
seven rounds while focus moved `(220, 0)`→`(220, -139.97)`, then both touches
ended and pan returned to neutral. The operator layout, thermal contrast and
heavy warning improvements were independently inspected on the unchanged
presentation source `000ebe3` and again on `232889f`. The [current representative
capture](p05-presentation/current-progress.jpg) is an actual active two-client
105mm view on `232889f`, with the test-only panel hidden.

In the focused rendered-effects review on `232889f`, the independent tester
fired both weapons at their 30°/40° views. The 105mm produced a broad pale
warning disc, a separate bright round projectile and a large impact flash; the
30mm produced smaller, closely spaced flashes. These [30mm](p05-presentation/30mm-impact.jpg)
and [105mm](p05-presentation/105mm-impact.jpg) actual impact captures show the
size difference. The tester could distinguish the weapons by size and cadence;
individual 30mm warning and projectile phases were difficult to separate during
a burst. The test-only panel was hidden and the production HUD was retained.

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

The original operator thermal and HUD defects were corrected and rechecked.
The view protocol validates a permitted client-claimed focus/aspect and pose,
with a symmetric 1.25-second allowance; it does not attest the exact physical
client camera. The current authored level places the aircraft above terrain,
but the muzzle-overlap check covers BaseParts rather than voxel Terrain. Future
level validation must prohibit terrain overlapping the muzzle or handle it.
The pre-existing Ground HUD remains large on a phone. Fine separation of the
rapid 30mm warning/projectile phases is a presentation improvement for later
polish rather than a claim that those phases were individually legible.
