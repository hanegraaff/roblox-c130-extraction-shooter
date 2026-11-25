# Salt Flats twin-bay hangar

Open [the editable scene](salt-flats-hangar.blend) in Blender 5.3. The file opens at the exterior camera with the packed materials and scene lighting enabled. Fighter 071 is parked for maintenance with its canopy raised and an intake cover fitted. From the access steps, you can see into both seats, down to the harnesses, instrument panels and head-up display. Fighter 072 shares the airframe meshes and has its canopy closed. Alongside the aircraft, a complete spare engine sits in a wheeled cradle. A second turbine hangs from a mobile gantry across the shop. The outdoor Hercules has an opened inboard cowling, exposed accessory plumbing and a lowered ramp into the cargo hold.

| Saved view | Detail |
| --- | --- |
| [Exterior](../../../docs/images/plane-hangar/exterior.jpg) | Twin gables, sliding doors and the wreck on the apron |
| [Service bays](../../../docs/images/plane-hangar/service-bays.jpg) | Parking lanes, open roof trusses and four gallery levels |
| [Rear gallery](../../../docs/images/plane-hangar/gallery.jpg) | Both fighters and the sightline out to the apron |
| [Interceptor](../../../docs/images/plane-hangar/interceptor.jpg) | Flush-riveted skin, fitted intake plug, service markings and wing-root walkways |
| [Salvage aircraft](../../../docs/images/plane-hangar/salvage.jpg) | Torn skin, propellers and forward ramp |
| [Cargo bay](../../../docs/images/plane-hangar/cargo-bay.jpg) | Quilted insulation, wiring looms, tie-downs and folding seats |

| Detail view | Detail |
| --- | --- |
| [Cockpit access](../../../docs/images/plane-hangar/cockpit.jpg) | Raised canopy, hinge struts and tandem cockpit |
| [Engine overhaul](../../../docs/images/plane-hangar/overhaul.jpg) | Swept fan blades, casing flanges, oil lines, gearbox and cradle |
| [Parts rack](../../../docs/images/plane-hangar/component-rack.jpg) | A skinned stabilizer and an exposed rib assembly on padded supports |
| [West elevation](../../../docs/images/plane-hangar/cladding.jpg) | Louvered bays, galvanized repair sheets, window hoods and oxide kick panels |

## Scale and access

One Blender unit represents one stud. The building floor is centered at the origin, Blender +Z is up and the front doors face −Y. The supplied plan fixes the shell at 208 × 144 studs and each parking stand holds a fighter approximately 50 studs across and 74 long. Four accessible levels occupy the rear of the building at +0, +12, +24 and +36 studs. The eaves rise to +48 and the twin roof peaks to +62. Both ends of the rear galleries have switchback stairs with 0.6-stud rises.

Concrete forms the exposed walking surface on each upper gallery. The steel
deck sits below it, the top treads meet the gallery and switchback landings at
their edges, and the yellow stair-nose trim is inset 0.04 studs from the steel
ends. These seams keep the adjacent materials from drawing over each other.

The exterior reference guided the 100-stud Hercules shell, its severed nose and its forward-facing cargo opening. The ramp spans 14.8 studs and rises just over three studs over a 16.65-stud run. A 5.5-stud standing clearance check passed at 237 positions from the ramp to the back of the cargo floor, in both the saved source and a fresh GLB reimport. In the covered section, the narrowest sampled aisle was 12.44 studs across and the lowest sampled overhead clearance exceeded 16 studs. The 120 stair treads also passed headroom and support checks in both files. A further 123 samples verified standing clearance along the central hangar aisle after the new machinery was installed. The scale figures belong to the Blender presentation collection.

## Damage handoff

The outdoor aircraft's 45 removable skin pieces, ramp, ribs, fittings and other meshes all belong to the single **HerculesWreck** group. The wreck root carries the proposed game binding in both files.

| Root property | Value |
| --- | --- |
| `M102DirectHitsToClear` | 1 |
| `GAU23SustainedSecondsToClear` | 3.0 seconds, the chosen long-burst tuning |
| `DestroyedState` | Clear the complete wreck hierarchy and its collision |

The skin material also carries these thresholds in Blender. Hide collection 06 to preview the cleared wreck. Weapon events and collision removal require a game-side binding. The rest of the hangar uses its own separate building panels.

Eight cladding profiles distinguish concrete plinths, steel window surrounds, louvers, repair plates, replacement cassettes, sliding doors, gables and roof flashings. Each profile follows its owning panel and its damage variants. A ray check through the center of all 152 Heavy variants confirmed that their cladding clears the breach. The 152 building panels carry stable `PanelId` values and origin-aligned Pristine, Light and Heavy meshes. Total clears the panel. The source shows the pristine assembly by default. To inspect an alternate, hide the matching pristine panel and isolate its named mesh from collection 07. Use the remaining mesh profiles for collision when integrating, preserving the central opening in the Heavy state.

## Export

The [assembled GLB](../../exports/plane-hangar/salt-flats-hangar.glb) contains the pristine hangar, apron, fighters and complete wreck. It has 341 mesh objects using 328 unique meshes, 327,336 assembled triangles, 36 materials and 23 embedded images. The images include a dedicated airframe seam normal map and color and roughness maps for the hardstand. The source also retains the alternate building panels and the presentation set. Meshes, surface maps and markings were authored locally using the four supplied hangar illustrations as visual references. The [asset manifest](../../manifest.json) records the file hashes.
