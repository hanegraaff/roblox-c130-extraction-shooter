# Static battlefield source

This folder maps to `Workspace.World` through Rojo. `FoundationSpawn.model.json` is an original 64×2×64-stud anchored, collidable, neutral SpawnLocation at the origin, used as the temporary platform in both builds. Its provenance is recorded in the [manifest](../manifest.json), with no cloud asset dependency. The server Studio smoke checks it with a real raycast.

Plan 02 will add the circular greybox district, protected spawn anchors, one launcher anchor, map center/perimeter and tagged cover. Those map features do not exist yet.

Own authored static objects here. Server services may instantiate a round from these definitions/templates, but transient projectiles, debris and playtest changes must not be exported back as source. Validate reachable launcher approaches, circular bounds and stable IDs in map tests.
