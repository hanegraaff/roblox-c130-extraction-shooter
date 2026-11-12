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

-- Starts one engine owner. optional onImpact is called synchronously after resolution;
-- it must not yield or reenter the owner. A valid callback is not a destruction award.
function CombatRuntime.start(
    match: MatchService.Controller,
    aircraft: AircraftService.Controller,
    onImpact: ((Impact) -> ())?
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
    local buckets: { [Player]: RateLimit.Bucket } = {}
    local connections: { RBXScriptConnection } = {}
    local projectiles: { Projectile } = {}
    local running = true
    local lastRound = -1
    local lastReadiness = ""
    local emit = onImpact or function(_impact: Impact) end
    local function now(): number
        return workspace:GetServerTimeNow()
    end
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
    local function impact(projectile: Projectile, position: Vector3, hit: Instance?, time: number): boolean
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
                member
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
        projectile.marker.Position = position
        projectile.marker.Size = Vector3.one * (if projectile.shot.weapon == "M102" then 8 else 3)
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
            local weapon = aircraft.weapon()
            local muzzle = aircraft.muzzle(weapon)
            if not muzzle then
                return
            end
            local shot =
                combat.fire(player.UserId, payload, weapon, eligible, time, muzzle.X, muzzle.Y, muzzle.Z)
            if not shot then
                return
            end
            local target = Vector3.new(shot.x, shot.y, shot.z)
            local delta = target - muzzle
            local visual = Instance.new("Part")
            visual.Name = "Projectile"
            visual.Size = Vector3.new(1, 1, 1) * (if weapon == "M102" then 2 else 0.6)
            visual.Shape = Enum.PartType.Ball
            visual.Material = Enum.Material.Neon
            visual.Color = if weapon == "M102"
                then Color3.fromRGB(255, 125, 35)
                else Color3.fromRGB(255, 242, 150)
            visual.Anchored = true
            visual.CanCollide = false
            visual.CanTouch = false
            visual.CanQuery = false
            visual.Position = muzzle
            visual.Parent = effects
            local marker = Instance.new("Part")
            marker.Name = "ImpactWarning"
            marker.Shape = Enum.PartType.Ball
            marker.Size = Vector3.new(2, 2, 2)
            marker.Material = Enum.Material.Neon
            marker.Color = visual.Color
            marker.Transparency = 0.35
            marker.Anchored = true
            marker.CanCollide = false
            marker.CanTouch = false
            marker.CanQuery = false
            marker.Position = target
            marker.Parent = effects
            table.insert(projectiles, {
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
            })
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
        RunService.Heartbeat:Connect(function(dt)
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
                local hit = workspace:Raycast(projectile.position, step, rayParameters(true))
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
            effects:Destroy()
            aircraftState:SetAttribute("Readiness", nil)
            aircraftState:SetAttribute("Impact", nil)
        end,
    },
        nil
end
return CombatRuntime
