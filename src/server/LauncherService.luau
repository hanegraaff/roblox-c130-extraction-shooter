--!strict
--[=[
    LauncherService: deterministic server-only ownership and readiness for one round weapon.
    Depends on Validation and caller-established role/life/world authority. Coordinates
    are studs, times monotonic server seconds. Nothing yields or creates Instances.
    Rejections never spend sequence, ownership or ammunition. Reload belongs to the
    stable weapon identity, including during recovery; snapshots cannot mutate state.
]=]
local loadPath = (require :: unknown) :: (string) -> unknown
local Validation = (
    if script
        then require(game:GetService("ReplicatedStorage").Shared.Validation)
        else loadPath("../shared/Validation")
) :: typeof(require(game:GetService("ReplicatedStorage").Shared.Validation))
local LauncherService = {}
LauncherService.reloadSeconds = 4
LauncherService.pickupStuds = 8
LauncherService.rangeStuds = 1200
LauncherService.speedStudsPerSecond = 240
LauncherService.lifetimeSeconds = 5
LauncherService.radiusStuds = 0.2
export type Position = { x: number, y: number, z: number }
export type Snapshot = {
    roundId: number,
    launcherId: string,
    state: string,
    ownerId: number?,
    readyAt: number,
    ammo: number,
    position: Position,
    revision: number,
}
export type Intent = { sequence: number, x: number?, y: number?, z: number? }
export type Controller = {
    reset: (number, Position) -> (),
    clear: () -> (),
    snapshot: (number) -> Snapshot,
    preflight: (number, unknown, string, boolean, number) -> Intent?,
    pickup: (number, unknown, boolean, boolean, number) -> boolean,
    drop: (number, unknown, boolean, number) -> boolean,
    recover: (number) -> boolean,
    place: (Position) -> boolean,
    fire: (number, unknown, boolean, number, Position) -> (Intent?, string?),
}
local function positionValid(position: Position): boolean
    return Validation.isFinite(position.x)
        and Validation.isFinite(position.y)
        and Validation.isFinite(position.z)
end
-- One nonyielding owner. reset starts a new round; calling it with the same ID
-- cannot refill or clone the weapon. clear terminally removes that round's weapon.
-- recover removes an owner before the engine chooses a supported drop or anchor;
-- place completes that transient Recovering state atomically at the adapter boundary.
function LauncherService.new(): Controller
    local roundId, launcherId, state = 0, "", "Inactive"
    local ownerId: number? = nil
    local readyAt, revision, shotSerial = 0, 0, 0
    local position: Position = { x = 0, y = 0, z = 0 }
    local sequences: { [number]: number } = {}
    local function preflight(
        userId: number,
        payload: unknown,
        action: string,
        eligible: boolean,
        now: number
    ): Intent?
        if
            not eligible
            or roundId <= 0
            or state == "Inactive"
            or not Validation.isFinite(now)
            or not Validation.flatPayload(payload, if action == "Fire" then 6 else 3, 64)
            or type(payload) ~= "table"
        then
            return nil
        end
        local fields = payload :: { [string]: unknown }
        local count = 0
        for key in fields do
            if
                key ~= "roundId"
                and key ~= "sequence"
                and key ~= "launcherId"
                and not (action == "Fire" and (key == "x" or key == "y" or key == "z"))
            then
                return nil
            end
            count += 1
        end
        local sequence = fields.sequence
        if
            fields.roundId ~= roundId
            or fields.launcherId ~= launcherId
            or count ~= (if action == "Fire" then 6 else 3)
            or type(sequence) ~= "number"
            or not Validation.inRange(sequence, 1, 2147483647)
            or sequence % 1 ~= 0
            or sequence <= (sequences[userId] or 0)
        then
            return nil
        end
        if action == "Pickup" then
            if state ~= "Available" then
                return nil
            end
        elseif action == "Drop" or action == "Fire" then
            if state ~= "Held" or ownerId ~= userId then
                return nil
            end
        else
            return nil
        end
        if action == "Fire" then
            local x, y, z = fields.x, fields.y, fields.z
            if
                now < readyAt
                or type(x) ~= "number"
                or type(y) ~= "number"
                or type(z) ~= "number"
                or not Validation.isFinite(x)
                or not Validation.isFinite(y)
                or not Validation.isFinite(z)
            then
                return nil
            end
            return { sequence = sequence, x = x, y = y, z = z }
        end
        return { sequence = sequence }
    end
    return {
        reset = function(id, anchor)
            if id == roundId then
                return
            end
            assert(id > 0 and id % 1 == 0 and positionValid(anchor), "invalid internal launcher round")
            roundId, launcherId, state, ownerId = id, "launcher:" .. tostring(id), "Available", nil
            position, readyAt, shotSerial = table.clone(anchor), 0, 0
            revision += 1
            table.clear(sequences)
        end,
        clear = function()
            if state ~= "Inactive" then
                state, ownerId = "Inactive", nil
                revision += 1
            end
        end,
        snapshot = function(now)
            return {
                roundId = roundId,
                launcherId = launcherId,
                state = state,
                ownerId = ownerId,
                readyAt = readyAt,
                ammo = if state ~= "Inactive" and now >= readyAt then 1 else 0,
                position = table.clone(position),
                revision = revision,
            }
        end,
        preflight = preflight,
        pickup = function(userId, payload, eligible, reachable, now)
            local intent = preflight(userId, payload, "Pickup", eligible, now)
            if not intent or not reachable then
                return false
            end
            state, ownerId, sequences[userId] = "Held", userId, intent.sequence
            revision += 1
            return true
        end,
        drop = function(userId, payload, eligible, now)
            local intent = preflight(userId, payload, "Drop", eligible, now)
            if not intent then
                return false
            end
            state, ownerId, sequences[userId] = "Recovering", nil, intent.sequence
            revision += 1
            return true
        end,
        recover = function(userId)
            if state ~= "Held" or ownerId ~= userId then
                return false
            end
            state, ownerId = "Recovering", nil
            revision += 1
            return true
        end,
        place = function(candidate)
            if state ~= "Recovering" or not positionValid(candidate) then
                return false
            end
            state, position = "Available", table.clone(candidate)
            revision += 1
            return true
        end,
        fire = function(userId, payload, eligible, now, origin)
            local intent = preflight(userId, payload, "Fire", eligible, now)
            if not intent or not positionValid(origin) then
                return nil, nil
            end
            local x, y, z = intent.x, intent.y, intent.z
            if not x or not y or not z then
                return nil, nil
            end
            local distanceSquared = (x - origin.x) ^ 2 + (y - origin.y) ^ 2 + (z - origin.z) ^ 2
            if not Validation.inRange(distanceSquared, 1, LauncherService.rangeStuds ^ 2) then
                return nil, nil
            end
            readyAt, sequences[userId] = now + LauncherService.reloadSeconds, intent.sequence
            shotSerial += 1
            revision += 1
            return intent, "rocket:" .. tostring(roundId) .. ":" .. tostring(shotSerial)
        end,
    }
end
return LauncherService
