# Avatar and camera clearance for Roblox buildings

Open this guide when authoring a walkable building, room, stairs or another space whose geometry affects the player camera.

## Measure the character and the space it needs

Use the target experience's permitted avatar rig, scale and accessory policy. Measure character collision and standing height, movement and jump envelope, and the room needed to turn, pass another character or carry equipment when the game calls for it. A neutral scale dummy is an early design aid. Use a representative Roblox Humanoid for verification.

Measure effective clear space with thickness, collision proxies and installed dressing included. Record the narrowest door and landing, clear headroom below beams and stairs, usable tread run and riser height, turn and passing space, and support at floor, stair and balcony seams. Walk the actual turns and transitions in each direction. Test both floors of multi-story assets and independent inside/outside routes when provided.

## Check the camera as a second moving body

Use the default outdoor zoom and representative user-controlled zooms, pitch angles and screen sizes. Test following the avatar through doorways, looking along walls and across corners, climbing stairs, looking up under ceilings, and turning near detailed props. A character can fit through a route while its trailing camera crosses a wall or sits above a ceiling.

| What happens in the test | Authoring response |
| --- | --- |
| The avatar bumps the jamb or cannot turn or pass | Widen the actual usable route or move its blockers. Review door frames, furniture, landing and headroom before changing the whole building. |
| The avatar fits and a useful third-person camera can fit with more room | Increase selected ceiling heights or room and landing depth if site and appearance permit. Confirm the minimum effective change in the blockout. |
| A compact room is intentional or the existing site must fit | Mark the usable interior and document the camera clearance it can support. Coordinate optional, reversible indoor camera assistance with the experience's existing camera owner. Keep solid gameplay cover opaque. |
| Both avatar and normal camera have comfortable clearance | Keep the ordinary camera in that space. |

Plan clearance in studs for each limiting route and angle. A proposed percentage increase from a single building does not define a general Roblox dimension. Compare any changes against existing site, room proportions and matched reference views.

## Hand off the evidence

For a per-route receipt, name the limiting object and record the measured clearance and camera settings. For example, record an upper-floor table as the narrowest turn, the clear width in studs, the avatar tested, and the follow distance and pitch that exposed the ceiling. Include the result after any layout adjustment.

Annotate routes and choke points, avatar and camera test setups, clear dimensions, and any proposed interior camera zone boundaries. In Studio, verify the actual rendered and collision geometry together. Capture an ordinary play view as well as geometry measurements. Keep the results for normal outdoor zoom, useful indoor view, threshold crossings, stair and balcony transitions, and whether intact cover conceals another character. See the [Roblox camera settings guide](https://create.roblox.com/docs/workspace/camera#occlusion-mode).
