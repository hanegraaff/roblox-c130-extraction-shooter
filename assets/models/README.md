# Server-owned model templates

Rojo maps this folder to `ServerStorage.Assets`. [`CoverPanel.model.json`](CoverPanel.model.json) is an original anchored, collidable 16×8×2-stud primitive panel, centered at `(0,4,0)`. It reserves a template for later cover replacement; no current service clones or damages it. Its provenance is recorded in the [asset manifest](../manifest.json), with no external asset or script dependency.

Aircraft, M-7, launcher and destructible-cover state variants remain planned. Services will clone only the world representations clients need. Document origin/license in the manifest and stable pivots, hitboxes, damage anchors, attachment names and cover IDs beside each model. Use deterministic fixtures and real-engine checks to verify those contracts.
