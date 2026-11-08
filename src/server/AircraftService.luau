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
    -- Idempotently destroys model, selection transport and all three owned connections.
    stop: () -> (),
    -- Pure canonical tangent CFrame at injected elapsed seconds; invalid time asserts.
    sample: (number) -> CFrame,
    -- Server-only finite disk/height and solid-world sight-line check; never fires.
    aimAllowed: (Vector3) -> boolean,
    -- Current live owned connections, for teardown/repeated-round diagnostics.
    resources: () -> { connections: number },
}

-- Starts from phase zero. Orbit runs in lobby for solo inspection, resets at each
-- deployment/lobby transition, and freezes in Results. Model pivot/Hitbox is the sole
-- gameplay pose; decorative parts do not collide/query/touch. No smoothing shell.
-- Optional clock supplies finite monotonic seconds for engine fixtures; production
-- uses GetServerTimeNow. match remains owned by GameRuntime, never destroyed here.
function AircraftService.start(match: MatchService.Controller, clock: (() -> number)?): (Controller?, string?)
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
    local function tick()
        local state = match.snapshot()
        if state.roundId ~= previousRound or (state.phase ~= previousPhase and state.phase == "Lobby") then
            epoch = now()
            selection.reset(state.roundId, state.phase == "Lobby")
            publish()
        end
        previousRound = state.roundId
        previousPhase = state.phase
        status:SetAttribute("EpochSeconds", epoch)
        if state.phase ~= "Results" and state.phase ~= "Resetting" then
            model:PivotTo(sample(now() - epoch))
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
    model:PivotTo(sample(0))
    model.Parent = workspace
    tick()
    status.Parent = ReplicatedStorage
    table.insert(connections, RunService.Heartbeat:Connect(tick))
    return {
        sample = sample,
        aimAllowed = function(endpoint)
            if not AircraftRules.aimAllowed(map, endpoint.X, endpoint.Y, endpoint.Z) then
                return false
            end
            local parameters = RaycastParams.new()
            parameters.RespectCanCollide = true
            parameters.FilterType = Enum.RaycastFilterType.Include
            parameters.FilterDescendantsInstances = { workspace.World.Battlefield, workspace.Terrain }
            local origin = hitbox.Position
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
