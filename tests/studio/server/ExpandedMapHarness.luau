--!strict
--[=[
    P13 A4–A6 automated acceptance with actual two-client roles, real Humanoid stair
    locomotion, two perturbed resets and an actual late third client. Test-only transport
    and fixtures are owned/removed. All waits are bounded; no waypoint teleports occur
    between each building's outside entry and usable upper floor.
]=]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StudioTestService = game:GetService("StudioTestService")
local GameRuntime = require(game.ServerScriptService.Server.GameRuntime)
local Harness = {}
local HttpService = game:GetService("HttpService")
type Case = { name: string, passed: boolean, detail: string? }
local function awaitCondition(predicate: () -> boolean, label: string, seconds: number?)
    local deadline = os.clock() + (seconds or 20)
    while not predicate() and os.clock() < deadline do
        task.wait(0.05)
    end
    assert(predicate(), "P13 timeout: " .. label)
end
-- Clients compare numeric components with a 0.001-stud/component tolerance,
-- without rounded-string boundaries. Sorted names keep observations reviewable.
local function observationsJSON(): string
    local values: {
        {
            name: string,
            className: string,
            shape: string,
            pose: { number },
            size: { number },
            anchored: boolean,
            collide: boolean,
            query: boolean,
            touch: boolean,
        }
    } =
        {}
    for _, item in workspace.World.Battlefield:GetDescendants() do
        if item:IsA("BasePart") then
            table.insert(values, {
                name = item.Name,
                className = item.ClassName,
                shape = if item:IsA("Part") then item.Shape.Name else item.ClassName,
                pose = { item.CFrame:GetComponents() },
                size = { item.Size.X, item.Size.Y, item.Size.Z },
                anchored = item.Anchored,
                collide = item.CanCollide,
                query = item.CanQuery,
                touch = item.CanTouch,
            })
        end
    end
    table.sort(values, function(first, second)
        return first.name < second.name
    end)
    return HttpService:JSONEncode(values)
end

-- Same-server reset equality has no network float conversion. Explicitly ordered
-- fields avoid relying on JSON object-key serialization order for exact comparisons.
local function signature(): string
    local values: { string } = {}
    for _, item in workspace.World.Battlefield:GetDescendants() do
        if item:IsA("BasePart") then
            table.insert(
                values,
                table.concat({
                    item.Name,
                    item.ClassName,
                    tostring(item.CFrame),
                    tostring(item.Size),
                    tostring(item.Anchored),
                    tostring(item.CanCollide),
                    tostring(item.CanQuery),
                    tostring(item.CanTouch),
                }, ":")
            )
        end
    end
    table.sort(values)
    return table.concat(values, "|")
end

-- ExecuteMultiplayerTestAsync(2,{kind="P13"}); returns a structured actual-client report.
function Harness.run()
    awaitCondition(function()
        return #Players:GetPlayers() == 2
    end, "two initial clients", 30)
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
    remote.Name = "P13Harness"
    local ready: { [Player]: boolean } = {}
    local replies: { [number]: { [Player]: { [string]: unknown } } } = {}
    local serial = 0
    local listener = remote.OnServerEvent:Connect(function(player: Player, token: unknown, payload: unknown)
        if token == 0 then
            ready[player] = true
        elseif type(token) == "number" and replies[token] and type(payload) == "table" then
            replies[token][player] = payload :: { [string]: unknown }
        end
    end)
    remote.Parent = ReplicatedStorage
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
    local function probeAll()
        for _, player in Players:GetPlayers() do
            awaitCondition(function()
                return ready[player] == true
            end, "client ready", 30)
            serial += 1
            local token = serial
            replies[token] = {}
            remote:FireClient(player, token, observationsJSON())
            awaitCondition(function()
                return replies[token][player] ~= nil
            end, "replicated world", 16)
            local reply = replies[token][player]
            assert(reply.passed == true, tostring(reply.detail))
            table.insert(
                observations,
                { userId = player.UserId, detail = reply.detail, baseline = reply.baseline }
            )
            replies[token] = nil
        end
    end
    local function deploy()
        assert(runtime.rounds.match.deploy(), "P13 deploy failed")
        awaitCondition(function()
            return runtime.rounds.match.snapshot().phase == "Active"
        end, "active round", 35)
    end
    local walked: { string } = {}
    local peak = 2
    local ok, failure = pcall(function()
        check(
            "ExpandedMapReplication two actual clients agree on source geometry terrain panels and aircraft",
            function()
                deploy()
                probeAll()
            end
        )
        check(
            "ExpandedMapNavigation actual ground avatar enters every building and walks every upper floor",
            function()
                local player: Player? = nil
                for _, candidate in Players:GetPlayers() do
                    if candidate:GetAttribute("Role") == "Ground" then
                        player = candidate
                    end
                end
                assert(player and player.Character, "actual ground avatar missing")
                local character = player.Character
                local humanoid = character:FindFirstChildOfClass("Humanoid")
                local root = character:FindFirstChild("HumanoidRootPart")
                assert(humanoid and root and root:IsA("BasePart"), "actual humanoid/root missing")
                root:SetNetworkOwner(nil)
                local buildings = workspace.World.Battlefield:FindFirstChild("Buildings") :: Folder
                for _, building in buildings:GetChildren() do
                    local nav = building:FindFirstChild(building.Name .. "_Navigation") :: Folder
                    local entry = nav:FindFirstChild(building.Name .. "_Walk01") :: BasePart
                    character:PivotTo(entry.CFrame)
                    root.AssemblyLinearVelocity = Vector3.zero
                    task.wait(0.3)
                    for index = 2, 5 do
                        local marker =
                            nav:FindFirstChild(string.format("%s_Walk%02d", building.Name, index)) :: BasePart
                        humanoid:MoveTo(marker.Position)
                        awaitCondition(function()
                            return (root.Position - marker.Position).Magnitude < 3
                        end, building.Name .. " waypoint " .. index, 12)
                    end
                    assert(root.Position.Y > 12, "avatar never reached upper floor")
                    table.insert(walked, building.Name)
                end
                root:SetNetworkOwnershipAuto()
            end
        )
        check(
            "ExpandedMapReplication two perturbed round resets restore terrain geometry IDs and panels",
            function()
                local initial = signature()
                for _ = 1, 2 do
                    local map = workspace.World.Battlefield
                    local buildings = map:FindFirstChild("Buildings") :: Folder
                    local building = buildings:GetChildren()[1]
                    local panels = building:FindFirstChild(building.Name .. "_Panels") :: Folder
                    panels:GetChildren()[1]:Destroy()
                    local transient = Instance.new("Part")
                    transient.Name = "P13RuntimeTransient"
                    transient.Anchored = true
                    transient.Parent = map
                    workspace.Terrain:FillBall(Vector3.new(-260, 20, -140), 12, Enum.Material.Sand)
                    local round = runtime.rounds.match.snapshot().roundId
                    assert(runtime.rounds.match.abort(round, "P13FixtureReset"), "reset abort failed")
                    awaitCondition(function()
                        return runtime.rounds.match.snapshot().phase == "Lobby"
                    end, "reset lobby")
                    assert(signature() == initial, "reset changed geometry or retained transient")
                    deploy()
                    probeAll()
                end
            end
        )
        check(
            "ExpandedMapReplication actual late third client observes rebuilt map and stays spectator",
            function()
                StudioTestService:AddPlayers(1)
                awaitCondition(function()
                    return #Players:GetPlayers() == 3
                end, "actual late join", 30)
                peak = #Players:GetPlayers()
                probeAll()
                local spectators = 0
                for _, player in Players:GetPlayers() do
                    if player:GetAttribute("Role") == "Spectator" then
                        spectators += 1
                        assert(player.Character == nil, "late spectator gained character")
                    end
                end
                assert(spectators == 1, "late join did not stay spectator")
            end
        )
    end)
    if not ok then
        table.insert(cases, { name = "Harness completion", passed = false, detail = tostring(failure) })
    end
    -- Teardown is independent of late-client launch and other gameplay scenarios.
    -- Preserve their failures, then always record this required resource assertion.
    local cleanupOK, cleanupFailure = pcall(function()
        check("ExpandedMapCleanup repeated teardown releases round aircraft transport ownership", function()
            runtime.stop()
            runtime.stop()
            local resources = runtime.rounds.resources()
            assert(
                resources.connections == 0 and resources.spawnTasks == 0,
                "round ownership survived teardown"
            )
            assert(
                runtime.aircraft.resources().connections == 0 and not workspace:FindFirstChild("Aircraft"),
                "aircraft survived teardown"
            )
        end)
        return true
    end)
    if not cleanupOK then
        warn("P13 cleanup assertion failed: " .. tostring(cleanupFailure))
    end
    runtime.stop()
    listener:Disconnect()
    remote:Destroy()
    local passed = 0
    for _, case in cases do
        if case.passed then
            passed += 1
        end
    end
    StudioTestService:EndTest({
        suite = "P13-multiplayer",
        environment = "Studio",
        initialClientCount = 2,
        clientCount = peak,
        discovered = #cases,
        passed = passed,
        failed = #cases - passed,
        skipped = 0,
        cases = cases,
        walkedBuildings = walked,
        observations = observations,
        serverBaseline = workspace:GetAttribute("ServerTestReport"),
    })
end
return Harness
