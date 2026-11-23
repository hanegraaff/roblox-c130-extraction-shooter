--!strict
--[=[
    VesperReconstruction: installs the source-managed native warehouse assembly
    at the canonical site before MapService takes its reset snapshot. Uses
    approved studio-exported payloads and the Vesper panel bank. Nonyielding.
    Receipt metadata comes from source; it does not prove cloud availability.
]=]
local Rules = require(script.Parent.PanelAssetRules)
local PanelGeometry = require(script.Parent.VesperPanelGeometry)
local AssetMesh = require(game:GetService("ReplicatedStorage").Shared.AssetMesh)

local VesperReconstruction = {}

export type Installation = {
    commit: () -> (),
    rollback: () -> (),
}

local sourceHash = "f114c37ec45febbc6a2c91e18aecfac28d59bcacc836e6577709bce176b534b7"
local site = CFrame.new(160, 0.125, -80)
local function unchanged()
    return
end

-- Both native roots must validate before any world replacement. Repeated
-- installation recognizes the same receipt and retains the current generation.
function VesperReconstruction.install(world: Instance, assets: Instance): (Installation?, string?)
    local source = assets:FindFirstChild("VesperArray")
    local bank = assets:FindFirstChild("VesperPanelVariants")
    if not source or not source:IsA("Model") or not bank or not bank:IsA("Folder") then
        return nil, "incomplete managed Vesper assets"
    end
    local receipt = source:GetAttribute("ImportReceiptSha256")
    if
        not Rules.receipt(receipt)
        or bank:GetAttribute("ImportReceiptSha256") ~= receipt
        or source:GetAttribute("BlendSha256") ~= sourceHash
        or source:GetPivot() ~= CFrame.identity
        or source:GetAttribute("PanelLayoutVersion") ~= 3
    then
        return nil, "invalid Vesper import provenance or geometry origin"
    end
    local map = world:FindFirstChild("Battlefield")
    local buildings = if map then map:FindFirstChild("Buildings") else nil
    local original = if buildings then buildings:FindFirstChild("Warehouse") else nil
    if not buildings or not original or not original:IsA("Model") or #buildings:GetChildren() ~= 3 then
        return nil, "missing Warehouse replacement site"
    end
    if original:GetAttribute("ImportReceiptSha256") == receipt then
        return { commit = unchanged, rollback = unchanged }, nil
    end
    local originalFloor = original:FindFirstChild("Warehouse_GroundFloor", true)
    if
        not originalFloor
        or not originalFloor:IsA("BasePart")
        or originalFloor.Position + Vector3.new(0, originalFloor.Size.Y / 2, 0) ~= site.Position
        or originalFloor.Size.X ~= 64
        or originalFloor.Size.Z ~= 48
    then
        return nil, "Warehouse site moved or changed footprint"
    end
    local panels = source:FindFirstChild("Warehouse_Panels")
    if not panels or not panels:IsA("Folder") or #panels:GetChildren() ~= 54 then
        return nil, "missing Vesper panel registry"
    end
    local names: { [string]: boolean } = {}
    for _, item in source:GetDescendants() do
        if names[item.Name] or not item.Archivable then
            return nil, "duplicate or unclonable Vesper assembly object: " .. item.Name
        end
        names[item.Name] = true
        if item:IsA("BasePart") then
            if
                not item.Anchored
                or item.CanTouch
                or not Rules.geometry(
                    { item.Size.X, item.Size.Y, item.Size.Z },
                    { item.CFrame:GetComponents() },
                    { 36, 33, 28 },
                    64
                )
                or (item:IsA("MeshPart") and not AssetMesh.validate(item, true))
            then
                return nil, "invalid native Vesper assembly object: " .. item.Name
            end
        elseif not item:IsA("Model") and not item:IsA("Folder") and not item:IsA("SurfaceAppearance") then
            return nil, "unexpected Vesper assembly content: " .. item.ClassName
        end
    end
    for _, panel in panels:GetChildren() do
        if not panel:IsA("Model") or panel:GetAttribute("VesperPanel") ~= true then
            return nil, "invalid Vesper panel identity"
        end
        local variants, reason = PanelGeometry.load(bank, panel)
        if not variants then
            return nil, reason
        end
    end
    local replacement = source:Clone()
    replacement.Name = "Warehouse"
    replacement:PivotTo(site)
    local replacementPanels = assert(replacement:FindFirstChild("Warehouse_Panels"))
    for _, panel in replacementPanels:GetChildren() do
        local localPanel = panels:FindFirstChild(panel.Name)
        assert(
            panel:IsA("Model") and localPanel and localPanel:IsA("Model"),
            "validated Vesper identity changed"
        )
        panel.WorldPivot = site * localPanel:GetPivot()
        for _, piece in panel:GetChildren() do
            if piece:GetAttribute("PanelProxy") == true then
                piece:SetAttribute("PanelId", panel.Name)
            end
        end
    end
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
            end
        end,
    },
        nil
end

return VesperReconstruction
