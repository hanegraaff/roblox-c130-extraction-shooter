--!strict
--[=[
    P08 test-only three-actual-client acceptance harness. Uses production GameRuntime,
    real client intents and real moving-aircraft swept flights. Trusted fixture poses
    isolate authority/collision tests; they do not claim operated route traversal.
    Each run owns/cleans its runtime and transport. Actual same-identity reconnect
    remains explicitly unverified: AddPlayers creates a new Studio identity.
]=]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local StudioTestService = game:GetService("StudioTestService")
local GameRuntime = require(game:GetService("ServerScriptService").Server.GameRuntime)
local LauncherService = require(game:GetService("ServerScriptService").Server.LauncherService)
local Harness = {}
type Case = { name: string, passed: boolean, detail: string? }
export type Report = {
    suite: string,
    environment: string,
    mode: string,
    clientCount: number,
    initialClientCount: number,
    peakClientCount: number,
    currentClientCount: number,
    requestedClients: number,
    discovered: number,
    passed: number,
    failed: number,
    skipped: number,
    cases: { Case },
    actualReconnectVerified: boolean,
    requiredUnverified: { string },
    departureMethod: string,
}
local function waitFor(predicate: () -> boolean, label: string, seconds: number?)
    local deadline = os.clock() + (seconds or 15)
    while not predicate() and os.clock() < deadline do
        task.wait(0.03)
    end
    assert(predicate(), "P08 timeout: " .. label)
end
-- SDK self-ends; native Server & Clients supplies finish to retain the report
-- until the coordinator collects it and ends the owned manual session.
function Harness.run(finish: ((Report) -> ())?)
    local cases: { Case } = {}
    local initialClientCount = #Players:GetPlayers()
    local peakClientCount = initialClientCount
    local arrivals = Players.PlayerAdded:Connect(function()
        peakClientCount = math.max(peakClientCount, #Players:GetPlayers())
    end)
    local function deliver()
        peakClientCount = math.max(peakClientCount, #Players:GetPlayers())
        arrivals:Disconnect()
        local passed = 0
        for _, case in cases do
            if case.passed then
                passed += 1
            end
        end
        local report: Report = {
            suite = "P08-multiplayer",
            environment = "Studio",
            mode = if finish then "manual-server-clients" else "sdk",
            clientCount = peakClientCount,
            initialClientCount = initialClientCount,
            peakClientCount = peakClientCount,
            currentClientCount = #Players:GetPlayers(),
            requestedClients = 3,
            discovered = #cases,
            passed = passed,
            failed = #cases - passed,
            skipped = 0,
            cases = cases,
            actualReconnectVerified = false,
            requiredUnverified = { "A5 actual same-identity reconnect" },
            departureMethod = if finish then "server-kick" else "client-leave",
        }
        workspace:SetAttribute("P08MultiplayerReport", HttpService:JSONEncode(report))
        if finish then
            finish(report)
        else
            StudioTestService:EndTest(report)
        end
    end
    local joined, joinFailure = pcall(function()
        waitFor(function()
            return #Players:GetPlayers() == 3
        end, "three actual clients", 35)
    end)
    if not joined then
        table.insert(cases, { name = "Harness startup", passed = false, detail = tostring(joinFailure) })
        deliver()
        return
    end
    local runtime, reason = GameRuntime.start({
        automaticDeployment = false,
        minimumPlayers = 2,
        durationSeconds = 180,
        lobbySeconds = 0,
        deploymentSeconds = 30,
        resultsSeconds = 3,
        seed = 1,
    })
    if not runtime then
        table.insert(cases, { name = "Harness runtime startup", passed = false, detail = tostring(reason) })
        deliver()
        return
    end
    local transport = Instance.new("RemoteEvent")
    transport.Name = "P08Harness"
    local ready: { [Player]: boolean } = {}
    local replies: { [number]: { player: Player, ok: boolean?, detail: string? } } = {}
    local token = 0
    local listener = transport.OnServerEvent:Connect(
        function(player: Player, serial: unknown, ok: unknown, detail: unknown)
            if serial == 0 then
                ready[player] = true
            elseif type(serial) == "number" and replies[serial] and replies[serial].player == player then
                replies[serial].ok, replies[serial].detail = ok == true, tostring(detail)
            end
        end
    )
    transport.Parent = ReplicatedStorage
    local function beginProbe(player: Player, kind: string, payload: unknown): number
        waitFor(function()
            return ready[player] == true
        end, "actual client ready")
        token += 1
        replies[token] = { player = player }
        transport:FireClient(player, token, kind, payload)
        return token
    end
    local function finishProbe(serial: number)
        waitFor(function()
            return replies[serial].ok ~= nil
        end, "client response")
        local reply = replies[serial]
        replies[serial] = nil
        assert(reply.ok, tostring(reply.detail))
    end
    local function probe(player: Player, kind: string, payload: unknown)
        finishProbe(beginProbe(player, kind, payload))
    end
    local sequences: { [Player]: number } = {}
    local rifleSequences: { [Player]: number } = {}
    local function payload(player: Player, target: Vector3?): { [string]: unknown }
        sequences[player] = (sequences[player] or 0) + 1
        local state = runtime.launcher.snapshot()
        local value: { [string]: unknown } = {
            roundId = state.roundId,
            launcherId = state.launcherId,
            sequence = sequences[player],
        }
        if target then
            value.x, value.y, value.z = target.X, target.Y, target.Z
        end
        return value
    end
    local function health(): number
        local value = ReplicatedStorage.AircraftState:GetAttribute("Health")
        assert(type(value) == "number", "aircraft health missing")
        return value
    end
    local function roles(): (Player, { Player })
        local operator: Player? = nil
        local ground: { Player } = {}
        for _, player in Players:GetPlayers() do
            if player:GetAttribute("Role") == "Gunship" then
                operator = player
            elseif player:GetAttribute("Role") == "Ground" and player:GetAttribute("Life") == "Alive" then
                table.insert(ground, player)
            end
        end
        assert(operator, "operator missing")
        table.sort(ground, function(a, b)
            return a.UserId < b.UserId
        end)
        return operator, ground
    end
    local function pose(player: Player, position: Vector3, trusted: boolean?)
        local character = player.Character
        assert(character, "fixture character missing")
        character:PivotTo(CFrame.new(position))
        local root = character:FindFirstChild("HumanoidRootPart")
        assert(root and root:IsA("BasePart"), "fixture root missing")
        root.Anchored = true
        if trusted ~= false then
            assert(runtime.groundCombat.trustCorrection(player), "trusted fixture correction")
        end
    end
    local function deploy()
        assert(runtime.rounds.match.deploy(), "deployment rejected")
        waitFor(function()
            return runtime.rounds.match.snapshot().phase == "Active"
        end, "active round", 45)
        waitFor(function()
            return runtime.launcher.snapshot().state == "Available"
        end, "one available launcher")
        table.clear(sequences)
        table.clear(rifleSequences)
    end
    local function observe(expectedHealth: number?)
        local snapshot = runtime.launcher.snapshot()
        local expected = {
            roundId = snapshot.roundId,
            state = snapshot.state,
            ownerId = snapshot.ownerId,
            readyAt = snapshot.readyAt,
            health = expectedHealth,
        }
        for _, player in Players:GetPlayers() do
            probe(player, "Observe", expected)
        end
        assert(
            runtime.launcher.resources().representations == (if snapshot.state == "Inactive" then 0 else 1),
            "representation count"
        )
    end
    local function pickup(player: Player)
        local position = runtime.launcher.snapshot().position
        pose(player, Vector3.new(position.x, position.y + 2, position.z))
        probe(player, "Pickup", payload(player))
        waitFor(function()
            return runtime.launcher.snapshot().ownerId == player.UserId
        end, "pickup ownership")
    end
    local function equip(player: Player, name: string)
        local backpack, character = player:FindFirstChildOfClass("Backpack"), player.Character
        local tool = if backpack then backpack:FindFirstChild(name) else nil
        local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
        assert(humanoid and tool and tool:IsA("Tool"), "equip fixture missing " .. name)
        humanoid:EquipTool(tool)
        waitFor(function()
            return tool.Parent == player.Character
        end, "equipped fixture")
    end
    local function nearAircraft(player: Player)
        local aircraft = workspace:FindFirstChild("Aircraft")
        assert(aircraft and aircraft:IsA("Model"), "aircraft missing")
        local position = aircraft:GetPivot().Position
        local horizontal = Vector3.new(position.X, 0, position.Z).Unit * 330
        pose(player, horizontal + Vector3.yAxis * 30)
    end
    -- Lead the unchanged moving aircraft, including a 0.10s transport/step
    -- allowance. This is a deterministic fixture aim, not client hit authority.
    local function lead(player: Player): Vector3
        local character = player.Character
        local head = if character then character:FindFirstChild("Head") else nil
        assert(head and head:IsA("BasePart"), "fire head missing")
        local epoch = ReplicatedStorage.AircraftState:GetAttribute("EpochSeconds")
        assert(type(epoch) == "number", "orbit epoch missing")
        local elapsed = workspace:GetServerTimeNow() - epoch
        local travel = 0.5
        local target = Vector3.zero
        for _ = 1, 5 do
            target = runtime.aircraft.sample(elapsed + travel + 0.10).Position
            travel = (target - head.Position).Magnitude / LauncherService.speedStudsPerSecond
        end
        return target
    end
    local function fire(player: Player, target: Vector3)
        waitFor(function()
            return runtime.launcher.snapshot().ammo == 1
        end, "rocket ready", 8)
        local before = runtime.launcher.snapshot().readyAt
        probe(player, "Fire", payload(player, target))
        waitFor(function()
            return runtime.launcher.snapshot().readyAt > before
        end, "accepted real fire")
    end
    local function resetRound()
        local before = runtime.rounds.match.snapshot()
        if before.phase == "Active" then
            assert(runtime.rounds.match.abort(before.roundId, "P08FixtureReset"), "fixture abort")
        end
        waitFor(function()
            return runtime.rounds.match.snapshot().phase == "Lobby"
        end, "pristine lobby", 25)
        waitFor(function()
            return health() == 300 and runtime.launcher.resources().representations == 0
        end, "pristine cleanup")
        assert(
            runtime.launcher.resources().flights == 0 and runtime.launcher.resources().queued == 0,
            "stale flight/queue"
        )
        deploy()
    end
    local function check(name: string, callback: () -> ())
        local ok, failure = pcall(function()
            callback()
            return true
        end)
        table.insert(cases, { name = name, passed = ok, detail = if ok then nil else tostring(failure) })
        assert(ok, tostring(failure))
    end
    local ok, failure = pcall(function()
        check("A1/A5 three clients see one map launcher with M-7-only initial loadouts", function()
            deploy()
            local _, ground = roles()
            assert(#ground == 2, "requires one operator and two actual ground clients")
            for _, player in ground do
                waitFor(function()
                    local bag = player:FindFirstChildOfClass("Backpack")
                    return bag ~= nil and bag:FindFirstChild("M-7 rifle") ~= nil
                end, "initial M-7")
                assert(not player.Backpack:FindFirstChild("Rocket launcher"), "initial launcher granted")
            end
            observe(300)
        end)
        check(
            "A2 malformed wrong-role stale flood and impossible-travel claims leave ownership unchanged",
            function()
                local operator, ground = roles()
                probe(operator, "Pickup", payload(operator))
                probe(ground[1], "Pickup", { roundId = -1, sequence = 1, launcherId = "forged" })
                probe(ground[1], "Flood", {})
                task.wait(1.5)
                pose(ground[1], Vector3.new(0, 5, 0), false)
                probe(ground[1], "Pickup", payload(ground[1]))
                task.wait(0.15)
                assert(
                    runtime.launcher.snapshot().state == "Available" and runtime.launcher.snapshot().ammo == 1,
                    "invalid ownership/ammo mutation"
                )
            end
        )
        check("A1/A2 raced real-client pickups claim once; carrier keeps M-7", function()
            local _, ground = roles()
            pose(ground[1], Vector3.new(-2, 5, 0))
            pose(ground[2], Vector3.new(2, 5, 0))
            local first = beginProbe(ground[1], "Pickup", payload(ground[1]))
            local second = beginProbe(ground[2], "Pickup", payload(ground[2]))
            finishProbe(first)
            finishProbe(second)
            waitFor(function()
                return runtime.launcher.snapshot().ownerId ~= nil
            end, "race owner")
            local carrier = Players:GetPlayerByUserId(
                assert(runtime.launcher.snapshot().ownerId, "launcher owner missing")
            )
            assert(carrier and carrier.Backpack:FindFirstChild("M-7 rifle"), "M-7 removed on pickup")
            observe(300)
        end)
        check("A3 actual miss drop transfer switching and early fire preserve identity and reload", function()
            local _, ground = roles()
            local carrier = Players:GetPlayerByUserId(
                assert(runtime.launcher.snapshot().ownerId, "launcher owner missing")
            )
            assert(carrier, "carrier missing")
            local teammate = if ground[1] == carrier then ground[2] else ground[1]
            equip(carrier, "Rocket launcher")
            fire(carrier, Vector3.new(0, 300, 0))
            local untilTime = runtime.launcher.snapshot().readyAt
            probe(carrier, "Drop", payload(carrier))
            waitFor(function()
                return runtime.launcher.snapshot().state == "Available"
            end, "voluntary drop")
            pickup(teammate)
            equip(teammate, "Rocket launcher")
            probe(teammate, "Fire", payload(teammate, Vector3.new(0, 300, 0)))
            equip(teammate, "M-7 rifle")
            equip(teammate, "Rocket launcher")
            assert(runtime.launcher.snapshot().readyAt == untilTime, "transfer/selection reset reload")
            observe(300)
        end)
        check(
            "A3/A4 actual carrier death recovers once while its in-flight direct rocket still damages",
            function()
                local _, ground = roles()
                local carrier = Players:GetPlayerByUserId(
                    assert(runtime.launcher.snapshot().ownerId, "launcher owner missing")
                )
                assert(carrier, "carrier missing")
                local teammate = if ground[1] == carrier then ground[2] else ground[1]
                nearAircraft(carrier)
                fire(carrier, lead(carrier))
                local untilTime = runtime.launcher.snapshot().readyAt
                local humanoid = if carrier.Character
                    then carrier.Character:FindFirstChildOfClass("Humanoid")
                    else nil
                assert(humanoid, "carrier body missing")
                humanoid.Health = 0
                waitFor(function()
                    return runtime.launcher.snapshot().state == "Available"
                end, "death recovery")
                waitFor(function()
                    return health() == 200
                end, "dead shooter's actual in-flight rocket", 8)
                pickup(teammate)
                assert(runtime.launcher.snapshot().readyAt == untilTime, "death healed reload")
                assert(carrier:GetAttribute("Life") == "Eliminated", "death restored life")
                observe(200)
            end
        )
        check("A6 real reset removes old state and rejects delayed prior-round intent", function()
            local _, ground = roles()
            local delayed = payload(ground[1], Vector3.new(0, 300, 0))
            local oldId = runtime.launcher.snapshot().launcherId
            resetRound()
            local _, fresh = roles()
            probe(fresh[1], "Fire", delayed)
            probe(fresh[1], "Pickup", delayed)
            task.wait(0.1)
            local state = runtime.launcher.snapshot()
            assert(
                state.launcherId ~= oldId
                    and state.state == "Available"
                    and state.readyAt == 0
                    and state.ammo == 1,
                "stale round mutated launcher"
            )
            assert(
                state.position.x == 0 and state.position.y == 3 and state.position.z == 0,
                "reset moved anchor"
            )
            observe(300)
        end)
        check("A4 three actual fired rockets leave 200 then 100 then commit one ground win", function()
            local _, ground = roles()
            local shooter = ground[1]
            pickup(shooter)
            equip(shooter, "Rocket launcher")
            for index = 1, 3 do
                nearAircraft(shooter)
                fire(shooter, lead(shooter))
                waitFor(function()
                    return health() == 300 - index * 100
                end, "direct rocket " .. tostring(index), 8)
                if index < 3 then
                    assert(runtime.rounds.match.snapshot().phase == "Active", "early destruction")
                    observe(300 - index * 100)
                end
            end
            waitFor(function()
                return runtime.rounds.match.snapshot().phase == "Results"
            end, "ground result")
            local result = runtime.rounds.match.snapshot().result
            assert(
                result and result.winner == "Ground" and result.reason == "AircraftDestroyed",
                "three-rocket result"
            )
            waitFor(function()
                return runtime.launcher.snapshot().state == "Inactive"
            end, "terminal launcher cleanup")
            observe(0)
        end)
        check(
            "A4 earlier real rifle damage means two remaining rockets can finish the shared health pool",
            function()
                resetRound()
                local _, ground = roles()
                local shooter = ground[1]
                pickup(shooter)
                nearAircraft(shooter)
                equip(shooter, "M-7 rifle")
                for index = 1, 21 do
                    local aircraft = workspace:FindFirstChild("Aircraft")
                    assert(aircraft and aircraft:IsA("Model"), "rifle target missing")
                    local target = aircraft:GetPivot().Position
                    rifleSequences[shooter] = (rifleSequences[shooter] or 0) + 1
                    probe(shooter, "Rifle", {
                        roundId = runtime.launcher.snapshot().roundId,
                        sequence = rifleSequences[shooter],
                        weapon = "M7",
                        x = target.X,
                        y = target.Y,
                        z = target.Z,
                    })
                    waitFor(function()
                        return health() == 300 - 5 * index
                    end, "real rifle hit", 5)
                    task.wait(0.16)
                end
                equip(shooter, "Rocket launcher")
                for index = 1, 2 do
                    nearAircraft(shooter)
                    fire(shooter, lead(shooter))
                    waitFor(function()
                        return health() == math.max(0, 195 - index * 100)
                    end, "mixed rocket", 8)
                end
                waitFor(function()
                    return runtime.rounds.match.snapshot().phase == "Results"
                end, "mixed result")
                assert(runtime.rounds.match.snapshot().result ~= nil, "mixed result missing")
            end
        )
        check("A3/A5 actual disconnect preserves reload and permits living teammate recovery", function()
            resetRound()
            local _, ground = roles()
            local carrier, teammate = ground[1], ground[2]
            pickup(carrier)
            equip(carrier, "Rocket launcher")
            fire(carrier, Vector3.new(0, 300, 0))
            local untilTime = runtime.launcher.snapshot().readyAt
            if finish then
                carrier:Kick("P08 actual carrier-disconnect fixture")
            else
                probe(carrier, "Leave", {})
            end
            waitFor(function()
                return #Players:GetPlayers() == 2
            end, "actual departure")
            waitFor(function()
                return runtime.launcher.snapshot().state == "Available"
            end, "disconnect recovery")
            assert(runtime.rounds.match.snapshot().phase == "Active", "departure ended populated round")
            pickup(teammate)
            assert(runtime.launcher.snapshot().readyAt == untilTime, "disconnect refilled launcher")
            observe(300)
        end)
    end)
    if not ok then
        table.insert(cases, { name = "Harness completion", passed = false, detail = tostring(failure) })
    end
    runtime.stop()
    runtime.stop()
    listener:Disconnect()
    transport:Destroy()
    local resources = runtime.launcher.resources()
    table.insert(cases, {
        name = "A6 teardown invalidates deferred callbacks and removes every owned resource",
        passed = resources.connections == 0
            and resources.representations == 0
            and resources.flights == 0
            and resources.queued == 0
            and ReplicatedStorage:FindFirstChild("LauncherState") == nil
            and workspace:FindFirstChild("LauncherEffects") == nil,
    })
    deliver()
end
return Harness
