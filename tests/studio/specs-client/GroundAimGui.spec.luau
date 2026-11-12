--!strict
-- P06: actual GUI layout and camera rays agree with ground aim on both input
-- modes. Uses the measured Studio inset and production projection adapter.
return function()
    local test = getfenv().it :: (string, () -> ()) -> ()
    test("P06 ground mouse and touch reticles agree with viewport rays", function()
        local players = game:GetService("Players")
        local guiService = game:GetService("GuiService")
        local runService = game:GetService("RunService")
        local input = game:GetService("UserInputService")
        local player = players.LocalPlayer
        local controller = require(player.PlayerScripts.Client.GroundCombatController)
        local camera = workspace.CurrentCamera
        assert(camera, "current camera missing")
        local gui = Instance.new("ScreenGui")
        gui.Name = "GroundAimProjectionProbe"
        gui.IgnoreGuiInset = true
        local origin = Instance.new("Frame")
        origin.Size = UDim2.fromOffset(0, 0)
        origin.BackgroundTransparency = 1
        origin.Parent = gui
        local cross = Instance.new("TextLabel")
        cross.Size = UDim2.fromOffset(24, 24)
        cross.AnchorPoint = Vector2.new(0.5, 0.5)
        cross.Parent = gui
        gui.Parent = player.PlayerGui
        local ok, failure = pcall(function()
            runService.RenderStepped:Wait()
            local inset = guiService:GetGuiInset()
            local viewport = camera.ViewportSize
            local samples = {
                { touch = false, mouse = input:GetMouseLocation() },
                { touch = false, mouse = Vector2.new(viewport.X * 0.5, viewport.Y * 0.3) + inset },
                { touch = true, mouse = Vector2.new(0, 0) },
            }
            for _, sample in samples do
                local pixels, offset = controller.projectAim(
                    viewport,
                    sample.mouse,
                    sample.touch,
                    inset,
                    origin.AbsolutePosition
                )
                cross.Position = offset
                runService.RenderStepped:Wait()
                runService.RenderStepped:Wait()
                local drawn = cross.AbsolutePosition + cross.AbsoluteSize * 0.5
                local expected = if sample.touch then viewport * 0.5 else sample.mouse - inset
                assert((drawn - expected).Magnitude <= 1, "reticle does not follow viewport aim")
                assert((drawn - pixels).Magnitude <= 1, "drawn reticle and ray pixels diverge")
                local actualRay = camera:ViewportPointToRay(pixels.X, pixels.Y)
                local drawnRay = camera:ViewportPointToRay(drawn.X, drawn.Y)
                assert(
                    (actualRay.Direction - drawnRay.Direction).Magnitude < 0.002,
                    "firing ray misses the actual drawn reticle"
                )
            end
        end)
        gui:Destroy()
        assert(ok, tostring(failure))
    end)
end
