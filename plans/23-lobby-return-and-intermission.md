# P23 — Return to the lobby, theater spectating and intermission

**Gameplay iteration.** Builds on P03, P09, P10 and the furnished P22 lobby. Covers R02–R04, R11, R12 and R24. [Roadmap](../roadmap.md) · [Requirements](../requirements.md)

## Player experience

A Ground player who dies immediately returns to a walkable, protected lobby. They can stay with the other waiting players or walk up to the theater TV and choose **Spectate**. The TV keeps its still image. The interaction puts the player into the existing spectator camera, where they can cycle living Ground teammates. **Exit spectating** returns their view and controls to their own avatar at the TV.

When the server commits a round result, the operator and surviving Ground players join the others in the lobby. Anyone watching leaves spectator mode. Players can move around and read the result while a **2:00 intermission** counts down. At zero, the next round can deploy as soon as the map is ready and at least two players are eligible.

## Implementation

- In `MatchService`, consume a battlefield life once. In `MatchRuntime` and `CharacterOwner`, request a protected lobby body on that same authoritative update, allowing for the engine's avatar load. Keep the consumed life and team result credit keyed by round and UserId. A replacement lobby body cannot count as Ground, receive a Tool, affect thermal targeting, or act in combat. If the round continues, drop a carried launcher at the last valid battlefield position before moving the player. The terminal result takes precedence on the last elimination.
- Give mid-round arrivals and returning players the same protected lobby entry. Keep them out of the deployed roster or preserve their consumed life as applicable. Rebuilding an operator's station body during play still preserves the assigned role. On a result, release the operator from the station and give them normal lobby movement.
- Attach a keyboard/touch interaction prompt to the existing P22 television. Offer entry only to a lobby participant in reach during a watchable round. Reuse `SpectatorCamera` and its living-target selection. While watching, leave the avatar protected at the TV. Provide a visible exit control on desktop and touch. Handle target death, role change, round end, character replacement and map rebuild, releasing camera, input and prompt bindings. The lobby camera is the default after elimination.
- Anchor next deployment to **result commit time + 120 seconds** on the server. Results presentation and pristine map reset fit inside this interval. Keep the lobby floor and occupants supported during map replacement, and avoid respawning a player already walking in the lobby. Publish an absolute deadline for the HUD. A join, departure, result banner dismissal or population drop cannot restart or bypass the timer. If the population is too low at zero, show the usual waiting state and deploy when eligible. Keep the existing first-server startup wait separate.

## Acceptance

| ID | Planned check | Passing observation |
| --- | --- | --- |
| A1 | Extend `MatchService`, `CharacterOwner` and launcher tests | Death/reset consumes one Ground life and issues one lobby placement, including duplicate death/removal events and a stale load finishing after results. The lobby avatar can walk but cannot fire, collect equipment or rejoin combat. A nonterminal carrier drops at their battlefield position. Last-player death commits the correct result once. |
| A2 | Extend `SpectatorCamera` and player-experience Studio coverage | With one operator and two Ground clients, eliminate one Ground player. They spawn in the lobby looking through their own camera, walk to the TV, enter, see the survivor move, exit and walk away. Walking past the TV does nothing. An out-of-range or active-role player cannot enter. Verify touch entry/exit, target loss, round-end exit, normal camera restoration and the original TV image. |
| A3 | Extend `RoundRules` and `MatchService` with an injected clock | Each committed ending, including a forfeit or abort with players connected, sets one deadline. At 119.999 seconds deployment is rejected. At 120 seconds one deployment is eligible given a ready map and sufficient population. Joining halfway shows the remaining time. Going below minimum and returning before or after expiry never adds a second wait. A cancelled deployment without a committed result uses the existing lobby retry. |
| A4 | Extend the round and match-outcome Studio harnesses | Observe all roles in the protected lobby from the result, with matching result and countdown on independent clients. Run one production-length intermission and a second reset. Check no early deployment, duplicate characters/prompts, camera takeover or loss of theater floor. Add a supported late join during a running round and exercise consumed-life reconnect with the service fixture. |

Run `python3 scripts/verify.py` and the affected native Studio suites. In the operated check, judge whether the TV action is discoverable, the exit is easy to use and the result can be read while walking. Update the player guide and the server/client package contracts when the feature lands.

## Completion record

### Candidate verification on 2026-11-25

The candidate loads a protected lobby avatar after death, keeps the existing avatar when play ends in the theater, and preserves the occupied lobby while rebuilding the battlefield. The TV retains its aerial image. Its proximity prompt opens a local spectator camera with a visible exit control. The result and 120-second deadline appear in the lobby UI.

The source candidate is `a164d4581d20c32af09a1185c08d76c449a5c0a0` (tree `f5c4fdf5defb92f615f230e98b99e7df429c8c95`). The full `python3 scripts/verify.py` gate passed on macOS arm64 with Python 3.15 and the pinned tools. The disposable verification checkout pointed the Lune alias at the pinned type definitions and used the same runtime and test source. Results were 83 passing unit, 81 passing integration, 26 passing tooling and 70 passing asset tests. Strict Luau analysis, lint, formatting, reconstruction, both Rojo builds and release isolation passed. The test place SHA-256 was `722f07a8aef75633657d54abee8b41ae2376ed5241066a54f4307cb02e8ea483`. The documentation reviewer and the final repository checker verified the player guide and test instructions. [Draft PR #71](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/71) · [GitHub Verify](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/45622775882)

| Criterion | Verification and result |
| --- | --- |
| A1 | `MatchService.spec.luau` exercises confirmed death, model removal, departures and consumed-life reconnect. The Studio `CharacterOwner`, `CharacterCleanup`, P23 and P18 fixtures cover an actual in-flight avatar lease, request supersession, a protected replacement avatar and recovery at the sampled battlefield drop. The engine checks are unrun. |
| A2 | `PlayerPresentation.spec.luau` covers opt-in spectator view selection. The P23 multiplayer fixture checks the real TV prompt, out-of-range and active-role rejection, camera return, resumed desktop movement and loss of the watched target. Independent source review found a foreign camera subject could remain during avatar reload. The correction releases the target immediately and uses the lobby anchor while the new avatar loads. Native prompt, camera and operated desktop/touch checks are unrun. |
| A3 | The injected-clock `MatchService.spec.luau` cases cover committed outcomes, the 119.999/120-second boundary, population change, cancelled deployment and runtime teardown. Independent review reproduced a stale deadline on reuse of the same runtime. The teardown regression and explicit result/deadline clear cover the correction. |
| A4 | The P23 Studio selector starts three real clients and adds a fourth during combat. Its authored checks cover result-time lobby return, a full 120-second wait, the same lobby floor and avatar through map replacement, prompt cleanup and a second reset. These Studio scenarios and the operated review are unrun. |

Roblox Studio 0.748.0.7481526 connected on the Apple Silicon Mac. The local Edit document `tests.rbxlx` still contained the earlier source at the first parity check and did not contain the P23 fixture or theater module. Native acceptance requires syncing the candidate into that test document. The [P23 Studio procedure](../docs/testing.md#run-the-p23-lobby-and-intermission-harness) describes the required reports and operated checks.
