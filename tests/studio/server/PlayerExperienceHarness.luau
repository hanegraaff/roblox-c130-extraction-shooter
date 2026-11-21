--!strict
-- P10 test-only orchestration. Four actual Studio clients exercise production
-- HUD, input, cameras and remote authority with two simultaneous spectator targets.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StudioTestService = game:GetService("StudioTestService")
local GameRuntime = require(game:GetService("ServerScriptService").Server.GameRuntime)
local Harness = {}

type Case = { name: string, passed: boolean, detail: string? }
type Ticket = { owner: Player, ok: boolean?, detail: string? }
type Record = { [string]: unknown }
type Report = {
    suite: string,
    environment: string,
    mode: string,
    initialIds: { number },
    finalClients: number,
    discovered: number,
    passed: number,
    failed: number,
    skipped: number,
    cases: { Case },
    observations: { Record },
    smoke: { server: Record?, clients: { [string]: Record } },
}

local function waitFor(predicate: () -> boolean, name: string, seconds: number?)
    local deadline = os.clock() + (seconds or 12)
    repeat
        if predicate() then
            return
        end
        task.wait()
    until os.clock() >= deadline
    error("P10 timeout: " .. name, 2)
end

local function body(player: Player): Humanoid
    local character = assert(player.Character, "missing " .. player.Name .. " character")
    return assert(character:FindFirstChildOfClass("Humanoid"), "missing " .. player.Name .. " humanoid")
end

local function decode(encoded: unknown): Record?
    if type(encoded) ~= "string" or #encoded > 4096 then
        return nil
    end
    local ok, value = pcall(function(): unknown
        return HttpService:JSONDecode(encoded)
    end)
    return if ok and type(value) == "table" then value :: Record else nil
end

-- Runs to completion with SDK or manual local Server & Clients. Manual mode
-- keeps the report in the server DataModel for retrieval before End Session.
function Harness.run(finish: ((Report) -> ())?)
    local cases: { Case } = {}
    local smoke: { [string]: Record } = {}
    local observations: { Record } = {}
    local initialIds: { number } = {}
    local passed = 0
    local function check(name: string, action: () -> ()): boolean
        workspace:SetAttribute("P10Stage", name)
        local ok, problem = pcall(function()
            action()
            return true
        end)
        table.insert(cases, { name = name, passed = ok, detail = if ok then nil else tostring(problem) })
        if ok then
            passed += 1
        end
        return ok
    end
    local function deliver()
        local report: Report = {
            suite = "P10-multiplayer",
            environment = "Studio",
            mode = if finish then "native-server-clients" else "sdk",
            initialIds = initialIds,
            finalClients = #Players:GetPlayers(),
            discovered = #cases,
            passed = passed,
            failed = #cases - passed,
            skipped = 0,
            cases = cases,
            observations = observations,
            smoke = { server = decode(workspace:GetAttribute("ServerTestReport")), clients = smoke },
        }
        if finish then
            finish(report)
        else
            StudioTestService:EndTest(report)
        end
    end
    if
        not check("Four actual clients connected", function()
            waitFor(function()
                return #Players:GetPlayers() == 4
            end, "four actual clients", 50)
            for _, player in Players:GetPlayers() do
                table.insert(initialIds, player.UserId)
            end
        end)
    then
        deliver()
        return
    end
    local rifleDecisions: { [number]: string } = {}
    local runtime, problem = GameRuntime.start({
        automaticDeployment = false,
        minimumPlayers = 4,
        durationSeconds = 120,
        lobbySeconds = 0,
        deploymentSeconds = 25,
        resultsSeconds = 14,
        seed = 1,
    }, {
        observeFire = function(userId, decision)
            rifleDecisions[userId] = decision
        end,
    })
    if not runtime then
        table.insert(cases, { name = "Runtime startup", passed = false, detail = problem })
        deliver()
        return
    end
    game:BindToClose(runtime.stop)
    local match = runtime.rounds.match
    local remote = Instance.new("RemoteEvent")
    remote.Name = "P10Harness"
    local tickets: { [number]: Ticket } = {}
    local sequence = 0
    local listener = remote.OnServerEvent:Connect(
        function(player: Player, token: unknown, ok: unknown, detail: unknown)
            if token == 0 and ok == true then
                local report = decode(detail)
                if report and report.userId == player.UserId then
                    smoke[tostring(player.UserId)] = report
                end
            elseif type(token) == "number" and type(detail) == "string" and #detail <= 4096 then
                local ticket = tickets[token]
                if ticket and ticket.owner == player and ticket.ok == nil then
                    ticket.ok, ticket.detail = ok == true, detail
                end
            end
        end
    )
    remote.Parent = ReplicatedStorage
    local function probe(player: Player, action: string, payload: unknown)
        sequence += 1
        local token = sequence
        local ticket: Ticket = { owner = player }
        tickets[token] = ticket
        remote:FireClient(player, token, action, payload)
        waitFor(function()
            return ticket.ok ~= nil
        end, player.Name .. " " .. action)
        tickets[token] = nil
        assert(ticket.ok, ticket.detail)
        local result = decode(ticket.detail)
        if result then
            result.action, result.userId = action, player.UserId
            table.insert(observations, result)
        end
    end
    local operator: Player? = nil
    local ground: { Player } = {}
    local roundId = 0
    local ready = check("Native smoke, lobby view and role assignment", function()
        waitFor(function()
            for _, player in Players:GetPlayers() do
                local report = smoke[tostring(player.UserId)]
                if not report then
                    return false
                end
                assert(
                    report.passed == report.discovered
                        and report.failed == 0
                        and report.skipped == 0
                        and report.errors == 0,
                    "client smoke failed"
                )
            end
            return true
        end, "all client smoke reports", 80)
        for _, player in Players:GetPlayers() do
            probe(player, "View", { view = "Waiting" })
        end
        assert(match.deploy(), "round deployment rejected")
        waitFor(function()
            return match.snapshot().phase == "Active" and runtime.launcher.snapshot().state == "Available"
        end, "deployment", 35)
        local snapshot = match.snapshot()
        roundId = snapshot.roundId
        for _, player in Players:GetPlayers() do
            local member = snapshot.members[player.UserId]
            assert(member, "missing participant")
            if member.role == "Gunship" then
                operator = player
            elseif member.role == "Ground" then
                table.insert(ground, player)
            end
        end
        assert(operator and #ground == 3, "expected one Operator and three Ground")
        table.sort(ground, function(a, b)
            return a.UserId < b.UserId
        end)
    end)
    if ready then
        local gunship = assert(operator, "Operator disappeared after deployment")
        local eliminated, first, second = ground[1], ground[2], ground[3]
        check("Role HUD, shared readiness and both acknowledged weapon views", function()
            -- Roblox reserves the number keys for its CoreGui inventory.
            -- Equip the actual Tool, then verify its live replicated HUD.
            local backpack = assert(first:FindFirstChildOfClass("Backpack"), "Ground backpack missing")
            local tool = backpack:FindFirstChild("M-7 rifle")
            assert(tool and tool:IsA("Tool"), "Ground M-7 rifle missing")
            body(first):EquipTool(tool)
            probe(first, "View", { view = "Ground", phrase = "M-7", ammo = true })
            local rifle = runtime.groundCombat.readiness(first)
            probe(first, "RejectFullReload", {})
            local after = runtime.groundCombat.readiness(first)
            assert(
                after.ammo == rifle.ammo
                    and after.reserve == rifle.reserve
                    and after.reloadUntil == rifle.reloadUntil,
                "rejected reload changed authoritative readiness"
            )
            probe(gunship, "View", {
                view = "Operator",
                phrase = "thermal",
                profile = "30mm GAU-23/A Chain Gun",
                fov = 30,
            })
            probe(gunship, "AircraftState/SelectWeapon", { roundId = roundId, weapon = "M102", sequence = 1 })
            probe(gunship, "View", {
                view = "Operator",
                profile = "105mm M102 Howitzer",
                fov = 40,
            })
            assert(runtime.aircraft.weapon() == "M102", "weapon selection did not reach authoritative server")
        end)
        check("Keyboard help/settings and muted visual warning preserve authority", function()
            local aircraft = ReplicatedStorage.AircraftState
            local health = aircraft:GetAttribute("Health")
            local launcher = runtime.launcher.snapshot()
            local rifle = runtime.groundCombat.readiness(first)
            probe(first, "HelpAndSettings", { view = "Ground" })
            local effects = assert(workspace:FindFirstChild("CombatEffects"), "combat effects owner absent")
            local root = assert((first.Character :: Model):FindFirstChild("HumanoidRootPart"))
            assert(root:IsA("BasePart"))
            -- The fixture holds the same warning representation near a real
            -- avatar independently of short projectile travel and frame timing.
            local warning = Instance.new("Part")
            warning.Name = "ImpactWarning"
            warning.Anchored = true
            warning.CanCollide, warning.CanQuery, warning.CanTouch = false, false, false
            warning.Position = root.Position
            warning:SetAttribute("Stage", "Warning")
            warning:SetAttribute("Weapon", "M102")
            warning.Parent = effects
            local ok, err = pcall(function()
                probe(first, "Cue", { phrase = "INCOMING GUNSHIP FIRE" })
                return true
            end)
            warning:Destroy()
            assert(ok, tostring(err))
            local after = runtime.launcher.snapshot()
            local rifleAfter = runtime.groundCombat.readiness(first)
            assert(
                aircraft:GetAttribute("Health") == health
                    and after.state == launcher.state
                    and after.ammo == launcher.ammo
                    and after.ownerId == launcher.ownerId
                    and after.readyAt == launcher.readyAt
                    and rifleAfter.ammo == rifle.ammo
                    and rifleAfter.reserve == rifle.reserve
                    and match.snapshot().phase == "Active"
                    and match.snapshot().roundId == roundId,
                "local preferences mutated authoritative state"
            )
        end)
        check("Elimination cycles only living teammates and rejects action", function()
            body(eliminated).Health = 0
            waitFor(function()
                return eliminated.Character == nil
                    and match.snapshot().members[eliminated.UserId].life == "Eliminated"
            end, "eliminated avatar release")
            probe(eliminated, "View", { view = "Spectator", targetId = first.UserId })
            probe(eliminated, "NextTarget", { view = "Spectator", targetId = second.UserId })
            probe(eliminated, "PreviousTarget", { view = "Spectator", targetId = first.UserId })
            local launcher = runtime.launcher.snapshot()
            local aircraft = ReplicatedStorage.AircraftState
            local health, readiness = aircraft:GetAttribute("Health"), aircraft:GetAttribute("Readiness")
            local selected = runtime.aircraft.weapon()
            probe(eliminated, "LauncherState/Pickup", {
                roundId = roundId,
                launcherId = launcher.launcherId,
                sequence = 1,
            })
            probe(eliminated, "AircraftState/SelectWeapon", {
                roundId = roundId,
                weapon = if selected == "M102" then "GAU23" else "M102",
                sequence = 1,
            })
            probe(eliminated, "AircraftState/GroundFire", {
                roundId = roundId,
                sequence = 1,
                weapon = "M7",
                x = 0,
                y = 0,
                z = 0,
            })
            waitFor(function()
                return rifleDecisions[eliminated.UserId] == "inactive"
            end, "spectator rifle intent reached server and was rejected")
            local after = runtime.launcher.snapshot()
            assert(
                after.ownerId == nil and after.state == "Available" and after.ammo == launcher.ammo,
                "spectator pickup changed launcher state"
            )
            assert(
                aircraft:GetAttribute("Health") == health and aircraft:GetAttribute("Readiness") == readiness,
                "spectator action changed aircraft state"
            )
            assert(
                runtime.aircraft.weapon() == selected and eliminated.Character == nil,
                "spectator selected a weapon or gained a character"
            )
            body(first).Health = 0
            probe(eliminated, "View", { view = "Spectator", targetId = second.UserId })
        end)
        check("No living target yields neutral result, then restores all local cameras", function()
            body(second).Health = 0
            waitFor(function()
                return match.snapshot().phase == "Results"
            end, "ground elimination result")
            for _, player in Players:GetPlayers() do
                probe(player, "View", { view = "Results", result = "All ground players were eliminated." })
            end
            waitFor(function()
                return match.snapshot().phase == "Lobby"
            end, "lobby reset", 45)
            for _, player in Players:GetPlayers() do
                probe(player, "View", { view = "Waiting" })
            end
        end)
        check("Destruction result and steady view remain visible with both settings off", function()
            assert(match.deploy(), "could not deploy the replay round")
            waitFor(function()
                return match.snapshot().phase == "Active" and runtime.launcher.snapshot().state == "Available"
            end, "replay deployment", 35)
            local replay = match.snapshot()
            assert(replay.roundId ~= roundId, "the replay retained the original round ID")
            for index = 1, 3 do
                assert(
                    runtime.groundCombat.rocketImpact(replay.roundId, "p10-controlled-impact-" .. index, true),
                    "controlled aircraft damage rejected"
                )
            end
            probe(first, "StillDestruction", {
                view = "Results",
                result = "The C-130 was destroyed.",
            })
            local result = match.snapshot().result
            assert(result and result.reason == "AircraftDestroyed", "wrong destruction result")
        end)
    end
    check("Runtime teardown removes HUD, camera subjects and fixture owners", function()
        runtime.stop()
        runtime.stop()
        if ready then
            for _, player in Players:GetPlayers() do
                probe(player, "NoHud", {})
            end
        end
        listener:Disconnect()
        remote:Destroy()
        assert(
            runtime.resources().frameConnections == 0
                and ReplicatedStorage:FindFirstChild("P10Harness") == nil,
            "runtime or fixture remained"
        )
    end)
    listener:Disconnect()
    remote:Destroy()
    deliver()
end

return Harness
