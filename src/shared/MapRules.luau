--!strict
--[=[
    MapRules: public, pure circle/orbit geometry contract for P02. Depends on Validation.
    Coordinates and distances are studs, phases are radians. No engine calls or yielding.
    Authoritative movement decisions belong to the server MapService.
]=]
local Validation = if script then require(script.Parent.Validation) else require("./Validation")
local MapRules = {}

-- Flat authored contract. Altitude is height above ground; focus is ground-level at center.
export type Settings = {
    centerX: number,
    centerZ: number,
    groundY: number,
    radiusStuds: number,
    orbitCenterX: number,
    orbitCenterZ: number,
    orbitRadiusStuds: number,
    focusX: number,
    focusY: number,
    focusZ: number,
    altitudeStuds: number,
    killY: number,
}
MapRules.defaults = table.freeze({
    centerX = 0,
    centerZ = 0,
    groundY = 0,
    radiusStuds = 180,
    orbitCenterX = 0,
    orbitCenterZ = 0,
    orbitRadiusStuds = 180,
    focusX = 0,
    focusY = 0,
    focusZ = 0,
    altitudeStuds = 140,
    killY = -30,
})

-- Decodes untrusted config, returning a fresh record or reason; never mutates input.
function MapRules.validate(value: unknown): (Settings?, string?)
    if type(value) ~= "table" or not Validation.flatPayload(value, 12, 32) then
        return nil, "invalid map settings shape"
    end
    local fields = value :: { [string]: unknown }
    for _, key in
        {
            "centerX",
            "centerZ",
            "groundY",
            "radiusStuds",
            "orbitCenterX",
            "orbitCenterZ",
            "orbitRadiusStuds",
            "focusX",
            "focusY",
            "focusZ",
            "altitudeStuds",
            "killY",
        }
    do
        local number = fields[key]
        if type(number) ~= "number" or not Validation.isFinite(number) then
            return nil, "map settings require finite " .. key
        end
    end
    local settings = (fields :: unknown) :: Settings
    if settings.radiusStuds <= 8 or settings.altitudeStuds <= 16 or settings.killY >= settings.groundY then
        return nil, "radius must exceed 8, altitude exceed 16, and kill plane be below ground"
    end
    if
        settings.orbitCenterX ~= settings.centerX
        or settings.orbitCenterZ ~= settings.centerZ
        or settings.orbitRadiusStuds ~= settings.radiusStuds
    then
        return nil, "orbit must match map center and radius"
    end
    if
        settings.focusX ~= settings.centerX
        or settings.focusZ ~= settings.centerZ
        or settings.focusY ~= settings.groundY
    then
        return nil, "focus must equal ground-level map center"
    end
    return table.clone(settings), nil
end

-- Includes the exact disk edge. Invalid coordinates fail closed; Y is checked separately.
function MapRules.inside(settings: Settings, x: number, z: number): boolean
    return Validation.isFinite(x)
        and Validation.isFinite(z)
        and (x - settings.centerX) ^ 2 + (z - settings.centerZ) ^ 2 <= settings.radiusStuds ^ 2
end

-- Samples canonical future orbit; no aircraft is spawned by P02. Caller supplies finite phase.
function MapRules.orbit(settings: Settings, angleRadians: number): (number, number, number)
    return settings.centerX + math.cos(angleRadians) * settings.radiusStuds,
        settings.groundY + settings.altitudeStuds,
        settings.centerZ + math.sin(angleRadians) * settings.radiusStuds
end
return MapRules
