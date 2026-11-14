--!strict
-- P17: actual imported templates/registered geometry. Native human movement,
-- operated firing, replication, full-orbit visual/performance/A6 remain separate.
local Server = game.ServerScriptService.Server
local Assets = game.ServerStorage.Assets
local Reconstruction = require(Server.OutpostReconstruction)
local BuildingGeometry = require(Server.BuildingGeometry)
local DestructionRuntime = require(Server.DestructionRuntime)
local Catalog = require(Server.PanelAssetCatalog)
local function fixture()
    local world = Instance.new("Folder")
    world.Name = "OutpostEngineFixture"
    local map = workspace.World.Battlefield:Clone()
    map.Parent = world
    local installation, reason = Reconstruction.install(world, Assets)
    assert(installation, reason)
    installation.commit()
    BuildingGeometry.decorate(map)
    world.Parent = workspace
    return world, map
end
return function()
    local test = getfenv().it :: (string, () -> ()) -> ()
    test(
        "P17OutpostReconstruction actual repaired source retains legacy identities exact site and clean rollback",
        function()
            local catalog, reason = Catalog.load(Assets.MaterialPanels)
            assert(catalog, reason)
            local world = Instance.new("Folder")
            local map = workspace.World.Battlefield:Clone()
            map.Parent = world
            local buildings = map.Buildings
            local foundry, warehouse, original = buildings.Foundry, buildings.Warehouse, buildings.Outpost
            local previous: { [string]: CFrame } = {}
            for _, part in original.Outpost_Panels:GetChildren() do
                if part:IsA("BasePart") then
                    previous[part.Name] = part.CFrame
                end
            end
            local owner, errorReason = Reconstruction.install(world, Assets)
            assert(owner, errorReason)
            local ok, failure = pcall(function()
                assert(
                    buildings.Foundry == foundry
                        and buildings.Warehouse == warehouse
                        and #buildings:GetChildren() == 3,
                    "unrelated buildings changed"
                )
                local panels = buildings.Outpost.Outpost_Panels:GetChildren()
                assert(#panels == 26, "approved partition missing")
                for _, panel in panels do
                    assert(panel:IsA("Model"), "material identity missing")
                    if previous[panel.Name] then
                        assert(panel:GetPivot() == previous[panel.Name], "legacy identity pivot changed")
                    end
                end
                local repeatOwner = Reconstruction.install(world, Assets)
                assert(repeatOwner and buildings.Outpost ~= original, "idempotent installation failed")
                repeatOwner.commit()
            end)
            owner.rollback()
            assert(
                buildings.Outpost == original and original.Parent == buildings,
                "failed preparation did not restore original exactly"
            )
            world:Destroy()
            assert(ok, failure)
        end
    )
    test(
        "P17MaterialPanelStates actual material families share exact heavy thresholds and real openings",
        function()
            local world, map = fixture()
            local owner, reason = DestructionRuntime.start(world)
            assert(owner, reason)
            owner.sync(1)
            local ok, failure = pcall(function()
                assert(owner.resources().panels == 188, "active registry lacks additional partition")
                local families: { [string]: Model } = {}
                for _, panel in map.Buildings.Outpost.Outpost_Panels:GetChildren() do
                    local family = panel:GetAttribute("PanelAssetFamily")
                    if panel:IsA("Model") and type(family) == "string" then
                        families[family] = panel
                    end
                end
                local serial = 0
                local familyCount = 0
                for _, panel in families do
                    familyCount += 1
                    for hit = 1, 6 do
                        serial += 1
                        assert(
                            owner.resolve({
                                roundId = 1,
                                shotId = serial,
                                weapon = "M102",
                                firedAt = serial * 4,
                                panelId = panel.Name,
                            }),
                            "valid heavy outcome rejected"
                        )
                        owner.flush(workspace:GetServerTimeNow())
                        local expected = if hit < 3 then "Light" elseif hit < 6 then "Heavy" else "Total"
                        assert(
                            panel:GetAttribute("DamageAppearance") == expected,
                            "material changed shared thresholds"
                        )
                        if hit == 3 then
                            local basis = panel:GetAttribute("PanelAssetBasis")
                            assert(typeof(basis) == "CFrame", "asset basis absent")
                            local pivot = panel:GetPivot() * basis
                            local rays = RaycastParams.new()
                            rays.FilterType = Enum.RaycastFilterType.Include
                            rays.FilterDescendantsInstances = { panel }
                            rays.RespectCanCollide = true
                            task.wait(0.1)
                            local direction = pivot:VectorToWorldSpace(Vector3.new(0, 0, 8))
                            assert(
                                workspace:Raycast(
                                    pivot:PointToWorldSpace(Vector3.new(0, 0, -4)),
                                    direction,
                                    rays
                                ) == nil,
                                "earned opening still blocked"
                            )
                            assert(
                                workspace:Raycast(
                                    pivot:PointToWorldSpace(Vector3.new(7, 0, -4)),
                                    direction,
                                    rays
                                ) ~= nil,
                                "remaining material lost solidity"
                            )
                        end
                    end
                    assert(#panel:GetChildren() == 0, "Total left attached art/phantom cover")
                end
                assert(familyCount == 6, "actual material family coverage incomplete")
            end)
            owner.stop()
            world:Destroy()
            assert(ok, failure)
        end
    )
end
