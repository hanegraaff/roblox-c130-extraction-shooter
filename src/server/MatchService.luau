--!strict
--[=[
    MatchService: server-only deterministic round/roster owner. Depends on RoleService,
    RoundRules and an injected monotonic clock. No Instances, transport or yielding.
    All queued work carries round IDs. State leaves this module only as fresh snapshots.
    Ready deployments start the Ground scatter clock separately from combat.
    The adapter submits damage in step. Deadline, damage, outcomes and cleanup use
    one captured server time; departures become competitive facts after damage.
]=]
local RoleService = if script then require(script.Parent.RoleService) else require("./RoleService")
local loadPath = (require :: unknown) :: (string) -> unknown
local RoundRules = (
    if script then require(script.Parent.RoundRules) else loadPath("./RoundRules")
) :: typeof(require(script.Parent.RoundRules))
local MatchService = {}

export type Phase = "Lobby" | "Deploying" | "Scatter" | "Active" | "Results" | "Resetting"
-- Optional server-derived credit identifies the operator or lethal aircraft hit.
export type Result = { winner: string, reason: string, userId: number?, weapon: string?, shotId: string? }
-- Server-resolved attribution for the direct hit that reduced aircraft health to zero.
export type AircraftCredit = { userId: number, weapon: string, shotId: string }
export type Member = {
    userId: number,
    role: string,
    life: string,
    connected: boolean,
    ready: boolean,
    sequence: number,
}
-- Round IDs never repeat within one owner; revisions increase on accepted mutation.
-- DeadlineSeconds holds the current phase's deadline in monotonic server seconds.
export type Snapshot = {
    roundId: number,
    revision: number,
    phase: Phase,
    deadlineSeconds: number,
    intermissionUntil: number,
    members: { [number]: Member },
    result: Result?,
}
-- Omitted intermission and scatter durations are for short standalone fixtures.
export type Settings = {
    minimumPlayers: number,
    durationSeconds: number,
    seed: number,
    intermissionSeconds: number?,
    scatterSeconds: number?,
}
-- releaseLife runs at most once per deployed life, with false for terminal/reset cleanup.
export type Adapters = { now: () -> number, releaseLife: (number, number, boolean) -> () }
export type Controller = {
    join: (number) -> (),
    leave: (number) -> (),
    deploy: () -> (boolean, string?),
    ready: (number, number) -> boolean,
    -- Activates the ready roster and begins scatter (or combat in a zero-length fixture).
    activate: (number?) -> (boolean, string?),
    -- Confirmed grounded death/surrender. Can refine a pending character loss.
    eliminate: (number, number) -> boolean,
    -- Revokes a deployed life or holds an ambiguous model loss for readiness
    -- processing. A same-step departure can explain the model removal.
    characterRemoved: (number, number) -> boolean,
    damageAllowed: (number) -> boolean,
    proposeAircraftDestroyed: (number, AircraftCredit?) -> boolean,
    abort: (number, string) -> boolean,
    step: (((number) -> ())?, number?) -> (),
    beginReset: () -> boolean,
    -- Normal cleanup retains the result/deadline. Runtime teardown alone clears them.
    finishReset: (boolean?) -> boolean,
    command: (number, unknown) -> (boolean, string?),
    snapshot: () -> Snapshot,
}

-- Creates one independent owner. Settings are trusted server configuration, validated here.
-- Cleanup adapters must not yield, throw, or reenter the service.
function MatchService.new(settings: Settings, adapters: Adapters): Controller
    assert(settings.minimumPlayers >= 2 and settings.minimumPlayers <= 10, "invalid minimum")
    assert(settings.minimumPlayers % 1 == 0, "minimum must be integral")
    assert(settings.durationSeconds >= 1 and settings.durationSeconds <= 3600, "invalid duration")
    local intermissionSeconds = settings.intermissionSeconds or 0
    assert(intermissionSeconds >= 0 and intermissionSeconds <= 3600, "invalid intermission duration")
    local scatterSeconds = settings.scatterSeconds or 0
    assert(scatterSeconds >= 0 and scatterSeconds <= 3600, "invalid scatter duration")
    assert(
        settings.seed >= 0 and settings.seed <= 2147483647 and settings.seed % 1 == 0,
        "seed must be a safe nonnegative integer"
    )
    local state: Snapshot = {
        roundId = 0,
        revision = 0,
        phase = "Lobby",
        deadlineSeconds = 0,
        intermissionUntil = 0,
        members = {},
        result = nil,
    }
    local connected: { [number]: boolean } = {}
    local waited: { [number]: number } = {}
    local previousOperator: number? = nil
    local aircraftDestroyed = false
    local aircraftCredit: AircraftCredit? = nil
    local ownedLives: { [number]: boolean } = {}
    local pendingRelease: { [number]: boolean } = {}
    local departingGround: { [number]: boolean } = {}
    local removedCharacters: { [number]: boolean } = {}
    local lastNow = -math.huge
    local damageSeconds: number? = nil
    local service: Controller
    local function now(atSeconds: number?): number
        local value = damageSeconds or atSeconds or adapters.now()
        assert(value == value and math.abs(value) < math.huge and value >= lastNow, "clock must be monotonic")
        lastNow = value
        return value
    end
    local function damageAllowed(roundId: number): boolean
        return state.phase == "Active" and roundId == state.roundId and now() < state.deadlineSeconds
    end
    local function lifeInPlay(roundId: number): boolean
        return roundId == state.roundId and (state.phase == "Scatter" or damageAllowed(roundId))
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
    local function commit(result: Result, atSeconds: number?): boolean
        if state.result or not transition("Results") then
            return false
        end
        state.result = result
        state.intermissionUntil = if intermissionSeconds > 0 then now(atSeconds) + intermissionSeconds else 0
        table.clear(departingGround)
        table.clear(removedCharacters)
        for _, member in state.members do
            release(member, false)
        end
        return true
    end
    local function loseGround(id: number, roundId: number, confirmed: boolean): boolean
        local member = state.members[id]
        if not lifeInPlay(roundId) or not member or not member.connected or member.role ~= "Ground" then
            return false
        end
        if member.life ~= "Alive" then
            if confirmed and removedCharacters[id] then
                -- Death can be reported after the owned model's removal.
                -- Keep the same consumed life but retain the confirmed cause.
                removedCharacters[id] = nil
                return true
            end
            return false
        end
        member.life = "Eliminated"
        pendingRelease[id] = true
        if not confirmed then
            removedCharacters[id] = true
        end
        changed()
        return true
    end
    local function cancelDeployment()
        for _, member in state.members do
            release(member, false)
        end
        table.clear(state.members)
        table.clear(removedCharacters)
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
            intermissionUntil = state.intermissionUntil,
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
                if state.phase == "Scatter" or state.phase == "Active" then
                    if member.life == "Alive" or removedCharacters[id] then
                        if member.role == "Ground" then
                            departingGround[id] = true
                        end
                    end
                    removedCharacters[id] = nil
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
            if state.intermissionUntil > 0 and now() < state.intermissionUntil then
                return false, "intermission has not elapsed"
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
            state.intermissionUntil = 0
            aircraftDestroyed = false
            aircraftCredit = nil
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
        activate = function(atSeconds)
            if state.phase ~= "Deploying" then
                return false, "not deploying"
            end
            if next(removedCharacters) then
                commit({ winner = "None", reason = "CharacterRemovedDuringDeployment" }, atSeconds)
                return false, "deployed character removed"
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
            local seconds = now(atSeconds)
            if scatterSeconds > 0 then
                state.deadlineSeconds = seconds + scatterSeconds
                transition("Scatter")
            else
                state.deadlineSeconds = seconds + settings.durationSeconds
                transition("Active")
            end
            return true, nil
        end,
        eliminate = function(id, roundId)
            return loseGround(id, roundId, true)
        end,
        characterRemoved = function(id, roundId)
            if state.phase == "Deploying" and roundId == state.roundId then
                local member = state.members[id]
                if
                    not member
                    or not member.connected
                    or member.role == "Spectator"
                    or removedCharacters[id]
                then
                    return false
                end
                removedCharacters[id] = true
                member.ready = false
                changed()
                return true
            end
            return loseGround(id, roundId, false)
        end,
        damageAllowed = damageAllowed,
        proposeAircraftDestroyed = function(roundId, credit)
            if not damageAllowed(roundId) or aircraftDestroyed then
                return false
            end
            aircraftDestroyed = true
            aircraftCredit = if credit then table.clone(credit) else nil
            changed()
            return true
        end,
        abort = function(roundId, reason)
            if
                roundId ~= state.roundId
                or (state.phase ~= "Deploying" and state.phase ~= "Scatter" and state.phase ~= "Active")
            then
                return false
            end
            return commit({ winner = "None", reason = reason })
        end,
        -- The optional server callback must not yield, reenter step or throw.
        -- Damage can run only in Active and strictly before expiry. Scatter
        -- resolves life/departure outcomes before opening combat at the deadline.
        step = function(resolveDamage, atSeconds)
            local scatter = state.phase == "Scatter"
            if (not scatter and state.phase ~= "Active") or damageSeconds ~= nil then
                return
            end
            local stepSeconds = now(atSeconds)
            if not scatter and resolveDamage and stepSeconds < state.deadlineSeconds then
                damageSeconds = stepSeconds
                resolveDamage(stepSeconds)
                damageSeconds = nil
            end
            local groundAlive, groundDeparted, count = 0, 0, 0
            local operatorConnected = false
            local operatorId: number? = nil
            for _, member in state.members do
                if member.role == "Gunship" then
                    operatorConnected = member.connected and member.life == "Alive"
                    operatorId = member.userId
                elseif member.role == "Ground" and member.life == "Alive" then
                    groundAlive += 1
                end
            end
            for _ in departingGround do
                groundDeparted += 1
            end
            for _ in connected do
                count += 1
            end
            local outcome = RoundRules.outcome({
                nowSeconds = stepSeconds,
                deadlineSeconds = if scatter then nil else state.deadlineSeconds,
                aircraftDestroyed = aircraftDestroyed,
                groundAlive = groundAlive,
                groundEliminated = groundAlive == 0 and groundDeparted == 0,
                operatorConnected = operatorConnected,
                connectedCount = count,
            })
            if outcome then
                local result: Result = { winner = outcome.winner, reason = outcome.reason }
                if result.reason == "AircraftDestroyed" and aircraftCredit then
                    result.userId = aircraftCredit.userId
                    result.weapon = aircraftCredit.weapon
                    result.shotId = aircraftCredit.shotId
                elseif result.winner == "Gunship" then
                    result.userId = operatorId
                end
                commit(result, stepSeconds)
            else
                table.clear(departingGround)
                table.clear(removedCharacters)
                for id in pendingRelease do
                    local member = state.members[id]
                    release(member, true)
                end
                if scatter and stepSeconds >= state.deadlineSeconds then
                    state.deadlineSeconds = stepSeconds + settings.durationSeconds
                    transition("Active")
                end
            end
        end,
        beginReset = function()
            return transition("Resetting")
        end,
        finishReset = function(teardown)
            if state.phase ~= "Resetting" and not (teardown and state.phase == "Lobby") then
                return false
            end
            table.clear(state.members)
            if teardown then
                state.intermissionUntil = 0
            end
            if state.intermissionUntil == 0 then
                state.result = nil
            end
            state.deadlineSeconds = 0
            aircraftDestroyed = false
            aircraftCredit = nil
            if state.phase == "Lobby" then
                changed()
                return true
            end
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
                (state.phase ~= "Active" and state.phase ~= "Scatter")
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
