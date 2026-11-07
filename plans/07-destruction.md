# P07 — Partial cover destruction

**Milestone:** M4. **Dependencies:** P06. **Requirements:** R06, R07, R09, R13, R15. Status: [roadmap](../roadmap.md).

## Capability and player experience

Selected walls, windows and barricades become damaged, then break. Every player sees the same opening and can use it. Permanent buildings still provide reliable protection.

## Implementation

Add a small authored set of Intact/Damaged/Destroyed templates with stable cover IDs, thresholds and collision contracts. DestructionService applies server damage once and swaps geometry deterministically. Use pre-impact cover for all damage in that impact; only later shots benefit from a new opening. Bound cosmetic debris lifetime/count, disable its gameplay collision and restore original geometry on reset.

## Acceptance criteria

- **A1:** Full gate passes; unit tests cover threshold boundaries, monotonic state, permanent-cover immunity, repeated impacts and idempotent destruction.
- **A2:** Engine tests verify collision/query geometry for each state, consistent IDs after swaps and a traversable opening after destruction.
- **A3:** A target behind a wall destroyed by the same blast remains protected from that blast; a subsequent shot through the opening can hit. Thermal occlusion updates with the new geometry.
- **A4:** Two clients and a late-joining spectator reconstruct the same state without replaying old debris. Client-side effect changes cannot alter authoritative collision.
- **A5:** Multiple reset cycles restore all initial cover and remove debris/temporary connections. Objectives/spawns remain reachable without requiring destruction.

## Focused human check

Inspect each damage state from ground and operator views. Verify openings read clearly, debris does not block movement, and major cover remains dependable.

## Documentation changes

Document breakable IDs/templates, collision and impact-order rules, and the player's distinction between permanent and destructible cover.

## Completion record

Not implemented. Record A1–A5, source, geometry/thermal evidence and limits of the authored damage states.
