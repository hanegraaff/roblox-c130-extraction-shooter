# P08 — One recoverable map rocket launcher

**Milestone:** M5. **Dependencies:** P07. **Requirements:** R08, R10, R13, R15. Status: [roadmap](../roadmap.md).

## Capability and player experience

One rocket launcher is available at its map anchor. A ground player can reach it, carry it alongside their M-7 and land the three direct hits needed to destroy a full-health C-130. Teammates can recover it when its carrier drops it, dies or disconnects.

## Implementation

Add LauncherService with one round-owned identity and Available/Held/Recovering transitions. Validate pickup range/life/role and plausible movement; claim atomically without yielding. Keep reload readiness on the weapon identity across transfers. Implement single-round replenishing reload, explicit drop, death/disconnect recovery and fallback to the original anchor for invalid/unreachable positions. Add ownership/readiness HUD and bounded dropped models. Use P06 rocket damage/projectile rules, not a new health system. Do not introduce other items, ammo pickups or a collection counter.

## Acceptance criteria

- **A1:** Full gate passes. Exactly one launcher exists in the round across available/held/recovery states. Two simultaneous pickup requests, duplicate messages and rapid transfer cannot create a second owner or weapon representation.
- **A2:** Wrong role, dead/spectator, invalid ID, impossible travel/reach, stale round and flood requests reject without ownership/ammo mutation. A valid pickup works afterward; M-7 remains available to the carrier.
- **A3:** During an active round, drop, death, character reset and disconnect preserve reload state and produce one recoverable weapon. Terminal cleanup takes precedence after a result. Invalid/out-of-bounds positions return it to its anchor. Switching/re-picking cannot fire before reload finishes; replenishment never creates ammo items.
- **A4:** Real launcher impacts apply the P06 contract: two direct hits alone leave a pristine plane alive, the third ends the round as ground win, and earlier rifle damage reduces remaining health. Miss/obstruction/duplicate impacts do not add a full direct hit. Configured timing permits at least three shots during the round.
- **A5:** A Studio session with one operator and two ground clients demonstrates raced acquisition, carrier death/disconnect and teammate recovery. Clients agree on ownership, reload and aircraft health; reconnect cannot restore a carried launcher or active life.
- **A6:** Reset removes old held/dropped/projectile state and spawns exactly one launcher at the original anchor. A delayed prior-round callback cannot grant ownership or damage the next aircraft.

## Focused human check

Traverse both launcher approaches, pick up, switch between M-7 and launcher, fire/miss/reload, drop and recover it. Check that the team can tell whether it is available or carried and how many damaging hits remain without implying a false fixed count after rifle damage.

## Documentation changes

Explain the single launcher, recovery/default replenishment and actual controls. Document ownership, reload continuity and recovery contracts.

## Completion record

Not implemented. Record A1–A6, source, three-client transfer evidence and timing/readability observations.
