--!strict
--[=[
    P13 A2–A6: loaded building transforms, actual avatar envelopes, deterministic smooth
    terrain reconstruction, protected/exposed full-orbit rays and pristine IDs. TestEZ
    runs before GameRuntime. Fixtures are disposed after failure; unrelated voxel data
    is restored exactly. Real operated Humanoid navigation and replication use P13Harness.
]=]
local Server = game:GetService("ServerScriptService").Server
local MapService = require(Server.MapService)
local TerrainRecipe = require(Server.TerrainRecipe)
local MapRules = require(game.ReplicatedStorage.Shared.MapRules)
local Terrain = workspace.Terrain

-- Terrain writes enqueue physics/query updates. ReadVoxels sees writes immediately,
-- while ray/collision visibility is allowed five seconds to converge in Studio.
local function awaitCondition(predicate: () -> boolean, message: string)
    local deadline = os.clock() + 5
    while not predicate() and os.clock() < deadline do
        task.wait()
    end
    assert(predicate(), message)
end

local function fixture(callback: (Model, MapService.Controller) -> ())
    local world = Instance.new("Folder")
    world.Name = "ExpandedMapFixture"
    local map = workspace.World.Battlefield:Clone()
    map.Parent = world
    world.Parent = workspace
    local step = Instance.new("BindableEvent")
    local owner, reason = MapService.new(world, {
        characters = function()
            return {}
        end,
        heartbeat = step.Event,
    })
    assert(owner, reason)
    local ok, failure = pcall(function()
        assert(owner.start(), "fixture map start failed")
        callback(map, owner)
    end)
    owner.destroy()
    step:Destroy()
    world:Destroy()
    assert(ok, tostring(failure))
end

local function terrainSignature(recipe: Instance): string
    local result: { string } = {}
    for _, hill in recipe:GetChildren() do
        if hill:IsA("Part") and hill.Name ~= "TerrainBounds" then
            local center = hill.Position + Vector3.new(0, hill.Size.Y / 2 - 8, 0)
            local region = Region3.new(center - Vector3.new(8, 16, 8), center + Vector3.new(8, 16, 8))
                :ExpandToGrid(4)
            local materials, occupancies = Terrain:ReadVoxels(region, 4)
            for x = 1, #materials do
                for y = 1, #materials[x] do
                    for z = 1, #materials[x][y] do
                        table.insert(
                            result,
                            tostring(materials[x][y][z]) .. ":" .. tostring(occupancies[x][y][z])
                        )
                    end
                end
            end
        end
    end
    return table.concat(result, "|")
end

return function()
    local test = getfenv().it :: (string, () -> ()) -> ()
    require(game.ServerStorage.Tests.Unit["BuildingLayout.spec"])(
        test,
        require(game.ReplicatedStorage.Shared.BuildingLayout)
    )
    test("BuildingLayout loaded panels have stable IDs story pivots and distinct static supports", function()
        fixture(function(map, owner)
            assert(owner.validate(), "loaded building validation failed")
            local buildings = map:FindFirstChild("Buildings")
            assert(buildings and #buildings:GetChildren() == 3, "three buildings required")
            local areas: { number } = {}
            for _, building in buildings:GetChildren() do
                local supports = building:FindFirstChild(building.Name .. "_Static") :: Folder
                local floor = supports:FindFirstChild(building.Name .. "_GroundFloor") :: BasePart
                table.insert(areas, floor.Size.X * floor.Size.Z)
                assert(floor:GetAttribute("CoverKind") == "StaticSupport", "floor marked destructible")
                local panels = building:FindFirstChild(building.Name .. "_Panels") :: Folder
                local stories: { [string]: boolean } = {}
                local roofs = 0
                for _, panel in panels:GetChildren() do
                    assert(panel:IsA("BasePart"), "panel must be part")
                    assert(panel:GetAttribute("PanelId") == panel.Name, "missing panel identity")
                    assert(panel:GetAttribute("IntactPivot") == panel.CFrame, "pivot changed on load")
                    assert(
                        panel:GetAttribute("VariantContract") == "Intact/Damaged/Destroyed:v1",
                        "variant contract missing"
                    )
                    stories[tostring(panel:GetAttribute("StoryId"))] = true
                    if string.find(panel.Name, "_Roof_", 1, true) then
                        roofs += 1
                    end
                end
                assert(stories["01"] and stories["02"] and roofs > 0, "missing story or roof panels")
            end
            table.sort(areas)
            assert(
                areas[1] == 1536 and areas[2] == 3072 and areas[3] == 3072,
                "large/small footprint areas changed"
            )
        end)
    end)
    test("BuildingLayout rejects missing upper support detached stairs and blocked avatar routes", function()
        fixture(function(map, owner)
            local buildings = map:FindFirstChild("Buildings") :: Folder
            local building = buildings:FindFirstChild("Foundry") :: Model
            local supports = building:FindFirstChild("Foundry_Static") :: Folder
            local floor = supports:FindFirstChild("Foundry_UpperMain") :: BasePart
            floor.Parent = nil
            assert(not owner.validate(), "missing upper floor accepted")
            floor.Parent = supports
            local step = supports:FindFirstChild("Foundry_Step08") :: BasePart
            local pose = step.CFrame
            step.CFrame += Vector3.new(0, 0, 8)
            assert(not owner.validate(), "detached stairs accepted")
            step.CFrame = pose
            step.Size += Vector3.new(0, 3, 0)
            assert(not owner.validate(), "excessive rise accepted")
            step.Size -= Vector3.new(0, 3, 0)
            local blocker = Instance.new("Part")
            blocker.Name = "P13DoorBlocker"
            blocker.Anchored = true
            blocker.Size = Vector3.new(16, 8, 4)
            blocker.Position = Vector3.new(-160, 4, -80)
            blocker.Parent = map
            assert(not owner.validate(), "blocked entrance accepted")
            blocker:Destroy()
            assert(owner.validate(), "valid route did not recover after rejection")
        end)
    end)
    test(
        "TerrainReconstruction samples elevations materials and exact voxels through two mutated rebuilds",
        function()
            fixture(function(map, owner)
                local world = map.Parent :: Instance
                local recipe = (map:FindFirstChild("TerrainRecipe") :: Folder):Clone()
                local rays = RaycastParams.new()
                rays.FilterType = Enum.RaycastFilterType.Include
                rays.FilterDescendantsInstances = { Terrain }
                local initial = terrainSignature(recipe)
                for _, hill in recipe:GetChildren() do
                    if hill:IsA("Part") and hill.Name ~= "TerrainBounds" then
                        awaitCondition(function()
                            local hit = workspace:Raycast(
                                Vector3.new(hill.Position.X, 80, hill.Position.Z),
                                Vector3.new(0, -150, 0),
                                rays
                            )
                            return hit ~= nil
                                and hit.Instance == Terrain
                                and hit.Material == hill.Material
                                and math.abs(hit.Position.Y - 16) <= 3
                        end, "terrain material/elevation did not converge")
                    end
                end
                local unrelated = Region3.new(Vector3.new(696, 16, -4), Vector3.new(704, 24, 4))
                    :ExpandToGrid(4)
                local oldMaterials, oldOccupancies = Terrain:ReadVoxels(unrelated, 4)
                local ok, failure = pcall(function()
                    Terrain:FillBlock(CFrame.new(700, 20, 0), Vector3.new(8, 8, 8), Enum.Material.Sand)
                    for _ = 1, 2 do
                        Terrain:FillBall(Vector3.new(-260, 20, -140), 12, Enum.Material.Sand)
                        local transient = Instance.new("Part")
                        transient.Name = "P13TransientPanel"
                        transient.Parent = world:FindFirstChild("Battlefield")
                        assert(owner.rebuild(), "terrain rebuild failed")
                        local current = world:FindFirstChild("Battlefield")
                        assert(
                            current and not current:FindFirstChild("P13TransientPanel"),
                            "runtime panel survived reset"
                        )
                        assert(terrainSignature(recipe) == initial, "terrain voxels differ after rebuild")
                        awaitCondition(function()
                            local hit =
                                workspace:Raycast(Vector3.new(700, 30, 0), Vector3.new(0, -20, 0), rays)
                            return hit ~= nil and hit.Material == Enum.Material.Sand
                        end, "unrelated terrain changed")
                    end
                end)
                Terrain:WriteVoxels(unrelated, 4, oldMaterials, oldOccupancies)
                recipe:Destroy()
                assert(ok, tostring(failure))
            end)
        end
    )
    test("TerrainReconstruction rejects out-of-bounds recipes without terrain writes", function()
        fixture(function(map)
            local recipe = (map:FindFirstChild("TerrainRecipe") :: Folder):Clone()
            local hill = recipe:FindFirstChild("TerrainHill00") :: BasePart
            hill.Position = Vector3.new(700, 0, 0)
            local before = terrainSignature(map:FindFirstChild("TerrainRecipe") :: Folder)
            assert(not TerrainRecipe.restore(Terrain, recipe), "out-of-bounds recipe accepted")
            hill.Position = Vector3.new(-260, -36, -140)
            local bounds = recipe:FindFirstChild("TerrainBounds") :: BasePart
            bounds.CFrame *= CFrame.Angles(0, math.pi / 4, 0)
            assert(not TerrainRecipe.restore(Terrain, recipe), "rotated ownership bounds accepted")
            recipe:Destroy()
            assert(
                terrainSignature(map:FindFirstChild("TerrainRecipe") :: Folder) == before,
                "invalid recipe mutated terrain"
            )
        end)
    end)
    test("ExpandedMapCleanup teardown restores mutated panel geometry and remains idempotent", function()
        fixture(function(map, owner)
            local world = map.Parent :: Instance
            local count = #map:GetDescendants()
            local buildings = map:FindFirstChild("Buildings") :: Folder
            local first = buildings:GetChildren()[1]
            local panels = first:FindFirstChild(first.Name .. "_Panels") :: Folder
            panels:GetChildren()[1]:Destroy()
            local temporary = Instance.new("Part")
            temporary.Name = "P13TeardownTransient"
            temporary.Parent = map
            owner.destroy()
            owner.destroy()
            local restored = world:FindFirstChild("Battlefield")
            assert(
                restored
                    and #restored:GetDescendants() == count
                    and not restored:FindFirstChild("P13TeardownTransient"),
                "teardown did not restore authored geometry"
            )
            assert(not owner.start() and not owner.rebuild(), "destroyed owner restarted")
        end)
    end)
    test(
        "ExpandedMapSightLines full orbit has protected building interiors and supported clear counterfire positions",
        function()
            fixture(function(map)
                local rays = RaycastParams.new()
                rays.FilterType = Enum.RaycastFilterType.Include
                rays.FilterDescendantsInstances = { map, Terrain }
                rays.RespectCanCollide = true
                local maxDistance = 0
                for i = 0, 63 do
                    local phase = i * math.pi / 32
                    local x, y, z = MapRules.orbit(MapRules.defaults, phase)
                    local plane = Vector3.new(x, y, z)
                    local groundProbe = Vector3.new(math.cos(phase) * 330, 80, math.sin(phase) * 330)
                    local support = workspace:Raycast(groundProbe, Vector3.new(0, -100, 0), rays)
                    assert(support, "outer firing position lacks support")
                    local muzzle = support.Position + Vector3.new(0, 4, 0)
                    assert(
                        not workspace:Raycast(muzzle, plane - muzzle, rays),
                        "plane inaccessible from counterfire angle"
                    )
                    maxDistance = math.max(maxDistance, (plane - muzzle).Magnitude)
                    local protected = Vector3.new(-168, 13, -104)
                    assert(
                        workspace:Raycast(protected, plane - protected, rays),
                        "building interior not protected"
                    )
                    assert(
                        math.sqrt(720 ^ 2 + 140 ^ 2) < 750,
                        "future full-disk weapon range budget infeasible"
                    )
                end
                assert(maxDistance < 160, "near-perimeter counterfire budget exceeded")
            end)
        end
    )
end
