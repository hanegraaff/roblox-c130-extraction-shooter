--!strict
--[=[
    GroundCameraRules: engine-independent indoor framing, heading and reticle placement
    for local Ground presentation. Distances are studs, frame intervals are
    seconds, and reticle coordinates are viewport pixels. No camera, world, gameplay authority, side effects, or yielding.
]=]
local Validation = if script then require(script.Parent.Validation) else require("./Validation")
local GroundCameraRules = {}

local ENTRY_INSET_STUDS = 0.2
local EXIT_MARGIN_STUDS = 0.25
local CEILING_MARGIN_STUDS = 0.15
local TRANSITION_RATE = 10
local SNAP_WEIGHT = 0.005

-- Tests an avatar root in the authored room's local coordinates. An already
-- selected room retains a small outer margin so door edges do not toggle it.
function GroundCameraRules.contains(
    x: number,
    y: number,
    z: number,
    halfWidth: number,
    halfHeight: number,
    halfDepth: number,
    wasInside: boolean
): boolean
    local margin = if wasInside then EXIT_MARGIN_STUDS else -ENTRY_INSET_STUDS
    return math.abs(x) <= halfWidth + margin
        and math.abs(y) <= halfHeight + margin
        and math.abs(z) <= halfDepth + margin
end

-- Advances a blend weight between zero and one using nonnegative frame
-- seconds. Cap a large frame gap so a stalled render cannot skip a transition.
function GroundCameraRules.blend(weight: number, inside: boolean, deltaSeconds: number): number
    local target = if inside then 1 else 0
    local nextWeight = target
        + (weight - target) * math.exp(-TRANSITION_RATE * math.clamp(deltaSeconds, 0, 0.1))
    return if math.abs(nextWeight - target) <= SNAP_WEIGHT then target else nextWeight
end

-- Blends toward the maximum room distance. Never pushes out a camera Roblox
-- already brought closer for manual zoom, first person or a physical obstruction.
function GroundCameraRules.distance(stockDistance: number, roomDistance: number, weight: number): number
    return stockDistance - math.max(0, stockDistance - roomDistance) * weight
end

-- Returns the safe stock-ray distance below the room's ceiling. Heights share
-- the zone's local coordinate frame. If the stock focus is already above the
-- ceiling (e.g. an open stairwell transition), defer that frame to the stock ray.
function GroundCameraRules.ceilingDistance(
    stockDistance: number,
    focusHeight: number,
    cameraHeight: number,
    ceilingHeight: number
): number
    local clearance = ceilingHeight - CEILING_MARGIN_STUDS
    if focusHeight >= clearance or cameraHeight <= clearance then
        return stockDistance
    end
    return (clearance - focusHeight) / (cameraHeight - focusHeight) * stockDistance
end

-- Rounds the fixed above-center aim row to the same pixel used by both
-- the rendered crosshair and the camera ray. Avatar animation cannot move it.
function GroundCameraRules.reticleY(viewportHeight: number): number
    return math.floor(viewportHeight * 0.40 + 0.5)
end

-- Converts a projected view direction into a Roblox yaw in [-π, π].
-- A vertical or nonfinite view has no stable horizontal heading.
function GroundCameraRules.yaw(lookX: number, lookZ: number): number?
    if not Validation.isFinite(lookX) or not Validation.isFinite(lookZ) then
        return nil
    end
    if math.max(math.abs(lookX), math.abs(lookZ)) < 1e-6 then
        return nil
    end
    return math.atan2(-lookX, -lookZ)
end

return GroundCameraRules
