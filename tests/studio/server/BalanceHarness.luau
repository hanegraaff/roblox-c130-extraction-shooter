--!strict
--[=[
    P26 local Studio acceptance. Two real clients drive the release admin and
    weapon remotes. Only persistence, principal identity and fixture contacts
    are injected. Manual panel preview uses the same adapter without automation.
]=]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local StudioTestService = game:GetService("StudioTestService")
local Server = game:GetService("ServerScriptService").Server
local Runtime = require(Server.GameRuntime)
local Match = require(Server.MatchRuntime)
local Balance = require(Server.BalanceRuntime)
local Schema = require(ReplicatedStorage.Shared.BalanceSchema)
local CombatChecks = require(script.Parent.BalanceCombatChecks)
local Harness = {}

type Bag = { [string]: unknown }
type Case = { name: string, passed: boolean, detail: string? }
type View = {
    revision: number,
    activeRevision: number,
    settings: Schema.Values,
    owner: boolean,
    groundCount: number,
}
type Ticket = { player: Player, ready: boolean, ok: boolean, value: unknown }
local function waitFor(check: () -> boolean, what: string, limit: number?)
    local untilTime = os.clock() + (limit or 15)
    while not check() do
        assert(os.clock() < untilTime, "P26 timeout: " .. what)
        task.wait(0.08)
    end
end

-- Start one real GameRuntime with isolated in-memory storage. The first client
-- is fixture principal 1 (owner); each other client gets a positive test ID.
local function start(owner: Player, minimum: number): Runtime.Controller
    local principals: { [number]: number } = { [owner.UserId] = 1 }
    local serial = 1
    local stored: unknown = nil
    local deps: Balance.Dependencies = {
        ownerId = function()
            return 1
        end,
        actorId = function(player: Player): number
            local id = principals[player.UserId]
            if not id then
                serial += 1
                id = serial
                principals[player.UserId] = id
            end
            player:SetAttribute("BalanceFixtureUserId", id)
            return id
        end,
        read = function(): unknown
            return stored
        end,
        update = function(change: (unknown) -> unknown): unknown
            local result = change(stored)
            if result ~= nil then
                stored = result
            end
            return result
        end,
        subscribe = function(_receive: (number) -> ()): () -> ()
            return function() end
        end,
        notify = function(_revision: number) end,
    }
    local settings = table.clone(Match.defaults)
    settings.minimumPlayers = minimum
    settings.lobbySeconds = 1
    settings.resultsSeconds = 1
    settings.scatterSeconds = 3
    local runtime, err = Runtime.start(settings, nil, deps)
    return assert(runtime, err)
end

-- Local Play / Server & Clients only. A solo user can configure settings before
-- additional clients arrive; the test datastore is discarded when Play ends.
function Harness.preview()
    assert(RunService:IsStudio(), "local Studio only")
    local owner = assert(Players:GetPlayers()[1], "start the preview with a player")
    local runtime = start(owner, 3)
    game:BindToClose(runtime.stop)
    workspace:SetAttribute(
        "P26PanelPreview",
        "Use the Balance button. Grant testers their BalanceFixtureUserId."
    )
end

-- SDK calls return the same structured report the manual route leaves in Workspace.
function Harness.run(automated: boolean)
    assert(RunService:IsStudio(), "local Studio only")
    local bridge = Instance.new("RemoteEvent")
    bridge.Name = "P26Harness"
    local ready: { [Player]: boolean } = {}
    local pending: { [number]: Ticket } = {}
    local sequence = 0
    local connection = bridge.OnServerEvent:Connect(
        function(player: Player, token: unknown, ok: unknown, value: unknown)
            if token == 0 and ok == true then
                ready[player] = true
                return
            end
            if type(token) == "number" then
                local ticket = pending[token]
                if ticket and ticket.player == player and not ticket.ready then
                    ticket.value = value
                    ticket.ok = ok == true
                    ticket.ready = true
                end
            end
        end
    )
    bridge.Parent = ReplicatedStorage
    local function probe(player: Player, kind: string, body: Bag): unknown
        sequence += 1
        local token = sequence
        local ticket: Ticket = { player = player, ready = false, ok = false, value = nil }
        pending[token] = ticket
        bridge:FireClient(player, token, kind, body)
        waitFor(function()
            return ticket.ready
        end, kind .. " reply")
        pending[token] = nil
        assert(ticket.ok, tostring(ticket.value))
        return ticket.value
    end
    local function request(player: Player, body: Bag): { ok: boolean, error: string?, view: View? }
        -- Remain within the release transport's per-user budget throughout the suite.
        task.wait(2.1)
        return probe(player, "Request", body) :: { ok: boolean, error: string?, view: View? }
    end
    local function accept(player: Player, body: Bag): View
        local reply = request(player, body)
        assert(reply.ok, reply.error)
        return assert(reply.view, "missing successful admin response")
    end
    local function observe(player: Player): Bag
        return probe(player, "Observe", {}) :: Bag
    end
    local cases: { Case } = {}
    local function check(name: string, fn: () -> ())
        local ok, why = pcall(function()
            fn()
            return true
        end)
        table.insert(cases, { name = name, passed = ok, detail = if ok then nil else tostring(why) })
        assert(ok, tostring(why))
    end
    local owned: Runtime.Controller? = nil
    local clients = 0
    local ok, failure = pcall(function()
        waitFor(function()
            return #Players:GetPlayers() == 2
        end, "two actual clients", 90)
        local pair = Players:GetPlayers()
        table.sort(pair, function(a, b)
            return a.UserId < b.UserId
        end)
        local owner, tester = pair[1], pair[2]
        clients = #pair
        local runtime = start(owner, 3)
        owned = runtime
        -- Client smoke observes the normal RoundState and a protected avatar.
        -- Its acknowledgements can only arrive after the runtime has started.
        waitFor(function()
            return ready[owner] == true and ready[tester] == true
        end, "both actual clients finished smoke", 90)
        local state = assert(ReplicatedStorage:FindFirstChild("RoundState"), "round state missing")
        local function both(predicate: (Bag) -> boolean, why: string)
            waitFor(function()
                return predicate(observe(owner)) and predicate(observe(tester))
            end, why)
        end
        local values = table.clone(Schema.defaults)
        values.minimumPlayers, values.roundDuration, values.intermission = 2, 90, 5
        values.groundHealth, values.aircraftHealthPerGround = 123, 777
        values.gauCadence, values.gauReload, values.gauDamage = 0.33, 2.4, 35
        values.m102Damage, values.m102Reload, values.m102Cadence = 75, 4, 0.6
        values.m7Damage, values.m7Cadence, values.m7Reload = 13, 0.27, 1.7
        values.rocketDamage, values.launcherReload = 270, 6
        values.medkitHeal, values.medkitSingleUse, values.medkitRespawn, values.panelDamage =
            31, false, 9, "Low"
        local revision = 0
        local function apply(player: Player, name: string)
            local saved =
                accept(player, { action = "save", revision = revision, name = name, settings = values })
            local live = accept(player, { action = "apply", revision = saved.revision, name = name })
            local wanted = (values :: unknown) :: Bag
            local actual = (live.settings :: unknown) :: Bag
            for _, field in Schema.fields do
                assert(actual[field.key] == wanted[field.key], "round-trip mismatch: " .. field.label)
            end
            revision = live.revision
            assert(live.activeRevision == revision, "apply missed live revision")
        end
        check("A1 Owner and ordinary player have different access in the waiting lobby", function()
            waitFor(function()
                return owner:GetAttribute("BalanceAdminAccess") == true
            end, "owner access")
            local initial = accept(owner, { action = "read" })
            revision = initial.revision
            assert(initial.owner and initial.groundCount == 1, "incorrect owner or lobby preview")
            assert(not request(tester, { action = "read" }).ok, "ordinary client could read presets")
            assert(
                observe(owner).panelVisible and not observe(tester).panelVisible,
                "incorrect button visibility"
            )
            assert(
                state:GetAttribute("MinimumPlayers") == 3 and state:GetAttribute("Phase") == "Lobby",
                "lobby gate changed"
            )
        end)
        check("A1 A2 A4 Trusted tester lowers waiting minimum and deploys the saved preset", function()
            local v = accept(owner, { action = "grant", revision = revision, userId = 2 })
            revision = v.revision
            local trusted = accept(tester, { action = "read" })
            assert(not trusted.owner and trusted.revision == revision, "tester grant missing")
            apply(tester, "QA first")
            waitFor(function()
                return state:GetAttribute("Phase") == "Active"
            end, "first deployment", 55)
            local left = (state:GetAttribute("DeadlineSeconds") :: number) - workspace:GetServerTimeNow()
            assert(left > 85 and left <= 90, "combat clock did not start at arrival")
            both(function(d)
                return d.phase == "Active"
                    and d.aircraftHP == 777
                    and d.revision == revision
                    and (d.role ~= "Ground" or d.groundHP == 123)
            end, "locked client health")
        end)
        local ctx = {
            runtime = runtime,
            owner = owner,
            tester = tester,
            probe = probe,
            waitFor = waitFor,
            values = values,
        }
        check("A2 Low panel damage keeps interrupted credit and replicates openings", function()
            CombatChecks.panels(ctx)
        end)
        check("A2 A5 Four tuned weapons change damage, cooldowns, held tools and both health HUDs", function()
            CombatChecks.weapons(ctx)
        end)
        check("A2 A4 Change settings during combat and intermission; both clients agree on replay", function()
            local deadline = state:GetAttribute("DeadlineSeconds")
            values.minimumPlayers, values.groundHealth, values.aircraftHealthPerGround = 3, 193, 901
            values.panelDamage, values.intermission = "High", 30
            apply(owner, "QA next")
            assert(state:GetAttribute("DeadlineSeconds") == deadline, "ongoing combat deadline changed")
            both(function(d)
                return d.aircraftHP == 777 and (d.role ~= "Ground" or d.groundHP == 123)
            end, "combat settings stay locked")
            local ground = if owner:GetAttribute("Role") == "Ground" then owner else tester
            local character = assert(ground.Character, "Ground body missing")
            assert(character:FindFirstChildOfClass("Humanoid"), "Ground Humanoid missing").Health = 0
            waitFor(function()
                return (state:GetAttribute("IntermissionUntil") :: number) > workspace:GetServerTimeNow()
            end, "committed result")
            local untilTime = state:GetAttribute("IntermissionUntil") :: number
            local remaining = untilTime - workspace:GetServerTimeNow()
            assert(remaining > 27 and remaining <= 30, "new intermission ignored")
            both(function(d)
                return d.intermission == untilTime
            end, "shared countdown")
            values.minimumPlayers, values.intermission = 2, 3
            apply(owner, "QA replay")
            assert(state:GetAttribute("IntermissionUntil") == untilTime, "ongoing intermission changed")
            waitFor(function()
                return state:GetAttribute("Phase") == "Active"
            end, "second active round", 65)
            assert(workspace:GetServerTimeNow() >= untilTime, "replay started early")
            both(function(d)
                return d.aircraftHP == 901
                    and (d.role ~= "Ground" or d.groundHP == 193)
                    and d.revision == revision
            end, "replay settings")
        end)
        check("A5 High and Medium panel settings change native damage after replay", function()
            CombatChecks.panels(ctx)
            values.panelDamage = "Medium"
            values.intermission = 2
            apply(owner, "QA medium")
            local prior = runtime.rounds.match.snapshot().roundId
            assert(runtime.rounds.match.abort(prior, "P26NextTier"), "fixture replay rejected")
            waitFor(function()
                local match = runtime.rounds.match.snapshot()
                return match.roundId > prior and match.phase == "Active"
            end, "third tier deployment", 45)
            CombatChecks.panels(ctx)
        end)
    end)
    if not ok and (#cases == 0 or cases[#cases].passed) then
        table.insert(cases, { name = "P26 harness", passed = false, detail = tostring(failure) })
    end
    connection:Disconnect()
    bridge:Destroy()
    if owned then
        owned.stop()
    end
    local passed = 0
    for _, case in cases do
        if case.passed then
            passed += 1
        end
    end
    local report = {
        suite = "P26-multiplayer",
        initialClientCount = clients,
        discovered = #cases,
        passed = passed,
        failed = #cases - passed,
        skipped = 0,
        cases = cases,
    }
    workspace:SetAttribute("P26MultiplayerReport", HttpService:JSONEncode(report))
    if automated then
        StudioTestService:EndTest(report)
    end
end
return Harness
