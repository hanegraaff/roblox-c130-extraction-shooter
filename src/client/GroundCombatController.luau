--!strict
--[=[
    GroundCombatController: local M-7/launcher aim, fire and equipment intent, plus
    team launcher ownership/readiness and pickup/drop presentation. The equipped
    server-owned Tool selects firing; native slots/touch buttons select equipment.
    Depends on PlayerGui, UserInputService, current camera and server-owned remotes.
    The server validates ownership, target, timing, cover and damage. start/stop are
    idempotent and disconnect all listeners, release held fire and destroy the HUD.
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local Lifecycle = require(ReplicatedStorage.Shared.Lifecycle)
local PlayerPresentation = require(ReplicatedStorage.Shared.PlayerPresentation)
local Validation = require(ReplicatedStorage.Shared.Validation)
local GroundInput = require(script.Parent.GroundInput)
local GroundCombatController = {}
local renderOwnerCount = 0
type LauncherView = {
    roundId: number,
    launcherId: string,
    state: string,
    ownerId: number?,
    readyAt: number,
    ammo: number,
    position: { x: number, y: number, z: number },
}

-- One rounded center pixel drives both the reticle and the ray on desktop
-- and touch. The measured GUI origin plus inset converts into local pixels.
function GroundCombatController.projectAim(
    viewport: Vector2,
    inset: Vector2,
    origin: Vector2
): (Vector2, UDim2)
    local pixels = Vector2.new(math.floor(viewport.X * 0.5 + 0.5), math.floor(viewport.Y * 0.5 + 0.5))
    local guiOrigin = origin + inset
    return pixels,
        UDim2.fromOffset(math.floor(pixels.X - guiOrigin.X + 0.5), math.floor(pixels.Y - guiOrigin.Y + 0.5))
end

-- Returns position/size in the owning ScreenGui's content coordinates.
-- On a phone readiness sits below the right-aligned surrender control.
function GroundCombatController.statusLayout(touch: boolean): (UDim2, UDim2)
    if touch then
        return UDim2.new(1, -8, 0, 52), UDim2.fromOffset(178, 20)
    end
    return UDim2.new(0.5, 0, 1, -100), UDim2.fromOffset(330, 36)
end

-- Copies the bounded presentation fields before using positions or ownership.
local function readLauncher(encoded: string): LauncherView?
    local ok, value = pcall(function()
        return HttpService:JSONDecode(encoded)
    end)
    if
        not ok
        or type(value) ~= "table"
        or not Validation.isFinite(value.roundId)
        or type(value.launcherId) ~= "string"
        or type(value.state) ~= "string"
        or not Validation.isFinite(value.readyAt)
        or not Validation.isFinite(value.ammo)
        or (value.ownerId ~= nil and not Validation.isFinite(value.ownerId))
    then
        return nil
    end
    local position = value.position
    if
        type(position) ~= "table"
        or not Validation.isFinite(position.x)
        or not Validation.isFinite(position.y)
        or not Validation.isFinite(position.z)
    then
        return nil
    end
    return (value :: unknown) :: LauncherView
end

-- Owns UI/input for one round-state lifetime. No yielding or combat authority.
-- Optional nonyielding touch provider supports alternate input environments and
-- tests; absent it, input capability is sampled from UserInputService per frame.
function GroundCombatController.new(
    player: Player,
    playerGui: PlayerGui,
    roundState: Instance,
    touchProvider: (() -> boolean)?
): Lifecycle.Controller
    return Lifecycle.new({
        function()
            local gui = Instance.new("ScreenGui")
            renderOwnerCount += 1
            local renderBinding = "GroundCombatAim:" .. tostring(renderOwnerCount)
            gui.Name = "GroundCombatHUD"
            gui.ResetOnSpawn = false
            gui.IgnoreGuiInset = true
            local projectionOrigin = Instance.new("Frame")
            projectionOrigin.Name = "ProjectionOrigin"
            projectionOrigin.BackgroundTransparency = 1
            projectionOrigin.Size = UDim2.fromOffset(0, 0)
            projectionOrigin.Parent = gui
            local label = Instance.new("TextLabel")
            label.Name = "RifleStatus"
            label.AnchorPoint = Vector2.new(0.5, 1)
            local function touchEnabled(): boolean
                return if touchProvider then touchProvider() else UserInputService.TouchEnabled
            end
            label.Position, label.Size = GroundCombatController.statusLayout(touchEnabled())
            label.BackgroundColor3 = Color3.fromRGB(16, 23, 31)
            label.BackgroundTransparency = 0.2
            label.TextColor3 = Color3.new(1, 1, 1)
            label.Font = Enum.Font.Gotham
            label.TextSize = 16
            label.Parent = gui
            local reticle = Instance.new("TextLabel")
            reticle.Name = "Reticle"
            reticle.AnchorPoint = Vector2.new(0.5, 0.5)
            reticle.Size = UDim2.fromOffset(24, 24)
            reticle.BackgroundTransparency = 1
            reticle.Text = "+"
            reticle.TextSize = 26
            reticle.TextColor3 = Color3.new(1, 1, 1)
            reticle.TextStrokeTransparency = 0
            reticle.Parent = gui
            local fireButton = Instance.new("TextButton")
            fireButton.Name = "Fire"
            fireButton.AnchorPoint = Vector2.new(1, 1)
            fireButton.Position = UDim2.new(1, -24, 1, -130)
            fireButton.Size = UDim2.fromOffset(90, 70)
            fireButton.Text = "FIRE"
            fireButton.TextSize = 18
            fireButton.BackgroundColor3 = Color3.fromRGB(115, 45, 35)
            fireButton.TextColor3 = Color3.new(1, 1, 1)
            fireButton.Parent = gui
            local reloadButton = Instance.new("TextButton")
            reloadButton.Name = "Reload"
            reloadButton.AnchorPoint = Vector2.new(1, 1)
            reloadButton.Position = UDim2.new(1, -24, 1, -210)
            reloadButton.Size = UDim2.fromOffset(90, 54)
            reloadButton.Text = "RELOAD"
            reloadButton.TextSize = 16
            reloadButton.BackgroundColor3 = Color3.fromRGB(35, 44, 55)
            reloadButton.TextColor3 = Color3.new(1, 1, 1)
            reloadButton.Parent = gui
            local launcherLabel = label:Clone()
            launcherLabel.Name = "LauncherStatus"
            launcherLabel.Position = UDim2.new(0.5, 0, 1, -204)
            launcherLabel.Size = UDim2.fromOffset(360, 28)
            launcherLabel.TextSize = 14
            launcherLabel.Parent = gui
            local healthLabel = label:Clone()
            healthLabel.Name = "GroundHealth"
            healthLabel.AnchorPoint = Vector2.zero
            healthLabel.Size = UDim2.fromOffset(188, 28)
            healthLabel.TextSize = 14
            healthLabel.Parent = gui
            local feedback = label:Clone()
            feedback.Name = "ActionFeedback"
            feedback.AnchorPoint = Vector2.new(1, 0)
            feedback.Size = UDim2.fromOffset(320, 34)
            feedback.TextSize = 14
            feedback.TextColor3 = Color3.fromRGB(255, 218, 155)
            feedback.TextWrapped = true
            feedback.Visible = false
            feedback.Parent = gui
            local launcherButtons: { [string]: TextButton } = {}
            for index, name in { "M7", "Rocket", "Drop", "Pickup" } do
                local button = Instance.new("TextButton")
                button.Name = name
                button.AnchorPoint = Vector2.new(0.5, 1)
                button.Position = UDim2.new(0.5, if name == "Pickup" then 0 else (index - 2) * 90, 1, -104)
                button.Size = UDim2.fromOffset(if name == "Pickup" then 130 else 84, 32)
                button.Text = if name == "M7"
                    then "M-7"
                    elseif name == "Rocket" then "ROCKET"
                    elseif name == "Drop" then "DROP"
                    else "PICK UP"
                button.TextSize = 14
                button.BackgroundColor3 = Color3.fromRGB(61, 65, 38)
                button.TextColor3 = Color3.new(1, 1, 1)
                button.Parent = gui
                launcherButtons[name] = button
            end
            gui.Parent = playerGui
            local selected: Tool? = nil
            local connections: { RBXScriptConnection } = {}
            local held = false
            local windowFocused = true
            local fireTouch: InputObject? = nil
            local sequence = 0
            local launcherSequence = 0
            local launcher: LauncherView? = nil
            local launcherEncoded: { [string]: string? } = {}
            local launcherViews: { [string]: LauncherView? } = {}
            local round = -1
            local nextAttempt = 0
            local lastShot: string? = nil
            local feedbackUntil = 0
            local shotUntil = 0
            local function clearTool()
                held = false
                fireTouch = nil
                selected = nil
            end
            local function remote(name: string): RemoteEvent?
                local aircraftState = ReplicatedStorage:FindFirstChild("AircraftState")
                local item = if aircraftState then aircraftState:FindFirstChild(name) else nil
                return if item and item:IsA("RemoteEvent") then item else nil
            end
            local function eligibleGround(allowScatter: boolean): boolean
                local phase = roundState:GetAttribute("Phase")
                return player:GetAttribute("Role") == "Ground"
                    and player:GetAttribute("Life") == "Alive"
                    and (phase == "Active" or (allowScatter and phase == "Scatter"))
            end
            local function overlayOpen(): boolean
                return not windowFocused or GroundInput.menuOpen(playerGui) or GroundInput.pointerRequested()
            end
            local function launcherFacts(): (string?, boolean, boolean)
                local current = launcher
                if not current or current.roundId ~= round then
                    return nil, false, false
                end
                local character = player.Character
                local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
                local near = false
                if current.state == "Available" and root and root:IsA("BasePart") then
                    local spot = current.position
                    near = (root.Position - Vector3.new(spot.x, spot.y, spot.z)).Magnitude <= 8
                end
                return current.state, current.ownerId == player.UserId, near
            end
            local function reject(message: string?)
                if message then
                    feedback.Text = message
                    feedbackUntil = os.clock() + 2.2
                end
            end
            local function sendLauncher(action: "Pickup" | "Drop", fromButton: boolean?)
                if
                    GroundInput.menuOpen(playerGui)
                    or (not fromButton and overlayOpen())
                    or not eligibleGround(true)
                then
                    return
                end
                local phase, owns, near = launcherFacts()
                local reason = PlayerPresentation.groundRejection(action, true, phase, owns, near, nil, 0)
                if reason then
                    reject(reason)
                    return
                end
                local state = ReplicatedStorage:FindFirstChild("LauncherState")
                local event = if state then state:FindFirstChild(action) else nil
                if not launcher or not event or not event:IsA("RemoteEvent") then
                    reject("The launcher is unavailable.")
                    return
                end
                feedbackUntil = 0
                launcherSequence += 1
                event:FireServer({
                    roundId = round,
                    sequence = launcherSequence,
                    launcherId = launcher.launcherId,
                })
            end
            local function equip(name: string)
                if overlayOpen() or not eligibleGround(true) then
                    return
                end
                local character, backpack = player.Character, player:FindFirstChildOfClass("Backpack")
                local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
                local tool = if backpack then backpack:FindFirstChild(name) else nil
                if humanoid and tool and tool:IsA("Tool") then
                    humanoid:EquipTool(tool)
                end
            end
            table.insert(
                connections,
                launcherButtons.Pickup.Activated:Connect(function()
                    sendLauncher("Pickup", true)
                end)
            )
            table.insert(
                connections,
                launcherButtons.Drop.Activated:Connect(function()
                    sendLauncher("Drop", true)
                end)
            )
            table.insert(
                connections,
                launcherButtons.M7.Activated:Connect(function()
                    equip("M-7 rifle")
                end)
            )
            table.insert(
                connections,
                launcherButtons.Rocket.Activated:Connect(function()
                    equip("Rocket launcher")
                end)
            )
            local function rifleReadiness(tool: Tool?): PlayerPresentation.Readiness?
                if not tool or tool.Name ~= "M-7 rifle" then
                    return nil
                end
                local ammo = tool:GetAttribute("Ammo")
                local deadline = tool:GetAttribute("ReloadUntil")
                if type(ammo) ~= "number" or type(deadline) ~= "number" then
                    return nil
                end
                local capacity = tool:GetAttribute("MaxAmmo")
                local readyAt = tool:GetAttribute("NextFire")
                return {
                    ammo = ammo,
                    reloadUntil = deadline,
                    capacity = if type(capacity) == "number" then capacity else nil,
                    nextFire = if type(readyAt) == "number" then readyAt else nil,
                    unlimitedReserve = tool:GetAttribute("UnlimitedReserve") == true,
                }
            end
            local function sendReload()
                if overlayOpen() or not eligibleGround(false) then
                    return
                end
                local reason = PlayerPresentation.groundRejection(
                    "Reload",
                    true,
                    nil,
                    false,
                    false,
                    rifleReadiness(selected),
                    workspace:GetServerTimeNow()
                )
                if reason then
                    reject(reason)
                    return
                end
                local event = remote("GroundReload")
                if event and round > 0 then
                    feedbackUntil = 0
                    sequence += 1
                    event:FireServer({ roundId = round, sequence = sequence })
                end
            end
            table.insert(
                connections,
                UserInputService.InputBegan:Connect(function(input, processed)
                    if input.UserInputType == Enum.UserInputType.Touch then
                        windowFocused = true
                    end
                    if processed or overlayOpen() then
                        return
                    end
                    if input.UserInputType == Enum.UserInputType.MouseButton1 and not touchEnabled() then
                        held = selected ~= nil and eligibleGround(false)
                    elseif input.KeyCode == Enum.KeyCode.R then
                        sendReload()
                    elseif input.KeyCode == Enum.KeyCode.E then
                        sendLauncher("Pickup")
                    elseif input.KeyCode == Enum.KeyCode.G then
                        sendLauncher("Drop")
                    end
                end)
            )
            table.insert(
                connections,
                fireButton.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.Touch then
                        windowFocused = true
                    end
                    if
                        input.UserInputType == Enum.UserInputType.Touch
                        and not fireTouch
                        and selected
                        and not overlayOpen()
                        and eligibleGround(false)
                    then
                        fireTouch = input
                        held = true
                    end
                end)
            )
            table.insert(
                connections,
                UserInputService.InputEnded:Connect(function(input)
                    if
                        input == fireTouch
                        or (not touchEnabled() and input.UserInputType == Enum.UserInputType.MouseButton1)
                    then
                        fireTouch = nil
                        held = false
                    end
                end)
            )
            table.insert(connections, reloadButton.Activated:Connect(sendReload))
            table.insert(
                connections,
                UserInputService.WindowFocusReleased:Connect(function()
                    windowFocused = false
                    held = false
                    fireTouch = nil
                end)
            )
            table.insert(
                connections,
                UserInputService.WindowFocused:Connect(function()
                    windowFocused = true
                end)
            )
            local lastTouch: boolean? = nil
            -- Aim from the displayed camera after Roblox and the indoor modifier commit it.
            do
                local function renderAim()
                    local touch = touchEnabled()
                    local layoutInset = GuiService:GetGuiInset()
                    if touch ~= lastTouch then
                        lastTouch = touch
                        gui.ScreenInsets = if touch
                            then Enum.ScreenInsets.CoreUISafeInsets
                            else Enum.ScreenInsets.DeviceSafeInsets
                        label.AnchorPoint = if touch then Vector2.new(1, 0) else Vector2.new(0.5, 1)
                        label.Position, label.Size = GroundCombatController.statusLayout(touch)
                        label.TextSize = if touch then 13 else 16
                        healthLabel.Size =
                            UDim2.fromOffset(if touch then 124 else 188, if touch then 20 else 28)
                        healthLabel.TextSize = if touch then 13 else 14
                        fireButton.AnchorPoint = Vector2.new(1, 0)
                        fireButton.Position = UDim2.new(1, -8, 0, 76)
                        fireButton.Size = UDim2.fromOffset(64, 52)
                        reloadButton.AnchorPoint = Vector2.new(1, 0)
                        reloadButton.Position = UDim2.new(1, -80, 0, 80)
                        reloadButton.Size = UDim2.fromOffset(78, 44)
                        reloadButton.TextSize = 12
                    end
                    if not touch then
                        local origin = projectionOrigin.AbsolutePosition
                        healthLabel.Position = UDim2.fromOffset(12, 169 + layoutInset.Y - origin.Y)
                        feedback.Position = UDim2.new(1, -12, 0, 95 + layoutInset.Y - origin.Y)
                    end
                    local roundId = roundState:GetAttribute("RoundId")
                    if type(roundId) == "number" and roundId ~= round then
                        round = roundId
                        sequence = 0
                        launcherSequence = 0
                        held = false
                        shotUntil, feedbackUntil, nextAttempt = 0, 0, 0
                        lastShot = nil
                    end
                    local character = player.Character
                    local tool = if character
                        then character:FindFirstChild("M-7 rifle") or character:FindFirstChild(
                            "Rocket launcher"
                        )
                        else nil
                    local equipped = if tool and tool:IsA("Tool") then tool else nil
                    if equipped ~= selected then
                        clearTool()
                        selected = equipped
                    end
                    local canFire = eligibleGround(false)
                    local visible = canFire or eligibleGround(true)
                    local overlay = overlayOpen()
                    gui.Enabled = visible
                    label.Visible = not touch or canFire
                    fireButton.Visible = canFire and touch and selected ~= nil and not overlay
                    reloadButton.Visible = fireButton.Visible
                        and selected ~= nil
                        and selected.Name == "M-7 rifle"
                    reticle.Visible = canFire and not overlay
                    local launcherState = ReplicatedStorage:FindFirstChild("LauncherState")
                    local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
                    local closest = math.huge
                    launcher = nil
                    for _, attribute in { "Snapshot", "HangarSnapshot", "DepotSnapshot", "SeedshipSnapshot" } do
                        local value = if launcherState then launcherState:GetAttribute(attribute) else nil
                        local encoded = if type(value) == "string" then value else nil
                        if encoded ~= launcherEncoded[attribute] then
                            launcherEncoded[attribute] = encoded
                            launcherViews[attribute] = if encoded then readLauncher(encoded) else nil
                        end
                        local view = launcherViews[attribute]
                        if not view or view.roundId ~= round then
                            continue
                        end
                        if view.ownerId == player.UserId then
                            launcher = view
                            break
                        end
                        if view.state == "Available" and root and root:IsA("BasePart") then
                            local pos = view.position
                            local distance = (root.Position - Vector3.new(pos.x, pos.y, pos.z)).Magnitude
                            if distance < closest then
                                closest, launcher = distance, view
                            end
                        elseif not launcher then
                            launcher = view
                        end
                    end
                    local launcherPhase, owns, near = launcherFacts()
                    local backpack = player:FindFirstChildOfClass("Backpack")
                    launcherButtons.Pickup.Visible = near and not owns and not GroundInput.menuOpen(playerGui)
                    launcherButtons.Drop.Visible = owns and touch and not overlay
                    launcherButtons.M7.Visible = touch
                        and not overlay
                        and backpack ~= nil
                        and backpack:FindFirstChild("M-7 rifle") ~= nil
                    launcherButtons.Rocket.Visible = owns
                        and touch
                        and not overlay
                        and backpack ~= nil
                        and backpack:FindFirstChild("Rocket launcher") ~= nil
                    local actions: { TextButton } = {}
                    for _, name in { "M7", "Rocket", "Drop", "Pickup" } do
                        local action = launcherButtons[name]
                        if action.Visible then
                            table.insert(actions, action)
                        end
                    end
                    for index, action in actions do
                        local offset = (index - (#actions + 1) * 0.5) * 76
                        action.Position =
                            UDim2.new(0.5, if touch then offset else 0, 1, if touch then -98 else -160)
                        action.Size = UDim2.fromOffset(if touch then 74 else 130, if touch then 44 else 32)
                    end
                    launcherLabel.Visible = not touch
                    if not touch then
                        local ownerId = if launcher then launcher.ownerId else nil
                        local carrier = if ownerId
                            then game:GetService("Players"):GetPlayerByUserId(ownerId)
                            else nil
                        launcherLabel.Text = PlayerPresentation.launcherText(
                            launcherPhase,
                            owns,
                            near,
                            if carrier then string.sub(carrier.DisplayName, 1, 18) else nil
                        )
                    end
                    feedback.Visible = visible and not touch and not overlay and os.clock() < feedbackUntil
                    local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
                    healthLabel.Visible = visible and humanoid ~= nil
                    if touch then
                        healthLabel.Position = UDim2.fromOffset(8, if canFire then 56 else 6)
                    end
                    if humanoid then
                        healthLabel.Text = string.format(
                            if touch then "HP  %d / %d" else "YOUR HEALTH  %d / %d",
                            math.ceil(humanoid.Health),
                            math.ceil(humanoid.MaxHealth)
                        )
                    end
                    if not canFire or overlay then
                        held = false
                        fireTouch = nil
                    end
                    if not visible then
                        return
                    end
                    if not canFire then
                        label.Text = if touch then "" else "Weapons unlock at aircraft arrival"
                        return
                    end
                    local serverTime = workspace:GetServerTimeNow()
                    local rocket = if selected and selected.Name == "Rocket launcher" then selected else nil
                    if rocket then
                        local reloadUntil = rocket:GetAttribute("ReloadUntil")
                        label.Text = if type(reloadUntil) == "number" and reloadUntil > serverTime
                            then string.format("ROCKET • Reload %.1fs", reloadUntil - serverTime)
                            elseif touch then "ROCKET • 1 ready"
                            else "ROCKET • 1 ready • G drop"
                    elseif selected then
                        label.Text = PlayerPresentation.rifleText(rifleReadiness(selected), serverTime, touch)
                    else
                        label.Text = if touch then "" else "Equip M-7 / launcher to fire"
                        label.Visible = not touch
                    end
                    local camera = workspace.CurrentCamera
                    if not camera then
                        return
                    end
                    local point, offset = GroundCombatController.projectAim(
                        camera.ViewportSize,
                        layoutInset,
                        projectionOrigin.AbsolutePosition
                    )
                    reticle.Position = offset
                    local now = os.clock()
                    local aircraftState = ReplicatedStorage:FindFirstChild("AircraftState")
                    local shot = if aircraftState then aircraftState:GetAttribute("GroundShot") else nil
                    if type(shot) == "string" and shot ~= lastShot then
                        lastShot = shot
                        local parsed, value = pcall(function()
                            return HttpService:JSONDecode(shot)
                        end)
                        if
                            parsed
                            and type(value) == "table"
                            and value.userId == player.UserId
                            and value.roundId == round
                        then
                            shotUntil = now + 0.2
                        end
                    end
                    reticle.TextColor3 = if now < shotUntil
                        then Color3.fromRGB(255, 205, 55)
                        else Color3.new(1, 1, 1)
                    if
                        overlay
                        or not selected
                        or not held
                        or now < nextAttempt
                        or UserInputService:GetFocusedTextBox()
                    then
                        return
                    end
                    local rocketRemote = if launcherState then launcherState:FindFirstChild("Fire") else nil
                    local event = if rocket
                        then (if rocketRemote and rocketRemote:IsA("RemoteEvent") then rocketRemote else nil)
                        else remote("GroundFire")
                    if not event then
                        return
                    end
                    local interval = selected:GetAttribute("ShotInterval")
                    local reloadUntil = selected:GetAttribute("ReloadUntil")
                    local readyAt = selected:GetAttribute("NextFire")
                    if
                        (type(reloadUntil) == "number" and serverTime < reloadUntil)
                        or (type(readyAt) == "number" and serverTime < readyAt)
                    then
                        return
                    end
                    nextAttempt = now
                        + (if type(interval) == "number" then math.min(0.25, interval) else 0.15)
                    local ray = camera:ViewportPointToRay(point.X, point.Y)
                    local params = RaycastParams.new()
                    params.FilterType = Enum.RaycastFilterType.Exclude
                    params.FilterDescendantsInstances = if character then { character } else {}
                    local result = workspace:Raycast(ray.Origin, ray.Direction * 950, params)
                    local target = if result then result.Position else ray.Origin + ray.Direction * 950
                    if rocket and launcher then
                        launcherSequence += 1
                        event:FireServer({
                            roundId = round,
                            sequence = launcherSequence,
                            launcherId = launcher.launcherId,
                            x = target.X,
                            y = target.Y,
                            z = target.Z,
                        })
                    elseif not rocket then
                        sequence += 1
                        event:FireServer({
                            roundId = round,
                            sequence = sequence,
                            weapon = "M7",
                            x = target.X,
                            y = target.Y,
                            z = target.Z,
                        })
                    end
                end
                RunService:BindToRenderStep(renderBinding, Enum.RenderPriority.Camera.Value + 2, renderAim)
            end
            return function()
                RunService:UnbindFromRenderStep(renderBinding)
                clearTool()
                for _, connection in connections do
                    connection:Disconnect()
                end
                gui:Destroy()
            end
        end,
    })
end
return GroundCombatController
