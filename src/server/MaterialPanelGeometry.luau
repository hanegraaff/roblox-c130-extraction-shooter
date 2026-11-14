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

-- Checks the authored pristine proxy set before capture. Imported visible mesh
-- references are separately validated in the private catalog; models may not add
-- solid/queryable dressing or a hidden full-panel collider around these proxies.
function MaterialPanelGeometry.validate(model: Model, family: Catalog.Family): (boolean, string?)
    local rectangles = family.states.Pristine.rectangles
    local found: { [number]: boolean } = {}
    local pivot = model:GetPivot()
    for _, component in { pivot:GetComponents() } do
        if component ~= component or math.abs(component) == math.huge then
            return false, "nonfinite material panel pivot"
        end
    end
    for _, item in model:GetDescendants() do
        if item:IsA("BasePart") then
            if
                not AssetRules.geometry(
                    { item.Size.X, item.Size.Y, item.Size.Z },
                    { pivot:ToObjectSpace(item.CFrame):GetComponents() },
                    { family.size.X / 2, family.size.Y / 2, family.size.Z / 2 + 0.4 }
                )
            then
                return false, "invalid material panel geometry"
            end
            if item:IsA("MeshPart") then
                if not item.Anchored or item.CanCollide or item.CanQuery or item.CanTouch then
                    return false, "material cosmetics cannot become solid cover"
                end
            else
                local index = tonumber(string.match(item.Name, "_Proxy(%d+)$"))
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

-- Replaces only children of the caller-owned identity. Template references must
-- already pass PanelAssetCatalog.load. No cloud loading or yielding occurs here.
function MaterialPanelGeometry.install(
    model: Model,
    pivot: CFrame,
    family: Catalog.Family,
    appearance: string
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
    model.WorldPivot = pivot
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
