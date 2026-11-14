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
    test("P08 phone readiness text fits beside health and clears centered aim", function()
        local player = game:GetService("Players").LocalPlayer
        local runService = game:GetService("RunService")
        local controller = require(player.PlayerScripts.Client.GroundCombatController)
        local gui = Instance.new("ScreenGui")
        gui.Name, gui.IgnoreGuiInset, gui.Parent = "GroundReadinessProbe", true, player.PlayerGui
        local viewport = Instance.new("Frame")
        viewport.BackgroundTransparency, viewport.Parent = 1, gui
        local status = Instance.new("TextLabel")
        status.AnchorPoint = Vector2.new(0.5, 1)
        status.Position, status.Size = controller.statusLayout(true)
        status.TextSize, status.Font = 14, Enum.Font.Gotham
        status.Text, status.Parent = "M-7 • 30 / 120 • R reload • HIT", viewport
        local health = Instance.new("Frame")
        health.Position, health.Size, health.Parent =
            UDim2.fromOffset(12, 44), UDim2.fromOffset(240, 22), viewport
        local cross = Instance.new("Frame")
        cross.AnchorPoint, cross.Position, cross.Size =
            Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(24, 24)
        cross.Parent = viewport
        local function overlaps(a: GuiObject, b: GuiObject): boolean
            local a0, b0 = a.AbsolutePosition, b.AbsolutePosition
            local a1, b1 = a0 + a.AbsoluteSize, b0 + b.AbsoluteSize
            return a0.X < b1.X and b0.X < a1.X and a0.Y < b1.Y and b0.Y < a1.Y
        end
        local ok, failure = pcall(function()
            for _, size in { Vector2.new(568, 320), Vector2.new(750, 381), Vector2.new(852, 393) } do
                viewport.Size = UDim2.fromOffset(size.X, size.Y)
                runService.RenderStepped:Wait()
                runService.RenderStepped:Wait()
                assert(
                    status.TextBounds.X <= status.AbsoluteSize.X
                        and status.TextBounds.Y <= status.AbsoluteSize.Y,
                    "readiness/confirmed-hit text clipped"
                )
                assert(
                    not overlaps(status, health) and not overlaps(status, cross),
                    "readiness obscures health or aim"
                )
                local offset = status.AbsolutePosition - viewport.AbsolutePosition
                assert(
                    offset.X >= 0
                        and offset.Y >= 0
                        and offset.X + status.AbsoluteSize.X <= size.X
                        and offset.Y + status.AbsoluteSize.Y <= size.Y,
                    "readiness outside viewport"
                )
            end
            local position, size = controller.statusLayout(false)
            assert(
                position == UDim2.new(0.5, 0, 1, -100) and size == UDim2.fromOffset(330, 36),
                "desktop readiness changed"
            )
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
                local projection = owned:FindFirstChild("ProjectionOrigin")
                assert(projection and projection:IsA("Frame"), "projection origin missing")
                local position, size = controllerModule.statusLayout(
                    mode,
                    projection.AbsolutePosition,
                    game:GetService("GuiService"):GetGuiInset()
                )
                assert(
                    status.Position == position and status.Size == size,
                    "status failed to follow input mode"
                )
                assert(fire.Visible == mode and reload.Visible == mode, "buttons failed to follow input mode")
                assert(status.Parent == owned, "input mode rebuilt the status")
                assert(
                    launcherStatus.Size
                        == UDim2.fromOffset(if mode then 240 else 360, if mode then 22 else 28),
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
    test(
        "P08 production cross-GUI layouts preserve native controls aim headers and confirmed hits",
        function()
            local players, runService = game:GetService("Players"), game:GetService("RunService")
            local replicated, guiService = game:GetService("ReplicatedStorage"), game:GetService("GuiService")
            local starterGui, http = game:GetService("StarterGui"), game:GetService("HttpService")
            local player = players.LocalPlayer
            local controller = require(player.PlayerScripts.Client.GroundCombatController)
            local roundModule = require(player.PlayerScripts.Client.RoundPanel)
            local oldRole, oldLife = player:GetAttribute("Role"), player:GetAttribute("Life")
            local backpackEnabled = starterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Backpack)
            local originalRound = player.PlayerGui:FindFirstChild("RoundHUD")
            local originalRoundName = if originalRound then originalRound.Name else nil
            local camera = workspace.CurrentCamera
            local oldCameraType = if camera then camera.CameraType else nil
            local oldSubject = if camera then camera.CameraSubject else nil
            local oldCFrame = if camera then camera.CFrame else nil
            local oldFov = if camera then camera.FieldOfView else nil
            local aircraft = replicated:FindFirstChild("AircraftState")
            local ownsAircraft = aircraft == nil
            if not aircraft then
                aircraft = Instance.new("Folder")
                aircraft.Name, aircraft.Parent = "AircraftState", replicated
                aircraft:SetAttribute("Health", 300)
                aircraft:SetAttribute("MaxHealth", 300)
            end
            local launcher = replicated:FindFirstChild("LauncherState")
            local ownsLauncher = launcher == nil
            if not launcher then
                launcher = Instance.new("Folder")
                launcher.Name, launcher.Parent = "LauncherState", replicated
            end
            local oldShot, oldImpact =
                aircraft:GetAttribute("GroundShot"), launcher:GetAttribute("LastImpact")
            local touch = false
            local state = Instance.new("Folder")
            state:SetAttribute("RoundId", 7001)
            state:SetAttribute("Phase", "Active")
            state:SetAttribute("DeadlineSeconds", workspace:GetServerTimeNow() + 600)
            state:SetAttribute("GroundAlive", 2)
            state:SetAttribute("MinimumPlayers", 2)
            local roundOwner: { start: () -> (boolean, string?), stop: () -> () }? = nil
            local groundOwner: { start: () -> (boolean, string?), stop: () -> () }? = nil
            local groundCopy: ScreenGui? = nil
            local roundCopy: ScreenGui? = nil
            local fixtureTool: Tool? = nil
            local renamedTool: Tool? = nil
            local oldToolName: string? = nil
            local observations: { unknown } = {}
            local function frames()
                runService.RenderStepped:Wait()
                runService.RenderStepped:Wait()
            end
            local function overlaps(a: GuiObject, b: GuiObject): boolean
                local a0, b0 = a.AbsolutePosition, b.AbsolutePosition
                local a1, b1 = a0 + a.AbsoluteSize, b0 + b.AbsoluteSize
                return a0.X < b1.X and b0.X < a1.X and a0.Y < b1.Y and b0.Y < a1.Y
            end
            local function child(parent: Instance, name: string): GuiObject
                local item = parent:FindFirstChild(name)
                assert(item and item:IsA("GuiObject"), "production GUI item missing: " .. name)
                return item
            end
            local function copyScreen(source: ScreenGui, name: string): (ScreenGui, Frame)
                local gui = Instance.new("ScreenGui")
                gui.Name, gui.IgnoreGuiInset, gui.ScreenInsets =
                    name, source.IgnoreGuiInset, source.ScreenInsets
                gui.ClipToDeviceSafeArea, gui.Parent = source.ClipToDeviceSafeArea, player.PlayerGui
                local viewport = Instance.new("Frame")
                viewport.BackgroundTransparency, viewport.Parent = 1, gui
                for _, item in source:GetChildren() do
                    if item:IsA("GuiObject") then
                        item:Clone().Parent = viewport
                    end
                end
                return gui, viewport
            end
            local ok, failure = pcall(function()
                if originalRound then
                    originalRound.Name = "P08PreservedRoundHUD"
                end
                player:SetAttribute("Role", "Ground")
                player:SetAttribute("Life", "Alive")
                local character = player.Character
                assert(character, "layout fixture requires a ready actual character")
                local existing = character:FindFirstChild("M-7 rifle")
                local tool: Tool
                if existing and existing:IsA("Tool") then
                    tool = existing
                else
                    tool = Instance.new("Tool")
                    tool.Name, tool.RequiresHandle, tool.Parent = "M-7 rifle", false, character
                    fixtureTool = tool
                end
                renamedTool, oldToolName = tool, tool.Name
                local before: { [Instance]: boolean } = {}
                for _, item in player.PlayerGui:GetChildren() do
                    before[item] = true
                end
                local round = roundModule.new(player, player.PlayerGui, state, nil, function()
                    return touch
                end)
                roundOwner = round
                assert(round.start(), "production RoundPanel fixture failed")
                local ground = controller.new(player, player.PlayerGui, state, function()
                    return touch
                end)
                groundOwner = ground
                assert(ground.start(), "production GroundCombatController fixture failed")
                local sourceGround: ScreenGui? = nil
                local sourceRound: ScreenGui? = nil
                for _, item in player.PlayerGui:GetChildren() do
                    if not before[item] and item:IsA("ScreenGui") then
                        if item.Name == "GroundCombatHUD" then
                            sourceGround = item
                        elseif item.Name == "RoundHUD" then
                            sourceRound = item
                        end
                    end
                end
                assert(sourceGround and sourceRound, "production HUD sources unavailable")
                local shotSequence = 0
                for _, mode in { false, true } do
                    touch = mode
                    local insetModes: { boolean } = if mode then { true, false } else { true }
                    for _, ignoreInset in insetModes do
                        sourceGround.IgnoreGuiInset = ignoreInset
                        for _, weapon in { "M7", "Rocket" } do
                            tool.Name = if weapon == "M7" then "M-7 rifle" else "Rocket launcher"
                            shotSequence += 1
                            if weapon == "M7" then
                                aircraft:SetAttribute(
                                    "GroundShot",
                                    http:JSONEncode({
                                        roundId = 7001,
                                        userId = player.UserId,
                                        sequence = shotSequence,
                                        aircraftHit = true,
                                    })
                                )
                            else
                                launcher:SetAttribute(
                                    "LastImpact",
                                    http:JSONEncode({
                                        roundId = 7001,
                                        userId = player.UserId,
                                        shotId = "P08layout" .. tostring(shotSequence),
                                        aircraftHit = true,
                                    })
                                )
                            end
                            frames()
                            local sourceStatus = child(sourceGround, "RifleStatus")
                            local sourceFeedback = child(sourceGround, "AircraftHit")
                            assert(sourceStatus:IsA("TextLabel"), "readiness label missing")
                            if mode then
                                assert(
                                    not sourceFeedback.Visible
                                        and string.find(sourceStatus.Text, "HIT", 1, true),
                                    "confirmed touch hit is not inline with named readiness"
                                )
                                assert(
                                    sourceStatus.TextBounds.X <= sourceStatus.AbsoluteSize.X,
                                    "confirmed-hit/readiness text clipped"
                                )
                            else
                                assert(sourceFeedback.Visible, "confirmed desktop feedback disappeared")
                            end
                            local groundGui, groundViewport =
                                copyScreen(sourceGround, "P08GroundCrossGuiProbe")
                            local roundGui, roundViewport = copyScreen(sourceRound, "P08RoundCrossGuiProbe")
                            groundCopy, roundCopy = groundGui, roundGui
                            local inset = guiService:GetGuiInset()
                            local layouts: { Vector2 } = if mode
                                then { Vector2.new(568, 320), Vector2.new(750, 381), Vector2.new(852, 393) }
                                else { Vector2.new(1280, 720), Vector2.new(1920, 1080) }
                            for _, size in layouts do
                                groundViewport.Size, roundViewport.Size =
                                    UDim2.fromOffset(size.X, size.Y), UDim2.fromOffset(size.X, size.Y)
                                frames()
                                local origin = child(groundViewport, "ProjectionOrigin")
                                local reticle = child(groundViewport, "Reticle")
                                local _, position = controller.projectAim(
                                    size,
                                    size * 0.5,
                                    mode,
                                    inset,
                                    origin.AbsolutePosition
                                )
                                reticle.Position = position
                                local feedback = child(groundViewport, "AircraftHit")
                                feedback.Position = position
                                    + (sourceFeedback.Position - child(sourceGround, "Reticle").Position)
                                local reserves: { GuiObject } = {}
                                local function reserve(
                                    name: string,
                                    width: UDim2,
                                    reservedPosition: UDim2,
                                    anchor: Vector2
                                )
                                    local item = Instance.new("Frame")
                                    item.Name, item.Size, item.Position, item.AnchorPoint =
                                        name, width, reservedPosition, anchor
                                    item.BackgroundTransparency, item.Parent = 1, roundViewport
                                    table.insert(reserves, item)
                                end
                                reserve(
                                    "NativeInventory",
                                    UDim2.new(1, 0, 0, 96),
                                    UDim2.new(0.5, 0, 1, -inset.Y),
                                    Vector2.new(0.5, 1)
                                )
                                if mode then
                                    table.insert(reserves, reticle)
                                    reserve(
                                        "NativeThumbstick",
                                        UDim2.fromOffset(170, 160),
                                        UDim2.new(0, 0, 1, -inset.Y),
                                        Vector2.new(0, 1)
                                    )
                                    reserve(
                                        "NativeJump",
                                        UDim2.fromOffset(120, 130),
                                        UDim2.new(1, -inset.X, 1, -inset.Y),
                                        Vector2.new(1, 1)
                                    )
                                end
                                frames()
                                for _, scenario in { "Available", "Held" } do
                                    local items = {
                                        child(groundViewport, "RifleStatus"),
                                        child(groundViewport, "LauncherStatus"),
                                        child(roundViewport, "Round"),
                                        child(roundViewport, "AircraftHealth"),
                                        child(roundViewport, "Surrender"),
                                    }
                                    if mode then
                                        table.insert(items, child(groundViewport, "Fire"))
                                        if weapon == "M7" then
                                            table.insert(items, child(groundViewport, "Reload"))
                                        end
                                    else
                                        table.insert(items, feedback)
                                    end
                                    if scenario == "Available" then
                                        table.insert(items, child(groundViewport, "Pickup"))
                                    elseif mode then
                                        for _, name in { "M7", "Rocket", "Drop" } do
                                            table.insert(items, child(groundViewport, name))
                                        end
                                    end
                                    for index, item in items do
                                        local detail = string.format(
                                            "%s %s %s %dx%d inset(%d,%d) origin(%d,%d): %s",
                                            if mode then "touch" else "desktop",
                                            weapon,
                                            scenario,
                                            size.X,
                                            size.Y,
                                            inset.X,
                                            inset.Y,
                                            origin.AbsolutePosition.X,
                                            origin.AbsolutePosition.Y,
                                            item.Name
                                        )
                                        local point = item.AbsolutePosition - roundViewport.AbsolutePosition
                                        assert(
                                            point.X >= -inset.X
                                                and point.Y >= -inset.Y
                                                and point.X + item.AbsoluteSize.X <= size.X
                                                and point.Y + item.AbsoluteSize.Y <= size.Y - inset.Y,
                                            "HUD outside usable viewport: " .. detail
                                        )
                                        for _, reserved in reserves do
                                            assert(
                                                not overlaps(item, reserved),
                                                "HUD intersects " .. reserved.Name .. ": " .. detail
                                            )
                                        end
                                        for other = index + 1, #items do
                                            assert(
                                                not overlaps(item, items[other]),
                                                "cross-GUI intersection "
                                                    .. detail
                                                    .. " / "
                                                    .. items[other].Name
                                            )
                                        end
                                        if item:IsA("TextButton") then
                                            assert(
                                                item.AbsoluteSize.Y >= 32,
                                                "touchable action became too short"
                                            )
                                        end
                                    end
                                end
                                table.insert(observations, {
                                    touch = mode,
                                    ignoreInset = ignoreInset,
                                    viewport = { size.X, size.Y },
                                    inset = { inset.X, inset.Y },
                                    groundOrigin = {
                                        origin.AbsolutePosition.X,
                                        origin.AbsolutePosition.Y,
                                    },
                                    roundOrigin = {
                                        roundViewport.AbsolutePosition.X,
                                        roundViewport.AbsolutePosition.Y,
                                    },
                                })
                                for _, reserved in reserves do
                                    if reserved ~= reticle then
                                        reserved:Destroy()
                                    end
                                end
                            end
                            groundGui:Destroy()
                            roundGui:Destroy()
                            groundCopy, roundCopy = nil, nil
                        end
                    end
                end
            end)
            if groundCopy then
                groundCopy:Destroy()
            end
            if roundCopy then
                roundCopy:Destroy()
            end
            if groundOwner then
                groundOwner.stop()
            end
            if roundOwner then
                roundOwner.stop()
            end
            if renamedTool and oldToolName then
                renamedTool.Name = oldToolName
            end
            if fixtureTool then
                fixtureTool:Destroy()
            end
            aircraft:SetAttribute("GroundShot", oldShot)
            launcher:SetAttribute("LastImpact", oldImpact)
            if ownsAircraft then
                aircraft:Destroy()
            end
            if ownsLauncher then
                launcher:Destroy()
            end
            player:SetAttribute("Role", oldRole)
            player:SetAttribute("Life", oldLife)
            if originalRound and originalRoundName then
                originalRound.Name = originalRoundName
            end
            if camera and oldCameraType and oldCFrame and oldFov then
                camera.CameraType, camera.CameraSubject, camera.CFrame, camera.FieldOfView =
                    oldCameraType, oldSubject, oldCFrame, oldFov
            end
            state:Destroy()
            local tests = player.PlayerScripts:FindFirstChild("ClientTests")
            if tests then
                tests:SetAttribute("P08LayoutInsets", http:JSONEncode(observations))
            end
            assert(
                starterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Backpack) == backpackEnabled,
                "layout fixture changed native inventory state"
            )
            assert(ok, tostring(failure))
        end
    )
end
