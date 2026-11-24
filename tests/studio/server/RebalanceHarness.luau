--!strict
-- P18 native integration coordinator: three actual clients, source-owned game
-- runtime, real cover queries, ordinary launcher remotes, replicated observations
-- and replay cleanup. Trusted structural fixtures enter at the accepted-outcome
-- boundary; they do not claim to test the gunship input/flight path.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local StudioTestService = game:GetService("StudioTestService")
local GameRuntime = require(game:GetService("ServerScriptService").Server.GameRuntime)
local Harness = {}
type Record = { [string]: unknown }
type Ticket = { player: Player, ok: boolean?, detail: string? }
type Case = { name: string, passed: boolean, detail: string? }
local function waitFor(predicate: () -> boolean, label: string, seconds: number?)
    local deadline = os.clock() + (seconds or 20)
    repeat
        if predicate() then
            return
        end
        task.wait()
    until os.clock() >= deadline
    error("P18 timeout: " .. label)
end
-- Runs one fresh Studio-only three-client scenario and yields for actual
-- replication and gameplay. Requires the caller to own the local test document
-- with no competing runtime. A finish callback keeps native Server & Clients
-- open for report collection; otherwise EndTest returns the SDK report. Every
-- expected case failure is recorded, then owned runtime/transport are cleaned.
-- Startup and assertion failures never count as skipped or passing checks.
function Harness.run(finish: ((unknown) -> ())?)
    assert(
        game:GetService("RunService"):IsStudio() and game.PlaceId == 0 and game.GameId == 0,
        "P18 requires the separate local Studio test document"
    )
    local cases: { Case } = {}
    local observations: { Record } = {}
    local smoke: { [string]: unknown } = {}
    local passed = 0
    local function check(name: string, callback: () -> ()): boolean
        workspace:SetAttribute("P18Stage", name)
        local ok, problem = pcall(function()
            callback()
            return true
        end)
        table.insert(cases, { name = name, passed = ok, detail = if ok then nil else tostring(problem) })
        if ok then
            passed += 1
        end
        return ok
    end
    local runtime: GameRuntime.Controller? = nil
    local remote: RemoteEvent? = nil
    local listener: RBXScriptConnection? = nil
    local ids: { number } = {}
    local function deliver()
        if runtime then
            runtime.stop()
        end
        if listener then
            listener:Disconnect()
        end
        if remote then
            remote:Destroy()
        end
        local report = {
            suite = "P18-rebalancing",
            environment = "Studio",
            clientIds = ids,
            actualClients = #ids,
            finalClients = #Players:GetPlayers(),
            discovered = #cases,
            passed = passed,
            failed = #cases - passed,
            skipped = 0,
            cases = cases,
            observations = observations,
            smoke = { server = workspace:GetAttribute("ServerTestReport"), clients = smoke },
        }
        workspace:SetAttribute("P18Report", HttpService:JSONEncode(report))
        if finish then
            finish(report)
        else
            StudioTestService:EndTest(report)
        end
    end
    if
        not check("Three actual clients connect", function()
            waitFor(function()
                return #Players:GetPlayers() == 3
            end, "three clients", 60)
            for _, player in Players:GetPlayers() do
                table.insert(ids, player.UserId)
            end
        end)
    then
        deliver()
        return
    end
    local owned, reason = GameRuntime.start({
        automaticDeployment = false,
        minimumPlayers = 3,
        durationSeconds = 180,
        lobbySeconds = 0,
        deploymentSeconds = 30,
        resultsSeconds = 0.5,
        seed = 1,
    })
    if not owned then
        check("Runtime starts", function()
            error(reason)
        end)
        deliver()
        return
    end
    runtime = owned
    local match = owned.rounds.match
    local transport = Instance.new("RemoteEvent")
    transport.Name = "P18Harness"
    remote = transport
    local tickets: { [number]: Ticket } = {}
    local serial = 0
    listener = transport.OnServerEvent:Connect(
        function(player: Player, token: unknown, ok: unknown, detail: unknown)
            if token == 0 and ok == true and type(detail) == "string" then
                local report = HttpService:JSONDecode(detail)
                assert(type(report) == "table" and report.userId == player.UserId, "smoke identity mismatch")
                smoke[tostring(player.UserId)] = report
            elseif type(token) == "number" and type(detail) == "string" and #detail < 16384 then
                local ticket = tickets[token]
                if ticket and ticket.player == player and ticket.ok == nil then
                    ticket.ok, ticket.detail = ok == true, detail
                end
            end
        end
    )
    transport.Parent = ReplicatedStorage
    local function probe(player: Player, action: string, payload: unknown)
        serial += 1
        local token = serial
        local ticket: Ticket = { player = player }
        tickets[token] = ticket
        transport:FireClient(player, token, action, payload)
        waitFor(function()
            return ticket.ok ~= nil
        end, player.Name .. " " .. action, 35)
        tickets[token] = nil
        assert(ticket.ok, ticket.detail)
        local observation: Record = { userId = player.UserId, action = action, detail = ticket.detail }
        table.insert(observations, observation)
    end
    local function observe(health: number, maximum: number)
        for _, player in Players:GetPlayers() do
            probe(player, "Observe", { health = health, maximum = maximum })
        end
    end
    local operator: Player? = nil
    local ground: { Player } = {}
    local round = 0
    local ready = check("A1 roster excludes operator and all clients share 2000 health", function()
        waitFor(function()
            for _, player in Players:GetPlayers() do
                if not smoke[tostring(player.UserId)] then
                    return false
                end
            end
            return true
        end, "all client smoke", 90)
        for _, value in smoke do
            local report = value :: Record
            assert(
                report.passed == report.discovered
                    and report.failed == 0
                    and report.skipped == 0
                    and report.errors == 0,
                "client smoke failed"
            )
        end
        assert(match.deploy(), "P18 assertion: match.deploy()")
        waitFor(function()
            return match.snapshot().phase == "Active"
        end, "deployment", 40)
        local state = match.snapshot()
        round = state.roundId
        for _, player in Players:GetPlayers() do
            local member = state.members[player.UserId]
            if member.role == "Gunship" then
                operator = player
            elseif member.role == "Ground" then
                table.insert(ground, player)
            end
        end
        assert(operator and #ground == 2, "incorrect deployed roles")
        observe(2000, 2000)
    end)
    if ready then
        local op = assert(operator, "P18 assertion: operator")
        check("A2 native wall roof Sandbreak Seedship openings replicate", function()
            local map = workspace.World.Battlefield
            local selected: { Model } = {}
            for _, root in
                {
                    map:FindFirstChild("PrismPanels"),
                    map:FindFirstChild("SpawnShelterPanels"),
                    map.Buildings.Outpost:FindFirstChild("Outpost_Panels"),
                }
            do
                assert(root, "coverage registry missing")
                local wall: Model? = nil
                local roof: Model? = nil
                for _, item in root:GetChildren() do
                    if item:IsA("Model") then
                        if string.find(string.lower(item.Name), "roof") then
                            roof = roof or item
                        else
                            wall = wall or item
                        end
                    end
                end
                assert(wall and roof, "wall/roof coverage missing")
                table.insert(selected, wall)
                table.insert(selected, roof)
            end
            local shot = 0
            for _, panel in selected do
                local solid: BasePart? = nil
                for _, item in panel:GetDescendants() do
                    if item:IsA("BasePart") and item.CanCollide and item.CanQuery then
                        solid = item
                        break
                    end
                end
                assert(solid, "pristine collider missing")
                local collider = solid
                shot += 1
                assert(
                    owned.destruction.resolve({
                        roundId = round,
                        shotId = shot,
                        weapon = "M102",
                        firedAt = shot * 4,
                        panelId = panel.Name,
                    }),
                    'P18 assertion: owned.destruction.resolve({ roundId = round, shotId = shot, weapon = "M102", firedAt = shot * 4, panelId = panel.Name, })'
                )
                assert(collider.Parent and collider.CanCollide, "pre-flush geometry changed")
                owned.destruction.flush(workspace:GetServerTimeNow())
                assert(
                    panel:GetAttribute("DamageAppearance") == "Total",
                    "one howitzer did not destroy panel"
                )
                local rays = RaycastParams.new()
                rays.FilterType = Enum.RaycastFilterType.Include
                rays.FilterDescendantsInstances = { panel }
                rays.RespectCanCollide = true
                assert(
                    workspace:Raycast(collider.Position + Vector3.yAxis * 10, -Vector3.yAxis * 20, rays)
                        == nil,
                    "Total native ray blocked"
                )
                for _, player in Players:GetPlayers() do
                    probe(player, "Panel", { id = panel.Name, appearance = "Total" })
                end
            end
            local burstPanel: Model? = nil
            for _, item in map.Buildings.Outpost.Outpost_Panels:GetChildren() do
                if item:IsA("Model") and item:GetAttribute("DamageAppearance") == "Pristine" then
                    burstPanel = item
                    break
                end
            end
            local panel = assert(burstPanel, "no pristine short-burst fixture")
            for sample = 0, 5 do
                shot += 1
                assert(
                    owned.destruction.resolve({
                        roundId = round,
                        shotId = shot,
                        weapon = "GAU23",
                        firedAt = 100 + sample * 0.2,
                        panelId = panel.Name,
                    }),
                    'P18 assertion: owned.destruction.resolve({ roundId = round, shotId = shot, weapon = "GAU23", firedAt = 100 + sample * 0.2, panelId = panel.Name, })'
                )
            end
            owned.destruction.flush(workspace:GetServerTimeNow())
            assert(panel:GetAttribute("DamageAppearance") == "Heavy", "one-second Heavy missing")
            for _, player in Players:GetPlayers() do
                probe(player, "Panel", { id = panel.Name, appearance = "Heavy" })
            end
            for sample = 0, 5 do
                shot += 1
                assert(
                    owned.destruction.resolve({
                        roundId = round,
                        shotId = shot,
                        weapon = "GAU23",
                        firedAt = 200 + sample * 0.2,
                        panelId = panel.Name,
                    }),
                    'P18 assertion: owned.destruction.resolve({ roundId = round, shotId = shot, weapon = "GAU23", firedAt = 200 + sample * 0.2, panelId = panel.Name, })'
                )
            end
            owned.destruction.flush(workspace:GetServerTimeNow())
            assert(panel:GetAttribute("DamageAppearance") == "Total", "two earned seconds failed after gap")
            for _, player in Players:GetPlayers() do
                probe(player, "Panel", { id = panel.Name, appearance = "Total" })
            end
            assert(owned.destruction.resources().fragments <= 48, "fragment bound exceeded")
        end)
        check("A3 square camera and two weapon profiles remain finite across orbit", function()
            probe(op, "SquareFrames", {})
            probe(op, "Camera", { right = 1, up = 0, seconds = 0.6 })
            probe(op, "Select", { roundId = round, sequence = 1, weapon = "M102" })
            probe(op, "Camera", { right = 0, up = 1, seconds = 0.6 })
            probe(op, "Select", { roundId = round, sequence = 2, weapon = "GAU23" })
        end)
        check("A6 thermal targets are red and ground palette is muted with native occlusion", function()
            probe(op, "Thermal", {})
        end)
        local carrier: Player? = nil
        check("A4 four sites and raced Seedship pickup retain one owner", function()
            local map = workspace.World.Battlefield
            local anchor = map.Anchors.LauncherSeedship
            assert(
                anchor:IsA("BasePart") and map:FindFirstChild("PrismSeedshipHull"),
                "Seedship site missing"
            )
            for _, site in { "Radar", "Hangar", "Depot", "Seedship" } do
                assert(owned.launcher.snapshot(site).state == "Available", "site missing " .. site)
            end
            for index, player in ground do
                local body = assert(player.Character, "P18 assertion: player.Character")
                local root = body:FindFirstChild("HumanoidRootPart")
                assert(root and root:IsA("BasePart"), 'P18 assertion: root and root:IsA("BasePart")')
                root.CFrame = CFrame.new(anchor.Position + Vector3.new((index - 1.5) * 3, 0, 0))
                root.AssemblyLinearVelocity = Vector3.zero
                assert(owned.groundCombat.trustCorrection(player), "trusted placement failed")
            end
            task.wait(0.25)
            local snapshot = owned.launcher.snapshot("Seedship")
            local acknowledgements = 0
            local raceFailure: string? = nil
            for _, player in ground do
                task.spawn(function()
                    local ok, problem = pcall(function()
                        probe(player, "Launcher", {
                            action = "Pickup",
                            payload = { roundId = round, sequence = 1, launcherId = snapshot.launcherId },
                        })
                        return true
                    end)
                    if not ok then
                        raceFailure = tostring(problem)
                    end
                    acknowledgements += 1
                end)
            end
            waitFor(function()
                return acknowledgements == 2
            end, "both raced claim intents")
            assert(not raceFailure, raceFailure)
            waitFor(function()
                return owned.launcher.snapshot("Seedship").state == "Held"
            end, "raced pickup")
            local held = owned.launcher.snapshot("Seedship")
            carrier = Players:GetPlayerByUserId(assert(held.ownerId, "P18 assertion: held.ownerId"))
            assert(
                carrier and (held.ownerId == ground[1].UserId or held.ownerId == ground[2].UserId),
                "P18 assertion: carrier and (held.ownerId == ground[1].UserId or held.ownerId == ground[2].UserId)"
            )
            local tools = 0
            for _, player in ground do
                local containers: { Instance } = {}
                if player.Character then
                    table.insert(containers, player.Character)
                end
                local backpack = player:FindFirstChildOfClass("Backpack")
                if backpack then
                    table.insert(containers, backpack)
                end
                for _, container in containers do
                    if container then
                        for _, item in container:GetChildren() do
                            if item:IsA("Tool") and item:GetAttribute("LauncherId") == held.launcherId then
                                tools += 1
                            end
                        end
                    end
                end
            end
            assert(tools == 1, "raced pickup duplicated launcher")
            local holder = assert(carrier, "raced carrier missing")
            local root = holder.Character and holder.Character:FindFirstChild("HumanoidRootPart")
            assert(root and root:IsA("BasePart"), "carrier root missing")
            local returnPose = root.CFrame
            root.CFrame = CFrame.new(map.Anchors.LauncherRadar.Position)
            root.AssemblyLinearVelocity = Vector3.zero
            assert(owned.groundCombat.trustCorrection(holder), "Radar correction failed")
            local radar = owned.launcher.snapshot("Radar")
            probe(holder, "Launcher", {
                action = "Pickup",
                payload = { roundId = round, sequence = 2, launcherId = radar.launcherId },
            })
            task.wait(0.2)
            assert(
                owned.launcher.snapshot("Radar").state == "Available"
                    and owned.launcher.snapshot("Seedship").ownerId == holder.UserId,
                "one carrier acquired two launchers"
            )
            root.CFrame = returnPose
            root.AssemblyLinearVelocity = Vector3.zero
            assert(owned.groundCombat.trustCorrection(holder), "Seedship return correction failed")
            local observation: Record = {
                launcherId = held.launcherId,
                ownerId = held.ownerId,
                position = { anchor.Position.X, anchor.Position.Y, anchor.Position.Z },
            }
            table.insert(observations, observation)
        end)
        if carrier then
            check("A4 fired drop recovery preserves reload and fixed damage", function()
                local player = assert(carrier, "P18 assertion: carrier")
                local held = owned.launcher.snapshot("Seedship")
                probe(player, "EquipLauncher", {})
                probe(player, "Launcher", {
                    action = "Fire",
                    payload = {
                        roundId = round,
                        sequence = 2,
                        launcherId = held.launcherId,
                        x = 0,
                        y = 300,
                        z = 214,
                    },
                })
                waitFor(function()
                    return owned.launcher.snapshot("Seedship").readyAt > workspace:GetServerTimeNow()
                end, "rocket reload")
                local readyAt = owned.launcher.snapshot("Seedship").readyAt
                probe(player, "Launcher", {
                    action = "Drop",
                    payload = { roundId = round, sequence = 3, launcherId = held.launcherId },
                })
                waitFor(function()
                    return owned.launcher.snapshot("Seedship").state == "Available"
                end, "drop")
                assert(owned.launcher.snapshot("Seedship").readyAt == readyAt, "drop reset reload")
                local recovering = if player == ground[1] then ground[2] else ground[1]
                local dropped = owned.launcher.snapshot("Seedship")
                probe(recovering, "Launcher", {
                    action = "Pickup",
                    payload = { roundId = round, sequence = 2, launcherId = dropped.launcherId },
                })
                waitFor(function()
                    return owned.launcher.snapshot("Seedship").ownerId == recovering.UserId
                end, "teammate recovery")
                assert(owned.launcher.snapshot("Seedship").readyAt == readyAt, "transfer reset reload")
                local root = assert(
                    workspace:FindFirstChild("Aircraft"),
                    'P18 assertion: workspace:FindFirstChild("Aircraft")'
                ):FindFirstChild("Hitbox")
                assert(root and root:IsA("BasePart"), 'P18 assertion: root and root:IsA("BasePart")')
                local collision, applied = owned.groundCombat.rocketCast(
                    round,
                    "P18-fixed",
                    root.Position + Vector3.yAxis * 50,
                    -Vector3.yAxis * 65
                )
                assert(collision and applied, "native direct rocket ray missed")
                observe(1900, 2000)
                local _, duplicateApplied = owned.groundCombat.rocketCast(
                    round,
                    "P18-fixed",
                    root.Position + Vector3.yAxis * 50,
                    -Vector3.yAxis * 65
                )
                assert(not duplicateApplied, "duplicate awarded")
            end)
        end
        check(
            "A1 A4 carrier death drops one launcher without resizing health or granting spectator pickup",
            function()
                local held = owned.launcher.snapshot("Seedship")
                local holder = assert(
                    held.ownerId and Players:GetPlayerByUserId(held.ownerId),
                    "recovered carrier missing"
                )
                local body = holder.Character and holder.Character:FindFirstChildOfClass("Humanoid")
                assert(body, "carrier body missing")
                body.Health = 0
                waitFor(function()
                    return match.snapshot().members[holder.UserId].life == "Eliminated"
                        and owned.launcher.snapshot("Seedship").state == "Available"
                end, "carrier death recovery")
                assert(owned.launcher.snapshot("Seedship").readyAt == held.readyAt, "death reset reload")
                observe(1900, 2000)
                local before = owned.launcher.snapshot("Seedship")
                probe(holder, "Launcher", {
                    action = "Pickup",
                    payload = { roundId = round, sequence = 99, launcherId = before.launcherId },
                })
                task.wait(0.2)
                local after = owned.launcher.snapshot("Seedship")
                assert(
                    after.state == "Available" and after.ownerId == nil and after.revision == before.revision,
                    "spectator pickup mutated ownership"
                )
            end
        )
        check("A1 A4 reset restores four pristine sites and next deployment health", function()
            assert(match.abort(round, "P18Reset"), 'P18 assertion: match.abort(round, "P18Reset")')
            waitFor(function()
                return match.snapshot().phase == "Lobby"
            end, "reset", 50)
            assert(match.deploy(), "P18 assertion: match.deploy()")
            waitFor(function()
                return match.snapshot().phase == "Active"
            end, "next round", 40)
            assert(match.snapshot().roundId > round, "P18 assertion: match.snapshot().roundId > round")
            observe(2000, 2000)
            for _, site in { "Radar", "Hangar", "Depot", "Seedship" } do
                local state = owned.launcher.snapshot(site)
                assert(
                    state.state == "Available" and state.ammo == 1 and state.ownerId == nil,
                    "launcher reset failed"
                )
            end
        end)
        check("A1 A4 actual carrier departure recovers equipment without health resize", function()
            local state = match.snapshot()
            local departing: Player? = nil
            for _, player in Players:GetPlayers() do
                if state.members[player.UserId].role == "Ground" then
                    departing = player
                    break
                end
            end
            local player = assert(departing, "departure Ground player missing")
            local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            assert(root and root:IsA("BasePart"), "departure root missing")
            local anchor = workspace.World.Battlefield.Anchors.LauncherSeedship
            root.CFrame = CFrame.new(anchor.Position)
            root.AssemblyLinearVelocity = Vector3.zero
            assert(owned.groundCombat.trustCorrection(player), "departure placement failed")
            local site = owned.launcher.snapshot("Seedship")
            probe(player, "Launcher", {
                action = "Pickup",
                payload = { roundId = state.roundId, sequence = 1, launcherId = site.launcherId },
            })
            waitFor(function()
                return owned.launcher.snapshot("Seedship").ownerId == player.UserId
            end, "departure pickup")
            local readyAt = owned.launcher.snapshot("Seedship").readyAt
            local userId = player.UserId
            player:Kick("P18 local Studio departure fixture")
            waitFor(function()
                local current = match.snapshot().members[userId]
                return current ~= nil
                    and not current.connected
                    and owned.launcher.snapshot("Seedship").state == "Available"
            end, "actual departure recovery", 30)
            assert(owned.launcher.snapshot("Seedship").readyAt == readyAt, "departure reset readiness")
            assert(match.snapshot().phase == "Active", "single Ground departure ended populated round")
            observe(2000, 2000)
            local observation: Record = {
                kind = "actual-carrier-departure",
                method = "server-Kick",
                userId = userId,
                remainingClients = #Players:GetPlayers(),
            }
            table.insert(observations, observation)
        end)
        check("A3 A6 client owners clean up after replay and departure", function()
            for _, player in Players:GetPlayers() do
                probe(player, "Cleanup", {})
            end
        end)
    end
    deliver()
end
return Harness
