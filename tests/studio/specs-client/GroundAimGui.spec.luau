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
        local http = game:GetService("HttpService")
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
            local deadline = os.clock() + 10
            local ready = false
            while os.clock() < deadline do
                runService.RenderStepped:Wait()
                local current = workspace.CurrentCamera
                if current and current.ViewportSize.X >= 200 and current.ViewportSize.Y >= 200 then
                    ready = true
                    break
                end
            end
            assert(ready, "camera viewport did not reach 200×200 within 10 seconds")
            for _, mode in { "world", "native", "touch" } do
                local camera = workspace.CurrentCamera
                assert(camera, "current camera disappeared")
                local viewport = camera.ViewportSize
                local inset = guiService:GetGuiInset()
                local worldPoint = camera.CFrame:PointToWorldSpace(Vector3.new(6, 4, -100))
                local projected = camera:WorldToViewportPoint(worldPoint)
                local mouse = if mode == "world"
                    then Vector2.new(projected.X, projected.Y)
                    else input:GetMouseLocation()
                -- Native mouse and its engine UnitRay are sampled together,
                -- without rendering waits between them.
                local nativeRay = if mode == "native" then player:GetMouse().UnitRay else nil
                local pixels, offset =
                    controller.projectAim(viewport, mouse, mode == "touch", inset, origin.AbsolutePosition)
                local actualRay = camera:ViewportPointToRay(pixels.X, pixels.Y)
                local diagnostic = {
                    mode = mode,
                    viewport = { viewport.X, viewport.Y },
                    inset = { inset.X, inset.Y },
                    fov = camera.FieldOfView,
                    cameraCFrame = { camera.CFrame:GetComponents() },
                    mouse = { mouse.X, mouse.Y },
                    pixels = { pixels.X, pixels.Y },
                    world = { worldPoint.X, worldPoint.Y, worldPoint.Z },
                    worldProjection = { projected.X, projected.Y, projected.Z },
                    rayOrigin = { actualRay.Origin.X, actualRay.Origin.Y, actualRay.Origin.Z },
                    rayDirection = { actualRay.Direction.X, actualRay.Direction.Y, actualRay.Direction.Z },
                }
                local detail = http:JSONEncode(diagnostic)
                if nativeRay then
                    local rawRay = camera:ViewportPointToRay(mouse.X, mouse.Y)
                    assert(
                        rawRay.Direction.Unit:Dot(nativeRay.Direction.Unit) > 0.99999,
                        "raw viewport ray disagrees with native Mouse.UnitRay: " .. detail
                    )
                    local nativePoint = nativeRay.Origin + nativeRay.Direction.Unit * 100
                    local nativeProjection = camera:WorldToViewportPoint(nativePoint)
                    local nativePixelError = (pixels - Vector2.new(nativeProjection.X, nativeProjection.Y)).Magnitude
                    assert(
                        nativePixelError <= 1,
                        "production aim differs from native Mouse.UnitRay by "
                            .. tostring(nativePixelError)
                            .. " pixels: "
                            .. detail
                    )
                end
                if mode == "world" then
                    -- Compare the independently projected world point to the
                    -- reprojected actual production ray in pixels. This tests
                    -- integer rasterization independently of viewport FOV.
                    local along = (worldPoint - actualRay.Origin).Magnitude
                    local actualProjection =
                        camera:WorldToViewportPoint(actualRay.Origin + actualRay.Direction.Unit * along)
                    local errorPixels = (Vector2.new(actualProjection.X, actualProjection.Y) - mouse).Magnitude
                    assert(
                        errorPixels <= 1,
                        "ground ray misses independently projected world point by "
                            .. tostring(errorPixels)
                            .. " pixels: "
                            .. detail
                    )
                    -- The old double-inset subtraction must fail the same
                    -- independent projection even on zero-inset machines.
                    local oldRay = camera:ViewportPointToRay(mouse.X, mouse.Y - 58)
                    local oldProjection =
                        camera:WorldToViewportPoint(oldRay.Origin + oldRay.Direction.Unit * along)
                    assert(
                        (Vector2.new(oldProjection.X, oldProjection.Y) - mouse).Magnitude > 40,
                        "old inset error was not detected: " .. detail
                    )
                end
                cross.Position = offset
                runService.RenderStepped:Wait()
                runService.RenderStepped:Wait()
                local drawn = cross.AbsolutePosition + cross.AbsoluteSize * 0.5 + guiService:GetGuiInset()
                local expected = if mode == "touch" then viewport * 0.5 else mouse
                assert((drawn - expected).Magnitude <= 1, "reticle does not follow viewport aim: " .. detail)
                assert((drawn - pixels).Magnitude <= 1, "drawn reticle and ray pixels diverge: " .. detail)
                local drawnRay = camera:ViewportPointToRay(drawn.X, drawn.Y)
                actualRay = camera:ViewportPointToRay(pixels.X, pixels.Y)
                assert(
                    (actualRay.Direction - drawnRay.Direction).Magnitude < 0.002,
                    "firing ray misses the actual drawn reticle: " .. detail
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
                assert(status.AbsoluteSize == Vector2.new(260, 24), "rifle status lost readable size")
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
    test("P06 existing ground HUD follows input capability changes and cleans up", function()
        local player = game:GetService("Players").LocalPlayer
        local runService = game:GetService("RunService")
        local controllerModule = require(player.PlayerScripts.Client.GroundCombatController)
        local before: { [Instance]: boolean } = {}
        for _, child in player.PlayerGui:GetChildren() do
            before[child] = true
        end
        local state = Instance.new("Folder")
        local touch = false
        local owner = controllerModule.new(player, player.PlayerGui, state, function()
            return touch
        end)
        local started, reason = owner.start()
        assert(started, reason)
        local owned: ScreenGui? = nil
        for _, child in player.PlayerGui:GetChildren() do
            if not before[child] and child.Name == "GroundCombatHUD" and child:IsA("ScreenGui") then
                owned = child
            end
        end
        local ok, failure = pcall(function()
            assert(owned, "controller did not create HUD")
            local status = owned:FindFirstChild("RifleStatus")
            local fire = owned:FindFirstChild("Fire")
            local reload = owned:FindFirstChild("Reload")
            local launcherStatus = owned:FindFirstChild("LauncherStatus")
            assert(launcherStatus and launcherStatus:IsA("TextLabel"), "launcher team status missing")
            for _, name in { "M7", "Rocket", "Drop", "Pickup" } do
                local button = owned:FindFirstChild(name)
                assert(button and button:IsA("TextButton"), "launcher action missing: " .. name)
                assert(button.Size.Y.Offset == 32, "launcher action lost readable size")
            end
            assert(status and status:IsA("TextLabel"), "rifle status missing")
            assert(fire and fire:IsA("TextButton") and reload and reload:IsA("TextButton"), "buttons missing")
            for _, mode in { false, true, false } do
                touch = mode
                runService.RenderStepped:Wait()
                runService.RenderStepped:Wait()
                local position, size = controllerModule.statusLayout(mode)
                assert(
                    status.Position == position and status.Size == size,
                    "status failed to follow input mode"
                )
                assert(fire.Visible == mode and reload.Visible == mode, "buttons failed to follow input mode")
                assert(status.Parent == owned, "input mode rebuilt the status")
                assert(
                    launcherStatus.Size
                        == UDim2.fromOffset(if mode then 260 else 360, if mode then 24 else 28),
                    "launcher status failed to follow input mode"
                )
            end
        end)
        owner.stop()
        owner.stop()
        state:Destroy()
        assert(not owned or owned.Parent == nil, "controller stop retained HUD")
        assert(ok, tostring(failure))
    end)
    test("P08 actual desktop and phone launcher HUD rectangles never hide ammunition or actions", function()
        local player = game:GetService("Players").LocalPlayer
        local runService = game:GetService("RunService")
        local controllerModule = require(player.PlayerScripts.Client.GroundCombatController)
        local before: { [Instance]: boolean } = {}
        for _, child in player.PlayerGui:GetChildren() do
            before[child] = true
        end
        local state = Instance.new("Folder")
        local touch = false
        local owner = controllerModule.new(player, player.PlayerGui, state, function()
            return touch
        end)
        assert(owner.start(), "layout owner failed")
        local source: ScreenGui? = nil
        for _, child in player.PlayerGui:GetChildren() do
            if not before[child] and child.Name == "GroundCombatHUD" and child:IsA("ScreenGui") then
                source = child
            end
        end
        local gui = Instance.new("ScreenGui")
        gui.Name, gui.IgnoreGuiInset, gui.Parent = "P08LayoutProbe", true, player.PlayerGui
        local viewport = Instance.new("Frame")
        viewport.BackgroundTransparency, viewport.Parent = 1, gui
        local function overlaps(a: GuiObject, b: GuiObject): boolean
            local a0, b0 = a.AbsolutePosition, b.AbsolutePosition
            local a1, b1 = a0 + a.AbsoluteSize, b0 + b.AbsoluteSize
            return a0.X < b1.X and b0.X < a1.X and a0.Y < b1.Y and b0.Y < a1.Y
        end
        local function object(name: string): GuiObject
            local result = viewport:FindFirstChild(name)
            assert(result and result:IsA("GuiObject"), "production HUD object missing: " .. name)
            return result
        end
        local ok, failure = pcall(function()
            assert(source, "production HUD not created")
            for _, mode in { false, true } do
                touch = mode
                runService.RenderStepped:Wait()
                runService.RenderStepped:Wait()
                viewport:ClearAllChildren()
                for _, child in source:GetChildren() do
                    if child:IsA("GuiObject") then
                        child:Clone().Parent = viewport
                    end
                end
                -- Reserve the full bottom 96 pixels on both input modes for
                -- native Backpack inventory, including slot borders/padding.
                -- CoreGui is omitted by Studio screenshots; this semantic region
                -- catches HUD overlap without depending on private CoreGui names.
                local inventory = Instance.new("Frame")
                inventory.Name = "NativeInventoryReserve"
                inventory.AnchorPoint = Vector2.new(0.5, 1)
                inventory.Position = UDim2.fromScale(0.5, 1)
                inventory.Size = UDim2.new(1, 0, 0, 96)
                inventory.BackgroundTransparency = 1
                inventory.Parent = viewport
                local reserves: { GuiObject } = { inventory }
                local function reserve(name: string, position: UDim2, size: UDim2, anchor: Vector2?)
                    local item = Instance.new("Frame")
                    item.Name, item.Position, item.Size = name, position, size
                    item.AnchorPoint = anchor or Vector2.zero
                    item.BackgroundTransparency, item.Parent = 1, viewport
                    table.insert(reserves, item)
                end
                if mode then
                    -- Independent spatial requirements: the fixed touch reticle
                    -- and active RoundHUD regions keep aim, health and surrender
                    -- readable. These reservations are not the new status offsets.
                    reserve(
                        "TouchReticleReserve",
                        UDim2.fromScale(0.5, 0.5),
                        UDim2.fromOffset(24, 24),
                        Vector2.new(0.5, 0.5)
                    )
                    reserve("RoundSummaryReserve", UDim2.fromOffset(12, 8), UDim2.fromOffset(300, 38))
                    reserve("AircraftHealthReserve", UDim2.fromOffset(12, 55), UDim2.fromOffset(250, 34))
                    reserve(
                        "SurrenderReserve",
                        UDim2.new(1, -12, 0, 8),
                        UDim2.fromOffset(150, 36),
                        Vector2.new(1, 0)
                    )
                end
                local layouts: { Vector2 } = if mode
                    then { Vector2.new(568, 320), Vector2.new(750, 381), Vector2.new(852, 393) }
                    else { Vector2.new(1280, 720), Vector2.new(1920, 1080) }
                for _, size in layouts do
                    viewport.Size = UDim2.fromOffset(size.X, size.Y)
                    for _, scenario in { "Available", "Held" } do
                        local names = { "RifleStatus", "LauncherStatus" }
                        if scenario == "Available" then
                            table.insert(names, "Pickup")
                        elseif mode then
                            for _, name in { "M7", "Rocket", "Drop" } do
                                table.insert(names, name)
                            end
                        end
                        if mode then
                            table.insert(names, "Fire")
                            table.insert(names, "Reload")
                        end
                        runService.RenderStepped:Wait()
                        runService.RenderStepped:Wait()
                        for index, name in names do
                            local item = object(name)
                            local relative = item.AbsolutePosition - viewport.AbsolutePosition
                            local detail = string.format(
                                "%s %s %dx%d: %s",
                                if mode then "touch" else "desktop",
                                scenario,
                                size.X,
                                size.Y,
                                name
                            )
                            assert(
                                relative.X >= 0
                                    and relative.Y >= 0
                                    and relative.X + item.AbsoluteSize.X <= size.X
                                    and relative.Y + item.AbsoluteSize.Y <= size.Y,
                                "HUD outside viewport: " .. detail
                            )
                            for _, reserved in reserves do
                                assert(
                                    not overlaps(item, reserved),
                                    "HUD overlaps reserved " .. reserved.Name .. ": " .. detail
                                )
                            end
                            for otherIndex = index + 1, #names do
                                assert(
                                    not overlaps(item, object(names[otherIndex])),
                                    "HUD rectangles overlap: " .. detail .. " / " .. names[otherIndex]
                                )
                            end
                        end
                    end
                end
            end
        end)
        owner.stop()
        state:Destroy()
        gui:Destroy()
        assert(ok, tostring(failure))
    end)
end
