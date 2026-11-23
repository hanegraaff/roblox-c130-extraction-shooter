# Prism Seedship

[Open the editable Blender scene](prism-seedship.blend) or [view the exterior render](../../../docs/images/alien-spaceship/exterior.jpg). The dark meridians wrap around a low, split shell of veined nacre. Follow the green inlays through the south portal to the luminous spine. The west concourse houses a working-scale model of four orbital rings. On the right as you enter, three glass reliquaries hold seeds suspended inside braided cages.

## Tour the model

| View | What to look for |
| --- | --- |
| [Exterior](../../../docs/images/alien-spaceship/exterior.jpg) | The crystalline dorsal ridge, folded shoulder vents, paired threshold sentinels and broad entrance steps |
| [Starboard flank](../../../docs/images/alien-spaceship/flank.jpg) | The profile of the landed ship, layered armor shoes and clerestory openings |
| [Arrival hall](../../../docs/images/alien-spaceship/arrival-hall.jpg) | Four ranks of bifurcating arches over the polished deck, a six-petal central spine and the upper crossover |
| [Seed vault](../../../docs/images/alien-spaceship/seed-vault.jpg) | Peridot ampoules, rolled cotyledons, luminous filaments and an engraved reader |
| [Observation deck](../../../docs/images/alien-spaceship/observation-deck.jpg) | The scale of the nave from the diamond balustrade |
| [Forward breach](../../../docs/images/alien-spaceship/starboard-breach.jpg) | The torn hull and fallen sill leading directly to the starboard stair |
| [Both decks exposed](../../../docs/images/alien-spaceship/open-decks.jpg) | Routes around the double-height hall, the twin stairs and the north crossover |

The scene opens at the exterior camera. Use the Outliner to select another named camera, then press **Ctrl + Numpad 0** to make it active. To orbit the open interior, hide collections **02 • Meridian shell frame** and **03 • Nacre hull panels**. Collection **06 • Review only** contains the desert, survey figures, cameras and lighting.

## Dimensions and access

| Feature | Authored dimension |
| --- | --- |
| Plan envelope | 208 × 144 studs including the front steps and side sills. The clipped ground deck occupies about 22,021 square studs. |
| Ground and upper decks | 0 and +16 studs. The 15-stud-deep crossover connects the galleries behind the spine. |
| Roof | The polar seal peaks at +40 studs above the ground deck. The Salt Flats hangar's actual roof peaks at +62. |
| South entrance and side exits | A 32-stud clear approach at the south stair and a 16-stud clear approach at each side gate |
| Port and starboard stairs | Both flights are 10 studs wide with 24 one-stud treads, a total rise of 16 studs and 12 studs of clear upper landing depth. |
| Outside grade | −2.4 studs relative to the ground deck. The lowest ends of the frame sit below grade. |

One Blender unit represents one stud. Local +Z is up, the south entrance faces −Y, and the insertion datum is the ground-deck center. The GLB converts Blender coordinates to glTF as `(x, z, -y)`. The 208 × 144-stud authoring envelope fits the existing 212 × 146-stud southern survey. Map placement and rotation are open integration choices.

The four supplied illustrations in `src/images/alien-spaceship/` guided the work. The plan sets the dimensions, stairs, galleries, exits and room locations. The exterior and two eye-level interiors guide the pale broken plates, purple structural ribs, green optical elements, vault and historic breach. The ephemeris, botanical specimens, navigation instruments, glyphs and baked surface maps are original designs. The source packs all eight 512 × 512 maps.

## Export and damage geometry

The [assembled GLB](../../exports/alien-spaceship/prism-seedship.glb) contains 213 mesh objects, 191,414 triangles and 14 materials. The two supplemental files are for authoring damage states. All three exports omit review figures, lights, cameras and desert scenery.

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

The [Blender inspection](../../../docs/images/alien-spaceship/inspection.json) records the exact source and export hashes, dimensions, material and geometry counts, stair and doorway measurements and panel ray checks. It compares the reopened scene with all three exports imported into a new scene. The two upper routes and central hall were checked against the assembled meshes with dressing installed. Humanoid traversal, camera response, collision, thermal presentation and damage replication require a future Studio integration.
