# Stock scenery for the battlefield

The level uses individual stock models from four free Creator Store packages. The Git assembly retains their existing shapes and surface maps. It contains 306 placements with no scripts or particle controllers.

| Package | Used in the level |
| --- | --- |
| [Roblox Forest Pack](https://create.roblox.com/store/asset/6432306802/Forest-Pack) | Boulders, talus, dry ferns, redwoods, mountain laurel and ferns |
| [Roblox City Props Pack](https://create.roblox.com/store/asset/6370681139/City-Props-Pack) | Telephone poles, streetlights, traffic barrels, hydrants and refuse bin |
| [EndorsedModel Pine Tree](https://create.roblox.com/store/asset/365275430/Pine-Tree) | Pines in the radar groves and younger trees at the woodland edge |
| [BodyElectrik PBR Cactuses](https://create.roblox.com/store/asset/17301398645/PBR-Cactuses) | Tall branching cacti and smaller companion plants in the wash |

Both Rojo projects include [the native assembly](DistrictScenery.rbxm) directly. For changes, export each source package as an uncompressed Roblox model file and run the placement script with the original packages in this order.

```sh
lune run scripts/districts/place_stock.luau forest.rbxm city.rbxm pine.rbxm cactus.rbxm assets/imports/districts/DistrictScenery.rbxm
```

The script selects static geometry and PBR surfaces before placing them. Boulders and telephone poles are solid. Small plants, needles and street dressing have no collision or query surface and use the existing thermal dressing rule. Record the updated assembly hash and cloud dependencies in the asset manifest.

Start a fresh Play session after syncing the stock assembly. The runtime installs the integrated buildings, paints the terrain and sets its material colors.

## Southern basin

The amber desert grades into rust-red ground around the Seedship site. The crater sits west of the landing pad. Its rim and nearby ridges rise above the original grade so the underlying support disk stays below the playable surface. The depot roads, circular bunker trail and Seedship approach remain level.

To regenerate terrain, run `python3 scripts/districts/layout.py`. For the boulders, run `python3 scripts/districts/mars_rocks.py` and execute its output in an Edit document that already contains the managed district scenery. Decode the returned base64 to `MarsBoulders.rbxm` and update its manifest hash. The compiler clones the Forest Pack mesh and native collision data with a warm stone tint. Small scree has no movement or query collision.
