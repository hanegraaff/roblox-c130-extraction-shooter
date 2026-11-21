--!strict
--[=[
    PresentationEffects: local, nonyielding feedback from replicated combat and
    result facts. Owns two bundled Roblox cue sounds and a short inert destruction
    animation. Warning text remains available at every intensity. No changes to
    authoritative effects, world geometry, inputs or active camera projection.
]=]
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local PresentationEffects = {}

export type Frame = { text: string?, pulse: number, destructionAge: number? }
export type Controller = {
    update: (string, number, string?, number, number) -> Frame,
    stop: () -> (),
}

local warningRadiusStuds = 24
local destructionSeconds = 2.4

local function makeSound(name: string, id: string): Sound
    local sound = Instance.new("Sound")
    sound.Name = name
    sound.SoundId = id
    sound.Parent = SoundService
    return sound
end

local function play(sound: Sound, volume: number)
    if volume > 0 then
        sound.Volume = volume
        sound:Stop()
        sound:Play()
    end
end

local function warningNearby(player: Player): boolean
    local character = player.Character
    local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
    local effects = workspace:FindFirstChild("CombatEffects")
    if not root or not root:IsA("BasePart") or not effects then
        return false
    end
    for _, marker in effects:GetChildren() do
        if
            marker:IsA("BasePart")
            and marker:GetAttribute("Stage") == "Warning"
            and (marker.Position - root.Position).Magnitude <= warningRadiusStuds
        then
            return true
        end
    end
    return false
end

local function impactText(encoded: string, roundId: number): string?
    local ok, data = pcall(function()
        return HttpService:JSONDecode(encoded)
    end)
    if not ok or type(data) ~= "table" or data.roundId ~= roundId then
        return nil
    end
    local caliber = if data.weapon == "GAU23" then "30MM" elseif data.weapon == "M102" then "105MM" else nil
    if not caliber then
        return nil
    end
    return caliber .. (if type(data.panelId) == "string" then " • PANEL IMPACT" else " • IMPACT")
end

-- Creates one local effect owner. update takes the current view and round, an
-- optional current-round result reason, monotonic seconds and a [0, 1] scale.
-- stop clears all resources; repeated calls are harmless.
function PresentationEffects.new(player: Player): Controller
    local ping = makeSound("RoundCueSound", "rbxasset://sounds/volume_slider.ogg")
    local blast = makeSound("RoundDestructionSound", "rbxasset://sounds/impact_explosion_03.mp3")
    local round, lastView = -1, ""
    local cue: string? = nil
    local cueStarted, cueUntil = 0, 0
    local resultStarted: number? = nil
    local lastImpact: string? = nil
    local nextWarningScan = 0
    local burst: Part? = nil
    local stopped = false

    local function setCue(text: string, now: number, duration: number)
        cue = text
        cueStarted = now
        cueUntil = now + duration
    end

    local function clearBurst()
        if burst then
            burst:Destroy()
            burst = nil
        end
    end

    local function clear()
        clearBurst()
        ping:Stop()
        blast:Stop()
        cue = nil
        cueUntil = 0
        resultStarted = nil
        lastImpact = nil
        nextWarningScan = 0
    end

    local function updateBurst(age: number, scale: number)
        if age >= 0.8 or scale == 0 then
            clearBurst()
            return
        end
        local model = workspace:FindFirstChild("Aircraft")
        local hitbox = if model then model:FindFirstChild("Hitbox") else nil
        if not hitbox or not hitbox:IsA("BasePart") then
            return
        end
        local light: Part
        if burst then
            light = burst
        else
            light = Instance.new("Part")
            light.Name = "RoundDestructionBurst"
            light.Anchored = true
            light.CanCollide = false
            light.CanTouch = false
            light.CanQuery = false
            light.CastShadow = false
            light.Shape = Enum.PartType.Ball
            light.Material = Enum.Material.Neon
            light.Color = Color3.fromRGB(255, 177, 90)
            light.Position = hitbox.Position
        end
        local progress = math.clamp(age / 0.8, 0, 1)
        light.Size = Vector3.one * (6 + 44 * progress * scale)
        light.Transparency = 1 - 0.48 * (1 - progress) * scale
        light.Parent = workspace
        burst = light
    end

    local function update(view: string, roundId: number, result: string?, now: number, scale: number): Frame
        if stopped then
            return { text = nil, pulse = 0, destructionAge = nil }
        end
        if roundId ~= round or view ~= lastView then
            clear()
            round, lastView = roundId, view
        end
        ping.Volume = math.min(ping.Volume, 0.28 * scale)
        blast.Volume = math.min(blast.Volume, 0.32 * scale)
        if view == "Ground" and now >= nextWarningScan then
            nextWarningScan = now + 0.08
            if warningNearby(player) then
                setCue("INCOMING GUNSHIP FIRE", now, 0.45)
            end
        elseif view == "Operator" then
            local state = ReplicatedStorage:FindFirstChild("AircraftState")
            local encoded = if state then state:GetAttribute("Impact") else nil
            if type(encoded) == "string" and encoded ~= lastImpact then
                lastImpact = encoded
                local text = impactText(encoded, roundId)
                if text then
                    setCue(text, now, 1.1)
                end
            end
        elseif view == "Results" and result and resultStarted == nil then
            resultStarted = now
            if result == "AircraftDestroyed" then
                setCue("C-130 DESTROYED", now, destructionSeconds)
                play(blast, 0.32 * scale)
            else
                play(ping, 0.24 * scale)
            end
        end
        local started = resultStarted
        local age = if started and result == "AircraftDestroyed" then now - started else nil
        if age then
            updateBurst(age, scale)
        end
        local visibleCue = if now < cueUntil then cue else nil
        return {
            text = visibleCue,
            pulse = if visibleCue then math.max(0, 1 - (now - cueStarted) * 2) * scale else 0,
            destructionAge = if age and age < destructionSeconds then age else nil,
        }
    end

    return {
        update = update,
        stop = function()
            if not stopped then
                stopped = true
                clear()
                ping:Destroy()
                blast:Destroy()
            end
        end,
    }
end

return PresentationEffects
