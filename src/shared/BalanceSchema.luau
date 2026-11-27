--!strict
--[=[
    Public balance field descriptions and shipped snapshot. Used by the admin UI
    and the server decoder. No engine services, storage, authority or yielding.
]=]
local BalanceSchema = {}

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
    m102Cadence = 1,
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
    return { key = key, label = label, kind = "number", unit = unit, minimum = minimum, maximum = maximum, integer = integer }
end
local fields: { Field } = {
    numeric("aircraftHealthPerGround", "Aircraft health per Ground player", "HP", 1, 10000, true),
    numeric("gauDamage", "30mm damage", "HP", 1, 1000, true),
    numeric("m102Damage", "105mm damage", "HP", 1, 1000, true),
    numeric("gauCadence", "30mm shot interval", "s", 0.15, 5, false),
    numeric("gauReload", "30mm reload", "s", 0.15, 120, false),
    numeric("m102Cadence", "105mm shot interval", "s", 0.15, 60, false),
    numeric("m102Reload", "105mm reload", "s", 0.15, 120, false),
    numeric("groundHealth", "Ground health", "HP", 1, 1000, true),
    numeric("m7Damage", "M-7 damage", "HP", 1, 1000, true),
    numeric("rocketDamage", "Rocket damage", "HP", 1, 10000, true),
    numeric("m7Cadence", "M-7 shot interval", "s", 0.15, 5, false),
    numeric("m7Reload", "M-7 reload", "s", 0.15, 120, false),
    numeric("launcherReload", "Launcher reload", "s", 0.15, 120, false),
    numeric("medkitHeal", "Medkit healing", "HP", 1, 1000, true),
    { key = "medkitSingleUse", label = "Single-use kits", unit = "", kind = "boolean" },
    numeric("medkitRespawn", "Reusable kit respawn", "s", 1, 600, true),
    { key = "panelDamage", label = "Panel damage", unit = "", kind = "choice", options = {
        "Low",
        "Medium",
        "High",
    } },
    numeric("roundDuration", "Combat duration", "s", 1, 3600, true),
    numeric("intermission", "Lobby intermission", "s", 0, 3600, true),
    numeric("minimumPlayers", "Minimum players", "players", 2, 10, true),
}
BalanceSchema.fields = table.freeze(fields)

-- Accepts exactly the published schema, including all fields. Copies the input
-- into a frozen snapshot so a running round never shares mutable UI/storage state.
function BalanceSchema.validate(raw: unknown): (Values?, string?)
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
            if
                type(value) ~= "number"
                or value ~= value
                or value < (field.minimum :: number)
                or value > (field.maximum :: number)
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
        result[field.key] = value
    end
    return (table.freeze(result) :: unknown) :: Values, nil
end

return BalanceSchema
