--!strict
--[=[
    AircraftPanRules: deterministic square-bound camera pan, reticle raster and
    bounded control placement.
    Depends on MapRules/Validation, with no Instances, clocks, transport or yield.
    Focus is a world-aligned offset from level center in studs. Aircraft pose
    defines screen movement direction but never rotates a held focus. Only the
    square edges block pan; invalid input rejects without mutating arguments.
]=]
local MapRules = if script then require(script.Parent.MapRules) else require("./MapRules")
local Validation = if script then require(script.Parent.Validation) else require("./Validation")
local AircraftPanRules = {}
export type Focus = { x: number, z: number }
export type Pixels = { x: number, y: number }
-- Pixel rectangle in one shared GUI-content coordinate space. Width/height are
-- positive extents, not right/bottom coordinates; origins may be negative.
export type PixelRect = { x: number, y: number, width: number, height: number }
AircraftPanRules.defaults = table.freeze({
    speedStudsPerSecond = 120,
    maximumDeltaSeconds = 0.1,
    backdropDepthStuds = 4,
})

local function backdropExtent(map: typeof(MapRules.defaults)): number?
    local extent = math.max(10240, map.radiusStuds * 4, map.altitudeStuds * 72)
    return if Validation.isFinite(extent) then extent else nil
end

-- Size of the noninteractive operator-only ground backdrop, in studs. The
-- inscribed disk covers the view at any aircraft phase; invalid maps reject.
function AircraftPanRules.backdropHalfExtent(map: typeof(MapRules.defaults)): number?
    return if MapRules.validate(map) then backdropExtent(map) else nil
end

-- Returns a GUI-local top-left pixel position for a control in the top-right
-- of the viewport/canvas intersection. Native GUI input excludes negative content
-- coordinates even when a device-safe canvas starts above the viewport. Callers
-- supply that actual input/render rectangle, and the measured canvas rectangle,
-- in the same coordinate space. A shrinking intersection reduces padding first;
-- if the whole control cannot fit, nil tells presentation to hide it. Rectangle
-- arguments are never mutated. Dimensions/padding are finite nonnegative pixels.
function AircraftPanRules.controlTopRight(
    viewport: PixelRect,
    canvas: PixelRect,
    width: number,
    height: number,
    padding: number
): Pixels?
    for _, value in
        {
            viewport.x,
            viewport.y,
            viewport.width,
            viewport.height,
            canvas.x,
            canvas.y,
            canvas.width,
            canvas.height,
            width,
            height,
            padding,
        }
    do
        if not Validation.isFinite(value) then
            return nil
        end
    end
    if
        viewport.width <= 0
        or viewport.height <= 0
        or canvas.width <= 0
        or canvas.height <= 0
        or width <= 0
        or height <= 0
        or padding < 0
    then
        return nil
    end
    local right, bottom =
        math.min(viewport.x + viewport.width, canvas.x + canvas.width),
        math.min(viewport.y + viewport.height, canvas.y + canvas.height)
    if not Validation.isFinite(right) or not Validation.isFinite(bottom) then
        return nil
    end
    -- Reserve complete integer pixels inside both measured rectangles; this also
    -- prevents final rasterization from crossing a fractional safe-area edge.
    local leftLocal = math.ceil(math.max(viewport.x, canvas.x) - canvas.x)
    local topLocal = math.ceil(math.max(viewport.y, canvas.y) - canvas.y)
    local rightLocal = math.floor(right - canvas.x)
    local bottomLocal = math.floor(bottom - canvas.y)
    local boxWidth, boxHeight = math.ceil(width), math.ceil(height)
    if rightLocal - leftLocal < boxWidth or bottomLocal - topLocal < boxHeight then
        return nil
    end
    local horizontal = math.min(math.floor(padding), math.floor((rightLocal - leftLocal - boxWidth) / 2))
    local vertical = math.min(math.floor(padding), math.floor((bottomLocal - topLocal - boxHeight) / 2))
    return { x = rightLocal - horizontal - boxWidth, y = topLocal + vertical }
end

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

-- Focus uses world-aligned offsets from the map center. P18 deliberately has
-- no frustum, disk or pitch restriction: only the square edges limit movement.
local function fits(
    map: typeof(MapRules.defaults),
    focus: Focus,
    _aspect: number,
    _fovDegrees: number
): boolean
    return math.abs(focus.x) <= map.radiusStuds and math.abs(focus.z) <= map.radiusStuds
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

-- Recenter returns an independent map-center focus. Invalid level/lens/viewport
-- input rejects; no viewing-angle restriction reduces square access.
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
    return { x = 0, z = 0 }
end

-- Keeps the configured vertical lens at every supported aspect. Lens selection
-- changes zoom alone and cannot reduce the square pan envelope.
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

-- Integrates signed screen axes in the ground plane, then clamps X and Z
-- independently to world square edges. Optional canonical aircraft coordinates
-- default to phase zero for pure callers. Projected camera-right defines a stable
-- screen basis even when focus is directly under the aircraft. Each ground
-- direction is the horizontal projection of that displayed axis. Componentwise
-- square clipping cannot reverse its signed screen projection: every surviving
-- component retains its sign. Combined input follows the weighted screen-axis
-- gradient, normalized to bound speed. No hidden offset accumulates at an edge.
function AircraftPanRules.step(
    map: typeof(MapRules.defaults),
    focus: Focus,
    right: number,
    up: number,
    deltaSeconds: number,
    blocked: boolean,
    aspect: number,
    fovDegrees: number,
    aircraftX: number?,
    aircraftZ: number?
): Focus?
    if not AircraftPanRules.viewFits(map, focus, aspect, fovDegrees) then
        return nil
    end
    local cameraX = aircraftX or (map.centerX + map.radiusStuds)
    local cameraZ = aircraftZ or map.centerZ
    for _, value in { right, up, deltaSeconds, cameraX, cameraZ } do
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
    local radialX, radialZ = cameraX - map.centerX, cameraZ - map.centerZ
    local radius = math.sqrt(radialX ^ 2 + radialZ ^ 2)
    if not Validation.isFinite(radius) or radius < 1e-6 then
        return nil
    end
    radialX, radialZ = radialX / radius, radialZ / radius
    local dx, dz = map.centerX + focus.x - cameraX, map.centerZ + focus.z - cameraZ
    local length = math.sqrt(dx ^ 2 + dz ^ 2 + map.altitudeStuds ^ 2)
    if not Validation.isFinite(length) or length <= 0 then
        return nil
    end
    local fx, fy, fz = dx / length, -map.altitudeStuds / length, dz / length
    local projection = radialZ * fx - radialX * fz
    local rx, ry, rz = radialZ - fx * projection, -fy * projection, -radialX - fz * projection
    local rlength = math.sqrt(rx ^ 2 + ry ^ 2 + rz ^ 2)
    if rlength < 1e-6 then
        return nil
    end
    rx, ry, rz = rx / rlength, ry / rlength, rz / rlength
    local ux, uz = ry * fz - rz * fy, rx * fy - ry * fx
    local rground = math.sqrt(ux ^ 2 + uz ^ 2)
    local uground = math.sqrt(rx ^ 2 + rz ^ 2)
    if rground < 1e-9 or uground < 1e-9 then
        return nil
    end
    local moveX = right * rx / uground + up * ux / rground
    local moveZ = right * rz / uground + up * uz / rground
    local normalization = math.max(1, math.sqrt(moveX ^ 2 + moveZ ^ 2))
    local distance = math.min(deltaSeconds, AircraftPanRules.defaults.maximumDeltaSeconds)
        * AircraftPanRules.defaults.speedStudsPerSecond
        / normalization
    return {
        x = math.clamp(focus.x + moveX * distance, -map.radiusStuds, map.radiusStuds),
        z = math.clamp(focus.z + moveZ * distance, -map.radiusStuds, map.radiusStuds),
    }
end

-- Converts a world-aligned map-local focus to world studs. Held focus stays
-- fixed while the canonical plane orbits; source pose is validated, never changed.
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
    if not fits(map, focus, 1, 40) then
        return nil
    end
    return { x = map.centerX + focus.x, z = map.centerZ + focus.z }
end
return AircraftPanRules
