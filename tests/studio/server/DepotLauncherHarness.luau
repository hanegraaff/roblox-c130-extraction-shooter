--!strict
-- P29 native integration coordinator. Starts the real runtime and uses three
-- actual Studio clients, two of whom observe each transfer. Only fixture poses,
-- a terminal Humanoid death and round restarts bypass ordinary player input.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local StudioTestService = game:GetService("StudioTestService")
local Server = game:GetService("ServerScriptService").Server
local GameRuntime = require(Server.GameRuntime)
local Geometry = require(Server.LauncherGeometry)
local LauncherService = require(Server.LauncherService)
local CombatFixture = require(script.Parent.P11CombatFixture)
local Harness = {}

local SITES = { "Radar", "Hangar", "Depot", "Seedship" }
type Record = { [string]: unknown }
type Case = { name: string, passed: boolean, detail: string? }
type Reply = { player: Player, ok: boolean?, detail: string? }

local function waitFor(predicate: () -> boolean, label: string, seconds: number?)
    local deadline = os.clock() + (seconds or 10)
    while not predicate() and os.clock() < deadline do
        task.wait()
    end
    assert(predicate(), "P29 server timeout: " .. label)
end

local function decoded(owner: Instance, key: string): Record?
    local raw = owner:GetAttribute(key)
    return if type(raw) == "string" then HttpService:JSONDecode(raw) else nil
end

local function vector(position: LauncherService.Position): Vector3
    return Vector3.new(position.x, position.y, position.z)
end

local function handle(owner: Instance): BasePart
    local part = owner:FindFirstChild("Handle")
    assert(part and part:IsA("BasePart"), "depot launcher Handle missing")
    return part
end

local function marker(owner: Instance, name: string): Attachment
    local item = handle(owner):FindFirstChild(name)
    assert(item and item:IsA("Attachment"), "depot launcher attachment missing " .. name)
    return item
end

-- Runs a three-client Studio test. SDK mode returns its report through EndTest.
-- The native UI route leaves the session open for report collection. Optional
-- bounded pauses expose live pickup/hold poses for rendered device review.
function Harness.run(automated: boolean, reviewSeconds: number)
    assert(game.PlaceId == 0 and game.GameId == 0, "P29 requires the separate local Studio test document")
    local cases: { Case } = {}
    local observations: { unknown } = {}
    local clients: { number } = {}
    local completedRounds: { number } = {}
    local smoke: { [string]: Record } = {}
    local runtime: GameRuntime.Controller? = nil
    local transport = Instance.new("RemoteEvent")
    transport.Name = "P29Harness"
    local requests: { [number]: Reply } = {}
    local serial = 0
    local flightListener: RBXScriptConnection? = nil
    local listener = transport.OnServerEvent:Connect(
        function(player: Player, token: unknown, ok: unknown, value: unknown)
            if type(token) ~= "number" or type(value) ~= "string" or #value > 4096 then
                return
            end
            if token == 0 and ok == true then
                local report = HttpService:JSONDecode(value)
                if type(report) == "table" and report.userId == player.UserId then
                    smoke[tostring(player.UserId)] = report
                end
            else
                local ticket = requests[token]
                if ticket and ticket.player == player and ticket.ok == nil then
                    ticket.ok, ticket.detail = ok == true, value
                end
            end
        end
    )
    local function check(name: string, callback: () -> ())
        workspace:SetAttribute("P29Stage", name)
        local ok, failure = pcall(function()
            callback()
            return true
        end)
        table.insert(cases, { name = name, passed = ok, detail = if ok then nil else tostring(failure) })
        assert(ok, tostring(failure))
    end
    local function probe(player: Player, action: string, fields: Record): unknown
        serial += 1
        local token = serial
        local reply: Reply = { player = player }
        requests[token] = reply
        transport:FireClient(player, token, action, fields)
        waitFor(function()
            return reply.ok ~= nil
        end, action .. " acknowledgement from " .. player.Name)
        requests[token] = nil
        assert(reply.ok == true and reply.detail, reply.detail)
        return HttpService:JSONDecode(reply.detail)
    end
    local passed, failure = pcall(function()
        check("Three actual clients and smoke reports", function()
            waitFor(function()
                return #Players:GetPlayers() == 3
            end, "three actual Studio clients", 60)
            local owned, reason = GameRuntime.start({
                automaticDeployment = false,
                minimumPlayers = 3,
                durationSeconds = 180,
                scatterSeconds = 0,
                lobbySeconds = 0,
                resultsSeconds = 0.5,
                intermissionSeconds = 0,
                deploymentSeconds = 25,
                seed = 1,
            })
            assert(owned, reason)
            runtime = owned
            transport.Parent = ReplicatedStorage
            waitFor(function()
                for _, player in Players:GetPlayers() do
                    if not smoke[tostring(player.UserId)] then
                        return false
                    end
                end
                return #Players:GetPlayers() == 3
            end, "all client smoke reports", 60)
            for _, player in Players:GetPlayers() do
                table.insert(clients, player.UserId)
                local report = smoke[tostring(player.UserId)]
                assert(
                    report.passed == report.discovered
                        and report.failed == 0
                        and report.skipped == 0
                        and report.errors == 0,
                    "client smoke was incomplete"
                )
            end
        end)
        local owned = assert(runtime, "runtime unavailable")
        local match = owned.rounds.match
        local effects = workspace.LauncherEffects
        local state = ReplicatedStorage.LauncherState
        local round = 0
        local ground: { Player } = {}
        local sequences: { [Player]: number } = {}
        local function deploy()
            assert(match.deploy(), "fixture deployment rejected")
            waitFor(function()
                return match.snapshot().phase == "Active"
            end, "combat ready", 30)
            local snapshot = match.snapshot()
            round = snapshot.roundId
            table.clear(ground)
            table.clear(sequences)
            for _, player in Players:GetPlayers() do
                if snapshot.members[player.UserId].role == "Ground" then
                    table.insert(ground, player)
                end
            end
            table.sort(ground, function(left, right)
                return left.UserId < right.UserId
            end)
            assert(#ground == 2, "two Ground roles required")
        end
        local function use(player: Player, site: string, action: string, target: Vector3?)
            local snapshot = owned.launcher.snapshot(site)
            local sequence = (sequences[player] or 0) + 1
            sequences[player] = sequence
            local fields: Record = { launcherId = snapshot.launcherId, roundId = round, sequence = sequence }
            if target then
                fields.x, fields.y, fields.z = target.X, target.Y, target.Z
            end
            probe(player, "Intent", { remote = action, payload = fields })
        end
        local function observe(id: string, owner: number?)
            for _, player in ground do
                local detail = probe(player, "Observe", { id = id, owner = owner })
                table.insert(
                    observations,
                    { client = player.UserId, launcherId = id, owner = owner, detail = detail }
                )
            end
        end
        local function review(stage: string)
            if reviewSeconds > 0 then
                workspace:SetAttribute("P29ReviewStage", stage)
                task.wait(reviewSeconds)
                workspace:SetAttribute("P29ReviewStage", nil)
            end
        end
        local function anchor(site: string): BasePart
            local item = workspace.World.Battlefield.Anchors:FindFirstChild("Launcher" .. site)
            assert(item and item:IsA("BasePart"), "landmark anchor missing " .. site)
            return item
        end
        local function pickupModel(id: string): Model
            local found: Model? = nil
            for _, item in effects:GetChildren() do
                if item:IsA("Model") and item:GetAttribute("LauncherId") == id then
                    assert(not found, "duplicate visible pickup " .. id)
                    found = item
                end
            end
            return assert(found, "pickup representation missing " .. id)
        end
        local function pickup(player: Player, site: string): Tool
            use(player, site, "Pickup")
            waitFor(function()
                return owned.launcher.snapshot(site).ownerId == player.UserId
            end, "server acknowledged pickup at " .. site)
            probe(player, "Equip", {})
            local backpack = assert(player:FindFirstChildOfClass("Backpack"), "player inventory missing")
            local avatar = assert(player.Character, "carrier avatar missing")
            waitFor(function()
                return avatar:FindFirstChild("Rocket launcher") ~= nil
            end, "equipped Tool replicated to server")
            assert(not backpack:FindFirstChild("Rocket launcher"), "duplicate carried launcher")
            local tool = avatar:FindFirstChild("Rocket launcher")
            assert(tool and tool:IsA("Tool"), "equipped native Tool missing")
            return tool
        end
        local function loadedSites(previous: { Model }?): { Model }
            local result: { Model } = {}
            for _, site in SITES do
                local snapshot = owned.launcher.snapshot(site)
                local model = pickupModel(snapshot.launcherId)
                local support = workspace:Raycast(
                    anchor(site).Position,
                    -Vector3.yAxis * 6,
                    Geometry.parameters(workspace.World.Battlefield)
                )
                assert(support, "missing support at " .. site)
                local contact = marker(model, "GroundContact")
                local floorGap = (contact.WorldPosition - support.Position):Dot(support.Normal)
                assert(math.abs(floorGap - 0.012) < 0.004, "pickup floor contact at " .. site)
                assert(
                    contact.WorldCFrame.UpVector:Dot(support.Normal) >= 0.999,
                    "pickup not aligned to floor"
                )
                local bounds, size = model:GetBoundingBox()
                local axis = bounds:VectorToObjectSpace(support.Normal)
                local radius = (
                    math.abs(axis.X) * size.X
                    + math.abs(axis.Y) * size.Y
                    + math.abs(axis.Z) * size.Z
                ) / 2
                local bottomGap = (bounds.Position - support.Position):Dot(support.Normal) - radius
                assert(
                    math.abs(bottomGap - floorGap) < 0.004,
                    "launcher art penetrates the floor at " .. site
                )
                assert(
                    (model:GetPivot().Position - anchor(site).Position).Magnitude < 0.001,
                    "model altered the gameplay anchor " .. site
                )
                assert(
                    snapshot.state == "Available" and snapshot.readyAt == 0 and snapshot.ammo == 1,
                    "pickup not pristine at " .. site
                )
                if previous then
                    assert(not table.find(previous, model), "old pickup reused at replay")
                end
                observe(snapshot.launcherId, 0)
                table.insert(observations, {
                    site = site,
                    floorGapStuds = floorGap,
                    artGapStuds = bottomGap,
                    support = support.Instance.Name,
                })
                table.insert(result, model)
                if not previous and reviewSeconds > 0 then
                    CombatFixture.pose(owned, ground[1], anchor(site).Position + Vector3.new(0, 0, 4))
                    review("pickup-" .. site)
                end
            end
            assert(
                owned.launcher.resources().representations == 4,
                "unexpected launcher representation count"
            )
            return result
        end
        local firstPickups: { Model } = {}
        check("A1 four native models rest on their existing site floors", function()
            deploy()
            firstPickups = loadedSites(nil)
        end)
        local first, second = ground[1], ground[2]
        local firstTool: Tool? = nil
        local secondTool: Tool? = nil
        local readyAt = 0
        local id = owned.launcher.snapshot("Radar").launcherId
        local radar = anchor("Radar").Position
        check("A2 both Ground clients see held art and real muzzle-aligned fire", function()
            CombatFixture.pose(owned, first, radar + Vector3.xAxis * 1.6)
            CombatFixture.pose(owned, second, radar - Vector3.xAxis * 1.6)
            local tool = pickup(first, "Radar")
            firstTool = tool
            observe(id, first.UserId)
            local avatar = assert(first.Character, "missing carrier avatar")
            local rightGrip = avatar:FindFirstChild("RightGrip", true)
            assert(
                rightGrip
                    and rightGrip:IsA("JointInstance")
                    and rightGrip.Part0
                    and rightGrip.Part1 == handle(tool),
                "native right grip did not bind the authored Handle"
            )
            local grip = marker(tool, "CarryGrip")
            local gripError = (grip.WorldPosition - (rightGrip.Part0.CFrame * rightGrip.C0).Position).Magnitude
            assert(gripError < 0.15, "native carry marker moved away from the hand")
            table.insert(observations, { gripErrorStuds = gripError, body = rightGrip.Part0.Name })
            review("equipped-Radar")
            local aircraft = owned.aircraft.position()
            CombatFixture.pose(
                owned,
                first,
                Vector3.new(aircraft.X, 0, aircraft.Z).Unit * 330 + Vector3.yAxis * 45
            )
            local head = avatar:FindFirstChild("Head")
            assert(head and head:IsA("BasePart"), "carrier Head missing")
            local firedPart: Part? = nil
            local launch: CFrame? = nil
            flightListener = effects.ChildAdded:Connect(function(item: Instance)
                if item:IsA("Part") and item.Name == "Rocket" then
                    firedPart, launch = item, item.CFrame
                end
            end)
            local epoch = ReplicatedStorage.AircraftState:GetAttribute("EpochSeconds")
            assert(type(epoch) == "number", "aircraft epoch missing")
            local sentAt = workspace:GetServerTimeNow()
            local elapsed = sentAt - epoch
            local seconds, target = 0.5, Vector3.zero
            for _ = 1, 5 do
                target = owned.aircraft.sample(elapsed + seconds + 0.1).Position
                seconds = (target - head.Position).Magnitude / LauncherService.speedStudsPerSecond
            end
            use(first, "Radar", "Fire", target)
            waitFor(function()
                return launch ~= nil and owned.launcher.snapshot("Radar").ammo == 0
            end, "real rocket accepted")
            local start = assert(launch, "rocket launch appeared without a pose")
            local muzzle = marker(tool, "Muzzle").WorldPosition
            local originError = (start.Position - muzzle).Magnitude
            assert(originError < 0.3, "rocket visual did not start on the authored muzzle")
            assert((start.Position - head.Position).Magnitude > 0.2, "rocket effect started at the head")
            assert(
                start.LookVector:Dot((target - head.Position).Unit) >= 0.9999,
                "rocket visual deviated from the validated target path"
            )
            local projectile = assert(firedPart, "rocket projectile missing")
            assert(
                projectile:FindFirstChild("Exhaust") and not projectile.CanQuery and not projectile.CanCollide,
                "rocket presentation gained gameplay collision or lost its trail"
            )
            readyAt = owned.launcher.snapshot("Radar").readyAt
            assert(readyAt - sentAt >= 15 and readyAt - sentAt < 15.75, "launcher reload changed")
            local shot = assert(decoded(state, "LastShot"), "server shot publication missing")
            waitFor(function()
                local impact = decoded(state, "LastImpact")
                return impact ~= nil and impact.shotId == shot.shotId
            end, "native aircraft impact", 6)
            local impact = assert(decoded(state, "LastImpact"), "rocket impact missing")
            assert(
                impact.aircraftHit == true and ReplicatedStorage.AircraftState:GetAttribute("Health") == 1850,
                "unchanged rocket sweep did not damage the aircraft exactly once"
            )
            for _, site in { "Depot", "Hangar", "Seedship" } do
                local other = owned.launcher.snapshot(site)
                assert(other.ammo == 1 and other.readyAt == 0, site .. " shared Radar readiness")
            end
            table.insert(observations, { muzzleErrorStuds = originError, impact = impact, readyAt = readyAt })
            CombatFixture.pose(owned, first, radar + Vector3.xAxis * 1.6)
        end)
        check("A2 drop and teammate handoff retain one cooled launcher", function()
            use(first, "Radar", "Drop")
            waitFor(function()
                return owned.launcher.snapshot("Radar").state == "Available"
            end, "cooldown drop")
            assert(owned.launcher.snapshot("Radar").readyAt == readyAt, "drop reset readiness")
            assert(firstTool and not firstTool.Parent, "old held instance survived drop")
            observe(id, 0)
            local oldPickup = pickupModel(id)
            local equipped = pickup(second, "Radar")
            secondTool = equipped
            assert(not oldPickup.Parent and equipped ~= firstTool, "handoff kept stale geometry")
            observe(id, second.UserId)
            assert(
                equipped:GetAttribute("ReloadUntil") == readyAt and equipped:GetAttribute("Ammo") == 0,
                "second carrier did not inherit the cooldown"
            )
            use(second, "Radar", "Fire", radar + Vector3.yAxis * 300)
            task.wait(0.2)
            assert(
                owned.launcher.snapshot("Radar").readyAt == readyAt
                    and owned.launcher.resources().flights == 0,
                "second carrier fired during cooldown"
            )
        end)
        check("A2 carrier death drops one visible model for teammate recovery", function()
            local avatar = assert(second.Character, "second carrier missing")
            local body = assert(avatar:FindFirstChildOfClass("Humanoid"), "second Humanoid missing")
            body.Health = 0
            waitFor(function()
                return match.snapshot().members[second.UserId].life == "Eliminated"
                    and owned.launcher.snapshot("Radar").state == "Available"
            end, "death recovers launcher")
            assert(secondTool and not secondTool.Parent, "death left the old held model")
            assert(owned.launcher.snapshot("Radar").readyAt == readyAt, "death reset site deadline")
            observe(id, 0)
            CombatFixture.pose(
                owned,
                first,
                vector(owned.launcher.snapshot("Radar").position) + Vector3.yAxis * 2
            )
            firstTool = pickup(first, "Radar")
            observe(id, first.UserId)
            assert(
                ReplicatedStorage.AircraftState:GetAttribute("Health") == 1850,
                "death changed roster health"
            )
        end)
        check("A3 replay clears old equipment and restores the four loaded models", function()
            -- Leave a genuine, still-traveling shot for the terminal frame to clear.
            waitFor(function()
                return owned.launcher.snapshot("Radar").ammo == 1
            end, "recovered launcher finishes reloading", 17)
            local avatar = assert(first.Character, "recovery carrier missing")
            local head = avatar:FindFirstChild("Head")
            assert(head and head:IsA("BasePart"), "recovery carrier Head missing")
            use(first, "Radar", "Fire", head.Position + Vector3.yAxis * 600)
            waitFor(function()
                return owned.launcher.resources().flights == 1
            end, "live flight when ending round")
            assert(match.abort(round, "P29Replay"), "fixture round could not end")
            table.insert(completedRounds, round)
            waitFor(function()
                return match.snapshot().phase == "Lobby"
            end, "end-of-round reset", 30)
            assert(
                firstTool and not firstTool.Parent and secondTool and not secondTool.Parent,
                "a previous round Tool survived"
            )
            assert(
                #effects:GetChildren() == 0
                    and state:GetAttribute("LastShot") == nil
                    and state:GetAttribute("LastImpact") == nil,
                "old launcher presentation survived lobby reset"
            )
            observe(id, nil)
            deploy()
            loadedSites(firstPickups)
            assert(match.abort(round, "P29Done"), "could not end replay round")
            table.insert(completedRounds, round)
        end)
    end)
    if not passed and (#cases == 0 or cases[#cases].passed) then
        table.insert(cases, { name = "Harness completion", passed = false, detail = tostring(failure) })
    end
    if flightListener then
        flightListener:Disconnect()
    end
    if runtime then
        runtime.stop()
    end
    listener:Disconnect()
    transport:Destroy()
    workspace:SetAttribute("P29ReviewStage", nil)
    local failures = 0
    for _, case in cases do
        failures += if case.passed then 0 else 1
    end
    local report = {
        suite = "P29-depot-launcher",
        environment = "Studio",
        actualClients = #clients,
        clientIds = clients,
        discovered = #cases,
        passed = #cases - failures,
        failed = failures,
        skipped = 0,
        completedRounds = completedRounds,
        cases = cases,
        observations = observations,
        smoke = { server = decoded(workspace, "ServerTestReport"), clients = smoke },
    }
    workspace:SetAttribute("P29Report", HttpService:JSONEncode(report))
    if automated then
        StudioTestService:EndTest(report)
    end
end

return Harness
