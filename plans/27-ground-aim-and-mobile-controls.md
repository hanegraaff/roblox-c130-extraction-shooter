# P27 — Mouse aiming and mobile controls

**Depends on** P24, P25. **Requirements** R26. [Roadmap](../roadmap.md#public-mvp-launch) · [Requirements](../requirements.md)

A Ground player can move the mouse to look and turn their character. Desktop and touch players can finish a round in either role.

## Work

- In Ground play, use a centered reticle. Mouse motion turns the camera without holding a button. Match character yaw to horizontal aim while keeping the avatar upright. WASD moves relative to the view. Use the reticle ray for the rifle and launcher, keeping the existing server checks and obstructions.
- On touch, use the movement stick and drag-to-look together with accessible fire, reload, equip, pickup and drop actions. Check the operator’s existing pan, aim, fire and weapon switch. Keep controls clear of the reticle and the device’s screen insets.
- Coordinate GroundIndoorCamera, GroundCombatController and role transitions. Release pointer capture for menus and the admin panel. Restore cursor, movement and camera ownership on close, death, lobby return and spectating. Controller support follows launch.

## Acceptance

1. **A1 · Aim and authority.** Test wraparound, pitch limits, avatar yaw, movement while aiming, and obstructed shots. In two-client Studio play, move the mouse without right-clicking, strafe and shoot at a visible target. Verify character facing on the other client and that both weapons aim through the center.
2. **A2 · Round transitions.** Walk through the Outpost indoors and out, use the menu, enter the lobby, spectate and switch roles on replay. Verify pointer release, zoom restoration and the operator’s independent pan and aim.
3. **A3 · Touch.** Exercise both roles on an operated phone, including moving, turning and firing together, interacting at a launcher, weapon switching and returning to the lobby. Capture device, layout and observed actions. Include a Studio phone-layout regression for button overlap.

Run the applicable [project checks](../docs/testing.md) and record the source revision, environment and observed results for each criterion.

## Documentation

Replace the Ground and operator control tables and add a touch diagram only if it clarifies the controls.

## Completion record

Planned checks have no results yet.
