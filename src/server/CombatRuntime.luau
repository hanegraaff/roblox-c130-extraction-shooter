--!strict
--[=[
    CombatRuntime: server engine adapter for aircraft shots, collision and health.
    Depends on MatchService, AircraftService, CombatService and workspace geometry.
    Clients supply only bounded target intent; all origins, collision and damage are
    computed on the server. Each round invalidates in-flight shots, effects and budgets.
    stop disconnects every listener and destroys owned replicated state and effects.
]=]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Debris = game:GetService("Debris")
local RateLimit = require(ReplicatedStorage.Shared.RateLimit)
local AircraftService = require(script.Parent.AircraftService)
local MatchService = require(script.Parent.MatchService)
local CombatService = require(script.Parent.CombatService)
local CombatViewRules = require(script.Parent.CombatViewRules)
local DamageRules = require(script.Parent.DamageRules)
local CombatRuntime = {}

-- Impact is a server-resolved direct collision seam for the future panel service.
-- panelId is nil for terrain/players or unregistered parts. No panel damage occurs.
export type Impact = {
    roundId: number,
    shotId: number,
    weapon: string,
    position: Vector3,
    panelId: string?,
    time: number,
}
export type Controller = {
    stop: () -> (),
    resources: () -> { connections: number, projectiles: number },
    onImpact: (Impact) -> (),
}
type Projectile = {
    shot: CombatService.Shot,
    position: Vector3,
    direction: Vector3,
    remaining: number,
    visual: Part,
    marker: Part,
    awards: DamageRules.Controller,
}

-- Sweeps the finite shell radius through authoritative query geometry. A zero
-- displacement cannot produce a collision. The caller supplies engine-owned
-- query filters; this synchronous query never mutates the world or yields.
function CombatRuntime.sweep(
    origin: Vector3,
    radius: number,
    displacement: Vector3,
    params: RaycastParams
): RaycastResult?
    if displacement.Magnitude == 0 then
        return nil
    end
    return workspace:Spherecast(origin, radius, displacement, params)
end

-- Spherecast does not report parts already intersecting its starting volume.
-- This exact overlap query uses an owned, invisible spherical probe at the muzzle;
-- solid cover is prioritized over characters if both intersect simultaneously.
-- The caller parents/positions the probe in Workspace and owns its cleanup.
function CombatRuntime.initialOverlap(
    probe: BasePart,
    params: OverlapParams,
    battlefield: Instance
): BasePart?
    local characterHit: BasePart? = nil
    for _, part in workspace:GetPartsInPart(probe, params) do
        if part:IsDescendantOf(battlefield) then
            if part.CanCollide then
                return part
            end
        elseif not characterHit then
            characterHit = part
        end
    end
    return characterHit
end

-- Starts one engine owner. optional onImpact is called synchronously after resolution;
-- it must not yield or reenter the owner. A valid callback is not a destruction award.
-- Optional monotonic clock and heartbeat are injected boundaries; production defaults
-- use synchronized server seconds and RunService.Heartbeat. Caller owns the signal.
function CombatRuntime.start(
    match: MatchService.Controller,
    aircraft: AircraftService.Controller,
    onImpact: ((Impact) -> ())?,
    clock: (() -> number)?,
    heartbeat: RBXScriptSignal?
): (Controller?, string?)
    local aircraftState = ReplicatedStorage:FindFirstChild("AircraftState")
    if not aircraftState or aircraftState:FindFirstChild("FireWeapon") then
        return nil, "aircraft fire transport unavailable or owned"
    end
    local map, minimumY, maximumY = aircraft.level()
    local combat = CombatService.new(map, minimumY, maximumY)
    local remote = Instance.new("RemoteEvent")
    remote.Name = "FireWeapon"
    remote.Parent = aircraftState
    local effects = Instance.new("Folder")
    effects.Name = "CombatEffects"
    effects.Parent = workspace
    local muzzleProbe = Instance.new("Part")
    muzzleProbe.Name = "CombatMuzzleProbe"
    muzzleProbe.Shape = Enum.PartType.Ball
    muzzleProbe.Size = Vector3.one * 0.1
    muzzleProbe.Transparency = 1
    muzzleProbe.Anchored = true
    muzzleProbe.CanCollide = false
    muzzleProbe.CanTouch = false
    muzzleProbe.CanQuery = false
    muzzleProbe.Parent = workspace
    local buckets: { [Player]: RateLimit.Bucket } = {}
    local connections: { RBXScriptConnection } = {}
    local projectiles: { Projectile } = {}
    local running = true
    local lastRound = -1
    local lastReadiness = ""
    local emit = onImpact or function(_impact: Impact) end
    local now: () -> number = clock or function(): number
        return workspace:GetServerTimeNow()
    end
    local frameSignal = heartbeat or RunService.Heartbeat
    local function clear()
        for _, projectile in projectiles do
            projectile.visual:Destroy()
            projectile.marker:Destroy()
        end
        table.clear(projectiles)
        table.clear(buckets)
        effects:ClearAllChildren()
    end
    local function publish(time: number)
        local gau = combat.readiness("GAU23", time)
        local heavy = combat.readiness("M102", time)
        if gau and heavy then
            local encoded = HttpService:JSONEncode({ GAU23 = gau, M102 = heavy })
            if encoded ~= lastReadiness then
                lastReadiness = encoded
                aircraftState:SetAttribute("Readiness", encoded)
            end
        end
    end
    local function geometry(): { Instance }
        local battlefield = workspace.World:FindFirstChild("Battlefield")
        return if battlefield then { battlefield, workspace.Terrain } else { workspace.Terrain }
    end
    local function rayParameters(includeCharacters: boolean): RaycastParams
        local roots = geometry()
        if includeCharacters then
            for _, player in Players:GetPlayers() do
                if
                    player.Character
                    and player:GetAttribute("Role") == "Ground"
                    and player:GetAttribute("Life") == "Alive"
                then
                    table.insert(roots, player.Character)
                end
            end
        end
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Include
        params.FilterDescendantsInstances = roots
        params.RespectCanCollide = not includeCharacters
        return params
    end
    -- Resolve the entire impact against unchanged cover; no destructible mutation is
    -- performed here. One iteration per player ensures no direct-plus-splash award.
    local function impact(
        projectile: Projectile,
        position: Vector3,
        hit: Instance?,
        time: number,
        embeddedInCover: boolean?
    ): boolean
        local state = match.snapshot()
        if
            state.phase ~= "Active"
            or state.roundId ~= projectile.shot.roundId
            or time >= state.deadlineSeconds
        then
            return false
        end
        local profile = CombatService.profiles[projectile.shot.weapon]
        if not profile then
            return false
        end
        local panelId: string? = nil
        if hit then
            local id = hit:GetAttribute("PanelId")
            if type(id) == "string" then
                panelId = id
            end
        end
        local visibilityOrigin = position - projectile.direction * 0.1
        for _, player in Players:GetPlayers() do
            local member = state.members[player.UserId]
            local character = player.Character
            local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
            local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
            if
                not embeddedInCover
                and member
                and member.connected
                and member.role == "Ground"
                and member.life == "Alive"
                and humanoid
                and humanoid.Health > 0
                and root
                and root:IsA("BasePart")
            then
                local direct = hit ~= nil and character ~= nil and hit:IsDescendantOf(character)
                local delta = root.Position - visibilityOrigin
                if direct or delta.Magnitude <= profile.radius then
                    local obstruction = workspace:Raycast(visibilityOrigin, delta, rayParameters(false))
                    if direct or obstruction == nil then
                        local damage = projectile.awards.award(
                            player.UserId,
                            humanoid.Health,
                            humanoid.MaxHealth,
                            profile.damage
                        )
                        if damage then
                            humanoid:TakeDamage(damage)
                            if humanoid.Health <= 0 then
                                match.eliminate(player.UserId, state.roundId)
                            end
                        end
                    end
                end
            end
        end
        aircraftState:SetAttribute(
            "Impact",
            HttpService:JSONEncode({
                roundId = state.roundId,
                shotId = projectile.shot.shotId,
                weapon = projectile.shot.weapon,
                x = position.X,
                y = position.Y,
                z = position.Z,
                panelId = panelId,
            })
        )
        projectile.marker.Name = "Impact"
        projectile.marker:SetAttribute("Stage", "Impact")
        projectile.marker.Shape = Enum.PartType.Ball
        projectile.marker.Position = position
        projectile.marker.Size = Vector3.one * (if projectile.shot.weapon == "M102" then 18 else 4)
        projectile.marker.Transparency = 0.2
        Debris:AddItem(projectile.marker, 0.35)
        emit({
            roundId = state.roundId,
            shotId = projectile.shot.shotId,
            weapon = projectile.shot.weapon,
            position = position,
            panelId = panelId,
            time = time,
        })
        match.step()
        return true
    end
    table.insert(
        connections,
        remote.OnServerEvent:Connect(function(player: Player, payload: unknown)
            local time = now()
            local bucket = buckets[player]
            if not bucket then
                bucket = assert(RateLimit.new(12, 8, time), "valid fire budget")
                buckets[player] = bucket
            end
            if not RateLimit.take(bucket, time) then
                return
            end
            local state = match.snapshot()
            local member = state.members[player.UserId]
            local eligible = state.phase == "Active"
                and time < state.deadlineSeconds
                and member ~= nil
                and member.connected
                and member.role == "Gunship"
                and member.life == "Alive"
            -- Reject spectators, stale phases and deadline expiry before any
            -- camera geometry search or world query.
            if not eligible then
                return
            end
            local weapon = aircraft.weapon()
            local muzzle = aircraft.muzzle(weapon)
            if not muzzle then
                return
            end
            local camera = aircraft.position()
            local command = CombatViewRules.validate(payload, map, weapon, camera.X, camera.Z)
            if not command then
                return
            end
            local shot =
                combat.fire(player.UserId, command, weapon, eligible, time, muzzle.X, muzzle.Y, muzzle.Z)
            if not shot then
                return
            end
            local target = Vector3.new(shot.x, shot.y, shot.z)
            local delta = target - muzzle
            local visual = Instance.new("Part")
            visual.Name = "Projectile"
            visual:SetAttribute("Weapon", weapon)
            visual:SetAttribute("Stage", "Flight")
            visual.Size = if weapon == "M102" then Vector3.one * 4 else Vector3.new(7, 0.8, 0.8)
            visual.Shape = if weapon == "M102" then Enum.PartType.Ball else Enum.PartType.Cylinder
            visual.Material = Enum.Material.Neon
            visual.Color = if weapon == "M102"
                then Color3.fromRGB(255, 125, 35)
                else Color3.fromRGB(255, 242, 150)
            visual.Anchored = true
            visual.CanCollide = false
            visual.CanTouch = false
            visual.CanQuery = false
            visual.CFrame = CFrame.lookAt(muzzle, target) * CFrame.Angles(0, math.pi / 2, 0)
            visual.Parent = effects
            local marker = Instance.new("Part")
            marker.Name = "ImpactWarning"
            marker:SetAttribute("Weapon", weapon)
            marker:SetAttribute("Stage", "Warning")
            marker.Shape = Enum.PartType.Cylinder
            marker.Size = if weapon == "M102" then Vector3.new(0.3, 22, 22) else Vector3.new(0.2, 5, 5)
            marker.Material = Enum.Material.Neon
            marker.Color = visual.Color
            marker.Transparency = 0.65
            marker.Anchored = true
            marker.CanCollide = false
            marker.CanTouch = false
            marker.CanQuery = false
            marker.CFrame = CFrame.new(target + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.pi / 2)
            marker.Parent = effects
            local projectile: Projectile = {
                shot = shot,
                position = muzzle,
                direction = delta.Unit,
                -- Camera raycast endpoints lie on surfaces. Allow a small bounded
                -- continuation so floating-point rounding does not end the server
                -- sweep just short of that surface; only actual hits can detonate.
                remaining = math.min(delta.Magnitude + 0.25, CombatService.profiles[weapon].range),
                visual = visual,
                marker = marker,
                awards = DamageRules.new(),
            }
            muzzleProbe.Position = muzzle
            local overlap = OverlapParams.new()
            overlap.FilterType = Enum.RaycastFilterType.Include
            overlap.FilterDescendantsInstances = rayParameters(true).FilterDescendantsInstances
            overlap.RespectCanCollide = false
            local battlefield = workspace.World:FindFirstChild("Battlefield")
            local initialHit = if battlefield
                then CombatRuntime.initialOverlap(muzzleProbe, overlap, battlefield)
                else nil
            if initialHit then
                -- A ray starting inside a solid can leave it without reporting an
                -- intersection. Conservatively suppress all splash for this rare
                -- embedded-cover impact rather than granting damage through cover.
                local embeddedInCover = battlefield ~= nil and initialHit:IsDescendantOf(battlefield)
                if not impact(projectile, muzzle, initialHit, time, embeddedInCover) then
                    marker:Destroy()
                end
                visual:Destroy()
            else
                table.insert(projectiles, projectile)
            end
            publish(time)
        end)
    )
    table.insert(
        connections,
        Players.PlayerRemoving:Connect(function(player)
            buckets[player] = nil
        end)
    )
    table.insert(
        connections,
        frameSignal:Connect(function(dt)
            local time = now()
            local state = match.snapshot()
            if state.roundId ~= lastRound then
                clear()
                aircraftState:SetAttribute("Impact", nil)
                lastRound = state.roundId
                combat.reset(lastRound)
                publish(time)
            end
            if state.phase ~= "Active" or time >= state.deadlineSeconds then
                if #projectiles > 0 then
                    clear()
                end
                return
            end
            for i = #projectiles, 1, -1 do
                local projectile = projectiles[i]
                local profile = CombatService.profiles[projectile.shot.weapon]
                local distance, expired = 0, true
                if profile then
                    distance, expired = CombatService.flight(
                        profile,
                        time - projectile.shot.firedAt,
                        projectile.remaining,
                        dt
                    )
                end
                if expired then
                    projectile.visual:Destroy()
                    projectile.marker:Destroy()
                    table.remove(projectiles, i)
                    continue
                end
                local step = projectile.direction * distance
                -- Sweep the physical shell volume through each frame. The finite
                -- radius catches shallow terrain contacts even when the aircraft
                -- moves between client surface sampling and the server launch.
                -- Empty-space endpoints still cannot create an impact.
                local hit = if profile
                    then CombatRuntime.sweep(
                        projectile.position,
                        profile.collisionRadius,
                        step,
                        rayParameters(true)
                    )
                    else nil
                projectile.position = if hit then hit.Position else projectile.position + step
                projectile.remaining -= distance
                projectile.visual.Position = projectile.position
                if hit or projectile.remaining <= 0 then
                    -- Client endpoints bound travel only; they do not create impacts.
                    if not hit or not impact(projectile, projectile.position, hit.Instance, time) then
                        projectile.marker:Destroy()
                    end
                    projectile.visual:Destroy()
                    table.remove(projectiles, i)
                end
            end
            publish(time)
        end)
    )
    return {
        onImpact = emit,
        resources = function()
            return { connections = #connections, projectiles = #projectiles }
        end,
        stop = function()
            if not running then
                return
            end
            running = false
            for _, connection in connections do
                connection:Disconnect()
            end
            table.clear(connections)
            clear()
            remote:Destroy()
            muzzleProbe:Destroy()
            effects:Destroy()
            aircraftState:SetAttribute("Readiness", nil)
            aircraftState:SetAttribute("Impact", nil)
        end,
    },
        nil
end
return CombatRuntime
