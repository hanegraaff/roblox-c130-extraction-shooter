--!strict
--[=[
    Config: shared pure validation for the foundation's public population/timing defaults.
    Depends only on Validation. No engine APIs, mutation or yielding. Test overrides are server-only.
]=]
local Validation = if script then require(script.Parent.Validation) else require("./Validation")
local Config = {}

-- Population is integral; round duration is seconds. No development override belongs in this record.
export type Settings = { minPlayers: number, maxPlayers: number, roundDurationSeconds: number }
Config.defaults = table.freeze({ minPlayers = 6, maxPlayers = 10, roundDurationSeconds = 600 })

-- Decodes unknown input to a fresh typed record, or a useful rejection reason without mutation.
function Config.validate(value: unknown): (Settings?, string?)
    if not Validation.flatPayload(value, 3, 32) or type(value) ~= "table" then
        return nil, "invalid config shape"
    end
    local payload = value :: { [string]: unknown }
    local minimum, maximum, duration = payload.minPlayers, payload.maxPlayers, payload.roundDurationSeconds
    if type(minimum) ~= "number" or not Validation.inRange(minimum, 6, 10) or minimum % 1 ~= 0 then
        return nil, "minPlayers must be an integer from 6 to 10"
    end
    if type(maximum) ~= "number" or not Validation.inRange(maximum, minimum, 10) or maximum % 1 ~= 0 then
        return nil, "maxPlayers must be an integer from minPlayers to 10"
    end
    if type(duration) ~= "number" or not Validation.inRange(duration, 1, 3600) then
        return nil, "roundDurationSeconds must be finite from 1 to 3600"
    end
    return { minPlayers = minimum, maxPlayers = maximum, roundDurationSeconds = duration }, nil
end
return Config
