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
                assert(
                    hitbox.Anchored and hitbox.Transparency == 1 and not hitbox.CanQuery,
                    "canonical root must never extend the shootable silhouette"
                )
                local roundedQueries = model:FindFirstChild("RoundedQueries")
                assert(roundedQueries and roundedQueries:IsA("Folder"), "missing rounded query volumes")
                local queryable = 0
                for _, item in model:GetDescendants() do
                    if item:IsA("BasePart") then
                        assert(
                            not item.CanCollide and not item.CanTouch and item.AssemblyRootPart == hitbox,
                            "aircraft must remain a single noncolliding rigid assembly"
                        )
                        if item ~= hitbox then
                            assert(not item.Anchored and item.Massless, "flight root must be the only anchor")
                        end
                        if item.CanQuery then
                            assert(
                                item.Transparency == (if item:IsDescendantOf(roundedQueries) then 1 else 0),
                                "only native solids and their dedicated rounded proxies participate in queries"
                            )
                            queryable += 1
                        end
                    end
                end
                assert(queryable >= 40, "missing solid airframe surfaces")
                local parameters = RaycastParams.new()
                parameters.FilterType = Enum.RaycastFilterType.Include
                parameters.FilterDescendantsInstances = { model }
                local function cast(from: Vector3, to: Vector3): RaycastResult?
                    local frame = model:GetPivot()
                    return workspace:Raycast(
                        frame:PointToWorldSpace(from),
                        frame:VectorToWorldSpace(to - from),
                        parameters
                    )
                end
                for _, sample in
                    {
                        { prefix = "Cargo cabin", point = Vector3.new(0, 0, -12) },
                        { prefix = "Starboard wing", point = Vector3.new(26.2, 0, -4) },
                        { prefix = "Starboard stabilizer", point = Vector3.new(9, 0, 26) },
                        { prefix = "Dorsal fin", point = Vector3.new(0, 12, 23.8), fromAbove = true },
                        { prefix = "Port2 nacelle", point = Vector3.new(-17.5, 0, -8.1) },
                    }
                do
                    local span = Vector3.yAxis * (if sample.fromAbove then -18 else 18)
                    local hit = cast(sample.point - span, sample.point + span)
                    assert(
                        hit and string.sub(hit.Instance.Name, 1, #sample.prefix) == sample.prefix,
                        "solid visible airframe surface missed: " .. sample.prefix .. " / " .. tostring(hit)
                    )
                end
                for _, sample in
                    {
                        {
                            prefix = "Rounded flight deck",
                            from = Vector3.new(6, 0, -24.5),
                            toward = Vector3.new(3.35, 0, -24.5),
                            outside = Vector3.new(4.9, 0, -24.5),
                        },
                        {
                            prefix = "Port2 nacelle",
                            from = Vector3.new(-17.5, -1, -10.4),
                            toward = Vector3.new(-17.5, 2.83, -10.4),
                            outside = Vector3.new(-17.5, 1.38, -10.4),
                        },
                        {
                            prefix = "Tapered tail cone",
                            from = Vector3.new(0, -8, 29.22),
                            toward = Vector3.new(0, 2.2, 29.22),
                            outside = Vector3.new(0, 1.11, 29.22),
                        },
                    }
                do
                    local hit = cast(sample.from, sample.toward)
                    assert(
                        hit
                            and hit.Instance:IsDescendantOf(roundedQueries)
                            and string.sub(hit.Instance.Name, 1, #sample.prefix) == sample.prefix,
                        "rounded visual mantle must support a matching native query: " .. sample.prefix
                    )
                    assert(
                        not cast(sample.from, sample.outside),
                        "rounded query escaped the authored visual shell: " .. sample.prefix
                    )
                end
                assert(
                    not cast(Vector3.new(29.3, -12, -4), Vector3.new(29.3, 12, -4)),
                    "shot outside the wingtips must miss"
                )
                assert(
                    not cast(Vector3.new(10, 4.7, -14), Vector3.new(5.6, 4.7, -14)),
                    "shot through the old rectangular proxy corner must miss"
                )
                local airframe = model:FindFirstChild("Airframe")
                assert(airframe and airframe:IsA("Model"), "managed aircraft visual missing")
                for _, shape in
                    {
                        { name = "Rounded flight deck", scale = Vector3.new(11.3, 9, 17.2) },
                        { name = "Port2 nacelle", scale = Vector3.new(3.77, 3.48, 10.2) },
                        { name = "Tapered tail cone", scale = Vector3.new(6.83, 4.23, 16) },
                    }
                do
                    local visual = airframe:FindFirstChild(shape.name)
                    assert(
                        visual and visual:IsA("Part") and not visual.CanQuery and visual.Size == Vector3.one,
                        "rounded shape uses a strictly visual mesh carrier"
                    )
                    local sphere = visual:FindFirstChild("RoundedVisual")
                    assert(
                        sphere
                            and sphere:IsA("SpecialMesh")
                            and sphere.MeshType == Enum.MeshType.Sphere
                            and (sphere.Scale - shape.scale).Magnitude < 0.001
                            and sphere.MeshId == "",
                        "built-in ellipse lost its independent visual scale: " .. shape.name
                    )
                end
                for _, weapon in { "GAU23", "M102" } do
                    local attachment = hitbox:FindFirstChild(weapon .. "Muzzle")
                    local bore = airframe:FindFirstChild(weapon .. " dark bore")
                    assert(attachment and attachment:IsA("Attachment"), "missing muzzle " .. weapon)
                    assert(bore and bore:IsA("BasePart"), "missing muzzle bore " .. weapon)
                    assert(
                        (attachment.WorldPosition - bore.Position).Magnitude < 0.01,
                        "muzzle effect source does not align with visible bore"
                    )
                end
                for i = 0, 16 do
                    local elapsed = i * 90 / 16
                    setTime(elapsed)
                    local actual = model:GetPivot()
                    local m102 = assert(owner.muzzle("M102"), "selected muzzle missing in flight")
                    local bore = airframe:FindFirstChild("M102 dark bore")
                    assert(
                        bore and bore:IsA("BasePart") and (bore.Position - m102).Magnitude < 0.02,
                        "flying rig drifted from muzzle"
                    )
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
                        math.abs(Vector2.new(actual.X, actual.Z).Magnitude - 360) < 0.01
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
            local endpoint = Vector3.new(0, 30, 0)
            assert(owner.aimAllowed(endpoint), "exposed elevated endpoint should be clear")
            assert(not owner.aimAllowed(Vector3.new(361, 0, 0)), "outside disk accepted")
            assert(not owner.aimAllowed(Vector3.new(0 / 0, 0, 0)), "nonfinite aim accepted")
            local wall = Instance.new("Part")
            wall.Name = "P04SolidSightFixture"
            wall.Anchored = true
            wall.Size = Vector3.new(10, 24, 24)
            wall.Position = Vector3.new(180, 85, 0)
            wall.Parent = workspace.World.Battlefield
            local blocked = not owner.aimAllowed(endpoint)
            wall:Destroy()
            assert(blocked, "solid cover did not block server sight line")
            assert(owner.aimAllowed(endpoint), "removed wall left stale obstruction")
            -- Terrain is outside Battlefield's Instance subtree, but must still block
            -- the server sight-line seam. Preserve and restore this disposable region.
            local terrain = workspace.Terrain
            local region = Region3.new(Vector3.new(168, 76, -12), Vector3.new(192, 100, 12)):ExpandToGrid(4)
            local materials, occupancies = terrain:ReadVoxels(region, 4)
            local ok, failure = pcall(function()
                terrain:FillBlock(CFrame.new(180, 90, 0), Vector3.new(20, 20, 20), Enum.Material.Rock)
                local deadline = os.clock() + 5
                while owner.aimAllowed(endpoint) and os.clock() < deadline do
                    task.wait()
                end
                assert(not owner.aimAllowed(endpoint), "solid terrain did not block server aim")
            end)
            terrain:WriteVoxels(region, 4, materials, occupancies)
            assert(ok, tostring(failure))
        end)
    end)
    test(
        "PannedTargetProjection authored vertical envelope rejects above-roof and below-ground endpoints",
        function()
            fixture(function(owner, _match, setTime)
                setTime(0)
                assert(not owner.aimAllowed(Vector3.new(0, 33, 0)), "above authored envelope accepted")
                assert(not owner.aimAllowed(Vector3.new(0, -1.01, 0)), "below authored envelope accepted")
                assert(owner.aimAllowed(Vector3.new(0, 30, 0)), "useful elevated endpoint rejected")
            end)
        end
    )
    test("PannedTargetProjection selected muzzle obstruction rejects a clear camera ray", function()
        fixture(function(owner, _match, setTime)
            setTime(0)
            local hitbox = workspace.Aircraft.Hitbox :: BasePart
            local muzzle = hitbox:FindFirstChild("GAU23Muzzle") :: Attachment
            local endpoint = Vector3.new(0, 30, 0)
            local wall = Instance.new("Part")
            wall.Name = "P14MuzzleOnlyObstruction"
            wall.Anchored = true
            wall.Size = Vector3.one
            wall.Position = muzzle.WorldPosition + (endpoint - muzzle.WorldPosition).Unit * 2
            wall.Parent = workspace.World.Battlefield
            local parameters = RaycastParams.new()
            parameters.FilterType = Enum.RaycastFilterType.Include
            parameters.FilterDescendantsInstances = { wall }
            local cameraHit = workspace:Raycast(hitbox.Position, endpoint - hitbox.Position, parameters)
            local allowed = owner.aimAllowed(endpoint)
            wall:Destroy()
            assert(cameraHit == nil, "fixture also blocked camera ray")
            assert(not allowed, "actual weapon muzzle obstruction accepted")
            assert(owner.aimAllowed(endpoint), "removed muzzle blocker survived")
        end)
    end)
end
