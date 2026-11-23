--!strict
--[=[
    Salt Flats private Studio Edit probe. Loads the approved version of one
    import batch outside the DataModel, records real native poses, dimensions,
    materials, and stable keys, and destroys the temporary load. Yields only
    for the native asset load. The caller supplies the batch inventory.
]=]
local InsertService = game:GetService("InsertService")

local function vector(value: Vector3): { number }
    return { value.X, value.Y, value.Z }
end

local function findKey(part: MeshPart, root: Instance): string?
    local current: Instance? = part
    while current and current ~= root do
        local key = string.match(current.Name, "^(SF_[PAD]%d*_%d%d%d_%d%d)$")
            or string.match(current.Name, "^(SF_[PAD]%d*_%d%d%d_%d%d)_Node$")
        if key then
            return key
        end
        current = current.Parent
    end
    return nil
end

-- Errors identify a missing, unexpected, or duplicated native mesh. This
-- probe trusts no imported scripts and makes no changes to the open place.
return function(assetVersionId: number, keys: { string })
    local remaining: { [string]: boolean } = {}
    for _, key in keys do
        assert(not remaining[key], "duplicate expected import key: " .. key)
        remaining[key] = true
    end
    local imported = InsertService:LoadAssetVersion(assetVersionId)
    local ok, report = pcall(function()
        local meshes = {}
        for _, item in imported:GetDescendants() do
            assert(not item:IsA("LuaSourceContainer"), "unexpected script in native batch")
            assert(not item:IsA("BasePart") or item:IsA("MeshPart"), "unexpected native part class")
            if item:IsA("MeshPart") then
                local key = findKey(item, imported)
                assert(key and remaining[key], "unmatched or duplicated native mesh: " .. item:GetFullName())
                remaining[key] = nil
                local surface = item:FindFirstChildWhichIsA("SurfaceAppearance")
                meshes[key] = {
                    meshId = item.MeshId,
                    meshSize = vector(item.MeshSize),
                    size = vector(item.Size),
                    cframe = { item.CFrame:GetComponents() },
                    textureId = item.TextureID,
                    colorMap = if surface then surface.ColorMap else "",
                    normalMap = if surface then surface.NormalMap else "",
                    roughnessMap = if surface then surface.RoughnessMap else "",
                    color = { item.Color.R, item.Color.G, item.Color.B },
                    collisionFidelity = item.CollisionFidelity.Name,
                }
            end
        end
        local missing = next(remaining)
        assert(not missing, "missing native mesh: " .. tostring(missing))
        return meshes
    end)
    imported:Destroy()
    if not ok then
        error(report)
    end
    return report
end
