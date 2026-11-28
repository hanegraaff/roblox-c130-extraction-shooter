--!strict
--[=[
    Installs the source-managed Sandbreak shelter before MapService snapshots
    the battlefield. A source checkout with no Sandbreak bank retains its
    primitive shelter. Validation and installation do not yield.
]=]
local VesperPanelGeometry = require(script.Parent.VesperPanelGeometry)
local SandbreakReconstruction = {}

export type Installation = { commit: () -> (), rollback: () -> () }

local panelCount = 103
local sourceSha256 = "27b825df1b09d7b7ea37d2fb302163ae55efa7b9c55c332ec2a9d86cc4160709"
local function unchanged() end

-- These presentation attributes are cloned with the pristine map. The operator
-- shades the native color maps locally; no authored part properties are edited.
local function configureThermal(model: Model)
    model:SetAttribute("ThermalBrightness", 0.60)
    model:SetAttribute("ThermalSurfacePalette", "SandbreakThermalSurfaces")
end

local function validState(root: Model): boolean
    local proxies, visuals = 0, 0
    for _, part in root:GetChildren() do
        if not part:IsA("MeshPart") or not part.Anchored or part.CanTouch or not part.Archivable then
            return false
        end
        local nativeSize = part:GetAttribute("NativeMeshSize")
        if
            typeof(nativeSize) ~= "Vector3"
            or (part.MeshSize - nativeSize).Magnitude > 0.001
            or nativeSize.Magnitude <= 0
            or part:GetAttribute("NativeMeshId") ~= part.MeshId
            or not string.match(part.MeshId, "^rbxassetid://[1-9]%d*$")
            or part:GetAttribute("NativeCollisionFidelity") ~= part.CollisionFidelity.Name
            or part:GetAttribute("NativeRenderFidelity") ~= part.RenderFidelity.Name
        then
            return false
        end
        if part:GetAttribute("PanelProxy") == true then
            if
                not part.CanCollide
                or not part.CanQuery
                or part.Transparency ~= 1
                or part.CollisionFidelity ~= Enum.CollisionFidelity.PreciseConvexDecomposition
                or #part:GetChildren() ~= 0
            then
                return false
            end
            proxies += 1
        else
            if part.CanCollide or part.CanQuery then
                return false
            end
            visuals += 1
        end
    end
    return proxies == 1 and visuals > 0
end

-- Resolves both validated damage states for the shared modeled-panel presenter.
function SandbreakReconstruction.panelVariants(
    bank: Instance?,
    panel: Model
): (VesperPanelGeometry.Variants?, string?)
    local entry = if bank then bank:FindFirstChild(panel.Name) else nil
    local light = if entry then entry:FindFirstChild("Light") else nil
    local heavy = if entry then entry:FindFirstChild("Heavy") else nil
    if
        not light
        or not light:IsA("Model")
        or not heavy
        or not heavy:IsA("Model")
        or light:GetPivot() ~= CFrame.identity
        or heavy:GetPivot() ~= CFrame.identity
        or not validState(panel)
        or not validState(light)
        or not validState(heavy)
    then
        return nil, "Invalid Sandbreak states for " .. panel.Name
    end
    local proxy: MeshPart? = nil
    for _, part in panel:GetChildren() do
        if part:IsA("MeshPart") and part:GetAttribute("PanelProxy") == true then
            proxy = part
            break
        end
    end
    assert(proxy, "Validated Sandbreak proxy missing")
    local lightProxy = light:FindFirstChild(proxy.Name)
    local intactLocal = panel:GetPivot():ToObjectSpace(proxy.CFrame)
    if
        not lightProxy
        or not lightProxy:IsA("MeshPart")
        or proxy.MeshId ~= lightProxy.MeshId
        or (proxy.Size - lightProxy.Size).Magnitude > 0.001
        or not intactLocal:FuzzyEq(lightProxy.CFrame, 0.001)
    then
        return nil, "Sandbreak Light must keep pristine collision for " .. panel.Name
    end
    return { light = light, heavy = heavy, fragments = nil }, nil
end

-- Returns committing and rollback callbacks. Failed validation changes nothing.
function SandbreakReconstruction.install(world: Instance, assets: Instance): (Installation?, string?)
    local source = assets:FindFirstChild("SandbreakBunker")
    local bank = assets:FindFirstChild("SandbreakPanelVariants")
    if not source and not bank then
        return { commit = unchanged, rollback = unchanged }, nil
    end
    if not source or not source:IsA("Model") or not bank or not bank:IsA("Folder") then
        return nil, "Missing managed Sandbreak assembly or panel bank"
    end
    local binding = source:GetAttribute("ImportBinding")
    if
        type(binding) ~= "string"
        or #binding ~= 64
        or string.match(binding, "^[a-f0-9]+$") == nil
        or binding ~= bank:GetAttribute("ImportBinding")
        or source:GetAttribute("BlendSha256") ~= sourceSha256
    then
        return nil, "Invalid native Sandbreak binding"
    end
    local map = world:FindFirstChild("Battlefield")
    if not map or not map:IsA("Model") then
        return nil, "Missing Sandbreak battlefield"
    end
    local installed = map:FindFirstChild(source.Name)
    if installed and installed:GetAttribute("ImportBinding") == binding then
        return { commit = unchanged, rollback = unchanged }, nil
    end
    local original = map:FindFirstChild("SpawnShelterPanels")
    local panels = source:FindFirstChild("SpawnShelterPanels")
    local static = source:FindFirstChild("SandbreakStatic")
    if
        installed
        or not original
        or not original:IsA("Folder")
        or #original:GetChildren() ~= 76
        or not panels
        or not panels:IsA("Folder")
        or #panels:GetChildren() ~= panelCount
        or #bank:GetChildren() ~= panelCount
        or not static
        or not static:IsA("Folder")
    then
        return nil, "Invalid Sandbreak shelter roots"
    end
    for _, part in static:GetChildren() do
        if
            not part:IsA("BasePart")
            or not part.Anchored
            or part.CanTouch
            or part.CanCollide ~= part.CanQuery
            or (part:IsA("MeshPart") and part.CanQuery)
            or (not part:IsA("MeshPart") and (not part:IsA("Part") or part.Transparency ~= 1))
        then
            return nil, "Invalid Sandbreak stable structure " .. part.Name
        end
    end
    local ids: { [string]: boolean } = {}
    for _, panel in panels:GetChildren() do
        if
            not panel:IsA("Model")
            or panel:GetAttribute("SandbreakPanel") ~= true
            or panel:GetAttribute("PanelId") ~= panel.Name
            or ids[panel.Name]
        then
            return nil, "Invalid Sandbreak panel identity"
        end
        local variants, reason = SandbreakReconstruction.panelVariants(bank, panel)
        if not variants then
            return nil, reason
        end
        ids[panel.Name] = true
    end

    local replacement = source:Clone()
    local replacementPanels = assert(replacement:FindFirstChild("SpawnShelterPanels"))
    configureThermal(replacement)
    for _, panel in replacementPanels:GetChildren() do
        assert(panel:IsA("Model"), "validated Sandbreak panel changed")
        -- The panel folder moves out of the assembly for the map registry.
        -- Scope each stable identity so replacement damage meshes inherit it.
        configureThermal(panel)
    end
    replacement:PivotTo(CFrame.new(0, 0, 120))
    original.Parent = nil
    replacement.Parent = map
    replacementPanels.Parent = map
    local finished = false
    return {
        commit = function()
            if not finished then
                finished = true
                original:Destroy()
            end
        end,
        rollback = function()
            if not finished then
                finished = true
                replacementPanels:Destroy()
                replacement:Destroy()
                original.Parent = map
            end
        end,
    },
        nil
end

return SandbreakReconstruction
