--!strict
--[=[
    P30 harness. Three actual Studio clients exercise the production runtime,
    native prompts and owner panel across two rounds. Fixture warps only place
    the actors at the starts of short walks. No fixture applies healing or
    consumes a site. Balance storage exists only in the isolated local place.
]=]
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StudioTestService = game:GetService("StudioTestService")
local Server = game:GetService("ServerScriptService").Server
local BalanceRecord = require(Server.BalanceRecord)
local BalanceRuntime = require(Server.BalanceRuntime)
local GameRuntime = require(Server.GameRuntime)
local RoleService = require(Server.RoleService)
local Schema = require(ReplicatedStorage.Shared.BalanceSchema)
local Harness = {}

local sites = { "MedkitSandbreak", "MedkitHangar", "MedkitRadar", "MedkitDepot", "MedkitSeedship" }
local originalHeal, editedHeal = 25, 43
type Fields = { [string]: unknown }
type Case = { name: string, passed: boolean, failure: string? }
type Reply = { player: Player, response: string?, ok: boolean? }
type Observation = {
    site: string,
    roundId: number?,
    floorGap: number?,
    userId: number?,
    walkedStuds: number?,
    serverRangeStuds: number?,
    healed: number?,
    feedback: string?,
    touch: boolean?,
}

local function waitFor(predicate: () -> boolean, description: string, timeout: number?)
    local deadline = os.clock() + (timeout or 10)
    repeat
        if predicate() then
            return
        end
        task.wait()
    until os.clock() >= deadline
    error("P30 server did not observe " .. description)
end

local function modelAt(site: string): Model
    local kit = workspace.Medkits:FindFirstChild(site)
    assert(kit and kit:IsA("Model"), "P30 medkit missing at " .. site)
    return kit
end

local function humanoid(player: Player): Humanoid
    local character = assert(player.Character, "P30 test avatar missing")
    return assert(character:FindFirstChildOfClass("Humanoid"), "P30 Humanoid missing")
end

local function solidQueries(): RaycastParams
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = { workspace.World.Battlefield, workspace.Terrain }
    params.RespectCanCollide = true
    params.IgnoreWater = true
    return params
end

-- Runs the full multiplayer fixture. Set touchReview to have the operator of
-- the test tap the Hangar prompt instead of the programmatic native activation.
function Harness.run(automated: boolean, touchReview: boolean)
    assert(game.PlaceId == 0 and game.GameId == 0, "P30 requires the separate local test document")
    local cases: { Case } = {}
    local observations: { Observation } = {}
    local completedRounds: { number } = {}
    local clients: { number } = {}
    local smoke: { [string]: Fields } = {}
    local pending: { [number]: Reply } = {}
    local serial = 0
    local owned: GameRuntime.Controller? = nil
    local transport = Instance.new("RemoteEvent")
    transport.Name = "P30Harness"
    local listener = transport.OnServerEvent:Connect(
        function(player: Player, token: unknown, ok: unknown, response: unknown)
            if type(token) ~= "number" or type(response) ~= "string" or #response > 4096 then
                return
            end
            if token == 0 and ok == true then
                local report = HttpService:JSONDecode(response)
                if type(report) == "table" and report.userId == player.UserId then
                    smoke[tostring(player.UserId)] = report
                end
            else
                local reply = pending[token]
                if reply and reply.player == player and reply.ok == nil then
                    reply.ok, reply.response = ok == true, response
                end
            end
        end
    )
    local function send(player: Player, action: string, fields: Fields): number
        serial += 1
        local token = serial
        pending[token] = { player = player }
        transport:FireClient(player, token, action, fields)
        return token
    end
    local function receive(token: number): unknown
        local reply = pending[token]
        waitFor(function()
            return reply.ok ~= nil
        end, "client reply from " .. reply.player.Name)
        pending[token] = nil
        assert(reply.ok == true and reply.response, reply.response)
        return HttpService:JSONDecode(reply.response)
    end
    local function probe(player: Player, action: string, fields: Fields): unknown
        return receive(send(player, action, fields))
    end
    local function check(name: string, callback: () -> ())
        workspace:SetAttribute("P30Stage", name)
        local ok, failure = pcall(function()
            callback()
            return true
        end)
        table.insert(cases, { name = name, passed = ok, failure = if not ok then tostring(failure) else nil })
        assert(ok, tostring(failure))
    end

    local passed, errorMessage = pcall(function()
        waitFor(function()
            return #Players:GetPlayers() == 3
        end, "three actual clients", 60)
        local roster = Players:GetPlayers()
        local candidates: { RoleService.Candidate } = {}
        for _, player in roster do
            table.insert(clients, player.UserId)
            table.insert(candidates, { userId = player.UserId, waitedRounds = 0 })
        end
        local assigned = assert(RoleService.assign(candidates, 3, nil, 1))
        local owner = assert(Players:GetPlayerByUserId(assigned.groundIds[1]))
        local ally = assert(Players:GetPlayerByUserId(assigned.groundIds[2]))
        local gunship = assert(Players:GetPlayerByUserId(assigned.operatorId))
        local initial = BalanceRecord.initial()
        local values = table.clone(Schema.defaults)
        values.minimumPlayers, values.roundDuration, values.intermission = 3, 180, 3
        values.medkitHeal, values.medkitSingleUse, values.medkitRespawn = originalHeal, false, 1
        initial.revision, initial.activeRevision, initial.activeName = 1, 1, "P30 Trial"
        initial.settings, initial.presets[initial.activeName] = values, values
        local stored: unknown = initial
        local balance: BalanceRuntime.Dependencies = {
            ownerId = function(): number?
                return 1
            end,
            actorId = function(player: Player): number
                return if player == owner then 1 else math.abs(player.UserId) + 2
            end,
            read = function(): unknown
                return stored
            end,
            update = function(transform: (unknown) -> unknown): unknown
                local result = transform(stored)
                if result ~= nil then
                    stored = result
                end
                return result
            end,
            subscribe = function(_receive: (number) -> ())
                return function() end
            end,
            notify = function(_revision: number) end,
        }
        local runtime, reason = GameRuntime.start({
            automaticDeployment = false,
            minimumPlayers = 3,
            durationSeconds = 180,
            deploymentSeconds = 25,
            lobbySeconds = 0,
            scatterSeconds = 3,
            resultsSeconds = 0.5,
            seed = 1,
        }, nil, balance)
        assert(runtime, reason)
        owned = runtime
        local match = runtime.rounds.match
        transport.Parent = ReplicatedStorage
        local activeRound = 0
        local function deploy()
            waitFor(function()
                return match.deploy()
            end, "fixture deployment", 25)
            waitFor(function()
                return match.snapshot().phase == "Active" and #workspace.Medkits:GetChildren() == #sites
            end, "active round and all five kits", 30)
            activeRound = match.snapshot().roundId
        end
        local function verifyFloor(site: string)
            local kit = modelAt(site)
            local pose, bounds, size = kit:GetPivot(), kit:GetBoundingBox()
            local floor =
                workspace:Raycast(pose.Position + Vector3.yAxis * 2, -Vector3.yAxis * 4, solidQueries())
            assert(floor and floor.Normal.Y >= 0.95, "case lacks level support at " .. site)
            local floorGap = bounds.Position.Y - size.Y / 2 - floor.Position.Y
            assert(floorGap >= 0.009 and floorGap <= 0.027, "wrong prop floor contact at " .. site)
            assert(
                math.max(size.X, size.Z) > 2 and size.Y > 1.6 and math.min(size.X, size.Z) > 1,
                "wrong prop bounds at " .. site
            )
            table.insert(
                observations,
                { site = site, roundId = activeRound, floorGap = floorGap } :: Observation
            )
        end
        local function approach(player: Player, site: string, side: number?, outside: boolean?)
            local kit = modelAt(site)
            local pose = kit:GetPivot()
            local avatar = assert(player.Character, "Ground avatar unavailable at approach")
            local human = humanoid(player)
            local root = assert(human.RootPart, "Ground root unavailable at approach")
            local function point(distance: number): Vector3
                local sample = pose.Position + pose.LookVector * distance + pose.RightVector * (side or 0)
                local floor =
                    workspace:Raycast(sample + Vector3.yAxis * 2.5, -Vector3.yAxis * 7, solidQueries())
                assert(floor and floor.Normal.Y >= 0.8, "approach lacks support at " .. site)
                return floor.Position + Vector3.yAxis * (human.HipHeight + root.Size.Y / 2 + 0.12)
            end
            local start = point(if outside then -5 else 11.5)
            local look = Vector3.new(pose.X, start.Y, pose.Z)
            avatar:PivotTo(CFrame.lookAt(start, look))
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            assert(runtime.groundCombat.trustCorrection(player), "fixture placement not trusted")
            if not outside then
                local goal = point(4.2)
                local walked = probe(player, "Walk", { start = start, goal = goal })
                assert(type(walked) == "number" and walked >= 3.5, "client did not walk to " .. site)
                local target = kit:FindFirstChild("InteractionPoint")
                assert(target and target:IsA("BasePart"), "server interaction point unavailable at " .. site)
                -- The client's walk reply can arrive ahead of its character pose.
                -- Wait for the server to observe the approach inside the eight-stud reach.
                waitFor(function()
                    return (root.Position - target.Position).Magnitude <= 7
                end, "server-observed approach inside medkit reach at " .. site)
                table.insert(
                    observations,
                    {
                        site = site,
                        userId = player.UserId,
                        walkedStuds = walked,
                        serverRangeStuds = (root.Position - target.Position).Magnitude,
                    } :: Observation
                )
            end
        end
        local function replicas(site: string, first: Player, other: Player, expected: number)
            local feedbackUntil = humanoid(first):GetAttribute("MedkitHealUntil")
            assert(type(feedbackUntil) == "number", "server heal feedback deadline missing")
            local witness = probe(first, "Replica", {
                site = site,
                present = false,
                expectedHeal = expected,
                feedbackUntil = feedbackUntil,
            }) :: Fields
            local partner = probe(other, "Replica", { site = site, present = false }) :: Fields
            assert(witness.present == false and partner.present == false, "kit removal did not replicate")
            assert(witness.heal == expected, "the recipient's restored HP did not replicate")
            assert(
                type(witness.health) == "number" and witness.health > expected,
                "the recipient's health did not replicate"
            )
            local suffix = string.format("  +%g HP", math.round(expected * 10) / 10)
            assert(
                type(witness.feedback) == "string" and witness.feedback:sub(-#suffix) == suffix,
                "the local +HP label showed the wrong amount"
            )
            if touchReview and site == "MedkitHangar" and activeRound == 1 then
                assert(witness.touch == true, "Hangar pickup was not activated from a shown phone prompt")
            end
            table.insert(
                observations,
                {
                    site = site,
                    healed = expected,
                    userId = first.UserId,
                    feedback = witness.feedback,
                    touch = witness.touch == true,
                } :: Observation
            )
        end
        local function use(
            site: string,
            player: Player,
            other: Player,
            before: number,
            expected: number,
            capped: boolean?
        )
            approach(player, site)
            local body = humanoid(player)
            body.Health = before
            if touchReview and site == "MedkitHangar" and activeRound == 1 then
                workspace:SetAttribute("P30ReviewStage", "Tap Use at " .. site)
                workspace:SetAttribute("P30TouchUserId", player.UserId)
            else
                assert(
                    probe(player, "Activate", { site = site, requireShown = true }) == true,
                    "native prompt was not visible for " .. site
                )
            end
            waitFor(function()
                return workspace.Medkits:FindFirstChild(site) == nil
            end, "native prompt consumed " .. site, if touchReview then 40 else nil)
            workspace:SetAttribute("P30ReviewStage", nil)
            local delta = body:GetAttribute("MedkitHealAmount")
            assert(type(delta) == "number", "server did not credit healing")
            if capped then
                assert(
                    body.Health == body.MaxHealth and delta > 0 and delta <= expected,
                    "heal exceeded maximum"
                )
            else
                assert(
                    delta == expected and body.Health >= before + expected,
                    "server applied the wrong healing amount"
                )
            end
            replicas(site, player, other, delta)
        end

        check("Three actual clients passed smoke and loaded five supported kits", function()
            waitFor(function()
                for _, player in roster do
                    if not smoke[tostring(player.UserId)] then
                        return false
                    end
                end
                return true
            end, "three client smoke reports", 60)
            for _, report in smoke do
                assert(
                    report.passed == report.discovered
                        and report.failed == 0
                        and report.skipped == 0
                        and report.errors == 0,
                    "a client smoke suite was incomplete"
                )
            end
            assert(#workspace.Medkits:GetChildren() == 0, "medkits appeared before deployment")
            deploy()
            for _, site in sites do
                verifyFloor(site)
                for _, player in { owner, ally } do
                    assert(
                        probe(player, "Replica", { site = site, present = true }) == activeRound,
                        "site generation did not replicate"
                    )
                end
            end
        end)
        check("A1 Full health and inaccessible attempts preserve the bunker kit", function()
            local site = sites[1]
            approach(owner, site)
            local body = humanoid(owner)
            body.Health = body.MaxHealth
            assert(
                probe(owner, "Activate", { site = site, requireShown = true }) == true,
                "full-health player did not see the prompt"
            )
            task.wait(0.15)
            assert(
                body.Health == body.MaxHealth and workspace.Medkits:FindFirstChild(site),
                "a full-health use changed health or consumed the kit"
            )
            approach(owner, site, nil, true)
            body.Health = 30
            probe(owner, "Activate", { site = site })
            probe(gunship, "Activate", { site = site })
            task.wait(0.15)
            assert(
                body:GetAttribute("MedkitHealAmount") == nil and workspace.Medkits:FindFirstChild(site),
                "an obstructed or distant use consumed the kit"
            )
        end)
        check("A1–A2 Nearby damage preserves the bunker kit and two contenders earn one heal", function()
            local site = sites[1]
            local kit = modelAt(site)
            local bed = kit:GetPivot()
            local hit = workspace:Raycast(bed.Position + Vector3.yAxis, -bed.LookVector * 8, solidQueries())
            assert(hit, "the bunker kit has no nearby cover to exercise")
            local panel = assert(runtime.destruction.identify(hit.Instance), "nearby cover is not registered")
            local time = workspace:GetServerTimeNow()
            assert(runtime.destruction.resolve({
                roundId = activeRound,
                shotId = 1,
                weapon = "M102",
                panelId = panel,
                firedAt = time,
            }))
            runtime.destruction.flush(time)
            local damaged = runtime.destruction.snapshot(panel)
            assert(damaged and damaged.appearance == "Total", "nearby cover did not reach Total")
            assert(modelAt(site) == kit, "kit vanished with adjacent cover")
            approach(owner, site, -1.4)
            approach(ally, site, 1.4)
            local firstBody, secondBody = humanoid(owner), humanoid(ally)
            firstBody.Health, secondBody.Health = 35, 35
            local stamp = workspace:GetServerTimeNow() + 0.5
            local one = send(owner, "Activate", { site = site, stamp = stamp, requireShown = true })
            local two = send(ally, "Activate", { site = site, stamp = stamp, requireShown = true })
            assert(
                receive(one) == true and receive(two) == true,
                "both contenders must see the native prompt"
            )
            waitFor(function()
                return kit.Parent == nil
            end, "contended kit spent")
            local firstWon = firstBody:GetAttribute("MedkitHealAmount") == originalHeal
            local secondWon = secondBody:GetAttribute("MedkitHealAmount") == originalHeal
            assert(firstWon ~= secondWon, "race produced zero or two heals")
            replicas(site, if firstWon then owner else ally, if firstWon then ally else owner, originalHeal)
        end)
        check("A2 Ground walks to the hangar, radar and depot to use the other cases", function()
            if touchReview then
                -- Leave enough missing health during the operated wait even
                -- when Roblox's ordinary avatar regeneration is enabled.
                use("MedkitHangar", ally, owner, 22, originalHeal)
                use("MedkitRadar", ally, owner, 92, 8, true)
            else
                use("MedkitHangar", ally, owner, 92, 8, true)
                use("MedkitRadar", ally, owner, 22, originalHeal)
            end
            use("MedkitDepot", ally, owner, 22, originalHeal)
            assert(
                workspace.Medkits:FindFirstChild(sites[1]) == nil,
                "legacy timed preset respawned a used kit"
            )
        end)
        check(
            "A2–A3 An eliminated owner edits healing and the surviving teammate gets the original Seedship amount",
            function()
                humanoid(owner).Health = 0
                waitFor(function()
                    local member = match.snapshot().members[owner.UserId]
                    return member ~= nil
                        and member.life == "Eliminated"
                        and match.snapshot().phase == "Active"
                end, "consumed owner life while ally remains")
                probe(owner, "EditHeal", { value = editedHeal })
                waitFor(function()
                    local record = BalanceRecord.decode(stored)
                    return record ~= nil
                        and record.settings.medkitHeal == editedHeal
                        and record.activeRevision == 2
                end, "real owner panel applied healing")
                assert(
                    ReplicatedStorage.RoundState:GetAttribute("BalanceRoundRevision") == 1,
                    "the applied edit changed the current round revision"
                )
                use("MedkitSeedship", ally, owner, 22, originalHeal)
                assert(#workspace.Medkits:GetChildren() == 0, "kit duplicated after five uses")
                assert(match.abort(activeRound, "P30Replay"))
                table.insert(completedRounds, activeRound)
            end
        )
        check("A2–A3 Next round recreates all five kits and uses the revised amount once", function()
            waitFor(function()
                return match.snapshot().phase == "Lobby"
            end, "post-result reset")
            assert(#workspace.Medkits:GetChildren() == 0, "kit survived round teardown")
            deploy()
            assert(
                activeRound == 2 and ReplicatedStorage.RoundState:GetAttribute("BalanceRoundRevision") == 2,
                "the replay did not capture the new preset"
            )
            local ground: { Player } = {}
            for _, player in roster do
                if match.snapshot().members[player.UserId].role == "Ground" then
                    table.insert(ground, player)
                end
            end
            assert(#ground == 2, "replay did not have two Ground players")
            for _, site in sites do
                for _, player in ground do
                    assert(
                        probe(player, "Replica", { site = site, present = true }) == activeRound,
                        "reset kit generation did not replicate"
                    )
                end
            end
            use(sites[1], ground[1], ground[2], 22, editedHeal)
            assert(#workspace.Medkits:GetChildren() == 4, "replay use consumed more than one kit")
            assert(match.abort(activeRound, "P30Complete"))
            waitFor(function()
                return #workspace.Medkits:GetChildren() == 0
            end, "terminal pickup cleanup")
            table.insert(completedRounds, activeRound)
        end)
        return true
    end)
    if not passed and (#cases == 0 or cases[#cases].passed) then
        table.insert(
            cases,
            { name = "P30 startup or completion", passed = false, failure = tostring(errorMessage) }
        )
    end
    if owned then
        owned.stop()
    end
    listener:Disconnect()
    transport:Destroy()
    workspace:SetAttribute("P30ReviewStage", nil)
    workspace:SetAttribute("P30TouchUserId", nil)
    local failures = 0
    for _, case in cases do
        failures += if case.passed then 0 else 1
    end
    local serverReport = workspace:GetAttribute("ServerTestReport")
    local report = {
        suite = "P30-medkits",
        environment = "Studio",
        actualClients = #clients,
        clientIds = clients,
        completedRounds = completedRounds,
        discovered = #cases,
        passed = #cases - failures,
        failed = failures,
        skipped = 0,
        cases = cases,
        observations = observations,
        touchReview = touchReview,
        smoke = {
            server = if type(serverReport) == "string" then HttpService:JSONDecode(serverReport) else nil,
            clients = smoke,
        },
    }
    workspace:SetAttribute("P30Report", HttpService:JSONEncode(report))
    if automated then
        StudioTestService:EndTest(report)
    end
end

return Harness
