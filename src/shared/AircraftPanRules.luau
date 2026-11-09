--!strict
--[=[
    AircraftPanRules: deterministic local camera-focus integration. Depends only on
    MapRules/Validation; no Instances, transport, clock or yielding. Focus is a
    world-space X/Z point in studs. Pointer coordinates are viewport fractions.
    Invalid/nonfinite inputs return nil without mutation; blocked input holds focus.
]=]
local MapRules = if script then require(script.Parent.MapRules) else require("./MapRules")
local Validation = if script then require(script.Parent.Validation) else require("./Validation")
local AircraftPanRules = {}
export type Focus = { x: number, z: number }
AircraftPanRules.defaults =
    table.freeze({ edgeFraction = 0.12, speedStudsPerSecond = 120, maximumDeltaSeconds = 0.1 })

-- Returns a fresh center focus, used at role/new-round entry and explicit recenter.
function AircraftPanRules.recenter(map: typeof(MapRules.defaults)): Focus
    return { x = map.centerX, z = map.centerZ }
end

-- Radially clamps to the exact authored disk. Scaled normalization avoids squaring
-- large coordinates. A final roundoff correction never intentionally shrinks bounds.
function AircraftPanRules.clamp(map: typeof(MapRules.defaults), x: number, z: number): Focus?
    if not MapRules.validate(map) or not Validation.isFinite(x) or not Validation.isFinite(z) then
        return nil
    end
    local dx, dz = x - map.centerX, z - map.centerZ
    if not Validation.isFinite(dx) or not Validation.isFinite(dz) then
        return nil
    end
    local scale = math.max(math.abs(dx), math.abs(dz))
    if scale == 0 then
        return AircraftPanRules.recenter(map)
    end
    local nx, nz = dx / scale, dz / scale
    local length = math.sqrt(nx * nx + nz * nz)
    if scale / map.radiusStuds * length <= 1 then
        return { x = x, z = z }
    end
    local rx, rz = nx / length * map.radiusStuds, nz / length * map.radiusStuds
    if rx * rx + rz * rz > map.radiusStuds * map.radiusStuds then
        rx *= 1 - 1e-14
        rz *= 1 - 1e-14
    end
    return { x = map.centerX + rx, z = map.centerZ + rz }
end

-- Integrates raw pointer edges before the display reticle clamp. Speed ramps from
-- zero at the edge-zone boundary to the declared speed at the viewport edge.
-- Camera-relative horizontal axes use the canonical aircraft radial direction,
-- remaining stable even when focus lies directly underneath the aircraft.
function AircraftPanRules.step(
    map: typeof(MapRules.defaults),
    focus: Focus,
    aircraftX: number,
    aircraftZ: number,
    pointerX: number,
    pointerY: number,
    deltaSeconds: number,
    blocked: boolean
): Focus?
    for _, value in { focus.x, focus.z, aircraftX, aircraftZ, pointerX, pointerY, deltaSeconds } do
        if not Validation.isFinite(value) then
            return nil
        end
    end
    if deltaSeconds < 0 or pointerX < 0 or pointerX > 1 or pointerY < 0 or pointerY > 1 then
        return nil
    end
    local current = AircraftPanRules.clamp(map, focus.x, focus.z)
    if not current then
        return nil
    end
    if blocked or deltaSeconds == 0 then
        return current
    end
    local dx, dz = aircraftX - map.centerX, aircraftZ - map.centerZ
    local radius = math.sqrt(dx * dx + dz * dz)
    if not Validation.isFinite(radius) or radius < 1e-6 then
        return nil
    end
    local function axis(fraction: number): number
        local edge = AircraftPanRules.defaults.edgeFraction
        if fraction < edge then
            return (fraction - edge) / edge
        elseif fraction > 1 - edge then
            return (fraction - (1 - edge)) / edge
        end
        return 0
    end
    local right, up = axis(pointerX), -axis(pointerY)
    local magnitude = math.max(1, math.sqrt(right * right + up * up))
    right /= magnitude
    up /= magnitude
    local distance = math.min(deltaSeconds, AircraftPanRules.defaults.maximumDeltaSeconds)
        * AircraftPanRules.defaults.speedStudsPerSecond
    return AircraftPanRules.clamp(
        map,
        current.x + (right * dz / radius - up * dx / radius) * distance,
        current.z + (-right * dx / radius - up * dz / radius) * distance
    )
end
return AircraftPanRules
