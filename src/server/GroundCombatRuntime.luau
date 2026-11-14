--!strict
--[=[
    GroundCombatRuntime: server engine adapter for M-7 equipment, fire and aircraft health.
    Depends on MatchService, AircraftService, GroundCombatService and AircraftHealth.
    Clients supply target intent only; server owns tool, muzzle, geometry, damage and result.
    Lifecycle: start creates one owner; stop disconnects listeners and destroys owned tools,
    transport and effects. All calls are nonyielding; test rocket impacts require a server caller.
]=]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Debris = game:GetService("Debris")
local RateLimit = require(ReplicatedStorage.Shared.RateLimit)
local MatchService = require(script.Parent.MatchService)
local AircraftHealth = require(script.Parent.AircraftHealth)
local GroundCombatService = require(script.Parent.GroundCombatService)
local GroundMovementGuard = require(script.Parent.GroundMovementGuard)
local GroundOriginGeometry = require(script.Parent.GroundOriginGeometry)
local GroundCombatRuntime = {}
local TRACER_SPEED = 1200 -- studs per second; cosmetic travel, not damage timing
local MIN_TRACER_SECONDS = 0.15
local TRACER_TAIL_SECONDS = 0.1
-- Server-only, nonauthoritative diagnostics for an already resolved shot.
export type ShotObservation = {
    userId: number,
    sequence: number,
    serverTime: number,
    origin: Vector3,
    requestedTarget: Vector3,
    hitPosition: Vector3,
    hitName: string,
    aircraftPosition: Vector3?,
    healthBefore: number,
    healthAfter: number,
    applied: boolean,
}
-- Server-composition boundaries must not yield, throw, or mutate combat state.
-- Production omits these and uses the authoritative Terrain query directly.
export type Dependencies = {
    terrainQuery: ((Vector3) -> boolean)?,
    observeFire: ((number, string, number) -> ())?,
    observeShot: ((ShotObservation) -> ())?,
}
export type Controller = {
    stop: () -> (),
    rocketImpact: (number, string, boolean) -> boolean,
    rocketSweep: (number, string, Vector3, Vector3) -> boolean,
    -- Sweeps the first authoritative solid. Returns collision and aircraft award;
    -- nil collision means clear travel, never permission to skip solid cover.
    rocketCast: (number, string, Vector3, Vector3) -> (Vector3?, boolean),
    -- Shared movement/origin authority for equipped launcher fire and pickup.
    validateGround: (Player) -> boolean,
    -- Only a trusted server owner may acknowledge its own spawn/correction.
    trustCorrection: (Player) -> boolean,
    -- Fresh readiness copy for a server-owned diagnostic, at server time.
    readiness: (Player) -> GroundCombatService.Readiness,
    resources: () -> { connections: number, tools: number },
}
-- match is the sole result owner. rocketImpact is a server-only fixture seam;
-- directness must be established by the server's swept collision before invocation.
function GroundCombatRuntime.start(
    match: MatchService.Controller,
    dependencies: Dependencies?
): (Controller?, string?)
    local aircraftState = ReplicatedStorage:FindFirstChild("AircraftState")
    if not aircraftState or aircraftState:FindFirstChild("GroundFire") then
        return nil, "ground combat transport unavailable or already owned"
    end
    local fire = Instance.new("RemoteEvent")
    fire.Name = "GroundFire"
    fire.Parent = aircraftState
    local reload = Instance.new("RemoteEvent")
    reload.Name = "GroundReload"
    reload.Parent = aircraftState
    local effects = Instance.new("Folder")
    effects.Name = "GroundCombatEffects"
    effects.Parent = workspace
    local originGeometry =
        GroundOriginGeometry.new(effects, if dependencies then dependencies.terrainQuery else nil)
    local health = AircraftHealth.new()
    local lastPhase = ""
    local rifles = GroundCombatService.new()
    local tools: { [Player]: Tool? } = {}
    local movement: { [Player]: { character: Model, guard: GroundMovementGuard.Controller }? } = {}
    local buckets: { [Player]: RateLimit.Bucket } = {}
    local connections: { RBXScriptConnection } = {}
    local tracers: { { part: Part, origin: Vector3, endpoint: Vector3, started: number, duration: number } } =
        {}
    local running = true
    local lastRound = -1
    local function clearTracers()
        for _, tracer in tracers do
            tracer.part:Destroy()
        end
        table.clear(tracers)
        for _, effect in effects:GetChildren() do
            if effect.Name == "M7MuzzleFlash" then
                effect:Destroy()
            end
        end
    end
    local function observe(player: Player, decision: string, now: number)
        if dependencies and dependencies.observeFire then
            dependencies.observeFire(player.UserId, decision, now)
        end
    end
    local function track(player: Player, now: number, trustedCorrection: boolean): boolean
        local character = player.Character
        local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
        if not character or not root or not root:IsA("BasePart") then
            return false
        end
        local current = movement[player]
        local position = root.Position
        if not current or current.character ~= character then
            local guard = GroundMovementGuard.new()
            if not guard.reset(position.X, position.Y, position.Z, now) then
                return false
            end
            movement[player] = { character = character, guard = guard }
            return true
        end
        if trustedCorrection then
            return current.guard.reset(position.X, position.Y, position.Z, now)
        end
        return current.guard.sample(position.X, position.Y, position.Z, now)
    end
    local function publish()
        local state = health.snapshot()
        aircraftState:SetAttribute("Health", state.health)
        aircraftState:SetAttribute("MaxHealth", state.maximum)
        aircraftState:SetAttribute("Destroyed", state.destroyed)
    end
    local function active(player: Player, now: number): boolean
        local state = match.snapshot()
        local member = state.members[player.UserId]
        local character = player.Character
        local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
        return state.phase == "Active"
            and now < state.deadlineSeconds
            and member ~= nil
            and member.connected
            and member.role == "Ground"
            and member.life == "Alive"
            and humanoid ~= nil
            and humanoid.Health > 0
    end
    local function ownedEquipped(player: Player): boolean
        local tool = tools[player]
        return tool ~= nil and tool.Parent == player.Character
    end
    local function removeTool(player: Player)
        local tool = tools[player]
        tools[player] = nil
        if tool then
            tool:Destroy()
        end
    end
    local function ensureTool(player: Player)
        local backpack = player:FindFirstChildOfClass("Backpack")
        if not backpack or not player.Character then
            return
        end
        local current = tools[player]
        if current and (current.Parent == backpack or current.Parent == player.Character) then
            return
        end
        removeTool(player)
        local tool = Instance.new("Tool")
        tool.Name = "M-7 rifle"
        tool.RequiresHandle = true
        tool.CanBeDropped = false
        tool.ToolTip = "M-7 rifle"
        -- Primitive server-owned rifle; pieces are cosmetic and cannot block
        -- collision or queries. Roblox's Tool grip owns the equipped Handle.
        local handle = Instance.new("Part")
        handle.Name = "Handle"
        handle.Size = Vector3.new(0.35, 0.5, 1.4)
        handle.Color = Color3.fromRGB(48, 52, 49)
        handle.Material = Enum.Material.Metal
        handle.CanCollide = false
        handle.CanTouch = false
        handle.CanQuery = false
        handle.Massless = true
        handle.Parent = tool
        local function piece(name: string, size: Vector3, offset: Vector3, color: Color3)
            local part = Instance.new("Part")
            part.Name = name
            part.Size = size
            part.Color = color
            part.Material = Enum.Material.Metal
            part.CanCollide = false
            part.CanTouch = false
            part.CanQuery = false
            part.Massless = true
            part.CFrame = handle.CFrame * CFrame.new(offset)
            part.Parent = tool
            local weld = Instance.new("WeldConstraint")
            weld.Part0 = handle
            weld.Part1 = part
            weld.Parent = part
        end
        piece(
            "Barrel",
            Vector3.new(0.18, 0.18, 1.25),
            Vector3.new(0, 0.08, -1.25),
            Color3.fromRGB(32, 34, 32)
        )
        piece("Stock", Vector3.new(0.3, 0.42, 0.8), Vector3.new(0, -0.05, 1.05), Color3.fromRGB(77, 75, 58))
        piece(
            "Magazine",
            Vector3.new(0.26, 0.58, 0.38),
            Vector3.new(0, -0.48, -0.15),
            Color3.fromRGB(35, 38, 35)
        )
        tool.Parent = backpack
        tools[player] = tool
    end
    local function publishRifle(player: Player, now: number)
        local tool = tools[player]
        if not tool then
            return
        end
        local state = rifles.readiness(player.UserId, now)
        tool:SetAttribute("Ammo", state.ammo)
        tool:SetAttribute("Reserve", state.reserve)
        tool:SetAttribute("ReloadUntil", state.reloadUntil)
    end
    local function spendBudget(player: Player, now: number): boolean
        local bucket = buckets[player]
        if not bucket then
            bucket = assert(RateLimit.new(12, 8, now), "valid ground fire budget")
            buckets[player] = bucket
        end
        return RateLimit.take(bucket, now)
    end
    local function award(roundId: number, shotId: string, weapon: string, direct: boolean): boolean
        local state = match.snapshot()
        local now = workspace:GetServerTimeNow()
        if
            not running
            or state.phase ~= "Active"
            or state.roundId ~= roundId
            or now >= state.deadlineSeconds
        then
            return false
        end
        local amount, destroyed = health.impact(roundId, shotId, weapon, direct)
        if not amount then
            return false
        end
        publish()
        if destroyed then
            match.proposeAircraftDestroyed(roundId)
        end
        return true
    end
    local function rocketCast(
        roundId: number,
        shotId: string,
        origin: Vector3,
        displacement: Vector3
    ): (Vector3?, boolean)
        if
            not running
            or displacement.Magnitude <= 0
            or displacement.Magnitude > 1200
            or origin.Magnitude ~= origin.Magnitude
            or origin.Magnitude == math.huge
            or displacement.Magnitude ~= displacement.Magnitude
        then
            return nil, false
        end
        local aircraft = workspace:FindFirstChild("Aircraft")
        local world = workspace:FindFirstChild("World")
        local battlefield = if world then world:FindFirstChild("Battlefield") else nil
        if not aircraft or not battlefield then
            return nil, false
        end
        local parameters = RaycastParams.new()
        parameters.FilterType = Enum.RaycastFilterType.Include
        parameters.FilterDescendantsInstances = { battlefield, workspace.Terrain, aircraft }
        local overlap = OverlapParams.new()
        overlap.FilterType = Enum.RaycastFilterType.Include
        overlap.FilterDescendantsInstances = { battlefield }
        overlap.MaxParts = 1
        if #workspace:GetPartBoundsInRadius(origin, 0.2, overlap) > 0 then
            return origin, false
        end
        local hit = workspace:Spherecast(origin, 0.2, displacement, parameters)
        if not hit then
            return nil, false
        end
        local applied = hit.Instance:IsDescendantOf(aircraft)
            and award(roundId, shotId, "RocketLauncher", true)
        return hit.Position, applied
    end
    table.insert(
        connections,
        fire.OnServerEvent:Connect(function(player: Player, payload: unknown)
            local now = workspace:GetServerTimeNow()
            if not spendBudget(player, now) then
                observe(player, "rate", now)
                return
            end
            if not active(player, now) then
                observe(player, "inactive", now)
                return
            end
            if not ownedEquipped(player) then
                observe(player, "not-equipped", now)
                return
            end
            local character = player.Character
            local head = if character then character:FindFirstChild("Head") else nil
            local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
            if not head or not head:IsA("BasePart") or not root or not root:IsA("BasePart") then
                observe(player, "body-missing", now)
                return
            end
            local origin = head.Position
            -- Reject malformed, replayed, out-of-range or cooldown requests
            -- before the movement, voxel, overlap and world-ray checks.
            if not rifles.preflight(player.UserId, payload, true, now, origin.X, origin.Y, origin.Z) then
                observe(player, "preflight", now)
                return
            end
            if not track(player, now, false) then
                observe(player, "movement", now)
                return
            end
            local allowed, originReason = originGeometry.allows(root, head)
            if not allowed then
                observe(player, "origin:" .. tostring(originReason), now)
                return
            end
            local intent = rifles.fire(player.UserId, payload, true, now, origin.X, origin.Y, origin.Z)
            if not intent then
                observe(player, "fire-rejected", now)
                return
            end
            observe(player, "accepted", now)
            publishRifle(player, now)
            local target = Vector3.new(intent.x, intent.y, intent.z)
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Include
            local aircraft = workspace:FindFirstChild("Aircraft")
            local battlefield = workspace.World:FindFirstChild("Battlefield")
            local roots: { Instance } = { workspace.Terrain }
            if battlefield then
                table.insert(roots, battlefield)
            end
            if aircraft then
                table.insert(roots, aircraft)
            end
            params.FilterDescendantsInstances = roots
            params.RespectCanCollide = false
            -- The target establishes direction, not a claimed hit. Cast the
            -- entire bounded range so a moving aircraft can still intersect
            -- beyond its previously sampled surface; server cover wins first.
            local delta = target - origin
            local hit = workspace:Raycast(origin, delta.Unit * GroundCombatService.range, params)
            local endpoint = if hit then hit.Position else origin + delta.Unit * GroundCombatService.range
            local tracer = Instance.new("Part")
            tracer.Name = "M7Tracer"
            tracer.Anchored = true
            tracer.CanCollide = false
            tracer.CanTouch = false
            tracer.CanQuery = false
            tracer.Material = Enum.Material.Neon
            tracer.Color = Color3.fromRGB(255, 220, 120)
            -- Moving presentation follows the resolved authoritative ray; hit
            -- evaluation remains immediate. It never predicts a future hit.
            tracer.Size = Vector3.new(0.35, 0.35, 0.01)
            tracer.CFrame = CFrame.lookAt(origin, endpoint)
            tracer.Parent = effects
            local duration = math.max(MIN_TRACER_SECONDS, (endpoint - origin).Magnitude / TRACER_SPEED)
            table.insert(tracers, {
                part = tracer,
                origin = origin,
                endpoint = endpoint,
                started = now,
                duration = duration,
            })
            local ownedTool = tools[player]
            local barrel = if ownedTool then ownedTool:FindFirstChild("Barrel") else nil
            if barrel and barrel:IsA("BasePart") then
                local flash = Instance.new("Part")
                flash.Name = "M7MuzzleFlash"
                flash.Shape = Enum.PartType.Ball
                flash.Size = Vector3.new(1.2, 1.2, 1.2)
                flash.Anchored = true
                flash.CanCollide = false
                flash.CanTouch = false
                flash.CanQuery = false
                flash.Material = Enum.Material.Neon
                flash.Color = Color3.fromRGB(255, 206, 80)
                flash.CFrame = barrel.CFrame * CFrame.new(0, 0, -barrel.Size.Z / 2)
                flash.Parent = effects
                Debris:AddItem(flash, 0.15)
            end
            local state = match.snapshot()
            local healthBefore = health.snapshot().health
            local applied = false
            if hit and aircraft and hit.Instance:IsDescendantOf(aircraft) then
                applied = award(
                    state.roundId,
                    tostring(player.UserId) .. ":" .. tostring(intent.sequence),
                    "M7",
                    true
                )
            end
            aircraftState:SetAttribute(
                "GroundShot",
                HttpService:JSONEncode({
                    roundId = state.roundId,
                    userId = player.UserId,
                    sequence = intent.sequence,
                    x = endpoint.X,
                    y = endpoint.Y,
                    z = endpoint.Z,
                    aircraftHit = applied,
                })
            )
            if dependencies and dependencies.observeShot then
                local hitbox = if aircraft then aircraft:FindFirstChild("Hitbox") else nil
                dependencies.observeShot({
                    userId = player.UserId,
                    sequence = intent.sequence,
                    serverTime = now,
                    origin = origin,
                    requestedTarget = target,
                    hitPosition = endpoint,
                    hitName = if hit then hit.Instance:GetFullName() else "none",
                    aircraftPosition = if hitbox and hitbox:IsA("BasePart") then hitbox.Position else nil,
                    healthBefore = healthBefore,
                    healthAfter = health.snapshot().health,
                    applied = applied,
                })
            end
        end)
    )
    table.insert(
        connections,
        reload.OnServerEvent:Connect(function(player: Player, payload: unknown)
            local now = workspace:GetServerTimeNow()
            if
                spendBudget(player, now)
                and active(player, now)
                and ownedEquipped(player)
                and rifles.reload(player.UserId, payload, true, now)
            then
                publishRifle(player, now)
            end
        end)
    )
    table.insert(
        connections,
        Players.PlayerRemoving:Connect(function(player)
            removeTool(player)
            buckets[player] = nil
            movement[player] = nil
        end)
    )
    table.insert(
        connections,
        RunService.Heartbeat:Connect(function()
            local now = workspace:GetServerTimeNow()
            local state = match.snapshot()
            for i = #tracers, 1, -1 do
                local tracer = tracers[i]
                local elapsed = now - tracer.started
                if elapsed >= tracer.duration + TRACER_TAIL_SECONDS or not tracer.part.Parent then
                    tracer.part:Destroy()
                    table.remove(tracers, i)
                else
                    local progress = math.clamp(elapsed / tracer.duration, 0, 1)
                    local direction = (tracer.endpoint - tracer.origin).Unit
                    local traveled = (tracer.endpoint - tracer.origin).Magnitude * progress
                    local length = math.max(0.01, math.min(3, traveled))
                    local position = tracer.origin + direction * (traveled - length * 0.5)
                    tracer.part.Size = Vector3.new(0.35, 0.35, length)
                    tracer.part.CFrame = CFrame.lookAt(position, position + direction)
                end
            end
            if state.phase == "Resetting" and lastPhase ~= "Resetting" then
                aircraftState:SetAttribute("GroundShot", nil)
                clearTracers()
            end
            if state.phase == "Lobby" and lastPhase ~= "Lobby" then
                health = AircraftHealth.new()
                health.reset(state.roundId)
                aircraftState:SetAttribute("GroundShot", nil)
                publish()
            end
            lastPhase = state.phase
            if state.roundId ~= lastRound then
                lastRound = state.roundId
                health.reset(lastRound)
                rifles.reset(lastRound)
                table.clear(movement)
                aircraftState:SetAttribute("GroundShot", nil)
                publish()
            end
            for _, player in Players:GetPlayers() do
                local member = state.members[player.UserId]
                if
                    member
                    and member.role == "Ground"
                    and (state.phase == "Deploying" or state.phase == "Active")
                then
                    track(player, now, false)
                else
                    movement[player] = nil
                end
                if active(player, now) then
                    ensureTool(player)
                    publishRifle(player, now)
                else
                    removeTool(player)
                end
            end
        end)
    )
    publish()
    return {
        readiness = function(player)
            return rifles.readiness(player.UserId, workspace:GetServerTimeNow())
        end,
        trustCorrection = function(player)
            return running and track(player, workspace:GetServerTimeNow(), true)
        end,
        validateGround = function(player)
            local now = workspace:GetServerTimeNow()
            if not running or not active(player, now) or not track(player, now, false) then
                return false
            end
            local character = player.Character
            local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
            local head = if character then character:FindFirstChild("Head") else nil
            return root ~= nil
                and root:IsA("BasePart")
                and head ~= nil
                and head:IsA("BasePart")
                and originGeometry.allows(root, head)
        end,
        rocketImpact = function(roundId, shotId, direct)
            return award(roundId, shotId, "RocketLauncher", direct)
        end,
        rocketCast = rocketCast,
        rocketSweep = function(roundId, shotId, origin, displacement)
            local _, applied = rocketCast(roundId, shotId, origin, displacement)
            return applied
        end,
        resources = function()
            local count = 0
            for _ in tools do
                count += 1
            end
            return { connections = #connections, tools = count }
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
            for player in tools do
                removeTool(player)
            end
            table.clear(buckets)
            table.clear(movement)
            clearTracers()
            fire:Destroy()
            reload:Destroy()
            originGeometry.destroy()
            effects:Destroy()
            aircraftState:SetAttribute("Health", nil)
            aircraftState:SetAttribute("MaxHealth", nil)
            aircraftState:SetAttribute("Destroyed", nil)
            aircraftState:SetAttribute("GroundShot", nil)
        end,
    },
        nil
end
return GroundCombatRuntime
