# P10 — Player guidance, spectating and presentation

**Milestone:** M6. **Dependencies:** P09. **Requirements:** R04, R12, R15. Status: [roadmap](../roadmap.md).

## Capability and player experience

A new player understands their role, controls, aircraft health, launcher availability and result without a developer narrating the session. Spectating, thermal view, effects and audio feel like one coherent game.

## Implementation

Consolidate role-specific HUD/help, launcher ownership/recovery messages and weapon-specific zoom feedback, ammunition/cooldown/health, accessible result reasons and spectator target cycling. Add authored stylized art/audio/effects within the asset manifest. Important sounds have visible cues; color has text/icon equivalents. Add effect/camera-shake intensity controls. Keep full functionality at 1280×720 and 1920×1080 desktop viewports. Do not add touch/gamepad, purchases or progression.

## Acceptance criteria

- **A1:** Full gate passes; view-model tests cover each phase/role, death, destroyed aircraft, operator forfeit, no living spectator targets, rejected actions and result reason.
- **A2:** Engine UI tests show correct role controls, legible aircraft-health/timer/ammo/launcher state and both named aircraft weapons, bounded layout at both target resolutions, and keyboard-operable help/settings.
- **A3:** Spectators follow living teammates only, never gain weapon/interact authority and recover to a neutral view when targets disappear. Role/reset transitions restore camera/input and clear duplicate UI.
- **A4:** Settings change effects without gameplay advantage or state mutation. Required warnings/results have visual equivalents independent of audio/color.
- **A5:** All added assets have provenance and ownership records; their source/reference dependencies build cleanly and no imported unintended scripts remain.

## Focused human check

Have a tester complete both roles from in-game instructions. Inspect thermal contrast, warning/impact frames, launcher ownership/reload, both weapon zoom levels, aircraft destruction and team-result states, defeat/spectate and two viewport sizes. Capture actual gameplay screenshots for the README only after reviewing them; label the build shown.

## Documentation changes

Make the README a truthful player guide to the whole current game, with actual controls and curated screenshots if available. Keep contributor setup elsewhere. Document asset credits and current limitations.

## Completion record

Not implemented. Record A1–A5, source, viewport evidence, onboarding findings and the exact assets/screenshots used.
