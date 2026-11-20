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
end
