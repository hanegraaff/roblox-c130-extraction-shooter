--!strict
--[=[
    AircraftArrivalHarness: server-only P24 acceptance in the Studio test place.
    Runs actual GameRuntime with standard scatter and combat seconds, requests
    observations from real clients, and tests accepted/rejected production remotes.
    Only fixture placement and a terminal Humanoid death bypass ordinary input.
]=]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StudioTestService = game:GetService("StudioTestService")
local Server = game:GetService("ServerScriptService").Server
local HttpService = game:GetService("HttpService")
local GameRuntime = require(Server.GameRuntime)
local MatchRuntime = require(Server.MatchRuntime)
local MatchService = require(Server.MatchService)
local LauncherService = require(Server.LauncherService)
local MapRules = require(ReplicatedStorage.Shared.MapRules)
local Pan = require(ReplicatedStorage.Shared.AircraftPanRules)
local CombatViewRules = require(Server.CombatViewRules)
local AircraftArrivalHarness = {}

type Case = { name: string, passed: boolean, detail: string? }
type Reply = { player: Player, ready: boolean, ok: boolean, value: unknown }
type Record = { [string]: unknown }
local function waitFor(predicate: () -> boolean, label: string, seconds: number?)
    local deadline = os.clock() + (seconds or 8)
    while not predicate() and os.clock() < deadline do
        task.wait(0.025)
    end
    assert(predicate(), "P24 server timeout: " .. label)
end

local function bodyPart(player: Player, name: string): BasePart
    local part = if player.Character then player.Character:FindFirstChild(name) else nil
    assert(part and part:IsA("BasePart"), "missing " .. name)
    return part
end

-- Runs one isolated Studio session. The SDK variant terminates its own session;
-- a native UI start writes the same report in the Server DataModel.
function AircraftArrivalHarness.run(automated: boolean)
    local cases: { Case } = {}
    local observations: { unknown } = {}
    local completed: { number } = {}
    local smoke: { [string]: string } = {}
    local initialCount = 0
    local runtime: GameRuntime.Controller? = nil
    local transport = Instance.new("RemoteEvent")
    transport.Name = "P24Harness"
    local replies: { [number]: Reply } = {}
    local serial = 0
    local listener = transport.OnServerEvent:Connect(
        function(player: Player, token: unknown, ok: unknown, value: unknown)
            if token == 0 and ok == true and type(value) == "string" then
                smoke[tostring(player.UserId)] = value
            elseif type(token) == "number" then
                local reply = replies[token]
                if reply and reply.player == player and not reply.ready then
                    reply.ready, reply.ok, reply.value = true, ok == true, value
                end
            end
        end
    )
    local function check(name: string, callback: () -> ())
        local ok, failure = pcall(function()
            callback()
            return true
        end)
        table.insert(cases, { name = name, passed = ok, detail = if ok then nil else tostring(failure) })
        assert(ok, tostring(failure))
    end
    local function probe(player: Player, kind: string, payload: Record): unknown
        serial += 1
        local reply: Reply = { player = player, ready = false, ok = false, value = nil }
        replies[serial] = reply
        transport:FireClient(player, serial, kind, payload)
        waitFor(function()
            return reply.ready
        end, kind .. " acknowledgement from " .. player.Name)
        replies[serial] = nil
        assert(reply.ok, tostring(reply.value))
        return reply.value
    end
    local function intent(player: Player, parent: string, remote: string, payload: Record)
        probe(player, "Intent", { parent = parent, remote = remote, payload = payload })
    end
    local success, failure = pcall(function()
        waitFor(function()
            return #Players:GetPlayers() == 2
        end, "two actual clients", 60)
        initialCount = #Players:GetPlayers()
        local defaults = MatchRuntime.defaults
        assert(defaults.scatterSeconds == 20 and defaults.durationSeconds == 600, "production clocks changed")
        local owned, reason = GameRuntime.start({
            automaticDeployment = false,
            minimumPlayers = 2,
            durationSeconds = defaults.durationSeconds,
            scatterSeconds = defaults.scatterSeconds,
            lobbySeconds = 0,
            deploymentSeconds = 25,
            resultsSeconds = 2,
            intermissionSeconds = 1,
            seed = 1,
        })
        assert(owned, reason)
        runtime = owned
        local match = owned.rounds.match
        transport.Parent = ReplicatedStorage
        waitFor(function()
            for _, player in Players:GetPlayers() do
                if not smoke[tostring(player.UserId)] then
                    return false
                end
            end
            return #Players:GetPlayers() == 2
        end, "both actual clients finished smoke", 75)
        local function noPlane()
            local start = owned.aircraft.sample(0).Position
            assert(not workspace:FindFirstChild("Aircraft"), "plane visible during deployment or Scatter")
            assert(not owned.aircraft.muzzle("GAU23"), "unrevealed aircraft exposes a muzzle")
            assert(
                not workspace:Raycast(start + Vector3.yAxis * 24, -Vector3.yAxis * 48),
                "aircraft ray surface is present early"
            )
        end
        local function deploy(): (MatchService.Snapshot, Player, Player)
            assert(match.deploy(), "could not deploy fixture")
            -- Yield until the owner has applied the phase, then inspect the
            -- server through readiness. A deploy mutation alone is not a frame.
            task.wait()
            waitFor(function()
                local phase = match.snapshot().phase
                if phase == "Deploying" then
                    noPlane()
                end
                return phase == "Scatter"
            end, "ready roster begins scatter", 25)
            local state = match.snapshot()
            assert(
                math.abs(state.deadlineSeconds - workspace:GetServerTimeNow() - 20) < 0.5,
                "readiness shortened scatter"
            )
            local operator: Player? = nil
            local ground: Player? = nil
            for _, player in Players:GetPlayers() do
                local member = state.members[player.UserId]
                if member.role == "Gunship" then
                    operator = player
                elseif member.role == "Ground" then
                    ground = player
                end
            end
            assert(operator and ground, "both assigned roles are required")
            assert(not bodyPart(ground, "HumanoidRootPart").Anchored, "roster ready without Ground movement")
            return state, operator, ground
        end
        local function equip(player: Player, name: string): Tool
            local character = assert(player.Character, "equipping player has no character")
            local humanoid = assert(character:FindFirstChildOfClass("Humanoid"), "character lacks Humanoid")
            local backpack = assert(player:FindFirstChildOfClass("Backpack"), "player lacks Backpack")
            local tool = backpack:FindFirstChild(name) or character:FindFirstChild(name)
            assert(tool and tool:IsA("Tool"), "waiting for owned " .. name)
            humanoid:EquipTool(tool)
            assert(tool.Parent == character, "native Tool equip failed")
            return tool
        end
        local function place(player: Player, position: Vector3)
            local character = assert(player.Character, "fixture character missing")
            local root = bodyPart(player, "HumanoidRootPart")
            root.Anchored = true
            character:PivotTo(CFrame.new(position))
            assert(owned.groundCombat.trustCorrection(player), "fixture placement not acknowledged")
        end
        local function launcherIntent(player: Player, action: string, sequence: number, target: Vector3?)
            local slot = owned.launcher.snapshot()
            local payload: Record =
                { roundId = slot.roundId, launcherId = slot.launcherId, sequence = sequence }
            if target then
                payload.x, payload.y, payload.z = target.X, target.Y, target.Z
            end
            intent(player, "LauncherState", action, payload)
        end
        local function operatorPayload(roundId: number, sequence: number, camera: Vector3): Record
            local map = MapRules.defaults
            local target = Vector3.new(0, 30, 0)
            local aimFloor = camera + (target - camera) * (map.altitudeStuds / (camera.Y - target.Y))
            local home = assert(Pan.recenter(map, 16 / 9, 40), "canonical view cannot recenter")
            local command: Record = {
                roundId = roundId,
                sequence = sequence,
                weapon = "GAU23",
                x = target.X,
                y = target.Y,
                z = target.Z,
                aspect = 16 / 9,
                focusX = home.x,
                focusZ = home.z,
                cameraX = camera.X,
                cameraZ = camera.Z,
            }
            for sample = 0, 100 do
                local weight = sample / 100
                command.focusX = aimFloor.X + (home.x - aimFloor.X) * weight
                command.focusZ = aimFloor.Z + (home.z - aimFloor.Z) * weight
                if CombatViewRules.validate(command, map, "GAU23", camera.X, camera.Z) then
                    return command
                end
            end
            error("fixture target lacks a valid operator view")
        end
        local function reset(roundId: number)
            assert(match.abort(roundId, "P24Replay"), "could not end fixture round")
            waitFor(function()
                return match.snapshot().phase == "Lobby"
            end, "pristine reset", 15)
            assert(
                workspace:GetServerTimeNow() >= match.snapshot().intermissionUntil,
                "fixture could not replay yet"
            )
            table.insert(completed, roundId)
        end
        local previousOperator: Player? = nil
        for round = 1, 2 do
            local state, operator, ground = deploy()
            assert(operator ~= previousOperator, "operator did not rotate on replay")
            previousOperator = operator
            check("A3 round " .. tostring(round) .. " replicates scatter on both actual clients", function()
                for _, player in { operator, ground } do
                    table.insert(
                        observations,
                        probe(player, "Scatter", {
                            roundId = state.roundId,
                            role = state.members[player.UserId].role,
                            deadline = state.deadlineSeconds,
                        })
                    )
                end
            end)
            local carried: Tool? = nil
            local preservedPosition = Vector3.zero
            local char = assert(ground.Character, "deployed Ground character missing")
            check(
                "A2 round "
                    .. tostring(round)
                    .. " permits movement and launcher transfers but blocks all fire",
                function()
                    local root = bodyPart(ground, "HumanoidRootPart")
                    local beforeMove = root.Position
                    local params = RaycastParams.new()
                    params.FilterType = Enum.RaycastFilterType.Exclude
                    params.FilterDescendantsInstances = { char }
                    params.RespectCanCollide = true
                    local direction: Vector3? = nil
                    for angle = 0, 7 do
                        local unit =
                            Vector3.new(math.cos(angle * math.pi / 4), 0, math.sin(angle * math.pi / 4))
                        if not workspace:Raycast(beforeMove, unit * 8, params) then
                            direction = unit
                            break
                        end
                    end
                    assert(direction, "no reachable movement direction from authored spawn")
                    local clientDistance = probe(ground, "Move", { direction = direction })
                    assert(
                        type(clientDistance) == "number" and clientDistance >= 3,
                        "actual Ground did not walk from spawn"
                    )
                    waitFor(function()
                        return (root.Position - beforeMove).Magnitude >= 3
                    end, "Ground motion replicated")
                    local pickup = owned.launcher.snapshot().position
                    place(ground, Vector3.new(pickup.x, pickup.y + 2, pickup.z))
                    local function carry(sequence: number)
                        launcherIntent(ground, "Pickup", sequence)
                        waitFor(function()
                            return owned.launcher.snapshot().ownerId == ground.UserId
                        end, "scatter pickup")
                    end
                    carry(1)
                    launcherIntent(ground, "Drop", 2)
                    waitFor(function()
                        return owned.launcher.snapshot().state == "Available"
                    end, "scatter drop")
                    carry(3)
                    place(ground, Vector3.new(330, 30, 0))
                    preservedPosition = root.Position
                    local aircraftState = ReplicatedStorage.AircraftState
                    local launcherState = ReplicatedStorage.LauncherState
                    local oldAmmo = aircraftState:GetAttribute("Readiness")
                    local oldSelection = aircraftState:GetAttribute("Selection")
                    local oldRifle = HttpService:JSONEncode(owned.groundCombat.readiness(ground))
                    local oldLauncher = owned.launcher.snapshot()
                    local start = owned.aircraft.sample(0).Position
                    equip(ground, "M-7 rifle")
                    intent(ground, "AircraftState", "GroundFire", {
                        roundId = state.roundId,
                        sequence = 99,
                        weapon = "M7",
                        x = start.X,
                        y = start.Y,
                        z = start.Z,
                    })
                    intent(
                        ground,
                        "AircraftState",
                        "GroundReload",
                        { roundId = state.roundId, sequence = 99 }
                    )
                    carried = equip(ground, "Rocket launcher")
                    launcherIntent(ground, "Fire", 99, start)
                    intent(operator, "AircraftState", "SelectWeapon", {
                        roundId = state.roundId,
                        sequence = 99,
                        weapon = "M102",
                    })
                    intent(operator, "AircraftState", "FireWeapon", operatorPayload(state.roundId, 99, start))
                    task.wait(0.3)
                    assert(match.snapshot().phase == "Scatter", "fire probes ran after reveal")
                    assert(
                        aircraftState:GetAttribute("Readiness") == oldAmmo,
                        "operator readiness changed early"
                    )
                    assert(
                        aircraftState:GetAttribute("Selection") == oldSelection,
                        "operator selection changed early"
                    )
                    assert(
                        HttpService:JSONEncode(owned.groundCombat.readiness(ground)) == oldRifle,
                        "rifle readiness changed early"
                    )
                    assert(
                        owned.launcher.snapshot().revision == oldLauncher.revision,
                        "rocket consumed ammo early"
                    )
                    assert(
                        launcherState:GetAttribute("LastShot") == nil
                            and aircraftState:GetAttribute("GroundShot") == nil,
                        "pre-arrival shot resolved"
                    )
                    assert(
                        owned.launcher.resources().queued == 0 and owned.groundCombat.resources().queued == 0,
                        "pre-arrival shot remained queued"
                    )
                    assert(
                        aircraftState:GetAttribute("Health") == 1000
                            and aircraftState:GetAttribute("MaxHealth") == 1000,
                        "deployment health changed early"
                    )
                    noPlane()
                    table.insert(observations, {
                        roundId = state.roundId,
                        groundDisplacementStuds = clientDistance,
                        operatorId = operator.UserId,
                    })
                end
            )
            check(
                "A1 A3 round " .. tostring(round) .. " reveals once at canonical start and preserves Ground",
                function()
                    waitFor(function()
                        if match.snapshot().phase == "Scatter" then
                            noPlane()
                        end
                        return match.snapshot().phase == "Active"
                    end, "aircraft arrival", 22)
                    local active = match.snapshot()
                    local aircraft = workspace.Aircraft
                    local aircraftState = ReplicatedStorage.AircraftState
                    local epoch = aircraftState:GetAttribute("EpochSeconds")
                    assert(
                        type(epoch) == "number"
                            and epoch >= state.deadlineSeconds
                            and epoch - state.deadlineSeconds < 0.5,
                        "arrival missed its first eligible step"
                    )
                    assert(
                        active.roundId == state.roundId and active.deadlineSeconds - epoch == 600,
                        "combat duration was shortened or restarted"
                    )
                    assert(
                        aircraft:GetAttribute("RoundId") == state.roundId,
                        "arrival model has wrong generation"
                    )
                    local poseError = (aircraft:GetPivot().Position - owned.aircraft.sample(0).Position).Magnitude
                    assert(poseError < 5, "arrival skipped the canonical orbit start")
                    assert(
                        ground.Character == char
                            and (bodyPart(ground, "HumanoidRootPart").Position - preservedPosition).Magnitude
                                < 1,
                        "arrival relocated Ground"
                    )
                    assert(
                        carried
                            and carried.Parent == char
                            and owned.launcher.snapshot().ownerId == ground.UserId,
                        "arrival replaced scatter equipment"
                    )
                    assert(
                        ReplicatedStorage.LauncherState:GetAttribute("LastShot") == nil
                            and aircraftState:GetAttribute("GroundShot") == nil,
                        "early fire crossed into combat"
                    )
                    for _, player in { operator, ground } do
                        table.insert(
                            observations,
                            probe(
                                player,
                                "Active",
                                { roundId = state.roundId, role = state.members[player.UserId].role }
                            )
                        )
                    end
                    table.insert(observations, {
                        roundId = state.roundId,
                        revealLateSeconds = epoch - state.deadlineSeconds,
                        poseErrorStuds = poseError,
                    })
                end
            )
            check(
                "A2 A3 round " .. tostring(round) .. " fires fresh rocket and gunship intents on the real map",
                function()
                    local aircraftState = ReplicatedStorage.AircraftState
                    local epoch = aircraftState:GetAttribute("EpochSeconds")
                    assert(type(epoch) == "number", "arrival epoch missing")
                    local head = bodyPart(ground, "Head").Position
                    local elapsed = workspace:GetServerTimeNow() - epoch
                    local lead = owned.aircraft.position()
                    for _ = 1, 5 do
                        local travel = (lead - head).Magnitude / LauncherService.speedStudsPerSecond
                        lead = owned.aircraft.sample(elapsed + travel + 0.1).Position
                    end
                    launcherIntent(ground, "Fire", 4, lead)
                    waitFor(function()
                        return aircraftState:GetAttribute("Health") == 900
                    end, "fresh real direct rocket hit")
                    local wireReadiness = aircraftState:GetAttribute("Readiness")
                    intent(
                        operator,
                        "AircraftState",
                        "FireWeapon",
                        operatorPayload(state.roundId, 1, owned.aircraft.position())
                    )
                    waitFor(function()
                        return aircraftState:GetAttribute("Readiness") ~= wireReadiness
                    end, "fresh real operator fire")
                    waitFor(function()
                        return owned.combat.resources().projectiles == 0
                    end, "first gunship flight resolves against the current structural ledger")
                    -- Impacts and misses both advance the ledger. Replay the
                    -- first flight ID without a panel to distinguish a retired
                    -- flight from a ledger accidentally closed during Scatter.
                    local accepted, rejection = owned.destruction.resolve({
                        roundId = state.roundId,
                        shotId = 1,
                        weapon = "GAU23",
                        firedAt = workspace:GetServerTimeNow(),
                    })
                    assert(
                        not accepted and rejection == "stale, duplicate or unbounded shot",
                        "first gunship flight did not advance structural ledger: " .. tostring(rejection)
                    )
                    reset(state.roundId)
                end
            )
        end
        check(
            "A2 actual Scatter death cancels arrival, consumes one life and returns both avatars to lobby",
            function()
                local _, operator, ground = deploy()
                local character = assert(ground.Character, "Ground character missing")
                local humanoid =
                    assert(character:FindFirstChildOfClass("Humanoid"), "Ground humanoid missing")
                humanoid.Health = 0
                waitFor(function()
                    return match.snapshot().phase == "Results"
                end, "terminal scatter death")
                local ended = match.snapshot()
                assert(
                    ended.result and ended.result.reason == "GroundEliminated",
                    "wrong scatter death outcome"
                )
                noPlane()
                waitFor(function()
                    for _, player in { operator, ground } do
                        local avatar = player.Character
                        if
                            not avatar
                            or not avatar:FindFirstChild("StationProtection")
                            or bodyPart(player, "HumanoidRootPart").Anchored
                        then
                            return false
                        end
                    end
                    return true
                end, "protected walking lobby bodies")
            end
        )
    end)
    if not success and (#cases == 0 or cases[#cases].passed) then
        table.insert(cases, { name = "P24 harness completion", passed = false, detail = tostring(failure) })
    end
    listener:Disconnect()
    transport:Destroy()
    if runtime then
        runtime.stop()
    end
    local passed = 0
    for _, case in cases do
        if case.passed then
            passed += 1
        end
    end
    local report = {
        suite = "P24-multiplayer",
        initialClientCount = initialCount,
        completedRoundIds = completed,
        discovered = #cases,
        passed = passed,
        failed = #cases - passed,
        skipped = 0,
        cases = cases,
        observations = observations,
        clientSmoke = smoke,
        serverSmoke = workspace:GetAttribute("ServerTestReport"),
    }
    workspace:SetAttribute("P24MultiplayerReport", HttpService:JSONEncode(report))
    if automated then
        StudioTestService:EndTest(report)
    end
end

return AircraftArrivalHarness
