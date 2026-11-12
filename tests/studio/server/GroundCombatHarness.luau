--!strict
-- Test-only P06 real-client harness: owned match, M-7, cover, damage and reset.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local StudioTestService = game:GetService("StudioTestService")
local RunService = game:GetService("RunService")
local GameRuntime = require(game:GetService("ServerScriptService").Server.GameRuntime)
local GroundOriginGeometry = require(game:GetService("ServerScriptService").Server.GroundOriginGeometry)
local Harness = {}
-- Fixture-only ballistic default; the production launcher and its final tuning
-- arrive in P08. A 1/6-second step at 300 studs/second sweeps 50 studs.
local FIXTURE_ROCKET_SPEED = 300
local FIXTURE_ROCKET_STEP_SECONDS = 1 / 6
local FIXTURE_ROCKET_STEP = Vector3.new(0, -FIXTURE_ROCKET_SPEED * FIXTURE_ROCKET_STEP_SECONDS, 0)
type Case = { name: string, passed: boolean, detail: string? }
export type Report = {
    suite: string,
    environment: string,
    mode: string,
    departureMethod: string,
    clientCount: number,
    requestedClients: number,
    discovered: number,
    passed: number,
    failed: number,
    skipped: number,
    cases: { Case },
    observations: { unknown },
}
local function waitFor(predicate: () -> boolean, label: string, seconds: number?)
    local deadline = os.clock() + (seconds or 15)
    while not predicate() and os.clock() < deadline do
        task.wait(0.03)
    end
    assert(predicate(), "P06 timeout: " .. label)
end
-- Manual mode invokes finish after complete cleanup; SDK mode uses EndTest.
-- Both paths require the same real-client cases and preserve failures.
function Harness.run(expectedClients: number?, finish: ((Report) -> ())?)
    local expected = expectedClients or 2
    local mode = if finish then "manual-server-clients" else "sdk"
    local departureMethod = if expected >= 3
        then "not-exercised"
        elseif finish then "server-kick"
        else "client-leave"
    local function deliver(report: Report)
        workspace:SetAttribute("P06MultiplayerReport", HttpService:JSONEncode(report))
        if finish then
            finish(report)
        else
            StudioTestService:EndTest(report)
        end
    end
    local function startupFailure(detail: string)
        deliver({
            suite = "P06-multiplayer",
            environment = "Studio",
            mode = mode,
            departureMethod = departureMethod,
            clientCount = #Players:GetPlayers(),
            requestedClients = expected,
            discovered = 1,
            passed = 0,
            failed = 1,
            skipped = 0,
            cases = { { name = "Harness startup", passed = false, detail = detail } },
            observations = {},
        })
    end
    local joined, joinFailure = pcall(function()
        waitFor(function()
            return #Players:GetPlayers() == expected
        end, "actual clients", 35)
        return true
    end)
    if not joined then
        startupFailure(tostring(joinFailure))
        return
    end
    local faultArmed = false
    local queryFailures = 0
    local traceEnabled = false
    local fireDecisions: { unknown } = {}
    local shotObservations: { unknown } = {}
    local tracerObservations: { { endpoint: Vector3, visualEnd: Vector3, length: number } } = {}
    local started, runtimeOrFailure = pcall(function()
        local owner, reason = GameRuntime.start({
            automaticDeployment = false,
            minimumPlayers = 2,
            durationSeconds = 120,
            lobbySeconds = 0,
            deploymentSeconds = 25,
            resultsSeconds = 5,
            seed = 1,
        }, {
            terrainQuery = function(position)
                if faultArmed then
                    faultArmed = false
                    queryFailures += 1
                    error("injected terrain query failure")
                end
                return GroundOriginGeometry.clearTerrain(position)
            end,
            observeFire = function(userId, decision, serverTime)
                if traceEnabled then
                    table.insert(
                        fireDecisions,
                        { userId = userId, decision = decision, serverTime = serverTime }
                    )
                end
            end,
            observeShot = function(shot)
                if traceEnabled then
                    local effects = workspace:FindFirstChild("GroundCombatEffects")
                    local tracer = if effects then effects:FindFirstChild("M7Tracer") else nil
                    if tracer and tracer:IsA("BasePart") then
                        table.insert(tracerObservations, {
                            endpoint = shot.hitPosition,
                            visualEnd = tracer.Position + tracer.CFrame.LookVector * tracer.Size.Z * 0.5,
                            length = tracer.Size.Z,
                        })
                    end
                    local aircraftPosition = shot.aircraftPosition
                    table.insert(shotObservations, {
                        userId = shot.userId,
                        sequence = shot.sequence,
                        serverTime = shot.serverTime,
                        origin = { shot.origin.X, shot.origin.Y, shot.origin.Z },
                        requestedTarget = {
                            shot.requestedTarget.X,
                            shot.requestedTarget.Y,
                            shot.requestedTarget.Z,
                        },
                        hitPosition = { shot.hitPosition.X, shot.hitPosition.Y, shot.hitPosition.Z },
                        hitName = shot.hitName,
                        aircraftPosition = if aircraftPosition
                            then { aircraftPosition.X, aircraftPosition.Y, aircraftPosition.Z }
                            else nil,
                        healthBefore = shot.healthBefore,
                        healthAfter = shot.healthAfter,
                        applied = shot.applied,
                    })
                end
            end,
        })
        assert(owner, reason)
        return owner
    end)
    if not started then
        startupFailure(tostring(runtimeOrFailure))
        return
    end
    local runtime = runtimeOrFailure
    local transport = Instance.new("RemoteEvent")
    transport.Name = "P06Harness"
    local ready: { [Player]: boolean } = {}
    local replies: { [number]: { ok: boolean, message: string } } = {}
    local observations: { unknown } = {}
    local sequence = 0
    local listener = transport.OnServerEvent:Connect(
        function(player: Player, token: unknown, ok: unknown, message: unknown)
            if token == 0 then
                ready[player] = true
            elseif type(token) == "number" then
                replies[token] = { ok = ok == true, message = tostring(message) }
            end
        end
    )
    transport.Parent = ReplicatedStorage
    local function probe(player: Player, kind: string, payload: unknown)
        waitFor(function()
            return ready[player] == true
        end, "client ready")
        sequence += 1
        local token = sequence
        transport:FireClient(player, token, kind, payload)
        waitFor(function()
            return replies[token] ~= nil
        end, "client reply")
        local reply = replies[token]
        replies[token] = nil
        assert(reply.ok, reply.message)
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
        assert(operator and ground, "roles missing")
        return operator, ground
    end
    local function health(): number
        local state = ReplicatedStorage:FindFirstChild("AircraftState")
        local value = if state then state:GetAttribute("Health") else nil
        assert(type(value) == "number", "health missing")
        return value
    end
    local function hitbox(): BasePart
        local model = workspace:FindFirstChild("Aircraft")
        local part = if model then model:FindFirstChild("Hitbox") else nil
        assert(part and part:IsA("BasePart"), "aircraft hitbox missing")
        return part
    end
    -- Two independent Heartbeat callbacks carry ground death and real swept
    -- rocket hits. A separate Stepped marker identifies the simulation epoch;
    -- the Heartbeat marker is retained only to diagnose callback interleaving.
    local function mutualBatch(ground: Player, roundId: number, aircraftFirst: boolean, prefix: string)
        local callbacks = 0
        local callbackErrors: { string } = {}
        local heartbeatFrame, simulationFrame, simulationTime = 0, 0, 0
        local names: { string } = {}
        local heartbeatFrames: { number } = {}
        local simulationFrames: { number } = {}
        local simulationTimes: { number } = {}
        local deltas: { number } = {}
        local calibrationOrder: { string } = {}
        local calibrationFrames: { number } = {}
        local calibrationTimes: { number } = {}
        local calibrationDeltas: { number } = {}
        local aircraftPositions: { { number } } = {}
        local events: { unknown } = {}
        local captureMarkers = false
        local diagnostic = {
            kind = "mutual-batch",
            requestedOrder = if aircraftFirst then "aircraft-first" else "ground-first",
            order = names,
            heartbeatFrames = heartbeatFrames,
            simulationFrames = simulationFrames,
            simulationTimes = simulationTimes,
            heartbeatDeltas = deltas,
            callbackErrors = callbackErrors,
            calibration = {
                order = calibrationOrder,
                simulationFrames = calibrationFrames,
                simulationTimes = calibrationTimes,
                heartbeatDeltas = calibrationDeltas,
            },
            events = events,
            fixtureRocketSpeedStudsPerSecond = FIXTURE_ROCKET_SPEED,
            fixtureRocketStepSeconds = FIXTURE_ROCKET_STEP_SECONDS,
            sweptDistanceStuds = FIXTURE_ROCKET_STEP.Magnitude,
            aircraftPositions = aircraftPositions,
        }
        -- Attach first: even marker/callback timeouts must survive in the report.
        table.insert(observations, diagnostic)
        local function trace(label: string, dt: number?)
            if #events >= 60 then
                return
            end
            local current = runtime.rounds.match.snapshot()
            table.insert(events, {
                label = label,
                heartbeatFrame = heartbeatFrame,
                simulationFrame = simulationFrame,
                simulationTime = simulationTime,
                heartbeatDelta = dt,
                distributedGameTime = workspace.DistributedGameTime,
                serverTime = workspace:GetServerTimeNow(),
                clock = os.clock(),
                phase = current.phase,
                winner = if current.result then current.result.winner else "",
                reason = if current.result then current.result.reason else "",
                aircraftHealth = health(),
            })
        end
        local stepMarker = RunService.Stepped:Connect(function(time)
            simulationFrame += 1
            simulationTime = time
            if captureMarkers then
                trace("stepped-marker", nil)
            end
        end)
        local frameMarker = RunService.Heartbeat:Connect(function(dt)
            heartbeatFrame += 1
            if captureMarkers then
                trace("heartbeat-marker", dt)
            end
        end)
        local markerDeadline = os.clock() + 5
        while (simulationFrame == 0 or heartbeatFrame == 0) and os.clock() < markerDeadline do
            task.wait(0.03)
        end
        if simulationFrame == 0 or heartbeatFrame == 0 then
            stepMarker:Disconnect()
            frameMarker:Disconnect()
            error("P06 timeout: simulation/heartbeat markers")
        end
        captureMarkers = true
        -- Observe this engine's scheduling of two independent callbacks before
        -- registering the combat callbacks. Actual combat order and epoch are
        -- still checked below; a change in scheduling between frames fails.
        local function calibrate(name: string, dt: number)
            table.insert(calibrationOrder, name)
            table.insert(calibrationFrames, simulationFrame)
            table.insert(calibrationTimes, simulationTime)
            table.insert(calibrationDeltas, dt)
            trace("calibration-" .. name, dt)
        end
        local firstCalibration = RunService.Heartbeat:Once(function(dt)
            calibrate("first-registered", dt)
        end)
        local secondCalibration = RunService.Heartbeat:Once(function(dt)
            calibrate("second-registered", dt)
        end)
        local calibrationDeadline = os.clock() + 5
        while #calibrationOrder < 2 and os.clock() < calibrationDeadline do
            task.wait(0.03)
        end
        firstCalibration:Disconnect()
        secondCalibration:Disconnect()
        local calibrationValid = #calibrationOrder == 2
            and ((calibrationOrder[1] == "first-registered" and calibrationOrder[2] == "second-registered") or (calibrationOrder[1] == "second-registered" and calibrationOrder[2] == "first-registered"))
            and calibrationFrames[1] > 0
            and calibrationFrames[1] == calibrationFrames[2]
            and calibrationTimes[1] == calibrationTimes[2]
            and calibrationDeltas[1] == calibrationDeltas[2]
        if not calibrationValid then
            trace("calibration-invalid", nil)
            captureMarkers = false
            stepMarker:Disconnect()
            frameMarker:Disconnect()
            error("invalid callback calibration: " .. HttpService:JSONEncode(diagnostic))
        end
        trace("callbacks-registered", nil)
        local function record(name: string, dt: number)
            table.insert(names, name)
            table.insert(heartbeatFrames, heartbeatFrame)
            table.insert(simulationFrames, simulationFrame)
            table.insert(simulationTimes, simulationTime)
            table.insert(deltas, dt)
            trace(name .. "-start", dt)
        end
        local function checked(name: string, action: () -> ())
            local passed, callbackError = pcall(function()
                action()
                return true
            end)
            if not passed then
                table.insert(callbackErrors, name .. ": " .. tostring(callbackError))
            end
            callbacks += 1
            trace(name .. "-end", nil)
        end
        local function eliminate(dt: number)
            record("ground", dt)
            checked("ground", function()
                assert(
                    runtime.rounds.match.eliminate(ground.UserId, roundId),
                    "last ground elimination rejected"
                )
            end)
        end
        local function destroyAircraft(dt: number)
            record("aircraft", dt)
            checked("aircraft", function()
                local part = hitbox()
                local origin = part.Position + Vector3.new(0, 25, 0)
                table.insert(aircraftPositions, { part.Position.X, part.Position.Y, part.Position.Z })
                for n = 1, 3 do
                    assert(
                        runtime.groundCombat.rocketSweep(roundId, prefix .. n, origin, FIXTURE_ROCKET_STEP),
                        "swept batch rocket rejected"
                    )
                    assert(health() == 300 - n * 100, "pristine rocket damage boundary failed")
                    if n < 3 then
                        assert(
                            runtime.rounds.match.snapshot().phase == "Active",
                            "aircraft destroyed before third rocket"
                        )
                    end
                end
            end)
        end
        local firstAction = if aircraftFirst then destroyAircraft else eliminate
        local secondAction = if aircraftFirst then eliminate else destroyAircraft
        if calibrationOrder[1] == "second-registered" then
            RunService.Heartbeat:Once(secondAction)
            RunService.Heartbeat:Once(firstAction)
        else
            RunService.Heartbeat:Once(firstAction)
            RunService.Heartbeat:Once(secondAction)
        end
        local deadline = os.clock() + 15
        while callbacks < 2 and os.clock() < deadline do
            task.wait(0.03)
        end
        trace("callbacks-complete-or-timeout", nil)
        captureMarkers = false
        stepMarker:Disconnect()
        frameMarker:Disconnect()
        assert(callbacks == 2, "P06 timeout: combat callbacks: " .. HttpService:JSONEncode(diagnostic))
        assert(#callbackErrors == 0, "combat callback failed: " .. HttpService:JSONEncode(diagnostic))
        assert(
            simulationFrames[1] > 0
                and simulationFrames[1] == simulationFrames[2]
                and simulationTimes[1] == simulationTimes[2],
            "callbacks crossed a recorded simulation step: " .. HttpService:JSONEncode(diagnostic)
        )
        assert(
            deltas[1] == deltas[2],
            "callbacks observed different Heartbeat intervals: " .. HttpService:JSONEncode(diagnostic)
        )
        local firstExpected = if aircraftFirst then "aircraft" else "ground"
        local secondExpected = if aircraftFirst then "ground" else "aircraft"
        assert(
            names[1] == firstExpected and names[2] == secondExpected,
            "actual callback order differs: " .. HttpService:JSONEncode(diagnostic)
        )
        waitFor(function()
            return runtime.rounds.match.snapshot().phase == "Results"
        end, "batched result")
        local result = runtime.rounds.match.snapshot().result
        assert(
            result and result.winner == "Ground" and result.reason == "AircraftDestroyed",
            "mutual batch chose wrong winner: " .. HttpService:JSONEncode(diagnostic)
        )
    end
    local fixture = Instance.new("Folder")
    fixture.Name = "P06Fixture"
    fixture.Parent = workspace.World.Battlefield
    local cases: { Case } = {}
    local function check(name: string, callback: () -> ())
        local ok, failure = pcall(function()
            callback()
            return true
        end)
        table.insert(cases, { name = name, passed = ok, detail = if ok then nil else tostring(failure) })
        assert(ok, tostring(failure))
    end
    local ok, failure = pcall(function()
        check("A1 ground receives one rifle and no launcher", function()
            assert(runtime.rounds.match.deploy(), "deployment failed")
            waitFor(function()
                return runtime.rounds.match.snapshot().phase == "Active"
            end, "active", 40)
            local op, ground = roles()
            waitFor(function()
                local bag = ground:FindFirstChildOfClass("Backpack")
                return bag ~= nil and bag:FindFirstChild("M-7 rifle") ~= nil
            end, "rifle loadout")
            for _, player in Players:GetPlayers() do
                if player:GetAttribute("Role") == "Ground" then
                    local bag = assert(player:FindFirstChildOfClass("Backpack"), "backpack missing")
                    waitFor(function()
                        return bag:FindFirstChild("M-7 rifle") ~= nil
                    end, "ground rifle")
                    assert(
                        #bag:GetChildren() == 1 and bag:FindFirstChild("M-7 rifle"),
                        "unexpected ground loadout"
                    )
                end
            end
            local operatorBag = op:FindFirstChildOfClass("Backpack")
            assert(not operatorBag or not operatorBag:FindFirstChild("M-7 rifle"), "operator received rifle")
            assert(health() == 300, "aircraft health not full")
            probe(op, "Observe", { health = 300, hud = true })
            probe(ground, "Observe", { health = 300, hud = true })
        end)
        check("A3 forged and wrong-role requests cannot mutate health or ammo", function()
            local op, ground = roles()
            local bag = assert(ground:FindFirstChildOfClass("Backpack"), "backpack missing")
            local tool = bag:FindFirstChild("M-7 rifle")
            assert(tool and tool:IsA("Tool"), "rifle missing")
            local humanoid = if ground.Character
                then ground.Character:FindFirstChildOfClass("Humanoid")
                else nil
            assert(humanoid, "ground humanoid missing")
            humanoid:EquipTool(tool)
            waitFor(function()
                return tool.Parent == ground.Character
            end, "equipped visible rifle")
            local handle = tool:FindFirstChild("Handle")
            assert(handle and handle:IsA("BasePart"), "rifle handle missing")
            for _, name in { "Barrel", "Stock", "Magazine" } do
                local piece = tool:FindFirstChild(name)
                assert(
                    piece and piece:IsA("BasePart") and piece:FindFirstChildOfClass("WeldConstraint"),
                    name .. " missing or unwelded"
                )
                assert(not piece.CanCollide and not piece.CanQuery, name .. " interferes with world")
            end
            waitFor(function()
                local character = ground.Character
                return character ~= nil and character:FindFirstChild("RightGrip", true) ~= nil
            end, "equipped rifle grip")
            local roundId = runtime.rounds.match.snapshot().roundId
            local target = hitbox().Position
            local forged = {
                roundId = roundId,
                sequence = 1,
                weapon = "M7",
                x = target.X,
                y = target.Y,
                z = target.Z,
                damage = 9999,
            }
            probe(ground, "Fire", forged)
            local valid =
                { roundId = roundId, sequence = 1, weapon = "M7", x = target.X, y = target.Y, z = target.Z }
            probe(op, "Fire", valid)
            probe(ground, "Fire", {
                roundId = roundId - 1,
                sequence = 1,
                weapon = "M7",
                x = target.X,
                y = target.Y,
                z = target.Z,
            })
            probe(
                ground,
                "Fire",
                { roundId = roundId, sequence = 1, weapon = "M7", x = math.huge, y = target.Y, z = target.Z }
            )
            probe(ground, "Flood", forged)
            task.wait(2)
            assert(health() == 300 and tool:GetAttribute("Ammo") == 30, "forged fire mutated state")
            local character = ground.Character
            local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
            assert(root and root:IsA("BasePart"), "ground root missing")
            local originalPose = root.CFrame
            local wasAnchored = root.Anchored
            root.Anchored = true
            root.CFrame = originalPose + Vector3.new(0, 100, 0)
            task.wait(0.2)
            target = hitbox().Position
            probe(
                ground,
                "Fire",
                { roundId = roundId, sequence = 1, weapon = "M7", x = target.X, y = target.Y, z = target.Z }
            )
            task.wait(0.3)
            assert(health() == 300 and tool:GetAttribute("Ammo") == 30, "implausible origin mutated combat")
            root.CFrame = originalPose
            task.wait(0.2)
            root.Anchored = wasAnchored
        end)
        check("A1 server raycast stops rifle at cover then damages aircraft", function()
            local op, ground = roles()
            local character = ground.Character
            local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
            local tool = if character then character:FindFirstChild("M-7 rifle") else nil
            assert(root and root:IsA("BasePart") and tool and tool:IsA("Tool"), "equipped ground missing")
            root.Anchored = true
            local level = runtime.aircraft.level()
            local aircraftPosition = hitbox().Position
            local radial =
                Vector3.new(aircraftPosition.X - level.centerX, 0, aircraftPosition.Z - level.centerZ)
            assert(radial.Magnitude > 0, "aircraft radial direction missing")
            -- The canonical orbit is exactly on the playable boundary. Give the
            -- trusted fixture a 20-stud inward margin so float rounding cannot
            -- trigger the legitimate MapService boundary correction mid-shot.
            root.CFrame = CFrame.new(aircraftPosition - radial.Unit * 20 - Vector3.new(0, 25, 0))
            task.wait(0.15)
            assert(runtime.groundCombat.trustCorrection(ground), "trusted geometry-fixture placement failed")
            local head = character and character:FindFirstChild("Head")
            assert(head and head:IsA("BasePart"), "ground head missing")
            traceEnabled = true
            local samples: { unknown } = {}
            local diagnostic = {
                kind = "rifle-cover-and-open-shot",
                userId = ground.UserId,
                inwardMarginStuds = 20,
                decisions = fireDecisions,
                shots = shotObservations,
                samples = samples,
            }
            table.insert(observations, diagnostic)
            local function sample(stage: string, requested: Vector3?)
                local state = runtime.rounds.match.snapshot()
                local member = state.members[ground.UserId]
                local plane = hitbox().Position
                table.insert(samples, {
                    stage = stage,
                    serverTime = workspace:GetServerTimeNow(),
                    roundId = state.roundId,
                    phase = state.phase,
                    role = if member then member.role else "missing",
                    life = if member then member.life else "missing",
                    readiness = runtime.groundCombat.readiness(ground),
                    ammo = tool:GetAttribute("Ammo"),
                    health = health(),
                    root = { root.Position.X, root.Position.Y, root.Position.Z },
                    head = { head.Position.X, head.Position.Y, head.Position.Z },
                    aircraftPosition = { plane.X, plane.Y, plane.Z },
                    requestedTarget = if requested then { requested.X, requested.Y, requested.Z } else nil,
                })
            end
            sample("trusted-position", nil)
            local embedded = Instance.new("Part")
            embedded.Name = "P06EmbeddedCover"
            embedded.Anchored = true
            embedded.Size = Vector3.new(8, 8, 8)
            embedded.Position = head.Position
            embedded.Parent = fixture
            local roundId = runtime.rounds.match.snapshot().roundId
            local target = hitbox().Position
            sample("before-embedded-shot", target)
            probe(
                ground,
                "Fire",
                { roundId = roundId, sequence = 1, weapon = "M7", x = target.X, y = target.Y, z = target.Z }
            )
            task.wait(0.3)
            assert(health() == 300 and tool:GetAttribute("Ammo") == 30, "embedded cover allowed fire")
            sample("after-embedded-shot", nil)
            embedded:Destroy()
            local bodyWall = Instance.new("Part")
            bodyWall.Name = "P06BodySegmentCover"
            bodyWall.Anchored = true
            bodyWall.Size = Vector3.new(8, 0.2, 8)
            bodyWall.Position = root.Position:Lerp(head.Position, 0.5)
            bodyWall.Parent = fixture
            sample("before-body-wall-shot", target)
            probe(
                ground,
                "Fire",
                { roundId = roundId, sequence = 1, weapon = "M7", x = target.X, y = target.Y, z = target.Z }
            )
            task.wait(0.3)
            assert(health() == 300 and tool:GetAttribute("Ammo") == 30, "body-to-head cover allowed fire")
            sample("after-body-wall-shot", nil)
            bodyWall:Destroy()
            local wall = Instance.new("Part")
            wall.Name = "P06Cover"
            wall.Anchored = true
            wall.Size = Vector3.new(120, 1, 120)
            wall.Position = hitbox().Position - Vector3.new(0, 12, 0)
            wall.Parent = fixture
            target = hitbox().Position
            sample("before-solid-cover-shot", target)
            probe(
                ground,
                "Fire",
                { roundId = roundId, sequence = 1, weapon = "M7", x = target.X, y = target.Y, z = target.Z }
            )
            waitFor(function()
                return tool:GetAttribute("Ammo") == 29
            end, "blocked shot")
            assert(health() == 300, "cover failed to block damage")
            sample("after-solid-cover-shot", nil)
            wall:Destroy()
            task.wait(0.2)
            local teammateHumanoid: Humanoid? = nil
            local teammateModel: Model? = nil
            if expected >= 3 then
                for _, player in Players:GetPlayers() do
                    if player ~= ground and player:GetAttribute("Role") == "Ground" then
                        local teammateCharacter = player.Character
                        teammateModel = teammateCharacter
                        local teammateRoot = if teammateCharacter
                            then teammateCharacter:FindFirstChild("HumanoidRootPart")
                            else nil
                        teammateHumanoid = if teammateCharacter
                            then teammateCharacter:FindFirstChildOfClass("Humanoid")
                            else nil
                        assert(
                            teammateRoot and teammateRoot:IsA("BasePart") and teammateHumanoid,
                            "teammate fixture missing"
                        )
                        teammateRoot.Anchored = true
                        teammateRoot.CFrame = CFrame.new(head.Position:Lerp(hitbox().Position, 0.55))
                        assert(
                            runtime.groundCombat.trustCorrection(player),
                            "trusted teammate fixture placement failed"
                        )
                    end
                end
                assert(teammateHumanoid, "teammate missing")
                task.wait(0.1)
            end
            local teammateHealth = if teammateHumanoid then teammateHumanoid.Health else 0
            target = hitbox().Position
            sample("before-exposed-shot", target)
            if teammateModel then
                local filter = RaycastParams.new()
                filter.FilterType = Enum.RaycastFilterType.Include
                filter.FilterDescendantsInstances = { teammateModel }
                assert(
                    workspace:Raycast(head.Position, target - head.Position, filter),
                    "rifle path did not cross teammate"
                )
            end
            probe(
                ground,
                "Fire",
                { roundId = roundId, sequence = 2, weapon = "M7", x = target.X, y = target.Y, z = target.Z }
            )
            local deadline = os.clock() + 8
            local nextSample = 0
            while health() ~= 295 and os.clock() < deadline do
                if os.clock() >= nextSample then
                    sample("waiting-exposed-shot", nil)
                    nextSample = os.clock() + 0.25
                end
                task.wait(0.03)
            end
            sample("after-exposed-shot", nil)
            assert(health() == 295, "real rifle hit aircraft failed: " .. HttpService:JSONEncode(diagnostic))
            local latestTracer = tracerObservations[#tracerObservations]
            assert(
                latestTracer and (latestTracer.visualEnd - latestTracer.endpoint).Magnitude < 0.01,
                "tracer endpoint disagrees with authoritative hit"
            )
            assert(latestTracer.length <= 12.01, "tracer exceeds terminal segment")
            if teammateHumanoid then
                assert(teammateHumanoid.Health == teammateHealth, "rifle damaged a ground teammate")
            end
            probe(op, "Observe", { health = 295, shotSequence = 2, shotAircraftHit = true, hud = true })
            probe(ground, "Observe", { health = 295, shotSequence = 2, shotAircraftHit = true, hud = true })
            traceEnabled = false
            fireDecisions = {}
            shotObservations = {}
        end)
        check("A2 direct swept rocket fixtures destroy once", function()
            local roundId = runtime.rounds.match.snapshot().roundId
            local _, activeGround = roles()
            local eliminated: Player? = nil
            if expected >= 3 then
                for _, player in Players:GetPlayers() do
                    if player ~= activeGround and player:GetAttribute("Role") == "Ground" then
                        eliminated = player
                    end
                end
                assert(eliminated, "second ground player missing")
                assert(
                    runtime.rounds.match.eliminate(eliminated.UserId, roundId),
                    "teammate elimination failed"
                )
                waitFor(function()
                    return eliminated:GetAttribute("Life") == "Eliminated"
                end, "teammate eliminated")
                assert(runtime.rounds.match.snapshot().phase == "Active", "round ended while teammate alive")
                local target = hitbox().Position
                probe(eliminated, "Fire", {
                    roundId = roundId,
                    sequence = 100,
                    weapon = "M7",
                    x = target.X,
                    y = target.Y,
                    z = target.Z,
                })
                task.wait(0.2)
                assert(health() == 295, "eliminated player damaged aircraft")
            end
            assert(not runtime.groundCombat.rocketImpact(roundId, "miss", false), "near miss caused damage")
            assert(health() == 295, "near miss altered health")
            for n = 1, 3 do
                local part = hitbox()
                local origin = part.Position + Vector3.new(0, 25, 0)
                assert(
                    runtime.groundCombat.rocketSweep(roundId, "rocket" .. n, origin, FIXTURE_ROCKET_STEP),
                    "swept rocket missed aircraft"
                )
                table.insert(observations, {
                    kind = "live-orbit-rocket-sweep",
                    shot = n,
                    aircraftPosition = { part.Position.X, part.Position.Y, part.Position.Z },
                    origin = { origin.X, origin.Y, origin.Z },
                    fixtureRocketSpeedStudsPerSecond = FIXTURE_ROCKET_SPEED,
                    fixtureRocketStepSeconds = FIXTURE_ROCKET_STEP_SECONDS,
                    sweptDistanceStuds = FIXTURE_ROCKET_STEP.Magnitude,
                    healthAfter = health(),
                })
                if n < 3 then
                    assert(health() == 295 - n * 100, "incorrect rocket damage")
                end
                if n == 1 then
                    assert(
                        not runtime.groundCombat.rocketSweep(roundId, "rocket1", origin, FIXTURE_ROCKET_STEP),
                        "duplicate hit accepted"
                    )
                end
            end
            assert(health() == 0, "health did not clamp")
            waitFor(function()
                return runtime.rounds.match.snapshot().phase == "Results"
            end, "ground victory")
            local result = runtime.rounds.match.snapshot().result
            assert(result and result.winner == "Ground", "wrong winner")
            if eliminated then
                assert(
                    runtime.rounds.match.snapshot().members[eliminated.UserId].life == "Eliminated",
                    "eliminated teammate lost team result"
                )
                probe(eliminated, "Observe", { health = 0, destroyed = true, winner = "Ground" })
            end
            assert(not runtime.groundCombat.rocketImpact(roundId, "late", true), "terminal hit accepted")
            local op, ground = roles()
            probe(op, "Observe", { health = 0, destroyed = true, winner = "Ground" })
            probe(ground, "Observe", { health = 0, destroyed = true, winner = "Ground" })
        end)
        check("A5 reset restores aircraft and no stale equipment", function()
            local previousRound = runtime.rounds.match.snapshot().roundId
            waitFor(function()
                return runtime.rounds.match.snapshot().phase == "Lobby"
            end, "lobby reset", 25)
            waitFor(function()
                return health() == 300
            end, "pristine health")
            assert(
                ReplicatedStorage.AircraftState:GetAttribute("GroundShot") == nil,
                "stale shot survived reset"
            )
            for _, player in Players:GetPlayers() do
                probe(player, "Observe", { health = 300, shotCleared = true })
            end
            assert(runtime.groundCombat.resources().tools == 0, "rifle leaked into lobby")
            assert(runtime.rounds.match.deploy(), "second deployment failed")
            waitFor(function()
                return runtime.rounds.match.snapshot().phase == "Active"
            end, "new active round", 40)
            local _, ground = roles()
            waitFor(function()
                local bag = ground:FindFirstChildOfClass("Backpack")
                local tool = if bag then bag:FindFirstChild("M-7 rifle") else nil
                return tool ~= nil and tool:GetAttribute("Ammo") == 30
            end, "fresh rifle")
            assert(health() == 300, "fresh round not pristine")
            local backpack = assert(ground:FindFirstChildOfClass("Backpack"), "fresh backpack missing")
            local tool = backpack:FindFirstChild("M-7 rifle")
            local humanoid = if ground.Character
                then ground.Character:FindFirstChildOfClass("Humanoid")
                else nil
            assert(tool and tool:IsA("Tool") and humanoid, "fresh rifle or humanoid missing")
            humanoid:EquipTool(tool)
            local target = hitbox().Position
            probe(ground, "Fire", {
                roundId = previousRound,
                sequence = 1,
                weapon = "M7",
                x = target.X,
                y = target.Y,
                z = target.Z,
            })
            task.wait(0.2)
            assert(health() == 300 and tool:GetAttribute("Ammo") == 30, "old-round shot mutated new round")
            assert(
                runtime.groundCombat.resources().tools == expected - 1,
                "duplicate rifle owner after reset"
            )
            local root = if ground.Character then ground.Character:FindFirstChild("HumanoidRootPart") else nil
            assert(root and root:IsA("BasePart"), "ground root missing for map correction")
            root.CFrame = CFrame.new(1000, root.Position.Y, 0)
            waitFor(function()
                return math.abs(root.Position.X) < 360
            end, "server boundary correction")
            local head = if ground.Character then ground.Character:FindFirstChild("Head") else nil
            assert(head and head:IsA("BasePart"), "corrected head missing")
            target = head.Position + Vector3.new(0, 0, 30)
            probe(ground, "Fire", {
                roundId = runtime.rounds.match.snapshot().roundId,
                sequence = 2,
                weapon = "M7",
                x = target.X,
                y = target.Y,
                z = target.Z,
            })
            waitFor(function()
                return tool:GetAttribute("Ammo") == 29
            end, "valid fire after server correction")
        end)
        check("A3 terrain-query failure rejects remote without mutation then recovers", function()
            local _, ground = roles()
            local character = ground.Character
            local head = if character then character:FindFirstChild("Head") else nil
            local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
            local tool = if character then character:FindFirstChild("M-7 rifle") else nil
            assert(
                head and head:IsA("BasePart") and root and root:IsA("BasePart") and tool and tool:IsA("Tool"),
                "equipped rifle fixture missing"
            )
            local target = head.Position + Vector3.new(0, 0, 30)
            local command = {
                roundId = runtime.rounds.match.snapshot().roundId,
                sequence = 3,
                weapon = "M7",
                x = target.X,
                y = target.Y,
                z = target.Z,
            }
            local samples: { unknown } = {}
            local diagnostic = {
                kind = "terrain-query-recovery",
                command = command,
                userId = ground.UserId,
                decisions = fireDecisions,
                samples = samples,
            }
            table.insert(observations, diagnostic)
            local function sample(stage: string)
                local state = runtime.rounds.match.snapshot()
                local member = state.members[ground.UserId]
                local readiness = runtime.groundCombat.readiness(ground)
                table.insert(samples, {
                    stage = stage,
                    serverTime = workspace:GetServerTimeNow(),
                    readiness = readiness,
                    toolAmmo = tool:GetAttribute("Ammo"),
                    health = health(),
                    phase = state.phase,
                    actualRoundId = state.roundId,
                    role = if member then member.role else "missing",
                    life = if member then member.life else "missing",
                    toolEquipped = tool.Parent == ground.Character,
                    root = { root.Position.X, root.Position.Y, root.Position.Z },
                    head = { head.Position.X, head.Position.Y, head.Position.Z },
                    queryFailures = queryFailures,
                    faultArmed = faultArmed,
                })
            end
            sample("before-readiness-wait")
            -- The preceding correction probe spent seq 2. Wait on the actual
            -- server readiness deadline rather than assuming event timing.
            waitFor(function()
                local readiness = runtime.groundCombat.readiness(ground)
                return readiness.ammo == 29
                    and readiness.reloadUntil == 0
                    and workspace:GetServerTimeNow() >= readiness.nextFire
            end, "actual rifle readiness before terrain fault", 5)
            sample("ready-before-fault")
            local beforeAmmo = tool:GetAttribute("Ammo")
            local beforeHealth = health()
            assert(beforeAmmo == 29, "unexpected ammunition before query failure")
            traceEnabled = true
            faultArmed = true
            probe(ground, "Fire", command)
            local deadline = os.clock() + 5
            local nextSample = 0
            while queryFailures == 0 and os.clock() < deadline do
                if os.clock() >= nextSample then
                    sample("waiting-for-injection")
                    nextSample = os.clock() + 0.25
                end
                task.wait(0.03)
            end
            sample("after-fault-attempt")
            assert(
                queryFailures == 1,
                "injected query failure not reached: " .. HttpService:JSONEncode(diagnostic)
            )
            assert(
                tool:GetAttribute("Ammo") == beforeAmmo and health() == beforeHealth,
                "failed terrain query mutated combat: " .. HttpService:JSONEncode(diagnostic)
            )
            probe(ground, "Fire", command)
            local recoveryDeadline = os.clock() + 5
            nextSample = 0
            while tool:GetAttribute("Ammo") ~= 28 and os.clock() < recoveryDeadline do
                if os.clock() >= nextSample then
                    sample("waiting-for-recovery")
                    nextSample = os.clock() + 0.25
                end
                task.wait(0.03)
            end
            sample("after-recovery-attempt")
            traceEnabled = false
            assert(
                tool:GetAttribute("Ammo") == 28,
                "same valid sequence failed after recovery: " .. HttpService:JSONEncode(diagnostic)
            )
            assert(health() == beforeHealth, "horizontal recovery shot damaged aircraft")
        end)
        if expected == 2 then
            check(
                "A4 last ground elimination then aircraft destruction share one simulation batch",
                function()
                    local _, ground = roles()
                    local roundId = runtime.rounds.match.snapshot().roundId
                    mutualBatch(ground, roundId, false, "batchA")
                end
            )
            check(
                "A4 aircraft destruction then last ground elimination share one simulation batch",
                function()
                    waitFor(function()
                        return runtime.rounds.match.snapshot().phase == "Lobby"
                    end, "batch lobby", 25)
                    assert(runtime.rounds.match.deploy(), "batch deployment failed")
                    waitFor(function()
                        return runtime.rounds.match.snapshot().phase == "Active"
                    end, "batch active", 40)
                    local _, ground = roles()
                    local roundId = runtime.rounds.match.snapshot().roundId
                    waitFor(function()
                        return health() == 300
                    end, "batch pristine health")
                    mutualBatch(ground, roundId, true, "batchB")
                end
            )
            check("A4 actual operator disconnect has separate forfeit reason", function()
                waitFor(function()
                    return runtime.rounds.match.snapshot().phase == "Lobby"
                end, "forfeit lobby", 25)
                assert(runtime.rounds.match.deploy(), "forfeit deployment failed")
                waitFor(function()
                    return runtime.rounds.match.snapshot().phase == "Active"
                end, "forfeit active", 40)
                local operator = roles()
                if finish then
                    -- Manual Server & Clients has no SDK-owned LeaveTest.
                    -- Kicking the simulated operator causes an actual player
                    -- departure; report its method separately from SDK leave.
                    operator:Kick("P06 manual disconnect fixture")
                else
                    probe(operator, "Leave", nil)
                end
                waitFor(function()
                    return #Players:GetPlayers() == 1
                end, "actual operator departure", 15)
                waitFor(function()
                    return runtime.rounds.match.snapshot().phase == "Results"
                end, "forfeit result")
                local result = runtime.rounds.match.snapshot().result
                assert(
                    result and result.winner == "Ground" and result.reason == "OperatorForfeit",
                    "wrong operator departure reason"
                )
            end)
        end
        check("A5 repeated-round teardown releases tools and listeners", function()
            runtime.stop()
            assert(
                runtime.groundCombat.resources().connections == 0
                    and runtime.groundCombat.resources().tools == 0,
                "ground combat resources leaked"
            )
            assert(not workspace:FindFirstChild("GroundCombatEffects"), "rifle effects leaked")
            assert(not ReplicatedStorage:FindFirstChild("AircraftState"), "aircraft transport leaked")
        end)
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
    local report: Report = {
        suite = "P06-multiplayer",
        environment = "Studio",
        mode = mode,
        departureMethod = departureMethod,
        clientCount = expected,
        requestedClients = expected,
        discovered = #cases,
        passed = passed,
        failed = #cases - passed,
        skipped = 0,
        cases = cases,
        observations = observations,
    }
    deliver(report)
end
return Harness
