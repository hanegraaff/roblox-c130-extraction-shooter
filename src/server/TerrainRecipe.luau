--!strict
--[=[
    TerrainRecipe reconstructs the server-owned surface from four-stud material and
    height cells ordered by X then Z. Heights are hex-encoded studs above base grade.
    Validation finishes before any engine write. Restores touch only the authored box.
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
    m = Enum.Material.Mud,
    ["."] = Enum.Material.Air,
}
local resolution = 4
local cells = 180
local firstLayer = -8
local layerCount = 6

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
    local relief = recipe:FindFirstChild("ReliefRaster")
    if
        not raster
        or not raster:IsA("StringValue")
        or not relief
        or not relief:IsA("StringValue")
        or #recipe:GetChildren() ~= 3
    then
        return false, "missing district surface or relief raster"
    end
    for _, material in materials do
        if material ~= Enum.Material.Air and typeof(raster:GetAttribute(material.Name)) ~= "Color3" then
            return false, "missing terrain palette color"
        end
    end
    local rows = string.split(raster.Value, "\n")
    local heights = string.split(relief.Value, "\n")
    if #rows ~= cells or #heights ~= cells then
        return false, "invalid surface width"
    end
    for index, row in rows do
        local height = heights[index]
        if #row ~= cells or string.find(row, "[^stdpglavm%.]") then
            return false, "invalid district material row"
        end
        if #height ~= cells or string.find(height, "[^0-9a-f]") then
            return false, "invalid district relief row"
        end
        for column = 1, cells do
            if string.sub(row, column, column) == "." and string.sub(height, column, column) ~= "0" then
                return false, "raised terrain outside battlefield"
            end
        end
    end
    return true, nil
end

-- Repaints the native surface and fills the southern ridges and crater rim.
-- The original disk supports players while the terrain physics mesh updates.
function TerrainRecipe.restore(terrain: Terrain, recipe: Instance): (boolean, string?)
    local ok, reason = TerrainRecipe.validate(recipe)
    if not ok then
        return false, reason
    end
    local bounds = recipe:FindFirstChild("TerrainBounds") :: BasePart
    local raster = recipe:FindFirstChild("SurfaceRaster") :: StringValue
    local heights = string.split((recipe:FindFirstChild("ReliefRaster") :: StringValue).Value, "\n")
    local grid, density = {}, {}
    for x, row in string.split(raster.Value, "\n") do
        local stripe: { Enum.Material } = table.create(cells)
        local columnHeights: { number } = table.create(cells)
        local height = heights[x]
        for z = 1, cells do
            stripe[z] = materials[string.sub(row, z, z)]
            columnHeights[z] = tonumber(string.sub(height, z, z), 16) :: number
        end
        local layers: { { Enum.Material } } = table.create(layerCount)
        local occupancy: { { number } } = table.create(layerCount)
        for layer = 1, layerCount do
            local elevation = firstLayer + (layer - 1) * resolution
            local layerMaterials: { Enum.Material } = table.create(cells)
            local layerOccupancy: { number } = table.create(cells)
            for z = 1, cells do
                local amount = if stripe[z] == Enum.Material.Air
                    then 0
                    else math.clamp((columnHeights[z] - 2 - elevation) / resolution, 0, 1)
                layerOccupancy[z] = amount
                layerMaterials[z] = if amount > 0 then stripe[z] else Enum.Material.Air
            end
            layers[layer], occupancy[layer] = layerMaterials, layerOccupancy
        end
        grid[x], density[x] = layers, occupancy
    end
    for _, material in materials do
        if material ~= Enum.Material.Air then
            terrain:SetMaterialColor(material, raster:GetAttribute(material.Name) :: Color3)
        end
    end
    terrain:FillBlock(bounds.CFrame, bounds.Size, Enum.Material.Air)
    terrain:WriteVoxels(
        Region3.new(
            Vector3.new(-360, firstLayer, -360),
            Vector3.new(360, firstLayer + layerCount * resolution, 360)
        ),
        resolution,
        grid,
        density
    )
    return true, nil
end
return TerrainRecipe
