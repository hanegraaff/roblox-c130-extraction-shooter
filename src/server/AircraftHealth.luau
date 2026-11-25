--!strict
--[=[
    AircraftHealth: server-only round-scoped aircraft health and shot deduplication.
    Maximum is 1,000 game health units per deployment Ground player, excluding
    the operator. Counts are locked at reset; later roster changes never resize
    or heal the current aircraft. Fixed rockets deal 150 units and M-7 hits 5.
    Pure finite-scalar rules: no Instances, transport, clock or yielding.
]=]
local AircraftHealth = {}
AircraftHealth.rocketDamage = 150
AircraftHealth.rifleDamage = 5
AircraftHealth.healthPerGroundPlayer = 1000
-- One-Ground-player preview/Lobby baseline; active rounds use maximumFor(count).
AircraftHealth.maximum = AircraftHealth.healthPerGroundPlayer
export type Snapshot = { roundId: number, health: number, maximum: number, destroyed: boolean }
export type Controller = {
    reset: (number, number?) -> boolean,
    impact: (number, string, string, boolean) -> (number?, boolean),
    snapshot: () -> Snapshot,
}

-- Valid deployment teams contain 1–9 Ground players. Reject nonfinite/fractional
-- or out-of-range counts without creating authority state.
function AircraftHealth.maximumFor(groundPlayers: number): number?
    if groundPlayers ~= groundPlayers or groundPlayers % 1 ~= 0 or groundPlayers < 1 or groundPlayers > 9 then
        return nil
    end
    return groundPlayers * AircraftHealth.healthPerGroundPlayer
end

-- Creates an independent owner. reset accepts a newer positive integral round
-- and optional deployment Ground count (default one for deterministic fixtures).
-- Same/stale/invalid resets reject without clearing damage or deduplication.
-- impact returns applied units and whether this call alone destroyed the plane.
function AircraftHealth.new(): Controller
    local roundId, maximum = 0, AircraftHealth.maximum
    local health = maximum
    local seen: { [string]: boolean } = {}
    return {
        reset = function(id, groundPlayers)
            local nextMaximum = AircraftHealth.maximumFor(groundPlayers or 1)
            if id ~= id or id % 1 ~= 0 or id <= roundId or id > 2147483647 or not nextMaximum then
                return false
            end
            roundId, maximum, health = id, nextMaximum, nextMaximum
            table.clear(seen)
            return true
        end,
        impact = function(id, shotId, weapon, direct)
            if
                id ~= roundId
                or id <= 0
                or health <= 0
                or type(shotId) ~= "string"
                or #shotId == 0
                or #shotId > 100
                or seen[shotId]
            then
                return nil, false
            end
            local damage = if weapon == "M7"
                then AircraftHealth.rifleDamage
                elseif weapon == "RocketLauncher" and direct then AircraftHealth.rocketDamage
                else 0
            if damage <= 0 or not direct then
                return nil, false
            end
            seen[shotId] = true
            local applied = math.min(damage, health)
            health -= applied
            return applied, health == 0
        end,
        snapshot = function()
            return { roundId = roundId, health = health, maximum = maximum, destroyed = health <= 0 }
        end,
    }
end
return AircraftHealth
