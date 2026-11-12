--!strict
--[=[
    CombatService: server-only deterministic aircraft fire authorization and readiness.
    Depends on injected active-level bounds, monotonic seconds and authoritative muzzle
    coordinates. No Instances, transport, health mutation, yielding or client authority.
    Each accepted shot spends ammunition once; switching profiles never changes readiness.
    A round reset invalidates sequences and shot IDs. Callers own flight and impact.
]=]
local loadPath = (require :: unknown) :: (string) -> unknown
local AircraftRules = (
    if script
        then require(game:GetService("ReplicatedStorage").Shared.AircraftRules)
        else loadPath("../shared/AircraftRules")
) :: typeof(require(game:GetService("ReplicatedStorage").Shared.AircraftRules))
local MapRules = (
    if script
        then require(game:GetService("ReplicatedStorage").Shared.MapRules)
        else loadPath("../shared/MapRules")
) :: typeof(require(game:GetService("ReplicatedStorage").Shared.MapRules))
local Validation = (
    if script
        then require(game:GetService("ReplicatedStorage").Shared.Validation)
        else loadPath("../shared/Validation")
) :: typeof(require(game:GetService("ReplicatedStorage").Shared.Validation))
local CombatService = {}

-- Balance defaults in seconds, studs and health units. A 100-round chain-gun
-- magazine at 0.15 seconds per shot permits more than nine uninterrupted seconds.
export type Profile = {
    capacity: number,
    cadence: number,
    reload: number,
    speed: number,
    lifetime: number,
    range: number,
    damage: number,
    radius: number,
    collisionRadius: number,
}
CombatService.profiles = table.freeze({
    GAU23 = table.freeze({
        capacity = 100,
        cadence = 0.15,
        reload = 5,
        speed = 650,
        lifetime = 2,
        range = 900,
        damage = 25,
        radius = 4,
        collisionRadius = 0.5,
    }),
    M102 = table.freeze({
        capacity = 1,
        cadence = 1,
        reload = 4,
        speed = 300,
        lifetime = 4,
        range = 900,
        damage = 100,
        radius = 18,
        collisionRadius = 2,
    }),
}) :: { [string]: Profile }
export type Readiness = { ammo: number, nextFire: number, reloadUntil: number }
export type Shot = {
    roundId: number,
    shotId: number,
    weapon: string,
    x: number,
    y: number,
    z: number,
    firedAt: number,
}
export type Controller = {
    reset: (number) -> (),
    fire: (number, unknown, string, boolean, number, number, number, number) -> (Shot?, string?),
    readiness: (string, number) -> Readiness?,
}

-- Computes a bounded swept distance in studs from caller-supplied elapsed/frame
-- seconds. Flight expires strictly after its profile lifetime; equality remains
-- live. Invalid numeric inputs expire rather than advancing. A negative frame
-- delta advances zero, matching the engine adapter's clock-boundary behavior.
function CombatService.flight(
    profile: Profile,
    elapsed: number,
    remaining: number,
    delta: number
): (number, boolean)
    if
        not Validation.isFinite(elapsed)
        or not Validation.isFinite(remaining)
        or not Validation.isFinite(delta)
        or not Validation.isFinite(profile.speed)
        or not Validation.isFinite(profile.lifetime)
        or profile.speed <= 0
        or profile.lifetime <= 0
        or remaining < 0
    then
        return 0, true
    end
    if elapsed > profile.lifetime then
        return 0, true
    end
    return math.min(remaining, profile.speed * math.max(0, delta)), false
end

-- A copy of level geometry and its authored vertical envelope is supplied by the
-- owner. Input coordinates are studs. now is monotonic server time in seconds.
-- Requests are exactly six scalar fields; the caller establishes role/deadline and
-- selection from authoritative state. Rejected requests never spend ammo or sequence.
function CombatService.new(map: typeof(MapRules.defaults), minimumY: number, maximumY: number): Controller
    assert(MapRules.validate(map), "valid active-level bounds required")
    assert(
        Validation.isFinite(minimumY) and Validation.isFinite(maximumY) and minimumY < maximumY,
        "valid aim envelope required"
    )
    local level = table.clone(map)
    local roundId = 0
    local shotId = 0
    local sequences: { [number]: number } = {}
    local weapons: { [string]: Readiness } = {}
    local function clear()
        table.clear(sequences)
        table.clear(weapons)
        for id, profile in CombatService.profiles do
            weapons[id] = { ammo = profile.capacity, nextFire = 0, reloadUntil = 0 }
        end
    end
    clear()
    -- Computes completed reload without modifying stored state on a rejected request.
    local function current(weapon: string, now: number): Readiness?
        local state = weapons[weapon]
        local profile = CombatService.profiles[weapon]
        if not state or not profile or not Validation.isFinite(now) then
            return nil
        end
        local copy = table.clone(state)
        if copy.reloadUntil > 0 and now >= copy.reloadUntil then
            copy.ammo = profile.capacity
            copy.reloadUntil = 0
        end
        return copy
    end
    return {
        reset = function(id)
            if id ~= roundId then
                roundId = id
                shotId = 0
                clear()
            end
        end,
        readiness = current,
        fire = function(userId, payload, selected, eligible, now, originX, originY, originZ)
            if not eligible or roundId <= 0 or not Validation.isFinite(now) then
                return nil, "ineligible"
            end
            if not Validation.flatPayload(payload, 6, 32) or type(payload) ~= "table" then
                return nil, "invalid shape"
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
                    return nil, "unknown field"
                end
                count += 1
            end
            local sequence, weapon, x, y, z = fields.sequence, fields.weapon, fields.x, fields.y, fields.z
            if
                count ~= 6
                or fields.roundId ~= roundId
                or type(sequence) ~= "number"
                or sequence % 1 ~= 0
                or sequence < 1
                or sequence > 2147483647
                or sequence <= (sequences[userId] or 0)
            then
                return nil, "stale round or sequence"
            end
            if type(weapon) ~= "string" or weapon ~= selected then
                return nil, "invalid selection"
            end
            local profile = CombatService.profiles[weapon]
            if not profile or type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" then
                return nil, "invalid weapon or target"
            end
            if
                not AircraftRules.aimAllowed(level, x, y, z, minimumY, maximumY)
                or not Validation.isFinite(originX)
                or not Validation.isFinite(originY)
                or not Validation.isFinite(originZ)
            then
                return nil, "outside aim envelope"
            end
            local distanceSquared = (x - originX) ^ 2 + (y - originY) ^ 2 + (z - originZ) ^ 2
            if
                not Validation.isFinite(distanceSquared)
                or distanceSquared < 1
                or distanceSquared > profile.range ^ 2
            then
                return nil, "target out of range"
            end
            local readiness = current(weapon, now)
            if
                not readiness
                or now < readiness.nextFire
                or readiness.reloadUntil > 0
                or readiness.ammo <= 0
            then
                return nil, "weapon not ready"
            end
            readiness.ammo -= 1
            readiness.nextFire = now + profile.cadence
            if readiness.ammo == 0 then
                readiness.reloadUntil = now + profile.reload
            end
            weapons[weapon] = readiness
            sequences[userId] = sequence
            shotId += 1
            return { roundId = roundId, shotId = shotId, weapon = weapon, x = x, y = y, z = z, firedAt = now },
                nil
        end,
    }
end
return CombatService
