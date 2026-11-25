--!strict
--[=[
    LobbyGeometry: server-side validation and horizontal containment of the protected station.
    The authored floors define the station footprint, and the rest of the lobby must stay
    outside the playable circle. This module reads Instances without mutating or yielding.
]=]
local MapRules = require(game:GetService("ReplicatedStorage").Shared.MapRules)

local LobbyGeometry = {}

-- A validated floor and its immutable geometry for containment between rebuilds.
export type Floor = { part: BasePart, pose: CFrame, size: Vector3 }

local roomFloorNames = { "LobbyFloorMain", "LobbyFloorTheater", "LobbyFloorGallery" }
local corners = {
    Vector2.new(-1, -1),
    Vector2.new(-1, 1),
    Vector2.new(1, -1),
    Vector2.new(1, 1),
}

-- Find the closest point on an upright oriented rectangle. Tilted decorative
-- meshes use their conservative horizontal projection to avoid missed overlap.
local function overlapsDisk(part: BasePart, settings: MapRules.Settings): boolean
    local half = part.Size / 2
    local pose = part.CFrame
    local center = Vector3.new(settings.centerX, part.Position.Y, settings.centerZ)
    local nearest: Vector3
    if pose.UpVector:Dot(Vector3.yAxis) >= 0.999999 then
        local localCenter = pose:PointToObjectSpace(center)
        nearest = pose:PointToWorldSpace(
            Vector3.new(
                math.clamp(localCenter.X, -half.X, half.X),
                0,
                math.clamp(localCenter.Z, -half.Z, half.Z)
            )
        )
    else
        local xExtent = math.abs(pose.RightVector.X) * half.X
            + math.abs(pose.UpVector.X) * half.Y
            + math.abs(pose.LookVector.X) * half.Z
        local zExtent = math.abs(pose.RightVector.Z) * half.X
            + math.abs(pose.UpVector.Z) * half.Y
            + math.abs(pose.LookVector.Z) * half.Z
        nearest = Vector3.new(
            math.clamp(center.X, part.Position.X - xExtent, part.Position.X + xExtent),
            center.Y,
            math.clamp(center.Z, part.Position.Z - zExtent, part.Position.Z + zExtent)
        )
    end
    return MapRules.inside(settings, nearest.X, nearest.Z)
end

local function readFloor(item: Instance?): Floor?
    if
        not item
        or not item:IsA("BasePart")
        or not item.Anchored
        or not item.CanCollide
        or not item.CanQuery
        or item.CFrame.UpVector:Dot(Vector3.yAxis) < 0.999999
    then
        return nil
    end
    return { part = item, pose = item.CFrame, size = item.Size }
end

-- Returns the configured physical floor footprints, or nil and a diagnostic.
-- The original greybox uses one deck. The furnished lobby uses three joined floors.
function LobbyGeometry.read(map: Model, settings: MapRules.Settings): ({ Floor }?, string?)
    local station = map:FindFirstChild("LobbyStation")
    if not station or not station:IsA("Folder") then
        return nil, "missing protected lobby station"
    end
    local collision = station:FindFirstChild("LobbyCollision")
    if not collision then
        local deck = readFloor(station:FindFirstChild("LobbyDeck"))
        if not deck then
            return nil, "missing upright protected lobby deck"
        end
        if overlapsDisk(deck.part, settings) then
            return nil, "protected lobby deck overlaps playable disk"
        end
        return { deck }, nil
    end
    if not collision:IsA("Folder") then
        return nil, "missing protected lobby collision folder"
    end

    for _, name in { "LobbyDeck", "OperatorCanopy", "OperatorBack" } do
        if station:FindFirstChild(name) then
            return nil, "legacy geometry in furnished lobby: " .. name
        end
    end
    local folder = collision:FindFirstChild("LobbyFloors")
    if not folder or not folder:IsA("Folder") or #folder:GetChildren() ~= #roomFloorNames then
        return nil, "protected lobby needs one floor per room"
    end
    local floors: { Floor } = {}
    for _, name in roomFloorNames do
        local floor = readFloor(folder:FindFirstChild(name))
        if not floor or math.abs(floor.pose.Position.Y + floor.size.Y / 2 - settings.groundY) > 0.01 then
            return nil, "invalid protected lobby floor: " .. name
        end
        table.insert(floors, floor)
    end
    for _, item in station:GetDescendants() do
        if item:IsA("BasePart") and overlapsDisk(item, settings) then
            return nil, "protected lobby overlaps playable disk: " .. item.Name
        end
    end
    return floors, nil
end

-- Tests the four corners of a two-stud horizontal margin against the union of
-- rooms. At a doorway a body can straddle two aligned floors. The exemption
-- extends 20 studs above the floors and starts at the walking surface.
function LobbyGeometry.contains(floors: { Floor }, position: Vector3): boolean
    if #floors == 1 then
        local floor = floors[1]
        local localPosition = floor.pose:PointToObjectSpace(position)
        local half = floor.size / 2
        return math.abs(localPosition.X) <= half.X - 2
            and math.abs(localPosition.Z) <= half.Z - 2
            and localPosition.Y >= half.Y
            and localPosition.Y <= half.Y + 20
    end

    for _, corner in corners do
        local sample = position + Vector3.new(corner.X * 2, 0, corner.Y * 2)
        local withinFloor = false
        for _, floor in floors do
            local localSample = floor.pose:PointToObjectSpace(sample)
            local half = floor.size / 2
            if
                math.abs(localSample.X) <= half.X
                and math.abs(localSample.Z) <= half.Z
                and localSample.Y >= half.Y
                and localSample.Y <= half.Y + 20
            then
                withinFloor = true
                break
            end
        end
        if not withinFloor then
            return false
        end
    end
    return true
end

return LobbyGeometry
