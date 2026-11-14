--!strict
--[=[
    OutpostReconstruction: server-only construction adapter for the approved MVP
    smaller building. Depends on private managed MilitaryOutpost/MaterialPanels
    templates, shared material validation and the existing World.Battlefield.
    It changes no combat/round rules. Missing assets/invalid references/geometry
    reject before replacing the active building. No remotes/events/tasks/yielding.
    Source coordinates are studs at the surveyed (144,0,164) site; all25 legacy
    identity pivots remain exact. The map owner snapshots the installed building.
]=]
local Approved = require(script.Parent.ApprovedOutpost)
local Catalog = require(script.Parent.PanelAssetCatalog)
local MaterialGeometry = require(script.Parent.MaterialPanelGeometry)
local AssetRules = require(script.Parent.PanelAssetRules)
local OutpostReconstruction = {}
export type Installation = { commit: () -> (), rollback: () -> () }
local site = CFrame.new(144, 0, 164)

-- Validates the entire managed source and material library without world writes.
function OutpostReconstruction.prepare(assets: Instance): (Model?, string?)
    local catalog, catalogReason = Catalog.load(assets:FindFirstChild("MaterialPanels"))
    if not catalog then
        return nil, catalogReason
    end
    local source = assets:FindFirstChild("MilitaryOutpost")
    if
        not source
        or not source:IsA("Model")
        or not source.Archivable
        or source:GetAttribute("AssetRevision") ~= Approved.revision
        or source:GetAttribute("BlendSha256") ~= Approved.blendSha256
        or not AssetRules.receipt(source:GetAttribute("ImportReceiptSha256"))
        or source:GetAttribute("SourceMeshCount") ~= 2225
    then
        return nil, "missing/mismatched approved Outpost reconstruction"
    end
    local panels = source:FindFirstChild("Outpost_Panels")
    local statics = source:FindFirstChild("Outpost_Static")
    local navigation = source:FindFirstChild("Outpost_Navigation")
    if
        not panels
        or not panels:IsA("Folder")
        or #panels:GetChildren() ~= 26
        or not statics
        or not navigation
        or #navigation:GetChildren() ~= 5
    then
        return nil, "invalid approved Outpost registry/structure/navigation"
    end
    local function support(name: string, position: Vector3, size: Vector3): boolean
        local part = statics:FindFirstChild(name)
        return part ~= nil
            and part:IsA("MeshPart")
            and part.CanCollide
            and part.CanQuery
            and (part.Position - position).Magnitude < 0.001
            and (part.Size - size).Magnitude < 0.001
            and part.CFrame.UpVector:Dot(Vector3.yAxis) > 0.9999
    end
    if
        not support("Outpost_GroundFloor", Vector3.new(0, -0.375, 0), Vector3.new(32, 1, 48))
        or not support("Outpost_UpperMain", Vector3.new(5.5, 9.625, 0), Vector3.new(19, 1, 46))
        or not support("Outpost_UpperNorthLanding", Vector3.new(-9.5, 9.625, -20.5), Vector3.new(11, 1, 5))
    then
        return nil, "approved Outpost floor contract changed"
    end
    for index = 1, 16 do
        local height = index * 0.625
        if
            not support(
                string.format("Outpost_Step%02d", index),
                Vector3.new(-10, 0.125 + height / 2, 15 - (index - 1) * 2),
                Vector3.new(8, height, 2)
            )
        then
            return nil, "approved Outpost internal stair contract changed"
        end
    end
    local ids: { [string]: boolean } = {}
    local meshes = 0
    for _, item in source:GetDescendants() do
        if not item.Archivable then
            return nil, "non-archivable approved Outpost content"
        end
        if ids[item.Name] then
            return nil, "duplicate Outpost reconstruction identity"
        end
        ids[item.Name] = true
        if item:IsA("BasePart") then
            if
                not item.Anchored
                or item.CanTouch
                or not AssetRules.geometry(
                    { item.Size.X, item.Size.Y, item.Size.Z },
                    { item.CFrame:GetComponents() },
                    { 100, 100, 100 },
                    64
                )
            then
                return nil, "invalid approved Outpost geometry"
            end
            if item:IsA("MeshPart") then
                meshes += 1
                local appearance = item:FindFirstChildOfClass("SurfaceAppearance")
                if
                    item.MeshId == ""
                    or not appearance
                    or appearance.ColorMap == ""
                    or item.Color ~= Color3.new(1, 1, 1)
                then
                    return nil, "missing approved Outpost mesh/material repair"
                end
                local nonCover = item:GetAttribute("ThermalNonCover") == true
                if nonCover and (item.CanCollide or item.CanQuery) then
                    return nil, "non-cover art became authoritative cover"
                end
            end
        elseif not item:IsA("Model") and not item:IsA("Folder") and not item:IsA("SurfaceAppearance") then
            return nil, "unintended imported Outpost content: " .. item.ClassName
        end
    end
    if meshes ~= source:GetAttribute("PristineMeshCount") then
        return nil, "Outpost imported mesh count mismatch"
    end
    for _, item in panels:GetChildren() do
        if not item:IsA("Model") or item:GetAttribute("PanelId") ~= item.Name then
            return nil, "invalid Outpost panel identity"
        end
        local localPivot = item:GetAttribute("LocalIdentityPivot")
        if typeof(localPivot) ~= "CFrame" or localPivot ~= item:GetPivot() then
            return nil, "invalid Outpost local identity pivot"
        end
        local familyId = item:GetAttribute("PanelAssetFamily")
        local family = if type(familyId) == "string" then catalog[familyId] else nil
        if not family then
            return nil, "unknown Outpost panel family"
        end
        local valid, reason = MaterialGeometry.validate(item, family)
        if not valid then
            return nil, reason
        end
    end
    local model = source:Clone()
    model.Name = "Outpost"
    model.WorldPivot = CFrame.identity
    model:PivotTo(site)
    local clonedPanels = model:FindFirstChild("Outpost_Panels")
    assert(clonedPanels, "validated Outpost panels disappeared")
    for _, panel in clonedPanels:GetChildren() do
        assert(panel:IsA("Model"), "validated material identity changed class")
        local localPivot = panel:GetAttribute("LocalIdentityPivot")
        assert(typeof(localPivot) == "CFrame", "validated Outpost identity lacks local pivot")
        panel.WorldPivot = site * localPivot
        panel:SetAttribute("IntactPivot", panel:GetPivot())
    end
    return model, nil
end

-- Replaces exactly the smaller authored Outpost. Already-installed revision is
-- idempotent, preserving live damage. commit releases the old source; rollback
-- restores it only before the map owner snapshots/accepts this installation.
function OutpostReconstruction.install(world: Instance, assets: Instance): (Installation?, string?)
    local map = world:FindFirstChild("Battlefield")
    local buildings = if map then map:FindFirstChild("Buildings") else nil
    local original = if buildings then buildings:FindFirstChild("Outpost") else nil
    if
        not map
        or not buildings
        or #buildings:GetChildren() ~= 3
        or not original
        or not original:IsA("Model")
    then
        return nil, "missing intended smaller Outpost replacement target"
    end
    if original:GetAttribute("AssetRevision") == Approved.revision then
        return { commit = function() end, rollback = function() end }, nil
    end
    local model, reason = OutpostReconstruction.prepare(assets)
    if not model then
        return nil, reason
    end
    local previousRevision = map:GetAttribute("OutpostAssetRevision")
    original.Parent = nil
    model.Parent = buildings
    map:SetAttribute("OutpostAssetRevision", Approved.revision)
    local open = true
    return {
        commit = function()
            if not open then
                return
            end
            open = false
            original:Destroy()
        end,
        rollback = function()
            if not open then
                return
            end
            open = false
            model:Destroy()
            original.Parent = buildings
            map:SetAttribute("OutpostAssetRevision", previousRevision)
        end,
    },
        nil
end

return OutpostReconstruction
