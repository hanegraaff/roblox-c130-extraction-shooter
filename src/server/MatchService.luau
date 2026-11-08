--!strict
--[=[
    MatchService: server-only deterministic round/roster owner. Depends on RoleService,
    RoundRules and an injected monotonic clock. No Instances, transport or yielding.
    All queued work carries round IDs. State leaves this module only as fresh snapshots.
    The adapter calls step after batching damage/departures; deadline is evaluated first.
]=]
local RoleService = if script then require(script.Parent.RoleService) else require("./RoleService")
local RoundRules = if script then require(script.Parent.RoundRules) else require("./RoundRules")
local MatchService = {}

export type Phase = "Lobby" | "Deploying" | "Active" | "Results" | "Resetting"
export type Result = { winner: string, reason: string }
export type Member = {
    userId: number,
    role: string,
    life: string,
    connected: boolean,
    ready: boolean,
    sequence: number,
}
-- Round IDs never repeat within one owner; revisions increase on every accepted mutation.
export type Snapshot = {
    roundId: number,
    revision: number,
    phase: Phase,
    deadlineSeconds: number,
    members: { [number]: Member },
    result: Result?,
}
export type Settings = { minimumPlayers: number, durationSeconds: number, seed: number }
-- releaseLife runs at most once per active life, with false for terminal/reset cleanup.
export type Adapters = { now: () -> number, releaseLife: (number, number, boolean) -> () }
export type Controller = {
    join: (number) -> (),
    leave: (number) -> (),
    deploy: () -> (boolean, string?),
    ready: (number, number) -> boolean,
    activate: () -> (boolean, string?),
    eliminate: (number, number) -> boolean,
    proposeAircraftDestroyed: (number) -> boolean,
    abort: (number, string) -> boolean,
    step: () -> (),
    beginReset: () -> boolean,
    finishReset: () -> boolean,
    command: (number, unknown) -> (boolean, string?),
    snapshot: () -> Snapshot,
}

-- Creates one independent owner. Settings are trusted server configuration, validated here.
-- Cleanup adapters must not yield, throw, or reenter the service.
function MatchService.new(settings: Settings, adapters: Adapters): Controller
    assert(settings.minimumPlayers >= 2 and settings.minimumPlayers <= 10, "invalid minimum")
    assert(settings.minimumPlayers % 1 == 0, "minimum must be integral")
    assert(settings.durationSeconds >= 1 and settings.durationSeconds <= 3600, "invalid duration")
    assert(
        settings.seed >= 0 and settings.seed <= 2147483647 and settings.seed % 1 == 0,
        "seed must be a safe nonnegative integer"
    )
    local state: Snapshot = {
        roundId = 0,
        revision = 0,
        phase = "Lobby",
        deadlineSeconds = 0,
        members = {},
        result = nil,
    }
    local connected: { [number]: boolean } = {}
    local waited: { [number]: number } = {}
    local previousOperator: number? = nil
    local aircraftDestroyed = false
    local ownedLives: { [number]: boolean } = {}
    local pendingRelease: { [number]: boolean } = {}
    local lastNow = -math.huge
    local service: Controller
    local function now(): number
        local value = adapters.now()
        assert(value == value and math.abs(value) < math.huge and value >= lastNow, "clock must be monotonic")
        lastNow = value
        return value
    end
    local function changed()
        state.revision += 1
    end
    local function transition(phase: Phase): boolean
        if not RoundRules.canTransition(state.phase, phase) then
            return false
        end
        state.phase = phase
        changed()
        return true
    end
    local function release(member: Member, recover: boolean)
        if ownedLives[member.userId] then
            ownedLives[member.userId] = nil
            pendingRelease[member.userId] = nil
            adapters.releaseLife(member.userId, state.roundId, recover)
        end
        if member.life == "Alive" then
            member.life = "Eliminated"
        end
    end
    local function commit(result: Result): boolean
        if state.result or not transition("Results") then
            return false
        end
        state.result = result
        for _, member in state.members do
            release(member, false)
        end
        return true
    end
    local function cancelDeployment()
        for _, member in state.members do
            release(member, false)
        end
        table.clear(state.members)
        state.deadlineSeconds = 0
        transition("Lobby")
    end
    local function snapshot(): Snapshot
        local members: { [number]: Member } = {}
        for id, member in state.members do
            members[id] = table.clone(member)
        end
        return {
            roundId = state.roundId,
            revision = state.revision,
            phase = state.phase,
            deadlineSeconds = state.deadlineSeconds,
            members = members,
            result = if state.result then table.clone(state.result) else nil,
        }
    end
    service = {
        join = function(id)
            if connected[id] then
                return
            end
            connected[id] = true
            waited[id] = waited[id] or 0
            local member = state.members[id]
            if member then
                -- UserId tombstones survive departures; reconnect never restores a life.
                member.connected = true
            elseif state.phase ~= "Lobby" then
                state.members[id] = {
                    userId = id,
                    role = "Spectator",
                    life = "Spectating",
                    connected = true,
                    ready = false,
                    sequence = 0,
                }
            end
            changed()
        end,
        leave = function(id)
            if not connected[id] then
                return
            end
            connected[id] = nil
            local member = state.members[id]
            if member then
                member.connected = false
                if state.phase == "Active" then
                    if member.life == "Alive" then
                        member.life = "Eliminated"
                        pendingRelease[id] = true
                    end
                end
            end
            changed()
            if state.phase == "Deploying" and member and member.role ~= "Spectator" then
                cancelDeployment()
            end
        end,
        deploy = function()
            if state.phase ~= "Lobby" then
                return false, "not in lobby"
            end
            local candidates: { { userId: number, waitedRounds: number } } = {}
            for id in connected do
                table.insert(candidates, { userId = id, waitedRounds = waited[id] or 0 })
            end
            local assignment, reason = RoleService.assign(
                candidates,
                settings.minimumPlayers,
                previousOperator,
                (settings.seed + state.roundId) % 2147483648
            )
            if not assignment then
                return false, reason
            end
            state.roundId += 1
            table.clear(state.members)
            state.result = nil
            state.deadlineSeconds = 0
            aircraftDestroyed = false
            for _, candidate in candidates do
                state.members[candidate.userId] = {
                    userId = candidate.userId,
                    role = if candidate.userId == assignment.operatorId then "Gunship" else "Ground",
                    life = "Deploying",
                    connected = true,
                    ready = false,
                    sequence = 0,
                }
            end
            transition("Deploying")
            return true, nil
        end,
        ready = function(id, roundId)
            local member = state.members[id]
            if
                state.phase ~= "Deploying"
                or roundId ~= state.roundId
                or not member
                or not member.connected
                or member.role == "Spectator"
                or member.ready
            then
                return false
            end
            member.ready = true
            changed()
            return true
        end,
        activate = function()
            if state.phase ~= "Deploying" then
                return false, "not deploying"
            end
            for _, member in state.members do
                if member.role ~= "Spectator" and (not member.connected or not member.ready) then
                    return false, "roster not ready"
                end
            end
            for id, member in state.members do
                if member.role ~= "Spectator" then
                    member.life = "Alive"
                    ownedLives[id] = true
                    waited[id] = if member.role == "Gunship" then 0 else (waited[id] or 0) + 1
                    if member.role == "Gunship" then
                        previousOperator = id
                    end
                end
            end
            state.deadlineSeconds = now() + settings.durationSeconds
            transition("Active")
            return true, nil
        end,
        eliminate = function(id, roundId)
            local member = state.members[id]
            if
                state.phase ~= "Active"
                or roundId ~= state.roundId
                or now() >= state.deadlineSeconds
                or not member
                or member.role ~= "Ground"
                or member.life ~= "Alive"
            then
                return false
            end
            member.life = "Eliminated"
            pendingRelease[id] = true
            changed()
            return true
        end,
        proposeAircraftDestroyed = function(roundId)
            if
                state.phase ~= "Active"
                or roundId ~= state.roundId
                or now() >= state.deadlineSeconds
                or aircraftDestroyed
            then
                return false
            end
            aircraftDestroyed = true
            changed()
            return true
        end,
        abort = function(roundId, reason)
            if roundId ~= state.roundId or (state.phase ~= "Deploying" and state.phase ~= "Active") then
                return false
            end
            return commit({ winner = "None", reason = reason })
        end,
        step = function()
            if state.phase ~= "Active" then
                return
            end
            local groundAlive, count = 0, 0
            local operatorConnected = false
            for _, member in state.members do
                if member.role == "Gunship" then
                    operatorConnected = member.connected and member.life == "Alive"
                elseif member.role == "Ground" and member.life == "Alive" then
                    groundAlive += 1
                end
            end
            for _ in connected do
                count += 1
            end
            local result = RoundRules.outcome({
                nowSeconds = now(),
                deadlineSeconds = state.deadlineSeconds,
                aircraftDestroyed = aircraftDestroyed,
                groundAlive = groundAlive,
                operatorConnected = operatorConnected,
                connectedCount = count,
            })
            if result then
                commit(result)
            else
                for id in pendingRelease do
                    local member = state.members[id]
                    release(member, true)
                end
            end
        end,
        beginReset = function()
            return transition("Resetting")
        end,
        finishReset = function()
            if state.phase ~= "Resetting" then
                return false
            end
            table.clear(state.members)
            state.result = nil
            state.deadlineSeconds = 0
            aircraftDestroyed = false
            return transition("Lobby")
        end,
        command = function(id, value)
            if type(value) ~= "table" then
                return false, "invalid payload"
            end
            local payload = value :: { [unknown]: unknown }
            local count = 0
            for key in payload do
                if key ~= "roundId" and key ~= "sequence" and key ~= "action" then
                    return false, "unknown payload field"
                end
                count += 1
            end
            local roundId, sequence = payload.roundId, payload.sequence
            if
                count ~= 3
                or type(roundId) ~= "number"
                or type(sequence) ~= "number"
                or sequence ~= sequence
                or sequence == math.huge
                or sequence % 1 ~= 0
                or sequence < 1
                or sequence > 2147483647
                or payload.action ~= "Surrender"
            then
                return false, "invalid command"
            end
            local member = state.members[id]
            if
                state.phase ~= "Active"
                or roundId ~= state.roundId
                or not member
                or not member.connected
                or member.role ~= "Ground"
                or member.life ~= "Alive"
                or sequence <= member.sequence
            then
                return false, "unauthorized or stale command"
            end
            if not service.eliminate(id, roundId) then
                return false, "round deadline reached"
            end
            member.sequence = sequence
            return true, nil
        end,
        snapshot = snapshot,
    }
    return service
end

return MatchService
