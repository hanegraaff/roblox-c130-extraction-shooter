--!strict
--[=[
    Validation: shared, engine-independent guards for future network boundaries.
    No services, yields, clocks or mutation. Flat payloads deliberately reject nested data.
    These structural guards do not establish role, ownership, replay or world authority.
]=]
local Validation = {}

-- Reports whether an unknown value is a finite number, including zero.
function Validation.isFinite(value: unknown): boolean
    return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

-- Inclusive finite numeric bounds; malformed bounds reject rather than throwing.
function Validation.inRange(value: unknown, minimum: number, maximum: number): boolean
    return Validation.isFinite(minimum)
        and Validation.isFinite(maximum)
        and minimum <= maximum
        and type(value) == "number"
        and Validation.isFinite(value)
        and value >= minimum
        and value <= maximum
end

-- Accepts only plain flat string-keyed tables with bounded scalar contents.
-- Counts bytes, not Unicode characters. Metatables and nested/cyclic tables reject.
function Validation.flatPayload(value: unknown, maxFields: number, maxStringBytes: number): boolean
    if
        not Validation.inRange(maxFields, 0, 1024)
        or maxFields % 1 ~= 0
        or not Validation.inRange(maxStringBytes, 0, 65536)
        or maxStringBytes % 1 ~= 0
    then
        return false
    end
    if type(value) ~= "table" then
        return false
    end
    local payload = value :: { [unknown]: unknown }
    -- Luau infers getmetatable only for statically known metatable types; this boundary accepts unknown tables.
    local readMetatable = (getmetatable :: unknown) :: (unknown) -> unknown
    if readMetatable(payload) ~= nil then
        return false
    end
    local count = 0
    for key, item in pairs(payload) do
        count += 1
        if count > maxFields or type(key) ~= "string" or #key > maxStringBytes then
            return false
        end
        if type(item) == "number" then
            if not Validation.isFinite(item) then
                return false
            end
        elseif type(item) == "string" then
            if #item > maxStringBytes then
                return false
            end
        elseif type(item) ~= "boolean" then
            return false
        end
    end
    return true
end
return Validation
