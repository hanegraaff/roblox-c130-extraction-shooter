--!strict
--[=[
    MapService: server-only ownership of the authored P02 map and ground containment.
    Depends on shared MapRules, Workspace queries, and injected characters/Heartbeat.
    Retains a private pristine clone; rebuild removes all runtime descendants and restores it.
    Does not spawn roles, weapons, aircraft, or round state. All public calls are nonyielding.
]=]
local MapRules = require(game:GetService("ReplicatedStorage").Shared.MapRules)
local MapService = {}

-- Query/step adapters let tests exercise actual Instance behavior without fake services.
export type Adapters = { characters: () -> { Model }, heartbeat: RBXScriptSignal, allowStations: boolean? }
-- Owns one heartbeat while started and one unparented snapshot until destroy.
export type Controller = {
    start: () -> (boolean, string?),
    stop: () -> (),
    rebuild: () -> (boolean, string?),
    enforce: () -> (),
    destroy: () -> (),
    validate: () -> (boolean, string?),
}

-- Validates identity, anchor counts, disk membership, floor support and avatar clearance.
-- Anchor clearance is a 4x5.5x4-stud upright envelope above the authored ground surface.
function MapService.validateMap(map: Model, settings: MapRules.Settings): (boolean, string?)
    local ids: { [string]: boolean } = {}
    local anchors = map:FindFirstChild("Anchors")
    if not anchors then
        return false, "missing Anchors"
    end
    local disk = map:FindFirstChild("GroundDisk")
    if not disk or not disk:IsA("Part") or disk.Shape ~= Enum.PartType.Cylinder then
        return false, "missing cylindrical ground disk"
    end
    if
        math.abs(disk.Position.X - settings.centerX) > 0.01
        or math.abs(disk.Position.Z - settings.centerZ) > 0.01
        or math.abs(disk.Position.Y + disk.Size.X / 2 - settings.groundY) > 0.01
        or math.abs(disk.Size.Y / 2 - settings.radiusStuds) > 0.01
        or math.abs(disk.Size.Z / 2 - settings.radiusStuds) > 0.01
        or math.abs(disk.CFrame.RightVector:Dot(Vector3.yAxis)) < 0.999
    then
        return false, "ground geometry does not match circle configuration"
    end
    local groundCount, launcherCount = 0, 0
    local overlap = OverlapParams.new()
    overlap.FilterType = Enum.RaycastFilterType.Include
    overlap.FilterDescendantsInstances = { map }
    overlap.RespectCanCollide = true
    local rays = RaycastParams.new()
    rays.FilterType = Enum.RaycastFilterType.Include
    rays.FilterDescendantsInstances = { map }
    rays.RespectCanCollide = true
    for _, item in map:GetDescendants() do
        if ids[item.Name] then
            return false, "duplicate map ID: " .. item.Name
        end
        ids[item.Name] = true
        if item:IsA("BasePart") and not item.Anchored then
            return false, "unanchored map part: " .. item.Name
        end
    end
    for _, item in anchors:GetChildren() do
        if not item:IsA("BasePart") then
            return false, "anchor must be a BasePart"
        end
        local ground = string.match(item.Name, "^Ground%d%d$") ~= nil
        if ground then
            groundCount += 1
        end
        if item.Name == "Launcher" then
            launcherCount += 1
        end
        if ground or item.Name == "Launcher" or item.Name == "Lobby" or item.Name == "Operator" then
            local position = item.Position
            if
                (ground or item.Name == "Launcher")
                and (
                    not MapRules.inside(settings, position.X, position.Z)
                    or math.abs(position.Y - settings.groundY - 3) > 0.01
                )
            then
                return false, "anchor outside safe disk: " .. item.Name
            end
            if #workspace:GetPartBoundsInBox(CFrame.new(position), Vector3.new(4, 5.5, 4), overlap) > 0 then
                return false, "blocked avatar clearance: " .. item.Name
            end
            if not workspace:Raycast(position, Vector3.new(0, -4, 0), rays) then
                return false, "unsupported anchor: " .. item.Name
            end
        end
    end
    if groundCount ~= 9 or launcherCount ~= 1 then
        return false, "map requires nine ground anchors and one launcher"
    end
    for index = 1, 9 do
        local anchor = anchors:FindFirstChild(string.format("Ground%02d", index))
        if not anchor or not anchor:IsA("BasePart") then
            return false, "missing numbered ground anchor"
        end
    end
    for _, name in { "Lobby", "Operator" } do
        if not anchors:FindFirstChild(name) then
            return false, "missing " .. name .. " station"
        end
    end
    for _, kind in { "Permanent", "Breakable" } do
        local covers = map:FindFirstChild(kind)
        if not covers or #covers:GetChildren() == 0 then
            return false, "missing " .. kind .. " cover"
        end
        for _, cover in covers:GetChildren() do
            if not cover:IsA("BasePart") or not cover.CanCollide or not cover.CanQuery then
                return false, "cover must collide and block queries"
            end
        end
    end
    return true, nil
end

-- Creates an owner for World.Battlefield. Invalid authoring returns nil/reason, without writes.
-- The caller must destroy the owner when finished. Only one owner may mutate a map subtree.
function MapService.new(world: Instance, adapters: Adapters): (Controller?, string?)
    local settings, reason = MapRules.validate(MapRules.defaults)
    if not settings then
        return nil, reason
    end
    local authored = world:FindFirstChild("Battlefield")
    if not authored or not authored:IsA("Model") then
        return nil, "missing Battlefield model"
    end
    local valid, mapReason = MapService.validateMap(authored, settings)
    if not valid then
        return nil, mapReason
    end
    local snapshot = authored:Clone()
    local map = authored
    local anchorFolder = authored:FindFirstChild("Anchors")
    assert(anchorFolder, "validated anchors disappeared")
    local safeAnchor = anchorFolder:FindFirstChild("Ground05")
    assert(safeAnchor and safeAnchor:IsA("BasePart"), "validated safe anchor disappeared")
    local returnPose = safeAnchor.CFrame
    local stations = authored:FindFirstChild("LobbyStation")
    local lobbyDeck = if stations then stations:FindFirstChild("LobbyDeck") else nil
    if not lobbyDeck or not lobbyDeck:IsA("BasePart") then
        snapshot:Destroy()
        return nil, "missing lobby deck"
    end
    local lobbyPose, lobbySize = lobbyDeck.CFrame, lobbyDeck.Size
    local heartbeat: RBXScriptConnection? = nil
    local destroyed = false
    local controller: Controller
    local function decorate()
        for _, kind in { "Permanent", "Breakable" } do
            local covers = map:FindFirstChild(kind)
            if covers then
                for _, cover in covers:GetChildren() do
                    cover:SetAttribute("CoverId", cover.Name)
                    cover:SetAttribute("CoverKind", kind)
                end
            end
        end
        map:SetAttribute("RadiusStuds", settings.radiusStuds)
        map:SetAttribute("AircraftAltitudeStuds", settings.altitudeStuds)
    end
    local function enforce()
        if destroyed then
            return
        end
        for _, character in adapters.characters() do
            local root = character:FindFirstChild("HumanoidRootPart")
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
                local position = root.Position
                -- Explicit noncombat station exemption only within the authored lobby deck.
                local stationPosition = lobbyPose:PointToObjectSpace(position)
                local inLobby = adapters.allowStations ~= false
                    and math.abs(stationPosition.X) <= lobbySize.X / 2 - 2
                    and math.abs(stationPosition.Z) <= lobbySize.Z / 2 - 2
                    and stationPosition.Y >= lobbySize.Y / 2
                    and stationPosition.Y <= lobbySize.Y / 2 + 20
                if
                    not inLobby
                    and (not MapRules.inside(settings, position.X, position.Z) or position.Y < settings.killY)
                then
                    -- Return to a protected anchor, never clamp onto unknown/blocked edge geometry.
                    character:PivotTo(returnPose)
                    root.AssemblyLinearVelocity = Vector3.zero
                    root.AssemblyAngularVelocity = Vector3.zero
                end
            end
        end
    end
    local function stop()
        if heartbeat then
            heartbeat:Disconnect()
            heartbeat = nil
        end
    end
    controller = {
        start = function()
            if destroyed then
                return false, "map owner destroyed"
            end
            if heartbeat then
                return true, nil
            end
            local ok, errorReason = MapService.validateMap(map, settings)
            if not ok then
                return false, errorReason
            end
            decorate()
            heartbeat = adapters.heartbeat:Connect(enforce)
            return true, nil
        end,
        stop = stop,
        enforce = enforce,
        validate = function()
            return MapService.validateMap(map, settings)
        end,
        rebuild = function()
            if destroyed then
                return false, "map owner destroyed"
            end
            map:Destroy()
            map = snapshot:Clone()
            map.Parent = world
            decorate()
            return MapService.validateMap(map, settings)
        end,
        destroy = function()
            if destroyed then
                return
            end
            stop()
            snapshot:Destroy()
            destroyed = true
        end,
    }
    return controller, nil
end
return MapService
