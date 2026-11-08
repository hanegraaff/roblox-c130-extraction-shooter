--!strict
--[=[
    AircraftRules: public deterministic P04 orbit, zoom and aim geometry. Depends on
    MapRules/Validation; no Instances, clocks or yielding. Seconds, studs and radians
    are explicit. These public values convey no authority; the server owns selection.
]=]
local MapRules = if script then require(script.Parent.MapRules) else require("./MapRules")
local Validation = if script then require(script.Parent.Validation) else require("./Validation")
local AircraftRules = {}

export type Settings = { periodSeconds: number, fov30mm: number, fov105mm: number }
export type Pose = { x: number, y: number, z: number, tangentX: number, tangentZ: number, phase: number }
AircraftRules.defaults = table.freeze({ periodSeconds = 90, fov30mm = 35, fov105mm = 60 })
AircraftRules.names = table.freeze({ GAU23 = "30mm GAU-23/A Chain Gun", M102 = "105mm M102 Howitzer" })

-- Validates a complete bounded config and returns a copy. FOV uses degrees as Roblox does.
function AircraftRules.validate(value: unknown): (Settings?, string?)
    if type(value) ~= "table" or not Validation.flatPayload(value, 3, 32) then
        return nil, "invalid aircraft settings"
    end
    local fields = value :: { [string]: unknown }
    for _, name in { "periodSeconds", "fov30mm", "fov105mm" } do
        local number = fields[name]
        if type(number) ~= "number" or not Validation.isFinite(number) then
            return nil, "aircraft settings require finite " .. name
        end
    end
    local config = (fields :: unknown) :: Settings
    if config.periodSeconds < 10 or config.periodSeconds > 3600 then
        return nil, "orbit period must be 10–3600 seconds"
    end
    if config.fov30mm < 1 or config.fov105mm > 120 or config.fov30mm >= config.fov105mm then
        return nil, "zoom requires 1 <= FOV30mm < FOV105mm <= 120"
    end
    return table.clone(config), nil
end

-- Samples the CCW perimeter using injected elapsed seconds; negative elapsed wraps too.
-- Returns nil for invalid time/config, including overflow. Position tolerance is 1e-6
-- studs in pure tests; engine CFrames require 0.01 studs due to float serialization.
function AircraftRules.pose(map: typeof(MapRules.defaults), settings: Settings, elapsedSeconds: number): Pose?
    if
        not Validation.isFinite(elapsedSeconds)
        or not AircraftRules.validate(settings)
        or not MapRules.validate(map)
    then
        return nil
    end
    local phase = (elapsedSeconds % settings.periodSeconds) / settings.periodSeconds * 2 * math.pi
    local x, y, z = MapRules.orbit(map, phase)
    if not Validation.isFinite(x) or not Validation.isFinite(y) or not Validation.isFinite(z) then
        return nil
    end
    return { x = x, y = y, z = z, tangentX = -math.sin(phase), tangentZ = math.cos(phase), phase = phase }
end

-- Unknown IDs fail closed. A selected profile always defines both name and projection.
function AircraftRules.fov(settings: Settings, weapon: string): number?
    if weapon == "GAU23" then
        return settings.fov30mm
    elseif weapon == "M102" then
        return settings.fov105mm
    end
    return nil
end

-- Future fire adapter seam: a finite endpoint must lie within the playable disk and
-- ground-to-aircraft vertical envelope. This is geometry only, not line-of-sight proof.
function AircraftRules.aimAllowed(map: typeof(MapRules.defaults), x: number, y: number, z: number): boolean
    if
        not MapRules.validate(map)
        or not Validation.isFinite(x)
        or not Validation.isFinite(y)
        or not Validation.isFinite(z)
    then
        return false
    end
    local upper = map.groundY + map.altitudeStuds
    local dx = (x - map.centerX) / map.radiusStuds
    local dz = (z - map.centerZ) / map.radiusStuds
    return Validation.isFinite(upper)
        and Validation.isFinite(dx)
        and Validation.isFinite(dz)
        and y >= map.groundY - 1
        and y <= upper
        and dx * dx + dz * dz <= 1
end
return AircraftRules
