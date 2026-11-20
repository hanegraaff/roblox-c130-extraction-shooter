--!strict
--[=[
    AssetMaterial: shared, nonyielding reader for compiled material metadata.
    SurfaceAppearance map properties require Plugin capability and are NEVER read
    by ordinary game code. The compiler and artifact/Edit audits bind these
    readable attributes to the actual serialized slots and approved PNG receipt.
    Metadata matching is not an asset-availability or protected-slot comparison;
    actual Instance-based preload and authoring audits establish those separately.
    No world mutation, remotes, caching or cleanup ownership.
]=]
local AssetMaterial = {}
export type Material = {
    key: string,
    colorMap: string,
    normalMap: string,
    roughnessMap: string,
    metalnessMap: string,
    colorPngSha256: string,
}

local function reference(value: unknown, required: boolean): string?
    if type(value) ~= "string" then
        return nil
    end
    if value == "" and not required then
        return value
    end
    return if string.match(value, "^rbxassetid://[1-9]%d*$") then value else nil
end

-- Requires one real SurfaceAppearance plus its explicit v1 compiled contract.
-- All map strings are metadata; callers must label observations accordingly.
function AssetMaterial.read(mesh: MeshPart): (Material?, string?)
    local surface: SurfaceAppearance? = nil
    for _, child in mesh:GetChildren() do
        if child:IsA("SurfaceAppearance") then
            if surface then
                return nil, "duplicate compiled SurfaceAppearance"
            end
            surface = child
        end
    end
    if not surface then
        return nil, "missing compiled SurfaceAppearance"
    end
    local key = mesh:GetAttribute("MaterialKey")
    if
        type(key) ~= "string"
        or #key < 1
        or #key > 40
        or surface:GetAttribute("MaterialMetadataVersion") ~= 1
        or surface:GetAttribute("MaterialKey") ~= key
    then
        return nil, "invalid compiled material identity/version"
    end
    local color = reference(surface:GetAttribute("CompiledColorMap"), true)
    local normal = reference(surface:GetAttribute("CompiledNormalMap"), false)
    local roughness = reference(surface:GetAttribute("CompiledRoughnessMap"), false)
    local metalness = reference(surface:GetAttribute("CompiledMetalnessMap"), false)
    local digest = surface:GetAttribute("CompiledColorPngSha256")
    if
        not color
        or normal == nil
        or roughness == nil
        or metalness == nil
        or type(digest) ~= "string"
        or #digest ~= 64
        or not string.match(digest, "^[0-9a-f]+$")
    then
        return nil, "invalid compiled material map metadata"
    end
    return {
        key = key,
        colorMap = color,
        normalMap = normal,
        roughnessMap = roughness,
        metalnessMap = metalness,
        colorPngSha256 = digest,
    },
        nil
end

return AssetMaterial
