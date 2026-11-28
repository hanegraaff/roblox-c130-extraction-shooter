# P30 — Medkits at each battlefield building

**Depends on** P26, P27 and medkit reference art. **Requirements** R27, R28. [Roadmap](../roadmap.md#public-mvp-launch) · [Requirements](../requirements.md)

An injured Ground player can find and use a medkit in or near each battlefield building. Each kit heals once and comes back next round.

## Work

- Use the [medkit references](../src/images/medkit/). Save one editable master at `assets/blender/medkit/medkit.blend` and register its managed export. Place a reachable, tucked-away kit at Sandbreak bunker, Salt Flats hangar, Vesper Radar, the military depot/Outpost and Prism Seedship. Keep the waiting lobby protected.
- Proposed interaction: use a nearby prompt to heal immediately. The server checks round, phase, living Ground role, proximity, line of sight, current health and kit availability. Apply healing up to maximum health and consume the kit atomically. A full-health player leaves it for a teammate. Resolve lethal damage and committed results before pickup.
- Read the healing amount from P26’s round preset. Each site supplies one single-use kit per round. Show health feedback and remove the spent pickup on every client. Remove remaining cases at Results and restore all five at the next deployment.

## Acceptance

1. **A1 · Healing rules.** Test partial and capped heals, zero missing health, raced uses, out-of-range or through-wall requests, death, spectator and stale requests. Two players using one kit can earn only one heal. Verify that spent kits remain unavailable for the rest of the round, including when a legacy preset contains a respawn interval, and return for the next round. [Single-use decision D112](../docs/decisions.md)
2. **A2 · World placement.** In three-client Studio play, walk to each of the five kits, use one while injured, and verify health, disappearance and replay on both Ground clients. Exercise at least one pickup on phone. Check that damage to nearby cover leaves a reachable pickup.
3. **A3 · Live tuning.** Set a different heal amount through the panel. Verify the current round finishes on its original preset, measure the new heal amount in the next round and confirm each kit can only be used once per round.

Run the applicable [project checks](../docs/testing.md) and record the source revision, environment and observed results for each criterion.

## Documentation

Add a short player tip and explain the healing control in the owner guide.

## Completion record

### Candidate and host verification

The editable 120-piece field case, portable GLB and native Roblox template reconstruct from the repository. Blender 5.3.0 reopened the master and imported all 120 pieces with eight matching materials, outward normals, zero external dependencies and a maximum bounds difference of 0.000000042 studs. The re-export produced identical GLB, native model and audit hashes. [Asset workflow](../assets/blender/medkit/README.md) · [Blender reimport result](../docs/evidence/p30/blender-reimport.json)

Local candidate `cbe28d471759f4821b98a8f690a3e0d5747f33fa` and GitHub candidate `64ed7344bd037c10545ec7fc467228bfcb8b72aa` share tree `08ab48cd3128b41179e7a051a47bb5b46a488c0d`. [Candidate commit](https://github.com/hanegraaff/roblox-c130-extraction-shooter/commit/64ed7344bd037c10545ec7fc467228bfcb8b72aa) · [PR #92](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/92)

On macOS 27.2.1 arm64, `python3 scripts/verify.py` passed 27 tooling tests, 81 asset tests, 101 Luau unit tests and 103 service integration tests. Format, lint, strict types, expected rejection probes, both place builds, 14,726 release and 14,813 test geometry checks, and release isolation passed. `build/game.rbxlx` SHA-256 is `cbe41beb18ba7735b9c331bebf5347a71840dbc69a6ab7a42464319c2450e0ba`. `build/tests.rbxlx` SHA-256 is `e596923f46c311299275b10971cc621c292b0fc21cdb5831fcf788a8d6c1dc93`.

### Early Studio findings

The first three-client run passed 219 server and 23 cases on each client, then failed to observe the client walk. The corrected walk fixture exercised real movement but initially reached the hangar trigger before the server observed the avatar inside reach. At resolution the server measured 8.043 studs, then observed 5.910 studs on the replicated avatar. The final fixture waits for the server to observe the walk within seven studs before invoking a valid test activation. The shipped interaction retains eight-stud reach. An early phone attempt timed out without registering an input. [Walk failure](../docs/evidence/p30/initial-walk-failure.json) · [Hangar failure](../docs/evidence/p30/initial-hangar-failure.json) · [Replication timing](../docs/evidence/p30/hangar-replication-timing.json) · [Phone timeout](../docs/evidence/p30/initial-phone-timeout.json)

At Vesper, the scripted approach retained its camera heading from the previous site and the native prompt's camera ray met a wall. The fixture now looks toward the kit from the live avatar's head and observes the native prompt before activating it. The simulated phone pickup then passed. The owner panel initially became available a frame before the cursor unlocked after elimination. The fixture now waits for the lobby view and the cursor to be ready before operating the real editor. The client observer matches the current pickup's heal amount and feedback deadline. [Vesper failure](../docs/evidence/p30/radar-activation-failure.json) · [Early owner fixture failure](../docs/evidence/p30/phone-and-owner-fixture-failure.json) · [Operated phone pickup](../docs/evidence/p30/operated-phone-before-editor-fix.json) · [Owner cursor timing](../docs/evidence/p30/owner-cursor-timing.json)

### 2026-11-28 · Studio acceptance

Roblox Studio `0.748.0.7481526` ran `StudioTestService:ExecuteMultiplayerTestAsync(3, { kind = "P30", touchReview = false })` and repeated it with `touchReview = true`. Both runs passed all six cases across two rounds with three actual clients. Server smoke passed 219/219 in each run. Every client passed 23/23 with zero failures, errors or skips. The independent tester matched all 12 relevant live server and client script fingerprints to the candidate, observed the desktop run and separately operated a native phone pickup. [Desktop report and source binding](../docs/evidence/p30/studio-desktop-verified.json) · [Phone report and input trace](../docs/evidence/p30/studio-phone-verified.json)

| Criterion | Observed result |
| --- | --- |
| A1 · Healing rules | `tests/unit/MedkitService.spec.luau` covers capped and partial healing, full health, invalid state or requests, stale rounds and single use. `tests/integration/MedkitService.spec.luau` covers `MatchService` damage and committed-result ordering. Studio kept a full-health or inaccessible kit available and awarded one heal to two contenders. The used kit stayed absent during the round with a legacy one-second respawn setting. |
| A2 · World placement | Both Ground clients saw all five cases seated about 0.018 studs above their supports. Players walked the final approach and consumed each kit. The server and clients confirmed removal and healing. Sandbreak's case remained usable after an adjacent registered panel reached Total. An operated tap on a simulated iPhone 17 Pro produced a native Touch input and `PromptTriggered` at Salt Flats, removed the kit and awarded 25 HP. All five cases returned on replay. [Hangar before the tap](../docs/evidence/p30/hangar-phone.jpg) |
| A3 · Live tuning | An eliminated owner used the real lobby balance panel to save and apply 43 HP. The surviving teammate's Seedship pickup still healed for 25 HP in round one. Sandbreak healed for 43 HP in round two, once for the team. |

The technical writer reviewed the player controls, owner instructions, Blender rebuild, test procedure and runtime contracts against the candidate. [Player guide](../README.md) · [Owner guide](../docs/balance.md#set-medkit-healing) · [Studio procedure](../docs/testing.md#verify-single-use-medkits)

### 2026-11-28 · Owner playtest

The owner confirmed the medkit playtest in the open Roblox Studio candidate. This records the owner's hands-on check alongside the three-client acceptance reports.
