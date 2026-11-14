--!strict
-- P17 preparation fixtures exercise actual Instances/shared geometry and cleanup.
-- Empty test-only MeshParts are inert stand-ins for imported cosmetic references;
-- these cases do NOT prove approved art, cloud access, navigation or multiplayer.
local Server = game:GetService("ServerScriptService").Server
local Approved = require(Server.ApprovedOutpost)
local Catalog = require(Server.PanelAssetCatalog)
local MaterialGeometry = require(Server.MaterialPanelGeometry)
local Geometry = require(Server.PanelGeometry)
local Rules = require(Server.PanelDamageRules)
local DestructionRuntime = require(Server.DestructionRuntime)
local BuildingGeometry = require(Server.BuildingGeometry)
local Fragments = require(Server.PanelFragments)
local PhysicsService = game:GetService("PhysicsService")

local function familyFixture(id: string): Catalog.Family
    local definition = Approved.families[id]
    local states: { [string]: Catalog.Variant } = {}
    for name, state in definition.states do
        local model = Instance.new("Model")
        model.Name = name
        model.WorldPivot = CFrame.identity
        if name ~= "Total" then
            local cosmetic = Instance.new("MeshPart")
            cosmetic.Name = "TestOnlyEmptyCosmetic"
            cosmetic.Size = Vector3.new(1, 1, 0.1)
            cosmetic.Anchored = true
            cosmetic.CanCollide = false
            cosmetic.CanQuery = false
            cosmetic.CanTouch = false
            cosmetic.Parent = model
        end
        states[name] = { template = model, rectangles = state.rectangles }
    end
    return {
        id = id,
        size = Vector3.new(definition.size[1], definition.size[3], definition.size[2]),
        states = states,
        fragments = {},
    }
end
local function destroyFamily(family: Catalog.Family)
    for _, state in family.states do
        state.template:Destroy()
    end
    for _, fragment in family.fragments do
        fragment:Destroy()
    end
end

return function()
    local test = getfenv().it :: (string, () -> ()) -> ()
    require(game.ServerStorage.Tests.Unit["PanelAssetRules.spec"])(test, require(Server.PanelAssetRules))
    test("P17AssetCatalog missing imports and duplicate registry IDs reject before mutation", function()
        assert(Catalog.load(nil) == nil, "P17 assertion: Catalog.load(nil) == nil")
        local metadata = Instance.new("Folder")
        metadata:SetAttribute("AssetRevision", Approved.revision)
        metadata:SetAttribute("BlendSha256", Approved.blendSha256)
        metadata:SetAttribute("ImportReceiptSha256", string.rep("g", 64))
        assert(Catalog.load(metadata) == nil, "P17 assertion: Catalog.load(metadata) == nil")
        metadata:Destroy()
        local world = Instance.new("Folder")
        local map = workspace.World.Battlefield:Clone()
        map.Parent = world
        BuildingGeometry.decorate(map)
        local registries = BuildingGeometry.registries(map)
        assert(registries, "P17 assertion: registries")
        local first = registries[1].panels:GetChildren()[1]
        local duplicate = first:Clone()
        duplicate.Parent = registries[1].panels
        local before = #world:GetDescendants()
        local previousGroup = PhysicsService:IsCollisionGroupRegistered("PanelFragments")
        local owner, reason = DestructionRuntime.start(world)
        assert(
            owner == nil and reason == "invalid/duplicate registered panel identity",
            'P17 assertion: owner == nil and reason == "invalid/duplicate registered panel identity"'
        )
        assert(#world:GetDescendants() == before, "invalid registry mutated world")
        assert(
            PhysicsService:IsCollisionGroupRegistered("PanelFragments") == previousGroup,
            'P17 assertion: PhysicsService:IsCollisionGroupRegistered("PanelFragments") == previousGroup'
        )
        world:Destroy()
    end)
    test(
        "P17MaterialPanelStates shared thresholds retain catalog proxies across persistent Light Heavy Total",
        function()
            for id in Approved.families do
                local family = familyFixture(id)
                local model = Instance.new("Model")
                model.Name = "Fixture_" .. id
                model:SetAttribute("IntactSize", family.size)
                model:SetAttribute("PanelAssetFamily", id)
                model:SetAttribute("PanelId", model.Name)
                MaterialGeometry.install(model, CFrame.new(2000, 80, 2000), family, "Pristine")
                local panel = Geometry.capture(model, family)
                local ok, failure = pcall(function()
                    assert(
                        MaterialGeometry.validate(model, family),
                        "P17 assertion: MaterialGeometry.validate(model, family)"
                    )
                    local damage = Rules.new()
                    for hit = 1, 6 do
                        Rules.apply(damage, true, 0)
                        Geometry.setStage(panel, damage.stage)
                        Geometry.publish(
                            panel,
                            damage.stage,
                            Rules.progress(damage),
                            damage.heavySeconds,
                            damage.sustainedSeconds,
                            Rules.appearance(damage)
                        )
                        assert(
                            model:GetAttribute("DamageAppearance")
                                == (if hit < 3 then "Light" elseif hit < 6 then "Heavy" else "Total"),
                            'P17 assertion: model:GetAttribute("DamageAppearance") == (if hit < 3 then "Light" elseif hit < 6 then "Heavy" else "Total")'
                        )
                        local solids = 0
                        for _, item in model:GetChildren() do
                            if item:IsA("BasePart") and item.CanCollide and item.CanQuery then
                                solids += 1
                                assert(
                                    item:GetAttribute("PanelId") == model.Name,
                                    'P17 assertion: item:GetAttribute("PanelId") == model.Name'
                                )
                            end
                        end
                        local expected = family.states[Rules.appearance(damage)].rectangles
                        assert(solids == #expected, "catalog proxy set differs from authoritative appearance")
                    end
                    assert(#model:GetChildren() == 0, "Total retained geometry")
                    Geometry.setStage(panel, 0)
                    Geometry.publish(panel, 0, 0, 0, 0, "Pristine")
                    assert(
                        MaterialGeometry.validate(model, family),
                        "reset did not restore exact pristine proxies"
                    )
                    local phantom = Instance.new("Part")
                    phantom.Size = family.size
                    phantom.Anchored = true
                    phantom.Parent = model
                    local before = #model:GetDescendants()
                    assert(
                        not MaterialGeometry.validate(model, family),
                        "phantom full panel collider accepted"
                    )
                    assert(#model:GetDescendants() == before, "rejection mutated geometry")
                end)
                panel.original:Destroy()
                model:Destroy()
                destroyFamily(family)
                assert(ok, failure)
            end
        end
    )
    test(
        "P17OutpostOpenings catalog proxies expose actual Heavy and Total rays with residual solidity",
        function()
            for id in Approved.families do
                local family = familyFixture(id)
                local model = Instance.new("Model")
                model.Name = "RayFixture_" .. id
                local pivot = CFrame.new(2000, 80, 2000)
                    * (if id == "layered_roof" then CFrame.Angles(math.pi / 2, 0, 0) else CFrame.identity)
                MaterialGeometry.install(model, pivot, family, "Heavy")
                model.Parent = workspace
                local ok, failure = pcall(function()
                    local rays = RaycastParams.new()
                    rays.FilterType = Enum.RaycastFilterType.Include
                    rays.FilterDescendantsInstances = { model }
                    rays.RespectCanCollide = true
                    task.wait(0.1)
                    local direction = pivot:VectorToWorldSpace(Vector3.new(0, 0, 8))
                    assert(
                        workspace:Raycast(pivot:PointToWorldSpace(Vector3.new(0, 0, -4)), direction, rays)
                            == nil,
                        "P17 assertion: workspace:Raycast(pivot:PointToWorldSpace(Vector3.new(0, 0, -4)), direction, rays) == nil"
                    )
                    assert(
                        workspace:Raycast(pivot:PointToWorldSpace(Vector3.new(7, 0, -4)), direction, rays)
                            ~= nil,
                        "P17 assertion: workspace:Raycast(pivot:PointToWorldSpace(Vector3.new(7, 0, -4)), direction, rays) ~= nil"
                    )
                    MaterialGeometry.install(model, pivot, family, "Total")
                    task.wait(0.1)
                    assert(
                        workspace:Raycast(pivot:PointToWorldSpace(Vector3.new(7, 0, -4)), direction, rays)
                            == nil,
                        "P17 assertion: workspace:Raycast(pivot:PointToWorldSpace(Vector3.new(7, 0, -4)), direction, rays) == nil"
                    )
                end)
                model:Destroy()
                destroyFamily(family)
                assert(ok, failure)
            end
        end
    )
    test(
        "P17MaterialFragments template clones obey bounded ownership expiry and idempotent cleanup",
        function()
            local root = Instance.new("Folder")
            root.Name = "P17FragmentFixture"
            root.Parent = workspace
            local template = Instance.new("MeshPart")
            template.Size = Vector3.new(1, 1, 1)
            template.Anchored = true
            template.CanCollide = false
            template.CanQuery = false
            template.CanTouch = false
            local owner, reason = Fragments.start(root)
            assert(owner, reason)
            local ok, failure = pcall(function()
                for _ = 1, 20 do
                    owner.emit(
                        CFrame.new(2000, 80, 2000),
                        Vector3.new(16, 8, 1),
                        Color3.new(1, 1, 1),
                        0,
                        { template }
                    )
                end
                assert(
                    owner.count() == 48 and template.Parent == nil and template.Anchored,
                    "P17 assertion: owner.count() == 48 and template.Parent == nil and template.Anchored"
                )
                for _, part in workspace.PanelFragments:GetChildren() do
                    assert(
                        part:IsA("MeshPart") and not part.Anchored and not part.CanQuery and not part.CanTouch,
                        'P17 assertion: part:IsA("MeshPart") and not part.Anchored and not part.CanQuery and not part.CanTouch'
                    )
                    assert(
                        part.CollisionGroup == "PanelFragments" and part:GetNetworkOwner() == nil,
                        'P17 assertion: part.CollisionGroup == "PanelFragments" and part:GetNetworkOwner() == nil'
                    )
                end
                owner.step(8)
                assert(owner.count() == 0, "P17 assertion: owner.count() == 0")
                owner.emit(
                    CFrame.new(2000, 80, 2000),
                    Vector3.new(16, 8, 1),
                    Color3.new(1, 1, 1),
                    10,
                    { template }
                )
                owner.clear()
                assert(owner.count() == 0, "P17 assertion: owner.count() == 0")
            end)
            owner.stop()
            owner.stop()
            template:Destroy()
            root:Destroy()
            assert(ok, failure)
        end
    )
end
