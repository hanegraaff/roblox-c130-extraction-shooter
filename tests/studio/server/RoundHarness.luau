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
local RunService = game:GetService("RunService")
local GameRuntime = require(game:GetService("ServerScriptService").Server.GameRuntime)
local MatchService = require(game:GetService("ServerScriptService").Server.MatchService)
local MatchRuntime = require(game:GetService("ServerScriptService").Server.MatchRuntime)
local RoundHarness = {}

type Probe = {
    kind: string,
    roundId: number?,
    role: string?,
    life: string?,
    phase: string?,
    deadlineSeconds: number?,
    intermissionUntil: number?,
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
    -- Reject archived selectors before any old coordinator can acquire owners.
    local compatibility = require(ReplicatedStorage.HarnessCompatibility)
    local requestedArgs = StudioTestService:GetTestArgs()
    local settings = game:GetService("ServerStorage"):FindFirstChild("DevelopmentSettings")
    local kind = if type(requestedArgs) == "table"
        then requestedArgs.kind
        elseif settings then settings:GetAttribute("ManualHarness")
        else nil
    if type(kind) == "string" then
        local reason = compatibility.reason(kind)
        if reason then
            workspace:SetAttribute(
                "HarnessCompatibilityReport",
                HttpService:JSONEncode({
                    kind = kind,
                    rejected = true,
                    reason = reason,
                    replacement = "P18",
                    discovered = 0,
                    passed = 0,
                    failed = 1,
                    skipped = 0,
                })
            )
            compatibility.assertCurrent(kind)
        end
    end
    -- P17's native UI route is selected before consulting any SDK arguments.
    -- The marker exists only in the local test mapping and has no client remote.
    local p17Settings = game:GetService("ServerStorage"):FindFirstChild("DevelopmentSettings")
    if
        RunService:IsStudio()
        and p17Settings
        and p17Settings:IsA("ModuleScript")
        and p17Settings:GetAttribute("ManualHarness") == "P17"
    then
        require(script.Parent.P17ManualRunner).run()
        return
    end
    local args = StudioTestService:GetTestArgs()
    if kind == "P26" then
        require(script.Parent.BalanceHarness).run(type(args) == "table")
        return
    elseif kind == "P26Panel" and args == nil then
        require(script.Parent.BalanceHarness).preview()
        return
    end
    if kind == "P29" then
        local review = if type(args) == "table"
            then args.reviewSeconds
            elseif settings then settings:GetAttribute("P29ReviewSeconds")
            else nil
        require(script.Parent.DepotLauncherHarness).run(
            type(args) == "table",
            if type(review) == "number" and review == review then math.clamp(review, 0, 25) else 0
        )
        return
    end
    if kind == "P30" then
        local touchReview = if type(args) == "table"
            then args.touchReview
            elseif settings then settings:GetAttribute("P30TouchReview")
            else nil
        require(script.Parent.MedkitHarness).run(type(args) == "table", touchReview == true)
        return
    end
    if kind == "P24" or kind == "P28" then
        require(script.Parent.AircraftArrivalHarness).run(type(args) == "table", kind == "P28")
        return
    end
    -- A trusted, temporary server-only invocation marker supports Studio's native
    -- Server & Clients UI when the SDK spawn path is unavailable. It is absent from
    -- Git defaults and the release mapping; no client remote can set it. Dispatch
    -- before the ordinary HumanTestSession acquires its competing runtime owner.
    local development = game:GetService("ServerStorage"):FindFirstChild("DevelopmentSettings")
    if
        RunService:IsStudio()
        and args == nil
        and development
        and development:IsA("ModuleScript")
        and development:GetAttribute("ManualHarness") == "P14"
    then
        local invocation = {
            mode = "manual-server-clients",
            harness = "P14",
            requestedClients = 2,
            selector = "ServerStorage.DevelopmentSettings.ManualHarness",
            selectorValue = "P14",
            studioOnly = true,
        }
        workspace:SetAttribute("ManualP14Invocation", HttpService:JSONEncode(invocation))
        workspace:SetAttribute("ManualP14Report", nil)
        require(script.Parent.AircraftPanHarness).run(false, function(report)
            workspace:SetAttribute(
                "ManualP14Report",
                HttpService:JSONEncode({ invocation = invocation, result = report })
            )
        end)
        return
    end
    local selector = if development and development:IsA("ModuleScript")
        then development:GetAttribute("ManualHarness")
        else nil
    if
        RunService:IsStudio()
        and ((args == nil and selector == "P18") or (type(args) == "table" and args.kind == "P18"))
    then
        require(script.Parent.RebalanceHarness).run(if args == nil
            then function(report)
                workspace:SetAttribute("ManualP18Report", HttpService:JSONEncode(report))
            end
            else nil)
        return
    end
    if RunService:IsStudio() and args == nil and selector == "P19Profile" and development then
        local harness = require(script.Parent.PerformanceHarness)
        if development:GetAttribute("ManualP19Scenario") == "Replay" then
            harness.impactReplay(function(report)
                workspace:SetAttribute("ManualP19ReplayReport", HttpService:JSONEncode(report))
            end)
        else
            harness.profile(function(report)
                workspace:SetAttribute("ManualP19ProfileReport", HttpService:JSONEncode(report))
            end)
        end
        return
    end
    if RunService:IsStudio() and args == nil and selector == "P11" and development then
        require(script.Parent.PerformanceHarness).run(
            development:GetAttribute("ManualP11Scenario"),
            development:GetAttribute("ManualP11Clients"),
            function(report)
                workspace:SetAttribute("ManualP11Report", HttpService:JSONEncode(report))
            end
        )
        return
    end
    if RunService:IsStudio() and args == nil and selector == "P10" then
        require(script.Parent.PlayerExperienceHarness).run(function(report)
            workspace:SetAttribute("ManualP10Report", HttpService:JSONEncode(report))
        end)
        return
    end
    if RunService:IsStudio() and args == nil and selector == "P09" and development then
        local scenario = development:GetAttribute("ManualP09Scenario")
        require(script.Parent.MatchOutcomeHarness).run(
            if type(scenario) == "string" then scenario else "Outcomes",
            function(report)
                workspace:SetAttribute("ManualP09Report", HttpService:JSONEncode(report))
            end
        )
        return
    end
    if RunService:IsStudio() and args == nil and selector == "P08" then
        local invocation = { mode = "manual-server-clients", harness = "P08", requestedClients = 3 }
        workspace:SetAttribute("ManualP08Invocation", HttpService:JSONEncode(invocation))
        workspace:SetAttribute("ManualP08Report", nil)
        require(script.Parent.LauncherHarness).run(function(report)
            workspace:SetAttribute(
                "ManualP08Report",
                HttpService:JSONEncode({ invocation = invocation, result = report })
            )
        end)
        return
    end
    if RunService:IsStudio() and args == nil and (selector == "P07" or selector == "Sandbreak") then
        local invocation = {
            mode = "manual-server-clients",
            harness = selector,
            requestedInitialClients = 2,
            actualLateClientRequired = false,
        }
        local reportAttribute = "Manual" .. selector .. "Report"
        workspace:SetAttribute("Manual" .. selector .. "Invocation", HttpService:JSONEncode(invocation))
        workspace:SetAttribute(reportAttribute, nil)
        require(script.Parent.DestructionHarness).run(function(report)
            workspace:SetAttribute(
                reportAttribute,
                HttpService:JSONEncode({ invocation = invocation, result = report })
            )
        end, selector == "Sandbreak")
        return
    end
    if RunService:IsStudio() and args == nil and selector == "P31" then
        require(script.Parent.CombatHarness).run(function(report)
            workspace:SetAttribute("ManualP31Report", HttpService:JSONEncode(report))
        end, true)
        return
    end
    if RunService:IsStudio() and args == nil and selector == "P05" then
        local invocation = {
            mode = "manual-server-clients",
            harness = "P05",
            requestedClients = 2,
            selector = "ServerStorage.DevelopmentSettings.ManualHarness",
            selectorValue = "P05",
            studioOnly = true,
        }
        workspace:SetAttribute("ManualP05Invocation", HttpService:JSONEncode(invocation))
        workspace:SetAttribute("ManualP05Report", nil)
        require(script.Parent.CombatHarness).run(function(report)
            workspace:SetAttribute(
                "ManualP05Report",
                HttpService:JSONEncode({ invocation = invocation, result = report })
            )
        end)
        return
    end
    if RunService:IsStudio() and args == nil and (selector == "P06" or selector == "P06Team") then
        local requested = if selector == "P06Team" then 3 else 2
        local invocation = {
            mode = "manual-server-clients",
            harness = selector,
            requestedClients = requested,
            selector = "ServerStorage.DevelopmentSettings.ManualHarness",
            selectorValue = selector,
            studioOnly = true,
        }
        local invocationKey = "Manual" .. selector .. "Invocation"
        local reportKey = "Manual" .. selector .. "Report"
        workspace:SetAttribute(invocationKey, HttpService:JSONEncode(invocation))
        workspace:SetAttribute(reportKey, nil)
        require(script.Parent.GroundCombatHarness).run(requested, function(report)
            workspace:SetAttribute(
                reportKey,
                HttpService:JSONEncode({ invocation = invocation, result = report })
            )
        end)
        return
    end
    if type(args) == "table" and (args.kind == "P14" or args.kind == "P14ArrivalRegression") then
        require(script.Parent.AircraftPanHarness).run(args.kind == "P14ArrivalRegression")
        return
    end
    if type(args) == "table" and args.kind == "P08" then
        require(script.Parent.LauncherHarness).run()
        return
    end
    if type(args) == "table" and args.kind == "P09" then
        local scenario = args.scenario
        require(script.Parent.MatchOutcomeHarness).run(
            if type(scenario) == "string" then scenario else "Outcomes"
        )
        return
    end
    if type(args) == "table" and args.kind == "P10" then
        require(script.Parent.PlayerExperienceHarness).run()
        return
    end
    if type(args) == "table" and args.kind == "P19Profile" then
        local harness = require(script.Parent.PerformanceHarness)
        if args.scenario == "Replay" then
            harness.impactReplay()
        else
            harness.profile()
        end
        return
    end
    if type(args) == "table" and args.kind == "P11" then
        require(script.Parent.PerformanceHarness).run(args.scenario, args.clients)
        return
    end
    if type(args) == "table" and args.kind == "Sandbreak" then
        require(script.Parent.DestructionHarness).run(nil, true)
        return
    end
    if type(args) == "table" and args.kind == "P07" then
        require(script.Parent.DestructionHarness).run()
        return
    end
    if type(args) == "table" and args.kind == "P13" then
        require(script.Parent.ExpandedMapHarness).run()
        return
    end
    if type(args) == "table" and args.kind == "P06" then
        require(script.Parent.GroundCombatHarness).run()
        return
    end
    if type(args) == "table" and args.kind == "P06Team" then
        require(script.Parent.GroundCombatHarness).run(3)
        return
    end
    if type(args) == "table" and (args.kind == "P05" or args.kind == "P31") then
        require(script.Parent.CombatHarness).run(nil, args.kind == "P31")
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
    local verifyIntermission = type(args) == "table" and args.kind == "P23"
    local theaterOnly = type(args) == "table" and args.kind == "P23Theater"
    local productionIntermission = verifyIntermission or theaterOnly
    local automated = productionIntermission or (type(args) == "table" and args.kind == "P03")
    if productionIntermission then
        assert(
            MatchRuntime.defaults.intermissionSeconds == 120,
            "production intermission must be 120 seconds"
        )
    end
    if automated then
        awaitCondition(function()
            return #Players:GetPlayers() == 3
        end, "three actual clients join", 30)
    end
    local combatSeconds = if verifyIntermission
        then 85
        elseif theaterOnly then 45
        elseif automated then 30
        else 60
    local runtime, reason = GameRuntime.start({
        automaticDeployment = automated,
        minimumPlayers = 2,
        durationSeconds = combatSeconds,
        scatterSeconds = if automated then 0 else MatchRuntime.defaults.scatterSeconds,
        -- The first automated deployment follows actual client smoke readiness.
        -- This is only a guard against an automatic start during that handshake.
        lobbySeconds = if automated then 180 else 0,
        deploymentSeconds = 25,
        resultsSeconds = if automated then 2 else 3,
        intermissionSeconds = if productionIntermission
            then MatchRuntime.defaults.intermissionSeconds
            elseif automated then 10
            else nil,
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
    local lobbyStation = workspace.World.Battlefield.LobbyStation
    local theaterFloor =
        assert(lobbyStation:FindFirstChild("LobbyFloorTheater", true), "theater floor missing")
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
        -- A new Studio client loads the native battlefield and runs its smoke
        -- suites before acknowledging the harness transport.
        local readinessSeconds = if verifyIntermission and slots[player] == 4 then 45 else 15
        awaitCondition(function()
            return readyClients[player] == true
        end, "client harness ready " .. tostring(slots[player]), readinessSeconds)
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
                intermissionUntil = state.intermissionUntil,
            })
        end
    end
    local function waitingAvatar(player: Player, previous: Model?): Model
        awaitCondition(function()
            local avatar = player.Character
            local root = if avatar then avatar:FindFirstChild("HumanoidRootPart") else nil
            return avatar ~= nil
                and avatar ~= previous
                and avatar:FindFirstChild("StationProtection") ~= nil
                and root ~= nil
                and root:IsA("BasePart")
                and not root.Anchored
        end, "protected, movable lobby avatar")
        return assert(player.Character, "lobby avatar disappeared")
    end
    local returnedAvatars: { [Player]: Model } = {}
    local firstRound, secondRound, thirdRound = 0, 0, 0
    local function placeAtTelevision(player: Player, avatar: Model)
        local root = avatar:FindFirstChild("HumanoidRootPart")
        assert(
            player.Character == avatar and root and root:IsA("BasePart") and not root.Anchored,
            "theater placement requires the actual movable lobby avatar"
        )
        avatar:PivotTo(CFrame.lookAt(Vector3.new(472.5, 3, -40), Vector3.new(472.5, 3, -43.815)))
        root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
    end
    local ok, failure = pcall(function()
        check("A5 three actual clients receive assigned roles, phase, deadline and UI", function()
            assert(#clients == 3, "P03 harness requires exactly three actual clients")
            awaitCondition(function()
                for _, player in clients do
                    if not readyClients[player] then
                        return false
                    end
                end
                return true
            end, "all initial clients completed their smoke suites", 90)
            assert(runtime.rounds.match.deploy(), "first deployment rejected after client smoke")
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
        if not theaterOnly then
            check("P23 A4 actual late arrival receives a protected lobby avatar and cannot act", function()
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
                waitingAvatar(late, nil)
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
                assert(
                    runtime.rounds.match.snapshot().revision == before,
                    "late spectator command mutated state"
                )
            end)
        end
        check(
            "P23 A1/A2 death returns Ground to lobby and the theater enables optional spectating",
            function()
                local state = runtime.rounds.match.snapshot()
                local operator, ground = roles(state)
                local dead, survivor = ground[1], ground[2]
                local original = dead.Character
                assert(original, "ground character missing")
                probe(operator, { kind = "NoTheaterPrompt" })
                probe(survivor, { kind = "NoTheaterPrompt" })
                local humanoid = original:FindFirstChildOfClass("Humanoid")
                assert(humanoid, "ground humanoid missing")
                humanoid.Health = 0
                awaitCondition(function()
                    local member = runtime.rounds.match.snapshot().members[dead.UserId]
                    return member.life == "Eliminated"
                end, "ground death elimination")
                local lobby = waitingAvatar(dead, original)
                probe(dead, { kind = "LobbyCamera" })
                probe(dead, { kind = "DistantTheater" })
                placeAtTelevision(dead, lobby)
                probe(dead, { kind = "EnterTheater", targetId = survivor.UserId, roundId = state.roundId })
                probe(dead, { kind = "ExitTheater" })
                assert(dead.Character == lobby, "leaving spectator mode replaced the lobby avatar")
                local revision = runtime.rounds.match.snapshot().revision
                probe(operator, { kind = "SendRejected", roundId = state.roundId, sequence = 1 })
                probe(dead, { kind = "SendRejected", roundId = state.roundId, sequence = 1 })
                probe(survivor, { kind = "SendRejected", roundId = state.roundId - 1, sequence = 1 })
                task.wait(0.3)
                assert(runtime.rounds.match.snapshot().revision == revision, "rejected remote mutated match")
                -- Exit deliberately walks the avatar away from the screen.
                -- Start the second native entry check back in prompt range.
                placeAtTelevision(dead, lobby)
                probe(dead, { kind = "EnterTheater", targetId = survivor.UserId, roundId = state.roundId })
                probe(survivor, { kind = "Surrender", roundId = state.roundId, sequence = 2 })
                awaitCondition(function()
                    return runtime.rounds.match.snapshot().phase == "Results"
                end, "elimination result")
                local terminal = runtime.rounds.match.snapshot()
                local result = terminal.result
                assert(
                    result and result.winner == "Gunship" and result.reason == "GroundEliminated",
                    "wrong elimination result"
                )
                probe(dead, { kind = "LobbyCamera" })
                assert(dead.Character == lobby, "results respawned a player already in the theater")
                if productionIntermission then
                    -- Observe lobby arrival as soon as the result commits. Avatar
                    -- loading may still be in flight when the battlefield resets.
                    for _, player in Players:GetPlayers() do
                        returnedAvatars[player] = waitingAvatar(player, nil)
                        probe(
                            player,
                            { kind = "Intermission", intermissionUntil = terminal.intermissionUntil }
                        )
                    end
                end
            end
        )
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
        if theaterOnly then
            return true
        end
        if verifyIntermission then
            check("P23 A4 production-length intermission keeps all clients in the protected lobby", function()
                local result = runtime.rounds.match.snapshot()
                local deadline = result.intermissionUntil
                assert(
                    deadline > workspace:GetServerTimeNow() + 90,
                    "production countdown did not start at result"
                )
                assert(
                    not runtime.rounds.match.deploy(),
                    "manual deployment bypassed production intermission"
                )
                while workspace:GetServerTimeNow() + 0.1 < deadline do
                    local current = runtime.rounds.match.snapshot()
                    assert(
                        current.roundId == firstRound and current.phase == "Lobby",
                        "deployed before countdown ended"
                    )
                    assert(
                        workspace.World.Battlefield.LobbyStation == lobbyStation,
                        "reset replaced the occupied lobby"
                    )
                    assert(
                        theaterFloor:IsDescendantOf(lobbyStation),
                        "theater floor was replaced during reset"
                    )
                    for player, avatar in returnedAvatars do
                        assert(player.Character == avatar, "intermission replaced a lobby avatar")
                    end
                    task.wait(0.05)
                end
            end)
        end
        check("A5/A6 operator reset retains assignment and timeout is authoritative", function()
            local state = activeAfter(firstRound)
            secondRound = state.roundId
            initialConnections = runtime.rounds.resources().connections
            perturbMap()
            local operator, ground = roles(state)
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
            if verifyIntermission then
                local watcher, currentTarget, nextTarget = ground[3], ground[1], ground[2]
                assert(watcher and currentTarget and nextTarget, "late client not included in the new roster")
                local oldWatcher = assert(watcher.Character, "watcher not deployed")
                local watcherBody =
                    assert(oldWatcher:FindFirstChildOfClass("Humanoid"), "watcher body missing")
                watcherBody.Health = 0
                placeAtTelevision(watcher, waitingAvatar(watcher, oldWatcher))
                probe(
                    watcher,
                    { kind = "EnterTheater", targetId = currentTarget.UserId, roundId = state.roundId }
                )
                local targetBody = assert(
                    currentTarget.Character and currentTarget.Character:FindFirstChildOfClass("Humanoid"),
                    "first target body missing"
                )
                targetBody.Health = 0
                probe(watcher, { kind = "FollowTheater", targetId = nextTarget.UserId })
                assert(
                    runtime.rounds.match.snapshot().phase == "Active",
                    "losing one theater target ended the round"
                )
            end
            awaitCondition(function()
                return runtime.rounds.match.snapshot().phase == "Results"
            end, "round timeout", combatSeconds + 5)
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
            assert(theaterFloor:IsDescendantOf(lobbyStation), "second reset replaced the theater floor")
            assert(
                workspace.World.Battlefield.LobbyStation == lobbyStation,
                "second reset replaced the occupied lobby"
            )
        end)
        if verifyIntermission then
            return true
        end
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
        return true
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
        suite = if theaterOnly
            then "P23-theater"
            elseif verifyIntermission then "P23-multiplayer"
            else "P03-multiplayer",
        environment = "Studio",
        clientCount = peakClientCount,
        initialClientCount = #clients,
        completedRoundIds = if theaterOnly
            then (if ok then { firstRound } else {})
            elseif verifyIntermission then { firstRound, secondRound }
            else { firstRound, secondRound, thirdRound },
        discovered = #cases,
        passed = passed,
        failed = #cases - passed,
        skipped = 0,
        cases = cases,
    }
    workspace:SetAttribute(
        if theaterOnly
            then "P23TheaterReport"
            elseif verifyIntermission then "P23MultiplayerReport"
            else "P03MultiplayerReport",
        HttpService:JSONEncode(report)
    )
    StudioTestService:EndTest(report)
end

return RoundHarness
