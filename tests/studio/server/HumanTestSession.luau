--!strict
--[=[
    HumanTestSession: Studio test-mapping-only owner of manual test settings and restarts.
    Composes the actual GameRuntime and solo-preview controls. A chosen operator is
    selected through the normal seeded RoleService on a fresh runtime, never by client
    assignment or fabricated players. Owns its transport, listeners and restart task.
    Production mappings exclude this entire module and its settings/transport.
]=]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GameRuntime = require(game.ServerScriptService.Server.GameRuntime)
local RoleService = require(game.ServerScriptService.Server.RoleService)
local RateLimit = require(ReplicatedStorage.Shared.RateLimit)
local LocalTestControls = require(script.Parent.LocalTestControls)
local Session = {}

type Preference = { role: string, sequence: number, bucket: RateLimit.Bucket }
export type Controller = { stop: () -> (), request: (Player, unknown) -> (boolean, string?) }

-- Takes ownership of an already-started runtime. All callbacks are server-owned.
-- Settings apply to the next explicit start/reset, not the current round's deadline.
function Session.start(initial: GameRuntime.Controller): Controller
    assert(RunService:IsStudio(), "human test session requires Studio")
    assert(not ReplicatedStorage:FindFirstChild("StudioTestControls"), "test controls already owned")
    local runtime = initial
    local stopPreview = LocalTestControls.start(runtime.rounds)
    local running, busy = true, false
    local generation, durationSeconds = 1, 60
    local worker: thread? = nil
    local preferences: { [Player]: Preference } = {}
    local folder = Instance.new("Folder")
    folder.Name = "StudioTestControls"
    local remote = Instance.new("RemoteEvent")
    remote.Name = "Request"
    remote.Parent = folder
    local function publish()
        folder:SetAttribute("Generation", generation)
        folder:SetAttribute("RoundSeconds", durationSeconds)
        folder:SetAttribute("Busy", busy)
    end
    local function feedback(player: Player, message: string)
        player:SetAttribute("LocalTestFeedback", message)
    end
    local function add(player: Player)
        local bucket = RateLimit.new(6, 3, workspace:GetServerTimeNow())
        assert(bucket, "valid test request budget")
        preferences[player] = { role = "Auto", sequence = 0, bucket = bucket }
        player:SetAttribute("LocalTestRoleChoice", "Auto")
        feedback(player, "Solo Play previews the map. Real rounds need two clients.")
    end
    for _, player in Players:GetPlayers() do
        add(player)
    end
    local connections = {
        Players.PlayerAdded:Connect(add),
        Players.PlayerRemoving:Connect(function(player)
            preferences[player] = nil
        end),
    }
    -- Fresh runtimes have zero wait counters and no previous operator. Find a normal
    -- deterministic seed producing the requested assignment; never bypass roster rules.
    local function seedForRoster(): (number?, string?)
        local candidates: { RoleService.Candidate } = {}
        local chosen: number? = nil
        local automatic: { number } = {}
        for _, player in Players:GetPlayers() do
            local preference = preferences[player]
            table.insert(candidates, { userId = player.UserId, waitedRounds = 0 })
            local role = if preference then preference.role else "Auto"
            if role == "Gunship" then
                if chosen then
                    return nil, "Only one tester can choose Operator. Change one choice to Ground or Auto."
                end
                chosen = player.UserId
            elseif role == "Auto" then
                table.insert(automatic, player.UserId)
            end
        end
        if #candidates < 2 or #candidates > 10 then
            return nil, "A real round needs 2–10 clients. Use solo role preview with one client."
        end
        table.sort(automatic)
        chosen = chosen or automatic[1]
        if not chosen then
            return nil, "Choose one Operator or leave at least one tester on Auto."
        end
        for seed = 0, 99 do
            local assignment = RoleService.assign(candidates, 2, nil, seed)
            if assignment and assignment.operatorId == chosen then
                return seed, nil
            end
        end
        return nil, "No seeded assignment matched the current roster."
    end
    local function restart(player: Player, startRound: boolean, seed: number)
        busy = true
        publish()
        worker = task.spawn(function()
            local ok, reason = pcall(function()
                -- Use the real reset path to restore the owned pristine map before
                -- replacing a runtime which has entered a competitive round.
                local state = runtime.rounds.match.snapshot()
                if state.phase == "Active" or state.phase == "Deploying" then
                    runtime.rounds.match.abort(state.roundId, "HumanTestReset")
                end
                if runtime.rounds.match.snapshot().phase == "Results" then
                    runtime.rounds.match.beginReset()
                end
                local deadline = os.clock() + 30
                while
                    running
                    and runtime.rounds.match.snapshot().phase == "Resetting"
                    and os.clock() < deadline
                do
                    task.wait()
                end
                assert(runtime.rounds.match.snapshot().phase ~= "Resetting", "test map reset timed out")
                stopPreview()
                runtime.stop()
                while running and runtime.rounds.resources().spawnTasks > 0 and os.clock() < deadline do
                    task.wait()
                end
                if not running then
                    return false
                end
                assert(runtime.rounds.resources().spawnTasks == 0, "previous avatar loads did not drain")
                local fresh, startReason = GameRuntime.start({
                    automaticDeployment = false,
                    minimumPlayers = 2,
                    durationSeconds = durationSeconds,
                    lobbySeconds = 0,
                    deploymentSeconds = 25,
                    resultsSeconds = 3,
                    seed = seed,
                })
                assert(fresh, startReason)
                runtime = fresh
                generation += 1
                stopPreview = LocalTestControls.start(runtime.rounds)
                if startRound then
                    local deployed, deploymentReason = runtime.rounds.match.deploy()
                    assert(deployed, deploymentReason)
                end
                feedback(
                    player,
                    if startRound
                        then "Starting the chosen roles."
                        else "Test reset. Solo preview or lobby is ready."
                )
                return true
            end)
            if running then
                if not ok then
                    feedback(player, "Test restart failed: " .. tostring(reason))
                    warn("Human test restart failed: " .. tostring(reason))
                end
                busy = false
                publish()
            end
            worker = nil
        end)
    end
    local function request(player: Player, payload: unknown): (boolean, string?)
        local preference = preferences[player]
        if not running or not preference or player.Parent ~= Players then
            return false, "test session unavailable"
        end
        if not RateLimit.take(preference.bucket, workspace:GetServerTimeNow()) then
            return false, "Too many test requests; try again shortly."
        end
        if type(payload) ~= "table" then
            return false, "invalid test request"
        end
        local value = payload :: { [unknown]: unknown }
        for key in value do
            if key ~= "action" and key ~= "value" and key ~= "sequence" and key ~= "generation" then
                return false, "unknown test request field"
            end
        end
        local sequence = value.sequence
        if
            type(sequence) ~= "number"
            or sequence % 1 ~= 0
            or sequence < 1
            or sequence > 2147483647
            or sequence <= preference.sequence
            or value.generation ~= generation
        then
            return false, "stale or invalid test request"
        end
        if busy then
            return false, "A test restart is already running."
        end
        local action = value.action
        if action == "Role" then
            if value.value ~= "Auto" and value.value ~= "Ground" and value.value ~= "Gunship" then
                return false, "invalid role choice"
            end
            preference.role = value.value :: string
            player:SetAttribute("LocalTestRoleChoice", preference.role)
            feedback(player, "Role choice saved. Applies to solo preview or the next Start round.")
        elseif action == "Duration" then
            if value.value ~= 30 and value.value ~= 60 and value.value ~= 180 and value.value ~= 600 then
                return false, "invalid test duration"
            end
            durationSeconds = value.value :: number
            feedback(player, "Duration saved for the next round.")
            publish()
        elseif action == "Start" or action == "Reset" then
            if value.value ~= nil then
                return false, "unexpected test value"
            end
            local seed = 1
            if action == "Start" then
                local selected, rejection = seedForRoster()
                if not selected then
                    return false, rejection
                end
                seed = selected
            end
            restart(player, action == "Start", seed)
        elseif action == "Explore" or action == "Lobby" then
            if value.value ~= nil then
                return false, "unexpected test value"
            end
            local controls = game.ServerStorage:FindFirstChild("LocalTestControls")
            local command = if controls
                then controls:FindFirstChild(if action == "Explore" then "ExploreMap" else "ReturnToLobby")
                else nil
            if not command or not command:IsA("BindableFunction") then
                return false, "preview unavailable"
            end
            local accepted, rejection = command:Invoke()
            if not accepted then
                return false, rejection
            end
            feedback(
                player,
                if action == "Explore"
                    then "Solo role preview is ready."
                    else "Returned to the walkable lobby."
            )
        else
            return false, "invalid test action"
        end
        preference.sequence = sequence
        return true, nil
    end
    table.insert(
        connections,
        remote.OnServerEvent:Connect(function(player: Player, payload: unknown)
            local accepted, reason = request(player, payload)
            if not accepted then
                feedback(player, reason or "Test request rejected.")
            end
        end)
    )
    publish()
    folder.Parent = ReplicatedStorage
    return {
        request = request,
        stop = function()
            if not running then
                return
            end
            running = false
            if worker and worker ~= coroutine.running() and coroutine.status(worker) ~= "dead" then
                task.cancel(worker)
                worker = nil
            end
            for _, connection in connections do
                connection:Disconnect()
            end
            stopPreview()
            runtime.stop()
            folder:Destroy()
            for player in preferences do
                player:SetAttribute("LocalTestRoleChoice", nil)
                player:SetAttribute("LocalTestFeedback", nil)
            end
            table.clear(preferences)
        end,
    }
end

return Session
