--!strict
--[=[
    GroundMovementGuard: server-only bounded movement budget for ground firing origins.
    Depends only on finite coordinates and monotonic server seconds. The owner samples
    the server-observed root each Heartbeat and before fire. It is not a ban or a full
    anti-cheat: a finite burst and lag tolerance are deliberate tuning defaults.
]=]
local GroundMovementGuard = {}
-- Studs, studs per second, and seconds; generous for normal movement and short
-- replication gaps while preventing unlimited travel credit from idle time.
GroundMovementGuard.burstStuds = 45
GroundMovementGuard.speedStudsPerSecond = 70
GroundMovementGuard.recoveryStuds = 8
export type Controller = {
    sample: (number, number, number, number) -> boolean,
    reset: (number, number, number, number) -> boolean,
}
local function finite(value: number): boolean
    return value == value and math.abs(value) < math.huge
end
-- Creates one character-scoped budget. reset is for a trusted server spawn or
-- correction only. sample rejects bad time/position and quarantines suspicious
-- jumps until the character returns near its last trusted position or the server
-- explicitly resets the budget. Rejection does not grant ammunition or damage.
function GroundMovementGuard.new(): Controller
    local x, y, z, lastTime, credit = 0, 0, 0, 0, 0
    local initialized, quarantined = false, false
    local function valid(px: number, py: number, pz: number, now: number): boolean
        return finite(px) and finite(py) and finite(pz) and finite(now)
    end
    return {
        reset = function(px, py, pz, now)
            if not valid(px, py, pz, now) then
                return false
            end
            x, y, z, lastTime = px, py, pz, now
            credit = GroundMovementGuard.burstStuds
            initialized, quarantined = true, false
            return true
        end,
        sample = function(px, py, pz, now)
            if not initialized or not valid(px, py, pz, now) or now < lastTime then
                return false
            end
            local distance = math.sqrt((px - x) ^ 2 + (py - y) ^ 2 + (pz - z) ^ 2)
            if not finite(distance) then
                return false
            end
            credit = math.min(
                GroundMovementGuard.burstStuds,
                credit + (now - lastTime) * GroundMovementGuard.speedStudsPerSecond
            )
            lastTime = now
            if quarantined then
                if distance > GroundMovementGuard.recoveryStuds then
                    return false
                end
                quarantined = false
            elseif distance > credit then
                quarantined = true
                return false
            end
            credit = math.max(0, credit - distance)
            x, y, z = px, py, pz
            return true
        end,
    }
end
return GroundMovementGuard
