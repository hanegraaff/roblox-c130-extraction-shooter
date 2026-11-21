--!strict
-- WeaponAudio: positional client playback of server-admitted combat cues.
-- Uses the existing round update clock. The bounded queue and voices are
-- destroyed at mute, phase/round change or teardown. Contains no gameplay IO.
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rules = require(ReplicatedStorage.Shared.WeaponSoundRules)

local WeaponAudio = {}

type Pending = { cue: string, profile: Rules.Profile, origin: Vector3, due: number }
type Voice = { part: Part, sound: Sound, expires: number, volume: number }

export type Controller = {
    update: (number, boolean, number, number) -> (),
    stop: () -> (),
}

local pendingLimit = 48
local voiceLimit = 24

-- Attaches to the provided round state. All playback and positioning are local.
-- update takes round ID, Active, intensity in [0,1] and synchronized seconds.
function WeaponAudio.new(state: Instance, player: Player): Controller
    local pending: { Pending } = {}
    local voices: { Voice } = {}
    local holder = Instance.new("Folder")
    holder.Name = "LocalWeaponAudio"
    local listener: RBXScriptConnection? = nil
    local round, active, scale = -1, false, 0
    local stopped = false

    local function retire(index: number)
        local voice = assert(table.remove(voices, index), "weapon audio voice index missing")
        voice.part:Destroy()
    end

    local function clear()
        table.clear(pending)
        for index = #voices, 1, -1 do
            retire(index)
        end
        holder.Parent = nil
    end

    local function receive(
        cue: unknown,
        eventRound: unknown,
        origin: unknown,
        seconds: unknown,
        shooter: unknown
    )
        local profile = Rules.profile(cue)
        if
            not active
            or scale == 0
            or eventRound ~= round
            or type(cue) ~= "string"
            or not profile
            or typeof(origin) ~= "Vector3"
            or type(seconds) ~= "number"
        then
            return
        end
        local camera = workspace.CurrentCamera
        if not camera then
            return
        end
        local distance = (origin - camera.CFrame.Position).Magnitude
        local due =
            Rules.due(profile, distance, seconds, workspace:GetServerTimeNow(), shooter == player.UserId)
        if due and #pending < pendingLimit then
            table.insert(pending, { cue = cue, profile = profile, origin = origin, due = due })
        end
    end

    local function attach(child: Instance)
        if not listener and child.Name == "WeaponAudio" and child:IsA("UnreliableRemoteEvent") then
            listener = child.OnClientEvent:Connect(receive)
        end
    end

    local added = state.ChildAdded:Connect(attach)
    local current = state:FindFirstChild("WeaponAudio")
    if current then
        attach(current)
    end
    local preload = task.defer(function()
        ContentProvider:PreloadAsync({
            assert(Rules.profile("GAU23"), "missing gunship effect").asset,
            assert(Rules.profile("M102"), "missing howitzer effect").asset,
            assert(Rules.profile("M7"), "missing rifle effect").asset,
            assert(Rules.profile("RocketLaunch"), "missing launcher effect").asset,
        })
    end)

    local function play(item: Pending, seconds: number)
        if #voices >= voiceLimit then
            retire(1)
        end
        local profile = item.profile
        local source = Instance.new("Part")
        source.Name = item.cue
        source.Size = Vector3.one
        source.Anchored, source.CanCollide, source.CanTouch, source.CanQuery = true, false, false, false
        source.Transparency = 1
        source.Position = item.origin
        source:SetAttribute("DueSeconds", item.due)
        source:SetAttribute("PlayedSeconds", seconds)

        local sound = Instance.new("Sound")
        sound.SoundId = profile.asset
        sound.Volume = profile.volume * scale
        sound.PlaybackSpeed = profile.speed
        sound.RollOffMode = Enum.RollOffMode.InverseTapered
        sound.RollOffMinDistance, sound.RollOffMaxDistance = profile.near, profile.far
        local equalizer = Instance.new("EqualizerSoundEffect")
        equalizer.HighGain = profile.highGain
        equalizer.LowGain = profile.lowGain
        equalizer.Parent = sound
        sound.Parent = source
        holder.Parent = workspace
        source.Parent = holder
        sound:Play()
        table.insert(
            voices,
            { part = source, sound = sound, expires = seconds + profile.duration, volume = profile.volume }
        )
    end

    return {
        update = function(roundId, roundActive, intensity, seconds)
            if stopped then
                return
            end
            if roundId ~= round or (active and not roundActive) or (scale > 0 and intensity == 0) then
                clear()
            end
            round, active, scale = roundId, roundActive, intensity
            if not active or scale == 0 then
                return
            end
            for index = #voices, 1, -1 do
                local voice = voices[index]
                if seconds >= voice.expires then
                    retire(index)
                else
                    local tail = math.min((voice.expires - seconds) / 0.07, 1)
                    voice.sound.Volume = voice.volume * scale * tail
                end
            end
            for index = #pending, 1, -1 do
                local item = pending[index]
                if seconds >= item.due then
                    table.remove(pending, index)
                    if seconds - item.due <= 0.4 then
                        play(item, seconds)
                    end
                end
            end
        end,
        stop = function()
            if stopped then
                return
            end
            stopped = true
            added:Disconnect()
            if listener then
                listener:Disconnect()
                listener = nil
            end
            if coroutine.status(preload) ~= "dead" then
                task.cancel(preload)
            end
            clear()
            holder:Destroy()
        end,
    }
end

return WeaponAudio
