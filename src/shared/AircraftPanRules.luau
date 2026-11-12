--!strict
--[=[
    AircraftPanRules: deterministic orbit-local camera pan and reticle rasterization.
    Depends on MapRules/Validation; no Instances, transport, clock or yielding.
    Focus is a ground point in the aircraft's rotating local map frame, in studs:
    +X is radial toward the aircraft, +Z is camera-right at orbit phase zero.
    Releasing input holds this relative view through the aircraft's full orbit.
    All four viewport corner rays must land inside the playable disk; invalid
    inputs return nil and no function mutates its arguments.
]=]
local MapRules = if script then require(script.Parent.MapRules) else require("./MapRules")
local Validation = if script then require(script.Parent.Validation) else require("./Validation")
local AircraftPanRules = {}
export type Focus = { x: number, z: number }
export type Pixels = { x: number, y: number }
AircraftPanRules.defaults = table.freeze({
    speedStudsPerSecond = 120,
    maximumDeltaSeconds = 0.1,
    edgeInsetStuds = 2,
    homePitchRadians = math.rad(45),
})

-- One integer viewport pixel pair drives both the GUI reticle and camera ray.
function AircraftPanRules.raster(pointerX: number, pointerY: number, width: number, height: number): Pixels?
    for _, value in { pointerX, pointerY, width, height } do
        if not Validation.isFinite(value) then
            return nil
        end
    end
    if width < 2 or height < 2 then
        return nil
    end
    local function coordinate(pointer: number, size: number): number
        local minimum = math.ceil(size * 0.15)
        local maximum = math.floor(size * 0.85)
        return math.clamp(math.floor(math.clamp(pointer, minimum, maximum) + 0.5), minimum, maximum)
    end
    return { x = coordinate(pointerX, width), y = coordinate(pointerY, height) }
end

-- The downward corner rays form a convex ground footprint. Because the disk is
-- convex, four contained corners also contain the entire projected viewport.
-- A small inset prevents perimeter-ring grazing under replication roundoff.
local function fits(map: typeof(MapRules.defaults), focus: Focus, aspect: number, fovDegrees: number): boolean
    local radius, altitude = map.radiusStuds, map.altitudeStuds
    local dx, dz = focus.x - radius, focus.z
    local length = math.sqrt(dx * dx + dz * dz + altitude * altitude)
    if not Validation.isFinite(length) or length <= 0 or dx >= 0 then
        return false
    end
    local fx, fy, fz = dx / length, -altitude / length, dz / length
    -- Project the canonical orbit-right tangent into the look plane.
    local rightLength = math.sqrt(1 - fz * fz)
    if rightLength < 1e-6 then
        return false
    end
    local rx, ry, rz = -fx * fz / rightLength, -fy * fz / rightLength, rightLength
    local ux, uy, uz = fy * rz - fz * ry, fz * rx - fx * rz, fx * ry - fy * rx
    local vertical = math.tan(math.rad(fovDegrees) * 0.5)
    local horizontal = aspect * vertical
    local limit = radius - AircraftPanRules.defaults.edgeInsetStuds
    if limit <= 0 then
        return false
    end
    for _, side in { -1, 1 } do
        for _, top in { -1, 1 } do
            local rayX = fx + side * horizontal * rx + top * vertical * ux
            local rayY = fy + side * horizontal * ry + top * vertical * uy
            local rayZ = fz + side * horizontal * rz + top * vertical * uz
            if rayY >= -1e-9 then
                return false
            end
            local distance = altitude / -rayY
            local hitX, hitZ = radius + rayX * distance, rayZ * distance
            if not Validation.isFinite(hitX) or not Validation.isFinite(hitZ) then
                return false
            end
            if hitX * hitX + hitZ * hitZ > limit * limit then
                return false
            end
        end
    end
    return true
end

-- FOV is vertical degrees; aspect is viewport width divided by height.
function AircraftPanRules.viewFits(
    map: typeof(MapRules.defaults),
    focus: Focus,
    aspect: number,
    fovDegrees: number
): boolean
    return MapRules.validate(map) ~= nil
        and Validation.isFinite(focus.x)
        and Validation.isFinite(focus.z)
        and Validation.isFinite(aspect)
        and aspect > 0
        and aspect <= 10
        and Validation.isFinite(fovDegrees)
        and fovDegrees > 0
        and fovDegrees < 120
        and fits(map, focus, aspect, fovDegrees)
end

-- Selects the safe default view nearest a 45-degree downward pitch.
-- Nil means no complete view fits the selected level, viewport and lens.
function AircraftPanRules.recenter(map: typeof(MapRules.defaults), aspect: number, fovDegrees: number): Focus?
    if
        not MapRules.validate(map)
        or not Validation.isFinite(aspect)
        or not Validation.isFinite(fovDegrees)
    then
        return nil
    end
    if aspect <= 0 or aspect > 10 or fovDegrees <= 0 or fovDegrees >= 120 then
        return nil
    end
    for offset = 0, 70 do
        for _, direction in { 1, -1 } do
            local pitch = AircraftPanRules.defaults.homePitchRadians + math.rad(offset * 0.5 * direction)
            if pitch > 0 and pitch < math.pi * 0.5 then
                local candidate = { x = map.radiusStuds - map.altitudeStuds / math.tan(pitch), z = 0 }
                if fits(map, candidate, aspect, fovDegrees) then
                    return candidate
                end
            end
        end
    end
    return nil
end

-- Adapts only unusually wide viewports; normal desktop and phone ratios retain
-- the configured lens. This presentation value never changes server selection.
function AircraftPanRules.supportedFov(
    map: typeof(MapRules.defaults),
    aspect: number,
    requestedDegrees: number
): number?
    if not Validation.isFinite(requestedDegrees) or requestedDegrees < 15 or requestedDegrees >= 120 then
        return nil
    end
    local candidate = requestedDegrees
    while candidate >= 15 do
        if AircraftPanRules.recenter(map, aspect, candidate) then
            return candidate
        end
        candidate -= 0.5
    end
    return nil
end

-- Clips toward a requested local point from an already-safe origin. Separate
-- axis clips let diagonal input slide along the curved valid-view boundary.
local function clip(
    map: typeof(MapRules.defaults),
    from: Focus,
    desired: Focus,
    aspect: number,
    fovDegrees: number
): Focus
    if fits(map, desired, aspect, fovDegrees) then
        return desired
    end
    local lower, upper = 0, 1
    for _ = 1, 18 do
        local middle = (lower + upper) * 0.5
        local candidate = {
            x = from.x + (desired.x - from.x) * middle,
            z = from.z + (desired.z - from.z) * middle,
        }
        if fits(map, candidate, aspect, fovDegrees) then
            lower = middle
        else
            upper = middle
        end
    end
    return { x = from.x + (desired.x - from.x) * lower, z = from.z + (desired.z - from.z) * lower }
end

-- Integrates WASD/touch in the rotating camera plane. Right increases local Z;
-- up looks farther across the level (decreases local X). The widest enabled
-- lens bounds both profiles so switching zoom preserves the relative pan state.
function AircraftPanRules.step(
    map: typeof(MapRules.defaults),
    focus: Focus,
    right: number,
    up: number,
    deltaSeconds: number,
    blocked: boolean,
    aspect: number,
    fovDegrees: number
): Focus?
    if not AircraftPanRules.viewFits(map, focus, aspect, fovDegrees) then
        return nil
    end
    for _, value in { right, up, deltaSeconds } do
        if not Validation.isFinite(value) then
            return nil
        end
    end
    if math.abs(right) > 1 or math.abs(up) > 1 or deltaSeconds < 0 then
        return nil
    end
    if blocked or deltaSeconds == 0 or (right == 0 and up == 0) then
        return { x = focus.x, z = focus.z }
    end
    local normalized = math.max(1, math.sqrt(right * right + up * up))
    local distance = math.min(deltaSeconds, AircraftPanRules.defaults.maximumDeltaSeconds)
        * AircraftPanRules.defaults.speedStudsPerSecond
    local nextZ =
        clip(map, focus, { x = focus.x, z = focus.z + right / normalized * distance }, aspect, fovDegrees)
    return clip(map, nextZ, { x = nextZ.x - up / normalized * distance, z = nextZ.z }, aspect, fovDegrees)
end

-- Rotates a held local focus with the canonical aircraft orbit. This never
-- writes the aircraft pose. Returns a world-space ground point in studs.
function AircraftPanRules.worldFocus(
    map: typeof(MapRules.defaults),
    focus: Focus,
    aircraftX: number,
    aircraftZ: number
): Focus?
    if not MapRules.validate(map) then
        return nil
    end
    for _, value in { focus.x, focus.z, aircraftX, aircraftZ } do
        if not Validation.isFinite(value) then
            return nil
        end
    end
    local radialX, radialZ = aircraftX - map.centerX, aircraftZ - map.centerZ
    local length = math.sqrt(radialX * radialX + radialZ * radialZ)
    if not Validation.isFinite(length) or length < 1e-6 then
        return nil
    end
    radialX /= length
    radialZ /= length
    return {
        x = map.centerX + radialX * focus.x - radialZ * focus.z,
        z = map.centerZ + radialZ * focus.x + radialX * focus.z,
    }
end
return AircraftPanRules
