--!strict
--[=[
    TerrainRecipe: server-only deterministic, bounded smooth-terrain reconstruction.
    Depends on Terrain and authored invisible sphere descriptors in Battlefield.TerrainRecipe.
    The recipe is version 1 / seed 0 (no random sampling), 4-stud engine voxels. It owns
    only the explicit voxel-aligned TerrainBounds box. No global Clear is permitted.
    Calls do not yield; at most eight FillBall writes plus one bounded FillBlock clear.
    Engine ray/collision updates may converge afterward; no immediate physics-ready claim.
]=]
local TerrainRecipe = {}

-- Rejects malformed recipes before touching terrain. Bounds include each entire sphere,
-- so a reset cannot leave voxels from a previous recipe outside its clear volume.
function TerrainRecipe.validate(recipe: Instance): (boolean, string?)
    local bounds = recipe:FindFirstChild("TerrainBounds")
    if not bounds or not bounds:IsA("BasePart") then
        return false, "missing terrain ownership bounds"
    end
    if bounds.CFrame ~= CFrame.new(0, -40, 0) or bounds.Size ~= Vector3.new(736, 144, 736) then
        return false, "terrain ownership bounds changed"
    end
    if #recipe:GetChildren() ~= 9 then
        return false, "terrain recipe requires eight hills and bounds"
    end
    for _, item in recipe:GetChildren() do
        if item ~= bounds then
            if not item:IsA("Part") or item.Shape ~= Enum.PartType.Ball then
                return false, "terrain recipe must contain spheres"
            end
            local radius = item.Size.X / 2
            if item.Size ~= Vector3.one * radius * 2 or radius < 4 or radius > 64 then
                return false, "invalid terrain sphere radius"
            end
            local localCenter = bounds.CFrame:PointToObjectSpace(item.Position)
            if
                math.abs(localCenter.X) + radius > bounds.Size.X / 2
                or math.abs(localCenter.Y) + radius > bounds.Size.Y / 2
                or math.abs(localCenter.Z) + radius > bounds.Size.Z / 2
            then
                return false, "terrain sphere escapes ownership bounds"
            end
            if Vector2.new(item.Position.X, item.Position.Z).Magnitude + radius >= 358 then
                return false, "terrain sphere escapes playable boundary"
            end
            if item.Material ~= Enum.Material.Grass and item.Material ~= Enum.Material.Rock then
                return false, "unexpected terrain material"
            end
        end
    end
    return true, nil
end

-- Replaces only the owned volume with the fixed recipe. Returns false without writes
-- for invalid authoring. Unrelated Terrain outside bounds is never read or overwritten.
function TerrainRecipe.restore(terrain: Terrain, recipe: Instance): (boolean, string?)
    local valid, reason = TerrainRecipe.validate(recipe)
    if not valid then
        return false, reason
    end
    local bounds = recipe:FindFirstChild("TerrainBounds") :: BasePart
    terrain:FillBlock(bounds.CFrame, bounds.Size, Enum.Material.Air)
    for _, item in recipe:GetChildren() do
        if item:IsA("Part") and item.Name ~= "TerrainBounds" then
            terrain:FillBall(item.Position, item.Size.X / 2, item.Material)
        end
    end
    return true, nil
end
return TerrainRecipe
