# Player presentation and controls

Client bootstrap, ground input, thermal camera, HUD, spectating, effects and audio belong here. Rojo maps this folder to `StarterPlayer.StarterPlayerScripts.Client`. It currently contains no executable modules.

Clients turn input into bounded intent and render server snapshots. They do not award hits, lives, launcher ownership or results. Keep UI view-model transformations testable apart from Instances. Restore camera/input state and dispose of listeners/effects on role change, round reset or teardown.

Document controller entrypoints and engine/UI suites here as their plans are implemented. A local visual prediction must reconcile with server state and must not modify authoritative collision or health.
