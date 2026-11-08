# Lobby movement and human test controls

2026-11-08. User-directed follow-up to P03 on `fix/human-test-controls`, based on the unmerged P03 source `038684c`. The user requested lobby walking, solo exploration and convenient role/settings controls for human testing. This task does not implement P04 or change roadmap status.

## Implemented behavior

Waiting characters can walk with WASD and retain ForceField protection; the assigned operator remains anchored at its protected placeholder station. Ordinary Studio test Play installs a clearly labelled bottom-right **STUDIO TESTING** panel. One client automatically previews the map. Role cycles Auto/Ground/Operator; Ground preview can walk and Operator preview uses the station. The authoritative player remains Waiting and the phase remains Lobby during preview: no fake opponent, active life or competitive round is created.

The panel selects the next duration from 30/60/180/600 seconds, starts a real round immediately with 2–10 actual clients, resets the test, and moves between solo preview and the walkable lobby. Explicit Operator requests must be unique; an all-Ground roster also rejects with an explanation. Auto supplies an eligible operator when needed. A fresh normal RoleService seed produces requested roles without any production role-override hook. Role/duration changes do not mutate an active role/deadline; they apply on the next explicit start. Manual testing disables automatic deployment rather than relying on a long artificial lobby timer. Production automatic deployment and 6–10-player defaults remain unchanged.

All settings, role preference policy, request transport, GUI and restart owner live in the excluded test mapping. The server validates request shape, action/value, rate, sequence and session generation. Reset restores the map through the normal reset path, waits for old avatar work to drain and replaces the actual runtime. Teardown disconnects listeners, cancels the owned restart/discovery tasks and removes owned GUI/transport/preview state. No publication or production player data was used.

## Source and automated evidence

Tested runtime/test source: `b2430906e96c86566a3207759604466a8d0b8763`, Git tree `aa84114344bb3d0f4023a6cf52d30bec15303449`. Later edits are documentation/evidence only. [Source/build manifest](lobby-preview/source-manifest.json) records exact generated artifact SHA256 values. [All 42 mapped source signatures](lobby-preview/source-signatures.json) match actual Studio byte counts and Adler32, with zero mismatches, in the same Rojo-connected document `p02-tests-5c809beff70b.rbxlx`, place 0, instance `21f6fc11-4429-4148-9764-89a36987e5e9`, Studio 0.746.0.7461269. The document's old filename is not the candidate identity.

- [Full host log](lobby-preview/verify.txt): `python3 scripts/verify.py > build/human-test-controls-verify.log 2>&1` passes 24 unit/14 integration cases, zero failures/skips; format/lint/strict types, rejection probes, both builds, 112 authored parts per artifact, corruption probes and release isolation pass. Only 17 runtime scripts exist in the release mapping; the new test panel/session modules are absent.
- [Structured Studio reports](lobby-preview/studio-report.json): ordinary final solo Play passes 45 server/2 client baseline cases, zero errors/failures/skips.
- `ExecutePlayModeAsync({kind="LobbyControls"})` passes 4/4 actual-engine cases: unlocked/protected Waiting character, automatic one-client preview, no active-role/life grants, exterior recovery and return/duplicate rejection.
- `ExecutePlayModeAsync({kind="HumanTestControls"})` passes 6/6 actual-engine cases: malformed/stale/invalid requests, Ground/Operator previews, bounded durations, solo-start/replay rejection, lobby/preview navigation, reset generation and teardown.
- `ExecuteMultiplayerTestAsync(2,{kind="HumanTestMultiplayer"})` passes 4/4 cases with two actual clients: invalid-request immutability; conflicting Operator/all-Ground rejection; requested actual roles with selected duration; next-round choice changes, reset and a second start applying the reversed roles. These tests use the controller's actual request boundary; operated single-client UI tests below separately exercise the real client remote and GUI.

These are primary-agent verification results, not an additional independent reviewer. P03's prior independent evidence remains in its own record. No required case was skipped.

## Operated review and session hygiene

Actual mouse clicks on the role/duration/start/reset/location buttons changed the server-owned preferences, switched the solo preview between walking Ground and anchored Operator, selected 180 seconds, rejected solo real-round start, preserved the GUI across a new runtime generation and restored the camera to its own Humanoid. Returning through the panel left the lobby root unanchored; operated D moved 6.40 studs over 0.4 seconds. Earlier operated W moved 9.50 studs over 0.6 seconds in map preview. This supplements anchoring assertions with real input/movement.

The [representative capture](lobby-preview/current-progress.jpg) shows the actual final panel and Ground preview at logical viewport 1081×619, graphics Automatic. Chat was hidden only in the capture client. Role and duration button text fit their actual bounds. It is a local prototype capture, not planned aircraft art or a release claim.

Every launched test ended. The final connected inventory contains only the original document in Edit; no extra multiplayer windows were left open. The same live Rojo test connection on 127.0.0.1:34872 delivered the source. No source edits were left solely in Studio.

## Limits

Operator preview is the current protected avatar station; aircraft/thermal targeting/combat are still planned. Solo preview does not supply a real opponent or establish multiplayer combat. Settings last for the local session and across its resets, not a new Play session. Real rounds still require at least two test clients; production requires 6–10. These checks do not establish release capacity or balance.
