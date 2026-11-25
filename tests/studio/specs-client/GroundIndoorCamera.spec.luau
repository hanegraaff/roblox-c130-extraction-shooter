--!strict
-- P17: native relocated/rotated camera frames and actual authored room descriptors.
type IndoorAPI = typeof(require(game.StarterPlayer.StarterPlayerScripts.Client.GroundIndoorCamera))

local function indoor(): IndoorAPI
    local scripts = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts", 10)
    local client = if scripts then scripts:WaitForChild("Client", 15) else nil
    local module = if client then client:WaitForChild("GroundIndoorCamera", 10) else nil
    assert(module and module:IsA("ModuleScript"), "client GroundIndoorCamera replication timeout")
    return require(module) :: IndoorAPI
end

return function()
    local test = getfenv().it :: (string, () -> ()) -> ()

    test("P17 authored Outpost camera rooms are metadata below each ceiling", function()
        local camera = indoor()
        local world = assert(workspace:WaitForChild("World", 10), "missing authored world")
        local field = assert(world:WaitForChild("Battlefield", 10), "missing authored battlefield")
        local folder = assert(field:WaitForChild("GroundCameraInteriors", 10), "missing room descriptors")
        local interiors = camera.readInteriors(folder)
        assert(#interiors == 2, "expected both Outpost story descriptors")
        local command, workshop = interiors[1], interiors[2]
        assert(workshop.frame.Position == Vector3.new(144, 4.625, 164), "workshop descriptor moved")
        assert(command.frame.Position == Vector3.new(144, 14.625, 164), "command-room descriptor moved")
        assert(workshop.maxDistanceStuds == 5 and command.maxDistanceStuds == 5, "wrong Outpost camera caps")
        assert(command.frame.Position.Y + command.halfSize.Y == 20.125, "roof clearance differs")
        assert(workshop.frame.Position.Y + workshop.halfSize.Y == 9.125, "ceiling clearance differs")
        for _, descendant in folder:GetDescendants() do
            assert(not descendant:IsA("BasePart"), "camera room metadata entered gameplay geometry")
        end
    end)

    test("P17 native camera frame preserves aim direction and keeps its eye below the ceiling", function()
        local module = indoor()
        local roomFrame = CFrame.new(144, 4.625, 164) * CFrame.Angles(0, math.rad(38), 0)
        local focus = roomFrame:PointToWorldSpace(Vector3.new(0, 3, 0))
        local stock = CFrame.lookAt(roomFrame:PointToWorldSpace(Vector3.new(2, 9, 8)), focus)
        local room = { frame = roomFrame, halfSize = Vector3.new(15.5, 4.5, 23.5), maxDistanceStuds = 5 }
        local projected = module.frame(stock, focus, room, 5, 1)
        local camera = Instance.new("Camera")
        local ok, reason = pcall(function()
            camera.CFrame = projected
            camera.Focus = CFrame.new(focus)
            camera.FieldOfView = 70
            assert((camera.CFrame.LookVector - stock.LookVector).Magnitude < 1e-5, "view rotated")
            assert((camera.Focus.Position - focus).Magnitude < 1e-5, "stock subject focus shifted")
            assert(
                (camera.CFrame.Position - camera.Focus.Position).Magnitude < 5,
                "ceiling did not constrain zoom"
            )
            assert(roomFrame:PointToObjectSpace(camera.CFrame.Position).Y < 4.5, "camera crossed the ceiling")
            assert(camera.FieldOfView == 70, "camera lens changed")
            local close = CFrame.lookAt(focus + Vector3.new(0, 0, 2), focus)
            assert(module.frame(close, focus, room, 5, 1) == close, "nearby stock camera moved backward")
        end)
        camera:Destroy()
        assert(ok, reason)
    end)

    test("P22 stock frame sweeps transparent lobby walls and releases through a real opening", function()
        local module = indoor()
        local scene = Instance.new("Folder")
        scene.Name = "P22LobbyCameraFixture"
        local lobby = Instance.new("Folder")
        lobby.Parent = scene

        local wall = Instance.new("Part")
        wall.Size = Vector3.new(0.6, 12, 5)
        wall.Position = Vector3.new(900, 6, 0)
        wall.Anchored = true
        wall.Transparency = 1
        wall.Parent = lobby

        local unrelated = wall:Clone()
        unrelated.Transparency = 0
        unrelated.Position += Vector3.new(0, 0, 9)
        unrelated.Parent = scene
        scene.Parent = workspace

        local rays = RaycastParams.new()
        rays.FilterType = Enum.RaycastFilterType.Include
        rays.FilterDescendantsInstances = { lobby }
        rays.RespectCanCollide = true
        local ok, failure = pcall(function()
            local focus = Vector3.new(897, 4.5, 0)
            local stock = CFrame.lookAt(Vector3.new(903, 5.6, 0), focus)
            local adjusted = module.lobbyFrame(stock, focus, rays)
            assert(adjusted.Position.X < 899.35, "frame crossed the transparent collider")
            assert((adjusted.LookVector - stock.LookVector).Magnitude < 1e-5, "stock rotation changed")
            local closeFocus = Vector3.new(899.5, 4.5, 0)
            assert(
                module.lobbyFrame(stock, closeFocus, rays).Position.X <= closeFocus.X,
                "start overlap skipped"
            )

            local clear = stock + 9 * Vector3.zAxis
            local clearFocus = focus + 9 * Vector3.zAxis
            assert(
                module.lobbyFrame(clear, clearFocus, rays) == clear,
                "opening or unrelated obstacle clipped zoom"
            )
            wall:Destroy()
            assert(
                module.lobbyFrame(stock, focus, rays) == stock,
                "removed collider still shortened the frame"
            )
            return true
        end)
        scene:Destroy()
        assert(ok, failure)
    end)
end
