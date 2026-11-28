# P31 — Darker starting bunker

**Depends on** P18 and the integrated Sandbreak bunker. **Requirements** R22. [Roadmap](../roadmap.md#public-mvp-launch) · [Requirements](../requirements.md)

From the aircraft, the starting bunker reads as dark cover beside the other buildings. An exposed player remains easy to spot.

## Work

- Compare the bunker and a neighboring landmark at the same operator zoom and lighting. Identify the bright wall, roof or material contributions. Adjust the bunker’s operator-side thermal treatment and retain the existing normal Ground materials.
- Keep the structure and attached damage surfaces visible. Preserve real openings, white exposed targets and cover occlusion through the full damage sequence. Follow the [building thermal checklist](../assets/README.md#thermal-presentation-for-buildings).

## Acceptance

1. **A1 · Side-by-side captures.** Record before/after scenes at both weapon zooms using repeatable camera positions. Compare representative wall and roof brightness with nearby structural surfaces. Review the actual rendered result with an exposed, covered and doorway target.
2. **A2 · Two-client regression.** Exercise both roles in Studio. Check pristine and damaged panels, line of sight through an earned opening, normal Ground colors, role switch and reset. Verify the local thermal change never alters server collision or damage.

Run the applicable [project checks](../docs/testing.md) and record the source revision, environment and observed results for each criterion.

## Documentation

Record the reference scene and the material rule in the bunker asset guide.

## Completion record

### 2026-11-28 · Candidate and verification

Sandbreak's walls and roof use a 0.27 color multiplier in the operator view before the grayscale grade. The client applies the tint to local surfaces that reuse all 33 existing color maps. The assembly and each registered panel carry the setting, so Light and Heavy replacement meshes get the same treatment. [Bunker material rule](../assets/blender/spawn-bunker/README.md#operator-thermal-materials) · [P31 pull request](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/93)

| Criterion | Observed result |
| --- | --- |
| A1 · Side-by-side captures | Local Studio Operator preview compared base `db2ccbe` and the candidate from `(315, 140, 174)` looking at `(0, 8, 173)` at 30° and 40°. The Sandbreak wall sample fell from 113 to 25 on the 8-bit grayscale scale at both zooms. The roof fell from 151 to 53 at 30° and 156 to 53 at 40°. Corresponding Seedship wall and roof samples changed by at most one level. The exposed and doorway targets stayed white, and the intact wall concealed the third target. The roof breach, attached detail and wall silhouette remained legible. [30° comparison](../docs/evidence/p31/thermal-30.jpg) · [40° comparison](../docs/evidence/p31/thermal-40.jpg) · [Capture and pixel measurements](../docs/evidence/p31/rendered-comparison.json) |
| A2 · Two-client regression | `StudioTestService:ExecuteMultiplayerTestAsync(2, { kind = "P31" })` passed four of four cases with two actual clients. On panel `SB.W.SE.02`, all 66 sampled cover rays stayed blocked through Light. Heavy retained 53 blocked rays and opened a previously blocked line to `(22, 2.5, 136)`. Total kept that line clear and removed the panel proxy. The server retained ownership of collision and staged damage. Both clients verified their respective textures and role-local tinting at each stage. On replay they exchanged roles and the rebuilt pristine panel blocked the original rays. The fixture sends deterministic damage outcomes at the server's accepted-impact boundary. [Studio report and source comparison](../docs/evidence/p31/native-two-client.json) · [Reproduction](../docs/testing.md#verify-sandbreak-thermal-contrast) |

Studio `0.748.0.7481526` ran the local `tests.rbxlx` document with Rojo on port 34872 and place and universe IDs of zero. The final multiplayer run passed 219 server smoke cases and 24 client smoke cases per client, with zero failures, errors or skips. `ThermalCosmetics.spec.luau` checks native wall and roof tint, replacement inheritance, cover flags and exact cleanup. The tester matched nine Studio script fingerprints and all 33 palette entries to the candidate. The test place returned to Edit with the selector clear.

An early solo fixture cloned already tinted local surfaces. The corrected fixture removes those transient clones before testing the original textures in isolation. The first two-client attempt deployed before the client smoke suites were ready. The final fixture waits for both passing client reports before deploying. The independent rerun passed the corrected cases. [First multiplayer attempt](../docs/evidence/p31/native-attempt-1.json)

The independent tester ran `python3 scripts/verify.py` on macOS 27.2.1 arm64. It passed 101 unit, 103 integration, 27 tooling and 81 asset regression tests, seven P16 audits, format, lint, strict analysis and all deliberate rejection probes. Both Rojo builds matched the 33 palette maps to the 3,787 native Sandbreak MeshParts and 103 panel identities. The inspector checked 14,726 release and 14,813 test transforms and confirmed 80 runtime scripts in the isolated release build.

| Build | SHA-256 |
| --- | --- |
| `build/game.rbxlx` | `b996dd626e82f627606cd941bcfb5990d53707a4a58bda3a9a1490a72fedf45c` |
| `build/tests.rbxlx` | `71433c0eccbbdba2609eaf159017ce350fb1cfdcdd4a43691a2a2c361a2cd4b1` |

Tested local commit `382ae6f8d564e66c7fc2586d193f1e309d24e37d` and GitHub commit `fb2311626b551ea7667b9a1b02a2db5bba9c210d` share source tree `eb1c389e4749a6f4fc94bfbd2279cb703de72cc2`. The tester independently reviewed both rendered zooms and the final runs. The technical writer reconciled the player, asset, client and testing guides with the verified behavior. The repository checker passed after the documentation updates. [GitHub candidate](https://github.com/hanegraaff/roblox-c130-extraction-shooter/commit/fb2311626b551ea7667b9a1b02a2db5bba9c210d) · [Candidate CI](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/46160024389)
