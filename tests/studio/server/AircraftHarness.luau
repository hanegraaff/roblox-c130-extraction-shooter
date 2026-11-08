--!strict
--[=[
    AircraftHarness: P04 automated acceptance against actual GameRuntime and two
    distinct Studio network clients. Samples a full 90-second production orbit;
    8-stud convergence bound allows <=0.32s replication age at 25.13 studs/second on the expanded map.
    No local visual shell or secondary hitbox exists. Test-only transport is excluded
    from release. All waits are bounded; failures remain in EndTest's structured report.
]=]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local StudioTestService = game:GetService("StudioTestService")
local CollectionService = game:GetService("CollectionService")
local GameRuntime = require(game:GetService("ServerScriptService").Server.GameRuntime)
local AircraftHarness = {}
type Request = {
    kind: string,
    position: Vector3?,
    weapon: string?,
    sequence: number?,
    roundId: number?,
    role: string?,
    payload: unknown?,
}
type Case = { name: string, passed: boolean, detail: string? }
local function awaitCondition(predicate: () -> boolean, label: string, seconds: number?)
    local deadline = os.clock() + (seconds or 15)
    while not predicate() and os.clock() < deadline do
        task.wait(0.03)
    end
    assert(predicate(), "P04 timeout: " .. label)
end
-- Runs one bounded two-round session and owns all temporary transport/fixtures.
function AircraftHarness.run()
    awaitCondition(function()
        return #Players:GetPlayers() == 2
    end, "two actual clients", 30)
    local runtime, reason = GameRuntime.start({
        automaticDeployment = false,
        minimumPlayers = 2,
        durationSeconds = 180,
        lobbySeconds = 0,
        deploymentSeconds = 25,
        resultsSeconds = 2,
        seed = 1,
    })
    assert(runtime, reason)
    local transport = Instance.new("RemoteEvent")
    transport.Name = "P04Harness"
    local ready: { [Player]: unknown } = {}
    local replies: { [number]: { [Player]: { [string]: unknown } } } = {}
    local serial = 0
    local listener = transport.OnServerEvent:Connect(
        function(player: Player, token: unknown, payload: unknown)
            if token == 0 then
                ready[player] = payload
                return
            end
            if type(token) == "number" and replies[token] and type(payload) == "table" then
                replies[token][player] = payload :: { [string]: unknown }
            end
        end
    )
    transport.Parent = ReplicatedStorage
    local cases: { Case } = {}
    local observations: { unknown } = {}
    local initialClients = Players:GetPlayers()
    local function check(name: string, callback: () -> ())
        local ok, failure = pcall(function()
            callback()
            return true
        end)
        table.insert(cases, { name = name, passed = ok, detail = if ok then nil else tostring(failure) })
        assert(ok, tostring(failure))
    end
    local function probe(player: Player, request: Request)
        awaitCondition(function()
            return ready[player] ~= nil
        end, "actual client ready")
        serial += 1
        local token = serial
        replies[token] = {}
        transport:FireClient(player, token, request)
        awaitCondition(function()
            return replies[token][player] ~= nil
        end, "client " .. request.kind, 12)
        local reply = replies[token][player]
        replies[token] = nil
        assert(reply.passed == true, tostring(reply.detail))
        table.insert(
            observations,
            { kind = request.kind, userId = player.UserId, observations = reply.observations }
        )
    end
    local function selection(): { roundId: number, revision: number, weapon: string }
        local encoded = ReplicatedStorage.AircraftState:GetAttribute("Selection")
        assert(type(encoded) == "string", "selection commit missing")
        return HttpService:JSONDecode(encoded)
    end
    local function roles(): (Player, Player)
        local operator: Player? = nil
        local ground: Player? = nil
        for _, player in Players:GetPlayers() do
            if player:GetAttribute("Role") == "Gunship" then
                operator = player
            end
            if player:GetAttribute("Role") == "Ground" then
                ground = player
            end
        end
        assert(operator and ground, "actual roles missing")
        return operator, ground
    end
    local function deploy()
        assert(runtime.rounds.match.deploy(), "manual harness deployment failed")
        awaitCondition(function()
            return runtime.rounds.match.snapshot().phase == "Active"
        end, "actual deployment", 35)
    end
    local fixture = Instance.new("Folder")
    fixture.Name = "P04ThermalFixtures"
    fixture.Parent = workspace.World.Battlefield
    local function target(name: string, position: Vector3)
        local model = Instance.new("Model")
        model.Name = name
        local body = Instance.new("Part")
        body.Name = "ThermalBody"
        body.Size = Vector3.new(5, 10, 5)
        body.Anchored = true
        body.Position = position
        body.Color = Color3.fromRGB(90, 110, 120)
        body.Parent = model
        model.Parent = fixture
        CollectionService:AddTag(model, "ThermalTarget")
        return body
    end
    local exposed = target("P04ExposedTarget", Vector3.new(0, 35, 30))
    local covered = target("P04CoveredTarget", Vector3.new(0, 5, -30))
    local wall = Instance.new("Part")
    wall.Name = "P04ThermalWall"
    wall.Anchored = true
    wall.Size = Vector3.new(2, 25, 22)
    wall.Position = Vector3.new(12, 12, -30)
    wall.Parent = fixture
    local roof = Instance.new("Part")
    roof.Name = "P04ThermalRoof"
    roof.Anchored = true
    roof.Size = Vector3.new(26, 2, 22)
    roof.Position = Vector3.new(0, 25, -30)
    roof.Parent = fixture
    local firstRound = 0
    local ok, failure = pcall(function()
        check("A2/A4 initial canonical pose and both acknowledged zoom profiles stay inward", function()
            deploy()
            firstRound = runtime.rounds.match.snapshot().roundId
            local operator, ground = roles()
            probe(operator, { kind = "Profile", weapon = "GAU23" })
            probe(operator, { kind = "Send", roundId = firstRound, sequence = 1, weapon = "M102" })
            awaitCondition(function()
                return selection().weapon == "M102"
            end, "wide selection acknowledged")
            probe(operator, { kind = "Profile", weapon = "M102" })
            probe(
                ground,
                { kind = "Pose", position = workspace.Aircraft:GetPivot().Position, role = "Ground" }
            )
        end)
        check(
            "A4 stale malformed wrong-role duplicate and unknown selections preserve acknowledged view",
            function()
                local operator, ground = roles()
                local before = selection().revision
                probe(ground, { kind = "Send", roundId = firstRound, sequence = 1, weapon = "GAU23" })
                for _, payload in
                    {
                        { roundId = firstRound - 1, sequence = 2, weapon = "GAU23" },
                        { roundId = firstRound, sequence = 1, weapon = "GAU23" },
                        { roundId = firstRound, sequence = 2, weapon = "M7" },
                        { roundId = firstRound, sequence = 2, weapon = "GAU23", extra = true },
                    }
                do
                    probe(operator, { kind = "Send", payload = payload })
                end
                task.wait(0.3)
                assert(
                    selection().revision == before and selection().weapon == "M102",
                    "rejected selection mutated authoritative profile"
                )
                probe(operator, { kind = "Profile", weapon = "M102" })
                task.wait(0.5)
                probe(operator, { kind = "Send", roundId = firstRound, sequence = 2, weapon = "GAU23" })
                awaitCondition(function()
                    return selection().weapon == "GAU23"
                end, "valid traffic after rejection")
                probe(operator, { kind = "Profile", weapon = "GAU23" })
            end
        )
        check("A5 exposed and covered real geometry uses occluded thermal rendering", function()
            local operator = roles()
            local origin = workspace.Aircraft:GetPivot().Position
            local parameters = RaycastParams.new()
            parameters.FilterType = Enum.RaycastFilterType.Include
            parameters.FilterDescendantsInstances = { fixture }
            local clear = workspace:Raycast(origin, exposed.Position - origin, parameters)
            local blocked = workspace:Raycast(origin, covered.Position - origin, parameters)
            assert(clear and clear.Instance == exposed, "exposed thermal fixture not visible to real ray")
            assert(
                blocked and blocked.Instance ~= covered,
                "solid fixture failed to occlude covered thermal body"
            )
            probe(operator, { kind = "Thermal" })
        end)
        check(
            "A2/A3 two actual clients converge at nine samples spanning a complete production orbit",
            function()
                local operator, ground = roles()
                local started = os.clock()
                for sample = 0, 8 do
                    awaitCondition(function()
                        return os.clock() - started >= sample * 90 / 8
                    end, "next full-orbit sample", 14)
                    local pose = workspace.Aircraft:GetPivot()
                    local epoch = ReplicatedStorage.AircraftState:GetAttribute("EpochSeconds")
                    assert(type(epoch) == "number", "orbit epoch missing")
                    local expected = runtime.aircraft.sample(workspace:GetServerTimeNow() - epoch)
                    assert(
                        (pose.Position - expected.Position).Magnitude < 2,
                        "server canonical orbit drift beyond heartbeat budget"
                    )
                    assert(pose.LookVector:Dot(expected.LookVector) > 0.9999, "server tangent drift")
                    probe(operator, { kind = "Pose", position = pose.Position, role = "Gunship" })
                    probe(ground, { kind = "Pose", position = pose.Position, role = "Ground" })
                    if sample == 4 then
                        probe(
                            operator,
                            { kind = "Send", roundId = firstRound, sequence = 3, weapon = "M102" }
                        )
                        awaitCondition(function()
                            return selection().weapon == "M102"
                        end, "mid-orbit wide profile")
                        probe(operator, { kind = "Profile", weapon = "M102" })
                    end
                end
            end
        )
        check("A2/A5 result and reset restore initial profile camera input and effects", function()
            local operator, ground = roles()
            assert(runtime.rounds.match.abort(firstRound, "P04FixtureReset"), "harness abort")
            awaitCondition(function()
                return runtime.rounds.match.snapshot().phase == "Lobby"
            end, "lobby reset")
            probe(operator, { kind = "Restored" })
            probe(ground, { kind = "Restored" })
            assert(selection().weapon == "GAU23", "lobby reset retained previous weapon")
            assert(not fixture:IsDescendantOf(workspace), "map reset retained test fixtures")
            deploy()
            local nextOperator = roles()
            probe(nextOperator, { kind = "Profile", weapon = "GAU23" })
            local hudCount = 0
            for _, player in Players:GetPlayers() do
                probe(player, {
                    kind = "Pose",
                    position = workspace.Aircraft:GetPivot().Position,
                    role = tostring(player:GetAttribute("Role")),
                })
                if player:GetAttribute("Role") == "Gunship" then
                    hudCount += 1
                end
            end
            assert(hudCount == 1, "repeat entry must have exactly one operator")
        end)
        check(
            "A5 actual operator disconnect forfeits and server teardown removes all aircraft ownership",
            function()
                local operator = roles()
                probe(operator, { kind = "Leave" })
                awaitCondition(function()
                    return #Players:GetPlayers() == 1 and runtime.rounds.match.snapshot().phase == "Results"
                end, "actual operator disconnect")
                local result = runtime.rounds.match.snapshot().result
                assert(result and result.reason == "OperatorForfeit", "aircraft changed disconnect result")
                runtime.stop()
                runtime.stop()
                assert(
                    runtime.aircraft.resources().connections == 0,
                    "aircraft connections survived teardown"
                )
                assert(
                    not workspace:FindFirstChild("Aircraft")
                        and not ReplicatedStorage:FindFirstChild("AircraftState"),
                    "aircraft instances survived teardown"
                )
            end
        )
    end)
    if not ok then
        table.insert(cases, { name = "Harness completion", passed = false, detail = tostring(failure) })
    end
    fixture:Destroy()
    runtime.stop()
    listener:Disconnect()
    transport:Destroy()
    local passed = 0
    for _, case in cases do
        if case.passed then
            passed += 1
        end
    end
    local baselineClients: { unknown } = {}
    for _, player in initialClients do
        table.insert(baselineClients, ready[player])
    end
    local report = {
        suite = "P04-multiplayer",
        environment = "Studio",
        clientCount = 2,
        discovered = #cases,
        passed = passed,
        failed = #cases - passed,
        skipped = 0,
        cases = cases,
        observations = observations,
        serverBaseline = workspace:GetAttribute("ServerTestReport"),
        clientBaselines = baselineClients,
        poseToleranceStuds = 8,
        orbitSeconds = 90,
    }
    workspace:SetAttribute("P04MultiplayerReport", HttpService:JSONEncode(report))
    StudioTestService:EndTest(report)
end
return AircraftHarness
