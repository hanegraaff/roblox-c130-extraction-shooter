# P10 — Player guidance, spectating and presentation

**Milestone:** M6. **Dependencies:** P09. **Requirements:** R04, R12, R15. Status: [roadmap](../roadmap.md).

## Capability and player experience

A new player understands their role, controls, aircraft health, launcher availability and result without a developer narrating the session. Spectating, thermal view, effects and audio feel like one coherent game.

## Implementation

Consolidate role-specific HUD and help, launcher ownership and recovery messages,
WASD pan, mouse aim and recenter guidance, panel-damage progression, weapon-specific
zoom, ammunition, cooldown and health feedback, accessible result reasons, and
spectator target cycling. Add readable stylized cues, audio and effects with
provenance in the asset manifest. P13 and P07 already supply terrain, buildings
and destruction, and P16/P17 supply the detailed Outpost. Important sounds have
visible cues, and labels or icons convey information also shown by color. Add
effect and camera-shake intensity controls. Keep full functionality at 1280×720
and 1920×1080 desktop viewports, and preserve the existing touch controls.

## Acceptance criteria

- **A1:** Full gate passes; view-model tests cover each phase/role, death, destroyed aircraft, operator forfeit, no living spectator targets, rejected actions and result reason.
- **A2:** Engine UI tests show correct role controls, legible aircraft-health/timer/ammo/launcher state and both named aircraft weapons, bounded layout at both target resolutions, and keyboard-operable help/settings.
- **A3:** Spectators follow living teammates only, never gain weapon/interact authority and recover to a neutral view when targets disappear. Role/reset transitions restore camera/input and clear duplicate UI.
- **A4:** Settings change effects without gameplay advantage or state mutation. Required warnings/results have visual equivalents independent of audio/color.
- **A5:** All added assets have provenance and ownership records; their source/reference dependencies build cleanly and no imported unintended scripts remain.

## Focused human check

Have a tester complete both roles from in-game instructions. Inspect thermal
contrast, warning and impact frames, launcher ownership and reload, both weapon
zoom levels while panning, building-panel stages and physical debris, aircraft
destruction and team results, defeat and spectating, and both desktop viewport
sizes. Keep reviewed gameplay captures in the linked evidence record.

## Documentation changes

The dedicated military-outpost art work is scoped separately in
[P16](16-blender-military-outpost-assets.md) (Blender assets and human approval)
and [P17](17-integrate-military-outpost.md) (smaller-Outpost integration).
P10 retains its presentation/onboarding scope. D63 schedules P16/P17 before
P09 and this plan, so onboarding and presentation must describe the approved
Outpost actually present in the tested candidate.

Update the README's player guide and local setup for the current game. Keep the
selected P16 Blender authoring image in the README and link reviewed gameplay
captures in the evidence guide. Document asset credits and current limitations.

## Completion record

Not implemented. Record A1–A5, source, viewport evidence, onboarding findings and the exact assets/screenshots used.
