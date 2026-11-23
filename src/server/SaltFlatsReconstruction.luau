--!strict
--[=[
    SaltFlatsReconstruction installs the approved Foundry replacement before
    the map owner captures its reset snapshot. It binds Studio-exported native
    art, aligned panel states, and the separately destructible wreck. Geometry
    uses Roblox studs and has no client, clock, or network dependencies.
]=]
local VesperPanelGeometry = require(script.Parent.VesperPanelGeometry)
local SaltFlatsReconstruction = {}

export type Installation = { commit: () -> (), rollback: () -> () }

local sourceHash = "a708a8720e9d6f8517442dcaa92e489b3c8b48c9d46f2fb12345f90730468a57"
local site = CFrame.new(-211, 0.125, -116) * CFrame.Angles(0, math.rad(60), 0)
local hillLocations: { [string]: Vector3 } = {
    TerrainHill00 = Vector3.new(-99, -36, 180),
    TerrainHill07 = Vector3.new(-284, -32, 25),
}

local function unchanged() end

local function validMesh(part: MeshPart): boolean
    -- Studio preserves a zero intrinsic dimension for legitimately planar
    -- decals and cladding details. These are visual-only assets and their
    -- assigned Size is still finite and positive in all dimensions.
    return string.match(part.MeshId, "^rbxassetid://[1-9]%d*$") ~= nil
        and part:GetAttribute("NativeMeshId") == part.MeshId
        and part:GetAttribute("NativeMeshSize") == part.MeshSize
        and part:GetAttribute("NativeCollisionFidelity") == part.CollisionFidelity.Name
        and part:GetAttribute("NativeRenderFidelity") == part.RenderFidelity.Name
        and part.MeshSize.Magnitude > 0
        and part.MeshSize.Magnitude < 400
        and not part.CanQuery
        and not part.CanCollide
end

local function verifyParts(root: Instance): boolean
    for _, item in root:GetDescendants() do
        if item:IsA("BasePart") then
            if
                not item.Archivable
                or not item.Anchored
                or item.CanTouch
                or item.CanQuery ~= item.CanCollide
            then
                return false
            end
            if item:IsA("MeshPart") then
                if not validMesh(item) then
                    return false
                end
            elseif not item:IsA("Part") or not item.CanQuery or item.Transparency ~= 1 then
                return false
            end
        elseif not item:IsA("Folder") and not item:IsA("Model") and not item:IsA("SurfaceAppearance") then
            return false
        end
    end
    return true
end

-- Fetches the aligned state templates for the shared native panel presenter.
-- The bank was validated before exposing the replacement to MapService.
function SaltFlatsReconstruction.panelVariants(
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
        or #light:GetChildren() == 0
        or #heavy:GetChildren() == 0
    then
        return nil, "invalid Salt Flats variant bank for " .. panel.Name
    end
    return { light = light, heavy = heavy, fragments = nil }, nil
end

-- The rectilinear frame uses explicit solids. The original fine-detail mesh
-- stays visual-only, so mullions and open trusses do not acquire hull collision.
local function addStableCover(root: Model)
    local structure = assert(root:FindFirstChild("Foundry_Static"))
    local function solid(name: string, center: Vector3, size: Vector3, angle: number?)
        local part = Instance.new("Part")
        part.Name = "SaltFlats_" .. name
        part.Anchored = true
        part.Transparency = 1
        part.CastShadow = false
        part.CanTouch = false
        part.Size = size
        part.CFrame = CFrame.new(center) * CFrame.Angles(0, math.rad(angle or 0), 0)
        part.Parent = structure
    end
    for index, x in { -104, 0, 104 } do
        solid("PortalPier" .. index, Vector3.new(x, 24, 72), Vector3.new(2.5, 48, 3))
    end
    for _, sign in { -1, 1 } do
        for index = 1, 5 do
            solid(
                string.format("SidePier%d_%d", sign, index),
                Vector3.new(103.5 * sign, 24, 72 - 24 * index),
                Vector3.new(1.38, 48, 1.55)
            )
        end
        solid("Lintel" .. sign, Vector3.new(52 * sign, 46.8, 72), Vector3.new(102.6, 2.45, 1.8))
        solid("RearLintel" .. sign, Vector3.new(52 * sign, 46.8, -72), Vector3.new(102.6, 2.45, 1.8))
        solid(
            "FighterBody" .. sign,
            Vector3.new(52 * sign, 7.8, -2),
            Vector3.new(5.5, 3.1, 51),
            if sign < 0 then 3 else -4
        )
        solid(
            "FighterWing" .. sign,
            Vector3.new(52 * sign, 9, -13),
            Vector3.new(43, 1, 7),
            if sign < 0 then 3 else -4
        )
    end
    for floor = 1, 3 do
        for index, y in { 1.65, 3.5 } do
            solid(
                string.format("GalleryRail%d_%d", floor, index),
                Vector3.new(0, floor * 12 + y, -57.25),
                Vector3.new(164, 0.25, 0.26)
            )
        end
    end
end

-- Validates both managed roots and all affected references before mutation.
-- rollback restores the greybox and the original terrain/aim descriptors.
-- Reinstalling the same package preserves the current round generation.
function SaltFlatsReconstruction.install(world: Instance, assets: Instance): (Installation?, string?)
    local source = assets:FindFirstChild("SaltFlatsHangar")
    local bank = assets:FindFirstChild("SaltFlatsPanelVariants")
    if not source or not source:IsA("Model") or not bank or not bank:IsA("Folder") then
        return nil, "missing managed Salt Flats assembly or panel bank"
    end
    local binding = source:GetAttribute("ImportBinding")
    if
        type(binding) ~= "string"
        or #binding ~= 64
        or not string.match(binding, "^[a-f0-9]+$")
        or source:GetAttribute("BlendSha256") ~= sourceHash
        or bank:GetAttribute("ImportBinding") ~= binding
        or source:GetAttribute("PanelLayoutVersion") ~= 4
        or source:GetPivot() ~= CFrame.identity
    then
        return nil, "invalid Salt Flats source binding"
    end
    local map = world:FindFirstChild("Battlefield")
    local buildings = if map then map:FindFirstChild("Buildings") else nil
    local original = if buildings then buildings:FindFirstChild("Foundry") else nil
    local terrain = if map then map:FindFirstChild("TerrainRecipe") else nil
    local envelope = if map then map:FindFirstChild("AimEnvelope") else nil
    local aimHeight = if envelope then envelope:FindFirstChild("MaximumY") else nil
    if
        not buildings
        or not original
        or not original:IsA("Model")
        or not terrain
        or not aimHeight
        or not aimHeight:IsA("NumberValue")
    then
        return nil, "missing Foundry replacement site or level settings"
    end
    if original:GetAttribute("ImportBinding") == binding then
        return { commit = unchanged, rollback = unchanged }, nil
    end
    local originalFloor = original:FindFirstChild("Foundry_GroundFloor", true)
    local panels = source:FindFirstChild("Foundry_Panels")
    local wreck = source:FindFirstChild("HerculesWreck")
    if
        not originalFloor
        or not originalFloor:IsA("BasePart")
        or originalFloor.Position ~= Vector3.new(-168, -0.375, -104)
        or not panels
        or not panels:IsA("Folder")
        or #panels:GetChildren() ~= 152
        or not wreck
        or not wreck:IsA("Model")
        or wreck:GetAttribute("DestructibleWreck") ~= true
        or #bank:GetChildren() ~= 152
        or not verifyParts(source)
        or not verifyParts(bank)
    then
        return nil, "invalid Foundry position or incomplete Salt Flats native content"
    end
    for _, panel in panels:GetChildren() do
        if not panel:IsA("Model") or panel:GetAttribute("SaltFlatsPanel") ~= true then
            return nil, "invalid Salt Flats panel identity"
        end
        local valid, reason = SaltFlatsReconstruction.panelVariants(bank, panel)
        if not valid then
            return nil, reason
        end
    end
    local hills: { [BasePart]: Vector3 } = {}
    for name in hillLocations do
        local hill = terrain:FindFirstChild(name)
        if not hill or not hill:IsA("BasePart") then
            return nil, "missing Salt Flats terrain descriptor " .. name
        end
        hills[hill] = hill.Position
    end
    local replacement = source:Clone()
    replacement.Name = "Foundry"
    replacement:SetAttribute("ThermalBrightness", 0.66)
    replacement:SetAttribute("ThermalSurfacePalette", "SaltFlatsThermalSurfaces")
    for _, item in replacement:GetDescendants() do
        if item:IsA("MeshPart") and item:GetAttribute("SaltFlatsRole") == "dressing" then
            item:SetAttribute("ThermalNonCover", true)
        end
    end
    addStableCover(replacement)
    replacement:PivotTo(site)
    local installedWreck = replacement:FindFirstChild("HerculesWreck")
    assert(installedWreck and installedWreck:IsA("Model"), "validated wreck changed")
    installedWreck.WorldPivot = site * CFrame.new(-108, 10, 135)
    local replacementPanels = assert(replacement:FindFirstChild("Foundry_Panels"))
    for _, panel in replacementPanels:GetChildren() do
        local template = panels:FindFirstChild(panel.Name)
        assert(panel:IsA("Model") and template and template:IsA("Model"), "validated panel changed")
        panel.WorldPivot = site * template:GetPivot()
    end
    local previousAimHeight = aimHeight.Value
    for hill in hills do
        hill.Position = hillLocations[hill.Name]
    end
    aimHeight.Value = 64
    original.Parent = nil
    replacement.Parent = buildings
    local pending = true
    return {
        commit = function()
            if pending then
                pending = false
                original:Destroy()
            end
        end,
        rollback = function()
            if pending then
                pending = false
                replacement:Destroy()
                original.Parent = buildings
                aimHeight.Value = previousAimHeight
                for hill, location in hills do
                    hill.Position = location
                end
            end
        end,
    },
        nil
end

return SaltFlatsReconstruction
