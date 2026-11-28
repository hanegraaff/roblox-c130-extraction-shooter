# P29 — Rocket launcher model in play

**Depends on** P25 and rocket launcher reference art. **Requirements** R27. [Roadmap](../roadmap.md#public-mvp-launch) · [Requirements](../requirements.md)

The same original launcher is recognizable on the ground and in a player’s hands.

## Work

- Use the approved [depot launcher references](../src/images/rocket-launcher/). Match the muted sand, graphite and teal exterior. Use the carried view to judge the prop's size against a Roblox avatar. Save one editable master at `assets/blender/rocket-launcher/rocket-launcher.blend`. Create pickup and equipped presentations from it with an avatar-sized grip and a consistent visual firing point.
- Use LauncherRuntime and LauncherGeometry for placement, equipping and transfer. Each of the four existing sites keeps its own identity, ready time and drop/recovery behavior. Register the export, materials and managed source in the manifest.

## Acceptance

1. **A1 · Asset and fit.** Verify a clean build and inspect all four pickup placements. Check grip, clipping, floor contact, scale and muzzle effect alignment from desktop and phone views.
2. **A2 · Transfer and fire.** Use three Studio clients to pick up, aim, fire, hand off while cooling, lose a carrier and recover a launcher. Check the visible held/dropped state on both Ground clients, one owner, the correct firing origin and independent readiness.
3. **A3 · Replay.** Check that each site resets with one loaded launcher and that old held models and effects disappear.

Run the applicable [project checks](../docs/testing.md) and record the source revision, environment and observed results for each criterion.

## Documentation

Document the shared master, the two presentations and how to check fit and attachments.

## Completion record

### 2026-11-28 · Candidate and verification

The four map launchers share one original sealed depot model. `LauncherGeometry` clones the native template for a floor-fitted pickup or a welded Tool with a lower hand grip. The muzzle and launch sound use the modeled nose when the short visual path clears cover. The authoritative rocket sweep still starts at the validated character head and uses the existing aim, hit and damage rules. The candidate is available in draft for local testing. [Blender master and export recipe](../assets/blender/rocket-launcher/README.md) · [PR #89](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/89)

| Criterion | Verification and observed result |
| --- | --- |
| A1 · Asset and fit | Three `DepotLauncherPackageTests` cases passed. Blender 5.3.0 reopened the master and reimported all 126 visual meshes and ten materials. The audit measured a maximum bounds difference of 0.000000060 studs, outward faces and zero external dependencies. A disposable re-export reproduced the GLB, native model and audit byte for byte. The clean Rojo builds contain the model and all three placement frames. The four native floor contacts, equipped grip and clipping, and rendered desktop and phone fit remain open. |
| A2 · Transfer and fire | The independent tester reviewed the validated head-origin sweep and passed all 102 host integration cases. Source review found that the cosmetic convergence segment could cross offset cover. The correction tests that path with a bounded spherecast after accepted fire and falls back to the head origin if blocked. The tester confirmed the source correction. The native `Launcher.spec.luau` regression and the `P29-depot-launcher` three-client cases for muzzle alignment, held and dropped replicas, cooldown handoff, and recovery after a carrier's death remain open. |
| A3 · Replay | The host verifier confirmed test isolation and checked the release and test assets. The `P29-depot-launcher` replay case exercises one loaded launcher at each original site and removal of prior held models and effects. Actual replay and cleanup remain open. |

The independent tester checked the asset package, the standalone unit and integration suites, the Blender reimport and the cover-path correction. The technical writer reviewed the player guide, source and export instructions, and three-client test procedure against the candidate. [Player guide](../README.md) · [Studio procedure](../docs/testing.md#verify-the-depot-launcher-model)

The local candidate `22386998e2491b0351ff78e0bd95ce8d673a3077` and GitHub candidate `25de54f3fa0028c8f5936a318d15843df77175d4` share tree `b81078bcab24616e985b324fbe6554d72006ea31`. A clean checkout on macOS 27.2.1 arm64 ran `python3 scripts/setup.py` and `python3 scripts/prepare_release.py`. Its full `python3 scripts/verify.py` passed 97 unit, 102 integration, 27 tooling and 78 asset tests, along with pinned-tool, formatting, lint, strict types, expected rejection, geometry reconstruction and test-isolation gates. The artifact inspector checked 14,601 release and 14,688 test transforms. The release contains 78 runtime scripts. [Candidate GitHub Verify](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/46145994332)

| Artifact | SHA-256 |
| --- | --- |
| `build/game.rbxlx` | `543057dedc1bc670d345d568e76aa7da730a4e42f4a855112ccd12f5a6cb29f6` |
| `build/tests.rbxlx` | `24720a262a7349f3a110c602d785eae92b50a0579250e3af8cef8c82a9f0b00e` |

For Studio 0.748.0.7481526, MCP reported only the published `C130 P17 Import` place in Edit. The native local file picker stopped responding during the attempt to open `build/tests.rbxlx`. The separate local test document remained unavailable, so the Studio smoke report, three-client result and rendered desktop and phone checks are pending. Resume with the local file in Edit and run the six-case `P29` scenario with three actual clients plus the rendered review. [Studio procedure](../docs/testing.md#verify-the-depot-launcher-model)

### 2026-11-28 · Pickup floor fit correction

The owner reported poor ground rendering while the carried model worked. Studio showed that the original `GroundContact` frame placed the authored body below the surface even though the marker itself appeared 0.012 studs above it. The corrected Blender marker points into the body from its resting side. Regeneration changed the native attachment and retained the visual geometry and held grip. The host package test checks the marker axis. The native harness checks the bottom of the art bounds against the supporting plane at all four sites.

In a one-client local `game.rbxlx` Play session, the production `LauncherGeometry` loaded the corrected Rojo-built template as a temporary fixture. At Radar, Hangar, Depot and Seedship, the visible bottom moved from 1.111 studs below the floor to 0.012 studs above it. The teal plate rose to about 1.095 studs above the floor, and the gameplay pivot stayed at the original site. A desktop client capture showed the corrected Radar pickup. The session returned to Edit. The three-client scenario and phone review remain open. [Studio procedure](../docs/testing.md#verify-the-depot-launcher-model)

`python3 scripts/verify.py` passed on the corrected source tree `4e6c003dff2d43500b4f19c9fcaeb740aa4c79e7`, with 97 unit, 102 integration, 27 tooling and 78 asset tests. Blender 5.3.0 reopened and reimported all 126 meshes. The rebuilt `build/tests.rbxlx` has SHA-256 `3d574a35374e6586a1a4678789b17c33a7c79fcbdf9a7e61e54202bb9d4ba9fa`. The rebuilt `build/game.rbxlx` has SHA-256 `6245a043dcde6d3da3f26efd478b016b9fd1625bc4f123439cffa5b0ff51f334`.
