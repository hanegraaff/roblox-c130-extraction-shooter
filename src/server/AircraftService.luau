--!strict
--[=[
    AircraftService: server engine owner of one canonical anchored C-130, orbit clock
    and selected weapon. Depends on MatchService snapshot, Workspace, Players,
    Heartbeat and the Git-authored ServerStorage.Assets.C130 template. All geometry
    derives from MapRules. start/stop are nonyielding/idempotent; stop destroys every
    owned Instance/listener. Clients never supply a pose or muzzle origin.
]=]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local MapRules = require(ReplicatedStorage.Shared.MapRules)
local AircraftRules = require(ReplicatedStorage.Shared.AircraftRules)
local RateLimit = require(ReplicatedStorage.Shared.RateLimit)
local AircraftSelection = require(script.Parent.AircraftSelection)
local MatchService = require(script.Parent.MatchService)
local AircraftService = {}
export type Controller = {
    -- Idempotently destroys model, selection transport and all owned connections.
    stop: () -> (),
    -- Synchronizes selection and canonical pose at trusted server seconds.
    step: (number) -> (),
    -- Pure canonical tangent CFrame at injected elapsed seconds; invalid time asserts.
    sample: (number) -> CFrame,
    -- Server-only finite disk/height and solid-world sight-line check; never fires.
    aimAllowed: (Vector3) -> boolean,
    -- Server-owned selected weapon and muzzle position. An absent plane has no muzzle.
    weapon: () -> string,
    muzzle: (string) -> Vector3?,
    -- Current canonical camera origin used to bound client pose replication age.
    position: () -> Vector3,
    -- Current active-level combat bounds and authored vertical aim envelope.
    level: () -> (MapRules.Settings, number, number),
    -- Current live owned connections, for teardown/repeated-round diagnostics.
    resources: () -> { connections: number },
}

-- Orbit runs in Lobby for inspection. The model is detached during deployment
-- and scatter, starts at phase zero on arrival, and freezes in Results if it arrived.
-- Model pivot/Hitbox is the sole
-- gameplay pose; visible parts participate in shot queries but do not collide or
-- touch. No smoothing shell.
-- Optional clock supplies finite monotonic seconds for engine fixtures; production
-- uses GetServerTimeNow. externallyStepped lets GameRuntime own the frame order.
-- match remains caller-owned.
function AircraftService.start(
    match: MatchService.Controller,
    clock: (() -> number)?,
    externallyStepped: boolean?
): (Controller?, string?)
    local now: () -> number = clock or function(): number
        return workspace:GetServerTimeNow()
    end
    if workspace:FindFirstChild("Aircraft") or ReplicatedStorage:FindFirstChild("AircraftState") then
        return nil, "aircraft already owned"
    end
    local template = game:GetService("ServerStorage").Assets:FindFirstChild("C130")
    if not template or not template:IsA("Model") then
        return nil, "missing aircraft model template"
    end
    local model = template:Clone()
    model.Name = "Aircraft"
    local hitbox = model:FindFirstChild("Hitbox")
    if not hitbox or not hitbox:IsA("BasePart") then
        model:Destroy()
        return nil, "missing canonical aircraft hitbox"
    end
    model.PrimaryPart = hitbox
    local map = MapRules.defaults
    local config = AircraftRules.defaults
    local envelope = workspace.World.Battlefield:FindFirstChild("AimEnvelope")
    local minimum = if envelope then envelope:FindFirstChild("MinimumY") else nil
    local maximum = if envelope then envelope:FindFirstChild("MaximumY") else nil
    if
        not minimum
        or not minimum:IsA("NumberValue")
        or not maximum
        or not maximum:IsA("NumberValue")
        or minimum.Value < map.groundY - 4
        or maximum.Value > map.groundY + map.altitudeStuds
        or not AircraftRules.aimAllowed(
            map,
            map.centerX,
            map.groundY,
            map.centerZ,
            minimum.Value,
            maximum.Value
        )
    then
        model:Destroy()
        return nil, "invalid authored aircraft aim envelope"
    end
    local minimumY, maximumY = minimum.Value, maximum.Value
    local focus = Vector3.new(map.focusX, map.focusY, map.focusZ)
    local function sample(elapsed: number): CFrame
        local pose = AircraftRules.pose(map, config, elapsed)
        assert(pose, "finite server orbit time")
        local position = Vector3.new(pose.x, pose.y, pose.z)
        return CFrame.lookAt(position, position + Vector3.new(pose.tangentX, 0, pose.tangentZ))
    end
    local status = Instance.new("Folder")
    status.Name = "AircraftState"
    status:SetAttribute("Focus", focus)
    status:SetAttribute("AimMinimumY", minimumY)
    status:SetAttribute("AimMaximumY", maximumY)
    status:SetAttribute("FOV30mm", config.fov30mm)
    status:SetAttribute("FOV105mm", config.fov105mm)
    status:SetAttribute("PeriodSeconds", config.periodSeconds)
    local selection = AircraftSelection.new()
    local function publish()
        -- One atomic string is the presentation commit: weapon/round/revision cannot
        -- be read half-updated. Clients only switch FOV after this acknowledgement.
        status:SetAttribute("Selection", HttpService:JSONEncode(selection.snapshot()))
    end
    local remote = Instance.new("RemoteEvent")
    remote.Name = "SelectWeapon"
    remote.Parent = status
    local buckets: { [Player]: RateLimit.Bucket } = {}
    local connections: { RBXScriptConnection } = {}
    local running = true
    local epoch = now()
    local previousPhase = ""
    local previousRound = -1
    local arrivedRound = -1
    local function step(time: number)
        if not running then
            return
        end
        local state = match.snapshot()
        local newLobby = state.phase == "Lobby" and previousPhase ~= "Lobby"
        local arrival = state.phase == "Active"
            and (previousPhase ~= "Active" or state.roundId ~= previousRound)
        if state.roundId ~= previousRound or newLobby then
            selection.reset(state.roundId, state.phase == "Lobby")
            publish()
        end
        if newLobby or arrival then
            epoch = time
            status:SetAttribute("EpochSeconds", epoch)
        end
        if arrival then
            arrivedRound = state.roundId
        end
        previousRound = state.roundId
        previousPhase = state.phase
        if
            state.phase == "Deploying"
            or state.phase == "Scatter"
            or state.phase == "Resetting"
            or (state.phase == "Results" and arrivedRound ~= state.roundId)
        then
            model.Parent = nil
        elseif state.phase == "Lobby" or (state.phase == "Active" and time < state.deadlineSeconds) then
            model:PivotTo(sample(time - epoch))
            model:SetAttribute("RoundId", state.roundId)
            if not model.Parent then
                model.Parent = workspace
            end
        end
    end
    table.insert(
        connections,
        remote.OnServerEvent:Connect(function(player: Player, payload: unknown)
            local bucket = buckets[player]
            if not bucket then
                local created = RateLimit.new(6, 4, workspace:GetServerTimeNow())
                assert(created, "valid selection budget")
                bucket = created
                buckets[player] = bucket
            end
            if not RateLimit.take(bucket, workspace:GetServerTimeNow()) then
                return
            end
            local state = match.snapshot()
            local member = state.members[player.UserId]
            local eligible = state.phase == "Active"
                and state.deadlineSeconds ~= nil
                and workspace:GetServerTimeNow() < state.deadlineSeconds
                and member ~= nil
                and member.connected
                and member.role == "Gunship"
                and member.life == "Alive"
            if selection.command(player.UserId, payload, eligible) then
                publish()
            end
        end)
    )
    table.insert(
        connections,
        Players.PlayerRemoving:Connect(function(player)
            buckets[player] = nil
        end)
    )
    step(epoch)
    status.Parent = ReplicatedStorage
    if not externallyStepped then
        table.insert(
            connections,
            RunService.Heartbeat:Connect(function()
                step(now())
            end)
        )
    end
    return {
        sample = sample,
        step = step,
        weapon = function()
            return selection.snapshot().weapon
        end,
        position = function()
            return hitbox.Position
        end,
        muzzle = function(weapon)
            if model.Parent ~= workspace or (weapon ~= "GAU23" and weapon ~= "M102") then
                return nil
            end
            local attachment = hitbox:FindFirstChild(if weapon == "M102" then "M102Muzzle" else "GAU23Muzzle")
            return if attachment and attachment:IsA("Attachment") then attachment.WorldPosition else nil
        end,
        level = function()
            return table.clone(map), minimumY, maximumY
        end,
        aimAllowed = function(endpoint)
            if
                model.Parent ~= workspace
                or not AircraftRules.aimAllowed(map, endpoint.X, endpoint.Y, endpoint.Z, minimumY, maximumY)
            then
                return false
            end
            local parameters = RaycastParams.new()
            parameters.RespectCanCollide = true
            parameters.FilterType = Enum.RaycastFilterType.Include
            parameters.FilterDescendantsInstances = { workspace.World.Battlefield, workspace.Terrain }
            local weapon = selection.snapshot().weapon
            local muzzle = hitbox:FindFirstChild(if weapon == "M102" then "M102Muzzle" else "GAU23Muzzle")
            if not muzzle or not muzzle:IsA("Attachment") then
                return false
            end
            local origin = muzzle.WorldPosition
            local result = workspace:Raycast(origin, endpoint - origin, parameters)
            -- Surface endpoints are legal; earlier solid geometry blocks the sight line.
            return result == nil or (result.Position - endpoint).Magnitude <= 0.5
        end,
        resources = function()
            return { connections = #connections }
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
            table.clear(buckets)
            status:Destroy()
            model:Destroy()
        end,
    },
        nil
end
return AircraftService
