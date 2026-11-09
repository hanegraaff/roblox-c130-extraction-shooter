--!strict
-- P14 A4/R06/R12: actual GUI hit queries through the production default-input
-- adapter. Raw pointer coordinates retain viewport space; normal/full-bleed GUIs
-- use current GuiInset only for hit testing. This is not an injected blocked flag.
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
