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
    test("P06 phone rifle status avoids the centered reticle and action buttons", function()
        local player = game:GetService("Players").LocalPlayer
        local runService = game:GetService("RunService")
        local controller = require(player.PlayerScripts.Client.GroundCombatController)
        local gui = Instance.new("ScreenGui")
        gui.Name = "GroundLayoutProbe"
        gui.IgnoreGuiInset = true
        gui.Parent = player.PlayerGui
        local viewport = Instance.new("Frame")
        viewport.BackgroundTransparency = 1
        viewport.Parent = gui
        local status = Instance.new("TextLabel")
        status.AnchorPoint = Vector2.new(0.5, 1)
        status.Position, status.Size = controller.statusLayout(true)
        status.TextSize = 16
        status.Font = Enum.Font.Gotham
        status.Text = "M-7 • 30 / 120 • R reload"
        status.Parent = viewport
        local cross = Instance.new("TextLabel")
        cross.AnchorPoint = Vector2.new(0.5, 0.5)
        cross.Position = UDim2.fromScale(0.5, 0.5)
        cross.Size = UDim2.fromOffset(24, 24)
        cross.Parent = viewport
        local function button(y: number, height: number): TextButton
            local item = Instance.new("TextButton")
            item.AnchorPoint = Vector2.new(1, 1)
            item.Position = UDim2.new(1, -24, 1, y)
            item.Size = UDim2.fromOffset(90, height)
            item.Parent = viewport
            return item
        end
        local fire = button(-130, 70)
        local reload = button(-210, 54)
        local function overlaps(a: GuiObject, b: GuiObject): boolean
            local a0, b0 = a.AbsolutePosition, b.AbsolutePosition
            local a1, b1 = a0 + a.AbsoluteSize, b0 + b.AbsoluteSize
            return a0.X < b1.X and b0.X < a1.X and a0.Y < b1.Y and b0.Y < a1.Y
        end
        local ok, failure = pcall(function()
            for _, size in { Vector2.new(750, 381), Vector2.new(568, 320), Vector2.new(852, 393) } do
                viewport.Size = UDim2.fromOffset(size.X, size.Y)
                runService.RenderStepped:Wait()
                runService.RenderStepped:Wait()
                assert(status.AbsoluteSize == Vector2.new(260, 36), "rifle status lost readable size")
                assert(status.TextBounds.X <= status.AbsoluteSize.X, "ammunition text clipped")
                assert(not overlaps(status, cross), "rifle status overlaps centered reticle")
                assert(not overlaps(status, fire), "rifle status overlaps fire")
                assert(not overlaps(status, reload), "rifle status overlaps reload")
                local offset = status.AbsolutePosition - viewport.AbsolutePosition
                assert(offset.X >= 0 and offset.Y >= 0, "status escaped viewport")
                assert(
                    offset.X + status.AbsoluteSize.X <= size.X and offset.Y + status.AbsoluteSize.Y <= size.Y,
                    "status escaped viewport"
                )
            end
            local desktopPosition, desktopSize = controller.statusLayout(false)
            assert(desktopPosition == UDim2.new(0.5, 0, 1, -100), "desktop status position changed")
            assert(desktopSize == UDim2.fromOffset(330, 36), "desktop status size changed")
        end)
        gui:Destroy()
        assert(ok, tostring(failure))
    end)
end
