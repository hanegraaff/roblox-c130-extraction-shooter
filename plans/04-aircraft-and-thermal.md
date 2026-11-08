# P04 — Perimeter aircraft and inward thermal view

**Milestone:** M2. **Dependencies:** P03. **Requirements:** R05, R06, R12, R15. Status: [roadmap](../roadmap.md).

## Capability and player experience

Ground players see a C-130 circle the map's perimeter. The operator's thermal view always faces inward toward the main map. Choosing the 30mm or 105mm profile changes zoom; live firing arrives in P05.

## Implementation

Add an aircraft model with documented canonical hitbox/muzzle attachments and server-owned anchored circular movement. Use map center/radius/altitude to compute orbit and tangent. Separately orient the camera toward the ground-level map-center focus at all phases. Let the player move the reticle inside the view; do not add free camera yaw/pitch or independent zoom. Provide distinct FOV profiles and named selection UI for the 30mm GAU-23/A Chain Gun and 105mm M102 Howitzer, with tighter 30mm zoom. Keep role-authorized selection state coherent with presentation. Use occluded thermal highlights and restore camera/effects on role change. Keep MVP streaming disabled per D11.

## Acceptance criteria

- **A1:** Full gate passes. Orbit tests cover periodicity, phase wrap, altitude, equal map/orbit radius, tangent orientation and invalid configuration with injected time and documented tolerances.
- **A2:** At sampled phases over a full orbit, engine checks match canonical aircraft pose to the perimeter and camera look direction to the map-center focus; model heading remains tangent. Reset returns to initial orbit/view state.
- **A3:** Two clients see the aircraft and battlefield with documented pose convergence tolerance. Any cosmetic smoothing shell is noncollidable and cannot define a second gameplay pose.
- **A4:** Unit/engine tests verify finite distinct FOVs, `FOV30mm < FOV105mm`, selection/HUD/reticle coherence, and inward look direction during both zoom levels and transitions. Stale/rejected selection cannot leave the wrong view active.
- **A5:** Exposed targets receive the thermal effect; solid cover occludes them. Out-of-map aim endpoints reject. Role loss/disconnect/reset restores camera/input/post-processing and removes highlights/listeners; repeat entry creates one controller.

## Focused human check

Inspect the aircraft from the ground and thermal view over a full orbit with both weapon profiles. Verify understandable magnification, reticle stability and cover occlusion. Weapon firing is still pending.

## Documentation changes

Update named weapons, selection-linked zoom, inward-facing view, controls and orbit/model attachment contracts.

## Completion record

### Selection and verification scope

2026-11-08: selected P04 on `plan/04-aircraft-and-thermal` from integrated `main` commit `27f488e`. P03 and the human-testing controls are already integrated; no dependency branch is required. The workspace was clean and GitHub had no open plan PR at selection.

Required evidence is the full host gate, real-engine canonical pose/camera/reset checks, two actual client contexts with measured pose convergence, both weapon profiles and rejected-selection coherence, exposed/covered thermal fixtures, bounded aim rejection, and repeated role/controller cleanup. Focused full-orbit review and a representative actual playtest capture supplement the automated gates. The verified results follow.

### Candidate and implementation

Initial candidate source is `33e7b1da953809c57a42bf4c47166eaca917d753`, tree `f3b5db0a210617104e64519c63e4e95bfd42ef9f`. The original primitive C-130 template is versioned in `assets/models/C130.model.json` and the manifest. `Hitbox` is the sole queryable canonical part/model pivot; `GAU23Muzzle` and `M102Muzzle` are its named attachments. All parts are anchored and noncolliding; decorative parts are nonqueryable. There is no smoothing shell or second gameplay pose.

The default orbit takes 90 seconds with increasing phase from positive X toward positive Z. It shares the map's 180-stud radius and 140-stud altitude. The separate camera always looks at ground-level map center. GAU23 uses 35° FOV and M102 uses 60°; the reticle is bounded to the central 70% of the viewport. Selection changes only after the server's atomic selection acknowledgement. The test-only solo Operator preview permits cosmetic profile inspection without creating an active role. Live firing, damage, ammunition and cooldowns remain P05+ work.

The two-client harness defines an eight-stud pose convergence tolerance, equivalent to approximately 0.64 seconds of motion at the default 12.57 studs/second. Canonical injected-time engine pose checks use 0.01 studs for CFrame precision; the live server comparison permits two studs between Heartbeat updates. The actual maximum observed two-client pose difference was 0.4237336218357086 studs.

### Acceptance evidence

Final source is `b27f738e84c2f87eb25ff402c235b7a91ad82458`, tree `13617b93d55381683ebbdaae027b08e7c32cbae9`. The delta from the full orbit candidate is two UI strings and module comments only. [Evidence overview](../docs/evidence/p04-aircraft-and-thermal.md), [final source/build manifest](../docs/evidence/p04/source-manifest.json) and [original orbit manifest](../docs/evidence/p04/orbit-source-manifest.json) retain exact source/build identities and the different verification scopes.

| Criterion | Named tests and actual environment | Observed result |
| --- | --- | --- |
| A1 / R05, R15 | `AircraftRules.spec.luau`: periodic/negative wrap, perimeter/unit tangent, nonfinite/config/derived-overflow rejection; final `python3 scripts/verify.py` on macOS arm64, Python 3.10.4 | 30 unit / 18 integration, zero failures/skips; format/lint/strict types, rejection probes, both builds, 128 authored parts per artifact, corruption probes and release isolation pass. Five independent adversarial probes also pass. |
| A2 / R05, R06 | Studio `Aircraft.spec.luau` canonical perimeter/tangent/muzzle/reset case: 17 injected-time phases; P04 actual two-client harness initial profiles, nine paired samples over 90 seconds and two-round reset/reentry | Pass. Aircraft pose follows the perimeter/tangent; operator camera stays inward through both FOVs and transitions. Reset restores initial orbit/profile and normal view when no longer operator. |
| A3 / R05 | MCP `ExecuteMultiplayerTestAsync(2, {kind = "P04"})`, two distinct actual network clients; canonical server/paired client pose checks and ground-level inspection | Pass. Maximum observed difference 0.4237336218357086 studs, below 8-stud bound. One anchored queryable gameplay pose; no smoothing shell. Actual aircraft silhouette visible from the ground. |
| A4 / R06, R12, R13 | Six pure aircraft cases, four `AircraftSelection.spec.luau` service cases, actual remote invalid-profile/stale/replay/malformed/wrong-role scenario; focused final keys 1/2 and both named buttons | Pass. Acknowledged GAU23 = 35°, M102 = 60°; label/FOV/reticle agree, inward dot within about `1.2e-7` of 1. Rejections leave the acknowledged profile unchanged; subsequent valid traffic succeeds. |
| A5 / R06, R12 | Actual server aim ray fixture; P04 exposed/covered geometry and thermal assertions; independent rendered enclosed-target/cover-removal review; reset/role-rotation/disconnect/teardown scenarios and operated return to Ground | Pass. Exterior/nonfinite/solid-blocked aim rejects. Covered target stays hidden, then highlights after cover removal. Camera/FOV/mouse restore; highlights/HUD/effect/input listeners clear; repeat entry owns one HUD/effect. Actual operator departure forfeits and aircraft resources reach zero. |

Independent host log: [30/18 full gate](../docs/evidence/p04/independent-verify.txt). Final host log after label/comment corrections: [30/18 full gate](../docs/evidence/p04/final-verify.txt), command `python3 scripts/verify.py > build/p04-final-verify.txt 2>&1`. Deliberate failing/empty/type/geometry probes reject as intended; these are not production failures. All 51 first-party mapped scripts match Studio for each tested source.

The [multiplayer report](../docs/evidence/p04/studio-report.json) has six discovered/passing scenarios, zero failed/skipped cases, two actual clients and two rounds. Its baseline has 57 server / 2 per client, zero errors/failures/skips. The baseline server recorded one client while clients were joining; the harness separately waited for two. Final source received a fresh one-client 57 server / 2 client baseline plus operated review. Studio was `0.746.0.7461269`, place 0, existing document `p02-tests-5c809beff70b.rbxlx`, project `PlayersVsC130Tests`, Rojo port 34872. All sessions ended in the original Edit document.

### Review and limitations

The [independent tester](../docs/evidence/p04/tester-report.md) found no remaining material functional defect. Pre-candidate review corrected derived orbit overflow and forced same-ID Lobby profile reset; tests cover both. The stale aircraft-planned status label found during actual rendering is corrected in final source. Singleton/input restoration assertions were strengthened before the committed candidate. Client input-listener disconnection is source-inspected; engine checks observe restored presentation, while server teardown directly reports zero owned aircraft connections. [Focused final observations](../docs/evidence/p04/focused-review.json) retain the actual controls, renderer fixtures and cleanup results.

The technical writer reviewed actual source/tests and the current screenshot, updating 17 player/contributor/package documents. The root guide selects the unmerged P04 branch, describes both current role views and controls, preserves setup/test instructions, and labels combat/launcher scope as planned. Repository-link and whitespace checks pass after the prose updates.

Observed prototype limits are upper-view HUD overlap and an aircraft strip in the upper-left sky at wide FOV; neither blocked the central targeting area in the review. The test panel occupies the lower-right screen. Full combat, damage, cooldowns/reload, launcher, balance and 6/10-player release capacity are outside P04 evidence. No merge or Roblox publication occurred.

### GitHub delivery

Source `b27f738` and documentation/evidence commit `7d9e200c7fcf687445562b77fe541ef6873b4d0a` are pushed to `origin/plan/04-aircraft-and-thermal`. [PR #9](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/9) targets `main` and is open for review, unmerged. Subsequent delivery/status/link edits are prose only and run the repository checker before commit/push. Tested runtime/configuration/assets remain unchanged after `b27f738`.

[GitHub Verify run 42526282440](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/42526282440) passes on pushed candidate `7d9e200`. The final local complete gate is preserved above; repository and whitespace checks also pass after the final delivery records.

P05 is the next eligible increment; it has not been implemented. Until PR #9 is integrated, dependent source must include this branch rather than stale `main`. No Roblox publication occurred.
