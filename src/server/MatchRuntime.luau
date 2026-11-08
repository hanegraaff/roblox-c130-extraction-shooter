--!strict
--[=[
    MatchRuntime: server engine adapter for MatchService. Owns explicit character loads,
    death/listener generations, protected stations, teams, collision group and replicated
    round attributes. Depends on Players/RunService/PhysicsService and injected map owner.
    start/stop are nonyielding and idempotent. Character loads run in owned guarded tasks;
    stop invalidates them before disconnecting/destroying owned resources.
]=]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Teams = game:GetService("Teams")
local PhysicsService = game:GetService("PhysicsService")
local MatchService = require(script.Parent.MatchService)
local MapService = require(script.Parent.MapService)
local CharacterOwner = require(script.Parent.CharacterOwner)
local Config = require(ReplicatedStorage.Shared.Config)
local RateLimit = require(ReplicatedStorage.Shared.RateLimit)
local MatchRuntime = {}

-- Times are monotonic server-clock seconds. Test-only callers may shorten these settings.
export type Settings = {
    minimumPlayers: number,
    durationSeconds: number,
    lobbySeconds: number,
    deploymentSeconds: number,
    resultsSeconds: number,
    seed: number,
}
MatchRuntime.defaults = table.freeze({
    minimumPlayers = Config.defaults.minPlayers,
    durationSeconds = Config.defaults.roundDurationSeconds,
    lobbySeconds = 8,
    deploymentSeconds = 15,
    resultsSeconds = 5,
    seed = 1,
})
export type Controller = {
    start: () -> (boolean, string?),
    stop: () -> (),
    match: MatchService.Controller,
    resources: () -> { connections: number, spawnTasks: number },
}
type PlayerOwner = { characters: CharacterOwner.Controller, bucket: RateLimit.Bucket }

-- Creates an inactive adapter. Caller owns the supplied map; stop does not destroy it.
-- releaseLife is currently equipment cleanup only; launcher recovery is connected in P08.
function MatchRuntime.new(map: MapService.Controller, settings: Settings): Controller
    assert(
        settings.lobbySeconds >= 0 and settings.deploymentSeconds > 0 and settings.resultsSeconds >= 0,
        "invalid phase durations"
    )
    local running = false
    local folder: Folder? = nil
    local connections: { RBXScriptConnection } = {}
    local owners: { [Player]: PlayerOwner } = {}
    local drainingOwners: { CharacterOwner.Controller } = {}
    local restoringAutoLoads = false
    local ownedTeams: { Team } = {}
    local oldCharacterAutoLoads = Players.CharacterAutoLoads
    local phaseStarted = workspace:GetServerTimeNow()
    local phase = "Lobby"
    local lastRevision = -1
    local collisionOwned = false
    local match = MatchService.new(settings, {
        now = function()
            return workspace:GetServerTimeNow()
        end,
        releaseLife = function(id)
            local player = Players:GetPlayerByUserId(id)
            if player then
                local backpack = player:FindFirstChildOfClass("Backpack")
                if backpack then
                    backpack:ClearAllChildren()
                end
                if player.Character then
                    for _, item in player.Character:GetChildren() do
                        if item:IsA("Tool") then
                            item:Destroy()
                        end
                    end
                end
            end
        end,
    })
    local function disconnect(list: { RBXScriptConnection })
        for _, connection in list do
            connection:Disconnect()
        end
        table.clear(list)
    end
    local function retire(owner: CharacterOwner.Controller)
        owner.stop()
        if owner.resources().spawnTasks > 0 then
            table.insert(drainingOwners, owner)
        end
    end
    local function drainCount(): number
        local count = 0
        for index = #drainingOwners, 1, -1 do
            local pending = drainingOwners[index].resources().spawnTasks
            if pending == 0 then
                table.remove(drainingOwners, index)
            else
                count += pending
            end
        end
        return count
    end
    local function teamFor(role: string): Team?
        for _, team in ownedTeams do
            if team.Name == role then
                return team
            end
        end
        return nil
    end
    local function publish(state: MatchService.Snapshot)
        local status = folder
        if not status then
            return
        end
        status:SetAttribute("RoundId", state.roundId)
        status:SetAttribute("Phase", state.phase)
        status:SetAttribute("DeadlineSeconds", state.deadlineSeconds)
        status:SetAttribute("Winner", if state.result then state.result.winner else "")
        status:SetAttribute("Reason", if state.result then state.result.reason else "")
        status:SetAttribute("MinimumPlayers", settings.minimumPlayers)
        local alive = 0
        for _, member in state.members do
            if member.role == "Ground" and member.life == "Alive" then
                alive += 1
            end
        end
        status:SetAttribute("GroundAlive", alive)
        for player in owners do
            local member = state.members[player.UserId]
            local role = if member then member.role else "Waiting"
            local life = if member then member.life else "Waiting"
            player:SetAttribute("RoundId", state.roundId)
            player:SetAttribute("Role", role)
            local previousLife = player:GetAttribute("Life")
            player:SetAttribute("Life", life)
            if life == "Eliminated" and previousLife == "Alive" then
                owners[player].characters.clear()
            end
            player:SetAttribute("RoundRevision", state.revision)
            local team = teamFor(if role == "Ground" or role == "Gunship" then role else "Waiting")
            assert(team, "runtime teams missing")
            player.Team = team
        end
        -- Revision is written last as the presentation commit marker.
        status:SetAttribute("Revision", state.revision)
        lastRevision = state.revision
    end
    local function addPlayer(player: Player)
        if owners[player] then
            return
        end
        local bucket = RateLimit.new(4, 2, workspace:GetServerTimeNow())
        assert(bucket, "valid fixed remote budget")
        owners[player] = { characters = CharacterOwner.new(player, match), bucket = bucket }
        match.join(player.UserId)
        local state = match.snapshot()
        if state.phase == "Lobby" then
            owners[player].characters.request("Lobby", "Waiting", state.roundId)
        else
            owners[player].characters.clear()
        end
        publish(state)
    end
    local function applyPhase(state: MatchService.Snapshot)
        phase = state.phase
        phaseStarted = workspace:GetServerTimeNow()
        if state.phase == "Deploying" then
            local groundIndex = 0
            local ids: { number } = {}
            for id in state.members do
                table.insert(ids, id)
            end
            table.sort(ids)
            for _, id in ids do
                local member = state.members[id]
                local player = Players:GetPlayerByUserId(id)
                if player and member.role ~= "Spectator" then
                    local anchor = "Operator"
                    if member.role == "Ground" then
                        groundIndex += 1
                        anchor = string.format("Ground%02d", groundIndex)
                    end
                    owners[player].characters.request(anchor, member.role, state.roundId)
                end
            end
        elseif state.phase == "Lobby" then
            for player in owners do
                owners[player].characters.request("Lobby", "Waiting", state.roundId)
            end
        elseif state.phase == "Resetting" then
            for _, owner in owners do
                owner.characters.clear()
            end
            local ok, reason = map.rebuild()
            if not ok then
                warn("Round map reset failed: " .. tostring(reason))
                if folder then
                    folder:SetAttribute("ResetError", tostring(reason))
                end
                return
            end
            match.finishReset()
        end
    end
    local function tick()
        local state = match.snapshot()
        if state.phase ~= phase then
            applyPhase(state)
            state = match.snapshot()
        end
        local elapsed = workspace:GetServerTimeNow() - phaseStarted
        if state.phase == "Lobby" and elapsed >= settings.lobbySeconds then
            match.deploy()
        elseif state.phase == "Deploying" then
            local active = match.activate()
            if not active and elapsed >= settings.deploymentSeconds then
                match.abort(state.roundId, "DeploymentTimeout")
            end
        elseif state.phase == "Active" then
            match.step()
        elseif state.phase == "Results" and elapsed >= settings.resultsSeconds then
            match.beginReset()
        end
        state = match.snapshot()
        if state.phase ~= phase then
            applyPhase(state)
            state = match.snapshot()
        end
        if state.revision ~= lastRevision then
            publish(state)
        end
    end
    local function stop()
        if not running then
            return
        end
        running = false
        disconnect(connections)
        local state = match.snapshot()
        if state.phase == "Deploying" or state.phase == "Active" then
            match.abort(state.roundId, "RuntimeStopped")
        end
        if match.snapshot().phase == "Results" then
            match.beginReset()
        end
        if match.snapshot().phase == "Resetting" then
            match.finishReset()
        end
        for player, owner in owners do
            retire(owner.characters)
            match.leave(player.UserId)
            player.Neutral = true
            for _, key in { "RoundId", "Role", "Life", "RoundRevision" } do
                player:SetAttribute(key, nil)
            end
        end
        table.clear(owners)
        for _, team in ownedTeams do
            team:Destroy()
        end
        table.clear(ownedTeams)
        if folder then
            folder:Destroy()
            folder = nil
        end
        if collisionOwned then
            PhysicsService:UnregisterCollisionGroup("RoundCharacters")
            collisionOwned = false
        end
        if drainCount() == 0 then
            Players.CharacterAutoLoads = oldCharacterAutoLoads
        else
            -- A yielding engine load cannot be cancelled safely. Keep auto spawning
            -- disabled until all old loads release their leases; account for this
            -- teardown task and refuse a premature start instead of reporting zero.
            restoringAutoLoads = true
            task.spawn(function()
                while drainCount() > 0 do
                    task.wait()
                end
                if not ReplicatedStorage:FindFirstChild("RoundState") then
                    Players.CharacterAutoLoads = oldCharacterAutoLoads
                end
                restoringAutoLoads = false
            end)
        end
    end
    return {
        match = match,
        start = function()
            if running then
                return true, nil
            end
            if ReplicatedStorage:FindFirstChild("RoundState") then
                return false, "round runtime already owned"
            end
            if restoringAutoLoads or drainCount() > 0 then
                return false, "previous character loads are still draining"
            end
            for _, player in Players:GetPlayers() do
                if player:GetAttribute("RoundCharacterLoad") then
                    return false, "previous character loads are still draining"
                end
            end
            for _, name in { "Ground", "Gunship", "Waiting" } do
                if Teams:FindFirstChild(name) then
                    return false, "team name already owned: " .. name
                end
            end
            if PhysicsService:IsCollisionGroupRegistered("RoundCharacters") then
                return false, "character collision group already owned"
            end
            running = true
            oldCharacterAutoLoads = Players.CharacterAutoLoads
            Players.CharacterAutoLoads = false
            if not PhysicsService:IsCollisionGroupRegistered("RoundCharacters") then
                PhysicsService:RegisterCollisionGroup("RoundCharacters")
                collisionOwned = true
            end
            PhysicsService:CollisionGroupSetCollidable("RoundCharacters", "RoundCharacters", false)
            for _, role in { "Ground", "Gunship", "Waiting" } do
                local team = Instance.new("Team")
                team.Name = role
                team.AutoAssignable = false
                team.TeamColor = if role == "Ground"
                    then BrickColor.new("Bright blue")
                    elseif role == "Gunship" then BrickColor.new("Bright red")
                    else BrickColor.new("Medium stone grey")
                team.Parent = Teams
                table.insert(ownedTeams, team)
            end
            local status = Instance.new("Folder")
            status.Name = "RoundState"
            folder = status
            local command = Instance.new("RemoteEvent")
            command.Name = "Surrender"
            command.Parent = status
            status.Parent = ReplicatedStorage
            table.insert(
                connections,
                command.OnServerEvent:Connect(function(player: Player, payload: unknown)
                    local owner = owners[player]
                    if owner and RateLimit.take(owner.bucket, workspace:GetServerTimeNow()) then
                        match.command(player.UserId, payload)
                    end
                end)
            )
            table.insert(connections, Players.PlayerAdded:Connect(addPlayer))
            table.insert(
                connections,
                Players.PlayerRemoving:Connect(function(player)
                    local owner = owners[player]
                    if owner then
                        retire(owner.characters)
                        owners[player] = nil
                    end
                    match.leave(player.UserId)
                end)
            )
            phase = match.snapshot().phase
            phaseStarted = workspace:GetServerTimeNow()
            for _, player in Players:GetPlayers() do
                addPlayer(player)
            end
            publish(match.snapshot())
            table.insert(connections, RunService.Heartbeat:Connect(tick))
            return true, nil
        end,
        stop = stop,
        resources = function()
            local count = #connections
            local tasks = drainCount() + if restoringAutoLoads then 1 else 0
            for _, owner in owners do
                local resources = owner.characters.resources()
                count += resources.connections
                tasks += resources.spawnTasks
            end
            return { connections = count, spawnTasks = tasks }
        end,
    }
end

return MatchRuntime
