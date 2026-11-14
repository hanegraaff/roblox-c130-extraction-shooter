--!strict
--[=[
    PanelAssetCatalog: server-only, nonyielding validation of approved imported
    material-panel templates. Depends on ApprovedOutpost and Roblox Instances.
    Templates are cosmetic MeshParts in canonical Blender-face coordinates mapped
    to Roblox (X,Z,-Y). Authoritative proxies come from the approved rectangles.
    This boundary never uploads, loads cloud content, mutates a world or falls back
    to approximate art. Validation of references is not proof of asset access.
]=]
local Approved = require(script.Parent.ApprovedOutpost)
local Rules = require(script.Parent.PanelAssetRules)
local PanelAssetCatalog = {}
export type Appearance = "Pristine" | "Light" | "Heavy" | "Total"
export type Rectangle = { number }
export type Variant = { template: Model, rectangles: { Rectangle } }
export type Family = {
    id: string,
    size: Vector3,
    states: { [string]: Variant },
    fragments: { MeshPart },
}
export type Catalog = { [string]: Family }

local function assetId(value: string): boolean
    return string.match(value, "^rbxassetid://[1-9]%d*$") ~= nil
end

-- Checks only inert imported content. The template's declared source identity
-- binds it to a receipt that must separately prove actual imported mesh/UV data.
-- Mesh cosmetics cannot obstruct weapons, thermal rays, avatars or fragment paths.
local function meshContent(root: Instance, bounds: { number }): (boolean, string?)
    local meshes = 0
    local names: { [Instance]: { [string]: boolean } } = {}
    for _, item in root:GetDescendants() do
        local parent = item.Parent
        assert(parent, "imported child detached during nonyielding validation")
        local siblings = names[parent] or {}
        if siblings[item.Name] then
            return false, "duplicate imported child name"
        end
        siblings[item.Name] = true
        names[parent] = siblings
        if item:IsA("MeshPart") then
            meshes += 1
            local appearance = item:FindFirstChildOfClass("SurfaceAppearance")
            if
                not assetId(item.MeshId)
                or (item.TextureID ~= "" and not assetId(item.TextureID))
                or (item.TextureID == "" and (not appearance or appearance.ColorMap == ""))
                or not item.Anchored
                or item.CanCollide
                or item.CanQuery
                or item.CanTouch
                or not Rules.geometry(
                    { item.Size.X, item.Size.Y, item.Size.Z },
                    { item.CFrame:GetComponents() },
                    bounds
                )
            then
                return false, "invalid cosmetic mesh/reference/flags: " .. item.Name
            end
        elseif item:IsA("SurfaceAppearance") then
            if not parent:IsA("MeshPart") or parent:FindFirstChildOfClass("SurfaceAppearance") ~= item then
                return false, "invalid/duplicate material appearance child"
            end
            for _, value in { item.ColorMap, item.MetalnessMap, item.NormalMap, item.RoughnessMap } do
                if value ~= "" and not assetId(value) then
                    return false, "invalid material texture reference"
                end
            end
        elseif not item:IsA("Model") and not item:IsA("Folder") then
            return false, "unexpected imported content: " .. item.ClassName
        end
    end
    if meshes > 32 then
        return false, "material variant exceeds mesh budget"
    end
    return true, nil
end

-- Reads six family folders, four named appearance Models and four MeshPart
-- fragment templates per family. Root requires AssetRevision, BlendSha256 and
-- a nonempty ImportReceiptSha256. Rejects all malformed/missing content without
-- any mutation. The returned references belong to the caller's private asset root.
function PanelAssetCatalog.load(root: Instance?): (Catalog?, string?)
    if not root or not root:IsA("Folder") then
        return nil, "missing approved material-panel assets"
    end
    if
        root:GetAttribute("AssetRevision") ~= Approved.revision
        or root:GetAttribute("BlendSha256") ~= Approved.blendSha256
        or not Rules.receipt(root:GetAttribute("ImportReceiptSha256"))
        or #root:GetChildren() ~= 6
    then
        return nil, "missing/mismatched approved import identity"
    end
    local result: Catalog = {}
    for id, definition in Approved.families do
        local family = root:FindFirstChild(id)
        if not family or not family:IsA("Folder") or #family:GetChildren() ~= 5 then
            return nil, "missing material family: " .. id
        end
        local states: { [string]: Variant } = {}
        for name, state in definition.states do
            local template = family:FindFirstChild(name)
            if
                not template
                or not template:IsA("Model")
                or template:GetAttribute("SourcePath") ~= state.source
                or template:GetAttribute("SourceSha256") ~= state.sha256
                or template:GetPivot() ~= CFrame.identity
            then
                return nil, "missing/invalid material appearance: " .. id .. "/" .. name
            end
            local valid, reason = meshContent(
                template,
                { definition.size[1] / 2, definition.size[3] / 2, definition.size[2] / 2 + 0.4 }
            )
            if not valid then
                return nil, reason
            end
            local hasMesh = template:FindFirstChildWhichIsA("MeshPart", true) ~= nil
            if hasMesh ~= (name ~= "Total") then
                return nil, "appearance has incorrect visible geometry"
            end
            states[name] = { template = template, rectangles = state.rectangles }
        end
        local fragments = family:FindFirstChild("Fragments")
        if not fragments or not fragments:IsA("Folder") or #fragments:GetChildren() ~= 4 then
            return nil, "missing material fragments: " .. id
        end
        local fragmentParts: { MeshPart } = {}
        for index, fragment in definition.fragments do
            local part = fragments:FindFirstChild(tostring(index))
            if
                not part
                or not part:IsA("MeshPart")
                or #part:GetChildren() > 1
                or not assetId(part.MeshId)
                or part:GetAttribute("SourcePath") ~= fragment.source
                or part:GetAttribute("SourceSha256") ~= fragment.sha256
                or part.Size.X > 1.5
                or part.Size.Y > 1.5
                or part.Size.Z > 1.5
                or not part.Anchored
                or part.CanCollide
                or part.CanQuery
                or part.CanTouch
            then
                return nil, "invalid material fragment: " .. id
            end
            local valid, reason = meshContent(fragments, { 0.75, 0.75, 0.75 })
            if not valid then
                return nil, reason
            end
            table.insert(fragmentParts, part)
        end
        result[id] = {
            id = id,
            size = Vector3.new(definition.size[1], definition.size[3], definition.size[2]),
            states = states,
            fragments = fragmentParts,
        }
    end
    return result, nil
end

return PanelAssetCatalog
