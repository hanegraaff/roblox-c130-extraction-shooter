--!strict
-- WeaponImpactEffects: consumes confirmed server contacts and observed rocket
-- flights. Owns only local, non-queryable parts and pooled particles. Times
-- are synchronized seconds and distances are world studs. No gameplay IO.
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rules = require(ReplicatedStorage.Shared.WeaponImpactRules)

local WeaponImpactEffects = {}
local textureRoot = "rbxasset://textures/particles/"
local smokeTexture = textureRoot .. "smoke_main.dds"
local fireTexture = textureRoot .. "explosion01_core_main.dds"
local sparkTexture = textureRoot .. "fire_sparks_main.dds"
local impactLimit = 12
local trailLimit = 8
local trailLifetime = 0.65
local metalTint = Color3.fromRGB(154, 149, 141)
local groundTint = Color3.fromRGB(125, 93, 67)
local solidTint = Color3.fromRGB(123, 122, 119)
local fireTint = Color3.fromRGB(255, 165, 77)
type Burst = {
    part: Part,
    socket: Attachment,
    fire: ParticleEmitter,
    smoke: ParticleEmitter,
    sparks: ParticleEmitter,
    untilTime: number,
    flashStarted: number,
    flashUntil: number,
    flashDiameter: number,
    flashGrowth: number,
    flashOpacity: number,
    priority: number,
}
type Trail = { part: Part, smoke: ParticleEmitter, untilTime: number, rocket: BasePart? }

-- update advances phase/round and expires local work. show admits transport
-- facts in the current generation and emits immediately without yielding.
-- stop destroys pools and subscriptions and may be called twice.
export type Controller = {
    update: (number, string, number, boolean, number) -> (),
    show: (unknown, unknown, unknown, unknown, unknown, unknown, unknown) -> boolean,
    stop: () -> (),
}

local function anchor(name: string): Part
    local part = Instance.new("Part")
    part.Name = name
    part.Size = Vector3.one * 0.1
    part.Transparency = 1
    part.Shape = Enum.PartType.Ball
    part.Material = Enum.Material.Neon
    part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
    part.CastShadow = false
    return part
end

local function emitter(socket: Attachment, name: string, texture: string): ParticleEmitter
    local effect = Instance.new("ParticleEmitter")
    effect.Name = name
    effect.Texture = texture
    effect.Enabled = false
    effect.EmissionDirection = Enum.NormalId.Front
    effect.Rotation = NumberRange.new(-180, 180)
    effect.RotSpeed = NumberRange.new(-60, 60)
    effect.Parent = socket
    return effect
end

local function fading(startOpacity: number): NumberSequence
    return NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1 - startOpacity),
        NumberSequenceKeypoint.new(0.18, 1 - startOpacity * 0.78),
        NumberSequenceKeypoint.new(1, 1),
    })
end

local function newBurst(): Burst
    local part = anchor("ImpactBurst")
    local socket = Instance.new("Attachment")
    socket.Parent = part
    local fire = emitter(socket, "Fireball", fireTexture)
    fire.Color = ColorSequence.new(Color3.fromRGB(255, 216, 117), Color3.fromRGB(203, 67, 20))
    fire.LightEmission = 0.7
    fire.Transparency = fading(0.86)
    fire.Drag = 5
    fire.SpreadAngle = Vector2.new(70, 70)
    local smoke = emitter(socket, "Smoke", smokeTexture)
    smoke.Drag = 3
    smoke.Acceleration = Vector3.new(0, 4, 0)
    smoke.SpreadAngle = Vector2.new(78, 78)
    local sparks = emitter(socket, "Sparks", sparkTexture)
    sparks.Color = ColorSequence.new(Color3.fromRGB(255, 218, 148), Color3.fromRGB(155, 92, 40))
    sparks.LightEmission = 0.55
    sparks.Lifetime = NumberRange.new(0.18, 0.42)
    sparks.Acceleration = Vector3.new(0, -40, 0)
    sparks.Transparency = fading(0.85)
    sparks.SpreadAngle = Vector2.new(58, 58)
    return {
        part = part,
        socket = socket,
        fire = fire,
        smoke = smoke,
        sparks = sparks,
        untilTime = 0,
        flashStarted = 0,
        flashUntil = 0,
        flashDiameter = 0,
        flashGrowth = 0,
        flashOpacity = 0,
        priority = 0,
    }
end

local function clearBurst(burst: Burst)
    burst.fire:Clear()
    burst.smoke:Clear()
    burst.sparks:Clear()
    burst.part.Parent = nil
    burst.untilTime = 0
end

local function newTrail(): Trail
    local part = anchor("RocketSmoke")
    local socket = Instance.new("Attachment")
    socket.Parent = part
    local smoke = emitter(socket, "Smoke", smokeTexture)
    smoke.Color = ColorSequence.new(Color3.fromRGB(187, 185, 173), Color3.fromRGB(113, 112, 105))
    smoke.Size = NumberSequence.new(0.55, 2.7)
    smoke.Transparency = fading(0.44)
    smoke.Lifetime = NumberRange.new(0.34, trailLifetime)
    smoke.Speed = NumberRange.new(1, 3)
    smoke.SpreadAngle = Vector2.new(25, 25)
    return { part = part, smoke = smoke, untilTime = 0, rocket = nil }
end

-- Keep the heavier plume visible after the fireball recedes. Starting
-- translucent limits the initial white overlap at the impact point.
local function risingSmoke(opacity: number): NumberSequence
    return NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1 - opacity * 0.45),
        NumberSequenceKeypoint.new(0.21, 1 - opacity),
        NumberSequenceKeypoint.new(0.64, 1 - opacity * 0.78),
        NumberSequenceKeypoint.new(1, 1),
    })
end

-- Full howitzer effects have a brief expanding flash and readable smoke at
-- orbit distances. Keep orbital Full below the near Ground emission budget,
-- and preserve a shorter, smaller silhouette for Reduced.
local function emitHeavy(burst: Burst, tint: Color3, full: boolean, thermal: boolean, distant: boolean)
    local fire = burst.fire
    fire.Lifetime = if full then NumberRange.new(0.24, 0.56) else NumberRange.new(0.12, 0.31)
    fire.Speed = if full then NumberRange.new(10, 30) else NumberRange.new(4, 13)
    fire.Size = if full then NumberSequence.new(7, 21) else NumberSequence.new(3.5, 9)
    fire:Emit(if not full then 2 elseif distant then 5 elseif thermal then 6 else 8)

    local smoke = burst.smoke
    smoke.Color = if thermal
        then ColorSequence.new(Color3.fromRGB(175, 175, 175), Color3.fromRGB(101, 101, 101))
        else ColorSequence.new(
            tint:Lerp(Color3.fromRGB(180, 174, 164), 0.45),
            Color3.fromRGB(85, 83, 78)
        )
    smoke.LightInfluence = if thermal then 0.18 else 0.6
    smoke.Transparency = risingSmoke(if not full then 0.2 elseif thermal then 0.44 else 0.52)
    smoke.Lifetime = if full then NumberRange.new(1.15, 1.75) else NumberRange.new(0.5, 0.95)
    smoke.Speed = if full then NumberRange.new(9, 21) else NumberRange.new(4, 11)
    smoke.Size = if full then NumberSequence.new(6, 22) else NumberSequence.new(2.5, 10)
    smoke:Emit(if not full then 3 elseif distant then 5 elseif thermal then 8 else 12)
end

local function clearTrail(trail: Trail)
    trail.smoke.Enabled = false
    trail.smoke:Clear()
    trail.part.Parent = nil
    trail.untilTime = 0
    trail.rocket = nil
end

-- Subscribes to the round's server-to-client impact stream. The client
-- independently caps visual cost and ages out confirmations after delivery.
function WeaponImpactEffects.new(state: Instance): Controller
    local holder = Instance.new("Folder")
    holder.Name = "LocalWeaponImpacts"
    local bursts: { Burst } = {}
    local trails: { Trail } = {}
    local history = Rules.history()
    local activeTrails: { [BasePart]: Trail? } = {}
    local round, phase, effects, thermal, clock = -1, "", 0, false, 0
    local stopped = false
    local listener: RBXScriptConnection? = nil
    local remote: RemoteEvent? = nil
    local resultsAt = -math.huge
    local function clear()
        for _, burst in bursts do
            clearBurst(burst)
        end
        for _, trail in trails do
            clearTrail(trail)
        end
        table.clear(activeTrails)
        holder.Parent = nil
    end
    local function reserveBurst(priority: number): Burst?
        local oldest: Burst? = nil
        for _, burst in bursts do
            if burst.untilTime == 0 then
                return burst
            end
            if burst.priority <= priority and (not oldest or burst.untilTime < oldest.untilTime) then
                oldest = burst
            end
        end
        if #bursts < impactLimit then
            local burst = newBurst()
            table.insert(bursts, burst)
            return burst
        end
        if oldest then
            clearBurst(oldest)
        end
        return oldest
    end

    local function show(
        weapon: unknown,
        eventRound: unknown,
        id: unknown,
        position: unknown,
        normal: unknown,
        surface: unknown,
        emittedAt: unknown
    ): boolean
        if
            stopped
            or effects <= 0
            or eventRound ~= round
            or (phase ~= "Active" and (phase ~= "Results" or clock - resultsAt > 0.75))
            or (weapon ~= "M102" and weapon ~= "GAU23" and weapon ~= "Rocket")
            or (surface ~= "Ground" and surface ~= "Solid" and surface ~= "Metal")
            or type(id) ~= "string"
            or type(emittedAt) ~= "number"
            or typeof(position) ~= "Vector3"
            or not (position.Magnitude < math.huge)
            or typeof(normal) ~= "Vector3"
            or not (math.abs(normal.Magnitude - 1) <= 0.01)
        then
            return false
        end
        local camera = workspace.CurrentCamera
        if not camera then
            return false
        end
        local heavy = weapon == "M102"
        local light = weapon == "GAU23"
        local distance = (position - camera.CFrame.Position).Magnitude
        if distance > (if light then 410 else 850) or not history.admit(weapon, id, emittedAt, clock) then
            return false
        end
        local burst = reserveBurst(if light then 1 else 2)
        if not burst then
            return false
        end
        local full = effects >= 0.9
        local reduced = not full or thermal or distance > 400
        local distant = distance > 550
        local flashSize = if heavy then (if full then 7.5 else 4) elseif light then 0.8 else 3.2
        -- Keep the growing fireball on the incoming side of the actual surface.
        -- Particles start at contact through the offset socket.
        local flashOffset = if heavy then (if full then 5.8 else 2.8) elseif light then 0.5 else 1.8
        local point = position + normal * flashOffset
        burst.part.CFrame = CFrame.lookAt(point, point + normal)
        burst.socket.Position = Vector3.new(0, 0, flashOffset - 0.1)
        burst.part.Size = Vector3.one * flashSize
        burst.part.Color = fireTint
        local opacity = if heavy and full then 0.87 elseif reduced then 0.45 else 0.75
        burst.part.Transparency = 1 - opacity
        burst.part:SetAttribute("Weapon", weapon)
        burst.part:SetAttribute("ShotId", id)
        burst.part:SetAttribute("ImpactPoint", position)
        burst.part:SetAttribute("Surface", surface)
        burst.part:SetAttribute("ReceivedSeconds", clock)
        burst.flashStarted = clock
        burst.flashUntil = clock
            + (if heavy then (if full then 0.17 else 0.09) elseif light then 0.05 else 0.11)
        burst.flashDiameter = flashSize
        burst.flashGrowth = if heavy then (if full then 5.5 else 2) elseif light then 0.4 else 1.8
        burst.flashOpacity = opacity
        burst.untilTime = clock + (if heavy then (if full then 1.8 else 1) elseif light then 0.58 else 1.1)
        burst.priority = if light then 1 else 2
        holder.Parent = workspace
        burst.part.Parent = holder

        local spark = burst.sparks
        spark.Size = NumberSequence.new(if heavy then 0.38 elseif light then 0.13 else 0.26, 0)
        spark.Speed = if heavy
            then NumberRange.new(21, 48)
            elseif light then NumberRange.new(8, 22)
            else NumberRange.new(16, 32)
        spark:Emit(
            if heavy and full
                then (if distant then 10 elseif thermal then 14 else 20)
                elseif reduced then (if light then 3 else 7)
                elseif light then 6
                else 13
        )
        local tint = if surface == "Ground"
            then groundTint
            elseif surface == "Metal" then metalTint
            else solidTint
        if heavy then
            emitHeavy(burst, tint, full, thermal, distant)
            return true
        end

        local smoke = burst.smoke
        smoke.LightInfluence = 0.6
        smoke.Color = ColorSequence.new(tint, Color3.fromRGB(78, 78, 77))
        smoke.Transparency =
            fading(if thermal then (if light then 0.2 else 0.29) elseif reduced then 0.24 else 0.46)
        smoke.Size = if light then NumberSequence.new(0.7, 2.8) else NumberSequence.new(2.5, 9)
        smoke.Lifetime = if light then NumberRange.new(0.3, 0.53) else NumberRange.new(0.65, 1.05)
        smoke.Speed = if light then NumberRange.new(2, 5) else NumberRange.new(5, 11)
        if distance < 620 then
            smoke:Emit(if reduced then 1 elseif light then 2 else 6)
        end
        if not light then
            local fire = burst.fire
            fire.Lifetime = NumberRange.new(0.15, 0.32)
            fire.Speed = NumberRange.new(5, 14)
            fire.Size = NumberSequence.new(2, 8)
            fire:Emit(if reduced then 2 else 4)
        end
        return true
    end

    local function attach(child: Instance)
        if not listener and child.Name == "WeaponImpact" and child:IsA("RemoteEvent") then
            remote = child
            listener = child.OnClientEvent:Connect(show)
        end
    end
    local added = state.ChildAdded:Connect(attach)
    local removed = state.ChildRemoved:Connect(function(child)
        if child == remote and listener then
            listener:Disconnect()
            listener, remote = nil, nil
        end
    end)
    local initial = state:FindFirstChild("WeaponImpact")
    if initial then
        attach(initial)
    end
    local preloadTextures: { Instance } = {}
    for _, texture in { smokeTexture, fireTexture, sparkTexture } do
        local reference = Instance.new("ParticleEmitter")
        reference.Texture = texture
        table.insert(preloadTextures, reference)
    end
    local function destroyPreloadTextures()
        for _, reference in preloadTextures do
            reference:Destroy()
        end
        table.clear(preloadTextures)
    end
    local preload = task.defer(function()
        ContentProvider:PreloadAsync(preloadTextures)
        destroyPreloadTextures()
    end)

    local function updateTrails()
        local folder = workspace:FindFirstChild("LauncherEffects")
        local camera = workspace.CurrentCamera
        for _, trail in trails do
            local rocket = trail.rocket
            if rocket then
                if not folder or rocket.Parent ~= folder or phase ~= "Active" then
                    activeTrails[rocket] = nil
                    trail.rocket = nil
                    trail.smoke.Enabled = false
                    trail.untilTime = clock + trailLifetime
                else
                    trail.part.CFrame = rocket.CFrame * CFrame.new(0, 0, 0.9) * CFrame.Angles(0, math.pi, 0)
                    local near = camera ~= nil and (rocket.Position - camera.CFrame.Position).Magnitude < 410
                    trail.smoke.Enabled = near
                    trail.smoke.Rate = if thermal or effects < 0.9 then 12 else 28
                end
            elseif trail.untilTime > 0 and clock >= trail.untilTime then
                clearTrail(trail)
            end
        end
        if phase ~= "Active" or not folder or not camera then
            return
        end
        for _, rocket in folder:GetChildren() do
            if
                rocket:IsA("BasePart")
                and rocket.Name == "Rocket"
                and rocket:GetAttribute("FlightRoundId") == round
                and not activeTrails[rocket]
                and (rocket.Position - camera.CFrame.Position).Magnitude < 410
            then
                local slot: Trail? = nil
                for _, trail in trails do
                    if not trail.rocket and trail.untilTime == 0 then
                        slot = trail
                        break
                    end
                end
                if not slot and #trails < trailLimit then
                    local created = newTrail()
                    table.insert(trails, created)
                    slot = created
                end
                if slot then
                    slot.rocket = rocket
                    activeTrails[rocket] = slot
                    slot.part.CFrame = rocket.CFrame
                    holder.Parent = workspace
                    slot.part.Parent = holder
                end
            end
        end
    end
    return {
        show = show,
        update = function(nextRound, nextPhase, intensity, operatorView, seconds)
            if stopped then
                return
            end
            if nextPhase == "Results" and phase ~= "Results" then
                resultsAt = seconds
            end
            if
                nextRound ~= round
                or (nextPhase ~= "Active" and nextPhase ~= "Results")
                or (effects > 0 and intensity <= 0)
            then
                clear()
            end
            if nextRound ~= round then
                history.clear()
            end
            round, phase, effects, thermal, clock = nextRound, nextPhase, intensity, operatorView, seconds
            if effects <= 0 or (phase ~= "Active" and phase ~= "Results") then
                return
            end
            for _, burst in bursts do
                if burst.untilTime > 0 then
                    if clock >= burst.untilTime then
                        clearBurst(burst)
                    elseif clock < burst.flashUntil then
                        local progress = math.clamp(
                            (clock - burst.flashStarted) / (burst.flashUntil - burst.flashStarted),
                            0,
                            1
                        )
                        burst.part.Size = Vector3.one * (burst.flashDiameter + burst.flashGrowth * progress)
                        burst.part.Transparency = 1 - burst.flashOpacity * (1 - progress)
                    elseif burst.part.Transparency < 1 then
                        burst.part.Transparency = 1
                    end
                end
            end
            updateTrails()
        end,
        stop = function()
            if stopped then
                return
            end
            stopped = true
            added:Disconnect()
            removed:Disconnect()
            if listener then
                listener:Disconnect()
            end
            if coroutine.status(preload) ~= "dead" then
                task.cancel(preload)
            end
            destroyPreloadTextures()
            clear()
            for _, burst in bursts do
                burst.part:Destroy()
            end
            for _, trail in trails do
                trail.part:Destroy()
            end
            holder:Destroy()
        end,
    }
end

return WeaponImpactEffects
