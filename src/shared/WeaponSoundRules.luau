--!strict
-- Weapon sound mix and distance timing. Runs on clients and in host tests with
-- scalar inputs only. Delays are presentation tuning in seconds and studs.
local WeaponSoundRules = {}

export type Cue = "GAU23" | "M102" | "LightImpact" | "HeavyImpact" | "M7" | "RocketLaunch" | "RocketImpact"
export type Emit = (Cue, number, Vector3, number, number?) -> ()
export type Profile = {
    asset: string,
    volume: number,
    speed: number,
    duration: number,
    near: number,
    far: number,
    highGain: number,
    lowGain: number,
    delay: number,
}

local blast = "rbxasset://sounds/impact_explosion_03.mp3"
local profiles: { [string]: Profile } = {
    GAU23 = {
        asset = blast,
        volume = 0.76,
        speed = 1.38,
        duration = 0.31,
        near = 105,
        far = 850,
        highGain = -21,
        lowGain = 1,
        delay = 0.13,
    },
    M102 = {
        asset = "rbxassetid://9120018088",
        volume = 1.15,
        speed = 0.87,
        duration = 1.48,
        near = 135,
        far = 960,
        highGain = -22,
        lowGain = 3,
        delay = 0.19,
    },
    LightImpact = {
        asset = blast,
        volume = 0.22,
        speed = 1.6,
        duration = 0.21,
        near = 24,
        far = 360,
        highGain = -12,
        lowGain = -2,
        delay = 0.06,
    },
    HeavyImpact = {
        asset = blast,
        volume = 0.68,
        speed = 0.77,
        duration = 1.05,
        near = 43,
        far = 620,
        highGain = -17,
        lowGain = 3,
        delay = 0.09,
    },
    M7 = {
        asset = "rbxassetid://9113189096",
        volume = 0.66,
        speed = 1,
        duration = 0.42,
        near = 20,
        far = 470,
        highGain = 0,
        lowGain = 0,
        delay = 0,
    },
    RocketLaunch = {
        asset = "rbxassetid://9120729973",
        volume = 0.94,
        speed = 1.13,
        duration = 0.87,
        near = 30,
        far = 530,
        highGain = -3,
        lowGain = 2,
        delay = 0,
    },
    RocketImpact = {
        asset = blast,
        volume = 0.92,
        speed = 0.91,
        duration = 1.12,
        near = 42,
        far = 620,
        highGain = -8,
        lowGain = 3,
        delay = 0.03,
    },
}

-- Returns a frozen mix profile or nil for an unsupported presentation cue.
function WeaponSoundRules.profile(cue: unknown): Profile?
    return if type(cue) == "string" then profiles[cue] else nil
end

for _, profile in profiles do
    table.freeze(profile)
end

-- Returns the due server-clock time. Nearby ground muzzle cues are immediate
-- for the shooter. Distant sounds add a bounded game-distance propagation delay.
function WeaponSoundRules.due(
    profile: Profile,
    distance: number,
    emittedAt: number,
    heardAt: number,
    ownShot: boolean
): number?
    if distance ~= distance or distance < 0 or distance >= profile.far then
        return nil
    end
    if not (math.abs(emittedAt) < math.huge and math.abs(heardAt) < math.huge) then
        return nil
    end
    local propagation = if ownShot and profile.delay == 0 then 0 else math.min(distance / 610, 0.88)
    local due = emittedAt + profile.delay + propagation
    if due < heardAt - 0.4 or emittedAt > heardAt + 0.25 then
        return nil
    end
    return math.max(due, heardAt)
end

return WeaponSoundRules
