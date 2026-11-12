--!strict
--[=[
    AircraftHealth: server-only round-scoped aircraft health and shot deduplication.
    Depends only on finite scalar arguments; no Instances, transport, or yielding.
    A direct rocket deals one third of maximum health; indirect impacts never damage.
]=]
local AircraftHealth = {}
AircraftHealth.rocketDamage = 100
AircraftHealth.rifleDamage = 5
AircraftHealth.maximum = AircraftHealth.rocketDamage * 3
export type Snapshot = { roundId: number, health: number, maximum: number, destroyed: boolean }
export type Controller = {
    reset: (number) -> (),
    impact: (number, string, string, boolean) -> (number?, boolean),
    snapshot: () -> Snapshot,
}
-- Creates an independent owner. reset changes round and restores pristine health.
-- impact returns applied damage and whether this call destroyed the aircraft.
-- Invalid, duplicate, stale, indirect rocket and terminal impacts do not mutate.
function AircraftHealth.new(): Controller
    local roundId, health = 0, AircraftHealth.maximum
    local seen: { [string]: boolean } = {}
    return {
        reset = function(id)
            if id ~= roundId then
                roundId = id
                health = AircraftHealth.maximum
                table.clear(seen)
            end
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
            return {
                roundId = roundId,
                health = health,
                maximum = AircraftHealth.maximum,
                destroyed = health <= 0,
            }
        end,
    }
end
return AircraftHealth
