# P14 edge visibility adjustment — 2026-11-12

The user approved the plane-relative orbit and requested visibility slightly
past each level edge, suggesting 25% of the viewport. The dedicated
`fix/p14-camera-edge-overscan` branch builds on unmerged PR #20. It replaces
the prior whole-viewport restriction with an allowance measured along each
horizontal and vertical centerline. At the 40° lens, the disk edge can reach
approximately 25% inward from the relevant screen edge. The circular boundary
can extend farther into screen corners. The 30° lens uses the same held focus,
so it shows less beyond the edge and zoom does not move the camera.

Corner rays remain downward and a tunable 80° maximum pitch avoids a perfectly
vertical view. The first actual Studio preview revealed sky beyond the authored
disk because there was no exterior ground. The candidate now creates a flat,
camera-owned visual backdrop below the disk. It is noncolliding, non-touchable,
nonqueryable, casts no shadow, does not replicate to the server, and is destroyed
on role loss or camera teardown. The ray limit also keeps all corners within the
backdrop's inscribed coverage throughout the orbit. It does not enlarge playable
or server-authorized targeting space.

## Verification

`python3 scripts/verify.py > build/p14-overscan-host.txt 2>&1` passed **49 unit /
18 integration** cases, formatting, lint, strict types, rejection probes, both
Rojo builds, geometry and release isolation. The tests hold all four directions,
verify the wide edge at the quarter-screen point and the narrower view reaches
past it, check diagonal corner coverage, reject invalid maps and preserve the
360-sample orbit-local view. The host log is [here](p14-edge-overscan/host-verify.txt).

The existing `PlayersVsC130Tests` test document (place 0, Rojo
`localhost:34872`) was synced and run in ordinary solo Studio Play. Baseline
TestEZ reports were **85 server / 3 client passed**, zero failed or skipped.
The log also contained three asset-type mismatch messages for
`rbxassetid://203785492`; they were present before this adjustment. Native W,
S, A and D holds at **1153×579**, 40° FOV, reached quarter-screen ground-ray
radii of **357.9–358.0 studs** on the 360-stud level; the corresponding outer
screen rays reached beyond 360 studs. Observed downward pitch ranged from
**21.3° to 78.8°**, with all corner rays pointing down. Switching to 30° after
a side pan retained the same local focus and the outer ray still reached
448.5 studs. The visual desktop review showed the perimeter and backdrop;
the aircraft silhouette can occupy part of the upper-left view at the far-up
limit. The [current capture](p14-edge-overscan/current-progress.jpg) shows the
side limit, with test and lobby overlays hidden locally.

An iPhone 17 Pro landscape simulation at **750×381** delivered a real held
PanUp touch. Focus moved from `(220, 0)` to `(1.797, 0)` at 40°; the actual
projected level boundary appeared approximately **21%** from the top, and the
backdrop remained visible beyond it. In a five-second held-view sample, aircraft
phase advanced about **20°**, the projection frame advanced 622 → 697, focus
remained unchanged and the plane-relative look components stayed stable. This
is focused evidence, not a complete operated orbit or multitouch acceptance.

An actual client ray filtered to the backdrop returned no hit, the server did
not see the local backdrop, and returning the solo preview to the lobby removed
both backdrop and thermal HUD and restored the Custom camera. The iPhone
simulator was reset afterward. A final fresh desktop Play on the refactored
candidate again measured a 358.0-stud quarter ray and the nonqueryable backdrop.
The six-scenario two-client P14 harness, full operated orbit, thermal-cover and
lifecycle acceptance remain open; these focused checks do not mark P14 complete.
