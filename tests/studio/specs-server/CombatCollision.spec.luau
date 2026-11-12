--!strict
-- P05 A4: actual Terrain and thin-cover queries through the production shell sweep.
-- The fixture rebuilds the authored level and destroys its owned map afterward.
local Server = game:GetService("ServerScriptService").Server
local CombatRuntime = require(Server.CombatRuntime)
local CombatService = require(Server.CombatService)
local MapService = require(Server.MapService)

return function()
    local test = getfenv().it :: (string, () -> ()) -> ()
    test("P05 swept shell reaches reproduced orbit-moving sloped terrain surface", function()
        local world = Instance.new("Folder")
        world.Name = "P05CollisionFixture"
        local map = workspace.World.Battlefield:Clone()
        map.Parent = world
        world.Parent = workspace
        local heartbeat = Instance.new("BindableEvent")
        local owner, reason = MapService.new(world, {
            characters = function()
                return {}
            end,
            heartbeat = heartbeat.Event,
        })
        assert(owner, reason)
        local ok, failure = pcall(function()
            assert(owner.start(), "map fixture failed")
            local terrain = workspace.Terrain
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Include
            params.FilterDescendantsInstances = { terrain }
            local origin = Vector3.new(363.7364, 138, 31.1414)
            local target = Vector3.new(-263.99924, 13.56503, -159.99977)
            local direction = (target - origin).Unit
            local travel = (target - origin).Magnitude + 0.25
            local deadline = os.clock() + 5
            local preflight = workspace:Raycast(origin, direction * travel, params)
            while (not preflight or (preflight.Position - target).Magnitude >= 1) and os.clock() < deadline do
                task.wait()
                preflight = workspace:Raycast(origin, direction * travel, params)
            end
            assert(
                preflight and (preflight.Position - target).Magnitude < 1,
                "terrain query did not converge to the reproduced surface"
            )
            for _, weapon in { "GAU23", "M102" } do
                local position = origin
                local remaining = travel
                local hit: RaycastResult? = nil
                while remaining > 0 and not hit do
                    local distance = math.min(remaining, CombatService.profiles[weapon].speed / 60)
                    hit = CombatRuntime.sweep(
                        position,
                        CombatService.profiles[weapon].collisionRadius,
                        direction * distance,
                        params
                    )
                    position += direction * distance
                    remaining -= distance
                end
                assert(hit and hit.Instance == terrain, weapon .. " missed the reproduced terrain surface")
                assert((hit.Position - target).Magnitude < 5, weapon .. " hit far from the target")
            end
        end)
        owner.destroy()
        heartbeat:Destroy()
        world:Destroy()
        assert(ok, tostring(failure))
    end)
    test("P05 shell sweep hits thin cover and cannot create an empty-space impact", function()
        local wall = Instance.new("Part")
        wall.Name = "P05ThinCover"
        wall.Anchored = true
        wall.Size = Vector3.new(0.2, 10, 10)
        wall.CFrame = CFrame.new(0, 120, 0)
        wall.Parent = workspace
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Include
        params.FilterDescendantsInstances = { wall }
        local overlap = OverlapParams.new()
        overlap.FilterType = Enum.RaycastFilterType.Include
        overlap.FilterDescendantsInstances = { wall }
        local probe = Instance.new("Part")
        probe.Anchored = true
        probe.Shape = Enum.PartType.Ball
        probe.Size = Vector3.one * 0.1
        probe.CanCollide = false
        probe.CanTouch = false
        probe.CanQuery = false
        probe.Transparency = 1
        probe.Position = Vector3.new(0, 120, 0)
        probe.Parent = workspace
        local ok, failure = pcall(function()
            local ownRay = RaycastParams.new()
            ownRay.FilterType = Enum.RaycastFilterType.Include
            ownRay.FilterDescendantsInstances = { probe }
            assert(
                not workspace:Raycast(Vector3.new(-1, 120, 0), Vector3.new(2, 0, 0), ownRay),
                "invisible muzzle probe was ray-queryable"
            )
            local ownOverlap = OverlapParams.new()
            ownOverlap.FilterType = Enum.RaycastFilterType.Include
            ownOverlap.FilterDescendantsInstances = { probe }
            assert(
                #workspace:GetPartBoundsInRadius(probe.Position, 1, ownOverlap) == 0,
                "invisible muzzle probe appeared in normal spatial queries"
            )
            assert(
                CombatRuntime.initialOverlap(probe, overlap, workspace) == wall,
                "muzzle inside solid cover bypassed initial overlap"
            )
            probe.Position = Vector3.new(-2, 120, 0)
            assert(
                not CombatRuntime.initialOverlap(probe, overlap, workspace),
                "clear muzzle falsely marked obstructed"
            )
            for _, profile in { CombatService.profiles.GAU23, CombatService.profiles.M102 } do
                local hit = CombatRuntime.sweep(
                    Vector3.new(-10, 120, 0),
                    profile.collisionRadius,
                    Vector3.new(20, 0, 0),
                    params
                )
                assert(hit and hit.Instance == wall, "thin cover was bypassed")
                assert(
                    not CombatRuntime.sweep(
                        Vector3.new(-10, 140, 0),
                        profile.collisionRadius,
                        Vector3.new(20, 0, 0),
                        params
                    ),
                    "empty space produced an impact"
                )
            end
        end)
        probe:Destroy()
        wall:Destroy()
        assert(ok, tostring(failure))
    end)
end
