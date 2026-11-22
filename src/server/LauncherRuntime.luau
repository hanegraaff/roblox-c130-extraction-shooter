--!strict
--[=[
    LauncherRuntime: server engine/network owner of the one recoverable launcher.
    Depends on MatchService, P06 ground movement/origin/rocket authority, level geometry
    and LauncherService. Intents are bounded/rate-limited, then processed atomically
    after the authoritative frame's outcome commit. Results/deadline beat transfers.
    Rockets sweep pre-impact solids and may outlive their shooter only while the
    round remains Active. stop invalidates work and destroys all owned
    transport, tools, pickup and flights. No gameplay callback yields.
]=]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local RateLimit = require(ReplicatedStorage.Shared.RateLimit)
local Validation = require(ReplicatedStorage.Shared.Validation)
local MapRules = require(ReplicatedStorage.Shared.MapRules)
local MatchService = require(script.Parent.MatchService)
local GroundCombatRuntime = require(script.Parent.GroundCombatRuntime)
local LauncherService = require(script.Parent.LauncherService)
local Geometry = require(script.Parent.LauncherGeometry)
local LauncherRuntime = {}
local WeaponSoundRules = require(game:GetService("ReplicatedStorage").Shared.WeaponSoundRules)
-- Shared bound for waiting pickup, drop and fire intents across the roster.
LauncherRuntime.queueCapacity = 32
export type Controller = {
    stop: () -> (),
    snapshot: () -> LauncherService.Snapshot,
    -- Sweep previously accepted flights at the frame timestamp in server seconds.
    advance: (number) -> (),
    -- Sync generations and process validated launcher intent after round results.
    interact: (number) -> (),
    resources: (
    ) -> {
        connections: number,
        representations: number,
        flights: number,
        queued: number,
        peakQueued: number,
        effects: number,
    },
}
type Request = { player: Player, action: string, payload: unknown }
type Flight = {
    roundId: number,
    shotId: string,
    userId: number,
    position: Vector3,
    direction: Vector3,
    lastTime: number,
    expires: number,
    remaining: number,
    part: Part,
}
local function scalar(position: Vector3): LauncherService.Position
    return { x = position.X, y = position.Y, z = position.Z }
end
local function vector(position: LauncherService.Position): Vector3
    return Vector3.new(position.x, position.y, position.z)
end
-- Starts beside the real P06 owner. The level has already been validated by
-- MapService. Rejects duplicate transport ownership without acquiring anything.
-- GameRuntime owns both frame steps when externallyStepped is true.
function LauncherRuntime.start(
    match: MatchService.Controller,
    ground: GroundCombatRuntime.Controller,
    externallyStepped: boolean?,
    emitSound: WeaponSoundRules.Emit?
): (Controller?, string?)
    if ReplicatedStorage:FindFirstChild("LauncherState") then
        return nil, "launcher already owned"
    end
    local rules = LauncherService.new()
    local state = Instance.new("Folder")
    state.Name = "LauncherState"
    local effects = Instance.new("Folder")
    effects.Name, effects.Parent = "LauncherEffects", workspace
    local running = true
    local peakQueued = 0
    local connections: { RBXScriptConnection } = {}
    local buckets: { [Player]: RateLimit.Bucket } = {}
    local pending: { Request } = {}
    local flights: { Flight } = {}
    local lastValid: { [number]: Vector3 } = {}
    local held: Tool? = nil
    local available: Model? = nil
    local observedRevision = -1
    local published = ""
    local lastSample = 0
    local function battlefield(): Instance?
        local world = workspace:FindFirstChild("World")
        return if world then world:FindFirstChild("Battlefield") else nil
    end
    local function anchor(): Vector3?
        local map = battlefield()
        local anchors = if map then map:FindFirstChild("Anchors") else nil
        local item = if anchors then anchors:FindFirstChild("Launcher") else nil
        return if item and item:IsA("BasePart") then item.Position else nil
    end
    local function active(now: number): boolean
        local round = match.snapshot()
        return running and round.phase == "Active" and now < round.deadlineSeconds
    end
    local function eligible(player: Player, now: number): boolean
        local round = match.snapshot()
        local member = round.members[player.UserId]
        local humanoid = if player.Character then player.Character:FindFirstChildOfClass("Humanoid") else nil
        return active(now)
            and player.Parent == Players
            and member ~= nil
            and member.connected
            and member.role == "Ground"
            and member.life == "Alive"
            and humanoid ~= nil
            and humanoid.Health > 0
    end
    local function destroyRepresentation()
        if held then
            held:Destroy()
            held = nil
        end
        if available then
            available:Destroy()
            available = nil
        end
    end
    local function clearFlights()
        for _, flight in flights do
            flight.part:Destroy()
        end
        table.clear(flights)
    end
    local function publish(now: number)
        local snapshot = rules.snapshot(now)
        local encoded = HttpService:JSONEncode(snapshot)
        if encoded ~= published then
            published = encoded
            state:SetAttribute("Snapshot", encoded)
        end
        if held then
            held:SetAttribute("Ammo", snapshot.ammo)
            held:SetAttribute("ReloadUntil", snapshot.readyAt)
        end
    end
    local function represent(now: number)
        local snapshot = rules.snapshot(now)
        local player = if snapshot.ownerId then Players:GetPlayerByUserId(snapshot.ownerId) else nil
        local backpack = if player then player:FindFirstChildOfClass("Backpack") else nil
        local validHeld = held ~= nil
            and player ~= nil
            and (held.Parent == backpack or held.Parent == player.Character)
        if
            snapshot.revision ~= observedRevision
            or (snapshot.state == "Held" and not validHeld)
            or (snapshot.state == "Available" and (not available or not available.Parent))
        then
            -- Fire changes readiness only; preserve the equipped Tool and native
            -- selection whenever its identity/owner has not changed.
            local correctHeld = snapshot.state == "Held"
                and validHeld
                and held ~= nil
                and held:GetAttribute("LauncherId") == snapshot.launcherId
            if not correctHeld then
                destroyRepresentation()
                if snapshot.state == "Available" then
                    local model = Geometry.pickup(snapshot.launcherId, vector(snapshot.position))
                    model.Parent = effects
                    available = model
                elseif snapshot.state == "Held" and backpack then
                    local tool = Geometry.tool(snapshot.launcherId)
                    tool.Parent = backpack
                    held = tool
                end
            end
            observedRevision = snapshot.revision
        end
        publish(now)
    end
    local function recover(userId: number)
        if not rules.recover(userId) then
            return
        end
        local map, initial = battlefield(), anchor()
        assert(map and initial, "validated launcher anchor disappeared")
        local last = lastValid[userId]
        local spot = if last then Geometry.supported(map, MapRules.defaults, last) else nil
        assert(rules.place(scalar(spot or initial)), "launcher recovery invariant")
    end
    local function shoot(player: Player, payload: unknown, now: number)
        if
            not held
            or held.Parent ~= player.Character
            or not rules.preflight(player.UserId, payload, "Fire", eligible(player, now), now)
            or not ground.validateGround(player)
        then
            return
        end
        local character = player.Character
        local head = if character then character:FindFirstChild("Head") else nil
        if not head or not head:IsA("BasePart") then
            return
        end
        local origin = head.Position
        local intent, shotId = rules.fire(player.UserId, payload, true, now, scalar(origin))
        if not intent or not shotId or not intent.x or not intent.y or not intent.z then
            return
        end
        local direction = (Vector3.new(intent.x, intent.y, intent.z) - origin).Unit
        local part = Instance.new("Part")
        part.Name = "Rocket"
        part.Size = Vector3.new(0.4, 0.4, 2)
        part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
        part.Material, part.Color = Enum.Material.Neon, Color3.fromRGB(255, 168, 50)
        local left, right = Instance.new("Attachment"), Instance.new("Attachment")
        left.Position, right.Position = Vector3.new(-0.18, 0, 0.5), Vector3.new(0.18, 0, 0.5)
        left.Parent, right.Parent = part, part
        local trail = Instance.new("Trail")
        trail.Name = "Exhaust"
        trail.Attachment0, trail.Attachment1 = left, right
        trail.Color = ColorSequence.new(Color3.fromRGB(255, 195, 121), Color3.fromRGB(104, 103, 102))
        trail.Transparency = NumberSequence.new(0.25, 1)
        trail.Lifetime, trail.MinLength = 0.32, 0.05
        trail.Parent = part
        part.CFrame, part.Parent = CFrame.lookAt(origin, origin + direction), effects
        if emitSound then
            emitSound("RocketLaunch", match.snapshot().roundId, origin, now, player.UserId)
        end
        table.insert(flights, {
            roundId = match.snapshot().roundId,
            shotId = shotId,
            userId = player.UserId,
            position = origin,
            direction = direction,
            lastTime = now,
            expires = now + LauncherService.lifetimeSeconds,
            remaining = LauncherService.rangeStuds,
            part = part,
        })
        state:SetAttribute(
            "LastShot",
            HttpService:JSONEncode({
                roundId = match.snapshot().roundId,
                userId = player.UserId,
                shotId = shotId,
            })
        )
    end
    local function process(request: Request, now: number)
        local player, action, payload = request.player, request.action, request.payload
        if not eligible(player, now) then
            return
        end
        if action == "Fire" then
            shoot(player, payload, now)
            return
        end
        if not rules.preflight(player.UserId, payload, action, true, now) then
            return
        end
        if action == "Drop" then
            if rules.drop(player.UserId, payload, true, now) then
                local map, initial = battlefield(), anchor()
                assert(map and initial, "validated launcher anchor disappeared")
                local last = lastValid[player.UserId]
                local spot = if last then Geometry.supported(map, MapRules.defaults, last) else nil
                assert(rules.place(scalar(spot or initial)), "drop recovery invariant")
            end
        elseif action == "Pickup" and ground.validateGround(player) then
            local map = battlefield()
            local character = player.Character
            local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
            local head = if character then character:FindFirstChild("Head") else nil
            if map and root and root:IsA("BasePart") and head and head:IsA("BasePart") then
                local target = vector(rules.snapshot(now).position)
                if
                    rules.pickup(
                        player.UserId,
                        payload,
                        true,
                        Geometry.reachable(map, root, head, target, LauncherService.pickupStuds),
                        now
                    )
                    and Geometry.supported(map, MapRules.defaults, root.Position)
                then
                    lastValid[player.UserId] = root.Position
                end
            end
        end
        represent(now)
    end
    for _, action in { "Pickup", "Drop", "Fire" } do
        local remote = Instance.new("RemoteEvent")
        remote.Name, remote.Parent = action, state
        table.insert(
            connections,
            remote.OnServerEvent:Connect(function(player: Player, payload: unknown)
                local now = workspace:GetServerTimeNow()
                local bucket = buckets[player]
                if not bucket then
                    bucket = assert(RateLimit.new(8, 6, now))
                    buckets[player] = bucket
                end
                if
                    not RateLimit.take(bucket, now)
                    or not Validation.flatPayload(payload, 6, 64)
                    or #pending >= LauncherRuntime.queueCapacity
                then
                    return
                end
                table.insert(pending, { player = player, action = action, payload = payload })
                peakQueued = math.max(peakQueued, #pending)
            end)
        )
    end
    table.insert(
        connections,
        Players.PlayerRemoving:Connect(function(player)
            buckets[player] = nil
        end)
    )
    local function advance(now: number)
        if not running then
            return
        end
        local round = match.snapshot()
        for index = #flights, 1, -1 do
            local flight = flights[index]
            if not active(now) or round.roundId ~= flight.roundId then
                flight.part:Destroy()
                table.remove(flights, index)
            else
                local endTime = math.min(now, flight.expires)
                local distance = math.min(
                    flight.remaining,
                    math.max(0, endTime - flight.lastTime) * LauncherService.speedStudsPerSecond
                )
                local displacement = flight.direction * distance
                local collision: Vector3? = nil
                local awarded = false
                if distance > 0 then
                    collision, awarded = ground.rocketCast(
                        flight.roundId,
                        flight.shotId,
                        flight.position,
                        displacement,
                        flight.userId
                    )
                end
                if collision then
                    if emitSound then
                        emitSound("RocketImpact", flight.roundId, collision, endTime, nil)
                    end
                    state:SetAttribute(
                        "LastImpact",
                        HttpService:JSONEncode({
                            roundId = flight.roundId,
                            shotId = flight.shotId,
                            userId = flight.userId,
                            aircraftHit = awarded,
                            x = collision.X,
                            y = collision.Y,
                            z = collision.Z,
                        })
                    )
                end
                if collision or now >= flight.expires or distance >= flight.remaining then
                    flight.part:Destroy()
                    table.remove(flights, index)
                else
                    flight.position += displacement
                    flight.remaining -= distance
                    flight.lastTime = now
                    flight.part.CFrame = CFrame.lookAt(flight.position, flight.position + flight.direction)
                end
            end
        end
    end
    local function interact(tickNow: number)
        if not running then
            return
        end
        local current = match.snapshot()
        if current.phase == "Deploying" or active(tickNow) then
            local initial = anchor()
            assert(initial, "validated launcher anchor missing")
            local before = rules.snapshot(tickNow)
            if current.roundId ~= before.roundId then
                destroyRepresentation()
                clearFlights()
                table.clear(lastValid)
                lastSample = 0
                rules.reset(current.roundId, scalar(initial))
                state:SetAttribute("LastShot", nil)
                state:SetAttribute("LastImpact", nil)
            end
            local snapshot = rules.snapshot(tickNow)
            local carrier = if snapshot.ownerId then Players:GetPlayerByUserId(snapshot.ownerId) else nil
            if snapshot.ownerId and (not carrier or not eligible(carrier, tickNow)) then
                recover(snapshot.ownerId)
            end
            if carrier and eligible(carrier, tickNow) and tickNow - lastSample >= 0.1 then
                lastSample = tickNow
                local map, character = battlefield(), carrier.Character
                local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
                if
                    map
                    and root
                    and root:IsA("BasePart")
                    and ground.validateGround(carrier)
                    and Geometry.supported(map, MapRules.defaults, root.Position)
                then
                    lastValid[carrier.UserId] = root.Position
                end
            end
            local requests = pending
            pending = {}
            for _, request in requests do
                process(request, tickNow)
            end
            represent(tickNow)
        else
            rules.clear()
            destroyRepresentation()
            clearFlights()
            table.clear(pending)
            table.clear(lastValid)
            if current.phase == "Lobby" or current.phase == "Resetting" then
                state:SetAttribute("LastShot", nil)
                state:SetAttribute("LastImpact", nil)
            end
            publish(tickNow)
        end
    end
    if not externallyStepped then
        table.insert(
            connections,
            RunService.Heartbeat:Connect(function()
                local now = workspace:GetServerTimeNow()
                advance(now)
                interact(now)
            end)
        )
    end
    state.Parent = ReplicatedStorage
    publish(workspace:GetServerTimeNow())
    return {
        advance = advance,
        interact = interact,
        snapshot = function()
            return rules.snapshot(workspace:GetServerTimeNow())
        end,
        resources = function()
            return {
                connections = #connections,
                representations = (if held then 1 else 0) + (if available then 1 else 0),
                flights = #flights,
                queued = #pending,
                peakQueued = peakQueued,
                effects = #effects:GetChildren(),
            }
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
            table.clear(pending)
            table.clear(buckets)
            table.clear(lastValid)
            rules.clear()
            destroyRepresentation()
            clearFlights()
            state:Destroy()
            effects:Destroy()
        end,
    },
        nil
end
return LauncherRuntime
