--!strict
--[=[
    Studio Edit helper for an approved Vesper batch. Loads an owner-authorized
    model version detached from the live place, matches material-specific keys
    from prepare_import.py, and serializes only its native MeshPart copies.
    No scripts, package links, or world changes cross the import boundary.
    Use a private test document and record the actual approved version.
]=]
local InsertService = game:GetService("InsertService")
local Serialization = game:GetService("SerializationService")
local Encoding = game:GetService("EncodingService")

type MeshObservation = {
    key: string,
    sourcePath: string,
    meshId: string,
    meshSize: { number },
    size: { number },
    pose: { number },
    textureId: string,
    colorMap: string?,
    color: { number },
    collisionFidelity: string,
    renderFidelity: string,
}

local function vector(value: Vector3): { number }
    return { value.X, value.Y, value.Z }
end

-- Resolve exporter and importer spelling of the same identity. Looking through
-- the ancestry handles glTF containers named KEY_Node with a generic mesh child.
local function sourceKey(part: MeshPart, root: Instance): string?
    local current: Instance? = part
    while current and current ~= root do
        local name = current.Name
        local key = string.match(name, "^(VA_[AD]_%d%d%d_%d%d_%w+)$")
            or string.match(name, "^(VA_[AD]_%d%d%d_%d%d_%w+)_Node$")
        if key then
            return key
        end
        current = current.Parent
    end
    return nil
end

-- Yields for InsertService and native serialization. Expected keys must be
-- unique and equal to the batch inventory. Fails without partial output if the
-- importer dropped, merged, or added a part. No insertion into the DataModel.
return function(assetVersionId: number, keys: { string })
    local remaining: { [string]: boolean } = {}
    for _, key in keys do
        assert(not remaining[key], "duplicate expected Vesper import key")
        remaining[key] = true
    end
    local imported = InsertService:LoadAssetVersion(assetVersionId)
    local folder = Instance.new("Folder")
    folder.Name = "VesperNativeImport"
    local ok, result = pcall(function()
        local records: { MeshObservation } = {}
        for _, item in imported:GetDescendants() do
            assert(not item:IsA("LuaSourceContainer"), "unexpected script in Vesper import")
            assert(not item:IsA("BasePart") or item:IsA("MeshPart"), "unexpected Vesper import geometry")
            if item:IsA("MeshPart") then
                local key = sourceKey(item, imported)
                assert(
                    key and remaining[key],
                    "unmatched or duplicate native Vesper object: " .. item:GetFullName()
                )
                remaining[key] = nil
                local surface = item:FindFirstChildWhichIsA("SurfaceAppearance")
                table.insert(records, {
                    key = key,
                    sourcePath = item:GetFullName(),
                    meshId = item.MeshId,
                    meshSize = vector(item.MeshSize),
                    size = vector(item.Size),
                    pose = { item.CFrame:GetComponents() },
                    textureId = item.TextureID,
                    colorMap = if surface then surface.ColorMap else nil,
                    color = { item.Color.R, item.Color.G, item.Color.B },
                    collisionFidelity = item.CollisionFidelity.Name,
                    renderFidelity = item.RenderFidelity.Name,
                })
                local copy = item:Clone()
                copy:ClearAllChildren()
                if surface then
                    surface:Clone().Parent = copy
                end
                copy.Name = key
                copy.Anchored = true
                copy.CanCollide = false
                copy.CanQuery = false
                copy.CanTouch = false
                copy.Parent = folder
            end
        end
        assert(next(remaining) == nil, "missing native Vesper objects")
        table.sort(records, function(a, b)
            return a.key < b.key
        end)
        local bytes = Serialization:SerializeInstancesAsync({ folder })
        return {
            assetVersionId = tostring(assetVersionId),
            records = records,
            byteLength = buffer.len(bytes),
            data = buffer.tostring(Encoding:Base64Encode(bytes)),
        }
    end)
    imported:Destroy()
    folder:Destroy()
    if not ok then
        error(result)
    end
    return result
end
