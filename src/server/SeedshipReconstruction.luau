--!strict
--[=[
    Mounts the approved native Prism Seedship before the map snapshot.
    The local deck datum is one spec unit per stud. The half-turn points the
    front threshold toward Sandbreak. The shared destruction owner handles
    all registered hull panels. No player, network or clock dependencies.
]=]
local VesperPanelGeometry = require(script.Parent.VesperPanelGeometry)
local SeedshipReconstruction = {}

export type Installation = { commit: () -> (), rollback: () -> () }
local sourceHash = "460918e405c1f1eae99aaf689a9d58892b533d539db3855bd5808edb0265a7ec"
local site = CFrame.new(0, 2.4, 259) * CFrame.Angles(0, math.pi, 0)
local function unchanged() end

-- The importer supplies the diagnostic atlas as SurfaceAppearance. In Studio
-- the same image is visible on this two-triangle readout through TextureID.
-- Preserve the baked UVs and move the graphic clear of the terminal face.
local function prepareRecoveryBay(ship: Model)
    local display = ship:FindFirstChild("PS_A6_174_05", true)
    assert(display and display:IsA("MeshPart"), "missing approved Seedship readout")
    local surface = display:FindFirstChildWhichIsA("SurfaceAppearance")
    if surface then
        surface:Destroy()
    end
    display.TextureID = "rbxassetid://135660905134253"
    display.Material = Enum.Material.SmoothPlastic
    display.Position += Vector3.new(-0.073, 0.012, 0.0126)
    local anchor = Instance.new("Part")
    anchor.Name = "PrismRecoveryLampAnchor"
    anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
    anchor.Transparency, anchor.CastShadow = 1, false
    anchor.Size = Vector3.one * 0.1
    anchor.Position = Vector3.new(54.8, 8.4, -12.5)
    local lamp = Instance.new("PointLight")
    lamp.Name = "PrismRecoveryLamp"
    lamp.Color = Color3.fromRGB(189, 231, 226)
    lamp.Range, lamp.Brightness = 13, 1.65
    lamp.Parent, anchor.Parent = anchor, ship
end

-- The visible floor is split by material, leaving open sides on each imported
-- piece. Discrete solids follow the authored deck outlines and preserve the
-- concave stairwells. In each horizontal strip the intersections are paired
-- in winding-independent order. Render meshes never own the floor contacts.
local function addDeckSolids(ship: Model)
    local frame = assert(ship:FindFirstChild("PrismStable"))
    for _, part in frame:GetChildren() do
        if part:IsA("MeshPart") then
            local role = part:GetAttribute("SeedshipRole")
            if role == "WalkableFloor" or role == "WalkableGallery" then
                part.CanCollide, part.CanQuery = false, false
            end
        end
    end
    local function deck(
        name: string,
        outline: { Vector2 },
        minZ: number,
        maxZ: number,
        top: number,
        thickness: number
    )
        local step = 2
        for startZ = minZ, maxZ - 0.001, step do
            local endZ = math.min(startZ + step, maxZ)
            local middle = (startZ + endZ) / 2
            local crossings: { number } = {}
            for index, a in outline do
                local b = outline[index % #outline + 1]
                if (a.Y > middle) ~= (b.Y > middle) then
                    table.insert(crossings, a.X + (b.X - a.X) * (middle - a.Y) / (b.Y - a.Y))
                end
            end
            table.sort(crossings)
            for index = 1, #crossings, 2 do
                local left, right = crossings[index], crossings[index + 1]
                local solid = Instance.new("Part")
                solid.Name = string.format("Prism%sStrip%03d_%d", name, startZ - minZ, index)
                solid.Position = Vector3.new((left + right) / 2, top - thickness / 2, middle)
                solid.Size = Vector3.new(right - left, thickness, endZ - startZ)
                solid.Anchored, solid.CanTouch, solid.CastShadow, solid.Transparency = true, false, false, 1
                solid.Parent = frame
            end
        end
    end
    local v = Vector2.new
    local half = {
        v(0, 60),
        v(15, 60),
        v(23, 60),
        v(48, 55),
        v(77, 49),
        v(90, 34),
        v(102, 22),
        v(99, 12.8),
        v(99, -12.8),
        v(102, -24),
        v(88, -43),
        v(73, -57),
        v(39, -64),
        v(0, -71.432),
    }
    local ground = table.clone(half)
    for index = #half - 1, 2, -1 do
        table.insert(ground, v(-half[index].X, half[index].Y))
    end
    deck("Ground", ground, -71.432, 60, 0, 2.38)
    local gallery = {
        v(51, 15),
        v(61, 15),
        v(61, 39),
        v(64, 39),
        v(73, 25),
        v(77, 9),
        v(77, -13),
        v(66, -32),
        v(54, -40),
        v(42, -40),
        v(42, 15),
    }
    local opposite: { Vector2 } = {}
    for _, point in gallery do
        table.insert(opposite, v(-point.X, point.Y))
    end
    deck("StarboardDeck", gallery, -40, 39, 16, 1.4)
    deck("PortDeck", opposite, -40, 39, 16, 1.4)
    deck("Crossover", { v(-42, -40), v(42, -40), v(42, -25), v(-42, -25) }, -40, -25, 16, 1.4)
end

-- Returns the panel's two native templates for the shared damage owner.
-- Total is represented by an empty panel; its identity and pivot survive.
function SeedshipReconstruction.panelVariants(
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
    then
        return nil, "missing aligned Seedship state for " .. panel.Name
    end
    local function query(model: Model): MeshPart?
        local proxy: MeshPart? = nil
        for _, child in model:GetChildren() do
            if
                not child:IsA("MeshPart")
                or not child.Anchored
                or child.CanTouch
                or child:GetAttribute("NativeMeshId") ~= child.MeshId
                or child:GetAttribute("NativeMeshSize") ~= child.MeshSize
                or child.MeshSize.Magnitude <= 0
            then
                return nil
            end
            if child:GetAttribute("PanelProxy") == true then
                if
                    proxy
                    or child.CollisionFidelity ~= Enum.CollisionFidelity.PreciseConvexDecomposition
                    or child.Transparency ~= 1
                    or not child.CanQuery
                    or not child.CanCollide
                then
                    return nil
                end
                proxy = child
            elseif child.CanQuery or child.CanCollide then
                return nil
            end
        end
        return if #model:GetChildren() > 1 then proxy else nil
    end
    local intact = query(panel)
    local lightProxy = query(light)
    local heavyProxy = query(heavy)
    if
        not intact
        or not lightProxy
        or not heavyProxy
        or lightProxy.MeshId ~= intact.MeshId
        or lightProxy.Size ~= intact.Size
        or (panel:GetPivot():PointToObjectSpace(intact.Position) - lightProxy.Position).Magnitude > 0.01
    then
        return nil, "invalid Seedship panel collision for " .. panel.Name
    end
    local fragmentBank = if bank then bank:FindFirstChild("PrismFragments") else nil
    if not fragmentBank then
        return nil, "missing Seedship fragments"
    end
    local fragments: { MeshPart } = {}
    for _, child in fragmentBank:GetChildren() do
        if child:IsA("MeshPart") and not child.CanQuery and not child.CanCollide then
            table.insert(fragments, child)
        end
    end
    if #fragments ~= 8 then
        return nil, "incomplete Seedship fragments"
    end
    return { light = light, heavy = heavy, fragments = fragments }, nil
end

-- Validates the managed roots before exposing them to MapService. The hull
-- panel folder is a direct level child so the other landmark layouts stay
-- independently validated. rollback removes both roots and their registration.
function SeedshipReconstruction.install(world: Instance, assets: Instance): (Installation?, string?)
    local source = assets:FindFirstChild("PrismSeedship")
    local bank = assets:FindFirstChild("PrismPanelVariants")
    local map = world:FindFirstChild("Battlefield")
    local registrations = if map then map:FindFirstChild("PanelRegistries") else nil
    if
        not source
        or not source:IsA("Model")
        or not bank
        or not bank:IsA("Folder")
        or not map
        or not registrations
    then
        return nil, "missing managed Seedship, damage bank, or level registration"
    end
    local binding = source:GetAttribute("ImportBinding")
    local panels = source:FindFirstChild("PrismPanels")
    local display = source:FindFirstChild("PS_A6_174_05", true)
    if
        type(binding) ~= "string"
        or #binding ~= 64
        or bank:GetAttribute("ImportBinding") ~= binding
        or source:GetAttribute("BlendSha256") ~= sourceHash
        or source:GetPivot() ~= CFrame.identity
        or not panels
        or not panels:IsA("Folder")
        or #panels:GetChildren() ~= 102
        or #bank:GetChildren() ~= 103
        or not display
        or not display:IsA("MeshPart")
    then
        return nil, "incomplete or invalid Seedship source binding"
    end
    local installed = map:FindFirstChild("PrismSeedshipHull")
    if
        installed
        and installed:GetAttribute("ImportBinding") == binding
        and registrations:FindFirstChild("PrismSeedship")
        and map:FindFirstChild("PrismPanels")
    then
        return { commit = unchanged, rollback = unchanged }, nil
    end
    if installed or registrations:FindFirstChild("PrismSeedship") or map:FindFirstChild("PrismPanels") then
        return nil, "conflicting Seedship location or registry"
    end
    for _, panel in panels:GetChildren() do
        if
            not panel:IsA("Model")
            or panel:GetAttribute("PanelId") ~= panel.Name
            or panel:GetAttribute("SeedshipPanel") ~= true
            or (panel:GetAttribute("StoryId") ~= "01" and panel:GetAttribute("StoryId") ~= "02")
        then
            return nil, "invalid Seedship panel identity"
        end
        local valid, reason = SeedshipReconstruction.panelVariants(bank, panel)
        if not valid then
            return nil, reason
        end
    end
    local ship = source:Clone()
    ship.Name = "PrismSeedshipHull"
    addDeckSolids(ship)
    prepareRecoveryBay(ship)
    ship:PivotTo(site)
    local placedPanels = ship:FindFirstChild("PrismPanels") :: Folder
    for _, panel in placedPanels:GetChildren() do
        local template = panels:FindFirstChild(panel.Name)
        assert(panel:IsA("Model") and template and template:IsA("Model"), "validated panel changed")
        panel.WorldPivot = site * template:GetPivot()
    end
    placedPanels:SetAttribute("ThermalBrightness", 0.63)
    local descriptor = Instance.new("StringValue")
    descriptor.Name, descriptor.Value = "PrismSeedship", placedPanels.Name
    descriptor:SetAttribute("UseAuthoredStories", true)
    ship.Parent, placedPanels.Parent, descriptor.Parent = map, map, registrations
    local pending = true
    return {
        commit = function()
            pending = false
        end,
        rollback = function()
            if pending then
                pending = false
                ship:Destroy()
                placedPanels:Destroy()
                descriptor:Destroy()
            end
        end,
    },
        nil
end

return SeedshipReconstruction
