--!strict
-- Historical pre-P18 staged fixture. Current entry rejects; use RebalanceHarness.
-- P09 native local multiplayer acceptance using production GameRuntime and real clients.
-- Trusted fixture poses set up engine collisions. Client commands use production remotes.
-- Departure scenarios use separate runs because departed Studio identities cannot rejoin.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StudioTestService = game:GetService("StudioTestService")
local Server = game:GetService("ServerScriptService").Server
local Shared = ReplicatedStorage.Shared
local GameRuntime = require(Server.GameRuntime)
local MatchService = require(Server.MatchService)
local CombatViewRules = require(Server.CombatViewRules)
local CombatService = require(Server.CombatService)
local LauncherService = require(Server.LauncherService)
local MapRules = require(Shared.MapRules)
local Pan = require(Shared.AircraftPanRules)
local AircraftRules = require(Shared.AircraftRules)
local Harness = {}
type Case = { name: string, passed: boolean, detail: string? }
type SmokeReport = { [string]: unknown }
type SmokeEvidence = { server: SmokeReport?, clients: { [string]: SmokeReport } }
export type Report = {
    suite: string,
    environment: string,
    scenario: string,
    mode: string,
    clientCount: number,
    initialIds: { number },
    finalClients: number,
    discovered: number,
    passed: number,
    failed: number,
    skipped: number,
    cases: { Case },
    observations: { unknown },
    smoke: SmokeEvidence,
}

local function waitFor(predicate: () -> boolean, label: string, seconds: number?)
    local untilWall = os.clock() + (seconds or 12)
    repeat
        if predicate() then
            return
        end
        task.wait()
    until os.clock() >= untilWall
    error("P09 timeout: " .. label, 2)
end

local function json(state: Instance, key: string): { [string]: unknown }
    local value = state:GetAttribute(key)
    assert(type(value) == "string", "missing " .. key)
    return HttpService:JSONDecode(value)
end

-- Preserve the test entrypoints' own reports. These are fixture diagnostics,
-- never production authority or a second source of suite totals.
local function smokeReport(encoded: unknown): SmokeReport?
    if type(encoded) ~= "string" or #encoded > 1024 then
        return nil
    end
    local ok, decoded = pcall(function(): unknown
        return HttpService:JSONDecode(encoded)
    end)
    return if ok and type(decoded) == "table" then decoded :: SmokeReport else nil
end

-- Outcomes and Departures start with three real clients. LastGround and Empty
-- start with two. Manual mode retains the report until the coordinator stops it.
function Harness.run(scenario: string, finish: ((Report) -> ())?)
    require(game:GetService("ReplicatedStorage").HarnessCompatibility).assertCurrent("P09")
    local expected = if scenario == "Outcomes" or scenario == "Departures" then 3 else 2
    assert(
        scenario == "Outcomes" or scenario == "Departures" or scenario == "LastGround" or scenario == "Empty",
        "unknown P09 scenario"
    )
    local cases: { Case } = {}
    local observations: { unknown } = {}
    local initialIds: { number } = {}
    local smoke: SmokeEvidence = {
        server = smokeReport(workspace:GetAttribute("ServerTestReport")),
        clients = {},
    }
    local function deliver()
        local passed = 0
        for _, case in cases do
            if case.passed then
                passed += 1
            end
        end
        local report: Report = {
            suite = "P09-multiplayer",
            environment = "Studio",
            scenario = scenario,
            mode = if finish then "native-server-clients" else "sdk",
            clientCount = #initialIds,
            initialIds = initialIds,
            finalClients = #Players:GetPlayers(),
            discovered = #cases,
            passed = passed,
            failed = #cases - passed,
            skipped = 0,
            cases = cases,
            observations = observations,
            smoke = smoke,
        }
        workspace:SetAttribute("P09MultiplayerReport", HttpService:JSONEncode(report))
        if finish then
            finish(report)
        else
            StudioTestService:EndTest(report)
        end
    end
    local joined, problem = pcall(function()
        waitFor(function()
            return #Players:GetPlayers() == expected
        end, "actual client count " .. tostring(expected), 45)
    end)
    if not joined then
        table.insert(cases, { name = "Startup", passed = false, detail = tostring(problem) })
        deliver()
        return
    end
    local initialPlayers = Players:GetPlayers()
    for _, player in initialPlayers do
        table.insert(initialIds, player.UserId)
    end
    local runtime, reason = GameRuntime.start({
        automaticDeployment = false,
        minimumPlayers = 2,
        durationSeconds = 30,
        lobbySeconds = 0,
        deploymentSeconds = 25,
        resultsSeconds = 10,
        seed = 1,
    })
    if not runtime then
        table.insert(cases, { name = "Runtime startup", passed = false, detail = reason })
        deliver()
        return
    end

    local match = runtime.rounds.match
    local aircraftState = ReplicatedStorage.AircraftState
    local transport = Instance.new("RemoteEvent")
    transport.Name = "P09Harness"
    local tickets: { [number]: { player: Player, ok: boolean?, detail: string? } } = {}
    local sequence = 0
    local listener = transport.OnServerEvent:Connect(
        function(player: Player, token: unknown, ok: unknown, detail: unknown)
            if token == 0 and ok == true then
                local report = smokeReport(detail)
                if report and report.userId == player.UserId then
                    smoke.clients[tostring(player.UserId)] = report
                end
            elseif type(token) == "number" and tickets[token] and tickets[token].player == player then
                tickets[token].ok, tickets[token].detail = ok == true, tostring(detail)
            end
        end
    )
    transport.Parent = ReplicatedStorage

    local function clientReady(player: Player): boolean
        return smoke.clients[tostring(player.UserId)] ~= nil
    end
    local function beginProbe(player: Player, action: string, payload: unknown): number
        waitFor(function()
            return clientReady(player)
        end, "client fixture ready")
        sequence += 1
        tickets[sequence] = { player = player }
        transport:FireClient(player, sequence, action, payload)
        return sequence
    end
    local function finishProbe(token: number)
        local ticket = tickets[token]
        waitFor(function()
            return ticket.ok ~= nil
        end, "client response from " .. ticket.player.Name)
        tickets[token] = nil
        assert(ticket.ok, ticket.detail)
    end
    local function probe(player: Player, action: string, payload: unknown)
        finishProbe(beginProbe(player, action, payload))
    end
    local function allClients(action: string, payload: unknown): number
        local tokens: { number } = {}
        for _, player in Players:GetPlayers() do
            table.insert(tokens, beginProbe(player, action, payload))
        end
        for _, token in tokens do
            finishProbe(token)
        end
        return #tokens
    end
    local function check(name: string, action: () -> ())
        workspace:SetAttribute("P09Stage", name)
        local ok, err = pcall(function()
            action()
            return true
        end)
        table.insert(cases, { name = name, passed = ok, detail = if ok then nil else tostring(err) })
    end
    local function roles(): (Player, { Player })
        local operator: Player? = nil
        local ground: { Player } = {}
        for _, player in Players:GetPlayers() do
            local member = match.snapshot().members[player.UserId]
            if member and member.role == "Gunship" then
                operator = player
            elseif member and member.role == "Ground" then
                table.insert(ground, player)
            end
        end
        assert(operator, "operator missing")
        table.sort(ground, function(a, b)
            return a.UserId < b.UserId
        end)
        return operator, ground
    end
    local function health(): number
        local value = aircraftState:GetAttribute("Health")
        assert(type(value) == "number", "aircraft health missing")
        return value
    end
    local function humanoid(player: Player): Humanoid
        return assert(
            if player.Character then player.Character:FindFirstChildOfClass("Humanoid") else nil,
            "humanoid missing"
        )
    end
    local function head(player: Player): BasePart
        local part = if player.Character then player.Character:FindFirstChild("Head") else nil
        assert(part and part:IsA("BasePart"), "head missing")
        return part
    end
    local function pose(player: Player, position: Vector3)
        local character = assert(player.Character, "character missing")
        local root = character:FindFirstChild("HumanoidRootPart")
        assert(root and root:IsA("BasePart"), "root missing")
        root.Anchored = true
        character:PivotTo(CFrame.new(position))
        assert(runtime.groundCombat.trustCorrection(player), "fixture correction rejected")
    end
    local function equip(player: Player, name: string)
        local backpack = assert(player:FindFirstChildOfClass("Backpack"), "backpack missing")
        local tool = backpack:FindFirstChild(name)
        assert(tool and tool:IsA("Tool"), "missing " .. name)
        humanoid(player):EquipTool(tool)
        assert(tool.Parent == player.Character, "equip failed")
    end
    local function groundRequest(serial: number, point: Vector3, roundId: number): { [string]: unknown }
        return { roundId = roundId, sequence = serial, weapon = "M7", x = point.X, y = point.Y, z = point.Z }
    end
    local function launcherRequest(serial: number, point: Vector3?): { [string]: unknown }
        local snapshot = runtime.launcher.snapshot()
        local payload: { [string]: unknown } = {
            roundId = snapshot.roundId,
            launcherId = snapshot.launcherId,
            sequence = serial,
        }
        if point then
            payload.x, payload.y, payload.z = point.X, point.Y, point.Z
        end
        return payload
    end
    local function pickup(player: Player, serial: number)
        local p = runtime.launcher.snapshot().position
        pose(player, Vector3.new(p.x, p.y + 2, p.z))
        probe(player, "LauncherState/Pickup", launcherRequest(serial))
        waitFor(function()
            return runtime.launcher.snapshot().ownerId == player.UserId
        end, "actual launcher pickup")
    end
    local function fireRocket(player: Player, serial: number, point: Vector3): string
        local oldReady = runtime.launcher.snapshot().readyAt
        probe(player, "LauncherState/Fire", launcherRequest(serial, point))
        waitFor(function()
            return runtime.launcher.snapshot().readyAt > oldReady
        end, "accepted rocket")
        local shot = json(ReplicatedStorage.LauncherState, "LastShot")
        assert(type(shot.shotId) == "string" and shot.userId == player.UserId, "rocket identity")
        return shot.shotId
    end
    local function lead(player: Player): Vector3
        local aircraft = runtime.aircraft.position()
        pose(player, Vector3.new(aircraft.X, 0, aircraft.Z).Unit * 330 + Vector3.yAxis * 30)
        local origin = head(player).Position
        local epoch = aircraftState:GetAttribute("EpochSeconds")
        assert(type(epoch) == "number", "orbit epoch missing")
        local elapsed = workspace:GetServerTimeNow() - epoch
        local target, travel = aircraft, 0.5
        for _ = 1, 5 do
            target = runtime.aircraft.sample(elapsed + travel + 0.10).Position
            travel = (target - origin).Magnitude / LauncherService.speedStudsPerSecond
        end
        return target
    end
    local function deploy(): MatchService.Snapshot
        assert(match.deploy(), "could not deploy")
        waitFor(function()
            return match.snapshot().phase == "Active"
        end, "deployment to Active", 30)
        local state = match.snapshot()
        waitFor(function()
            return runtime.launcher.snapshot().state == "Available"
        end, "launcher active")
        return state
    end
    local function result(
        winner: string,
        reasonCode: string,
        legalText: string,
        credit: number?
    ): MatchService.Result
        waitFor(function()
            return match.snapshot().phase == "Results"
        end, "result " .. reasonCode, 35)
        local state = match.snapshot()
        local ended = assert(state.result, "no authoritative result")
        assert(
            ended.winner == winner and ended.reason == reasonCode and ended.userId == credit,
            "unexpected result: " .. HttpService:JSONEncode(ended)
        )
        local clientCount = allClients("Result", {
            roundId = state.roundId,
            winner = winner,
            reason = reasonCode,
            credit = credit,
            text = legalText,
        })
        local resultHealth = health()
        local terminalPose = runtime.aircraft.position()
        assert(
            runtime.launcher.resources().flights == 0
                and runtime.launcher.resources().representations == 0
                and runtime.combat.resources().projectiles == 0,
            "terminal flight or launcher representation survived"
        )
        assert(not runtime.groundCombat.rocketImpact(state.roundId, "late", true), "terminal hit accepted")
        assert(not match.proposeAircraftDestroyed(state.roundId), "terminal result proposal accepted")
        task.wait(0.12)
        assert(
            health() == resultHealth and runtime.aircraft.position() == terminalPose,
            "terminal aircraft changed"
        )
        table.insert(
            observations,
            { roundId = state.roundId, result = ended, clientCount = clientCount, health = resultHealth }
        )
        return ended
    end
    local function lobby()
        waitFor(function()
            return match.snapshot().phase == "Lobby"
        end, "return to lobby", 15)
        local state = match.snapshot()
        allClients("Lobby", { roundId = state.roundId })
        assert(state.result == nil and health() == 300, "result or health survived reset")
        assert(
            runtime.launcher.resources().queued == 0 and runtime.launcher.resources().flights == 0,
            "launcher did not drain"
        )
        assert(runtime.groundCombat.resources().tools == 0, "rifle survived lobby")
        assert(runtime.destruction.resources().fragments == 0, "debris survived lobby")
    end

    local function readiness(weapon: string): CombatService.Readiness
        return json(aircraftState, "Readiness")[weapon] :: CombatService.Readiness
    end
    local function pristine(roundId: number, operator: Player, grounds: { Player })
        assert(health() == 300 and aircraftState:GetAttribute("Destroyed") == false, "aircraft not pristine")
        local epoch = aircraftState:GetAttribute("EpochSeconds")
        assert(type(epoch) == "number", "missing orbit epoch")
        local elapsed = workspace:GetServerTimeNow() - epoch
        assert(
            elapsed >= 0
                and elapsed < 25
                and (runtime.aircraft.position() - runtime.aircraft.sample(elapsed).Position).Magnitude
                    < 7,
            "orbit did not restart"
        )
        assert(runtime.aircraft.weapon() == "GAU23", "default weapon did not restore")
        local launcher = runtime.launcher.snapshot()
        assert(
            launcher.roundId == roundId
                and launcher.state == "Available"
                and launcher.ammo == 1
                and launcher.readyAt == 0,
            "pristine launcher unavailable"
        )
        assert(runtime.launcher.resources().representations == 3, "pristine launcher duplicated")
        for weapon, profile in CombatService.profiles do
            local fresh = readiness(weapon)
            assert(
                fresh.ammo == profile.capacity and fresh.nextFire == 0 and fresh.reloadUntil == 0,
                "stale weapon readiness " .. weapon
            )
        end
        probe(operator, "Operator", { roundId = roundId, fov = AircraftRules.defaults.fov30mm })
        for _, player in grounds do
            assert(player.Team == grounds[1].Team and player.Team ~= operator.Team, "split ground team")
            local rifle = runtime.groundCombat.readiness(player)
            assert(rifle.ammo == 30 and rifle.reserve == 120, "pristine rifle readiness")
            probe(player, "Ground", { roundId = roundId })
        end
    end

    -- Aim through the same permitted camera envelope and solid filters as
    -- production. A valid remote still needs real projectile contact.
    local function gunshipCommand(weapon: string, point: Vector3, serial: number): { [string]: unknown }?
        local map, camera = MapRules.defaults, runtime.aircraft.position()
        local radial = Vector2.new(camera.X, camera.Z).Unit
        local projected = camera + (point - camera) * (map.altitudeStuds / (camera.Y - point.Y))
        local focus = {
            x = projected.X * radial.X + projected.Z * radial.Y,
            z = -projected.X * radial.Y + projected.Z * radial.X,
        }
        local home = assert(Pan.recenter(map, 16 / 9, 40), "no valid home view")
        local payload: { [string]: unknown } = {
            roundId = match.snapshot().roundId,
            sequence = serial,
            weapon = weapon,
            x = point.X,
            y = point.Y,
            z = point.Z,
            aspect = 16 / 9,
            cameraX = camera.X,
            cameraZ = camera.Z,
        }
        for index = 0, 40 do
            local fraction = index / 40
            payload.focusX = focus.x + (home.x - focus.x) * fraction
            payload.focusZ = focus.z + (home.z - focus.z) * fraction
            if CombatViewRules.validate(payload, map, weapon, camera.X, camera.Z) then
                return payload
            end
        end
        return nil
    end
    local function selectWeapon(operator: Player, weapon: string, serial: number, fov: number)
        local id = match.snapshot().roundId
        probe(operator, "AircraftState/SelectWeapon", { roundId = id, weapon = weapon, sequence = serial })
        waitFor(function()
            return runtime.aircraft.weapon() == weapon
        end, "weapon selection " .. weapon)
        probe(operator, "Operator", { roundId = id, fov = fov })
    end
    local function fireGunship(operator: Player, weapon: string, payload: { [string]: unknown })
        local before = readiness(weapon).nextFire
        probe(operator, "AircraftState/FireWeapon", payload)
        waitFor(function()
            return readiness(weapon).nextFire > before
        end, "accepted " .. weapon)
    end

    local function fireAtOutpost(operator: Player, weapon: string, serial: number): string
        local battlefield = workspace.World.Battlefield
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Include
        params.FilterDescendantsInstances = { battlefield, workspace.Terrain }
        local muzzle = assert(runtime.aircraft.muzzle(weapon), "aircraft muzzle missing")
        local models = battlefield.Buildings.Outpost.Outpost_Panels:GetChildren()
        table.sort(models, function(a, b)
            return a.Name < b.Name
        end)
        for _, model in models do
            for _, part in model:GetChildren() do
                if part:IsA("BasePart") and runtime.destruction.identify(part) == model.Name then
                    local target = part.Position
                    local ray = workspace:Spherecast(muzzle, 0.05, target - muzzle, params)
                    if ray and runtime.destruction.identify(ray.Instance) == model.Name then
                        local payload = gunshipCommand(weapon, ray.Position, serial)
                        if payload then
                            fireGunship(operator, weapon, payload)
                            return model.Name
                        end
                    end
                end
            end
        end
        error("no shootable registered Outpost panel")
    end
    local function openImpact(weapon: string, serial: number): (Vector3, { [string]: unknown })
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Include
        params.FilterDescendantsInstances = { workspace.World.Battlefield, workspace.Terrain }
        local aircraft = runtime.aircraft.position()
        local radial = Vector3.new(aircraft.X, 0, aircraft.Z).Unit
        local tangent = Vector3.new(radial.Z, 0, -radial.X)
        local muzzle = assert(runtime.aircraft.muzzle(weapon), "aircraft muzzle missing")
        for distance = 85, 220, 15 do
            for offset = -60, 60, 15 do
                local flat = radial * distance + tangent * offset
                local floor = workspace:Raycast(flat + Vector3.yAxis * 80, -Vector3.yAxis * 100, params)
                if not floor or floor.Normal.Y < 0.99 or floor.Position.Y > 1 then
                    continue
                end
                local target = floor.Position
                local first = workspace:Spherecast(muzzle, 0.05, target - muzzle, params)
                if first and (first.Position - target).Magnitude <= 1 then
                    local payload = gunshipCommand(weapon, target, serial)
                    if payload then
                        return target, payload
                    end
                end
            end
        end
        error("no clear ground impact fixture")
    end

    local function leaveAll(targets: { Player })
        -- One server callback initiates grouped departures. Distinct client
        -- LeaveTest requests can otherwise reach separate authoritative frames.
        if finish or #targets > 1 then
            for _, player in targets do
                player:Kick("P09 local departure fixture")
            end
        else
            for _, player in targets do
                beginProbe(player, "Leave", nil)
            end
        end
        waitFor(function()
            for _, player in targets do
                if player.Parent == Players then
                    return false
                end
            end
            return true
        end, "actual client departures")
    end

    local function teardown()
        check("A6: stop drains the frame, combat, character resources and transport", function()
            runtime.stop()
            runtime.stop()
            waitFor(function()
                return runtime.rounds.resources().spawnTasks == 0
            end, "character loads drained")
            assert(
                runtime.resources().frameConnections == 0
                    and runtime.rounds.resources().connections == 0
                    and runtime.aircraft.resources().connections == 0
                    and runtime.combat.resources().connections == 0
                    and runtime.launcher.resources().connections == 0
                    and runtime.groundCombat.resources().connections == 0,
                "owned connections survived stop"
            )
            assert(
                not ReplicatedStorage:FindFirstChild("RoundState")
                    and not ReplicatedStorage:FindFirstChild("AircraftState")
                    and not ReplicatedStorage:FindFirstChild("LauncherState"),
                "owned state survived stop"
            )
        end)
        listener:Disconnect()
        transport:Destroy()
        workspace:SetAttribute("P09Stage", "finished")
        deliver()
    end

    workspace:SetAttribute("P09Stage", "Waiting for client smoke")
    local clientsReady, startupFailure = pcall(function()
        waitFor(function()
            for _, player in initialPlayers do
                if player.Parent ~= Players or not clientReady(player) then
                    return false
                end
            end
            return true
        end, "all initial clients passed smoke and connected the test fixture", 35)
        return true
    end)
    if not clientsReady then
        table.insert(
            cases,
            { name = "Client smoke startup", passed = false, detail = tostring(startupFailure) }
        )
        teardown()
        return
    end

    if scenario == "Outcomes" then
        local activeRound = 0
        local originalMap: Instance? = nil
        local damagedPanel: string? = nil
        local previousOperator: Player? = nil
        local connections = 0
        check("A3/A5: real rifle friendly fire rejected, three rockets win after carrier death", function()
            local state = deploy()
            activeRound = state.roundId
            originalMap = workspace.World.Battlefield
            local operator, ground = roles()
            pristine(activeRound, operator, ground)
            previousOperator = operator
            connections = runtime.rounds.resources().connections
            local carrier, teammate = ground[1], ground[2]
            local p = runtime.launcher.snapshot().position
            pose(carrier, Vector3.new(p.x, p.y + 2, p.z))
            pose(teammate, Vector3.new(p.x + 3, p.y + 2, p.z))
            equip(carrier, "M-7 rifle")
            local teammateHealth = humanoid(teammate).Health
            probe(carrier, "AircraftState/GroundFire", groundRequest(1, head(teammate).Position, activeRound))
            waitFor(function()
                return runtime.groundCombat.readiness(carrier).ammo == 29
            end, "real teammate-directed rifle round")
            waitFor(function()
                return aircraftState:GetAttribute("GroundShot") ~= nil
            end, "rifle ray resolved")
            assert(
                humanoid(teammate).Health == teammateHealth and health() == 300,
                "friendly fire caused damage"
            )
            fireAtOutpost(operator, "GAU23", 1)
            selectWeapon(operator, "M102", 1, AircraftRules.defaults.fov105mm)
            damagedPanel = fireAtOutpost(operator, "M102", 2)
            waitFor(function()
                local panel = if damagedPanel then runtime.destruction.snapshot(damagedPanel) else nil
                return panel ~= nil and panel.appearance == "Light"
            end, "actual Outpost Light damage")
            pickup(carrier, 1)
            equip(carrier, "Rocket launcher")
            for index = 1, 3 do
                waitFor(function()
                    return runtime.launcher.snapshot().ammo == 1
                end, "rocket reload")
                local shot = fireRocket(carrier, index + 1, lead(carrier))
                if index == 3 then
                    assert(runtime.launcher.resources().flights == 1, "lethal rocket not in flight")
                    humanoid(carrier).Health = 0
                    waitFor(function()
                        return match.snapshot().members[carrier.UserId].life == "Eliminated"
                    end, "carrier death")
                    assert(
                        match.snapshot().phase == "Active" and health() == 100,
                        "lethal hit predated shooter death"
                    )
                    local ended = result(
                        "Ground",
                        "AircraftDestroyed",
                        "Ground team wins\nThe C-130 was destroyed.",
                        carrier.UserId
                    )
                    assert(
                        ended.shotId == shot and ended.weapon == "RocketLauncher" and health() == 0,
                        "lethal flight credit mismatch"
                    )
                else
                    waitFor(function()
                        return health() == 300 - index * 100
                    end, "direct rocket " .. tostring(index))
                end
            end
        end)
        check(
            "A5/A6: replay resets equipment, Outpost, aircraft and cameras; shell wins elimination",
            function()
                lobby()
                local state = deploy()
                assert(
                    state.roundId == activeRound + 1 and workspace.World.Battlefield ~= originalMap,
                    "map generation did not advance"
                )
                local panel = if damagedPanel then runtime.destruction.snapshot(damagedPanel) else nil
                assert(panel and panel.appearance == "Pristine", "damaged Outpost panel did not restore")
                local operator, ground = roles()
                assert(
                    previousOperator ~= operator and runtime.rounds.resources().connections == connections,
                    "roles or listeners did not reset"
                )
                pristine(state.roundId, operator, ground)
                previousOperator = operator
                local carrier = ground[1]
                local stale = launcherRequest(99)
                stale.roundId, stale.launcherId = activeRound, runtime.launcher.snapshot().launcherId
                local p = runtime.launcher.snapshot().position
                pose(carrier, Vector3.new(p.x, p.y + 2, p.z))
                probe(carrier, "LauncherState/Pickup", stale)
                probe(
                    carrier,
                    "RoundState/Surrender",
                    { roundId = activeRound, sequence = 99, action = "Surrender" }
                )
                task.wait(0.12)
                assert(
                    runtime.launcher.snapshot().state == "Available"
                        and match.snapshot().members[carrier.UserId].life == "Alive",
                    "old-round intent mutated new round"
                )
                assert(
                    not runtime.groundCombat.rocketImpact(activeRound, "stale", true),
                    "old-round projectile hit"
                )
                pickup(carrier, 1)
                equip(carrier, "Rocket launcher")
                pose(carrier, Vector3.new(0, 80, 0))
                fireRocket(carrier, 2, Vector3.new(0, 600, 0))
                selectWeapon(operator, "M102", 1, AircraftRules.defaults.fov105mm)
                local target, payload = openImpact("M102", 1)
                for index, player in ground do
                    pose(player, target + Vector3.new(index * 2 - 3, 3, 0))
                end
                assert(runtime.launcher.resources().flights == 1, "setup lost in-flight timeout check")
                fireGunship(operator, "M102", payload)
                result(
                    "Gunship",
                    "GroundEliminated",
                    "C-130 wins\nAll ground players were eliminated.",
                    operator.UserId
                )
                assert(health() == 300, "canceled rocket awarded damage")
                activeRound = state.roundId
            end
        )
        check("A5/A6: third full round restores cooldowns and zoom and ends at the deadline", function()
            lobby()
            local state = deploy()
            assert(state.roundId == activeRound + 1, "third generation missing")
            local operator, ground = roles()
            assert(
                previousOperator ~= operator and runtime.rounds.resources().connections == connections,
                "listeners or rotation changed"
            )
            pristine(state.roundId, operator, ground)
            probe(
                ground[1],
                "RoundState/Surrender",
                { roundId = state.roundId, sequence = 1, action = "GroundWin" }
            )
            assert(
                match.snapshot().phase == "Active"
                    and match.snapshot().members[ground[1].UserId].life == "Alive",
                "client forged win"
            )
            result(
                "Gunship",
                "Timeout",
                "C-130 wins\nThe C-130 survived until time ran out.",
                operator.UserId
            )
            assert(
                workspace:GetServerTimeNow() >= state.deadlineSeconds and health() == 300,
                "wrong timeout boundary"
            )
            lobby()
        end)
        check("A4: invalid deployment aborts with no winner and restores authored anchors", function()
            local anchor = workspace.World.Battlefield.Anchors:FindFirstChild("Operator")
            assert(anchor, "operator anchor missing before probe")
            anchor.Name = "P09UnavailableOperator"
            assert(match.deploy(), "invalid deployment did not start")
            result("None", "CharacterIncomplete", "Round ended\nA team could not deploy.", nil)
            lobby()
            assert(
                workspace.World.Battlefield.Anchors:FindFirstChild("Operator"),
                "invalid anchor not restored"
            )
        end)
    elseif scenario == "Departures" then
        check(
            "A4: actual carrier departure recovers exactly one launcher; operator departure forfeits",
            function()
                local state = deploy()
                local operator, ground = roles()
                pickup(ground[1], 1)
                leaveAll({ ground[1] })
                waitFor(function()
                    return runtime.launcher.snapshot().state == "Available"
                end, "departed carrier recovery")
                assert(
                    match.snapshot().phase == "Active" and runtime.launcher.resources().representations == 3,
                    "carrier departure ended round or stranded launcher"
                )
                assert(
                    match.snapshot().members[ground[1].UserId].life == "Eliminated",
                    "departed life survived"
                )
                pickup(ground[2], 1)
                leaveAll({ operator })
                result(
                    "Ground",
                    "OperatorForfeit",
                    "Ground team wins\nThe C-130 operator left the round.",
                    nil
                )
                assert(
                    health() == 300 and match.snapshot().roundId == state.roundId,
                    "forfeit damaged aircraft"
                )
                lobby()
            end
        )
    elseif scenario == "LastGround" then
        check("A4: actual raw character removal eliminates the remaining ground life", function()
            deploy()
            local operator, ground = roles()
            local character = assert(ground[1].Character, "ground model unavailable for raw removal")
            character:Destroy()
            result(
                "Gunship",
                "GroundEliminated",
                "C-130 wins\nAll ground players were eliminated.",
                operator.UserId
            )
            assert(ground[1].Parent == Players, "raw model removal disconnected the player")
            lobby()
        end)
        check("A4: actual last-ground departure awards the surviving C-130 by departure", function()
            deploy()
            local operator, ground = roles()
            pickup(ground[1], 1)
            leaveAll(ground)
            result(
                "Gunship",
                "GroundDeparted",
                "C-130 wins\nThe last ground player left the round.",
                operator.UserId
            )
            assert(health() == 300, "departure caused aircraft damage")
            lobby()
        end)
    else
        check(
            "A4: same-step actual operator and ground departures empty the server without a winner",
            function()
                deploy()
                leaveAll(Players:GetPlayers())
                result("None", "EmptyServer", "Round ended\nAll players left the server.", nil)
                lobby()
            end
        )
    end
    teardown()
end

return Harness
