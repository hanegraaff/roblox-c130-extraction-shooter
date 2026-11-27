# P27 — Mouse aiming, mobile controls and compact HUD

**Depends on** P24, P25. **Requirements** R12, R26. [Roadmap](../roadmap.md#public-mvp-launch) · [Requirements](../requirements.md)

A Ground player can move the mouse to look and turn their character. Touch players can finish a round in either role with a clear view of the battlefield and room to aim.

## Work

- In Ground play, put the reticle above the avatar while keeping it horizontally centered. Mouse motion turns the camera without holding a button. Match character yaw to horizontal aim while keeping the avatar upright. WASD moves relative to the view. Use the reticle ray for the rifle and launcher, keeping the existing server checks and obstructions.
- On touch, use the movement stick and drag-to-look together with accessible fire, reload, equip, pickup and drop actions. Check the operator’s existing pan, aim, fire and weapon switch. Keep controls clear of the reticle and the device’s screen insets.
- During Ground Scatter on touch, combine the fixed 168×24 arrival label and the separate weapons-unlock notice into one short, single-line timer at the safe top edge. Derive the seconds from the existing server deadline. Use a label such as **C-130 in 20s** and keep the launcher actions usable. Preserve the operator’s intentional full-screen blackout through the first matching thermal frame, with compact, readable countdown text and the same remaining seconds as Ground. [P24 arrival contract](24-ground-scatter-and-aircraft-arrival.md)
- Review the complete touch HUD from the lobby through Scatter, combat, results and theater spectating. Place persistent information at the edges, consolidate repeated status and show contextual prompts only when actionable. Keep round time, health, ammo and reload feedback readable whenever relevant. Preserve usable hit targets and room for simultaneous movement or pan, aim and fire. Check against Roblox’s own controls and device cutouts as well as the other game HUDs.
- Coordinate GroundIndoorCamera, GroundCombatController and role transitions. Release pointer capture for menus and the admin panel. Restore cursor, movement and camera ownership on close, death, lobby return and spectating. Controller support follows launch.

## Acceptance

1. **A1 · Aim and authority.** Test wraparound, pitch limits, avatar yaw, movement while aiming, and obstructed shots. In two-client Studio play, move the mouse without right-clicking, strafe and shoot at a visible target. Verify character facing on the other client, reticle clearance above the avatar at ordinary third-person zoom and both weapons firing through the raised point.
2. **A2 · Round transitions.** Walk through the Outpost indoors and out, use the menu, enter the lobby, spectate and switch roles on replay. Verify pointer release, zoom restoration and the operator’s independent pan and aim.
3. **A3 · Touch.** Exercise both roles on an operated phone, including moving or panning while aiming and firing, interacting at a launcher, switching weapons and returning to the lobby. Capture the device, layout and observed actions.
4. **A4 · Screen space.** Extend `GroundAimGui.spec.luau` or add a focused Studio client spec using the production HUDs. Measure visible text and bounds in common viewport coordinates at 568×320 and on a wider landscape phone with a cutout. At 568×320, target a Ground Scatter timer at most one quarter of the safe-area width and 24 UI pixels tall. Check that values from 20 through 0 fit on one line in the layout fixture. During play, verify the timer sits clear of the aiming area, launcher actions and native controls, and replaces the duplicate unlock notice. Check both roles, the lobby and spectating for clipping, overlapping controls and stale HUD elements after phase or role changes. Save comparable before and after Ground Scatter captures and record bounds and operated touch observations for both phone layouts.
5. **A5 · Arrival handoff.** Run the two-client P24 arrival harness. Verify both roles read the shared deadline, Ground can move and handle launchers during Scatter, a canceled arrival clears the timer, and the operator’s blackout stays opaque until the matching thermal frame. Verify normal desktop arrival and HUD presentation. [P24 Studio procedure](../docs/testing.md#run-the-p24-aircraft-arrival-harness)

Run the applicable [project checks](../docs/testing.md) and record the source revision, environment and observed results for each criterion.

## Documentation

Replace the Ground and operator control tables and add a touch diagram only if it clarifies the controls.

## Completion record

The same test run may cover more than one criterion or plan. Link the original report when its source and observations cover the requirement. The P26 private balance test is recorded in P26. The P27 session covers the changed client controls, HUD and arrival behavior together.

The pre-change comparison uses two Studio clients on `91880ae`. The Ground countdown is 168×24 UI pixels on both simulated phones, with a separate 240×22 weapons-unlock notice. [Baseline measurements and source binding](../docs/evidence/p27/scatter-baseline.json) · [Compact phone](../docs/evidence/p27/scatter-before-compact.jpg) · [Phone with cutout](../docs/evidence/p27/scatter-before-cutout.jpg)
