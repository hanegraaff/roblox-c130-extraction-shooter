--!strict
--[=[
    MaterialPanelGeometry: nonyielding server-only installation of validated
    material variants. Depends on PanelAssetCatalog references and Instances.
    Canonical wall face is local X/Y, normal Z; roofs rotate their identity pivot.
    Cosmetic meshes never collide/query. Exact approved rectangle proxies alone
    own solidity. The caller owns the stable panel Model and its cleanup/reset.
]=]
local Catalog = require(script.Parent.PanelAssetCatalog)
local AssetRules = require(script.Parent.PanelAssetRules)
local MaterialPanelGeometry = {}
-- Owned dressing may span several panels (approved roof rails are 42/44 studs).
-- It shares the full-building 64-stud ceiling in a bounded canonical envelope;
-- ordinary panel meshes/proxies and fragment catalog bounds keep their defaults.
local attachmentHalfBoundsStuds = { 32, 32, 32 }
local attachmentMaximumDimensionStuds = 64

-- Rotation-only material coordinates preserve legacy sidewall/roof identities.
-- Missing basis is identity. Reject malformed authoring without mutation.
function MaterialPanelGeometry.basis(model: Model): (CFrame?, string?)
    local value = model:GetAttribute("PanelAssetBasis")
    if value == nil then
        return CFrame.identity, nil
    end
    if
        typeof(value) ~= "CFrame"
        or value.Position.Magnitude > 1e-6
        or not AssetRules.geometry({ 1, 1, 1 }, { value:GetComponents() }, { 2, 2, 2 })
    then
        return nil, "invalid material panel asset basis"
    end
    return value, nil
end

-- Axis-aligned IntactSize in the stable identity frame, never a solid collider.
function MaterialPanelGeometry.identitySize(family: Catalog.Family, basis: CFrame): Vector3
    local right, up, back = basis.RightVector, basis.UpVector, -basis.LookVector
    return Vector3.new(
        math.abs(right.X) * family.size.X + math.abs(up.X) * family.size.Y + math.abs(back.X) * family.size.Z,
        math.abs(right.Y) * family.size.X + math.abs(up.Y) * family.size.Y + math.abs(back.Y) * family.size.Z,
        math.abs(right.Z) * family.size.X + math.abs(up.Z) * family.size.Y + math.abs(back.Z) * family.size.Z
    )
end

-- Checks the authored pristine proxy set before capture. Imported visible mesh
-- references are separately validated in the private catalog; models may not add
-- solid/queryable dressing or a hidden full-panel collider around these proxies.
function MaterialPanelGeometry.validate(model: Model, family: Catalog.Family): (boolean, string?)
    local rectangles = family.states.Pristine.rectangles
    local found: { [number]: boolean } = {}
    local identityPivot = model:GetPivot()
    local basis, reason = MaterialPanelGeometry.basis(model)
    if not basis then
        return false, reason
    end
    local pivot = identityPivot * basis
    for _, component in { pivot:GetComponents() } do
        if component ~= component or math.abs(component) == math.huge then
            return false, "nonfinite material panel pivot"
        end
    end
    for _, item in model:GetDescendants() do
        if item:IsA("BasePart") then
            local attachment = item:GetAttribute("PanelAttachment") == true
            if
                attachment
                and (not item:IsA("MeshPart") or item:GetAttribute("AttachmentPanelId") ~= model.Name)
            then
                return false, "invalid material panel attachment ownership"
            end
            if
                not AssetRules.geometry(
                    { item.Size.X, item.Size.Y, item.Size.Z },
                    { pivot:ToObjectSpace(item.CFrame):GetComponents() },
                    if attachment
                        then attachmentHalfBoundsStuds
                        else { family.size.X / 2, family.size.Y / 2, family.size.Z / 2 + 0.4 },
                    if attachment then attachmentMaximumDimensionStuds else nil
                )
            then
                return false, "invalid material panel geometry"
            end
            if item:IsA("MeshPart") then
                if not item.Anchored or item.CanCollide or item.CanQuery or item.CanTouch then
                    return false, "material cosmetics cannot become solid cover"
                end
            else
                local suffix = string.match(item.Name, "_Proxy(%d+)$")
                local index = if suffix then tonumber(suffix) else nil
                local rectangle = if index then rectangles[index] else nil
                if
                    not index
                    or not rectangle
                    or found[index]
                    or item.Parent ~= model
                    or not item.Anchored
                    or not item.CanCollide
                    or not item.CanQuery
                    or item.CanTouch
                    or item:GetAttribute("PanelProxy") ~= true
                    or item:GetAttribute("PanelId") ~= model.Name
                then
                    return false, "invalid/duplicate material proxy"
                end
                local expectedSize =
                    Vector3.new(rectangle[3] - rectangle[1], rectangle[4] - rectangle[2], family.size.Z)
                local expectedPose =
                    CFrame.new((rectangle[1] + rectangle[3]) / 2, (rectangle[2] + rectangle[4]) / 2, 0)
                local pose = pivot:ToObjectSpace(item.CFrame)
                if
                    (item.Size - expectedSize).Magnitude > 0.001
                    or (pose.Position - expectedPose.Position).Magnitude > 0.001
                    or (pose.RightVector - expectedPose.RightVector).Magnitude > 0.001
                    or (pose.UpVector - expectedPose.UpVector).Magnitude > 0.001
                then
                    return false, "material proxy differs from approved aperture geometry"
                end
                found[index] = true
            end
        elseif not item:IsA("SurfaceAppearance") then
            return false, "unexpected material panel child"
        end
    end
    for index in rectangles do
        if not found[index] then
            return false, "missing material proxy"
        end
    end
    return true, nil
end

-- Replaces only children of the caller-owned identity. pivot places canonical
-- family geometry; optional identityPivot retains legacy Model pivot metadata.
-- Pristine/Light copy panel-owned cosmetic attachments from the private original;
-- Heavy/Total remove that dressing so it cannot float across earned openings.
-- Templates must pass PanelAssetCatalog.load. No cloud loading or yielding.
function MaterialPanelGeometry.install(
    model: Model,
    pivot: CFrame,
    family: Catalog.Family,
    appearance: string,
    identityPivot: CFrame?,
    attachments: Instance?
)
    local variant = family.states[appearance]
    assert(variant, "validated material appearance disappeared")
    model:ClearAllChildren()
    local meshIndex = 0
    for _, source in variant.template:GetDescendants() do
        if source:IsA("MeshPart") then
            meshIndex += 1
            local child = source:Clone()
            child.Name = model.Name .. "_Mesh" .. tostring(meshIndex)
            child.CFrame = pivot * child.CFrame
            child:SetAttribute("PanelId", nil)
            child.Parent = model
        end
    end
    for index, rectangle in variant.rectangles do
        local x0, y0, x1, y1 = rectangle[1], rectangle[2], rectangle[3], rectangle[4]
        local proxy = Instance.new("Part")
        proxy.Name = model.Name .. "_Proxy" .. tostring(index)
        proxy.Size = Vector3.new(x1 - x0, y1 - y0, family.size.Z)
        proxy.CFrame = pivot * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, 0)
        proxy.Transparency = 1
        proxy.Anchored = true
        proxy.CanCollide = true
        proxy.CanQuery = true
        proxy.CanTouch = false
        proxy:SetAttribute("PanelId", model.Name)
        proxy:SetAttribute("PanelProxy", true)
        proxy.Parent = model
    end
    if attachments and (appearance == "Pristine" or appearance == "Light") then
        for _, source in attachments:GetChildren() do
            if source:IsA("MeshPart") and source:GetAttribute("PanelAttachment") == true then
                source:Clone().Parent = model
            end
        end
    end
    model.WorldPivot = identityPivot or pivot
end

-- Progress darkens the approved base material within a stage; it never applies
-- generic Slate scars or changes proxies/durability. Restoring pristine clones
-- recovers the exact imported colors rather than accumulating multiplicative tint.
function MaterialPanelGeometry.progress(model: Model, progress: number)
    for _, part in model:GetDescendants() do
        if part:IsA("MeshPart") then
            local original = part:GetAttribute("ImportedColor")
            if typeof(original) ~= "Color3" then
                original = part.Color
                part:SetAttribute("ImportedColor", original)
            end
            part.Color = (original :: Color3):Lerp(Color3.new(0, 0, 0), progress * 0.18)
        end
    end
end

return MaterialPanelGeometry
