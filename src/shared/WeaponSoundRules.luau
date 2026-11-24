--!strict
-- Weapon sound mix and distance timing. Runs on clients and in host tests with
-- scalar inputs only. Delays are presentation tuning in seconds and studs.
local WeaponSoundRules = {}

export type Cue = "GAU23" | "M102" | "LightImpact" | "HeavyImpact" | "M7" | "RocketLaunch" | "RocketImpact"
-- Server presentation relay. Optional coarse surface selects a local mix.
export type Emit = (Cue, number, Vector3, number, number?, string?) -> ()
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
local rifle = "rbxassetid://9113189096"
local rocket = "rbxassetid://9120729973"
-- Approved platform sounds only. Pending or unavailable imports use this
-- bundled cue with the requested timing, envelope and equalizer.
WeaponSoundRules.fallbackAsset = blast
local profiles: { [string]: Profile } = {
    GAU23 = {
        asset = rifle,
        volume = 0.69,
        speed = 1.44,
        duration = 0.19,
        near = 105,
        far = 850,
        highGain = -9,
        lowGain = 1.5,
        delay = 0.13,
    },
    M102 = {
        asset = "rbxassetid://9120018088",
        volume = 0.98,
        speed = 0.83,
        duration = 1.48,
        near = 135,
        far = 960,
        highGain = -14,
        lowGain = 4,
        delay = 0.19,
    },
    LightImpact = {
        asset = blast,
        volume = 0.22,
        speed = 1.8,
        duration = 0.17,
        near = 24,
        far = 360,
        highGain = -6,
        lowGain = -6,
        delay = 0.06,
    },
    HeavyImpact = {
        asset = blast,
        volume = 0.82,
        speed = 0.73,
        duration = 1.22,
        near = 43,
        far = 620,
        highGain = -8,
        lowGain = 5,
        delay = 0.09,
    },
    M7 = {
        asset = rifle,
        volume = 0.66,
        speed = 1,
        duration = 0.42,
        near = 20,
        far = 470,
        highGain = 1,
        lowGain = -2,
        delay = 0,
    },
    RocketLaunch = {
        asset = rocket,
        volume = 0.83,
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
        volume = 0.76,
        speed = 1.04,
        duration = 0.74,
        near = 42,
        far = 620,
        highGain = -3,
        lowGain = 1.5,
        delay = 0.03,
    },
}

for _, profile in profiles do
    table.freeze(profile)
end

local function colored(profile: Profile, highGain: number, lowGain: number, speed: number): Profile
    local result = table.clone(profile)
    result.highGain, result.lowGain, result.speed = highGain, lowGain, speed
    return table.freeze(result)
end

local surfaceProfiles: { [string]: { [string]: Profile } } = {
    Ground = {
        LightImpact = colored(profiles.LightImpact, -11, -3, 1.66),
        HeavyImpact = colored(profiles.HeavyImpact, -13, 5, 0.71),
        RocketImpact = colored(profiles.RocketImpact, -8, 3, 0.97),
    },
    Metal = {
        LightImpact = colored(profiles.LightImpact, -2, -6, 1.94),
        HeavyImpact = colored(profiles.HeavyImpact, -5, 4, 0.77),
        RocketImpact = colored(profiles.RocketImpact, 1, 0, 1.13),
    },
}

-- Returns a frozen mix profile or nil for an unsupported presentation cue.
function WeaponSoundRules.profile(cue: unknown, surface: unknown?): Profile?
    if type(cue) ~= "string" then
        return nil
    end
    local variants = if type(surface) == "string" then surfaceProfiles[surface] else nil
    return (if variants then variants[cue] else nil) or profiles[cue]
end

-- Preload the distinct referenced samples off the firing path.
function WeaponSoundRules.assets(): { string }
    return { blast, rifle, rocket, profiles.M102.asset }
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
