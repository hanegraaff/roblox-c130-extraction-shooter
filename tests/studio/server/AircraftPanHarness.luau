--!strict
--[=[
    P14 actual two-client orchestration. Owns GameRuntime, excluded transport and
    thermal fixtures; asks the production operator controller to pan through injected
    raw pointer input, never a focus assignment. Both FOVs span full production orbits.
    Actual MCP operated review separately verifies native mouse/keys/buttons and feel.
    All deadlines are wall-clock seconds and every failure survives structured EndTest.
]=]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StudioTestService = game:GetService("StudioTestService")
local CollectionService = game:GetService("CollectionService")
local GameRuntime = require(game.ServerScriptService.Server.GameRuntime)
local Harness = {}
type Request = {
    kind: string,
    point: Vector3?,
    building: string?,
    category: string?,
    weapon: string?,
    position: Vector3?,
    payload: unknown?,
}
type Case = { name: string, passed: boolean, detail: string? }
local function waitFor(predicate: () -> boolean, label: string, seconds: number?)
    local deadline = os.clock() + (seconds or 25)
    while not predicate() and os.clock() < deadline do
        task.wait(0.05)
    end
    assert(predicate(), "P14 server timeout: " .. label)
end
function Harness.run(arrivalRegression: boolean?)
    waitFor(function()
        return #Players:GetPlayers() == 2
    end, "two actual clients", 30)
    local runtime, reason = GameRuntime.start({
        automaticDeployment = false,
        minimumPlayers = 2,
        durationSeconds = 600,
        lobbySeconds = 0,
        deploymentSeconds = 25,
        resultsSeconds = 1,
        seed = 1,
    })
    assert(runtime, reason)
    local remote = Instance.new("RemoteEvent")
    remote.Name = "P14Harness"
    local ready: { [Player]: unknown } = {}
    local replies: { [number]: { [Player]: { [string]: unknown } } } = {}
    local listener = remote.OnServerEvent:Connect(function(player: Player, token: unknown, payload: unknown)
        if token == 0 then
            ready[player] = payload
        elseif type(token) == "number" and replies[token] and type(payload) == "table" then
            replies[token][player] = payload :: { [string]: unknown }
        end
    end)
    remote.Parent = ReplicatedStorage
    local serial = 0
    local cases: { Case } = {}
    local observations: { unknown } = {}
    local function check(name: string, callback: () -> ())
        local ok, failure = pcall(function()
            callback()
            return true
        end)
        table.insert(cases, { name = name, passed = ok, detail = if ok then nil else tostring(failure) })
        assert(ok, tostring(failure))
    end
    local function probe(player: Player, request: Request)
        waitFor(function()
            return ready[player] ~= nil
        end, "client ready", 35)
        serial += 1
        local token = serial
        replies[token] = {}
        remote:FireClient(player, token, request)
        waitFor(function()
            return replies[token][player] ~= nil
        end, "client " .. request.kind, 20)
        local reply = replies[token][player]
        table.insert(observations, {
            userId = player.UserId,
            request = request.kind,
            target = request.building or request.category,
            weapon = request.weapon,
            passed = reply.passed,
            detail = reply.detail,
            observations = reply.observations,
        })
        replies[token] = nil
        assert(reply.passed == true, tostring(reply.detail))
    end
    local function roles(): (Player, Player)
        local operator: Player? = nil
        local ground: Player? = nil
        for _, player in Players:GetPlayers() do
            if player:GetAttribute("Role") == "Gunship" then
                operator = player
            elseif player:GetAttribute("Role") == "Ground" then
                ground = player
            end
        end
        assert(operator and ground, "actual operator/ground roles absent")
        return operator, ground
    end
    local function deploy()
        assert(runtime.rounds.match.deploy(), "P14 deployment rejected")
        waitFor(function()
            return runtime.rounds.match.snapshot().phase == "Active"
        end, "active", 35)
    end
    local function surface(x: number, z: number): Vector3
        local parameters = RaycastParams.new()
        parameters.FilterType = Enum.RaycastFilterType.Include
        parameters.FilterDescendantsInstances = { workspace.World.Battlefield, workspace.Terrain }
        parameters.RespectCanCollide = true
        local result = workspace:Raycast(Vector3.new(x, 80, z), Vector3.new(0, -100, 0), parameters)
        assert(result, "required map surface absent")
        return result.Position
    end
    local function upperPanel(buildingName: string): Vector3
        local building = workspace.World.Battlefield.Buildings:FindFirstChild(buildingName)
        assert(building, "building missing")
        local panels = building:FindFirstChild(buildingName .. "_Panels")
        assert(panels, "upper-floor panel registry missing")
        local origin = workspace.Aircraft:GetPivot().Position
        local parameters = RaycastParams.new()
        parameters.FilterType = Enum.RaycastFilterType.Include
        parameters.FilterDescendantsInstances = { workspace.World.Battlefield, workspace.Terrain }
        parameters.RespectCanCollide = true
        for _, panel in panels:GetChildren() do
            if
                panel:IsA("BasePart")
                and panel:GetAttribute("StoryId") == "02"
                and not string.find(panel.Name, "Roof", 1, true)
            then
                local hit = workspace:Raycast(origin, panel.Position - origin, parameters)
                if hit and hit.Instance == panel then
                    return hit.Position
                end
            end
        end
        error("no currently visible upper-floor panel in " .. buildingName)
    end
    local thermal: Folder? = nil
    local ok, failure = pcall(function()
        deploy()
        local operator, ground = roles()
        if arrivalRegression then
            check(
                "P14 arrival regression transitions from input-driven steering to a committed target-pointing frame",
                function()
                    probe(
                        operator,
                        { kind = "Projection", point = surface(0, 0), weapon = "GAU23", category = "Ground" }
                    )
                    probe(operator, {
                        kind = "Projection",
                        point = surface(220, 220),
                        weapon = "GAU23",
                        category = "Ground",
                    })
                    probe(ground, { kind = "Ground" })
                end
            )
            return true
        end
        check(
            "PannedTargetProjection both FOVs cover center quadrants boundary slopes and three upper-floor panels over full orbits",
            function()
                probe(operator, { kind = "EdgeFrames" })
                for _, weapon in { "GAU23", "M102" } do
                    local started = os.clock()
                    for index, point in
                        {
                            { 0, 0 },
                            { 220, 220 },
                            { -220, 220 },
                            { -220, -220 },
                            { 220, -220 },
                            { 350, 0 },
                            { 0, 350 },
                            { -350, 0 },
                            { 0, -350 },
                            { -240, -140 },
                            { 135, 260 },
                        }
                    do
                        probe(operator, {
                            kind = "Projection",
                            point = surface(point[1], point[2]),
                            weapon = weapon,
                            category = if index >= 10 then "TerrainSlope" else "Ground",
                        })
                    end
                    for _, building in { "Foundry", "Warehouse", "Outpost" } do
                        probe(operator, {
                            kind = "Projection",
                            point = upperPanel(building),
                            building = building,
                            weapon = weapon,
                        })
                    end
                    task.wait(math.max(0, 91 - (os.clock() - started)))
                    probe(operator, { kind = "OrbitSummary", weapon = weapon })
                    probe(ground, { kind = "Ground" })
                end
            end
        )
        check(
            "P14 acknowledged zoom and rejected selection preserve world-space pan and ground camera",
            function()
                probe(operator, { kind = "Projection", point = surface(180, -180), weapon = "GAU23" })
                probe(operator, { kind = "Coherence", weapon = "M102" })
                probe(operator, { kind = "Reject" })
                probe(operator, { kind = "Coherence", weapon = "GAU23" })
                probe(ground, { kind = "Ground" })
            end
        )
        check("P14 blocked UI outside-window input and recenter retain bounded ownership", function()
            probe(operator, { kind = "Blocked" })
        end)
        check("P14 slope and upper-floor targets retain actual occluded thermal configuration", function()
            local fixtures = Instance.new("Folder")
            fixtures.Name = "P14ThermalFixtures"
            fixtures.Parent = workspace.World.Battlefield
            thermal = fixtures
            local upperMarker =
                workspace.World.Battlefield.Buildings.Foundry.Foundry_Navigation.Foundry_Walk05 :: BasePart
            for index, point in
                { surface(-240, -140) + Vector3.new(0, 3, 0), upperMarker.Position + Vector3.new(0, 1, 0) }
            do
                local model = Instance.new("Model")
                model.Name = if index == 1 then "Slope" else "UpperFloorHeight"
                local body = Instance.new("Part")
                body.Name = "Body"
                body.Anchored = true
                body.Size = Vector3.new(2, 4, 2)
                body.Position = point
                body.Parent = model
                model.Parent = fixtures
                CollectionService:AddTag(model, "ThermalTarget")
            end
            task.wait(0.2)
            probe(operator, { kind = "Thermal" })
            fixtures:Destroy()
            thermal = nil
        end)
        check(
            "P14 result role loss and new-round operator entry reset focus without duplicate ownership",
            function()
                probe(operator, { kind = "ResetInput" })
                assert(
                    runtime.rounds.match.abort(runtime.rounds.match.snapshot().roundId, "P14Reset"),
                    "round abort failed"
                )
                probe(operator, { kind = "Normal" })
                waitFor(function()
                    return runtime.rounds.match.snapshot().phase == "Lobby"
                end, "reset lobby")
                deploy()
                operator, ground = roles()
                probe(operator, { kind = "ResetInput" })
                probe(ground, { kind = "Ground" })
                probe(operator, { kind = "Projection", point = surface(-180, 180), weapon = "M102" })
                operator:Kick("P14 actual operator departure")
                waitFor(function()
                    return #Players:GetPlayers() == 1 and runtime.rounds.match.snapshot().phase == "Results"
                end, "actual departure")
                probe(ground, { kind = "Normal" })
            end
        )
        return true
    end)
    if not ok then
        table.insert(cases, { name = "Harness completion", passed = false, detail = tostring(failure) })
    end
    if thermal then
        thermal:Destroy()
    end
    local cleanupOK, cleanupFailure = pcall(function()
        runtime.stop()
        runtime.stop()
        waitFor(function()
            return runtime.rounds.resources().spawnTasks == 0
        end, "avatar teardown drain", 30)
        assert(
            runtime.rounds.resources().connections == 0 and runtime.aircraft.resources().connections == 0,
            "owned listeners survived teardown"
        )
        assert(
            not workspace:FindFirstChild("Aircraft") and not ReplicatedStorage:FindFirstChild("RoundState"),
            "runtime state survived teardown"
        )
    end)
    table.insert(cases, {
        name = "P14 repeated teardown releases runtime aircraft and transport ownership",
        passed = cleanupOK,
        detail = if cleanupOK then nil else tostring(cleanupFailure),
    })
    listener:Disconnect()
    remote:Destroy()
    local baselines: { unknown } = {}
    for player, report in ready do
        table.insert(baselines, { userId = player.UserId, report = report })
    end
    local passed = 0
    for _, case in cases do
        if case.passed then
            passed += 1
        end
    end
    StudioTestService:EndTest({
        suite = if arrivalRegression then "P14-arrival-regression" else "P14-multiplayer",
        environment = "Studio",
        clientCount = 2,
        discovered = #cases,
        passed = passed,
        failed = #cases - passed,
        skipped = 0,
        cases = cases,
        observations = observations,
        serverBaseline = workspace:GetAttribute("ServerTestReport"),
        clientBaselines = baselines,
        projectionPixelTolerance = 1,
        projectionWorldToleranceStuds = 0.5,
        orbitSecondsPerWeapon = if arrivalRegression then 0 else 90,
    })
end
return Harness
