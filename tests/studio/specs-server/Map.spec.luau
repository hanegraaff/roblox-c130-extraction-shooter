--!strict
--[=[
    P02 A2–A5/R01/R05/R10: real Instance queries, cover raycasts, 4x6x4-stud route
    clearance and floor support, authoritative containment, and two pristine rebuilds.
    The upright envelope covers a standard avatar; actual walking is a separate feel review.
]=]
local MapService = require(game:GetService("ServerScriptService").Server.MapService)
local MapRules = require(game:GetService("ReplicatedStorage").Shared.MapRules)

type FixtureWorld = Folder & { Battlefield: typeof(workspace.World.Battlefield) }

-- Dispose fixtures even after an assertion failure so subsequent cases remain independent.
local function fixture(callback: (FixtureWorld, MapService.Controller, { Model }, BindableEvent) -> ())
    local world = (Instance.new("Folder") :: unknown) :: FixtureWorld
    world.Name = "MapFixture"
    world.Parent = workspace
    workspace.World.Battlefield:Clone().Parent = world
    local characters: { Model } = {}
    local step = Instance.new("BindableEvent")
    local owner, reason = MapService.new(world, {
        characters = function()
            return characters
        end,
        heartbeat = step.Event,
    })
    assert(owner, reason)
    local ok, message = pcall(function()
        callback(world, owner, characters, step)
        return true
    end)
    owner.destroy()
    step:Destroy()
    for _, character in characters do
        character:Destroy()
    end
    world:Destroy()
    assert(ok, tostring(message))
end

return function()
    local test = getfenv().it :: (string, () -> ()) -> ()
    require(game:GetService("ServerStorage").Tests.Unit["MapRules.spec"])(test, MapRules)
    test("authored anchors validate and malformed identity count clearance and elevations reject", function()
        fixture(function(world, owner)
            assert(owner.validate(), "expected owner.validate()")
            local map = world.Battlefield
            local disk = map.GroundDisk
            assert(
                (disk.Position - Vector3.new(0, -2, 0)).Magnitude < 0.01,
                "disk translation must survive file load"
            )
            assert(
                math.abs(disk.CFrame.RightVector:Dot(Vector3.yAxis)) > 0.999,
                "disk cylinder axis must load vertical"
            )
            assert(
                (map.GroundSpawn.Position - Vector3.new(0, 0.05, 120)).Magnitude < 0.01,
                "spawn transform must survive file load"
            )
            assert(
                (map.Permanent.ShelterRoof.Position - Vector3.new(0, 14, 114)).Magnitude < 0.01,
                "cover transform must survive file load"
            )
            local size = disk.Size
            disk.Size = Vector3.new(4, 350, 350)
            assert(not owner.validate(), "mismatched authored radius must reject")
            disk.Size = size
            local anchor = map.Anchors.Ground01 :: BasePart
            local original = anchor.Position
            for _, position in
                {
                    Vector3.new(361, 3, 0),
                    Vector3.new(0, -31, 0),
                    Vector3.new(0, 8, 0),
                    Vector3.new(35, 3, 120),
                }
            do
                anchor.Position = position
                assert(not owner.validate(), tostring(position))
            end
            anchor.Position = original
            local duplicate = anchor:Clone()
            duplicate.Parent = map.Anchors
            assert(not owner.validate(), "expected not owner.validate()")
            duplicate:Destroy()
            local launcher = map.Anchors.Launcher
            launcher.Parent = nil
            assert(not owner.validate(), "expected not owner.validate()")
            launcher.Parent = map.Anchors
            assert(owner.validate(), "expected owner.validate()")
        end)
    end)
    test("two launcher approaches clear a 4x6x4 stud upright avatar and have continuous floor", function()
        fixture(function(world)
            local map = world.Battlefield
            local overlap = OverlapParams.new()
            overlap.FilterType = Enum.RaycastFilterType.Include
            overlap.FilterDescendantsInstances = { map }
            overlap.RespectCanCollide = true
            local rays = RaycastParams.new()
            rays.FilterType = Enum.RaycastFilterType.Include
            rays.FilterDescendantsInstances = { map }
            rays.RespectCanCollide = true
            for _, side in { -1, 1 } do
                local route = {
                    Vector3.new(side * 20, 3.5, 108),
                    Vector3.new(side * 24, 3.5, 108),
                    Vector3.new(side * 24, 3.5, 65),
                    Vector3.new(side * 60, 3.5, 65),
                    Vector3.new(side * 60, 3.5, 0),
                    Vector3.new(0, 3.5, 0),
                }
                for index = 1, #route - 1 do
                    local start, finish = route[index], route[index + 1]
                    local samples = math.ceil((finish - start).Magnitude / 0.5)
                    for sample = 0, samples do
                        local position = start:Lerp(finish, sample / samples)
                        assert(
                            #workspace:GetPartBoundsInBox(
                                    CFrame.new(position),
                                    Vector3.new(4, 6, 4),
                                    overlap
                                ) == 0,
                            "route blocked: " .. tostring(position)
                        )
                        local floor = workspace:Raycast(position, Vector3.new(0, -5, 0), rays)
                        assert(floor and math.abs(floor.Position.Y) <= 0.11, "route floor missing")
                    end
                end
            end
        end)
    end)
    test("cover queries protect all nine spawns and expose firing angles to 64 perimeter samples", function()
        fixture(function(world, owner)
            assert(owner.start(), "expected owner.start()")
            local map = world.Battlefield
            local rays = RaycastParams.new()
            rays.FilterType = Enum.RaycastFilterType.Include
            rays.FilterDescendantsInstances = { map }
            rays.RespectCanCollide = true
            for _, kind in { "Permanent", "Breakable" } do
                local part = map[kind]:GetChildren()[1] :: BasePart
                assert(
                    part:GetAttribute("CoverKind") == kind and part:GetAttribute("CoverId") == part.Name,
                    'expected part:GetAttribute("CoverKind") == kind and part:GetAttribute("CoverId") == part.Name'
                )
                local hit =
                    workspace:Raycast(part.Position + Vector3.new(0, 30, 0), Vector3.new(0, -31, 0), rays)
                assert(hit and hit.Instance == part, kind .. " must block ray")
            end
            for i = 0, 63 do
                local x, y, z = MapRules.orbit(MapRules.defaults, i * math.pi / 32)
                local aircraft = Vector3.new(x, y, z)
                for _, anchor in map.Anchors:GetChildren() do
                    if string.match(anchor.Name, "^Ground") then
                        local point = (anchor :: BasePart).Position
                        local hit = workspace:Raycast(point, aircraft - point, rays)
                        assert(
                            hit and hit.Instance:IsDescendantOf(map.Permanent),
                            "spawn unprotected: " .. anchor.Name .. " phase " .. i
                        )
                    end
                end
                local muzzle =
                    Vector3.new(math.cos(i * math.pi / 32) * 330, 5, math.sin(i * math.pi / 32) * 330)
                assert(not workspace:Raycast(muzzle, aircraft - muzzle, rays), "blocked firing angle " .. i)
            end
        end)
    end)
    test(
        "server corrects exterior and below kill plane while preserving disk and station positions",
        function()
            fixture(function(world, owner, characters, step)
                local character = Instance.new("Model")
                local root = Instance.new("Part")
                root.Name = "HumanoidRootPart"
                root.Anchored = true
                root.Parent = character
                local humanoid = Instance.new("Humanoid")
                humanoid.Parent = character
                character.PrimaryPart = root
                character.Parent = workspace
                table.insert(characters, character)
                assert(owner.start(), "expected owner.start()")
                assert(owner.start(), "expected owner.start()")
                for _, position in
                    {
                        Vector3.new(361, 3, 0),
                        Vector3.new(-400, 3, 0),
                        Vector3.new(0, -31, 0),
                        Vector3.new(520, 30, 0),
                    }
                do
                    root.CFrame = CFrame.new(position)
                    owner.enforce()
                    assert(
                        (root.Position - (world.Battlefield.Anchors.Ground05 :: BasePart).Position).Magnitude
                            < 0.01,
                        "expected (root.Position - (world.Battlefield.Anchors.Ground05 :: BasePart).Position).Magnitude                             < 0.01"
                    )
                end
                for _, position in { Vector3.new(0, 3, 0), Vector3.new(170, 3, 0), Vector3.new(520, 3, 0) } do
                    root.CFrame = CFrame.new(position)
                    owner.enforce()
                    assert(root.Position == position, "expected root.Position == position")
                end
                owner.stop()
                owner.stop()
                root.CFrame = CFrame.new(500, 3, 0)
                step:Fire()
                assert(root.Position.X == 500, "stopped owner retained heartbeat")
            end)
        end
    )
    test("two rebuilds restore exact geometry IDs poses counts and remove transient content", function()
        fixture(function(world, owner)
            assert(owner.start(), "expected owner.start()")
            local baseline: { [string]: CFrame } = {}
            for _, item in world.Battlefield:GetDescendants() do
                if item:IsA("BasePart") then
                    baseline[item.Name] = item.CFrame
                end
            end
            local count = #world.Battlefield:GetDescendants()
            for _ = 1, 2 do
                world.Battlefield.Permanent.ShelterRoof:Destroy()
                local transient = Instance.new("Part")
                transient.Name = "TransientDebris"
                transient.Parent = world.Battlefield
                assert(owner.rebuild(), "expected owner.rebuild()")
                assert(
                    #world.Battlefield:GetDescendants() == count,
                    "expected #world.Battlefield:GetDescendants() == count"
                )
                assert(
                    not world.Battlefield:FindFirstChild("TransientDebris"),
                    'expected not world.Battlefield:FindFirstChild("TransientDebris")'
                )
                for _, item in world.Battlefield:GetDescendants() do
                    if item:IsA("BasePart") then
                        assert(baseline[item.Name] == item.CFrame, item.Name)
                    end
                end
            end
            owner.destroy()
            owner.destroy()
            assert(not owner.start(), "expected not owner.start()")
            assert(not owner.rebuild(), "expected not owner.rebuild()")
        end)
    end)
end
