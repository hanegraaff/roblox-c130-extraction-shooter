# Static battlefield source

Plan 02 adds the circular greybox district, safe spawn anchors, one rocket-launcher anchor, map center/perimeter and tagged cover. This folder maps to `Workspace.World` through Rojo and currently contains no geometry.

Own authored static objects here. Server services may instantiate a round from these definitions/templates, but transient projectiles, debris and playtest changes must not be exported back as source. Validate reachable launcher approaches, circular bounds and stable IDs in map tests.
