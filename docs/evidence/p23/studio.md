# P23 Studio verification

Roblox Studio 0.748.0.7481526 on macOS arm64. The local `tests.rbxlx` Edit document was synced through Rojo on port 34872. Before the first SDK run, the Edit probe matched 164 source scripts. Subsequent parity checks verified the edited runtime and test modules before restarting Play in the same document.

## Earlier runs and corrections

| Run | Actual observation | Correction |
| --- | --- | --- |
| First SDK run, source `a164d45` | Three actual clients deployed, but all three client smoke suites failed the equipped-weapon HUD layout case. The SDK report returned 0/2 with a harness readiness failure before P23 gameplay checks. | The first fixture deployment now waits for independent client smoke acknowledgements before calling the real match service. |
| Ordinary solo Play, source `a164d45` | The single client passed 22/22 client checks. The server passed 202/202. Both recorded zero failures, skips and errors. | This isolated the startup conflict to automated multiplayer deployment during client smoke. |
| Second SDK run with the readiness change | Initial role replication and the actual fourth-player late join passed. The attempt to start theater spectating timed out while waiting for the correct camera subject. | The client probe now waits for replicated proximity and the engine's prompt display, sends the actual keyboard input and verifies the activation and camera separately. |
| Operated desktop diagnostic | Two actual clients joined. A test-only eligibility shim let one walk from the lobby to within 8.45 studs of the TV. The lobby guidance covered the on-screen prompt. Pressing E opened the actual follow view on the other client. Exit restored the same avatar and a subsequent keypress walked 6.53 studs down the aisle. The TV's aerial image rendered. | The active-round lobby message now occupies a compact upper-left panel, leaving the theater interaction in its normal position. |
| SDK run with the prompt and HUD changes | Three initial players passed initial role replication. An actual fourth player connected, but had about 16 seconds in the session and had yet to finish client smoke when the test ended. | The fixture gives the fourth client 45 seconds to finish smoke. P23's test combat duration is 85 seconds. |

## Candidate `5c76afa`

The Studio SDK ran the `P23` scenario with three initial clients and one actual late arrival. During first-round Results an independent server probe at 119 seconds remaining showed the operator, both eliminated Ground players and the late arrival in protected, movable lobby avatars. The server smoke report showed 202/202 and all four clients reported 22/22, with zero failures, skips and errors.

A theater client at the original TV displayed the winner, reason and remaining intermission at a 1081 × 693 viewport. Native S input moved the player's lobby avatar about 10.7 studs down the aisle while the result and countdown stayed visible and the movement left the camera following that avatar.

The SDK returned **7 of 7 passing** with zero failures or skips, three initial and four peak actual clients, and completed round IDs 1 and 2. The run proved optional theater entry with native input, preserved lobby avatar and floor identity, an actual late arrival, the production two-minute wait, automatic redeployment, target loss, operator reset and a second reset after the timeout.

During round two, the independent tester used the actual eliminated Ground client in the iPhone 17 Pro landscape simulator. The logical viewport was 750 × 382 and `TouchEnabled` was true. A processed touch on **Exit spectating** restored that client's lobby Humanoid. The TV prompt reported native touch input. After framing the TV from the aisle, a tap triggered the prompt and switched to the sole surviving Ground player's Humanoid. A second exit tap restored the lobby avatar. The tester restored the default viewport before the round ended. At one side angle the lobby guidance could still overlap the prompt. That observation prompted a final layout correction.

The same runtime passed all 11 `P18-rebalancing` cases with three initial actual clients and two after the intentional carrier departure. Client smoke passed 22/22 on all three and server smoke passed 202/202. The launcher checks confirmed recovery at the sampled battlefield position after a carrier died, protected lobby return, rejection of a spectator's pickup, and fresh launchers after reset.

## Final theater layout

The lobby guidance now clears within TV interaction reach. The first full replay after this change could not establish its fourth Studio client and stopped before theater input. The earlier full replay and P18 cover the lobby, timing and launcher behavior with the same server source. The focused `P23Theater` selector exercises the changed presentation with three initial actual clients.

On `3157373`, `P23Theater` passed **3 of 3** with exactly three actual clients, one completed round and zero failures or skips. The real prompt appeared, the guidance cleared at interaction range, and the eliminated Ground player entered with native E, followed a living target and exited to their lobby avatar. The result returned all clients to the lobby and the first reset passed. The final Edit comparison matched 180 scripts and five launcher or support poses. The two-client P05 run passed **9 of 9** on the corrected layout, with zero failures or skips.
