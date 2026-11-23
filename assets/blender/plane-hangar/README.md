# Salt Flats twin-bay hangar

Open [the editable scene](salt-flats-hangar.blend) in Blender 5.3. The two parked interceptors share editable meshes. Each has a two-seat canopy, twin intakes, individual exhaust petals and turbine vanes, articulated-looking landing gear, wheel chocks and squadron markings. The separate outdoor Hercules has a severed forward fuselage, four propellers and a lowered ramp leading into a ribbed cargo hold with folding seats.

| Saved view | Detail |
| --- | --- |
| [Exterior](../../../docs/images/plane-hangar/exterior.jpg) | Twin gables, sliding doors and the wreck on the apron |
| [Service bays](../../../docs/images/plane-hangar/service-bays.jpg) | Parking lanes, open roof trusses and four gallery levels |
| [Rear gallery](../../../docs/images/plane-hangar/gallery.jpg) | Both fighters and the sightline out to the apron |
| [Interceptor](../../../docs/images/plane-hangar/interceptor.jpg) | Intake lips, canopy frames, port wing and undercarriage |
| [Salvage aircraft](../../../docs/images/plane-hangar/salvage.jpg) | Torn skin, propellers and forward ramp |
| [Cargo bay](../../../docs/images/plane-hangar/cargo-bay.jpg) | Interior ribs, side seats and sheltered aisle |

## Scale and access

One Blender unit represents one stud. The building floor is centered at the origin, Blender +Z is up and the front doors face −Y. The supplied plan fixes the shell at 208 × 144 studs and each parking stand holds a fighter approximately 50 studs across and 74 long. Four accessible levels occupy the rear of the building at +0, +12, +24 and +36 studs. The eaves rise to +48 and the twin roof peaks to +62. Both ends of the rear galleries have switchback stairs with 0.6-stud rises.

The exterior reference guided the 100-stud Hercules shell, its severed nose and its forward-facing cargo opening. The ramp spans 14.8 studs and rises just over three studs over a 16.65-stud run. A 5.5-stud standing clearance check passed at 237 positions from the ramp to the back of the cargo floor, in both the saved source and a fresh GLB reimport. In the covered section, the narrowest sampled aisle was 12.44 studs across and the lowest sampled overhead clearance exceeded 16 studs. The 120 stair treads also passed headroom and support checks in both files. The scale figures belong to the Blender presentation collection.

## Damage handoff

The outdoor aircraft's 45 removable skin pieces, ramp, ribs, fittings and other meshes all belong to the single **HerculesWreck** group. The wreck root carries the proposed game binding in both files.

| Root property | Value |
| --- | --- |
| `M102DirectHitsToClear` | 1 |
| `GAU23SustainedSecondsToClear` | 3.0 seconds, the chosen long-burst tuning |
| `DestroyedState` | Clear the complete wreck hierarchy and its collision |

The skin material also carries these thresholds in Blender. Hide collection 06 to preview the cleared wreck. Weapon events and collision removal require a game-side binding. The rest of the hangar uses its own separate building panels.

The 152 building panels carry stable `PanelId` values and origin-aligned Pristine, Light and Heavy meshes. Total clears the panel. The source shows the pristine assembly by default. To inspect an alternate, hide the matching pristine panel and isolate its named mesh from collection 07. Use the remaining mesh profiles for collision when integrating, preserving the central opening in the Heavy state.

## Export

The [assembled GLB](../../exports/plane-hangar/salt-flats-hangar.glb) contains the pristine hangar, apron, fighters and complete wreck. It has 274 mesh objects using 264 unique meshes, 203,076 assembled triangles, 24 materials and 15 embedded 512 × 512 color maps. The source also retains the alternate building panels and the presentation set. Meshes, surface maps and markings were authored locally using the four supplied hangar illustrations as visual references. The [asset manifest](../../manifest.json) records the file hashes.
