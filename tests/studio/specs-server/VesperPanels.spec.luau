--!strict
-- Exercises the Vesper adapter with borrowed native payloads and exact fixture
-- solids. Imported radar geometry and real co-op acceptance are separate.
local Server = game.ServerScriptService.Server
local Imported = require(Server.VesperPanelGeometry)
local Geometry = require(Server.PanelGeometry)
local Reconstruction = require(Server.VesperReconstruction)
local Assets = game.ServerStorage.Assets

local function visual(source: MeshPart, model: Model, suffix: string)
    local part = source:Clone()
    part:ClearAllChildren()
    part.Name = "Visible" .. suffix
    part.Size = Vector3.new(6, 5, 1)
    part.CFrame = model:GetPivot()
    part.Parent = model
end

local function proxy(model: Model, name: string, x: number, width: number): Part
    local part = Instance.new("Part")
    part.Name = name
    part.Size = Vector3.new(width, 5, 1)
    part.CFrame = model:GetPivot() * CFrame.new(x, 0, 0)
    part.Anchored = true
    part.CanTouch = false
    part.Transparency = 1
    part:SetAttribute("PanelProxy", true)
    part.Parent = model
    return part
end

return function()
    local test = getfenv().it :: (string, () -> ()) -> ()
    test("Vesper authored states keep one identity and remove only owned collision", function()
        local root = Instance.new("Folder")
        local bank = Instance.new("Folder")
        bank.Parent = root
        local panel = Instance.new("Model")
        panel.Name = "Warehouse_S01_Radar_Wall_S1"
        local pivot = CFrame.new(3, 7, 10) * CFrame.Angles(0, math.pi / 4, 0)
        panel.WorldPivot = pivot
        panel:SetAttribute("IntactSize", Vector3.new(6, 5, 1))
        panel.Parent = root

        local ok, failure = pcall(function()
            local material = assert(Assets:FindFirstChild("MaterialPanels"))
            local fragments: Folder? = nil
            for _, family in material:GetChildren() do
                local candidate = family:FindFirstChild("Fragments")
                if candidate and candidate:IsA("Folder") then
                    fragments = candidate
                    break
                end
            end
            assert(fragments, "missing genuine native fixture")
            local bankFragments = fragments:Clone()
            bankFragments.Name = "WallFragments"
            bankFragments.Parent = bank
            local native = bankFragments:FindFirstChild("1")
            assert(native and native:IsA("MeshPart"), "missing genuine native fixture part")

            local states = Instance.new("Folder")
            states.Name = panel.Name
            states.Parent = bank
            local light = Instance.new("Model")
            light.Name = "Light"
            light.WorldPivot = CFrame.identity
            light.Parent = states
            local heavy = Instance.new("Model")
            heavy.Name = "Heavy"
            heavy.WorldPivot = CFrame.identity
            heavy.Parent = states
            visual(native, panel, "Pristine")
            visual(native, light, "Light")
            visual(native, heavy, "Heavy")
            proxy(panel, "Intact", 0, 6)
            local lightProxy = proxy(light, "Intact", 0, 5)
            proxy(heavy, "HeavyLeft", -2.25, 1.5)
            proxy(heavy, "HeavyRight", 2.25, 1.5)

            assert(not Imported.load(bank, panel), "Light removed part of the intact cover")
            lightProxy.Size = Vector3.new(6, 5, 1)
            local variants, reason = Imported.load(bank, panel)
            assert(variants, reason)
            local state = Geometry.capture(panel, nil, variants)
            local exercised, errorMessage = pcall(function()
                Geometry.publish(state, 0, 0.5, 0.5, 0, "Light")
                local intact = panel:FindFirstChild("Intact")
                assert(
                    intact and intact:IsA("Part") and intact:GetAttribute("PanelId") == panel.Name,
                    "Light proxy lost identity"
                )
                assert((intact.Position - pivot.Position).Magnitude < 0.001, "Light proxy moved")
                Geometry.setStage(state, 1)
                assert(not panel:FindFirstChild("Intact"), "Heavy retained the intact cover")
                assert(
                    panel:FindFirstChild("HeavyLeft") and panel:FindFirstChild("HeavyRight"),
                    "Heavy residuals missing"
                )
                Geometry.setStage(state, 2)
                assert(
                    #panel:GetChildren() == 0 and panel:GetPivot() == pivot,
                    "Total changed identity or retained geometry"
                )
                Geometry.setStage(state, 0)
                assert(
                    panel:FindFirstChild("Intact") and panel:FindFirstChild("VisiblePristine"),
                    "restored pristine geometry missing"
                )
            end)
            state.original:Destroy()
            assert(exercised, errorMessage)
        end)
        root:Destroy()
        assert(ok, failure)
    end)
    test("Vesper reconstruction rejects an incomplete import before mutating the world", function()
        local world = Instance.new("Folder")
        local assets = Instance.new("Folder")
        local assembly = Instance.new("Model")
        assembly.Name = "VesperArray"
        assembly.Parent = assets
        local result, reason = Reconstruction.install(world, assets)
        world:Destroy()
        assets:Destroy()
        assert(
            result == nil and reason == "incomplete managed Vesper assets",
            "incomplete import was accepted"
        )
    end)
end
