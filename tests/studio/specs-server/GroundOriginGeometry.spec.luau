--!strict
-- P06 A3: real engine checks for server muzzle-cover and Terrain-origin geometry.
return function()
    local test = getfenv().it :: (string, () -> ()) -> ()
    local geometry = require(game:GetService("ServerScriptService").Server.GroundOriginGeometry)
    test("rejects a wall between root and head and a root embedded in cover", function()
        local folder = Instance.new("Folder")
        folder.Name = "GroundOriginFixture"
        folder.Parent = workspace.World.Battlefield
        local root = Instance.new("Part")
        root.Anchored = true
        root.CanCollide = false
        root.Position = Vector3.new(2000, 50, 0)
        root.Parent = workspace
        local head = Instance.new("Part")
        head.Anchored = true
        head.CanCollide = false
        head.Size = Vector3.one
        head.Position = root.Position + Vector3.new(0, 2, 0)
        head.Parent = workspace
        local owner = geometry.new(workspace)
        local ok, reason = pcall(function()
            assert(owner.allows(root, head), "clear body rejected")
            local wall = Instance.new("Part")
            wall.Anchored = true
            wall.Size = Vector3.new(8, 0.2, 8)
            wall.Position = root.Position + Vector3.new(0, 1, 0)
            wall.Parent = folder
            assert(not owner.allows(root, head), "thin cover between root and head bypassed")
            wall.Position = root.Position
            assert(not owner.allows(root, head), "root embedded in cover accepted")
            wall.Position = head.Position
            assert(not owner.allows(root, head), "head embedded in cover accepted")
            wall:Destroy()
            assert(owner.allows(root, head), "clear fire did not recover")
        end)
        owner.destroy()
        root:Destroy()
        head:Destroy()
        folder:Destroy()
        assert(ok, tostring(reason))
    end)
    test("rejects a head buried in Terrain but permits normal standing and jumping", function()
        local terrain = workspace.Terrain
        local center = Vector3.new(2050, 16, 0)
        local size = Vector3.new(32, 16, 32)
        terrain:FillBlock(CFrame.new(center), size, Enum.Material.Rock)
        local root = Instance.new("Part")
        root.Anchored = true
        root.CanCollide = false
        root.Parent = workspace
        local head = Instance.new("Part")
        head.Anchored = true
        head.CanCollide = false
        head.Parent = workspace
        local owner = geometry.new(workspace)
        local ok, reason = pcall(function()
            root.Position = Vector3.new(2050, 12, 0)
            head.Position = Vector3.new(2050, 14, 0)
            assert(not owner.allows(root, head), "head buried in terrain accepted")
            root.Position = Vector3.new(2050, 27, 0)
            head.Position = Vector3.new(2050, 29, 0)
            assert(owner.allows(root, head), "standing above terrain rejected")
            root.Position = Vector3.new(2050, 36, 0)
            head.Position = Vector3.new(2050, 38, 0)
            assert(owner.allows(root, head), "jumping above terrain rejected")
        end)
        owner.destroy()
        root:Destroy()
        head:Destroy()
        terrain:FillBlock(CFrame.new(center), size, Enum.Material.Air)
        assert(ok, tostring(reason))
    end)
    test("permits normal standing above a sloped Terrain surface", function()
        local terrain = workspace.Terrain
        local center = Vector3.new(2150, 16, 0)
        terrain:FillBall(center, 20, Enum.Material.Rock)
        local root = Instance.new("Part")
        root.Anchored = true
        root.CanCollide = false
        root.Parent = workspace
        local head = Instance.new("Part")
        head.Anchored = true
        head.CanCollide = false
        head.Parent = workspace
        local owner = geometry.new(workspace)
        local ok, reason = pcall(function()
            for _, x in { -8, -4, 0, 4, 8 } do
                local cast = workspace:Raycast(Vector3.new(center.X + x, 60, 0), Vector3.new(0, -60, 0))
                assert(cast and cast.Instance == terrain, "sloped terrain sample missing")
                root.Position = cast.Position + Vector3.new(0, 3, 0)
                head.Position = cast.Position + Vector3.new(0, 4.5, 0)
                assert(owner.allows(root, head), "normal slope stance rejected at x=" .. x)
            end
        end)
        owner.destroy()
        root:Destroy()
        head:Destroy()
        terrain:FillBall(center, 20, Enum.Material.Air)
        assert(ok, tostring(reason))
    end)
end
