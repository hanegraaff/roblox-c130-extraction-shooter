# Perimeter aircraft and inward thermal view

2026-11-08. P04 introduces a server-owned primitive C-130 on the map perimeter, an inward thermal operator view, bounded aiming reticle and acknowledged 30mm/105mm selection with distinct zoom. Combat and aircraft damage remain planned. The [plan record](../../plans/04-aircraft-and-thermal.md) maps A1–A5 to acceptance evidence. The [independent tester report](p04/tester-report.md) and [final focused observations](p04/focused-review.json) retain verification scope and findings; temporary `build/p04-*` paths in that report identify the original artifacts, whose retained copies are linked here.

## Candidate identity and environment

The full two-client orbit harness ran on source `33e7b1da953809c57a42bf4c47166eaca917d753`, tree `f3b5db0a210617104e64519c63e4e95bfd42ef9f`. The final source is `b27f738e84c2f87eb25ff402c235b7a91ad82458`, tree `13617b93d55381683ebbdaae027b08e7c32cbae9`: only two player-facing strings and module comments changed afterward. No orbit, selection, camera logic, authored model, project mapping or test changed. Final source received a fresh complete host gate, source-sync check and operated Studio review.

[Final source/build manifest](p04/source-manifest.json) and [original orbit manifest](p04/orbit-source-manifest.json) retain exact artifact SHA256 values. [Final source signatures](p04/source-signatures.json), [original signatures](p04/orbit-source-signatures.json) and [sync result](p04/source-sync-result.json) identify all 51 first-party mapped scripts. Both source checks matched actual Studio byte counts and Adler32 with no mismatches.

Environment: macOS arm64, Python 3.10.4, repository-pinned tools, Studio `0.746.0.7461269`, place 0. The same local document `p02-tests-5c809beff70b.rbxlx`, MCP instance `21f6fc11-4429-4148-9764-89a36987e5e9`, received `PlayersVsC130Tests` through the existing Rojo connection on `127.0.0.1:34872`. The historical document filename does not identify its current source.

## Automated evidence

- Independent `python3 scripts/verify.py > build/p04-independent-verify.txt 2>&1` passes **30 unit / 18 integration** cases on the orbit candidate; [log](p04/independent-verify.txt).
- Final `python3 scripts/verify.py > build/p04-final-verify.txt 2>&1` passes the same **30 unit / 18 integration** cases on final source. Formatting, lint, strict Roblox-aware analysis, intentional failing/empty/type probes, both builds, 128 authored parts per build, five geometry-corruption probes and release isolation pass; [final log](p04/final-verify.txt). The release contains 21 runtime scripts and no test/control overrides.
- Five independent disposable probes pass under `$HOME/.rokit/bin/lune run build/p04-adversarial.luau`: translated/elevated map and heading, extreme finite times, FOV boundaries, cyclic/large malformed selection payloads without mutation, and forced same-ID reset with a fresh sequence. [Probe source](p04/adversarial-probes.txt), [results](p04/adversarial-results.json).
- Studio MCP `StudioTestService:ExecuteMultiplayerTestAsync(2, {kind = "P04"})` passes **6/6 scenarios**, zero failures/skips, with **two actual clients** and two rounds. It samples both clients nine times over the complete production-speed **90-second orbit**. Maximum observed pose difference is **0.4237336218357086 studs**, against the declared 8-stud convergence bound. The [structured report](p04/studio-report.json) retains every scenario and observation.
- The harness's baseline passes **57 server cases / 2 cases per actual client**, zero errors/failures/skips. Its baseline server report recorded one connected client while clients were joining; the separate harness explicitly awaited two. These counts are not interchangeable.
- A fresh ordinary Play on final source again passes **57 server / 2 client** baseline cases with one actual client, followed by focused input/render/cleanup checks. Those observations are supplemental experience evidence, not additional TestEZ case counts.

The real-engine Aircraft suite samples 17 canonical phases with injected time, checks altitude/perimeter/tangent/attachments/query flags and reset, and exercises clear, solid-blocked, exterior and nonfinite aim. Selection tests and actual remotes reject stale, repeated, malformed, unknown and wrong-role input without changing the acknowledged profile. The two-client harness also verifies both zooms, thermal fixtures, repeated singleton entry, restored input/camera/effects, actual operator departure/forfeit and complete server teardown.

## Operated review and captures

The automated clients used 1081×658 viewports with graphics Automatic. Final solo review used 1081×619, Automatic. Actual keys **1 / 2** and both named buttons selected 35° GAU23 / 60° M102 coherently; measured inward direction stayed within approximately `1.2e-7` of dot 1. The camera remains fixed inward while the mouse moves the reticle. No aircraft-body clipping into the central targeting area was observed.

An independent temporary render fixture showed an exposed white target and a fully enclosed target. The enclosed target did not highlight through its solid walls/roof; removing that same cover revealed the second white body, and real obstruction rays changed from the wall to the target. [Covered capture](p04/thermal-occlusion.jpg), [cover removed](p04/thermal-cover-removed.jpg). This supplements the actual raycasts and `HighlightDepthMode.Occluded` assertions with renderer evidence.

The [representative capture](p04/current-progress.jpg) is an actual final solo Operator preview with the corrected labels, reticle and profile controls; chat was hidden only in that capture client. The [ground-level aircraft inspection](p04/ground-aircraft-inspection.jpg) shows the real replicated primitive silhouette using a temporary inspection camera and hidden HUD. Neither inspection change is part of the shipped source. All temporary fixtures and camera bindings were removed.

Returning through the actual Role button restored Custom camera, original 70° FOV, Default mouse, visible pointer, zero thermal highlights and no thermal HUD/post-processing. The multiplayer harness separately verified reset/role rotation and teardown. Every launched session ended; the final inventory contained only the original document in Edit, with the Rojo connection retained.

Client input-listener disconnection was source-inspected; engine observations verify the resulting UI/effect/camera state rather than directly counting RBXScriptConnections. Server teardown explicitly reports zero owned aircraft connections. Fresh multiplayer Output included the passing baseline and a pre-existing avatar asset warning for `rbxassetid://203785492` (asset type mismatch), with no first-party runtime failure.

## Findings and limits

Pre-candidate review corrected derived orbit overflow and a same-round Lobby reset retaining the previous profile, with regression coverage. The tester's material presentation finding was a stale status label claiming the aircraft was still planned; final source corrects it. Module headers and the thermal caption were also clarified. No material finding remains open.

The prototype round card covers part of the upper view. The 60° camera can include an opaque strip of the aircraft in the upper-left sky; the observed strip did not block the central battlefield/reticle. The test-only control panel also shares the lower-right screen area. These presentation limits are documented for later HUD work. Art is an original primitive model, and ordinary server replication has no smoothing shell.

This evidence establishes local P04 behavior, not firing, damage, weapon cooldowns, launcher gameplay, balance, release capacity or cloud readiness. Feature validation used no production player data and did not publish to Roblox; subsequent GitHub integration is recorded below.

## GitHub delivery

Source `b27f738` and documentation/evidence `7d9e200c7fcf687445562b77fe541ef6873b4d0a` were delivered on `plan/04-aircraft-and-thermal`. With explicit user authorization, [PR #9](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/9) merged into `main` at `da1327ac60425c544b7f2804107bb318fe9490dd`. The [integration record](p04-integration.md) verifies identical checked/merged source and a fresh passing host gate with matching builds. Follow-up delivery records change prose only. The [roadmap](../../roadmap.md) owns status; P05 is eligible but unimplemented and can branch from `main`.

[GitHub Verify run 42526282440](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/42526282440) completed successfully on `7d9e200`. Repository and whitespace checks pass after the final link/status records.
