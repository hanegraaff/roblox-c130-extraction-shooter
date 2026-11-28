--!strict
--[=[
    Public balance field descriptions and shipped snapshot. Used by the admin UI
    and the server decoder. No engine services, storage, authority or yielding.
]=]
local BalanceSchema = {}
-- Keep the stored key stable for existing servers and records. UI uses its label.
BalanceSchema.builtinPresetKey = "Shipped"
BalanceSchema.builtinPresetName = "Default"

-- Human-readable name for a stored preset identifier. No storage mutation.
function BalanceSchema.presetLabel(name: string): string
    return if name == BalanceSchema.builtinPresetKey then BalanceSchema.builtinPresetName else name
end

-- Shared naming contract. The server still validates every remote request.
function BalanceSchema.validPresetName(value: unknown): boolean
    return type(value) == "string" and #value >= 1 and #value <= 32 and value:match("^[%w][%w _%-]*$") ~= nil
end

-- Save allows a new name or edits to the loaded custom preset. Both names
-- for the built-in preset are reserved, even when its draft has changed.
function BalanceSchema.canSavePresetName(name: string, originalName: string, valuesChanged: boolean): boolean
    return BalanceSchema.validPresetName(name)
        and (name ~= originalName or valuesChanged)
        and name ~= BalanceSchema.builtinPresetName
        and name ~= BalanceSchema.builtinPresetKey
end

-- One full preset. Durations are seconds and damage/healing are game health units.
export type Values = {
    aircraftHealthPerGround: number,
    gauDamage: number,
    m102Damage: number,
    gauCadence: number,
    gauReload: number,
    m102Cadence: number,
    m102Reload: number,
    groundHealth: number,
    m7Damage: number,
    rocketDamage: number,
    m7Cadence: number,
    m7Reload: number,
    launcherReload: number,
    medkitHeal: number,
    medkitSingleUse: boolean,
    medkitRespawn: number,
    panelDamage: string,
    roundDuration: number,
    intermission: number,
    minimumPlayers: number,
}
-- Labels, units and inclusive ranges are shared by UI hints and runtime validation.
export type Field = {
    key: string,
    label: string,
    kind: string,
    unit: string,
    minimum: number?,
    maximum: number?,
    integer: boolean?,
    options: { string }?,
}
BalanceSchema.defaults = table.freeze({
    aircraftHealthPerGround = 1000,
    gauDamage = 25,
    m102Damage = 100,
    gauCadence = 0.15,
    gauReload = 5,
    m102Cadence = 12,
    m102Reload = 12,
    groundHealth = 100,
    m7Damage = 5,
    rocketDamage = 150,
    m7Cadence = 0.15,
    m7Reload = 2,
    launcherReload = 15,
    medkitHeal = 25,
    medkitSingleUse = true,
    medkitRespawn = 30,
    panelDamage = "Medium",
    roundDuration = 600,
    intermission = 120,
    minimumPlayers = 2,
}) :: Values
local function numeric(
    key: string,
    label: string,
    unit: string,
    minimum: number,
    maximum: number,
    integer: boolean
): Field
    return {
        key = key,
        label = label,
        kind = "number",
        unit = unit,
        minimum = minimum,
        maximum = maximum,
        integer = integer,
    }
end
local fields: { Field } = {
    numeric("aircraftHealthPerGround", "Aircraft health per Ground player", "HP", 1, 10000, true),
    numeric("gauDamage", "30mm damage", "HP", 1, 1000, true),
    numeric("m102Damage", "105mm damage", "HP", 1, 1000, true),
    numeric("gauCadence", "30mm shot interval", "s", 0.15, 5, false),
    numeric("gauReload", "30mm reload", "s", 0, 30, false),
    numeric("m102Cadence", "105mm shot interval", "s", 0, 120, false),
    numeric("m102Reload", "105mm reload", "s", 0, 30, false),
    numeric("groundHealth", "Ground health", "HP", 1, 1000, true),
    numeric("m7Damage", "M-7 damage", "HP", 1, 50, true),
    numeric("rocketDamage", "Rocket damage", "HP", 1, 5000, true),
    numeric("m7Cadence", "M-7 shot interval", "s", 0.15, 1, false),
    numeric("m7Reload", "M-7 reload", "s", 0.15, 10, false),
    numeric("launcherReload", "Launcher reload", "s", 0.15, 120, false),
    numeric("medkitHeal", "Medkit healing", "HP", 1, 1000, true),
    { key = "medkitSingleUse", label = "Single-use kits", unit = "", kind = "boolean" },
    numeric("medkitRespawn", "Reusable kit respawn", "s", 1, 600, true),
    {
        key = "panelDamage",
        label = "Panel damage",
        unit = "",
        kind = "choice",
        options = {
            "Low",
            "Medium",
            "High",
        },
    },
    numeric("roundDuration", "Combat duration", "s", 1, 3600, true),
    numeric("intermission", "Lobby intermission", "s", 1, 300, true),
    numeric("minimumPlayers", "Minimum players", "players", 2, 10, true),
}
BalanceSchema.fields = table.freeze(fields)

-- Earlier valid stored values are clamped to current limits during decoding.
-- New requests remain strict, including finite numbers and complete snapshots.
local previousBounds: { [string]: { number } } = {
    m7Damage = { 1, 1000 },
    m7Cadence = { 0.15, 5 },
    m7Reload = { 0.15, 120 },
    rocketDamage = { 1, 10000 },
    intermission = { 0, 3600 },
    gauReload = { 0, 120 },
    m102Reload = { 0, 120 },
}
local function decode(raw: unknown, stored: boolean): (Values?, string?)
    if type(raw) ~= "table" then
        return nil, "Expected a full preset."
    end
    local input = raw :: { [unknown]: unknown }
    local count = 0
    for _ in input do
        count += 1
        if count > #fields then
            return nil, "Unknown preset field."
        end
    end
    local result: { [string]: unknown } = {}
    for _, field in fields do
        local value = input[field.key]
        if field.kind == "number" then
            local legacy = if stored then previousBounds[field.key] else nil
            local low = if legacy then legacy[1] else field.minimum :: number
            local high = if legacy then legacy[2] else field.maximum :: number
            if
                type(value) ~= "number"
                or value ~= value
                or value < low
                or value > high
                or (field.integer and value % 1 ~= 0)
            then
                return nil, "Invalid " .. field.label .. "."
            end
        elseif field.kind == "choice" then
            if type(value) ~= "string" or not table.find(field.options :: { string }, value) then
                return nil, "Invalid " .. field.label .. "."
            end
        elseif type(value) ~= "boolean" then
            return nil, "Invalid " .. field.label .. "."
        end
        result[field.key] = if field.kind == "number"
            then math.clamp(value :: number, field.minimum :: number, field.maximum :: number)
            else value
    end
    -- Keep v1 storage readable. Old presets may contain a second howitzer timer
    -- or reusable kits. The current rules normalize those legacy fields.
    result.m102Cadence = result.m102Reload
    result.medkitSingleUse = true
    result.medkitRespawn = BalanceSchema.defaults.medkitRespawn
    return (table.freeze(result) :: unknown) :: Values, nil
end

-- Validate an untrusted new preset against the current ranges. Never mutates input.
function BalanceSchema.validate(raw: unknown): (Values?, string?)
    return decode(raw, false)
end

-- Decode previously stored presets, accepting only earlier supported bounds and
-- returning a frozen snapshot clamped to current ranges. Malformed data rejects.
function BalanceSchema.decodeStored(raw: unknown): (Values?, string?)
    return decode(raw, true)
end

return BalanceSchema
