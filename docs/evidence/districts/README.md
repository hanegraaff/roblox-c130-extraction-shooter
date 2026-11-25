# Battlefield districts in Studio

The map uses 306 placements from four Creator Store packs and eight built-in terrain materials. Four survey corners surround the empty 212 × 146-stud south pad. [Stock packages](../../../assets/imports/districts/README.md)

| View in Play | What to look for |
| --- | --- |
| [Battlefield from above](overview.jpg) | The exterior bunker circuit branches northwest to Salt Flats, northeast to Vesper and east to the depot. The south pad sits below the bunker. |
| [Sandbreak wash and Salt Flats](desert.jpg) | Cacti and boulder outcrops lead across yellow sand toward the hangar apron. |
| [Vesper Radar](vesper.jpg) | The trail meets the south gate through grass and woodland. |
| [Military depot](depot.jpg) | Utility poles, barrels and hydrants surround the building. |
| [Depot parking lot](parking.jpg) | Two rows of worn bays meet the curved access road at the foot of the exterior stairs. |

## Verification on 2026-11-23

The images come from the connected local Studio test place during Play. The review used fixed cameras with the HUD hidden. The server and client each loaded all 380 district MeshParts with a mesh ID and positive native mesh size. On both sides, every stock part's world bounds cleared the southern reserve. A server overlap query also found zero solid map parts inside the footprint up to 80 studs high.

The integrated map passed 628 collision checks along the four exit paths, the exterior circuit and all three building approaches. A 4 × 5.8 × 4-stud upright probe checked solid geometry at intervals of at most two studs. To repeat the geometry check, run `python3 scripts/districts/studio_probe.py` and paste its output into the Server Command Bar during Play. The same Play session passed 199 server and 14 client TestEZ cases. [Studio results](studio.json)

A separate three-client Studio session passed all 11 launcher scenarios. Two Ground clients contested one pickup, held different site launchers simultaneously and exercised transfer, reload, death, disconnect and reset. It used controlled character poses and real client intents. [Multiplayer results](multiplayer.json)

The host gate ran with `python3 scripts/verify.py`. Its 83 unit and 78 integration cases passed, as did 20 tooling and 56 asset tests. The release asset inventory matched the game's recorded mesh, texture and audio references.
