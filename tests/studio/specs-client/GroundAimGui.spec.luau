--!strict
-- R12/R26: actual Roblox GUI and camera projection for Ground aim, cleanup
-- and phone layout. Synthetic viewports and facts do not operate native input.
return function()
    local test = getfenv().it :: (string, () -> ()) -> ()
    test("P27 the centered Ground reticle and firing ray use the displayed camera", function()
        local player = game:GetService("Players").LocalPlayer
        local guiService = game:GetService("GuiService")
        local runService = game:GetService("RunService")
        local controller = require(player.PlayerScripts.Client.GroundCombatController)
        local gui = Instance.new("ScreenGui")
        gui.ResetOnSpawn = false
        gui.Name = "GroundAimProjectionProbe"
        local origin = Instance.new("Frame")
        origin.Size = UDim2.fromOffset(0, 0)
        origin.Parent = gui
        local reticle = Instance.new("TextLabel")
        reticle.Size = UDim2.fromOffset(24, 24)
        reticle.AnchorPoint = Vector2.new(0.5, 0.5)
        reticle.Parent = gui
        gui.Parent = player.PlayerGui
        local ok, failure = pcall(function()
            for _, insets in { Enum.ScreenInsets.DeviceSafeInsets, Enum.ScreenInsets.CoreUISafeInsets } do
                gui.ScreenInsets = insets
                local deadline = os.clock() + 10
                repeat
                    runService.RenderStepped:Wait()
                    local camera = workspace.CurrentCamera
                    if not camera or camera.ViewportSize.X < 200 or camera.ViewportSize.Y < 200 then
                        assert(os.clock() < deadline, "camera viewport was not ready")
                        continue
                    end
                    local viewport, inset, anchor =
                        camera.ViewportSize, guiService:GetGuiInset(), origin.AbsolutePosition
                    local pixels, position = controller.projectAim(viewport, inset, anchor)
                    reticle.Position = position
                    runService.RenderStepped:Wait()
                    if
                        workspace.CurrentCamera ~= camera
                        or camera.ViewportSize ~= viewport
                        or guiService:GetGuiInset() ~= inset
                        or origin.AbsolutePosition ~= anchor
                    then
                        assert(os.clock() < deadline, "viewport coordinates changed throughout test")
                        continue
                    end
                    local drawn = reticle.AbsolutePosition + reticle.AbsoluteSize * 0.5 + inset
                    assert((drawn - viewport * 0.5).Magnitude <= 1, "Ground reticle is off center")
                    assert((drawn - pixels).Magnitude <= 1, "Ground reticle and firing pixels differ")
                    local ray = camera:ViewportPointToRay(pixels.X, pixels.Y)
                    local reticleRay = camera:ViewportPointToRay(drawn.X, drawn.Y)
                    assert(
                        ray.Direction:Dot(reticleRay.Direction) > 0.99999,
                        "Ground reticle and firing rays differ"
                    )
                    assert(
                        ray.Direction:Dot(camera.CFrame.LookVector) > 0.99999,
                        "Ground ray missed the view direction"
                    )
                    break
                until false
            end
        end)
        gui:Destroy()
        assert(ok, tostring(failure))
    end)
    test("P27 facing rotates the root through yaw wrap while leaving the avatar upright", function()
        local player = game:GetService("Players").LocalPlayer
        local input = require(player.PlayerScripts.Client.GroundInput)
        local origin = Vector3.new(4, 9, -2)
        local tilted = CFrame.new(origin) * CFrame.Angles(0.4, -0.8, 0.3)
        local earlier: CFrame? = nil
        for _, yaw in { math.rad(179), math.rad(-179) } do
            local camera = CFrame.fromOrientation(math.rad(80), yaw, 0)
            local facing = input.facingFrame(tilted, camera.LookVector)
            assert(
                facing.Position == origin and facing.UpVector == Vector3.yAxis,
                "root position or up changed"
            )
            local horizontal = Vector3.new(camera.LookVector.X, 0, camera.LookVector.Z).Unit
            assert(facing.LookVector:Dot(horizontal) > 0.99999, "root did not follow horizontal aim")
            if earlier then
                assert(earlier.LookVector:Dot(facing.LookVector) > 0.999, "heading snapped at yaw wrap")
            end
            earlier = facing
        end
        assert(input.facingFrame(tilted, Vector3.yAxis) == tilted, "vertical aim changed yaw")
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
        local originalRole = player:GetAttribute("Role")
        local originalLife = player:GetAttribute("Life")
        local owned: ScreenGui? = nil
        local ok, failure = pcall(function()
            state:SetAttribute("Phase", "Active")
            player:SetAttribute("Role", "Ground")
            player:SetAttribute("Life", "Alive")
            local started, reason = owner.start()
            assert(started, reason)
            for _, child in player.PlayerGui:GetChildren() do
                if not before[child] and child.Name == "GroundCombatHUD" and child:IsA("ScreenGui") then
                    owned = child
                end
            end
            assert(owned, "controller did not create HUD")
            local status = owned:FindFirstChild("RifleStatus")
            local fire = owned:FindFirstChild("Fire")
            local reload = owned:FindFirstChild("Reload")
            local launcherStatus = owned:FindFirstChild("LauncherStatus")
            assert(launcherStatus and launcherStatus:IsA("TextLabel"), "launcher team status missing")
            for _, name in { "M7", "Rocket", "Drop", "Pickup" } do
                local button = owned:FindFirstChild(name)
                assert(button and button:IsA("TextButton"), "launcher action missing: " .. name)
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
                    "readiness did not follow input mode"
                )
                assert(status.Parent == owned, "input mode rebuilt the status")
                assert(launcherStatus.Visible == not mode, "touch retained duplicate launcher text")
                if not mode then
                    assert(not fire.Visible and not reload.Visible, "desktop exposed touch buttons")
                end
            end
            touch = true
            state:SetAttribute("Phase", "Scatter")
            runService.RenderStepped:Wait()
            runService.RenderStepped:Wait()
            assert(owned.Enabled and not launcherStatus.Visible, "Scatter did not keep the compact HUD")
            assert(not fire.Visible and not reload.Visible, "Scatter exposed weapon controls")
            assert(
                not status.Visible and status.Text == "",
                "touch Scatter retained the duplicate unlock notice"
            )
            player:SetAttribute("Life", "Eliminated")
            runService.RenderStepped:Wait()
            runService.RenderStepped:Wait()
            assert(not owned.Enabled, "Ground HUD outlived the body")
        end)
        owner.stop()
        owner.stop()
        player:SetAttribute("Role", originalRole)
        player:SetAttribute("Life", originalLife)
        state:Destroy()
        assert(not owned or owned.Parent == nil, "controller stop retained HUD")
        assert(ok, tostring(failure))
    end)
    test("P24 stopping a temporary arrival owner leaves the existing countdown rendering", function()
        local player = game:GetService("Players").LocalPlayer
        local runService = game:GetService("RunService")
        local arrival = require(player.PlayerScripts.Client.AircraftArrival)
        local oldMarker = player:GetAttribute("OperatorArrivalRoundId")
        local state = Instance.new("Folder")
        local first: arrival.Controller? = nil
        local temporary: arrival.Controller? = nil
        local ok, failure = pcall(function()
            local previous: { [Instance]: boolean } = {}
            for _, child in player.PlayerGui:GetChildren() do
                previous[child] = true
            end
            local roundId = 7924
            state:SetAttribute("RoundId", roundId)
            state:SetAttribute("Phase", "Deploying")
            player:SetAttribute("OperatorArrivalRoundId", roundId)
            local function pending(): boolean
                return false
            end
            first = arrival.start(player, player.PlayerGui, state, pending, function()
                return false
            end)
            local source: ScreenGui? = nil
            for _, child in player.PlayerGui:GetChildren() do
                if not previous[child] and child.Name == "AircraftArrival" and child:IsA("ScreenGui") then
                    source = child
                end
            end
            assert(source and source.Enabled, "original arrival screen did not arm")
            local cover = assert(source:FindFirstChild("Blackout"), "original blackout missing")
            local label = cover:FindFirstChild("Countdown")
            assert(label and label:IsA("TextLabel"), "original countdown missing")
            assert(label.Text == "Preparing deployment", "assignment cover did not paint immediately")
            local overlapping = arrival.start(player, player.PlayerGui, state, pending, function()
                return false
            end)
            temporary = overlapping
            overlapping.stop()
            state:SetAttribute("DeadlineSeconds", workspace:GetServerTimeNow() + 8)
            state:SetAttribute("Phase", "Scatter")
            runService.RenderStepped:Wait()
            runService.RenderStepped:Wait()
            local rendered = tonumber(label.Text:match("^C%-130 arrives in (%d+)$"))
            assert(
                rendered and rendered >= 7 and rendered <= 8,
                "stopping a temporary HUD stopped the first countdown"
            )
        end)
        if temporary then
            temporary.stop()
        end
        if first then
            first.stop()
        end
        player:SetAttribute("OperatorArrivalRoundId", oldMarker)
        state:Destroy()
        assert(ok, tostring(failure))
    end)
    test("P27 production Ground HUD clears safe areas through Scatter, combat and lobby", function()
        local players, runService = game:GetService("Players"), game:GetService("RunService")
        local replicated = game:GetService("ReplicatedStorage")
        local starterGui, http = game:GetService("StarterGui"), game:GetService("HttpService")
        local player = players.LocalPlayer
        local controller = require(player.PlayerScripts.Client.GroundCombatController)
        local roundModule = require(player.PlayerScripts.Client.RoundPanel)
        local presentation = require(replicated.Shared.PlayerPresentation)
        local oldRole, oldLife = player:GetAttribute("Role"), player:GetAttribute("Life")
        local backpackEnabled = starterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Backpack)
        local originalRound = player.PlayerGui:FindFirstChild("RoundHUD")
        local originalRoundName = if originalRound then originalRound.Name else nil
        local camera = workspace.CurrentCamera
        local oldCameraType = if camera then camera.CameraType else nil
        local oldSubject = if camera then camera.CameraSubject else nil
        local oldCFrame = if camera then camera.CFrame else nil
        local oldFocus = if camera then camera.Focus else nil
        local oldFov = if camera then camera.FieldOfView else nil
        local aircraft = replicated:FindFirstChild("AircraftState")
        local ownsAircraft = aircraft == nil
        if not aircraft then
            aircraft = Instance.new("Folder")
            aircraft.Name, aircraft.Parent = "AircraftState", replicated
            aircraft:SetAttribute("Health", 300)
            aircraft:SetAttribute("MaxHealth", 300)
        end
        local oldHealth = aircraft:GetAttribute("Health")
        local oldMaximum = aircraft:GetAttribute("MaxHealth")
        local oldDestroyed = aircraft:GetAttribute("Destroyed")
        local launcherState = replicated:FindFirstChild("LauncherState")
        local ownsLauncherState = launcherState == nil
        if not launcherState then
            launcherState = Instance.new("Folder")
            launcherState.Name, launcherState.Parent = "LauncherState", replicated
        end
        local launcher = launcherState
        local oldLauncher = launcher:GetAttribute("Snapshot")
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
        local alternateTool: Tool? = nil
        local fixtureBody: Model? = nil
        local renamedTool: Tool? = nil
        local oldToolName: string? = nil
        local restoreReadiness: (() -> ())? = nil
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
            assert(
                item and item:IsA("GuiObject"),
                "production GUI item missing: " .. name .. " under " .. parent:GetFullName()
            )
            return item
        end
        local function copyScreen(source: ScreenGui, name: string): (ScreenGui, Frame)
            local gui = Instance.new("ScreenGui")
            -- These copies model the production HUD across real avatar
            -- loads, including while P03 deploys before smoke ends.
            gui.ResetOnSpawn = false
            gui.Name, gui.ScreenInsets = name, Enum.ScreenInsets.None
            gui.ClipToDeviceSafeArea, gui.Parent = false, player.PlayerGui
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
            if not character then
                -- During asynchronous avatar startup, use an
                -- inert local body inside PlayerScripts for the HUD only.
                -- No spawn call or fixture geometry enters Workspace.
                local body = Instance.new("Model")
                fixtureBody = body
                body.Name = "P10GroundLayoutBody"
                for _, name in { "HumanoidRootPart", "Head" } do
                    local part = Instance.new("Part")
                    part.Name = name
                    part.Anchored = true
                    part.Transparency = 1
                    part.CanCollide, part.CanQuery, part.CanTouch = false, false, false
                    part.Parent = body
                end
                local humanoid = Instance.new("Humanoid")
                humanoid.RequiresNeck = false
                humanoid.Parent = body
                body.Parent = player.PlayerScripts
                player.Character = body
                assert(
                    player.Character == body and body.Parent == player.PlayerScripts,
                    "private layout body unavailable"
                )
                character = body
            end
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
            local backpack = player:FindFirstChildOfClass("Backpack")
            assert(backpack, "missing Backpack in HUD fixture")
            local alternate = Instance.new("Tool")
            alternate.RequiresHandle = false
            alternateTool = alternate
            alternate.Parent = backpack
            local bodyRoot = character:FindFirstChild("HumanoidRootPart")
            assert(bodyRoot and bodyRoot:IsA("BasePart"), "layout body missing root")
            local function setLauncher(held: boolean)
                local position = bodyRoot.Position
                launcher:SetAttribute(
                    "Snapshot",
                    http:JSONEncode({
                        roundId = 7001,
                        launcherId = "layout-launcher",
                        state = if held then "Held" else "Available",
                        ownerId = if held then player.UserId else nil,
                        readyAt = 0,
                        ammo = 1,
                        position = { x = position.X, y = position.Y, z = position.Z },
                    })
                )
            end
            local readinessAttributes = { "Ammo", "NextFire", "MaxAmmo", "ReloadUntil", "UnlimitedReserve" }
            local oldReadiness = tool:GetAttributes()
            restoreReadiness = function()
                for _, attribute in readinessAttributes do
                    tool:SetAttribute(attribute, oldReadiness[attribute])
                end
            end
            tool:SetAttribute("Ammo", 29)
            tool:SetAttribute("NextFire", 0)
            tool:SetAttribute("MaxAmmo", 30)
            tool:SetAttribute("UnlimitedReserve", true)
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
            aircraft:SetAttribute("MaxHealth", 300)
            aircraft:SetAttribute("Destroyed", false)
            local healthLabel = child(sourceRound, "AircraftHealth")
            local meter = child(healthLabel, "Meter")
            local fill = child(meter, "Fill")
            for _, sample in { { 300, 1 }, { 150, 0.5 }, { 3, 0.01 }, { 0, 0 } } do
                aircraft:SetAttribute("Health", sample[1])
                local deadline = os.clock() + 2
                repeat
                    frames()
                until math.abs(fill.Size.X.Scale - sample[2]) <= 0.002 or os.clock() >= deadline
                assert(
                    healthLabel.Visible and healthLabel:GetAttribute("Fraction") == sample[2],
                    "live health label ratio"
                )
                assert(math.abs(fill.Size.X.Scale - sample[2]) <= 0.002, "health bar width did not settle")
                if sample[1] == 300 then
                    assert(fill.BackgroundColor3.G > fill.BackgroundColor3.R, "full bar is not green")
                elseif sample[1] < 10 then
                    assert(fill.BackgroundColor3.R > fill.BackgroundColor3.G, "depleted bar is not red")
                end
            end
            aircraft:SetAttribute("Health", 150)
            assert(
                sourceRound:FindFirstChild("Help") == nil and sourceRound:FindFirstChild("Guide") == nil,
                "in-round guidance remains"
            )
            type Layout = { viewport: Vector2, min: Vector2, insetBottomRight: Vector2 }
            local phone: { Layout } = {
                {
                    viewport = Vector2.new(568, 320),
                    min = Vector2.new(0, 58),
                    insetBottomRight = Vector2.zero,
                },
                {
                    viewport = Vector2.new(852, 393),
                    min = Vector2.new(48, 58),
                    insetBottomRight = Vector2.new(16, 12),
                },
            }
            local desktop: { Layout } = {
                {
                    viewport = Vector2.new(1280, 720),
                    min = Vector2.new(0, 58),
                    insetBottomRight = Vector2.zero,
                },
            }

            local function checkLayout(variant: string, layouts: { Layout })
                local groundGui, groundViewport = copyScreen(sourceGround, "GroundSafeAreaProbe")
                local roundGui, roundViewport = copyScreen(sourceRound, "RoundSafeAreaProbe")
                groundCopy, roundCopy = groundGui, roundGui
                local reticle = child(groundViewport, "Reticle")
                local timer = child(roundViewport, "Round")
                assert(timer:IsA("TextLabel"), "round label missing")
                for _, layout in layouts do
                    local size, safeMin = layout.viewport, layout.min
                    local safeMax = size - layout.insetBottomRight
                    local safeSize = safeMax - safeMin
                    local groundMin = if touch then safeMin else Vector2.zero
                    local groundSize = if touch then safeSize else size
                    groundViewport.Position, groundViewport.Size =
                        UDim2.fromOffset(groundMin.X, groundMin.Y),
                        UDim2.fromOffset(groundSize.X, groundSize.Y)
                    roundViewport.Position, roundViewport.Size =
                        UDim2.fromOffset(safeMin.X, safeMin.Y), UDim2.fromOffset(safeSize.X, safeSize.Y)
                    local _, position = controller.projectAim(size, Vector2.zero, groundMin)
                    reticle.Position = position
                    local reserves: { GuiObject } = {}
                    local function reserve(name: string, minimum: Vector2, boxSize: Vector2)
                        local rect = Instance.new("Frame")
                        rect.Name = name
                        rect.Position = UDim2.fromOffset(minimum.X, minimum.Y)
                        rect.Size = UDim2.fromOffset(boxSize.X, boxSize.Y)
                        rect.BackgroundTransparency = 1
                        rect.Parent = roundGui
                        table.insert(reserves, rect)
                    end
                    if sourceGround.Enabled then
                        reserve(
                            "NativeInventory",
                            Vector2.new(safeMin.X, safeMax.Y - 96),
                            Vector2.new(safeSize.X, 96)
                        )
                        if touch then
                            reserve(
                                "NativeThumbstick",
                                Vector2.new(safeMin.X, safeMax.Y - 160),
                                Vector2.new(170, 160)
                            )
                            reserve(
                                "NativeJump",
                                Vector2.new(safeMax.X - 120, safeMax.Y - 130),
                                Vector2.new(120, 130)
                            )
                            table.insert(reserves, reticle)
                        end
                    end
                    local items: { GuiObject } = {}
                    for _, canvas in { roundViewport, groundViewport } do
                        if canvas == groundViewport and not sourceGround.Enabled then
                            continue
                        end
                        for _, item in canvas:GetChildren() do
                            if
                                item:IsA("GuiObject")
                                and item.Visible
                                and item ~= reticle
                                and item.Name ~= "ProjectionOrigin"
                            then
                                table.insert(items, item)
                            end
                        end
                    end
                    frames()
                    local base = roundViewport.AbsolutePosition - safeMin
                    for index, item in items do
                        local detail = string.format("%s · %s · %s", variant, tostring(size), item.Name)
                        local point = item.AbsolutePosition - base
                        local edge = point + item.AbsoluteSize
                        assert(
                            point.X >= safeMin.X
                                and point.Y >= safeMin.Y
                                and edge.X <= safeMax.X
                                and edge.Y <= safeMax.Y,
                            "outside safe viewport: " .. detail
                        )
                        for _, reserved in reserves do
                            assert(
                                not overlaps(item, reserved),
                                "intersects " .. reserved.Name .. ": " .. detail
                            )
                        end
                        for other = index + 1, #items do
                            local neighbor = items[other]
                            assert(
                                not overlaps(item, neighbor),
                                "intersects " .. neighbor.Name .. ": " .. detail
                            )
                        end
                        if item:IsA("TextButton") and touch then
                            assert(
                                item.AbsoluteSize.X >= 44 and item.AbsoluteSize.Y >= 44,
                                "small touch target: " .. detail
                            )
                        end
                        if (item:IsA("TextButton") or item:IsA("TextLabel")) and item.Text ~= "" then
                            assert(
                                item.TextFits and item.TextBounds.X > 0 and item.TextBounds.Y > 0,
                                "text clipped: " .. detail .. " " .. item.Text
                            )
                            if item.Name == "Reload" then
                                assert(
                                    item.TextBounds.X + 8 <= item.AbsoluteSize.X,
                                    string.format(
                                        "reload text lost padding at %s: %s in %s",
                                        detail,
                                        tostring(item.TextBounds),
                                        tostring(item.AbsoluteSize)
                                    )
                                )
                            end
                        end
                    end
                    if variant == "Scatter" then
                        assert(
                            timer.AbsoluteSize.X <= safeSize.X / 4 and timer.AbsoluteSize.Y <= 24,
                            "Scatter timer exceeds its screen budget"
                        )
                        assert(not timer.TextWrapped, "Scatter timer permits a second line")
                        for seconds = 20, 0, -1 do
                            timer.Text = presentation.arrivalText(120, 120 - seconds, true)
                            runService.RenderStepped:Wait()
                            assert(
                                timer.TextFits and timer.TextBounds.X > 0 and timer.TextBounds.Y <= 24,
                                "Scatter seconds clipped: " .. tostring(seconds)
                            )
                        end
                    end
                    table.insert(observations, {
                        phase = variant,
                        viewport = { size.X, size.Y },
                        safeMin = { safeMin.X, safeMin.Y },
                        safeMax = { safeMax.X, safeMax.Y },
                        roundLabel = { timer.AbsoluteSize.X, timer.AbsoluteSize.Y },
                        visible = #items,
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

            local status = child(sourceGround, "RifleStatus")
            assert(status:IsA("TextLabel"), "readiness label missing")
            for _, mode in { false, true } do
                touch = mode
                for _, weapon in { "M7", "Rocket" } do
                    local rocket = weapon == "Rocket"
                    tool.Name = if rocket then "Rocket launcher" else "M-7 rifle"
                    alternate.Name = if rocket then "M-7 rifle" else "Rocket launcher"
                    local remaining = if rocket then 120 else 10
                    tool:SetAttribute("ReloadUntil", workspace:GetServerTimeNow() + remaining)
                    setLauncher(rocket)
                    frames()
                    local prefix = if rocket then "ROCKET • Reload " else "M-7 • 29 / ∞ • Reload "
                    assert(string.find(status.Text, prefix, 1, true) == 1, "equipped readiness text missing")
                    assert(sourceGround:FindFirstChild("AircraftHit") == nil, "aircraft hit overlay remains")
                    assert(not string.find(status.Text, "HIT", 1, true), "old hit text remains")
                    assert(child(sourceGround, "Pickup").Visible ~= rocket, "pickup prompt ignores ownership")
                    if mode then
                        assert(child(sourceGround, "Fire").Visible, "equipped weapon lacks Fire")
                        assert(
                            child(sourceGround, "Reload").Visible ~= rocket,
                            "reload availability ignores weapon"
                        )
                        assert(
                            child(sourceGround, "Drop").Visible == rocket,
                            "drop availability ignores ownership"
                        )
                    end
                    checkLayout(weapon, if mode then phone else desktop)
                end
            end

            state:SetAttribute("Phase", "Scatter")
            state:SetAttribute("DeadlineSeconds", workspace:GetServerTimeNow() + 20)
            tool.Name, alternate.Name = "M-7 rifle", "Rocket launcher"
            setLauncher(false)
            frames()
            assert(child(sourceGround, "Pickup").Visible, "closed combat hid the actionable launcher pickup")
            for _, hidden in { "Reload", "Fire", "RifleStatus", "LauncherStatus", "Reticle" } do
                assert(not child(sourceGround, hidden).Visible, "Scatter exposed " .. hidden)
            end
            checkLayout("Scatter", phone)

            player:SetAttribute("Role", "Waiting")
            player:SetAttribute("Life", "Waiting")
            for _, phase in { "Results", "Lobby" } do
                state:SetAttribute("Phase", phase)
                state:SetAttribute(
                    "IntermissionUntil",
                    if phase == "Results" then workspace:GetServerTimeNow() + 120 else nil
                )
                frames()
                local timer = child(sourceRound, "Round")
                assert(
                    timer:IsA("TextLabel") and not timer.Text:find("C%-130 in"),
                    "arrival timer survived " .. phase
                )
                assert(
                    not sourceGround.Enabled and not child(sourceRound, "AircraftHealth").Visible,
                    "stale HUD in " .. phase
                )
                checkLayout(phase, phone)
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
        if restoreReadiness then
            restoreReadiness()
        end
        if renamedTool and oldToolName then
            renamedTool.Name = oldToolName
        end
        if alternateTool then
            alternateTool:Destroy()
        end
        if fixtureTool then
            fixtureTool:Destroy()
        end
        if fixtureBody then
            -- A real replication update can replace the local pointer.
            -- Clear it only while it still identifies our fixture.
            if player.Character == fixtureBody then
                player.Character = nil
            end
            fixtureBody:Destroy()
        end
        launcher:SetAttribute("Snapshot", oldLauncher)
        if ownsLauncherState then
            launcher:Destroy()
        end
        aircraft:SetAttribute("Health", oldHealth)
        aircraft:SetAttribute("MaxHealth", oldMaximum)
        aircraft:SetAttribute("Destroyed", oldDestroyed)
        if ownsAircraft then
            aircraft:Destroy()
        end
        player:SetAttribute("Role", oldRole)
        player:SetAttribute("Life", oldLife)
        if originalRound and originalRoundName then
            originalRound.Name = originalRoundName
        end
        if camera and oldCameraType and oldCFrame and oldFocus and oldFov then
            camera.CameraType, camera.CameraSubject, camera.CFrame, camera.Focus, camera.FieldOfView =
                oldCameraType, oldSubject, oldCFrame, oldFocus, oldFov
        end
        state:Destroy()
        local tests = player.PlayerScripts:FindFirstChild("ClientTests")
        if tests then
            tests:SetAttribute("P27GroundLayout", http:JSONEncode(observations))
        end
        assert(
            starterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Backpack) == backpackEnabled,
            "layout fixture changed native inventory state"
        )
        assert(
            not fixtureBody or (player.Character ~= fixtureBody and fixtureBody.Parent == nil),
            "private layout body survived cleanup"
        )
        assert(ok, tostring(failure))
    end)
end
