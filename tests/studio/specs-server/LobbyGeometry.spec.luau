--!strict
-- R01/R02/R24, P22 A1–A3: real Workspace floor, doorway and furnishing queries.
-- The fixture mounts the managed collision model in a disposable battlefield
-- clone. Native art loading, avatar walking and multiplayer require Play.
local Server = game:GetService("ServerScriptService").Server
local MapRules = require(game:GetService("ReplicatedStorage").Shared.MapRules)
local MapService = require(Server.MapService)
local LobbyGeometry = require(Server.LobbyGeometry)

-- Mount the exact authored collision independently of any cloud mesh access.
local function fixture(callback: (Model, Folder) -> ())
    local room = Instance.new("Folder")
    room.Name = "P22LobbyFixture"
    local battlefield = workspace.World.Battlefield:Clone() :: Model
    battlefield.Parent = room
    local station = battlefield:FindFirstChild("LobbyStation") :: Folder
    for _, child in station:GetChildren() do
        child:Destroy()
    end
    local collision = game:GetService("ServerStorage").Tests.Fixtures.LobbyCollision:Clone() :: Folder
    collision.Parent = station
    room.Parent = workspace
    local ok, failure = pcall(function()
        callback(battlefield, collision)
        return true
    end)
    room:Destroy()
    assert(ok, tostring(failure))
end

local function site(x: number, y: number, height: number): Vector3
    return Vector3.new(520 + x, height, -y)
end

-- Verify the union of collider floors, not a single enclosing rectangle.
local function assertContainment(floors: { LobbyGeometry.Floor })
    for _, point in
        {
            site(0, 0, 3),
            site(0, 15, 3),
            site(-25, 26, 3),
            site(25, 26, 3),
            site(-67, 22, 3),
            site(62, 22, 3),
        }
    do
        assert(LobbyGeometry.contains(floors, point), "protected footprint gap: " .. tostring(point))
    end
    for _, point in
        {
            site(-66, 0, 3),
            site(61, 1, 3),
            site(-69, 26, 3),
            site(64, 26, 3),
            site(0, 0, -0.01),
            site(0, 0, 20.01),
        }
    do
        assert(not LobbyGeometry.contains(floors, point), "unexpected protection: " .. tostring(point))
    end
end

local function rayParams(scope: Instance): RaycastParams
    local rays = RaycastParams.new()
    rays.FilterType = Enum.RaycastFilterType.Include
    rays.FilterDescendantsInstances = { scope }
    rays.RespectCanCollide = true
    return rays
end

return function()
    local test = getfenv().it :: (string, () -> ()) -> ()

    test(
        "P22 protects only the joined lobby floors and rejects overlapping wing and visual extents",
        function()
            fixture(function(battlefield, collision)
                local floors, reason = LobbyGeometry.read(battlefield, MapRules.defaults)
                assert(floors, reason)
                assertContainment(floors)
                local ok, invalid = MapService.validateMap(battlefield, MapRules.defaults)
                assert(ok, invalid)
                for _, floor in floors do
                    local part = floor.part
                    local pose = part.CFrame
                    part.CFrame = CFrame.new(370, pose.Position.Y, 0)
                    local accepted, message = MapService.validateMap(battlefield, MapRules.defaults)
                    assert(
                        not accepted and message == "protected lobby overlaps playable disk: " .. part.Name,
                        message
                    )
                    part.CFrame = pose
                end
                local stray = Instance.new("Part")
                stray.Name = "P22_TestOverhang"
                stray.Anchored = true
                stray.CanCollide = false
                stray.CanQuery = false
                stray.CFrame = CFrame.new(362, 25, 0) * CFrame.Angles(math.rad(40), 0, math.rad(55))
                stray.Size = Vector3.new(12, 1, 2)
                stray.Parent = collision.Parent
                local accepted, message = MapService.validateMap(battlefield, MapRules.defaults)
                assert(
                    not accepted and message == "protected lobby overlaps playable disk: " .. stray.Name,
                    message
                )
                stray:Destroy()

                local anchors = battlefield:FindFirstChild("Anchors") :: Folder
                for _, name in { "Lobby", "Operator" } do
                    local anchor = anchors:FindFirstChild(name) :: BasePart
                    local pose = anchor.CFrame
                    anchor.CFrame = CFrame.new(site(-66, 0, 3))
                    local valid, anchorReason = MapService.validateMap(battlefield, MapRules.defaults)
                    assert(
                        not valid and anchorReason == "anchor outside protected lobby floor: " .. name,
                        anchorReason
                    )
                    anchor.CFrame = pose
                end
                assert(MapService.validateMap(battlefield, MapRules.defaults))
            end)
        end
    )

    test("P22 thresholds floors and furniture have real colliders with a clear avatar route", function()
        fixture(function(_, collision)
            local overlaps = OverlapParams.new()
            overlaps.FilterType = Enum.RaycastFilterType.Include
            overlaps.FilterDescendantsInstances = { collision }
            overlaps.RespectCanCollide = true
            local floors = collision:FindFirstChild("LobbyFloors") :: Folder
            local floorRays = rayParams(floors)
            local rays = rayParams(collision)
            local routes = {
                {
                    site(0, 0, 3.1),
                    site(0, 15, 3.1),
                    site(-11.5, 21.5, 3.1),
                    site(-25, 26, 3.1),
                    site(-29.9, 32.2, 3.1),
                    site(-31.2, 35.7, 3.1),
                    site(-31.2, 37, 3.1),
                    site(-33.8, 37.8, 3.1),
                    site(-36.2, 38.1, 3.1),
                    site(-47.5, 38.1, 3.1),
                    site(-47.5, 12, 3.1),
                },
                {
                    site(0, 15, 3.1),
                    site(11.5, 21.5, 3.1),
                    site(25, 26, 3.1),
                    site(32.5, 26, 3.1),
                    site(32.7, 36.5, 3.1),
                    site(36, 41.6, 3.1),
                    site(54.5, 41.6, 3.1),
                    site(59.2, 37.6, 3.1),
                    site(59.2, 18.3, 3.1),
                    site(54.2, 15.2, 3.1),
                    site(35.9, 15.2, 3.1),
                    site(31.8, 22, 3.1),
                    site(25, 26, 3.1),
                },
            }
            for _, points in routes do
                for index = 1, #points - 1 do
                    local start, finish = points[index], points[index + 1]
                    local samples = math.ceil((finish - start).Magnitude / 0.5)
                    for sample = 0, samples do
                        local position = start:Lerp(finish, sample / samples)
                        local held =
                            workspace:GetPartBoundsInBox(CFrame.new(position), Vector3.new(4, 6, 4), overlaps)
                        assert(#held == 0, "route obstruction at " .. tostring(position))
                        for _, offset in { Vector3.zero, Vector3.new(-1.8, 0, 0), Vector3.new(1.8, 0, 0) } do
                            local hit = workspace:Raycast(position + offset, -4 * Vector3.yAxis, floorRays)
                            assert(
                                hit and math.abs(hit.Position.Y) < 0.01,
                                "unsupported route at " .. tostring(position)
                            )
                        end
                    end
                end
            end

            for _, side in { -1, 1 } do
                local direction = Vector3.xAxis * side * 6
                assert(workspace:Raycast(site(side * 22, 26, 2), direction, rays) == nil, "doorway blocked")
                local header = workspace:Raycast(site(side * 22, 26, 14.5), direction, rays)
                assert(header and string.find(header.Instance.Name, "PortalHeader"), "missing doorway header")
                local wall = workspace:Raycast(site(side * 22, 17.8, 3), direction, rays)
                assert(wall and string.find(wall.Instance.Name, "PortalSouth"), "missing doorway wall")
            end

            for _, sample in
                {
                    { p = site(7.4, 31.5, 3), name = "LobbyDaisDrum" },
                    { p = site(45, 29, 3), name = "LobbyGalleryBench" },
                    { p = site(-41.45, 14.5, 4.25), name = "LobbyTheaterSeat1Right1Back" },
                    { p = site(-47.5, 45.65, 3.95), name = "LobbyTelevisionTable" },
                }
            do
                local hit = workspace:Raycast(sample.p, -4 * Vector3.yAxis, rays)
                assert(hit and hit.Instance.Name == sample.name, "missing collider " .. sample.name)
            end
        end)
    end)

    test("P22 lobby floor exemption is disabled for the production Ground containment adapter", function()
        fixture(function(battlefield, collision)
            local world = battlefield.Parent :: Folder
            local signal = Instance.new("BindableEvent")
            signal.Parent = world
            local body = Instance.new("Model")
            body.Name = "P22ContainmentCharacterFixture"
            body.Parent = world
            local root = Instance.new("Part")
            root.Name = "HumanoidRootPart"
            root.Anchored = true
            root.Parent = body
            body.PrimaryPart = root
            Instance.new("Humanoid").Parent = body
            local permit = MapService.new(world, {
                characters = function()
                    return { body }
                end,
                heartbeat = signal.Event,
            })
            local deny = MapService.new(world, {
                characters = function()
                    return { body }
                end,
                heartbeat = signal.Event,
                allowStations = false,
            })
            assert(permit and deny, "could not start containment check")
            local ok, failure = pcall(function()
                for _, point in { site(-67, 22, 3), site(62, 22, 3), site(-25, 26, 3), site(25, 26, 3) } do
                    root.CFrame = CFrame.new(point)
                    permit.enforce()
                    assert(root.Position == point, "exempt body returned from protected room")
                    deny.enforce()
                    assert(
                        root.Position
                            == (
                                (battlefield:FindFirstChild("Anchors") :: Folder):FindFirstChild(
                                    "Ground05"
                                ) :: BasePart
                            ).Position,
                        "combat containment accepted the lobby"
                    )
                end
                for _, part in collision:GetDescendants() do
                    if part:IsA("BasePart") then
                        assert(part:GetAttribute("CoverId") == nil, "lobby registered as battle cover")
                    end
                end
            end)
            permit.destroy()
            deny.destroy()
            assert(ok, tostring(failure))
        end)
    end)
end
