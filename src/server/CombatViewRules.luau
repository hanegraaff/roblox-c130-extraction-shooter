--!strict
--[=[
    CombatViewRules: server-only validation of a claimed, permitted aircraft view.
    Depends on injected level geometry and canonical aircraft pose, public camera
    rules, and finite scalar input. No Instances, clocks, world queries or yielding.
    The client may claim any legal view; this proves reachable intent, not actual input.
]=]
local loadPath = (require :: unknown) :: (string) -> unknown
local MapRules = (
    if script
        then require(game:GetService("ReplicatedStorage").Shared.MapRules)
        else loadPath("../shared/MapRules")
) :: typeof(require(game:GetService("ReplicatedStorage").Shared.MapRules))
local Pan = (
    if script
        then require(game:GetService("ReplicatedStorage").Shared.AircraftPanRules)
        else loadPath("../shared/AircraftPanRules")
) :: typeof(require(game:GetService("ReplicatedStorage").Shared.AircraftPanRules))
local Aircraft = (
    if script
        then require(game:GetService("ReplicatedStorage").Shared.AircraftRules)
        else loadPath("../shared/AircraftRules")
) :: typeof(require(game:GetService("ReplicatedStorage").Shared.AircraftRules))
local Validation = (
    if script
        then require(game:GetService("ReplicatedStorage").Shared.Validation)
        else loadPath("../shared/Validation")
) :: typeof(require(game:GetService("ReplicatedStorage").Shared.Validation))
local CombatViewRules = {}

-- Allow 1.25 seconds of orbit replication age plus one stud of position rounding.
-- Normalized projection adds 0.02 (1% of viewport per edge) for raster/float rounding.
CombatViewRules.maximumPoseAgeSeconds = 1.25
CombatViewRules.orbitToleranceStuds = 1
CombatViewRules.projectionMargin = 0.02

-- Authorizes exactly eleven flat scalar fields. cameraX/Z describe the replicated
-- canonical aircraft position used by the client, never the muzzle. Its radius and
-- distance from the current server pose must be within the stated bounded lag.
-- Focus is orbit-local, aspect is width/height; target and all positions use studs.
-- Returns a fresh six-field fire command or nil without consuming gameplay state.
function CombatViewRules.validate(
    value: unknown,
    map: typeof(MapRules.defaults),
    selected: string,
    serverX: number,
    serverZ: number
): (unknown, string?)
    if not Validation.flatPayload(value, 11, 32) or type(value) ~= "table" then
        return nil, "invalid view shape"
    end
    local fields = value :: { [string]: unknown }
    local count = 0
    for key in fields do
        if
            key ~= "roundId"
            and key ~= "sequence"
            and key ~= "weapon"
            and key ~= "x"
            and key ~= "y"
            and key ~= "z"
            and key ~= "focusX"
            and key ~= "focusZ"
            and key ~= "aspect"
            and key ~= "cameraX"
            and key ~= "cameraZ"
        then
            return nil, "unknown view field"
        end
        count += 1
    end
    if count ~= 11 or fields.weapon ~= selected then
        return nil, "invalid selection or view fields"
    end
    local x, y, z = fields.x, fields.y, fields.z
    local focusX, focusZ, aspect = fields.focusX, fields.focusZ, fields.aspect
    local cameraX, cameraZ = fields.cameraX, fields.cameraZ
    if
        type(x) ~= "number"
        or type(y) ~= "number"
        or type(z) ~= "number"
        or type(focusX) ~= "number"
        or type(focusZ) ~= "number"
        or type(aspect) ~= "number"
        or type(cameraX) ~= "number"
        or type(cameraZ) ~= "number"
        or not MapRules.validate(map)
        or not Validation.isFinite(serverX)
        or not Validation.isFinite(serverZ)
    then
        return nil, "invalid view values"
    end
    local radialX, radialZ = cameraX - map.centerX, cameraZ - map.centerZ
    local radius = math.sqrt(radialX * radialX + radialZ * radialZ)
    local lagX, lagZ = cameraX - serverX, cameraZ - serverZ
    local lag = math.sqrt(lagX * lagX + lagZ * lagZ)
    local maximumLag = map.orbitRadiusStuds
            * 2
            * math.pi
            / Aircraft.defaults.periodSeconds
            * CombatViewRules.maximumPoseAgeSeconds
        + CombatViewRules.orbitToleranceStuds
    if
        not Validation.isFinite(radius)
        or math.abs(radius - map.orbitRadiusStuds) > CombatViewRules.orbitToleranceStuds
        or not Validation.isFinite(lag)
        or lag > maximumLag
    then
        return nil, "aircraft pose outside bounded replication age"
    end
    local widest = Pan.supportedFov(map, aspect, Aircraft.defaults.fov105mm)
    local selectedFov = Aircraft.fov(Aircraft.defaults, selected)
    local focus = { x = focusX, z = focusZ }
    if not widest or not selectedFov or not Pan.viewFits(map, focus, aspect, widest) then
        return nil, "invalid panned camera"
    end
    local worldFocus = Pan.worldFocus(map, focus, cameraX, cameraZ)
    if not worldFocus then
        return nil, "invalid focus"
    end
    radialX /= radius
    radialZ /= radius
    local cameraY = map.groundY + map.altitudeStuds
    local dx, dy, dz = worldFocus.x - cameraX, map.groundY - cameraY, worldFocus.z - cameraZ
    local length = math.sqrt(dx * dx + dy * dy + dz * dz)
    if not Validation.isFinite(length) or length <= 0 then
        return nil, "invalid camera basis"
    end
    local fx, fy, fz = dx / length, dy / length, dz / length
    local projection = radialZ * fx - radialX * fz
    local rightX, rightY, rightZ = radialZ - fx * projection, -fy * projection, -radialX - fz * projection
    local rightLength = math.sqrt(rightX * rightX + rightY * rightY + rightZ * rightZ)
    if not Validation.isFinite(rightLength) or rightLength < 1e-6 then
        return nil, "invalid camera basis"
    end
    rightX, rightY, rightZ = rightX / rightLength, rightY / rightLength, rightZ / rightLength
    local upX, upY, upZ = rightY * fz - rightZ * fy, rightZ * fx - rightX * fz, rightX * fy - rightY * fx
    local tx, ty, tz = x - cameraX, y - cameraY, z - cameraZ
    local depth = tx * fx + ty * fy + tz * fz
    if not Validation.isFinite(depth) or depth <= 0 then
        return nil, "aim behind camera"
    end
    local tangent = math.tan(math.rad(math.min(selectedFov, widest)) / 2)
    local horizontal = (tx * rightX + ty * rightY + tz * rightZ) / (depth * tangent * aspect)
    local vertical = (tx * upX + ty * upY + tz * upZ) / (depth * tangent)
    local limit = 0.7 + CombatViewRules.projectionMargin
    if
        not Validation.isFinite(horizontal)
        or not Validation.isFinite(vertical)
        or math.abs(horizontal) > limit
        or math.abs(vertical) > limit
    then
        return nil, "aim outside permitted reticle"
    end
    return {
        roundId = fields.roundId,
        sequence = fields.sequence,
        weapon = fields.weapon,
        x = x,
        y = y,
        z = z,
    },
        nil
end
return CombatViewRules
