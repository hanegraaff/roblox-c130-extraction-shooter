--!strict
--[=[
    GroundCombatService: server-only deterministic M-7 ammunition and request validation.
    Depends on Validation and injected server time/origin; no Instances or yielding.
    Each user has independent magazine, reserve, reload and replay state per round.
]=]
local loadPath = (require :: unknown) :: (string) -> unknown
local Validation = (
    if script
        then require(game:GetService("ReplicatedStorage").Shared.Validation)
        else loadPath("../shared/Validation")
) :: typeof(require(game:GetService("ReplicatedStorage").Shared.Validation))
local GroundCombatService = {}
GroundCombatService.capacity = 30
GroundCombatService.reserve = 120
GroundCombatService.cadence = 0.15
GroundCombatService.reloadSeconds = 2
GroundCombatService.range = 1200
export type Readiness = { ammo: number, reserve: number, nextFire: number, reloadUntil: number }
export type Intent = { x: number, y: number, z: number, sequence: number }
export type Controller = {
    reset: (number) -> (),
    readiness: (number, number) -> Readiness,
    fire: (
        number,
        unknown,
        boolean,
        number,
        number,
        number,
        number
    ) -> ({ x: number, y: number, z: number, sequence: number }?, string?),
    preflight: (number, unknown, boolean, number, number, number, number) -> boolean,
    reload: (number, unknown, boolean, number) -> boolean,
}
-- All times are monotonic seconds, target and server origin are studs. Callers
-- establish active round, life, role and exact Tool ownership before invoking.
function GroundCombatService.new(): Controller
    local round = 0
    local states: { [number]: Readiness } = {}
    local sequences: { [number]: number } = {}
    local function current(userId: number, now: number): Readiness
        local old = states[userId]
            or {
                ammo = GroundCombatService.capacity,
                reserve = GroundCombatService.reserve,
                nextFire = 0,
                reloadUntil = 0,
            }
        local state = table.clone(old)
        if state.reloadUntil > 0 and now >= state.reloadUntil then
            local taken = math.min(GroundCombatService.capacity - state.ammo, state.reserve)
            state.ammo += taken
            state.reserve -= taken
            state.reloadUntil = 0
        end
        return state
    end
    local function sequenceOf(userId: number, value: unknown): number?
        if
            type(value) ~= "number"
            or not Validation.isFinite(value)
            or value % 1 ~= 0
            or value < 1
            or value > 2147483647
            or value <= (sequences[userId] or 0)
        then
            return nil
        end
        return value
    end
    -- Returns a candidate/readiness copy without spending ammo or sequence.
    local function prepare(
        userId: number,
        payload: unknown,
        eligible: boolean,
        now: number,
        ox: number,
        oy: number,
        oz: number
    ): (Intent?, Readiness?, string?)
        if
            not eligible
            or round <= 0
            or not Validation.isFinite(now)
            or not Validation.isFinite(ox)
            or not Validation.isFinite(oy)
            or not Validation.isFinite(oz)
            or not Validation.flatPayload(payload, 6, 32)
            or type(payload) ~= "table"
        then
            return nil, nil, "ineligible or invalid payload"
        end
        local fields = payload :: { [string]: unknown }
        local count = 0
        for key in fields do
            if
                key ~= "roundId"
                and key ~= "sequence"
                and key ~= "weapon"
                and key ~= "x"
                and key ~= "y"
                and key ~= "z"
            then
                return nil, nil, "unknown field"
            end
            count += 1
        end
        local sequence, x, y, z = sequenceOf(userId, fields.sequence), fields.x, fields.y, fields.z
        if
            count ~= 6
            or fields.roundId ~= round
            or fields.weapon ~= "M7"
            or not sequence
            or type(x) ~= "number"
            or type(y) ~= "number"
            or type(z) ~= "number"
            or not Validation.isFinite(x)
            or not Validation.isFinite(y)
            or not Validation.isFinite(z)
        then
            return nil, nil, "invalid fire intent"
        end
        local distance = (x - ox) ^ 2 + (y - oy) ^ 2 + (z - oz) ^ 2
        if not Validation.isFinite(distance) or distance < 1 or distance > GroundCombatService.range ^ 2 then
            return nil, nil, "invalid range"
        end
        local state = current(userId, now)
        if state.ammo <= 0 or state.reloadUntil > 0 or now < state.nextFire then
            return nil, nil, "not ready"
        end
        return { x = x, y = y, z = z, sequence = sequence }, state, nil
    end
    return {
        reset = function(id)
            if id ~= round then
                round = id
                table.clear(states)
                table.clear(sequences)
            end
        end,
        readiness = current,
        preflight = function(userId, payload, eligible, now, ox, oy, oz)
            local intent = prepare(userId, payload, eligible, now, ox, oy, oz)
            return intent ~= nil
        end,
        fire = function(userId, payload, eligible, now, ox, oy, oz)
            local intent, state, reason = prepare(userId, payload, eligible, now, ox, oy, oz)
            if not intent or not state then
                return nil, reason
            end
            state.ammo -= 1
            state.nextFire = now + GroundCombatService.cadence
            states[userId], sequences[userId] = state, intent.sequence
            return intent, nil
        end,
        reload = function(userId, payload, eligible, now)
            if
                not eligible
                or round <= 0
                or not Validation.isFinite(now)
                or not Validation.flatPayload(payload, 2, 32)
                or type(payload) ~= "table"
            then
                return false
            end
            local fields = payload :: { [string]: unknown }
            local count = 0
            for key in fields do
                if key ~= "roundId" and key ~= "sequence" then
                    return false
                end
                count += 1
            end
            local sequence = sequenceOf(userId, fields.sequence)
            local state = current(userId, now)
            if
                count ~= 2
                or fields.roundId ~= round
                or not sequence
                or state.reloadUntil > 0
                or state.ammo >= GroundCombatService.capacity
                or state.reserve <= 0
            then
                return false
            end
            state.reloadUntil = now + GroundCombatService.reloadSeconds
            states[userId], sequences[userId] = state, sequence
            return true
        end,
    }
end
return GroundCombatService
