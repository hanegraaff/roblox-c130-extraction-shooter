--!strict
--[=[
    TerrainRecipe reconstructs the server-owned level surface from four-stud material
    cells ordered by X then Z. Each non-air cell fills the layer immediately below
    ground level. Restores and clears are bounded to the historical terrain volume so
    older hill voxels disappear on upgrade. Validation finishes before any engine write.
]=]
local TerrainRecipe = {}
local materials: { [string]: Enum.Material } = {
    s = Enum.Material.Sand,
    t = Enum.Material.Sandstone,
    d = Enum.Material.Ground,
    p = Enum.Material.Cobblestone,
    g = Enum.Material.Grass,
    l = Enum.Material.LeafyGrass,
    a = Enum.Material.Asphalt,
    v = Enum.Material.Pavement,
    ["."] = Enum.Material.Air,
}
local resolution = 4
local cells = 180

-- Rejects changed ownership bounds, unknown material symbols and truncated rows.
function TerrainRecipe.validate(recipe: Instance): (boolean, string?)
    local bounds = recipe:FindFirstChild("TerrainBounds")
    if
        not bounds
        or not bounds:IsA("BasePart")
        or bounds.CFrame ~= CFrame.new(0, -40, 0)
        or bounds.Size ~= Vector3.new(736, 144, 736)
    then
        return false, "invalid terrain ownership bounds"
    end
    local raster = recipe:FindFirstChild("SurfaceRaster")
    if not raster or not raster:IsA("StringValue") or #recipe:GetChildren() ~= 2 then
        return false, "missing district surface raster"
    end
    for _, material in materials do
        if material ~= Enum.Material.Air and typeof(raster:GetAttribute(material.Name)) ~= "Color3" then
            return false, "missing terrain palette color"
        end
    end
    local rows = string.split(raster.Value, "\n")
    if #rows ~= cells then
        return false, "invalid surface width"
    end
    for _, row in rows do
        if #row ~= cells or string.find(row, "[^stdpglav%.]") then
            return false, "invalid district material row"
        end
    end
    return true, nil
end

-- Repaints native Sand, Grass and road materials at Y=0. The original disk supports
-- players while the physics mesh updates. The volume outside TerrainBounds is untouched.
function TerrainRecipe.restore(terrain: Terrain, recipe: Instance): (boolean, string?)
    local ok, reason = TerrainRecipe.validate(recipe)
    if not ok then
        return false, reason
    end
    local bounds = recipe:FindFirstChild("TerrainBounds") :: BasePart
    local raster = recipe:FindFirstChild("SurfaceRaster") :: StringValue
    local grid, density = {}, {}
    for x, row in string.split(raster.Value, "\n") do
        local stripe: { Enum.Material } = table.create(cells)
        local solids: { number } = table.create(cells)
        local surface: { number } = table.create(cells)
        for z = 1, cells do
            local material = materials[string.sub(row, z, z)]
            stripe[z] = material
            solids[z] = if material == Enum.Material.Air then 0 else 1
            surface[z] = solids[z] * 0.5
        end
        grid[x], density[x] = { stripe, stripe }, { solids, surface }
    end
    for _, material in materials do
        if material ~= Enum.Material.Air then
            terrain:SetMaterialColor(material, raster:GetAttribute(material.Name) :: Color3)
        end
    end
    terrain:FillBlock(bounds.CFrame, bounds.Size, Enum.Material.Air)
    terrain:WriteVoxels(
        Region3.new(Vector3.new(-360, -8, -360), Vector3.new(360, 0, 360)),
        resolution,
        grid,
        density
    )
    return true, nil
end
return TerrainRecipe
