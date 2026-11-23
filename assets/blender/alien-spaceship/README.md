# Prism Seedship

[Open the editable Blender scene](prism-seedship.blend). It opens in the S-4 recovery bay, where Specimen 07 lies on a cushioned examination slab under a three-lens scanner. The dark eyes, folded sensory fans behind the jaw and long four-fingered hands are visible in the [specimen portrait](../../../docs/images/alien-spaceship/specimen-07.jpg). A numbered Groom Lake case plate and a terminal displaying the cranial scan give the bay its Area 51 character.

Through the south portal, an exposed turbine and three illuminated resonator chambers flank the central aisle. Follow the green deck inlays to the luminous spine, then take either stair to the upper galleries to find the memory-rod rack and suspended helical navigation instrument. The preserved alien is the only figure aboard.

## Tour the model

| View | What to look for |
| --- | --- |
| [S-4 recovery bay](../../../docs/images/alien-spaceship/recovery-bay.jpg) | The specimen, surgical scanner, wheeled instrument tray and case plate together |
| [Specimen 07](../../../docs/images/alien-spaceship/specimen-07.jpg) | Mottled skin, swept corneas, eyelid folds and paired sensory fans |
| [Field machinery](../../../docs/images/alien-spaceship/field-machinery.jpg) | Petal blades, concentric rings and the exposed turbine housing |
| [Resonator bank](../../../docs/images/alien-spaceship/resonator-bank.jpg) | Three phase chambers and the connections between them |
| [Exterior](../../../docs/images/alien-spaceship/exterior.jpg) | The crystalline dorsal ridge, folded shoulder vents, paired threshold sentinels and broad entrance steps |
| [Starboard flank](../../../docs/images/alien-spaceship/flank.jpg) | The profile of the landed ship, layered armor shoes and clerestory openings |
| [Arrival hall](../../../docs/images/alien-spaceship/arrival-hall.jpg) | Four ranks of bifurcating arches over the polished deck, a six-petal central spine and the upper crossover |
| [Seed vault](../../../docs/images/alien-spaceship/seed-vault.jpg) | Peridot ampoules, rolled cotyledons, luminous filaments and an engraved reader |
| [Observation deck](../../../docs/images/alien-spaceship/observation-deck.jpg) | The scale of the nave from the diamond balustrade |
| [Forward breach](../../../docs/images/alien-spaceship/starboard-breach.jpg) | The torn hull and fallen sill leading directly to the starboard stair |
| [Both decks exposed](../../../docs/images/alien-spaceship/open-decks.jpg) | Routes around the double-height hall, the twin stairs and the north crossover |

Use the Outliner to select another named camera, then press **Ctrl + Numpad 0** to make it active. To orbit the open interior, hide collections **02 • Meridian shell frame** and **03 • Nacre hull panels**. Collection **06 • Review only** holds the desert set, cameras and lighting.

## Dimensions and access

| Feature | Authored dimension |
| --- | --- |
| Plan envelope | 208 × 144 studs including the front steps and side sills. The clipped ground deck occupies about 22,021 square studs. |
| Ground and upper decks | 0 and +16 studs. The 15-stud-deep crossover connects the galleries behind the spine. |
| Roof | The polar seal peaks at +40 studs above the ground deck. The Salt Flats hangar's actual roof peaks at +62. |
| South entrance and side exits | A 32-stud clear approach at the south stair and a 16-stud clear approach at each side gate |
| Port and starboard stairs | Both flights are 10 studs wide with 24 one-stud treads, a total rise of 16 studs and 12 studs of clear upper landing depth. |
| Outside grade | −2.4 studs relative to the ground deck. The lowest ends of the frame sit below grade. |

One Blender unit represents one stud. Local +Z is up, the main entrance faces −Y, and the insertion datum is the ground-deck center. The GLB converts Blender coordinates to glTF as `(x, z, -y)`. The 208 × 144-stud envelope fits the 212 × 146-stud southern site. [Roblox import staging and placement](IMPORT.md)

The four supplied illustrations in `src/images/alien-spaceship/` guided the work. The plan sets the dimensions, stairs, galleries, exits and room locations. The exterior and two eye-level interiors guide the pale broken plates, purple structural ribs, green optical elements, vault and historic breach. The ephemeris, botanical specimens, machinery, preserved alien and diagnostic graphics are original designs. The source packs eight 512 × 512 mineral maps, two 448 × 768 skin maps and one 512 × 384 diagnostic atlas.

## Export and damage geometry

The [assembled GLB](../../exports/alien-spaceship/prism-seedship.glb) contains 225 mesh objects, 227,142 triangles and 24 materials. It includes the specimen, lab equipment and both furnished decks. The two supplemental files provide alternate hull damage states. Cameras, lights and desert scenery stay in the Blender review collection.

| File | Contents |
| --- | --- |
| [Panel catalog](panel-catalog.json) | 102 stable identities across the skirt, mantle, roof and crown, with a local pivot, story, placement and exact object names per panel |
| [Light and intact proxies](../../exports/alien-spaceship/light-and-intact-proxies.glb) | Fracture-marked Light skins and the query geometry shared by Pristine and Light |
| [Heavy and fragments](../../exports/alien-spaceship/heavy-and-fragments.glb) | Torn Heavy skins, matching residual query solids and four local-origin spall meshes |

Collection **05 • Damage variants, proxies and spalls** is disabled by default. To inspect a state in Blender, hide its Pristine object, enable collection 05, select the matching Light or Heavy object by catalog name, and isolate it with **Numpad /**. Each variant shares the original panel pivot. Heavy opens about half the remaining panel surface, including the plates already torn around the historic breach. Total clears the visual and query mesh. Floors, stairs and load-bearing ribs have separate identities. The hull carries its own optical details when removed. Independent instruments and loose rubble carry the `ThermalNonCover` handoff property.

## Rebuild and inspect

Use Blender 5.3 from the repository root. On macOS the installed executable can be substituted for `blender` as `/Applications/Blender.app/Contents/MacOS/Blender`.

```sh
blender -b --python-exit-code 1 -P scripts/seedship/build.py
blender -b --python-exit-code 1 -P scripts/seedship/inspect_asset.py
blender -b assets/blender/alien-spaceship/prism-seedship.blend --python-exit-code 1 -P scripts/seedship/render.py
python3 scripts/seedship/record_manifest.py
python3 scripts/p17_harness.py --write
python3 scripts/verify.py
```

The [Blender inspection](../../../docs/images/alien-spaceship/inspection.json) compares the reopened scene with the three exports imported into a fresh scene. It records their hashes and dimensions, checks all 102 damage panels, measures stair and doorway clearance, and samples routes through the furnished ship. Recovery-bay checks count the sole specimen and nine equipment objects, measure four points where the body rests on the slab and test a four-stud-wide approach along its west side. Native avatar traversal, collision, camera response, thermal presentation and damage replication belong to the subsequent Studio integration.
