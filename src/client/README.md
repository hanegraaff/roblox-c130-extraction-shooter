# Client status, round HUD, thermal view and spectating

Rojo maps this package to `StarterPlayer.StarterPlayerScripts.Client`. The entrypoint waits up to ten seconds each for PlayerGui and bootstrap status, then starts `StatusPanel`. It attaches one `RoundPanel` to RoundState and replaces it when the server owner changes. Removal or script destruction releases owned controllers and listeners. Missing initial readiness fails startup with an assertion.

`StatusPanel.new(playerGui, status)` returns an idempotent lifecycle controller. It owns one `FoundationStatus` ScreenGui and listeners for environment/running state and round HUD ownership. The panel hides while `RoundHUD` exists. Stop disconnects its listeners and destroys its GUI. `ResetOnSpawn = false` preserves ownership through character replacement. [Shared lifecycle](../shared/README.md)

## Round help, settings and spectator camera

`RoundPanel.new(player, playerGui, state, inputProvider?, touchProvider?, settings?)` returns a nonyielding lifecycle controller. Production samples `UserInputService`. Tests can provide input and touch capability. `newSettings()` returns a fresh session record with Full effects and Reduced camera shake. The entrypoint passes the same record to later round owners so choices persist during the play session.

`RoundHUD` displays the phase or role, surviving Ground players, a countdown from the authoritative deadline using `GetServerTimeNow`, status cues and aircraft health. Results reads a bounded `RoundState.Result` JSON payload and renders the winning team and reason for the matching round. Desktop settings and spectator controls are handled locally. Settings set `InputOverlayOpen` so the combat controllers suspend input. The only round intent here is **Surrender / spectate**, which sends current round ID and an increasing sequence from an eligible active Ground life. Touch Ground play uses the compact D58 header.

`SpectatorCamera.new(player)` returns a nonyielding camera owner. Its `update(view, roundId, direction, destructionAge, shake)` accepts signed direction, optional seconds since aircraft destruction and a shake scale from zero to one. It returns the selected UserId and display name, if any, and the count of eligible targets. It retains the current living Ground target when possible, cycles through eligible UserIds, and owns an inert local overview subject when the set is empty. Operator view owns the thermal camera. Results uses an overview and Lobby resumes the local Humanoid. `stop()` clears the overview subject and restores Custom camera mode.

`PresentationEffects.new(player)` owns two optional bundled cue sounds and the temporary original aircraft destruction flash. Its nonyielding `update(view, roundId, reason, now, scale)` takes monotonic seconds and a scale from zero to one, and returns cue text, pulse strength and any current destruction age. It draws from replicated warning markers, impacts and results. Effect intensity changes sound volume, pulse and flash. Independent camera shake is confined to the aircraft destruction Results overview. Warning and result text remain readable at Off. The round owner clears its UI, listeners, sounds and cameras on teardown. [Cue provenance](../../assets/manifest.json), [Studio checks](../../docs/testing.md#run-the-player-experience-harness)

## Operator thermal camera and weapon view

`ThermalCameraController.new(player, playerGui, roundState, inputProvider?)` immediately installs a nonyielding client owner exposing `ownsCamera()` and idempotent `stop()`. An active living Gunship player receives a Scriptable camera at the canonical replicated aircraft Hitbox. Focus is a world-aligned map offset; releasing input holds the map point while the plane orbits. A labelled solo Operator preview uses the same view without granting an active role. Each entry owns its ThermalHUD, ColorCorrectionEffect, role input listener, profile controls and native occluded Highlights. Touch devices also own device-safe pad, profile, Fire and Recenter controls.

Keys 1/2 or named buttons send bounded production selection intent. The acknowledged Selection string sets the 30° GAU23 / 40° M102 lens and reticle projection; rejection cannot optimistically change zoom. WASD/touch arrows feed signed rendered-view directions to `AircraftPanRules.step` using the current aircraft position. Focus clamps independently at the square’s X/Z edges, permitting sliding and immediate reversal, while speed stays at most 120 studs/second with a 0.1-second update cap. Both lenses share the full square envelope. R / Recenter and fresh role/round entry return to map center. Ground WASD remains movement, mouse movement aims only and a separate touch can aim while the pad is held. The reticle rounds/clamps once to 15–85% of the viewport, then drives both drawing and actual Battlefield/Terrain raycasts. A miss or endpoint outside the server’s disk/height envelope is invalid. Actionable GUI hover, text focus and window focus loss suspend pan. No pan remote or independent flight/zoom is introduced.

`ThermalCameraController.frame(position, focus)` returns a finite CFrame or nil for nonfinite, degenerate or out-of-square geometry. It projects canonical orbit-right into the look plane to avoid an overhead singularity; the view can roll at outward square corners. Server view validation uses the same deterministic basis. The optional nonyielding `InputProvider(viewport)` returns raw viewport `position`, `blocked`, signed `panRight`/`panUp` and optional `recenter`/`weapon` intent. Fixtures can exercise that normal boundary after releasing the ordinary owner; native keyboard/touch feel and rendered review remain separate checks.

The active operator camera owns a scaled, flat visual backdrop below the playable disk. It has no collision, touch, ray-query or shadow behavior, is never server-authored, and is destroyed with the camera owner on role loss or stop. Its size comes from `AircraftPanRules.backdropHalfExtent`; it does not clip pan or extend playable space. The backdrop uses its own dark neutral RGB `(38,42,45)`, independent of the invisible GroundDisk’s authored color. The actual playable disk and server aim validation are unchanged.

`ThermalCameraController.placeRecenter(control, canvas, viewport)` is a nonyielding presentation adapter for the touch Recenter button. The control’s parent must share the measured canvas origin. It intersects native input/render bounds with the actual device-safe canvas through `AircraftPanRules.controlTopRight`, including GUI-inset compensation, then sets the button’s local position/visibility. It returns false and hides the control when the full button cannot fit. Production remeasures placement every render/resize using a transparent inactive `ControlViewport` sibling, preserving button hierarchy and input ownership.

`ThermalCameraController.input(playerGui, rawPointer, windowFocused)` samples the desktop pointer/UI boundary without yielding. It returns the raw viewport pointer unchanged and a blocked flag for window/text focus, actionable GUI overlap or nonfinite pixels. Only the mouse GUI hit query subtracts the current top-left `GuiService:GetGuiInset()`; drawn-reticle and ray coordinates remain in viewport space.

`ThermalCameraController.touchViewportPosition(point)` converts a touch `InputObject.Position` from GUI-content to viewport pixels by adding the current `GuiInset`. It returns nil for nonfinite input or result and does not yield. `touchInput(playerGui, point, processed)` hit-tests the raw GUI-content point, returns the converted viewport position, and marks the frame blocked for processed input, a focused text box, an actionable GUI object or invalid coordinates. A touch on the pad cannot claim world aiming. If GUI and global callbacks arrive in either order, pad capture releases any accidental aim ownership and restores the prior aim position. A separate unprocessed world touch owns aiming until it ends; only its changes update the converted aim position. Focus loss clears held pad directions and the active aim-touch ownership; role loss or stop also clears the stored aim and disconnects all touch listeners. A fresh pad touch restores focus after a Studio/device window transition.

`guiOffset(pixels, guiOrigin)` returns integer GUI-local UDim2 offsets or nil for nonfinite coordinates; the GUI origin is measured from an owned zero-size Frame plus current GuiInset.

ThermalHUD attributes commit `PanFocus` (world point), `PanLocalFocus` (held world-aligned map offset), `PanDirection`, `ProjectionGuiOrigin`, `RawPointer`, `InputBlocked`, `ProjectionViewport`, `ProjectionFrame`, `ProjectionTime`, `ProjectionCamera`, `ProjectionHit`, `AimEndpoint`, `ReticlePixels`, `Weapon`, `FOV` and `AimAllowed` for observation. They are local presentation diagnostics, not hit authority.

Role loss, missing state/aircraft or camera replacement removes GUI, post-processing, highlights and role input connections, restoring captured camera/FOV/mouse settings. The controller's RenderStepped observer remains only until its RoundPanel owner stops; stop disconnects it and is idempotent. RoundPanel resumes normal ground/spectator/lobby camera behavior. No thermal state controls collision, authority or damage.

During an active operator life, holding left mouse or the touch Fire button sends bounded target intent when the reticle has a valid aim point. Solo preview permits practice with the camera and weapon selection. The HUD presents the acknowledged weapon, zoom, ammunition, cooldown or reload, and impact cues. The request includes a view claim for server-side reachable-view validation. The server owns flight, impact, damage and results. RoundPanel supplies a replicated aircraft-health readout for both active roles. Thermal and aim world queries use actual Battlefield/Terrain geometry with query filters that exclude physical fragments.

[Foundation client specs](../../tests/studio/specs-client/README.md) cover bootstrap replication and status-panel lifecycle. The test-only [RoundHarness](../../tests/studio/client/RoundHarness.luau) checks actual role/deadline/HUD replication and spectator/lobby CameraSubjects across clients. Follow the [testing guide](../../docs/testing.md) for execution and evidence requirements.

The test-only [AircraftHarness](../../tests/studio/client/AircraftHarness.luau) checks real replicated pose, inward camera, coherent weapon/FOV/reticle state, occluded Highlight setup, singleton ownership and camera/FOV/mouse/effect cleanup. Full rendered occlusion and readability require the separate focused review recorded in P04.

The [P14 client harness](../../tests/studio/client/AircraftPanHarness.luau) adds input-driven surface projection, bounded camera basis, zoom/rejection coherence and role/cleanup fixtures. Its integrated P14 evidence includes native touch, rendered occlusion and complete two-client fixtures. P05 firing controls have passed separate operated desktop and simulated-phone checks; see [P05](../../plans/05-gunship-combat.md).

## Ground rifle and launcher

`GroundIndoorCamera.start(player, roundState)` installs the local Outpost
camera modifier and returns an idempotent stop closure. It requires a living
Ground player or Studio Ground preview and the player's native Custom camera.
It reads validated `GroundCameraInteriors` descriptors from the active
Battlefield. Its callbacks restore the original stock frame at camera priority
−1 and apply the room limit at priority +1. Roblox still owns the desired zoom,
rotation, focus and occlusion. The modifier releases its frame when it loses
camera ownership and reacquires descriptors after a Battlefield rebuild.
`GroundCombatController` projects aim at camera priority +2 so its reticle rays
use the rendered camera.

`GroundCombatController.new(player, playerGui, roundState, touchProvider?)` returns a nonyielding idempotent Lifecycle owner. It owns one GroundCombatHUD and listeners for an active living Ground player. The optional nonyielding provider controls input-mode tests; production samples UserInputService. Role/round changes, unequip, focus loss or stop release held input; stop disconnects listeners and destroys the GUI.

Desktop aim uses raw mouse viewport pixels; touch aim uses viewport center. `projectAim` rounds one pixel for ray and reticle and uses the measured GUI origin plus inset only for drawing. The equipped server-owned M-7 or launcher Tool chooses fire intent. Native tool slots select equipment; carriers on touch use M-7/ROCKET buttons. Hold left click or FIRE; R/RELOAD applies only to the M-7, while launcher reload is automatic. Ammo and reload timing come from replicated Tool attributes, so selection cannot refill a weapon.

The desktop HUD shows personal health, equipped readiness, and text for locally
detectable pickup, drop or reload rejection. The launcher row distinguishes
available, carried and returning states. A locally rejected action carries no
server intent. Remote validation remains authoritative when input is sent.

The HUD selects the local carrier’s launcher or the nearest available pickup from LauncherState’s four atomic snapshots. Its selected snapshot supplies current round/identity/owner/position/readiness presentation. E/PICK UP sends bounded acquisition intent; G/DROP releases a carried launcher. Nearness controls the prompt only; the server still checks reach, geometry, membership, life and movement. All ground teammates see available/carried status. A carrier retains its M-7. The desktop pickup and launcher-status rows sit above ammunition, with all three above the reserved native inventory region. Active Ground touch presentation shares a compact header across RoundHUD and GroundCombatHUD: summary/surrender first, then aircraft health left and weapon readiness right, then launcher ownership left. The 240×22-pixel health/readiness row occupies shared GUI-content Y=44–66; ownership uses Y=70–92. GroundCombatHUD measures its content origin and current inset each frame to align with the normally inset RoundHUD; raw viewport coordinates remain reserved for aim rays. `statusLayout(touch, origin?, inset?)` returns readiness position/size in that GUI-content space without yielding. Touch FIRE is 78×56 and RELOAD 54×42 in the upper right; 68-pixel-wide equipment actions remain below the reticle and above the 96-pixel native inventory reserve. These compact dimensions are D58 tuning defaults. Ownership loss or a new round clears local readiness/input assumptions. Clients do not clone authoritative equipment.

Current-round server-resolved rifle shots flash the shooter’s reticle. Both weapons reduce the same replicated aircraft health. RoundPanel animates the shared bar and keeps numeric health or the destruction label available independently of color.

`WeaponAudio.new(state, player)` receives cosmetic cues from `RoundState.WeaponAudio`. Its nonyielding update takes the round identity, Active state, local effect scale and synchronized seconds. It schedules delayed spatial playback from server origins, drops stale cues, and caps queued and live sounds. Reset, mute and teardown clear local voices.

`GroundAimGui.spec.luau` checks real ray/reticle alignment, mode changes, cleanup and production-created HUD rectangle separation/containment at desktop and phone sizes. The layout case constructs both production RoundPanel and GroundCombatController under distinct ScreenGui origins/insets, supplies client-only presentation state representing replicated aircraft health and checks shared coordinates, hit text, centered aim, native inventory/thumbstick reserves and teardown. This catches cross-ScreenGui overlap that a shared cloned coordinate space misses. Actual native CoreGui/simulator measurements remain separate, since Studio captures omit the hotbar. These fixtures supplement native mouse/keyboard/touch and moving-aircraft review. [P06](../../plans/06-ground-combat.md) retains earlier source-specific aiming/tracer evidence; [P08](../../plans/08-rocket-launcher.md) records eleven native harness cases passing on test source `07e77ea` with three actual clients and unchanged `ef7826b` presentation. D59 removes unsupported actual same-identity reconnect from acceptance; runtime rejoin protections remain covered by service tests. The supported P08 checks pass and the source is integrated on `main`; the [main integration record](../../docs/evidence/p08-p16-main-integration.md) identifies its matching tree. The excluded client LauncherHarness sends production pickup/drop/fire intent and observes actual replicated ownership/reload/health; it is not shipped input code.


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

Operator scenery under `Workspace.World` uses a local 0.45 brightness multiplier. An imported Model’s nearest valid `ThermalBrightness` in `[0,1]` multiplies that base, including replacement panels. Legacy textures can use temporary local clones from the Model’s `ThermalSurfacePalette` in `ReplicatedStorage.Shared`; saved colors and cloned surfaces are restored on removal/stop. MeshPart child listeners retint after late SurfaceAppearance arrival or removal, restoring the earlier fallback before acquiring the new surface; a reentrancy guard prevents local palette clones from recursively retinting. With workspace ownership, the nine authored Terrain material colors are saved, multiplied by 0.4 and restored on stop. Character colors are unchanged. The operator’s ColorCorrectionEffect uses neutral saturation, zero contrast and brightness −0.04; living Ground targets use red fill `(255,32,24)` and outline `(255,72,48)` with native occlusion. These are tuning values; rendered contrast must be reviewed. [Asset thermal checklist](../../assets/README.md#thermal-presentation-for-buildings)


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
