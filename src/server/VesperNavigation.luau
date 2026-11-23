--!strict
--[=[
    VesperNavigation: validates the Warehouse replacement's open-plan routes
    against loaded solid geometry. Uses the approved Blender stair and gallery
    stations in local studs and caller-owned filter parameters. Read-only and
    nonyielding. Samples headroom and support, while actual avatar and camera
    traversal remain Studio acceptance checks.
]=]
local VesperNavigation = {}

local stairRun = 1.875
local stairRise = 0.625
local stepCount = 16
local upperFloor = 10
local clearance = 5.5
local lateralOffsets = { -2.55, 0, 2.55 }
local gatePaths = {
    { Vector3.new(8, 0, 27), Vector3.new(8, 0, 15) },
    { Vector3.new(-8, 0, -27), Vector3.new(-8, 0, -15) },
    { Vector3.new(35, 0, 0), Vector3.new(25, 0, 0) },
    { Vector3.new(-35, 0, 0), Vector3.new(-25, 0, 0) },
}
local gallery = {
    Vector2.new(0, 19.7),
    Vector2.new(12, 19.7),
    Vector2.new(21.2, 19.7),
    Vector2.new(26.8, 16),
    Vector2.new(26.8, -13),
    Vector2.new(25, -17.2),
    Vector2.new(21, -19),
    Vector2.new(-21, -19),
    Vector2.new(-26.8, -15),
    Vector2.new(-26.8, 15),
    Vector2.new(-21, 19),
    Vector2.new(-12, 19),
}

local function supports(scene: WorldRoot, point: Vector3, rays: RaycastParams, tolerance: number): boolean
    local result = scene:Raycast(point + Vector3.new(0, 0.2, 0), Vector3.new(0, -0.5, 0), rays)
    return result ~= nil and math.abs(result.Position.Y - point.Y) <= tolerance
end

-- Requires the box footprint and top elevation of the mesh foundation. The
-- upper deck is annular, so its actual walking surface is tested with rays.
function VesperNavigation.validate(scene: WorldRoot, floor: BasePart, rays: RaycastParams): (boolean, string?)
    if
        math.abs(floor.Size.X - 64) > 0.001
        or math.abs(floor.Size.Z - 48) > 0.001
        or (floor.CFrame.UpVector - Vector3.yAxis).Magnitude > 0.001
    then
        return false, "invalid Vesper foundation"
    end
    local origin = floor.Position + Vector3.new(0, floor.Size.Y / 2, 0)
    local up = Vector3.yAxis
    for _, path in gatePaths do
        local direction = path[2] - path[1]
        local lateral = up:Cross(direction.Unit)
        for _, offset in lateralOffsets do
            local foot = origin + lateral * offset
            for _, height in { 0.42, 3.15, clearance } do
                if scene:Raycast(foot + path[1] + Vector3.new(0, height, 0), direction, rays) then
                    return false, "blocked Vesper portal approach"
                end
            end
            if not supports(scene, foot + path[2], rays, 0.02) then
                return false, "unsupported Vesper entrance"
            end
        end
    end
    for _, side in { -1, 1 } do
        local x = side * 18.5
        for step = 1, stepCount do
            local z = side * (-15 + (step - 0.5) * stairRun)
            for _, offset in lateralOffsets do
                local tread = origin + Vector3.new(x + offset, step * stairRise, z)
                if
                    not supports(scene, tread, rays, 0.02)
                    or scene:Raycast(tread + Vector3.new(0, 0.02, 0), Vector3.new(0, clearance, 0), rays)
                then
                    return false, "blocked or unsupported Vesper stair tread"
                end
            end
        end
        if not supports(scene, origin + Vector3.new(x, upperFloor, side * 15.5), rays, 0.02) then
            return false, "unsupported Vesper stair landing"
        end
    end
    for index, first in gallery do
        local last = gallery[index % #gallery + 1]
        local samples = math.ceil((last - first).Magnitude)
        for sample = 0, samples do
            local position = first:Lerp(last, sample / samples)
            local point = origin + Vector3.new(position.X, upperFloor, position.Y)
            if
                not supports(scene, point, rays, 0.02)
                or scene:Raycast(point + Vector3.new(0, 0.02, 0), Vector3.new(0, clearance, 0), rays)
            then
                return false, "blocked or unsupported Vesper gallery route"
            end
        end
    end
    return true, nil
end

return VesperNavigation
