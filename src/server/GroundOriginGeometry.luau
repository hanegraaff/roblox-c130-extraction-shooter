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
    allows: (BasePart, BasePart) -> boolean,
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
-- than guessing; root-to-head queries exclude character and noncollidable art.
function GroundOriginGeometry.new(parent: Instance): Controller
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
    return {
        allows = function(root, head)
            if not running then
                return false
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
                return false
            end
            local world = workspace:FindFirstChild("World")
            local battlefield = if world then world:FindFirstChild("Battlefield") else nil
            if not battlefield or not clearTerrain(muzzle) then
                return false
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
                return false
            end
            local ray = RaycastParams.new()
            ray.FilterType = Enum.RaycastFilterType.Include
            ray.FilterDescendantsInstances = { battlefield, workspace.Terrain }
            ray.RespectCanCollide = true
            ray.IgnoreWater = true
            return workspace:Raycast(body, displacement, ray) == nil
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
