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
    local running = true
    local lastRound = -1
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
        tool.RequiresHandle = false
        tool.CanBeDropped = false
        tool.ToolTip = "M-7 rifle"
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
        if state.phase ~= "Active" or state.roundId ~= roundId or now >= state.deadlineSeconds then
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
            -- A camera-picked target can lie exactly on a surface. Continue a
            -- bounded half stud beyond it to avoid endpoint precision missing
            -- that surface; every award still requires a real server ray hit.
            local delta = target - origin
            local hit = workspace:Raycast(
                origin,
                delta.Unit * math.min(delta.Magnitude + 0.5, GroundCombatService.range),
                params
            )
            local endpoint = if hit then hit.Position else target
            local tracer = Instance.new("Part")
            tracer.Name = "M7Tracer"
            tracer.Anchored = true
            tracer.CanCollide = false
            tracer.CanTouch = false
            tracer.CanQuery = false
            tracer.Material = Enum.Material.Neon
            tracer.Color = Color3.fromRGB(255, 220, 120)
            local length = (endpoint - origin).Magnitude
            tracer.Size = Vector3.new(0.12, 0.12, math.max(length, 0.01))
            tracer.CFrame = CFrame.lookAt((origin + endpoint) / 2, endpoint)
            tracer.Parent = effects
            Debris:AddItem(tracer, 0.1)
            local state = match.snapshot()
            aircraftState:SetAttribute(
                "GroundShot",
                HttpService:JSONEncode({
                    roundId = state.roundId,
                    userId = player.UserId,
                    sequence = intent.sequence,
                    x = endpoint.X,
                    y = endpoint.Y,
                    z = endpoint.Z,
                })
            )
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
            if state.phase == "Lobby" and lastPhase ~= "Lobby" then
                health = AircraftHealth.new()
                health.reset(state.roundId)
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
        rocketImpact = function(roundId, shotId, direct)
            return award(roundId, shotId, "RocketLauncher", direct)
        end,
        rocketSweep = function(roundId, shotId, origin, displacement)
            if displacement.Magnitude <= 0 or displacement.Magnitude > 1200 then
                return false
            end
            local aircraft = workspace:FindFirstChild("Aircraft")
            if not aircraft then
                return false
            end
            local parameters = RaycastParams.new()
            parameters.FilterType = Enum.RaycastFilterType.Include
            parameters.FilterDescendantsInstances =
                { workspace.World.Battlefield, workspace.Terrain, aircraft }
            local hit = workspace:Spherecast(origin, 0.2, displacement, parameters)
            return hit ~= nil
                and hit.Instance:IsDescendantOf(aircraft)
                and award(roundId, shotId, "RocketLauncher", true)
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
