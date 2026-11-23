--!strict
--[=[
    VesperPanelGeometry: server-only adapter for named, native Warehouse panel
    states. Content lives in ServerStorage. Visual meshes have no query authority.
    Only immediate named proxies can register hits. Uses the shared structural
    ledger, damage tiers and fragment owner. All coordinates are local studs
    relative to the stable identity pivot. No yielding or network access.
]=]
local Shared = game:GetService("ReplicatedStorage").Shared
local AssetMesh = require(Shared.AssetMesh)
local Rules = require(script.Parent.PanelAssetRules)
local VesperPanelGeometry = {}

export type Variants = {
    light: Model,
    heavy: Model,
    fragments: { MeshPart }?,
}

-- Checks a single state. Report proxy poses in its identity frame so the Light
-- state can be required to retain precisely the pristine collision surface.
local function inspect(model: Model): ({ [string]: BasePart }?, string?)
    local proxies: { [string]: BasePart } = {}
    local names: { [string]: boolean } = {}
    local visualCount, proxyCount = 0, 0
    for _, item in model:GetChildren() do
        if
            not item:IsA("BasePart")
            or names[item.Name]
            or not item.Archivable
            or not item.Anchored
            or item.CanTouch
            or not Rules.geometry(
                { item.Size.X, item.Size.Y, item.Size.Z },
                { model:GetPivot():ToObjectSpace(item.CFrame):GetComponents() },
                { 24, 24, 24 }
            )
        then
            return nil, "invalid Vesper panel geometry: " .. item.Name
        end
        names[item.Name] = true
        if item:IsA("MeshPart") and not AssetMesh.validate(item, true) then
            return nil, "invalid Vesper native payload: " .. item.Name
        end
        if item:GetAttribute("PanelProxy") == true then
            if
                not item.CanCollide
                or not item.CanQuery
                or item.Transparency ~= 1
                or (not item:IsA("Part") and not item:IsA("MeshPart") and not item:IsA("WedgePart") and not item:IsA(
                    "CornerWedgePart"
                ))
                or (item:IsA("MeshPart") and item.CollisionFidelity ~= Enum.CollisionFidelity.PreciseConvexDecomposition)
                or #item:GetChildren() ~= 0
            then
                return nil, "invalid Vesper panel proxy: " .. item.Name
            end
            proxies[item.Name] = item
            proxyCount += 1
        else
            if not item:IsA("MeshPart") or item.CanCollide or item.CanQuery then
                return nil, "Vesper visual geometry cannot obstruct queries"
            end
            local children = item:GetChildren()
            if #children > 1 or (#children == 1 and not children[1]:IsA("SurfaceAppearance")) then
                return nil, "invalid Vesper visual dependencies"
            end
            visualCount += 1
        end
    end
    if proxyCount == 0 or visualCount == 0 then
        return nil, "Vesper panel requires visible geometry and cover"
    end
    return proxies, nil
end

-- Loads the aligned Light and Heavy templates for one stable identity. The
-- compiler additionally binds all geometry/materials to the recorded native
-- imports. Proxies in the assembled model are stamped before round capture.
function VesperPanelGeometry.load(bank: Instance?, panel: Model): (Variants?, string?)
    if not bank or not bank:IsA("Folder") then
        return nil, "missing private Vesper panel bank"
    end
    local spec = bank:FindFirstChild(panel.Name)
    local light = if spec then spec:FindFirstChild("Light") else nil
    local heavy = if spec then spec:FindFirstChild("Heavy") else nil
    if
        not light
        or not light:IsA("Model")
        or not heavy
        or not heavy:IsA("Model")
        or light:GetPivot() ~= CFrame.identity
        or heavy:GetPivot() ~= CFrame.identity
    then
        return nil, "missing or moved Vesper panel state: " .. panel.Name
    end
    local pristineProxies, pristineReason = inspect(panel)
    if not pristineProxies then
        return nil, pristineReason
    end
    local lightProxies, lightReason = inspect(light)
    if not lightProxies then
        return nil, lightReason
    end
    local heavyProxies, heavyReason = inspect(heavy)
    if not heavyProxies then
        return nil, heavyReason
    end
    for name, original in pristineProxies do
        local proxy = lightProxies[name]
        if
            not proxy
            or proxy.ClassName ~= original.ClassName
            or (proxy:IsA("Part") and original:IsA("Part") and proxy.Shape ~= original.Shape)
            or (proxy.Size - original.Size).Magnitude > 0.001
            or (proxy.Position - panel:GetPivot():PointToObjectSpace(original.Position)).Magnitude > 0.001
            or (proxy.CFrame.RightVector - panel:GetPivot():VectorToObjectSpace(original.CFrame.RightVector)).Magnitude > 0.001
            or (proxy.CFrame.UpVector - panel:GetPivot():VectorToObjectSpace(original.CFrame.UpVector)).Magnitude > 0.001
            or (proxy:IsA("MeshPart") and (not original:IsA("MeshPart") or proxy.MeshId ~= original.MeshId))
        then
            return nil, "Light panel must preserve pristine collision: " .. panel.Name
        end
        lightProxies[name] = nil
    end
    if next(lightProxies) then
        return nil, "unexpected added Light collider"
    end
    local variant = if string.find(panel.Name, "_Roof_", 1, true) then "RoofFragments" else "WallFragments"
    local fragmentBank = bank:FindFirstChild(variant)
    if not fragmentBank or not fragmentBank:IsA("Folder") or #fragmentBank:GetChildren() ~= 4 then
        return nil, "missing Vesper fragment family"
    end
    local fragments: { MeshPart } = {}
    for index = 1, 4 do
        local fragment = fragmentBank:FindFirstChild(tostring(index))
        if
            not fragment
            or not fragment:IsA("MeshPart")
            or not AssetMesh.validate(fragment, true)
            or not fragment.Anchored
            or fragment.CanQuery
            or fragment.CanCollide
            or fragment.CanTouch
            or math.max(fragment.Size.X, fragment.Size.Y, fragment.Size.Z) > 1.5
        then
            return nil, "invalid Vesper fragment"
        end
        table.insert(fragments, fragment)
    end
    return { light = light, heavy = heavy, fragments = fragments }, nil
end

-- Replaces the captured identity's owned state in one synchronous update.
-- A nil state represents Total. Restoring the captured pristine model uses its
-- own pivot as the origin. Static structure is outside the identity model.
function VesperPanelGeometry.install(panel: Model, template: Model?, pivot: CFrame)
    panel:ClearAllChildren()
    if template then
        for _, item in template:GetChildren() do
            assert(item:IsA("BasePart"), "validated Vesper part disappeared")
            local child = item:Clone()
            child.CFrame = pivot * template:GetPivot():ToObjectSpace(item.CFrame)
            child:SetAttribute(
                "PanelId",
                if child:GetAttribute("PanelProxy") == true then panel.Name else nil
            )
            child.Parent = panel
        end
    end
    panel.WorldPivot = pivot
end

return VesperPanelGeometry
