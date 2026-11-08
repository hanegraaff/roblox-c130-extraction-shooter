--!strict
-- P04 A2/A5: real canonical model/attachments, injected orbit time and solid world rays.
-- TestEZ executes before GameRuntime owns the world. Every fixture is destroyed even
-- after assertion failure; 0.01 studs/1e-5 dot tolerances allow CFrame float precision.
return function()
    local test = getfenv().it :: (string, () -> ()) -> ()
    local Server = game:GetService("ServerScriptService").Server
    local MatchService = require(Server.MatchService)
    local AircraftService = require(Server.AircraftService)
    local RunService = game:GetService("RunService")
    local function fixture(
        callback: (AircraftService.Controller, MatchService.Controller, (number) -> ()) -> ()
    )
        local time = 0
        local match = MatchService.new({ minimumPlayers = 2, durationSeconds = 1000, seed = 1 }, {
            now = function()
                return time
            end,
            releaseLife = function() end,
        })
        match.join(101)
        match.join(102)
        assert(match.deploy(), "fixture deploy")
        local id = match.snapshot().roundId
        assert(match.ready(101, id) and match.ready(102, id), "fixture ready")
        assert(match.activate(), "fixture activate")
        local owner, reason = AircraftService.start(match, function()
            return time
        end)
        assert(owner, reason)
        local ok, failure = pcall(function()
            callback(owner, match, function(nextTime)
                time = nextTime
                RunService.Heartbeat:Wait()
                RunService.Heartbeat:Wait()
            end)
        end)
        owner.stop()
        owner.stop()
        assert(owner.resources().connections == 0, "aircraft listeners survived stop")
        assert(
            not workspace:FindFirstChild("Aircraft")
                and not game:GetService("ReplicatedStorage"):FindFirstChild("AircraftState"),
            "aircraft instances survived stop"
        )
        assert(ok, tostring(failure))
    end
    test(
        "canonical engine aircraft follows full perimeter, tangent and muzzle contract then resets",
        function()
            fixture(function(owner, match, setTime)
                local model = workspace:FindFirstChild("Aircraft")
                assert(model and model:IsA("Model"), "aircraft model missing")
                local hitbox = model:FindFirstChild("Hitbox")
                assert(
                    hitbox and hitbox:IsA("BasePart") and model.PrimaryPart == hitbox,
                    "canonical hitbox missing"
                )
                for _, item in model:GetDescendants() do
                    if item:IsA("BasePart") then
                        assert(
                            item.Anchored
                                and not item.CanCollide
                                and not item.CanTouch
                                and item.CanQuery == (item == hitbox),
                            "aircraft collision/query contract"
                        )
                    end
                end
                for _, name in { "GAU23Muzzle", "M102Muzzle" } do
                    local attachment = hitbox:FindFirstChild(name)
                    assert(attachment and attachment:IsA("Attachment"), "missing muzzle " .. name)
                end
                for i = 0, 16 do
                    local elapsed = i * 90 / 16
                    setTime(elapsed)
                    local actual = model:GetPivot()
                    local expected = owner.sample(elapsed)
                    assert(
                        (actual.Position - expected.Position).Magnitude < 0.01,
                        "canonical engine pose drift"
                    )
                    assert(
                        actual.LookVector:Dot(expected.LookVector) > 1 - 1e-5,
                        "model heading is not tangent"
                    )
                    assert(
                        math.abs(Vector2.new(actual.X, actual.Z).Magnitude - 180) < 0.01
                            and math.abs(actual.Y - 140) < 0.01,
                        "orbit perimeter/altitude drift"
                    )
                end
                assert(match.abort(match.snapshot().roundId, "FixtureReset"), "fixture abort")
                assert(match.beginReset() and match.finishReset(), "fixture reset")
                setTime(95)
                assert(
                    (model:GetPivot().Position - owner.sample(0).Position).Magnitude < 0.01,
                    "reset must restore initial orbit"
                )
            end)
        end
    )
    test("server aim rejects exterior and actual solid cover while a clear endpoint succeeds", function()
        fixture(function(owner, _match, setTime)
            setTime(0)
            local endpoint = Vector3.new(0, 40, 0)
            assert(owner.aimAllowed(endpoint), "exposed elevated endpoint should be clear")
            assert(not owner.aimAllowed(Vector3.new(181, 0, 0)), "outside disk accepted")
            assert(not owner.aimAllowed(Vector3.new(0 / 0, 0, 0)), "nonfinite aim accepted")
            local wall = Instance.new("Part")
            wall.Name = "P04SolidSightFixture"
            wall.Anchored = true
            wall.Size = Vector3.new(10, 24, 24)
            wall.Position = Vector3.new(90, 90, 0)
            wall.Parent = workspace.World.Battlefield
            local blocked = not owner.aimAllowed(endpoint)
            wall:Destroy()
            assert(blocked, "solid cover did not block server sight line")
            assert(owner.aimAllowed(endpoint), "removed wall left stale obstruction")
        end)
    end)
end
