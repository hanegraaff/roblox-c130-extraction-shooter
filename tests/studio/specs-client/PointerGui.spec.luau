--!strict
-- P14 A4/R06/R12: actual GUI hit queries through the production default-input
-- adapter. Raw pointer coordinates retain viewport space; normal/full-bleed GUIs
-- use current GuiInset only for hit testing. Actual UDim draw centres also match
-- the production integer-raster helper. This is not an injected blocked flag.
return function()
    local test = getfenv().it :: (string, () -> ()) -> ()
    test(
        "P14 default pointer input blocks actual normal and full-bleed GUI buttons with current inset",
        function()
            local player = game:GetService("Players").LocalPlayer
            local playerGui = player.PlayerGui
            local CameraController = require(player.PlayerScripts.Client.ThermalCameraController)
            local GuiService = game:GetService("GuiService")
            local RunService = game:GetService("RunService")
            local Input = game:GetService("UserInputService")
            local HttpService = game:GetService("HttpService")
            local PanRules = require(game:GetService("ReplicatedStorage").Shared.AircraftPanRules)
            local containers: { ScreenGui } = {}
            local function screen(name: string, ignoreInset: boolean): ScreenGui
                local gui = Instance.new("ScreenGui")
                gui.Name = name
                gui.IgnoreGuiInset = ignoreInset
                if ignoreInset then
                    gui.ScreenInsets = Enum.ScreenInsets.None
                    gui.ClipToDeviceSafeArea = false
                end
                gui.DisplayOrder = 2000
                gui.Parent = playerGui
                table.insert(containers, gui)
                return gui
            end
            local function button(parent: ScreenGui, y: number): TextButton
                local value = Instance.new("TextButton")
                value.Name = "PointerGuiRegressionButton"
                value.Position = UDim2.fromOffset(24, y)
                value.Size = UDim2.fromOffset(180, 48)
                value.Text = "Pointer regression"
                value.Parent = parent
                return value
            end
            local normal = button(screen("PointerNormalGui", false), 240)
            local full = button(screen("PointerFullBleedGui", true), 340)
            local box = Instance.new("TextBox")
            box.Name = "PointerFocusRegression"
            box.Position = UDim2.fromOffset(24, 440)
            box.Size = UDim2.fromOffset(180, 48)
            box.Parent = containers[1]
            local ok, failure = pcall(function()
                RunService.RenderStepped:Wait()
                RunService.RenderStepped:Wait()
                local inset = GuiService:GetGuiInset()
                for _, control in { normal, full } do
                    assert(
                        control.AbsoluteSize.X > 0 and control.AbsoluteSize.Y > 0,
                        "GUI layout did not render"
                    )
                    local raw = control.AbsolutePosition + control.AbsoluteSize * 0.5 + inset
                    local frame = CameraController.input(playerGui, raw, true)
                    assert(frame.blocked, "actual GUI button did not block edge-pan input")
                    assert(frame.position == raw, "GUI conversion changed raw camera/pan coordinates")
                end
                local camera = workspace.CurrentCamera
                assert(camera, "viewport absent")
                -- Actual UDim/GUI regression for the independently reproduced
                -- .995/.995 truncation mismatch. The same production raster helper
                -- supplies both the draw offset and ray pixel coordinate.
                local probe = Instance.new("TextLabel")
                probe.Name = "RasterReticleRegression"
                probe.Size = UDim2.fromOffset(34, 34)
                probe.AnchorPoint = Vector2.new(0.5, 0.5)
                probe.Text = "+"
                probe.BackgroundTransparency = 1
                probe.Parent = containers[2]
                local origin = Instance.new("Frame")
                origin.Name = "ProjectionOrigin"
                origin.Size = UDim2.fromOffset(0, 0)
                origin.BackgroundTransparency = 1
                origin.Parent = containers[2]
                RunService.RenderStepped:Wait()
                local viewport = camera.ViewportSize
                local rasterSamples: { unknown } = {}
                for _, raw in
                    {
                        Vector2.new(540.995, 309.995),
                        viewport * 0.5,
                        Vector2.new(viewport.X * 0.15, viewport.Y * 0.85),
                        Vector2.new(viewport.X * 0.85, viewport.Y * 0.15),
                    }
                do
                    local raster = PanRules.raster(raw.X, raw.Y, viewport.X, viewport.Y)
                    assert(raster, "valid fractional reticle rejected")
                    local rayPixels = Vector2.new(raster.x, raster.y)
                    local guiOrigin = origin.AbsolutePosition + GuiService:GetGuiInset()
                    local offset = CameraController.guiOffset(rayPixels, guiOrigin)
                    assert(offset, "valid GUI projection offset rejected")
                    probe.Position = offset
                    RunService.RenderStepped:Wait()
                    RunService.RenderStepped:Wait()
                    local actualInset = GuiService:GetGuiInset()
                    local drawn = probe.AbsolutePosition + probe.AbsoluteSize * 0.5 + actualInset
                    local errorPixels = (drawn - rayPixels).Magnitude
                    table.insert(rasterSamples, {
                        raw = { raw.X, raw.Y },
                        ray = { raster.x, raster.y },
                        storedOffset = { probe.Position.X.Offset, probe.Position.Y.Offset },
                        drawn = { drawn.X, drawn.Y },
                        inset = { actualInset.X, actualInset.Y },
                        guiOrigin = { guiOrigin.X, guiOrigin.Y },
                        errorPixels = errorPixels,
                    })
                    player.PlayerScripts.ClientTests:SetAttribute(
                        "ReticleRasterProbe",
                        HttpService:JSONEncode({
                            viewport = { viewport.X, viewport.Y },
                            samples = rasterSamples,
                        })
                    )
                    assert(
                        probe.Position.X.Offset == offset.X.Offset
                            and probe.Position.Y.Offset == offset.Y.Offset,
                        "GUI truncated converted reticle coordinates"
                    )
                    assert(errorPixels <= 1, "actual raster reticle centre differs from ray pixels")
                end
                local openPointer = Vector2.new(camera.ViewportSize.X * 0.92, camera.ViewportSize.Y * 0.5)
                assert(
                    not CameraController.input(playerGui, openPointer, true).blocked,
                    "empty viewport falsely blocked"
                )
                assert(
                    CameraController.input(playerGui, openPointer, false).blocked,
                    "window focus loss did not block"
                )
                box:CaptureFocus()
                local deadline = os.clock() + 3
                while Input:GetFocusedTextBox() ~= box and os.clock() < deadline do
                    task.wait()
                end
                assert(Input:GetFocusedTextBox() == box, "actual text focus not acquired")
                assert(
                    CameraController.input(playerGui, openPointer, true).blocked,
                    "actual text focus did not block"
                )
                box:ReleaseFocus()
                containers[1].Enabled = false
                containers[2].Enabled = false
                RunService.RenderStepped:Wait()
                assert(
                    not CameraController.input(playerGui, openPointer, true).blocked,
                    "released GUI/text focus trapped input"
                )
                player.PlayerScripts.ClientTests:SetAttribute("PointerGuiInset", inset)
                return true
            end)
            if Input:GetFocusedTextBox() == box then
                box:ReleaseFocus()
            end
            for _, gui in containers do
                gui:Destroy()
            end
            assert(ok, tostring(failure))
        end
    )
end
