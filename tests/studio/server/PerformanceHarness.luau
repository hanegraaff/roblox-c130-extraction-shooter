--!strict
-- P19Profile reuses P11 timing and measurement with current battlefield targets.
-- P11 test-only coordinator for actual players and production combat owners.
-- The same seeded workload drives profiling and soak. A scoped RemoteEvent asks
-- clients to send production intents and report observations; it never grants
-- roles, hits or equipment. Reports retain only bounded samples and aggregates.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local StudioTestService = game:GetService("StudioTestService")
local Server = game:GetService("ServerScriptService").Server
local GameRuntime = require(Server.GameRuntime)
local GroundCombatRuntime = require(Server.GroundCombatRuntime)
local LauncherRuntime = require(Server.LauncherRuntime)
local GroundCombatService = require(Server.GroundCombatService)
local AircraftHealth = require(Server.AircraftHealth)
local CombatService = require(Server.CombatService)
local DestructionService = require(Server.DestructionService)
local PanelFragments = require(Server.PanelFragments)
local Fixture = require(script.Parent.P11CombatFixture)
local Metrics = require(ReplicatedStorage.P11Metrics)
local Harness = {}
local seed = 11021
local profileSeconds = 300
local profileSettings =
    string.format("%dx%d and %s", Metrics.profile.width, Metrics.profile.height, Metrics.profile.graphics)
local soakRounds = 10 -- after one completed warmup round
local soakActiveSeconds = 180
local air = "AircraftState"
local launcherState = "LauncherState"

type Mode = "Replay" | "Latency" | "Profile" | "Soak"
type Case = { name: string, passed: boolean, detail: string? }
type Payload = { [string]: unknown }
type Ticket = { player: Player, result: unknown, ok: boolean? }
type Counts = { [string]: number }
type Crew = {
    operator: Player,
    ground: { Player },
    roundId: number,
    activeBodies: { [Player]: Model },
}
type Report = {
    suite: string,
    mode: Mode,
    environment: string,
    seed: number,
    requestedClients: number,
    clientCount: number,
    finalClients: number,
    discovered: number,
    passed: number,
    failed: number,
    skipped: number,
    cases: { Case },
    observations: { [string]: unknown },
}

local function waitFor(predicate: () -> boolean, label: string, seconds: number)
    local deadline = os.clock() + seconds
    repeat
        if predicate() then
            return
        end
        task.wait()
    until os.clock() >= deadline
    error("P11 timeout: " .. label, 2)
end

local function attributes(owner: Instance, key: string): Payload
    local value = owner:GetAttribute(key)
    assert(type(value) == "string", "missing " .. key)
    return HttpService:JSONDecode(value)
end

local function resources(runtime: GameRuntime.Controller): Counts
    local frame = runtime.resources()
    local round = runtime.rounds.resources()
    local aircraft = runtime.aircraft.resources()
    local ground = runtime.groundCombat.resources()
    local launcher = runtime.launcher.resources()
    local combat = runtime.combat.resources()
    local destruction = runtime.destruction.resources()
    return {
        connections = frame.frameConnections
            + round.connections
            + aircraft.connections
            + ground.connections
            + launcher.connections
            + combat.connections,
        spawnTasks = round.spawnTasks,
        panels = destruction.panels,
        fragments = destruction.fragments,
        pendingOutcomes = destruction.pending,
        pendingBarriers = destruction.barriers,
        launcherQueue = launcher.queued,
        launcherQueuePeak = launcher.peakQueued,
        launcherRepresentations = launcher.representations,
        launcherFlights = launcher.flights,
        launcherEffects = launcher.effects,
        rifleQueue = ground.queued,
        rifleQueuePeak = ground.peakQueued,
        rifleTools = ground.tools,
        rifleTracers = ground.tracers,
        projectiles = combat.projectiles,
        gunshipEffects = combat.effects,
    }
end

-- Rifle and launcher queues track enqueue high-water marks. Structural
-- boundaries, effects and flights are sampled on each probe tick.
local function checkBounds(counts: Counts)
    assert(counts.launcherQueuePeak <= LauncherRuntime.queueCapacity, "launcher queue exceeded capacity")
    assert(counts.rifleQueuePeak <= GroundCombatRuntime.queueCapacity, "rifle queue exceeded capacity")
    assert(counts.pendingOutcomes <= DestructionService.outcomeWindow, "structural outcome window exceeded")
    assert(
        counts.pendingBarriers <= DestructionService.outcomeWindow + 1,
        "structural barrier window exceeded"
    )
    assert(counts.launcherRepresentations <= 4, "launcher representation duplicated")
    assert(counts.fragments <= PanelFragments.defaults.maximum, "fragment cap exceeded")
end

local function assertDrained(counts: Counts, baseline: Counts)
    for key, value in baseline do
        if key ~= "launcherQueuePeak" and key ~= "rifleQueuePeak" then
            assert(
                counts[key] == value,
                string.format("retained %s: expected %d, found %d", key, value, counts[key])
            )
        end
    end
end

local function launcherIntent(
    action: string,
    identity: string,
    roundId: number,
    sequence: number,
    point: Vector3?
): Fixture.Intent
    local body: Payload = { roundId = roundId, launcherId = identity, sequence = sequence }
    if point then
        body.x, body.y, body.z = point.X, point.Y, point.Z
    end
    return { owner = launcherState, remote = action, body = body }
end

-- Studio SDK and native Server & Clients use the same coordinator. Only a
-- trusted server-side invocation picks a scenario/actual client count.
local function runScenario(rawMode: unknown, rawExpected: unknown, finish: ((Report) -> ())?, suite: string)
    local mode: Mode = if rawMode == "Latency"
            or rawMode == "Profile"
            or rawMode == "Soak"
        then rawMode
        else "Replay"
    local expected = if type(rawExpected) == "number" then rawExpected else 2
    local cases: { Case } = {}
    local observations: { [string]: unknown } = {}
    local roster: { Player } = {}
    local function stage(name: string)
        workspace:SetAttribute(suite .. "Stage", name)
    end
    local function check(name: string, operation: () -> ()): boolean
        stage(name)
        local ok, problem = pcall(function()
            operation()
            return true
        end)
        table.insert(cases, { name = name, passed = ok, detail = if ok then nil else tostring(problem) })
        return ok
    end
    local function deliver()
        local passed = 0
        for _, case in cases do
            if case.passed then
                passed += 1
            end
        end
        stage("finished")
        local report: Report = {
            suite = suite,
            mode = mode,
            environment = "Studio",
            seed = seed,
            requestedClients = expected,
            clientCount = #roster,
            finalClients = #Players:GetPlayers(),
            discovered = #cases,
            passed = passed,
            failed = #cases - passed,
            skipped = 0,
            cases = cases,
            observations = observations,
        }
        workspace:SetAttribute(suite .. "Report", HttpService:JSONEncode(report))
        if finish then
            finish(report)
        else
            StudioTestService:EndTest(report)
        end
    end
    if
        not check("Actual roster and server smoke", function()
            assert(rawMode == nil or rawMode == mode, "unknown P11 scenario")
            assert(expected >= 2 and expected <= 8 and expected % 1 == 0, "expected 2–8 actual clients")
            waitFor(function()
                return #Players:GetPlayers() == expected
            end, "actual client count", 45)
            roster = Players:GetPlayers()
            table.sort(roster, function(left, right)
                return left.UserId < right.UserId
            end)
            local ids = {}
            for _, player in roster do
                table.insert(ids, player.UserId)
            end
            observations.initialUserIds = ids
            local smoke = attributes(workspace, "ServerTestReport")
            assert(
                type(smoke.passed) == "number"
                    and smoke.passed > 0
                    and smoke.failed == 0
                    and smoke.skipped == 0
                    and smoke.errors == 0,
                "server smoke failed or empty"
            )
            observations.serverSmoke = smoke
        end)
    then
        deliver()
        return
    end

    local rifleDecisions: Counts = {}
    local requests: Counts = {}
    local duration = if mode == "Profile" then 330 elseif mode == "Soak" then 195 else 20
    local runtime, reason = GameRuntime.start({
        automaticDeployment = false,
        minimumPlayers = expected,
        durationSeconds = duration,
        lobbySeconds = 0,
        deploymentSeconds = 25,
        resultsSeconds = 3,
        seed = seed,
    }, {
        observeFire = function(_, decision)
            rifleDecisions[decision] = (rifleDecisions[decision] or 0) + 1
        end,
    })
    if not runtime then
        table.insert(cases, { name = "Runtime startup", passed = false, detail = reason })
        deliver()
        return
    end

    local match = runtime.rounds.match
    local aircraft = ReplicatedStorage.AircraftState
    local transport = Instance.new("RemoteEvent")
    transport.Name = "P11Harness"
    local tickets: { [number]: Ticket } = {}
    local clientSmoke: { [Player]: Payload } = {}
    local clientErrors: { [Player]: string } = {}
    local nextTicket = 0
    local listener = transport.OnServerEvent:Connect(
        function(player: Player, token: unknown, ok: unknown, payload: unknown)
            if token == -1 and ok == true and type(payload) == "string" and #payload <= 1024 then
                local decodedOk, report = pcall(function(): Payload
                    return HttpService:JSONDecode(payload)
                end)
                if decodedOk and type(report) == "table" and report.userId == player.UserId then
                    clientSmoke[player] = report
                end
            elseif token == 0 and ok == false and type(payload) == "string" then
                clientErrors[player] = string.sub(payload, 1, 500)
            elseif type(token) == "number" and type(ok) == "boolean" then
                local ticket = tickets[token]
                if ticket and ticket.player == player and ticket.ok == nil then
                    ticket.ok, ticket.result = ok, payload
                end
            end
        end
    )
    transport.Parent = ReplicatedStorage

    local function assertRoster()
        assert(#Players:GetPlayers() == #roster, "actual client count changed")
        for _, player in roster do
            assert(player.Parent == Players, "client left: " .. player.Name)
            assert(not clientErrors[player], clientErrors[player])
        end
    end
    local function request(player: Player, action: string, payload: unknown): number
        nextTicket += 1
        local token = nextTicket
        tickets[token] = { player = player, result = nil, ok = nil }
        transport:FireClient(player, token, action, payload)
        return token
    end
    local function receive(token: number): unknown
        local ticket = assert(tickets[token], "missing fixture response")
        waitFor(function()
            return ticket.ok ~= nil
        end, ticket.player.Name .. " fixture response", 6)
        tickets[token] = nil
        assert(ticket.ok, tostring(ticket.result))
        return ticket.result
    end
    local function allClients(action: string, payload: unknown): { [string]: unknown }
        local pending = {}
        local responses: { [string]: unknown } = {}
        for _, player in roster do
            pending[player] = request(player, action, payload)
        end
        for _, player in roster do
            responses[tostring(player.UserId)] = receive(pending[player])
        end
        return responses
    end
    local function send(player: Player, intents: { Fixture.Intent }, acknowledged: boolean?)
        for _, intent in intents do
            local key = intent.owner .. "/" .. intent.remote
            requests[key] = (requests[key] or 0) + (intent.repetitions or 1)
        end
        if acknowledged then
            receive(request(player, "Send", intents))
        else
            transport:FireClient(player, 0, "Send", intents)
        end
    end
    local function health(): number
        local value = aircraft:GetAttribute("Health")
        assert(type(value) == "number", "aircraft health missing")
        return value
    end
    local function deploy(): Crew
        local accepted, problem = match.deploy()
        assert(accepted, problem)
        waitFor(function()
            return match.snapshot().phase == "Active" and runtime.launcher.snapshot().state == "Available"
        end, "deployment and launcher availability", 28)
        local snapshot = match.snapshot()
        local operator: Player? = nil
        local ground = {}
        local activeBodies: { [Player]: Model } = {}
        for _, player in roster do
            activeBodies[player] = assert(player.Character, "deployed client has no character")
            local member = assert(snapshot.members[player.UserId], "actual client missing from roster")
            if member.role == "Gunship" then
                assert(not operator, "duplicate operator")
                operator = player
            else
                assert(member.role == "Ground" and member.life == "Alive", "invalid ground role")
                table.insert(ground, player)
            end
        end
        assert(operator and #ground == #roster - 1, "incomplete role assignment")
        return {
            operator = operator,
            ground = ground,
            roundId = snapshot.roundId,
            activeBodies = activeBodies,
        }
    end

    -- The round can publish Lobby before launching replacement avatars on the
    -- next frame. Sample character generation, placement and zero load tasks
    -- together so an intermediate Lobby cannot establish a misleading baseline.
    local function waitLobby(previousBodies: { [Player]: Model }?)
        waitFor(function()
            assertRoster()
            if match.snapshot().phase ~= "Lobby" or runtime.rounds.resources().spawnTasks ~= 0 then
                return false
            end
            local station = workspace.World.Battlefield.LobbyStation
            local deck = station:FindFirstChild("LobbyFloorMain", true) or station:FindFirstChild("LobbyDeck")
            if not deck or not deck:IsA("BasePart") then
                return false
            end
            for _, player in roster do
                local body = player.Character
                if not body or body == (if previousBodies then previousBodies[player] else nil) then
                    return false
                end
                local humanoid = body:FindFirstChildOfClass("Humanoid")
                local root = body:FindFirstChild("HumanoidRootPart")
                if
                    player:GetAttribute("Role") ~= "Waiting"
                    or not humanoid
                    or humanoid.Health <= 0
                    or not root
                    or not root:IsA("BasePart")
                    or root.Anchored
                then
                    return false
                end
                local offset = deck.CFrame:PointToObjectSpace(root.Position)
                local half = deck.Size / 2
                if
                    math.abs(offset.X) > half.X
                    or math.abs(offset.Z) > half.Z
                    or offset.Y < half.Y
                    or offset.Y > half.Y + 20
                then
                    return false
                end
            end
            return true
        end, "fresh mobile lobby characters on the protected deck with zero load tasks", 15)
    end
    local function finishRound(crew: Crew, abortReason: string?)
        local roundId = crew.roundId
        waitFor(function()
            return match.snapshot().phase == "Results"
        end, "competitive result", duration + 3)
        local result = assert(match.snapshot().result, "missing authoritative result")
        local expectedReason = abortReason or "Timeout"
        local winner = if abortReason then "None" else "Gunship"
        assert(result.reason == expectedReason and result.winner == winner, "unexpected replay result")
        allClients("Check", {
            roundId = roundId,
            phase = "Results",
            health = health(),
            launcherState = "Inactive",
            resultReason = expectedReason,
            winner = winner,
        })
        waitFor(function()
            return match.snapshot().phase == "Lobby"
        end, "Lobby committed", 15)
        allClients("Check", {
            roundId = roundId,
            phase = "Lobby",
            health = AircraftHealth.maximum,
            launcherState = "Inactive",
            weapon = "GAU23",
        })
        waitLobby(crew.activeBodies)
    end
    local function selectWeapon(crew: Crew, weapon: string, serial: number, copies: number?)
        send(crew.operator, {
            {
                owner = air,
                remote = "SelectWeapon",
                body = { roundId = crew.roundId, sequence = serial, weapon = weapon },
                repetitions = copies,
            },
        })
        waitFor(function()
            return runtime.aircraft.weapon() == weapon
        end, "server selection " .. weapon, 4)
    end
    local function pickup(crew: Crew, repetitions: number): number
        local initial = runtime.launcher.snapshot()
        local point = Vector3.new(initial.position.x, initial.position.y + 2, initial.position.z)
        local pick = launcherIntent("Pickup", initial.launcherId, crew.roundId, 1, nil)
        pick.repetitions = repetitions
        -- Each real Ground client attempts the same identity when there is a
        -- recovery teammate available. Requests can race, so credit the winner.
        for _, player in crew.ground do
            Fixture.pose(runtime, player, point)
            send(player, { pick })
        end
        waitFor(function()
            return runtime.launcher.snapshot().ownerId ~= nil
        end, "launcher pickup", 4)
        local held = runtime.launcher.snapshot()
        assert(
            held.ownerId and held.launcherId == initial.launcherId and held.revision == initial.revision + 1,
            "pickup duplicated or altered identity"
        )
        assert(runtime.launcher.resources().representations == 4, "held representation missing or duplicated")
        return held.ownerId
    end

    local ready = check("Actual client smoke and convergence probes ready", function()
        waitFor(function()
            for _, player in roster do
                if not clientSmoke[player] then
                    return false
                end
            end
            return true
        end, "actual client smoke", 40)
        local reports: { [string]: Payload } = {}
        for _, player in roster do
            local smoke = assert(clientSmoke[player], "missing client smoke")
            assert(
                type(smoke.passed) == "number"
                    and smoke.passed > 0
                    and smoke.failed == 0
                    and smoke.skipped == 0
                    and smoke.errors == 0,
                "client smoke failed or empty"
            )
            reports[tostring(player.UserId)] = smoke
        end
        observations.clientSmoke = reports
        waitLobby()
        assertRoster()
    end)
    local baseline = resources(runtime)
    observations.lobbyBaseline = baseline

    -- Each reset follows real shell and launcher traffic in one live session.
    -- Abort once the panel has opened so the replay checks start promptly.
    local function impactReset(index: number)
        local crew = deploy()
        local previousMap = workspace.World.Battlefield
        local carrier = assert(Players:GetPlayerByUserId(pickup(crew, 1)), "missing real launcher owner")
        local launcher = runtime.launcher.snapshot()
        Fixture.pose(runtime, carrier, Vector3.new(255, 14, 0))
        Fixture.equip(carrier, "Rocket launcher")
        selectWeapon(crew, "M102", 1)
        local panels = Fixture.outpost()
        local shot, panelIndex = Fixture.panelShot(runtime, "M102", 1, panels, 1)
        assert(shot, "no visible Outpost panel in replay")
        send(crew.operator, { shot })
        local expires = index == 5
        local rocketTarget = if expires then Vector3.new(255, 750, 0) else Vector3.new(235, -6, -48)
        send(carrier, { launcherIntent("Fire", launcher.launcherId, crew.roundId, 2, rocketTarget) })
        local panel = panels[panelIndex]
        local launcherFolder = ReplicatedStorage[launcherState]
        local impact: Payload? = nil
        if expires then
            waitFor(function()
                return runtime.launcher.resources().flights == 1
            end, "actual empty-air rocket flight", 3)
            waitFor(function()
                return runtime.launcher.resources().flights == 0
            end, "empty-air rocket expiry", 7)
            assert(launcherFolder:GetAttribute("LastImpact") == nil, "expired rocket reported a world impact")
        else
            waitFor(function()
                return type(launcherFolder:GetAttribute("LastImpact")) == "string"
            end, "actual rocket ground contact", 7)
            local current = attributes(launcherFolder, "LastImpact")
            assert(
                current.roundId == crew.roundId and current.aircraftHit == false,
                "stale or non-world impact"
            )
            impact = current
        end
        waitFor(function()
            return panel:GetAttribute("DamageAppearance") == "Total"
        end, "panel opening from real howitzer impact", 7)
        assert(health() == AircraftHealth.maximum, "world rocket changed aircraft health")
        checkBounds(resources(runtime))
        local replicated = allClients("PanelStage", { id = panel.Name, appearance = "Total" })
        assert(match.abort(crew.roundId, "P19ReplayReset"), "replay abort failed")
        finishRound(crew, "P19ReplayReset")
        assertDrained(resources(runtime), baseline)
        assert(workspace.World.Battlefield ~= previousMap, "battlefield structure was not rebuilt")
        for _, restored in Fixture.outpost() do
            assert(restored:GetAttribute("DamageAppearance") == "Pristine", "panel survived replay")
        end
        local cleared = allClients("PanelStage", { id = panel.Name, appearance = "Pristine", clear = true })
        observations["impactReset" .. index] = {
            roundId = crew.roundId,
            panel = panel.Name,
            rocket = impact,
            rocketExpired = expires,
            activeClients = replicated,
            resetClients = cleared,
            resources = resources(runtime),
        }
    end

    local function rifleReceived(): number
        local total = 0
        for _, count in rifleDecisions do
            total += count
        end
        return total
    end

    local function replayRound(index: number, latency: number)
        local crew = deploy()
        local battlefield = workspace.World.Battlefield
        local carrierId = pickup(crew, 64)
        local carrier = assert(Players:GetPlayerByUserId(carrierId))
        local held = runtime.launcher.snapshot()
        selectWeapon(crew, "M102", 1, 64)
        allClients("Check", {
            roundId = crew.roundId,
            phase = "Active",
            health = AircraftHealth.maximum,
            ownerId = carrierId,
            launcherState = "Held",
            weapon = "M102",
        })
        Fixture.equip(carrier, "M-7 rifle")
        local position = runtime.aircraft.position()
        Fixture.pose(runtime, carrier, Vector3.new(position.X, 0, position.Z).Unit * 329 + Vector3.yAxis * 30)
        local orbitEpoch = aircraft:GetAttribute("EpochSeconds")
        assert(type(orbitEpoch) == "number", "missing orbit epoch")
        local aim = runtime.aircraft.sample(workspace:GetServerTimeNow() - orbitEpoch + latency).Position
        local shot = Fixture.rifle(crew.roundId, 1, aim)
        shot.repetitions = 64
        local firstSentAt = rifleReceived()
        send(carrier, { shot })
        local once = AircraftHealth.maximum - AircraftHealth.rifleDamage
        waitFor(function()
            return health() == once and rifleReceived() >= firstSentAt + 64
        end, "exactly one direct M-7 hit", 4)
        -- Same body after cooldown still cannot spend ammo or award another hit.
        task.wait(0.45)
        local replaySentAt = rifleReceived()
        send(carrier, { shot }, true)
        waitFor(function()
            return rifleReceived() >= replaySentAt + 64 and runtime.groundCombat.resources().queued == 0
        end, "rifle queue drained", 3)
        assert(health() == once, "rifle flood or replay duplicated damage")
        assert(
            runtime.groundCombat.readiness(carrier).ammo == GroundCombatService.capacity - 1,
            "rifle replay changed ammunition"
        )
        assert(runtime.launcher.snapshot().revision == held.revision, "launcher flood changed held state")
        local panels = Fixture.outpost()
        local gunshipShot, panelIndex = Fixture.panelShot(runtime, "M102", 1, panels, 1)
        assert(gunshipShot, "no reachable imported Outpost panel for replay")
        gunshipShot.repetitions = 64
        send(crew.operator, { gunshipShot })
        local panel = panels[panelIndex]
        waitFor(function()
            return panel:GetAttribute("DamageAppearance") == "Light"
        end, "single real M102 hit on an imported panel", 4)
        assert(panel:GetAttribute("HeavySeconds") == 3, "gunship flood altered panel credit")
        local rendered = allClients("Check", {
            roundId = crew.roundId,
            phase = "Active",
            health = once,
            ownerId = carrierId,
            launcherState = "Held",
            weapon = "M102",
        })
        assertRoster()
        local counts = resources(runtime)
        checkBounds(counts)
        assert(
            counts.launcherQueuePeak > 0 and counts.rifleQueuePeak > 0 and next(rendered),
            "workload did not reach production queues"
        )
        finishRound(crew)
        assertDrained(resources(runtime), baseline)
        assert(workspace.World.Battlefield ~= battlefield, "round did not restore map generation")
        for _, restored in Fixture.outpost() do
            assert(
                restored:GetAttribute("DamageAppearance") == "Pristine",
                "imported panel damage survived reset"
            )
        end
        observations["replayRound" .. index] =
            { roundId = crew.roundId, healthAfterFlood = once, owner = carrierId, resources = counts }
    end

    local function medians(): number
        local rttSamples: { number } = {}
        local perClient: { [string]: { number } } = {}
        for _, player in roster do
            local samples = {}
            for _ = 1, 7 do
                local t0 = os.clock()
                receive(request(player, "Ping", nil))
                table.insert(samples, (os.clock() - t0) * 1000)
            end
            table.sort(samples)
            table.insert(rttSamples, samples[4])
            perClient[tostring(player.UserId)] = samples
        end
        observations.actualRoundTripMs = perClient
        for _, rtt in rttSamples do
            assert(
                rtt >= 100 and rtt <= 200,
                string.format("fixture echo %.1f ms outside 100–200 ms around 150 ms target", rtt)
            )
        end
        table.sort(rttSamples)
        return rttSamples[math.ceil(#rttSamples / 2)] / 1000
    end

    -- The repeatable, real engine workload uses compressed firing cycles, stable
    -- target selection at the Outpost and actual playable roles/equipment. Rifle
    -- misses at a fixed direction keep the aircraft alive through long samples.
    local function workload(crew: Crew, seconds: number, ownerId: number): Counts
        local rng = Random.new(seed + crew.roundId)
        local panels = Fixture.outpost()
        assert(#panels == 26, "imported Outpost panel count changed")
        local preferred = rng:NextInteger(1, #panels)
        local serial = 2
        local rifleBefore = rifleDecisions.accepted or 0
        local position = runtime.aircraft.position()
        local carrier = assert(Players:GetPlayerByUserId(ownerId))
        local carrierHasLauncher = true
        for index, player in crew.ground do
            -- Ground fires at intentional misses, clear of the Outpost workload.
            local angle = 2 * math.pi * index / #crew.ground
            Fixture.pose(runtime, player, Vector3.new(math.cos(angle) * 255, 14, math.sin(angle) * 255))
            Fixture.equip(player, if player == carrier then "Rocket launcher" else "M-7 rifle")
        end
        local counts: Counts =
            { heavyAccepted = 0, chainAccepted = 0, rockets = 0, panelOpenings = 0, importedFragments = 0 }
        local maxima: Counts = {}
        local accepted: Counts = { GAU23 = 0, M102 = 0 }
        local acceptedFields: { [string]: string } = { GAU23 = "chainAccepted", M102 = "heavyAccepted" }
        local rocketReady = 0
        local nextGround, nextGunship = 0, 0
        local t0 = os.clock()
        local chosen = ""
        repeat
            assertRoster()
            assert(match.snapshot().phase == "Active", "load terminated before the measurement window")
            local elapsed = os.clock() - t0
            local weapon = if elapsed % 18 < 13 then "GAU23" else "M102"
            local read = attributes(aircraft, "Readiness")
            for name, field in acceptedFields do
                local current = read[name] :: CombatService.Readiness
                if current.nextFire > accepted[name] then
                    accepted[name] = current.nextFire
                    counts[field] += 1
                end
            end
            local launcherSnapshot = runtime.launcher.snapshot()
            if launcherSnapshot.readyAt > rocketReady then
                rocketReady = launcherSnapshot.readyAt
                counts.rockets += 1
            end
            if chosen ~= weapon then
                serial += 1
                selectWeapon(crew, weapon, serial, nil)
                chosen = weapon
            end
            if elapsed >= nextGunship then
                nextGunship = elapsed + 0.17
                serial += 1
                local readiness = read[weapon] :: CombatService.Readiness
                if
                    readiness.ammo > 0
                    and readiness.reloadUntil == 0
                    and workspace:GetServerTimeNow() >= readiness.nextFire
                then
                    local shot, panel = Fixture.panelShot(runtime, weapon, serial, panels, preferred)
                    if not shot then
                        shot = Fixture.terrainShot(runtime, weapon, serial)
                    end
                    if shot then
                        preferred = panel
                        send(crew.operator, { shot })
                    end
                end
            end
            if elapsed >= nextGround then
                nextGround = elapsed + 0.17
                serial += 1
                for _, player in crew.ground do
                    local fireRocket = player == carrier and launcherSnapshot.ammo == 1
                    if player == carrier and carrierHasLauncher ~= fireRocket then
                        Fixture.equip(player, if fireRocket then "Rocket launcher" else "M-7 rifle")
                        carrierHasLauncher = fireRocket
                    end
                    if fireRocket then
                        send(player, {
                            launcherIntent(
                                "Fire",
                                launcherSnapshot.launcherId,
                                crew.roundId,
                                serial,
                                Vector3.new(235, -6, -48)
                            ),
                        })
                    else
                        local rifle = runtime.groundCombat.readiness(player)
                        if rifle.ammo == 0 and rifle.reserve > 0 and rifle.reloadUntil == 0 then
                            send(player, {
                                {
                                    owner = air,
                                    remote = "GroundReload",
                                    body = { roundId = crew.roundId, sequence = serial },
                                },
                            })
                        elseif rifle.ammo > 0 and rifle.reloadUntil == 0 then
                            send(
                                player,
                                { Fixture.rifle(crew.roundId, serial, position + Vector3.yAxis * 150) }
                            )
                        end
                    end
                end
            end
            local current = resources(runtime)
            checkBounds(current)
            for name, value in current do
                maxima[name] = math.max(maxima[name] or 0, value)
            end
            local open = 0
            for _, panel in panels do
                local appearance = panel:GetAttribute("DamageAppearance")
                if appearance == "Heavy" or appearance == "Total" then
                    open += 1
                end
            end
            counts.panelOpenings = math.max(counts.panelOpenings, open)
            local fragments = workspace:FindFirstChild("PanelFragments")
            if fragments then
                local imported = 0
                for _, fragment in fragments:GetChildren() do
                    if fragment:IsA("MeshPart") then
                        imported += 1
                    end
                end
                counts.importedFragments = math.max(counts.importedFragments, imported)
            end
            task.wait(0.07)
        until os.clock() - t0 >= seconds
        counts.seconds = os.clock() - t0
        counts.rifleAccepted = (rifleDecisions.accepted or 0) - rifleBefore
        for name, value in maxima do
            counts["peak_" .. name] = value
        end
        return counts
    end

    local function validateLoad(counts: Counts)
        assert(
            counts.chainAccepted > 0
                and counts.heavyAccepted > 0
                and counts.rockets > 0
                and counts.rifleAccepted > 0,
            "missing accepted chain, heavy, rifle or rocket traffic"
        )
        assert(
            counts.panelOpenings > 0 and counts.importedFragments > 0,
            "missing imported Outpost Heavy/Total openings or physical MeshPart fragments"
        )
    end

    -- Native Studio presents each actual client in a separate window. Wait
    -- for operators to set the recorded graphics controls before any sampling.
    local function awaitProfileEnvironment()
        stage("Waiting for pinned viewport and graphics on actual clients")
        local deadline = os.clock() + 75
        local sampled: { [string]: unknown }
        repeat
            assertRoster()
            sampled = allClients("ProfileEnvironment", nil)
            observations.profilePreflight = sampled
            local configured = true
            for _, player in roster do
                local value = sampled[tostring(player.UserId)]
                local settings = if type(value) == "table" then value :: Payload else nil
                if
                    not settings
                    or settings.width ~= Metrics.profile.width
                    or settings.height ~= Metrics.profile.height
                    or settings.graphics ~= Metrics.profile.graphics
                then
                    configured = false
                end
            end
            if configured then
                return
            end
            task.wait(0.75)
        until os.clock() >= deadline
        error(
            suite
                .. " requires stable "
                .. profileSettings
                .. " for each client; observed "
                .. HttpService:JSONEncode(sampled)
        )
    end

    local serverFrameConnection: RBXScriptConnection? = nil
    if ready then
        if mode == "Replay" then
            for index = 1, 5 do
                if
                    not check("Accelerated flood and pristine replay " .. index, function()
                        if suite == "P19Replay" then
                            impactReset(index)
                        else
                            replayRound(index, 0.04)
                        end
                    end)
                then
                    break
                end
            end
        elseif mode == "Latency" then
            local rttSeconds = 0
            if
                check("Seven measured replication round trips per real client", function()
                    rttSeconds = medians()
                end)
            then
                check(
                    "Convergent replicated health, ownership, weapon and result under measured RTT",
                    function()
                        replayRound(1, rttSeconds)
                    end
                )
            end
        elseif mode == "Profile" then
            check("Five-minute loaded Studio p95 budgets for both roles and server", function()
                awaitProfileEnvironment()
                local crew = deploy()
                local ownerId = pickup(crew, 1)
                local heartbeat, elapsed = Metrics.frames(), Metrics.frames()
                allClients("ProfileStart", nil)
                local connection = RunService.Heartbeat:Connect(function(seconds)
                    heartbeat.record(Stats.HeartbeatTime)
                    elapsed.record(seconds)
                end)
                serverFrameConnection = connection
                local counts = workload(crew, profileSeconds, ownerId)
                connection:Disconnect()
                serverFrameConnection = nil
                local server = heartbeat.summary()
                local frames = allClients("ProfileStop", nil)
                observations.profile = {
                    load = counts,
                    server = server,
                    serverFrameInterval = elapsed.summary(),
                    clients = frames,
                }
                finishRound(crew)
                assertDrained(resources(runtime), baseline)
                validateLoad(counts)
                assert(
                    counts.seconds >= profileSeconds and counts.seconds <= profileSeconds + 5,
                    "unexpected server sampling window"
                )
                assert(
                    server.samples >= profileSeconds * 10
                        and server.invalid == 0
                        and server.p95Ms
                        and server.p95Ms <= 16.7,
                    "server heartbeat p95 exceeded 16.7 ms or sampling was incomplete"
                )
                for _, player in roster do
                    local result = assert(frames[tostring(player.UserId)], "missing rendered client") :: {
                        width: number,
                        height: number,
                        viewportChanged: boolean,
                        graphics: string,
                        graphicsChanged: boolean,
                        seconds: number,
                        role: string,
                        frames: Metrics.FrameSummary,
                    }
                    local measured = result.frames
                    local role = if player == crew.operator then "Gunship" else "Ground"
                    assert(result.role == role, "render role did not match actual assigned role")
                    assert(
                        result.width == Metrics.profile.width
                            and result.height == Metrics.profile.height
                            and not result.viewportChanged
                            and result.graphics == Metrics.profile.graphics
                            and not result.graphicsChanged,
                        "requires stable " .. profileSettings .. " on each client"
                    )
                    assert(
                        result.seconds >= profileSeconds and result.seconds <= profileSeconds + 10,
                        "unexpected client sampling window"
                    )
                    assert(
                        measured.samples >= profileSeconds * 10
                            and measured.invalid == 0
                            and measured.p95Ms
                            and measured.p95Ms <= 33.3,
                        "client render p95 exceeded 33.3 ms or sampling was incomplete"
                    )
                end
            end)
        else
            check("Equivalent lobby resets during thirty loaded minutes after warmup", function()
                local memory: { [string]: { number } } = { server = {} }
                local loads: { Counts } = {}
                observations.soakSamplesMb = memory
                observations.soakLoads = loads
                local retained: { [string]: Metrics.MemorySummary } = {}
                observations.retainedMemory = retained
                local loaded = 0
                local memoryStart = 0
                for roundIndex = 1, soakRounds + 1 do
                    stage("Soak round " .. roundIndex .. " of " .. (soakRounds + 1))
                    local crew = deploy()
                    local ownerId = pickup(crew, 1)
                    local counts = workload(crew, soakActiveSeconds, ownerId)
                    table.insert(loads, counts)
                    finishRound(crew)
                    task.wait(3)
                    assertDrained(resources(runtime), baseline)
                    assert(Stats.MemoryTrackingEnabled, "server engine memory tracking disabled")
                    table.insert(memory.server, Stats:GetTotalMemoryUsageMb())
                    for id, value in allClients("Memory", nil) do
                        assert(
                            type(value) == "number" and value > 0 and value < math.huge,
                            "invalid client memory"
                        )
                        local samples = memory[id] or {}
                        memory[id] = samples
                        table.insert(samples, value)
                    end
                    validateLoad(counts)
                    if roundIndex == 1 then
                        memoryStart = os.clock()
                    else
                        loaded += counts.seconds
                    end
                    observations.soakLoadedSeconds = loaded
                end
                assert(
                    loaded >= 1800 and os.clock() - memoryStart >= 1800,
                    "soak shorter than thirty post-warmup minutes"
                )
                for owner, samples in memory do
                    assert(#samples == soakRounds + 1, "missing equivalent samples")
                    retained[owner] = assert(Metrics.retainedMemory(samples), "invalid samples")
                end
                for owner, growth in retained do
                    assert(
                        growth.growthPercent <= 10 and not growth.monotonicGrowth,
                        owner .. " retained memory exceeded budget or grew monotonically"
                    )
                end
            end)
        end
    end
    observations.clientRequests = requests
    observations.groundFireDecisions = rifleDecisions
    observations.finalResources = resources(runtime)
    check("Owned combat, connections and transport drain on shutdown", function()
        if serverFrameConnection then
            serverFrameConnection:Disconnect()
        end
        runtime.stop()
        runtime.stop()
        waitFor(function()
            return runtime.rounds.resources().spawnTasks == 0
        end, "residual character tasks", 5)
        local counts = resources(runtime)
        for key, value in counts do
            if key ~= "launcherQueuePeak" and key ~= "rifleQueuePeak" then
                assert(value == 0, "resource survived stop: " .. key)
            end
        end
        assert(
            not ReplicatedStorage:FindFirstChild("RoundState")
                and not ReplicatedStorage:FindFirstChild(air)
                and not ReplicatedStorage:FindFirstChild(launcherState),
            "runtime transport survived stop"
        )
    end)
    listener:Disconnect()
    transport:Destroy()
    deliver()
end

-- Historical selector rejects on current builds before allocating resources.
function Harness.run(rawMode: unknown, rawExpected: unknown, finish: ((Report) -> ())?)
    require(game:GetService("ReplicatedStorage").HarnessCompatibility).assertCurrent("P11")
    runScenario(rawMode, rawExpected, finish, "P11")
end

-- Runs the current matched workload with two actual clients.
function Harness.profile(finish: ((Report) -> ())?)
    runScenario("Profile", 2, finish, "P19Profile")
end

-- Five consecutive resets in a real two-client session on current combat.
-- Native Server & Clients receives the same report through finish. With no
-- callback, the SDK owns ending the test and returning its result.
function Harness.impactReplay(finish: ((Report) -> ())?)
    runScenario("Replay", 2, finish, "P19Replay")
end

return Harness
