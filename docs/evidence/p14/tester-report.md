# P14 independent tester preparation

State: read-only preparation; no candidate implementation or engine checks accepted yet.
Base: main `10327b43638897aeacc6bc86187d8a31a392ce38`; task branch `plan/14-aircraft-panning`.
The developer currently owns Studio exclusively. Tester has made no Studio calls or tracked-file edits.

## Required evidence matrix

| Criterion | Required independent observations |
| --- | --- |
| A1 / R05,R15 | Full verify.py on unchanged candidate code. Pure production AircraftPanRules cases for center/dead zone, all edge/corner inputs, malformed/nonfinite values, huge and negative delta time, frame-rate independence, exact boundary inclusion/clamp, recenter, and a world-space focus unchanged by orbit/zoom. Sample actual canonical camera origins and finite inward directions, including focus at the nearest radial boundary. |
| A2 / R05,R06,R13 | Real client camera-ray hits reach center, four quadrants, useful near-boundary targets, terrain slopes and an upper-floor panel in each of Foundry/Warehouse/Outpost across a complete 90-second orbit at both acknowledged FOVs. Declare pixel/world tolerance before execution and retain same-frame viewport, reticle, focus, hit and profile snapshots. Independently compare actual raycast Instance/position, not a hard-coded Y=0 plane. Server rejects exterior/vertical-envelope/nonfinite endpoints and real solid muzzle obstruction, including camera-visible but muzzle-obstructed geometry. |
| A3 / R06,R12,R13 | Two actual client contexts, one real Gunship and one Ground. Pan via real client input path; server aircraft pose/orbit remains canonical and Ground camera/subject/FOV has no operator-driven change. Keys and buttons preserve world focus under coherent acknowledged labels/FOV/projection. Malformed/stale/replayed/unauthorized selections retain focus and selected profile; valid subsequent traffic works. No fire/cooldown behavior is claimed before P05. |
| A4 / R06,R12 | Rendered exposed/solid-covered thermal targets on terrain and upper floors at both zooms. Inspect inward extremes, diagonal edge pan and recenter; text focus, hover over actionable UI and window focus loss cannot cause uncommanded pan or trap input. Actual viewport/layout at 1280x720 and 1920x1080, recording simulator state and reverting it. Supplement numeric checks with operated full-orbit pan/zoom/recenter comfort notes and representative current gameplay capture. |
| A5 / R12,R15 | Actual reset/new-round/operator departure and repeated solo Operator/Ground preview/role entry. Default focus on fresh ownership; zoom does not recenter active ownership. Exactly one thermal HUD/controller/effect; all owned listeners cleaned, normal camera/FOV/mouse restored, no test transport/fixtures retained. Existing P04 orbit/selection and relevant round/preview regressions remain asserted, changing only fixed-center expectations superseded by P14. |

## Fixed acceptance boundaries

- Use actual stable source commit/tree, current Studio version/place, actual client counts and all-source fingerprint match before Play. A stale sync invalidates a run.
- Existing aircraft tolerances are 0.01 studs canonical engine pose, 1e-5 heading dot tolerance, <=2 studs live server heartbeat discrepancy and <=8 studs server-to-client replication comparison; retain observed maxima separately.
- New pan/projection tolerances must be declared by the candidate before running; a failure is not grounds to silently widen them.
- Reticle projection and UI geometry must come from the same rendered viewport/FOV, avoiding stale-frame comparisons.
- Zero discovered cases, skipped required cases, missing observations or client launch failures are incomplete evidence.
- Initial external OAuth metadata timeouts are diagnosed with bounded native logs. No blind repeated launch or new Studio application process. Reuse original instance `21f6fc11-4429-4148-9764-89a36987e5e9` only after parent handoff.

## Existing contract observations (not candidate defects)

The initial ThermalCameraController has fixed map-center look, central-70-percent reticle clamp and ground-plane-only projection. P04 client probes explicitly require exact central look, so this assertion must change to bounded inward focus while retaining canonical-origin/zoom/reticle/cleanup assertions. AircraftService.aimAllowed initially rays from hitbox center; P14 muzzle-line semantics require explicit coverage. No panning remote or second camera owner should be introduced.

No pass/fail result for P14 is claimed by this preparation record.

## Additional parent review probes queued for stable candidate

- Large finite translated maps and maximum finite endpoints: check every clamp/step output is finite or explicitly rejects, including derived subtraction/normalization/addition overflow. Radius-squared overflow must not make an invalid boundary comparison look valid. Do not assume a defect without reproducing it.
- Automated pointer injection must use the normal production controller boundary after destroying the original entrypoint cleanly. Confirm one live owner, then separately switch back to UserInputService for operated real mouse/keys/buttons evidence. Pure pointer injection is not physical input evidence.
- Observe horizontal edge movement at off-axis focus to assess camera-relative versus canonical-radial basis. Flag observable reversed/awkward controls, not an implementation preference.
- Declared new projection tolerance before candidate execution: <=1 pixel / <=0.5 stud, inward horizontal dot >=-1e-6, live canonical camera-origin discrepancy <=2 studs.

## Frozen candidate review — a326133

Exact candidate commit `a32613376599b38f787fe6484dc3e93a840ba935`, tree `6cd40a2507d554dc12fa7a731e121783314cde63`. Working tree was clean at review. Developer full host gate is reported passing in `build/p14-developer-verify.txt` (43 unit / 18 integration); I did not repeat that unchanged gate.

Read the actual production pan rules, controller/input/lifecycle, authored envelope validation, selected-muzzle LOS seam and both P14 harness sides. The fixture replaces the normal entrypoint after its Destroying cleanup and constructs one real RoundPanel with injected raw pointer/selection/recenter intent. It never assigns focus. Its physical toggle is not equivalent to the default native input provider because injected provider omits UI/window sampling; physical wiring/feel must use a fresh ordinary default-constructor session as agreed.

Independent pure probe: `/Users/markhanegraaff/.rokit/bin/lune run build/p14-overflow-probe.luau > build/p14-overflow-probe.json` exercised 73,205 clamp combinations over finite translations/endpoints through DBL_MAX and radii 360..1e308. There were 9,360 explicit rejections and zero nonfinite outputs. No derived-infinity defect reproduced.

Low-impact numeric observation: 64 huge-translated-map cases produced tiny positive relative disk overshoot after center re-addition (maximum squared-radius ratio 1.000000005670183). Example centerZ=1e10/radius360 has about 8e-7 stud radius overshoot. Current origin-centered map is unaffected, and the effect is far below declared engine tolerances. This is a pure API precision limitation, not a current gameplay defect or reason to change unrelated MapRules.

No material source defect is established by read-only review. Engine/rendered/input/replication evidence remains wholly open. Latest read-only Studio inventory exposes only unnamed instance `3115533b-a162-4a3b-a453-24ba1a187070`, not an identified project; no dependent tests were started.
