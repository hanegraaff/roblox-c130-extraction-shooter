--!strict
-- P08 A2/A4/A6: actual support/occlusion, P06 rocket sweeps and runtime cleanup.
-- Runs before the ordinary GameRuntime. Fixtures own and clean every Instance.
return function()
    local test = getfenv().it :: (string, () -> ()) -> ()
    local Server = game:GetService("ServerScriptService").Server
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local RunService = game:GetService("RunService")
    local MatchService = require(Server.MatchService)
    local AircraftService = require(Server.AircraftService)
    local GroundCombatRuntime = require(Server.GroundCombatRuntime)
    local LauncherRuntime = require(Server.LauncherRuntime)
    local Geometry = require(Server.LauncherGeometry)
    local MapRules = require(ReplicatedStorage.Shared.MapRules)
    test(
        "P08 supported recovery rejects exterior void steep and blocked positions; cover blocks pickup",
        function()
            local map = Instance.new("Model")
            map.Name, map.Parent = "P08RecoveryFixture", workspace
            local floor = Instance.new("Part")
            floor.Anchored, floor.Size, floor.CFrame = true, Vector3.new(24, 1, 24), CFrame.new(0, 100, 0)
            floor.Parent = map
            local root = Instance.new("Part")
            root.Anchored, root.Size, root.Position = true, Vector3.new(2, 2, 1), Vector3.new(0, 104, 0)
            root.Parent = workspace
            local head = root:Clone()
            head.Position, head.Parent = root.Position + Vector3.yAxis * 2, workspace
            local wall = Instance.new("Part")
            wall.Anchored, wall.Size, wall.Position = true, Vector3.new(1, 12, 12), Vector3.new(2, 105, 0)
            local ok, failure = pcall(function()
                local spot = Geometry.supported(map, MapRules.defaults, root.Position)
                assert(spot and math.abs(spot.Y - 101.6) < 0.01, "supported drop incorrect")
                assert(
                    not Geometry.supported(map, MapRules.defaults, Vector3.new(361, 104, 0)),
                    "exterior accepted"
                )
                assert(
                    not Geometry.supported(map, MapRules.defaults, Vector3.new(50, 104, 0)),
                    "void accepted"
                )
                assert(
                    not Geometry.supported(map, MapRules.defaults, Vector3.new(0, math.huge, 0)),
                    "nonfinite accepted"
                )
                local target = Vector3.new(5, 104, 0)
                assert(Geometry.reachable(map, root, head, target, 8), "clear reachable pickup rejected")
                wall.Parent = map
                assert(not Geometry.reachable(map, root, head, target, 8), "pickup through wall")
                wall.Position = Vector3.new(0, 104, 0)
                assert(not Geometry.supported(map, MapRules.defaults, root.Position), "blocked drop accepted")
                wall.Parent = nil
                floor.CFrame = CFrame.new(0, 100, 0) * CFrame.Angles(0, 0, math.rad(70))
                assert(not Geometry.supported(map, MapRules.defaults, root.Position), "steep drop accepted")
            end)
            map:Destroy()
            root:Destroy()
            head:Destroy()
            wall:Destroy()
            assert(ok, tostring(failure))
        end
    )
    test("P08 held and map representations keep one ID and cannot collide or enter combat queries", function()
        local tool = Geometry.tool("launcher:7")
        local model = Geometry.pickup("launcher:7", Vector3.new(2, 3, 4))
        local ok, failure = pcall(function()
            assert(tool:GetAttribute("LauncherId") == model:GetAttribute("LauncherId"), "identity drift")
            assert(not tool.CanBeDropped and tool.RequiresHandle, "native drop not disabled")
            assert((model:GetPivot().Position - Vector3.new(2, 3, 4)).Magnitude < 0.001, "pickup pose")
            local representations: { Instance } = { tool, model }
            for _, owner in representations do
                local count = 0
                for _, item in owner:GetDescendants() do
                    if item:IsA("BasePart") then
                        count += 1
                        assert(
                            not item.CanCollide and not item.CanQuery and not item.CanTouch,
                            "interactive cosmetic"
                        )
                    end
                end
                assert(count == 3, "unbounded launcher representation")
            end
        end)
        tool:Destroy()
        model:Destroy()
        assert(ok, tostring(failure))
    end)
    test("P08 first solid sweep blocks rockets; three deduplicated direct impacts destroy once", function()
        local match = MatchService.new({ minimumPlayers = 2, durationSeconds = 600, seed = 1 }, {
            now = function()
                return workspace:GetServerTimeNow()
            end,
            releaseLife = function() end,
        })
        match.join(101)
        match.join(102)
        assert(match.deploy(), "fixture deployment")
        local id = match.snapshot().roundId
        assert(match.ready(101, id) and match.ready(102, id) and match.activate(), "fixture active")
        local aircraft, reason = AircraftService.start(match)
        assert(aircraft, reason)
        local ground, groundReason = GroundCombatRuntime.start(match)
        if not ground then
            aircraft.stop()
            error(tostring(groundReason))
        end
        local launcher, launcherReason = LauncherRuntime.start(match, ground)
        if not launcher then
            ground.stop()
            aircraft.stop()
            error(tostring(launcherReason))
        end
        local wall = Instance.new("Part")
        wall.Anchored, wall.Size = true, Vector3.new(20, 0.2, 20)
        local ok, failure = pcall(function()
            RunService.Heartbeat:Wait()
            RunService.Heartbeat:Wait()
            task.wait()
            local model = workspace:FindFirstChild("Aircraft")
            assert(model and model:IsA("Model"), "aircraft fixture")
            local origin = model:GetPivot().Position + Vector3.new(0, 50, 0)
            local before = ReplicatedStorage.AircraftState:GetAttribute("Health")
            assert(before == 300, "health initialization")
            wall.Position, wall.Parent = origin - Vector3.yAxis * 20, workspace.World.Battlefield
            local collision, applied = ground.rocketCast(id, "P08blocked", origin, -Vector3.yAxis * 60)
            assert(
                collision and not applied and collision.Y > model:GetPivot().Position.Y + 20,
                "first cover ignored"
            )
            assert(ReplicatedStorage.AircraftState:GetAttribute("Health") == 300, "cover damaged aircraft")
            wall:Destroy()
            assert(
                not ground.rocketSweep(id, "P08nearMiss", origin + Vector3.xAxis * 100, -Vector3.yAxis * 60),
                "near miss counted"
            )
            for index = 1, 3 do
                local shot = "P08direct" .. tostring(index)
                assert(ground.rocketSweep(id, shot, origin, -Vector3.yAxis * 60), "direct rocket missed")
                assert(
                    ReplicatedStorage.AircraftState:GetAttribute("Health") == 300 - index * 100,
                    "three-hit health"
                )
                assert(
                    not ground.rocketSweep(id, shot, origin, -Vector3.yAxis * 60),
                    "duplicate impact counted"
                )
            end
            match.step()
            local result = match.snapshot().result
            assert(result and result.winner == "Ground", "third impact result")
            RunService.Heartbeat:Wait()
            task.wait()
            assert(
                launcher.snapshot().state == "Inactive" and launcher.resources().representations == 0,
                "terminal launcher survived"
            )
            assert(not ground.rocketSweep(id, "P08late", origin, -Vector3.yAxis * 60), "terminal award")
        end)
        wall:Destroy()
        launcher.stop()
        launcher.stop()
        ground.stop()
        aircraft.stop()
        assert(
            launcher.resources().connections == 0
                and launcher.resources().representations == 0
                and launcher.resources().flights == 0
                and launcher.resources().queued == 0,
            "launcher resource leak"
        )
        assert(
            not ReplicatedStorage:FindFirstChild("LauncherState")
                and not workspace:FindFirstChild("LauncherEffects"),
            "launcher owner leak"
        )
        assert(ok, tostring(failure))
    end)
end
