# Client status, round HUD, thermal view and spectating

Rojo maps this package to `StarterPlayer.StarterPlayerScripts.Client`. The entrypoint waits up to ten seconds each for PlayerGui and bootstrap status, then starts `StatusPanel`. It attaches `RoundPanel`, `GroundCombatController`, `GroundIndoorCamera`, `GroundInput` and `BalancePanel` to the current RoundState owner. Replacement, removal or script destruction releases those owners and their listeners. Missing initial readiness fails startup with an assertion.

`StatusPanel.new(playerGui, status)` returns an idempotent lifecycle controller. It owns one `FoundationStatus` ScreenGui and listeners for environment/running state and round HUD ownership. The panel hides while `RoundHUD` exists. Stop disconnects its listeners and destroys its GUI. `ResetOnSpawn = false` preserves ownership through character replacement. [Shared lifecycle](../shared/README.md)

## Lobby balance panel

`BalancePanel.start(player, playerGui, roundState)` mounts the editor for the current round owner and returns its cleanup function. In the lobby, an owner or trusted tester with the server’s access hint sees **Balance**. The panel builds fields from the shared schema, holds unsaved edits locally and sends explicit save, apply or restore requests. Only the owner sees tester management. Closing the panel or leaving the lobby discards its draft. [Owner guide](../../docs/balance.md)

## Round HUD, settings and spectator camera

`RoundPanel.new(player, playerGui, state, inputProvider?, touchProvider?, settings?)` returns a nonyielding lifecycle controller. Production samples `UserInputService`. Tests can provide input and touch capability. `newSettings()` returns a fresh session record with Full effects and Reduced camera shake. The entrypoint passes the same record to later round owners so choices persist during the play session.

`RoundHUD` displays phase or role, surviving Ground players, status cues and aircraft health. It derives the Ground arrival countdown, combat clock and intermission clock from replicated absolute deadlines using `GetServerTimeNow`. It reads the bounded `RoundState.Result` JSON payload and shows the matching round's winner and reason through intermission. Settings set `InputOverlayOpen` to suspend combat input. The touch HUD uses compact safe-area clock, health and status rows, with contextual controls during combat and spectating. RoundPanel temporarily hides the native PlayerList through touch arrival and combat so it cannot intercept taps. It restores the prior setting on role or input changes and teardown. During Scatter, the Ground header uses a single-line **C-130 in 20s** countdown and launcher actions remain available.

`AircraftArrival.start(player, playerGui, state, thermalReady, touchProvider?)` synchronously installs the operator's full-viewport blackout owner. The optional nonyielding provider supplies touch capability for fixtures. Assignment through `OperatorArrivalRoundId` arms the cover. Before the deadline replicates it shows **Preparing deployment** on desktop or **Preparing** on touch. During Scatter it uses the same deadline as Ground and the compact countdown text on touch. The owner keeps the cover until `thermalReady(roundId)` confirms a rendered frame for the matching aircraft or the assignment is cleared. `blocking()` reports cover state. `stop()` idempotently removes the owner's unique render binding, assignment listener and GUI. This owner sends no gameplay requests.

`TheaterSpectating.new(player)` returns a nonyielding local owner of the TV proximity prompt and the movement lock. A bounded task resolves the stock `PlayerModule` controls. `update(roundId, eligible)` refreshes the prompt against the current television and lobby body and returns whether the player is watching and whether the enabled prompt is within reach. Entry checks a living protected lobby avatar within ten studs during Active. RoundPanel supplies eligibility using the replicated round, phase and life and hides the lobby guidance within reach to keep the native prompt visible. `exit()` releases movement for the same avatar, and `stop()` also removes prompt and initialization work. This feature is camera and input presentation.

`SpectatorCamera.new(player)` returns a nonyielding camera owner. Its `update(view, roundId, direction, destructionAge, shake)` accepts signed direction, optional seconds since aircraft destruction and a shake scale from zero to one. It returns the selected UserId and display name, if any, and the count of eligible targets. It retains the current living Ground target when possible and cycles through eligible UserIds. An empty target set uses an inert local overview while spectator mode is open. Results and Lobby bind the local humanoid as it becomes available. `stop()` clears the overview and shake binding and restores Custom camera mode.

`PresentationEffects.new(player)` owns two optional bundled cue sounds and the temporary aircraft destruction flash. Its nonyielding `update(view, roundId, reason, now, scale)` takes monotonic seconds and a scale from zero to one, and returns cue text, pulse strength and any current destruction age. It draws from replicated warning markers, impacts and results. Effect intensity changes sound volume, pulse and flash. A separate setting controls the brief aircraft destruction shake on the lobby camera during Results. Warning and result text remain readable at Off. The round owner clears its UI, listeners, sounds and cameras on teardown. [Cue provenance](../../assets/manifest.json) · [Studio checks](../../docs/testing.md#run-the-p23-lobby-and-intermission-harness)

## Operator thermal camera and weapon view

`ThermalCameraController.new(player, playerGui, roundState, inputProvider?)` immediately installs a nonyielding client owner exposing `ownsCamera()`, `ready(roundId)` and idempotent `stop()`. A living Gunship player in Active receives a Scriptable camera after the canonical aircraft Hitbox for that round replicates. The controller renders at `Enum.RenderPriority.Camera.Value + 3`, after the stock camera. It samples the Hitbox position once per frame for pan, projection and fire intent. At `Enum.RenderPriority.Last`, the blackout owner checks `ready(roundId)` for a committed frame before uncovering the viewport. Focus is a world-aligned map offset. Releasing input holds the map point while the plane orbits. A labelled solo Operator preview uses the same view without granting an active role. Each entry owns its ThermalHUD, ColorCorrectionEffect, role input listener, profile controls and native occluded Highlights. Touch devices also own device-safe pad, profile, Fire and Recenter controls.

Keys 1/2 or named buttons send bounded production selection intent. The acknowledged Selection string sets the 30° GAU23 / 40° M102 lens and reticle projection; rejection cannot optimistically change zoom. WASD/touch arrows feed signed rendered-view directions to `AircraftPanRules.step` using the current aircraft position. Focus clamps independently at the square’s X/Z edges, permitting sliding and immediate reversal, while speed stays at most 120 studs/second with a 0.1-second update cap. Both lenses share the full square envelope. R / Recenter and fresh role/round entry return to map center. The operator's mouse or a separate world touch aims while pan input is held. The reticle rounds/clamps once to 15–85% of the viewport, then drives both drawing and actual Battlefield/Terrain raycasts. A miss or endpoint outside the server’s disk/height envelope is invalid. Actionable GUI hover, text focus and window focus loss suspend pan. No pan remote or independent flight/zoom is introduced.

`ThermalCameraController.frame(position, focus)` returns a finite CFrame or nil for nonfinite, degenerate or out-of-square geometry. It projects canonical orbit-right into the look plane to avoid an overhead singularity; the view can roll at outward square corners. Server view validation uses the same deterministic basis. The optional nonyielding `InputProvider(viewport)` returns raw viewport `position`, `blocked`, signed `panRight`/`panUp` and optional `recenter`/`weapon` intent. Fixtures can exercise that normal boundary after releasing the ordinary owner; native keyboard/touch feel and rendered review remain separate checks.

The active operator camera owns a scaled, flat visual backdrop below the playable disk. It has no collision, touch, ray-query or shadow behavior, is never server-authored, and is destroyed with the camera owner on role loss or stop. Its size comes from `AircraftPanRules.backdropHalfExtent`; it does not clip pan or extend playable space. The backdrop uses its own dark neutral RGB `(38,42,45)`, independent of the invisible GroundDisk’s authored color. The actual playable disk and server aim validation are unchanged.

`ThermalCameraController.placeRecenter(control, canvas, viewport)` is a nonyielding presentation adapter for the touch Recenter button. The control’s parent must share the measured canvas origin. It intersects native input/render bounds with the actual device-safe canvas through `AircraftPanRules.controlTopRight`, including GUI-inset compensation, then sets the button’s local position/visibility. It returns false and hides the control when the full button cannot fit. Production remeasures placement every render/resize using a transparent inactive `ControlViewport` sibling, preserving button hierarchy and input ownership.

`ThermalCameraController.input(playerGui, rawPointer, windowFocused)` samples the desktop pointer/UI boundary without yielding. It returns the raw viewport pointer unchanged and a blocked flag for window/text focus, actionable GUI overlap or nonfinite pixels. Only the mouse GUI hit query subtracts the current top-left `GuiService:GetGuiInset()`; drawn-reticle and ray coordinates remain in viewport space.

`ThermalCameraController.touchViewportPosition(point)` converts a touch `InputObject.Position` from GUI-content to viewport pixels by adding the current `GuiInset`. It returns nil for nonfinite input or result and does not yield. `touchInput(playerGui, point, processed)` hit-tests the raw GUI-content point, returns the converted viewport position, and marks the frame blocked for processed input, a focused text box, an actionable GUI object or invalid coordinates. Pad and Fire touches own their respective actions. If a GUI callback runs after the global touch callback, it restores the previous aim position before taking ownership. A separate unprocessed world touch owns aim until it ends. Its changes update the converted aim position. Ending the matching Fire touch releases held fire. Menus and focus loss clear held actions. Role loss or stop also clears the stored aim and disconnects the touch listeners. A fresh pad touch restores focus after a Studio/device window transition.

`guiOffset(pixels, guiOrigin)` returns integer GUI-local UDim2 offsets or nil for nonfinite coordinates; the GUI origin is measured from an owned zero-size Frame plus current GuiInset.

ThermalHUD attributes commit `PanFocus` (world point), `PanLocalFocus` (held world-aligned map offset), `PanDirection`, `ProjectionGuiOrigin`, `RawPointer`, `InputBlocked`, `ProjectionViewport`, `ProjectionFrame`, `ProjectionTime`, `ProjectionCamera`, `ProjectionHit`, `AimEndpoint`, `ReticlePixels`, `Weapon`, `FOV` and `AimAllowed` for observation. They are local presentation diagnostics, not hit authority.

Role loss, missing state/aircraft or camera replacement removes GUI, post-processing, highlights and role input connections, restoring captured camera/FOV/mouse settings. The controller's RenderStepped observer remains only until its RoundPanel owner stops; stop disconnects it and is idempotent. RoundPanel resumes normal ground/spectator/lobby camera behavior. No thermal state controls collision, authority or damage.

During an active operator life, holding left mouse or the touch Fire button sends bounded target intent when the reticle has a valid aim point. Solo preview permits practice with the camera and weapon selection. The HUD presents the acknowledged weapon, zoom, ammunition, cooldown or reload, and impact cues. The request includes a view claim for server-side reachable-view validation. The server owns flight, impact, damage and results. RoundPanel supplies a replicated aircraft-health readout for both active roles. Thermal and aim world queries use actual Battlefield/Terrain geometry with query filters that exclude physical fragments.

[Foundation client specs](../../tests/studio/specs-client/README.md) cover bootstrap replication and status-panel lifecycle. The test-only [RoundHarness](../../tests/studio/client/RoundHarness.luau) checks actual role/deadline/HUD replication and spectator/lobby CameraSubjects across clients. Follow the [testing guide](../../docs/testing.md) for execution and evidence requirements.

The test-only [AircraftHarness](../../tests/studio/client/AircraftHarness.luau) checks real replicated pose, inward camera, coherent weapon/FOV/reticle state, occluded Highlight setup, singleton ownership and camera/FOV/mouse/effect cleanup. Full rendered occlusion and readability require the separate focused review recorded in P04.

The [P14 client harness](../../tests/studio/client/AircraftPanHarness.luau) adds input-driven surface projection, bounded camera basis, zoom/rejection coherence and role/cleanup fixtures. Its integrated P14 evidence includes native touch, rendered occlusion and complete two-client fixtures. P05 firing controls have passed separate operated desktop and simulated-phone checks; see [P05](../../plans/05-gunship-combat.md).

## Ground input, rifle and launcher

`GroundInput.start(player, playerGui, roundState)` adds nonyielding local input and facing ownership for a living Ground player during Scatter or Active or in the labelled Studio Ground preview. Roblox's native Custom camera and movement controls supply mouse look, touch drag, view-relative movement, pitch limits, zoom and occlusion. After the stock camera update, the owner captures the desktop pointer and uses `facingFrame(root, look)` to keep the locally simulated root upright at the displayed view yaw. The helper preserves position and retains the input frame for a degenerate horizontal projection.

`menuOpen(playerGui)` reads local settings and balance overlays, the Roblox menu and text focus. An open menu pauses local movement and releases aim capture. `pointerRequested()` reads a held desktop Left Alt, which frees the cursor and suspends combat input for HUD interaction. Focus loss, character or role changes and idempotent stop release the owned pointer and humanoid settings. The controller leaves camera ownership with Roblox and sends no aim or damage remote.


`GroundIndoorCamera.start(player, roundState)` installs the local Outpost
camera modifier and returns an idempotent stop closure. It requires a living
Ground player or Studio Ground preview and the player's native Custom camera.
It reads validated `GroundCameraInteriors` descriptors from the active
Battlefield. The Outpost workshop and upstairs command room each cap the rendered distance at five studs. Its callbacks restore the original stock frame at camera priority
−1 and apply the room limit at priority +1. Roblox still owns the desired zoom,
rotation, focus and occlusion. The modifier releases its frame when it loses
camera ownership and reacquires descriptors after a Battlefield rebuild.
`GroundCombatController` projects aim at camera priority +2 so its reticle rays
use the rendered camera.

`GroundCombatController.new(player, playerGui, roundState, touchProvider?)` returns a nonyielding idempotent Lifecycle owner. It owns one GroundCombatHUD and listeners for an active living Ground player. The optional nonyielding provider controls input-mode tests; production samples UserInputService. Role/round changes, unequip, focus loss or stop release held input; stop disconnects listeners and destroys the GUI.

`GroundCombatController.projectAim(viewport, inset, origin)` returns an integer viewport pixel and a GUI-local `UDim2`. The reticle stays horizontally centered on desktop and touch. `GroundCameraRules.reticleY` supplies the raised row from viewport height. The same pixel drives the rendered-camera ray for either equipped weapon. Drawing converts through the measured GUI origin and inset. Native tool slots or touch M-7/ROCKET buttons select equipment. Hold left mouse or FIRE, use R/RELOAD for the M-7, and wait for automatic launcher reload. Tool attributes supply the loaded count and server deadlines. `PlayerPresentation.rifleText` retains the loaded count and the ∞ symbol during reload when `UnlimitedReserve = true`.

The desktop HUD shows personal health, equipped readiness, and text for locally
detectable pickup, drop or reload rejection. The launcher row distinguishes
available, carried and returning states. A locally rejected action carries no
server intent. Remote validation remains authoritative when input is sent.

The HUD selects the local carrier's launcher or the nearest available pickup from LauncherState's four atomic snapshots. E/PICK UP sends bounded acquisition intent, and G/DROP releases a carried launcher. The server validates reach, geometry, movement, membership and life. The carrier keeps the M-7. Desktop displays launcher ownership and recovery in a status row. Touch shows personal health and current readiness near the top with FIRE and RELOAD on the right. The bottom row presents contextual equipment and launcher actions above the native inventory reserve. `statusLayout(touch)` returns the readiness position and size in the owning ScreenGui's content coordinates. Changing round or equipment, opening a menu and losing focus clear held firing input.

Current-round server-resolved rifle shots flash the shooter’s reticle. Direct M-7 and rocket hits reduce the same replicated aircraft health by up to 5 and 150 units, respectively. RoundPanel animates the shared bar and keeps numeric health or the destruction label available independently of color. [P25 Studio verification](../../docs/testing.md#verify-p25-weapon-balance)

`WeaponAudio.new(state, player)` receives cosmetic cues from the unreliable `RoundState.WeaponAudio` relay. Its nonyielding update takes round identity, phase, local Effects scale and synchronized seconds. It schedules spatial playback from server origins with distance-based delay, drops stale cues, and caps the queue at 48 and live voices at 24. The mix selects playback speed and EQ by weapon and coarse surface and applies a short tail fade. Temporary Sound instances preload four existing samples off the firing path. A bundled explosion supplies the fallback while a source loads or if its fetch fails. Entering Results prunes queued and live muzzle cues. Fresh impacts can still arrive during the first 0.75 seconds of Results. Resetting, changing rounds, muting and teardown clear queued and live sounds.

`WeaponImpactEffects.new(state)` returns a local presentation owner for the reliable `RoundState.WeaponImpact` contact stream and replicated rocket flights. Its nonyielding `update(roundId, phase, intensity, operatorView, seconds)` uses synchronized seconds. `show(weapon, roundId, shotId, contact, normal, surface, emittedAt)` validates matching round, weapon, finite contact, normalized normal, surface, freshness and identity before displaying a burst. The controller pools at most 12 anchored bursts and eight smoke trails. At Full, the M102 uses a growing flash and longer smoke plume. Reduced uses a smaller, shorter burst. GAU23 retains a distinct small spark and smoke impact. Rockets stop emitting smoke at flight end and existing puffs fade. Distance, Effects level and thermal view trim optional particles. The owners are cosmetic and their Parts cannot collide, touch or enter queries. Active bursts can finish into Results. Reset and mute clear displayed effects; `stop()` also disconnects listeners and destroys the pools. [P19 Studio procedure](../../docs/testing.md#run-p19-weapon-impact-checks)

`GroundAimGui.spec.luau` projects the raised reticle and both weapon rays with the production controller. It compares the production RoundPanel and GroundCombatController in common viewport coordinates at desktop, compact phone and asymmetric cutout sizes. It checks text and control bounds, the countdown across Scatter, native control reserves, phase transitions and teardown. Operated touch and measurements of actual CoreGui controls are collected in Studio. [P27 Studio procedure](../../docs/testing.md#verify-p27-aim-and-mobile-hud)


## Non-cover art in the operator thermal view

`ThermalCosmetics.start(root)` returns a nonyielding `{ stop, resources }` owner.
It watches BaseParts under the selected subtree. Ordinary cosmetic furnishings
require server-authored `ThermalNonCover = true` and both CanCollide/CanQuery false
to hide. Physical fragments have a narrow exception: they must also carry
`PanelFragmentVisual = true`, use the owned `PanelFragments` collision group, be
unanchored and nontouching, and remain non-querying. Their scenery collision can
stay enabled. Ground players keep the furnished view and visible debris. Solid
cover without that complete fragment contract remains visible to native Occluded
highlights. The owner reacts to replication ordering, late tags and changes into
real cover, retains original LocalTransparencyModifier values, and restores them
on removal/stop. `resources()` counts tracked Parts; `stop()` disconnects all
root/property listeners idempotently. The operator camera starts/stops this
owner with its own role lifecycle. It writes no physics, hit or damage authority.
Rendered thermal legibility and workload cost require separate native review.

The same operator owner locally hides BaseParts of the canonical direct-child `Workspace.Aircraft` Model by setting `LocalTransparencyModifier = 1`. It saves each original value and restores it exactly when a part/model leaves the owned subtree, the aircraft is replaced, or the view stops on role loss. Added aircraft parts are observed too. This masking keeps the aircraft body out of its own targeting view; Ground clients retain the visible plane. Server hit geometry, query/collision flags and physics are unchanged.

Operator scenery under `Workspace.World` uses a local 0.45 brightness multiplier. An imported Model’s nearest valid `ThermalBrightness` in `[0,1]` multiplies that base, including replacement panels. Legacy textures can use temporary local clones from the Model’s `ThermalSurfacePalette` in `ReplicatedStorage.Shared`; saved colors and cloned surfaces are restored on removal/stop. MeshPart child listeners retint after late SurfaceAppearance arrival or removal, restoring the earlier fallback before acquiring the new surface; a reentrancy guard prevents local palette clones from recursively retinting. With workspace ownership, the nine authored Terrain material colors are saved, multiplied by 0.4 and restored on stop. Authored character colors are not rewritten. The camera-owned ColorCorrectionEffect fully desaturates the operator’s 3D world, including textured meshes and Terrain, with a darker grayscale grade. Living Ground targets use white fill and outline with native occlusion. The effect is removed with the view owner, restoring normal rendering alongside the saved local colors. Grade values are tuning in [decisions](../../docs/decisions.md); fresh rendered contrast must be reviewed. [Asset thermal checklist](../../assets/README.md#thermal-presentation-for-buildings)


Client imported-material observations use shared `AssetMaterial.read(mesh)`.
It reads the compiled v1 attribute contract and requires one actual
SurfaceAppearance without inspecting its protected map properties. The compiler,
artifact checker and Edit audit bind slots/source receipts; metadata validation
does not prove loading. Use actual Instance-based preload and rendered review
for availability/appearance. See the [shared material contract](../shared/README.md#compiled-material-metadata).


`AssetMesh.validate(mesh)` is the corresponding ordinary-context native
reconstruction check. It compares public MeshSize and collision/render fidelity
with the five compiled native attributes, without reading opaque payloads or
loading cloud content. The managed compiler preserves genuine engine payloads;
client metadata/intrinsic validity alone does not establish rendered bounds,
UVs, contact behavior or replication acceptance.

The lobby balance editor groups its draft into Player, C-130, Buildings and Game & lobby tabs. Numeric fields support mouse/touch dragging, arrow keys and exact entry. Each tab change disconnects its global drag listeners. Closing or stopping the editor also invalidates pending responses. Save persists the shared draft, while Apply selects the named saved preset.
