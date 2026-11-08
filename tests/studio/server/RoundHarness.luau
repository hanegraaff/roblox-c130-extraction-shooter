--!strict
--[=[
    RoundHarness: test-only orchestration of actual GameRuntime and multiplayer clients.
    Runs after the foundational TestEZ suites. P03 args require three actual clients;
    absent args start the ordinary two-player-minimum local development round loop.
    Owns its test transport/listener and stops its runtime before returning EndTest evidence.
    Timeouts are wall-clock seconds; all game deadlines still use the production clock.
]=]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StudioTestService = game:GetService("StudioTestService")
local HttpService = game:GetService("HttpService")
local GameRuntime = require(game:GetService("ServerScriptService").Server.GameRuntime)
local MatchService = require(game:GetService("ServerScriptService").Server.MatchService)
local RoundHarness = {}

type Probe = {
    kind: string,
    roundId: number?,
    role: string?,
    life: string?,
    phase: string?,
    deadlineSeconds: number?,
    targetId: number?,
    sequence: number?,
}
type Case = { name: string, passed: boolean, detail: string? }

-- Bounded, yielding wait. A timeout is a test failure, never an omitted assertion.
local function awaitCondition(predicate: () -> boolean, label: string, seconds: number?)
    local deadline = os.clock() + (seconds or 25)
    while not predicate() and os.clock() < deadline do
        task.wait(0.05)
    end
    assert(predicate(), "timeout: " .. label)
end

-- Uses actual mapped production owners. Returns only after automated test completion,
-- or immediately after starting an ordinary manually operated local test runtime.
function RoundHarness.run()
    local args = StudioTestService:GetTestArgs()
    if type(args) == "table" and args.kind == "P13" then
        require(script.Parent.ExpandedMapHarness).run()
        return
    end
    if type(args) == "table" and args.kind == "P04" then
        require(script.Parent.AircraftHarness).run()
        return
    end
    if
        type(args) == "table" and (args.kind == "HumanTestControls" or args.kind == "HumanTestMultiplayer")
    then
        StudioTestService:EndTest(require(script.Parent.HumanTestCheck).run())
        return
    end
    local automated = type(args) == "table" and args.kind == "P03"
    if automated then
        awaitCondition(function()
            return #Players:GetPlayers() == 3
        end, "three actual clients join", 30)
    end
    local runtime, reason = GameRuntime.start({
        automaticDeployment = automated,
        minimumPlayers = 2,
        durationSeconds = if automated then 30 else 60,
        lobbySeconds = if automated then 8 else 0,
        deploymentSeconds = 25,
        resultsSeconds = if automated then 2 else 3,
        seed = 1,
    })
    assert(runtime, reason)
    game:BindToClose(runtime.stop)
    if not automated then
        if type(args) == "table" and args.kind == "LobbyControls" then
            local stopControls = require(script.Parent.LocalTestControls).start(runtime.rounds)
            local report = require(script.Parent.LocalTestControlsCheck).run()
            stopControls()
            runtime.stop()
            StudioTestService:EndTest(report)
        else
            local session = require(script.Parent.HumanTestSession).start(runtime)
            game:BindToClose(session.stop)
        end
        return
    end
    local cases: { Case } = {}
    local function mapSignature(): string
        local parts: { string } = {}
        for _, item in workspace.World.Battlefield:GetDescendants() do
            if item:IsA("BasePart") then
                table.insert(parts, item.Name .. ":" .. tostring(item.CFrame) .. ":" .. tostring(item.Size))
            end
        end
        table.sort(parts)
        return table.concat(parts, "|")
    end
    local initialMap = mapSignature()
    local initialConnections = 0
    -- Change real map Instances so an unchanged signature after reset proves rebuild,
    -- rather than merely observing a map which was never modified.
    local function perturbMap()
        local cover = workspace.World.Battlefield.Breakable:GetChildren()[1]
        assert(cover, "missing breakable reset fixture")
        cover:Destroy()
        local debris = Instance.new("Part")
        debris.Name = "P03TransientResetFixture"
        debris.Anchored = true
        debris.CanCollide = false
        debris.Position = Vector3.new(0, 200, 0)
        debris.Parent = workspace.World.Battlefield
        assert(mapSignature() ~= initialMap, "map fixture failed to change geometry")
    end
    local clients = Players:GetPlayers()
    local peakClientCount = #clients
    table.sort(clients, function(a, b)
        return a.UserId < b.UserId
    end)
    local slots: { [Player]: number } = {}
    for index, player in clients do
        slots[player] = index
    end
    local testRemote = Instance.new("RemoteEvent")
    testRemote.Name = "P03Harness"
    local replies: { [number]: { [Player]: { [string]: unknown } } } = {}
    local readyClients: { [Player]: boolean } = {}
    local serial = 0
    local connection = testRemote.OnServerEvent:Connect(
        function(player: Player, token: unknown, reply: unknown)
            if token == 0 and slots[player] then
                readyClients[player] = true
                return
            end
            if type(token) == "number" and replies[token] and slots[player] and type(reply) == "table" then
                replies[token][player] = reply :: { [string]: unknown }
            end
        end
    )
    testRemote.Parent = ReplicatedStorage
    local function check(name: string, callback: () -> ())
        local ok, message = pcall(function()
            callback()
            return true
        end)
        table.insert(cases, { name = name, passed = ok, detail = if ok then nil else tostring(message) })
        assert(ok, tostring(message))
    end
    local function probe(player: Player, request: Probe)
        awaitCondition(function()
            return readyClients[player] == true
        end, "client harness ready " .. tostring(slots[player]), 15)
        serial += 1
        local token = serial
        replies[token] = {}
        testRemote:FireClient(player, token, request)
        awaitCondition(function()
            return replies[token][player] ~= nil
        end, "client slot " .. tostring(slots[player]) .. " " .. request.kind, 12)
        local reply = replies[token][player]
        replies[token] = nil
        assert(
            reply.passed == true,
            "client slot " .. tostring(slots[player]) .. ": " .. tostring(reply.detail)
        )
    end
    local function activeAfter(previous: number): MatchService.Snapshot
        awaitCondition(function()
            local state = runtime.rounds.match.snapshot()
            return state.phase == "Active" and state.roundId > previous
        end, "next active round", 40)
        return runtime.rounds.match.snapshot()
    end
    local function roles(state: MatchService.Snapshot): (Player, { Player })
        local operator: Player? = nil
        local ground: { Player } = {}
        for _, player in Players:GetPlayers() do
            local member = state.members[player.UserId]
            if member and member.role == "Gunship" then
                operator = player
            elseif member and member.role == "Ground" then
                table.insert(ground, player)
            end
        end
        table.sort(ground, function(a, b)
            return a.UserId < b.UserId
        end)
        assert(operator, "missing actual operator")
        return operator, ground
    end
    local function replicated(state: MatchService.Snapshot)
        for _, player in Players:GetPlayers() do
            local member = state.members[player.UserId]
            assert(member or state.phase == "Lobby", "client missing membership")
            probe(player, {
                kind = "Observe",
                roundId = state.roundId,
                role = if member then member.role else "Waiting",
                life = if member then member.life else "Waiting",
                phase = state.phase,
                deadlineSeconds = state.deadlineSeconds,
            })
        end
    end
    local firstRound, secondRound, thirdRound = 0, 0, 0
    local ok, failure = pcall(function()
        check("A5 three actual clients receive assigned roles, phase, deadline and UI", function()
            assert(#clients == 3, "P03 harness requires exactly three actual clients")
            local state = activeAfter(0)
            firstRound = state.roundId
            local operator, ground = roles(state)
            assert(#ground == 2, "expected two actual ground players")
            replicated(state)
            local character = operator.Character
            assert(character, "operator character missing")
            local root = character:FindFirstChild("HumanoidRootPart")
            assert(root and root:IsA("BasePart") and root.Anchored, "operator must be anchored")
            assert(character:FindFirstChild("StationProtection"), "operator station protection missing")
            perturbMap()
        end)
        check("A3/A4 actual late join remains a characterless spectator and cannot act", function()
            StudioTestService:AddPlayers(1)
            awaitCondition(function()
                return #Players:GetPlayers() == 4
            end, "actual late client joins")
            peakClientCount = #Players:GetPlayers()
            local late: Player? = nil
            for _, player in Players:GetPlayers() do
                if not slots[player] then
                    late = player
                    slots[player] = 4
                end
            end
            assert(late, "late client identity missing")
            local state = runtime.rounds.match.snapshot()
            local member = state.members[late.UserId]
            assert(
                member and member.role == "Spectator" and member.life == "Spectating",
                "late join gained an active role"
            )
            assert(late.Character == nil, "late join gained a character")
            probe(late, {
                kind = "Observe",
                roundId = state.roundId,
                role = "Spectator",
                life = "Spectating",
                phase = "Active",
                deadlineSeconds = state.deadlineSeconds,
            })
            local before = runtime.rounds.match.snapshot().revision
            probe(late, { kind = "SendRejected", roundId = state.roundId, sequence = 1 })
            task.wait(0.3)
            assert(runtime.rounds.match.snapshot().revision == before, "late spectator command mutated state")
        end)
        check("A3/A4 death does not respawn; teammate spectating and command rejection", function()
            local state = runtime.rounds.match.snapshot()
            local operator, ground = roles(state)
            local dead, survivor = ground[1], ground[2]
            local original = dead.Character
            assert(original, "ground character missing")
            local humanoid = original:FindFirstChildOfClass("Humanoid")
            assert(humanoid, "ground humanoid missing")
            humanoid.Health = 0
            awaitCondition(function()
                local member = runtime.rounds.match.snapshot().members[dead.UserId]
                return member.life == "Eliminated"
            end, "ground death elimination")
            probe(dead, { kind = "Spectate", targetId = survivor.UserId, roundId = state.roundId })
            task.wait(1)
            assert(dead.Character == original or dead.Character == nil, "death created a fresh character")
            local revision = runtime.rounds.match.snapshot().revision
            probe(operator, { kind = "SendRejected", roundId = state.roundId, sequence = 1 })
            probe(dead, { kind = "SendRejected", roundId = state.roundId, sequence = 1 })
            probe(survivor, { kind = "SendRejected", roundId = state.roundId - 1, sequence = 1 })
            task.wait(0.3)
            assert(runtime.rounds.match.snapshot().revision == revision, "rejected remote mutated match")
            probe(survivor, { kind = "Surrender", roundId = state.roundId, sequence = 2 })
            awaitCondition(function()
                return runtime.rounds.match.snapshot().phase == "Results"
            end, "elimination result")
            local result = runtime.rounds.match.snapshot().result
            assert(
                result and result.winner == "Gunship" and result.reason == "GroundEliminated",
                "wrong elimination result"
            )
        end)
        check("A6 first reset restores lobby camera, roster and perturbed map", function()
            awaitCondition(function()
                return runtime.rounds.match.snapshot().phase == "Lobby"
            end, "first lobby reset")
            replicated(runtime.rounds.match.snapshot())
            for _, player in Players:GetPlayers() do
                probe(player, { kind = "LobbyCamera" })
            end
            assert(workspace.World:FindFirstChild("Battlefield"), "map lost on reset")
            assert(mapSignature() == initialMap, "first reset changed authored map")
        end)
        check("A5/A6 operator reset retains assignment and timeout is authoritative", function()
            local state = activeAfter(firstRound)
            secondRound = state.roundId
            initialConnections = runtime.rounds.resources().connections
            perturbMap()
            local operator = roles(state)
            local original = operator.Character
            assert(original, "operator character missing")
            local humanoid = original:FindFirstChildOfClass("Humanoid")
            assert(humanoid, "operator humanoid missing")
            humanoid.Health = 0
            awaitCondition(function()
                return operator.Character ~= nil and operator.Character ~= original
            end, "operator placeholder restoration")
            local restored = operator.Character
            assert(restored, "operator restore missing")
            awaitCondition(function()
                local root = restored:FindFirstChild("HumanoidRootPart")
                return root ~= nil and root:IsA("BasePart") and root.Anchored
            end, "restored operator protection")
            assert(
                runtime.rounds.match.snapshot().members[operator.UserId].role == "Gunship",
                "operator reset changed role"
            )
            assert(
                runtime.rounds.match.snapshot().deadlineSeconds == state.deadlineSeconds,
                "operator reset changed deadline"
            )
            replicated(runtime.rounds.match.snapshot())
            awaitCondition(function()
                return runtime.rounds.match.snapshot().phase == "Results"
            end, "round timeout", 35)
            local result = runtime.rounds.match.snapshot().result
            assert(
                result and result.winner == "Gunship" and result.reason == "Timeout",
                "wrong timeout result"
            )
        end)
        check("A6 second reset restores roster, camera and map", function()
            awaitCondition(function()
                return runtime.rounds.match.snapshot().phase == "Lobby"
            end, "second lobby reset")
            replicated(runtime.rounds.match.snapshot())
            for _, player in Players:GetPlayers() do
                probe(player, { kind = "LobbyCamera" })
            end
            assert(mapSignature() == initialMap, "second reset changed authored map")
        end)
        check("A6 actual ground departure removes life; operator departure forfeits", function()
            local state = activeAfter(secondRound)
            thirdRound = state.roundId
            assert(
                runtime.rounds.resources().connections == initialConnections,
                "connections accumulated between populated rounds"
            )
            perturbMap()
            local operator, ground = roles(state)
            probe(ground[1], { kind = "Leave" })
            awaitCondition(function()
                return #Players:GetPlayers() == 3
            end, "actual ground disconnect")
            local afterGround = runtime.rounds.match.snapshot()
            assert(afterGround.phase == "Active", "one departing ground ended a populated round")
            assert(
                afterGround.members[ground[1].UserId].life == "Eliminated",
                "departure retained active life"
            )
            probe(operator, { kind = "Leave" })
            awaitCondition(function()
                return runtime.rounds.match.snapshot().phase == "Results"
            end, "actual operator forfeit")
            local result = runtime.rounds.match.snapshot().result
            assert(
                result and result.winner == "Ground" and result.reason == "OperatorForfeit",
                "wrong forfeit result"
            )
        end)
        check("A6 third reset restores camera, map and complete runtime teardown", function()
            awaitCondition(function()
                return runtime.rounds.match.snapshot().phase == "Lobby"
            end, "third lobby reset")
            local remaining = Players:GetPlayers()
            assert(#remaining == 2, "expected two connected actual clients")
            replicated(runtime.rounds.match.snapshot())
            for _, player in remaining do
                probe(player, { kind = "LobbyCamera" })
            end
            assert(mapSignature() == initialMap, "third reset changed authored map")
            runtime.stop()
            runtime.stop()
            local resources = runtime.rounds.resources()
            assert(resources.connections == 0 and resources.spawnTasks == 0, "runtime resources leaked")
            assert(not ReplicatedStorage:FindFirstChild("RoundState"), "round state survived teardown")
        end)
        check("A6 pending actual avatar loads retain ownership and accounting until drained", function()
            require(script.Parent.CharacterCleanup).run()
        end)
    end)
    if not ok then
        table.insert(cases, { name = "Harness completion", passed = false, detail = tostring(failure) })
    end
    runtime.stop()
    connection:Disconnect()
    testRemote:Destroy()
    local passed = 0
    for _, case in cases do
        if case.passed then
            passed += 1
        end
    end
    local report = {
        suite = "P03-multiplayer",
        environment = "Studio",
        clientCount = peakClientCount,
        initialClientCount = #clients,
        completedRoundIds = { firstRound, secondRound, thirdRound },
        discovered = #cases,
        passed = passed,
        failed = #cases - passed,
        skipped = 0,
        cases = cases,
    }
    workspace:SetAttribute("P03MultiplayerReport", HttpService:JSONEncode(report))
    StudioTestService:EndTest(report)
end

return RoundHarness
