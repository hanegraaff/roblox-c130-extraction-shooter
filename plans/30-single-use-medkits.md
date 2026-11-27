# P30 — Medkits at each battlefield building

**Depends on** P26, P27 and medkit reference art. **Requirements** R27, R28. [Roadmap](../roadmap.md#public-mvp-launch) · [Requirements](../requirements.md)

An injured Ground player can find and use a medkit in or near each battlefield building. By default, a kit heals once and comes back next round.

## Work

- Use the [medkit references](../src/images/medkit/). Save one editable master at `assets/blender/medkit/medkit.blend` and register its managed export. Place a reachable, tucked-away kit at Sandbreak bunker, Salt Flats hangar, Vesper Radar, the military depot/Outpost and Prism Seedship. Keep the waiting lobby protected.
- Proposed interaction: use a nearby prompt to heal immediately. The server checks round, phase, living Ground role, proximity, line of sight, current health and kit availability. Apply healing up to maximum health and consume the kit atomically. A full-health player leaves it for a teammate. Resolve lethal damage and committed results before pickup.
- Read the healing amount from P26’s round preset. Each site supplies one single-use kit per round. Show health feedback and remove the spent pickup on every client. Restore kits at round end.

## Acceptance

1. **A1 · Healing rules.** Test partial and capped heals, zero missing health, raced uses, out-of-range or through-wall requests, death, spectator and stale requests. Two players using one kit can earn only one heal. Test the exact respawn boundary in optional timed mode and reset before a timer expires.
2. **A2 · World placement.** In three-client Studio play, walk to each of the five kits, use one while injured, and verify health, disappearance and replay on both Ground clients. Exercise at least one pickup on phone. Check that damage to nearby cover leaves a reachable pickup.
3. **A3 · Live tuning.** Set a different heal amount and reuse mode through the panel. Verify the current round finishes on its original preset and measure the new heal and reuse behavior in the next round.

Run the applicable [project checks](../docs/testing.md) and record the source revision, environment and observed results for each criterion.

## Documentation

Add a short player tip and explain the healing and reuse controls in the owner guide.

## Completion record

Planned checks have no results yet.
