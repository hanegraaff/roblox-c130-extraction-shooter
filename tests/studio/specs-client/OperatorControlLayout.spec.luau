--!strict
-- P18 A3/R12: actual native GUI layout and center hit registration. Synthetic
-- canvas origins reproduce the negative safe-area witness without depending on
-- screenshot viewport resizing; the real device-safe canvas is checked as well.
return function()
    local test = getfenv().it :: (string, () -> ()) -> ()
    test(
        "P18 Recenter remains reachable inside negative-origin safe canvas and resized native viewport",
        function()
            local player = game:GetService("Players").LocalPlayer
            local RunService = game:GetService("RunService")
            local GuiService = game:GetService("GuiService")
            local Camera = require(player.PlayerScripts.Client.ThermalCameraController)
            local current = assert(workspace.CurrentCamera, "native layout camera missing")
            local gui = Instance.new("ScreenGui")
            gui.Name = "P18RecenterLayoutFixture"
            gui.ResetOnSpawn = false
            gui.IgnoreGuiInset = true
            gui.ScreenInsets = Enum.ScreenInsets.None
            gui.ClipToDeviceSafeArea = false
            gui.DisplayOrder = 3000
            local canvas = Instance.new("Frame")
            canvas.BackgroundTransparency = 1
            canvas.Active = false
            canvas.ClipsDescendants = true
            canvas.Parent = gui
            local button = Instance.new("TextButton")
            button.Name = "Recenter"
            button.Text = "Recenter"
            button.Size = UDim2.fromOffset(96, 42)
            button.Parent = canvas
            gui.Parent = player.PlayerGui
            local observations: { { [string]: unknown } } = {}
            local function topActionable(point: Vector2): GuiObject?
                for _, object in
                    player.PlayerGui:GetGuiObjectsAtPosition(math.floor(point.X), math.floor(point.Y))
                do
                    if object:IsA("GuiButton") or object:IsA("TextBox") or object.Active then
                        return object
                    end
                end
                return nil
            end
            local ok, problem = pcall(function()
                for _, case in
                    {
                        { origin = Vector2.zero, size = Vector2.new(749, 381) },
                        { origin = Vector2.new(0, -58), size = Vector2.new(749, 381) },
                        { origin = Vector2.new(12, 8), size = Vector2.new(500, 250) },
                        { origin = Vector2.new(0, -58), size = Vector2.new(568, 320) },
                    }
                do
                    canvas.Position = UDim2.fromOffset(case.origin.X, case.origin.Y)
                    canvas.Size = UDim2.fromOffset(case.size.X, case.size.Y)
                    RunService.RenderStepped:Wait()
                    assert(
                        Camera.placeRecenter(button, canvas, current.ViewportSize),
                        "fitting native control was hidden"
                    )
                    local reachable = false
                    for _ = 1, 4 do
                        RunService.RenderStepped:Wait()
                        Camera.placeRecenter(button, canvas, current.ViewportSize)
                        local point = button.AbsolutePosition + button.AbsoluteSize * 0.5
                        if topActionable(point) == button then
                            reachable = true
                            break
                        end
                    end
                    assert(reachable, "native GUI registry cannot reach Recenter center")
                    local origin, size = canvas.AbsolutePosition, canvas.AbsoluteSize
                    local topLeft, bounds = button.AbsolutePosition, button.AbsoluteSize
                    local inset = GuiService:GetGuiInset()
                    assert(
                        topLeft.X >= 0 and topLeft.Y >= 0,
                        "native button starts outside nonnegative input viewport"
                    )
                    assert(
                        topLeft.X >= origin.X
                            and topLeft.Y >= origin.Y
                            and topLeft.X + bounds.X <= origin.X + size.X
                            and topLeft.Y + bounds.Y <= origin.Y + size.Y,
                        "button escaped measured device-safe canvas"
                    )
                    assert(
                        topLeft.X + bounds.X + math.max(0, inset.X) <= current.ViewportSize.X
                            and topLeft.Y + bounds.Y + math.max(0, inset.Y) <= current.ViewportSize.Y,
                        "button escaped actual camera viewport"
                    )
                    local observation: { [string]: unknown } = {
                        canvas = { origin.X, origin.Y, size.X, size.Y },
                        button = { topLeft.X, topLeft.Y, bounds.X, bounds.Y },
                        centerReachable = reachable,
                    }
                    table.insert(observations, observation)
                end
                -- Check the genuine device-safe root, whose origin can differ from
                -- the full-bleed root and changes with native phone emulation.
                gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
                gui.ClipToDeviceSafeArea = true
                canvas.Position = UDim2.fromOffset(0, 0)
                canvas.Size = UDim2.fromScale(1, 1)
                RunService.RenderStepped:Wait()
                assert(
                    Camera.placeRecenter(button, canvas, current.ViewportSize),
                    "device-safe Recenter hidden"
                )
                RunService.RenderStepped:Wait()
                Camera.placeRecenter(button, canvas, current.ViewportSize)
                local center = button.AbsolutePosition + button.AbsoluteSize * 0.5
                assert(
                    center.X >= 0 and center.Y >= 0 and topActionable(center) == button,
                    "real device-safe center unreachable or covered by another GUI"
                )
                script:SetAttribute(
                    "P18NativeRecenterLayout",
                    game:GetService("HttpService"):JSONEncode(observations)
                )
                return true
            end)
            gui:Destroy()
            assert(ok, problem)
        end
    )
end
