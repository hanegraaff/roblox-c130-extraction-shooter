--!strict
--[=[
    GroundOriginGeometry: server-only conservative validation of rifle muzzle geometry.
    Depends on actual Battlefield BaseParts and Terrain voxels; never yields. Owns one
    invisible noninteractive probe, which must be destroyed by its caller on teardown.
    Rejects a root or head inside BasePart cover, any solid between root and head,
    and a head in a nonempty solid Terrain voxel. This conservative voxel policy can
    reject fire near terrain edges; it never moves or penalizes a character.
]=]
local Validation = require(game:GetService("ReplicatedStorage").Shared.Validation)
local GroundOriginGeometry = {}
export type Controller = {
    allows: (BasePart, BasePart) -> (boolean, string?),
    destroy: () -> (),
}
local VOXEL = 4
-- Conservative check: any non-air, non-water solid in the head's 4-stud voxel
-- forbids firing, including partial occupancy where exact point membership is not
-- available from ReadVoxels. The current character head stands above ground level.
local function clearTerrain(position: Vector3): boolean
    local cell = Vector3.new(
        math.floor(position.X / VOXEL) * VOXEL,
        math.floor(position.Y / VOXEL) * VOXEL,
        math.floor(position.Z / VOXEL) * VOXEL
    )
    local region = Region3.new(cell, cell + Vector3.one * VOXEL)
    local material, occupancy = workspace.Terrain:ReadVoxels(region, VOXEL)
    local voxelMaterial = material[1][1][1]
    return voxelMaterial == Enum.Material.Air
        or voxelMaterial == Enum.Material.Water
        or occupancy[1][1][1] <= 0
end
-- Creates a lifecycle-owned server probe. Parent must be in Workspace. The
-- function rejects missing battlefield and nonfinite/displaced body parts rather
-- than guessing; body queries exclude characters and noncollidable art. The
-- optional nonyielding terrain query is an injection boundary for failure tests.
function GroundOriginGeometry.new(parent: Instance, terrainQuery: ((Vector3) -> boolean)?): Controller
    local probe = Instance.new("Part")
    probe.Name = "GroundOriginProbe"
    probe.Anchored = true
    probe.Size = Vector3.one * 0.2
    probe.CanCollide = false
    probe.CanTouch = false
    probe.CanQuery = false
    probe.Transparency = 1
    probe.Parent = parent
    local running = true
    local query: (Vector3) -> boolean = if terrainQuery then terrainQuery else clearTerrain
    return {
        allows = function(root, head)
            if not running then
                return false, "stopped"
            end
            local body, muzzle = root.Position, head.Position
            local displacement = muzzle - body
            if
                not Validation.isFinite(body.X)
                or not Validation.isFinite(body.Y)
                or not Validation.isFinite(body.Z)
                or not Validation.isFinite(muzzle.X)
                or not Validation.isFinite(muzzle.Y)
                or not Validation.isFinite(muzzle.Z)
                or not Validation.isFinite(displacement.Magnitude)
                or displacement.Magnitude < 0.1
                or displacement.Magnitude > 8
            then
                return false, "invalid body geometry"
            end
            local world = workspace:FindFirstChild("World")
            local battlefield = if world then world:FindFirstChild("Battlefield") else nil
            if not battlefield then
                return false, "battlefield unavailable"
            end
            local queried, clear = pcall(function()
                return query(muzzle)
            end)
            if not queried then
                return false, "terrain query failed"
            end
            if not clear then
                return false, "muzzle terrain voxel occupied"
            end
            local overlaps = OverlapParams.new()
            overlaps.FilterType = Enum.RaycastFilterType.Include
            overlaps.FilterDescendantsInstances = { battlefield }
            overlaps.RespectCanCollide = true
            probe.Position = body
            if
                #workspace:GetPartsInPart(probe, overlaps) > 0
                or #workspace:GetPartsInPart(head, overlaps) > 0
            then
                return false, "body overlaps cover"
            end
            local ray = RaycastParams.new()
            ray.FilterType = Enum.RaycastFilterType.Include
            ray.FilterDescendantsInstances = { battlefield, workspace.Terrain }
            ray.RespectCanCollide = true
            ray.IgnoreWater = true
            -- Test both directions: Roblox may not report a solid containing
            -- the starting point. If the root is in Terrain but the head is
            -- outside, the head-to-root ray enters and detects that Terrain.
            if
                workspace:Raycast(body, displacement, ray) or workspace:Raycast(muzzle, -displacement, ray)
            then
                return false, "solid cover between body and muzzle"
            end
            return true, nil
        end,
        destroy = function()
            if not running then
                return
            end
            running = false
            probe:Destroy()
        end,
    }
end
return GroundOriginGeometry
