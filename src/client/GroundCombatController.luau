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
local GroundCombatController = {}
type LauncherView = {
    roundId: number,
    launcherId: string,
    state: string,
    ownerId: number?,
    readyAt: number,
    ammo: number,
    position: { x: number, y: number, z: number },
}

-- Mouse and touch-center inputs use viewport pixels. GUI layout uses its
-- measured content origin plus the current inset. One rounded viewport pixel
-- drives both the reticle and the ray.
-- Pure and nonyielding; all arguments are sampled by the caller each frame.
function GroundCombatController.projectAim(
    viewport: Vector2,
    mouse: Vector2,
    touch: boolean,
    inset: Vector2,
    origin: Vector2
): (Vector2, UDim2)
    local input = if touch then viewport * 0.5 else mouse
    local pixels = Vector2.new(math.floor(input.X + 0.5), math.floor(input.Y + 0.5))
    local guiOrigin = origin + inset
    return pixels,
        UDim2.fromOffset(math.floor(pixels.X - guiOrigin.X + 0.5), math.floor(pixels.Y - guiOrigin.Y + 0.5))
end

-- Weapon readiness layout in GUI-content pixels. Touch shares a compact
-- header with RoundPanel: health left/readiness right, then ownership left.
-- origin is this ScreenGui's measured content origin; unlike viewport rays,
-- readouts must share coordinates with the normal-inset RoundHUD. No yielding.
function GroundCombatController.statusLayout(
    touch: boolean,
    origin: Vector2?,
    inset: Vector2?
): (UDim2, UDim2)
    local offset = origin or Vector2.zero
    local safeInset = inset or Vector2.zero
    if touch then
        return UDim2.new(1, -132 - offset.X - safeInset.X, 0, 66 - offset.Y), UDim2.fromOffset(240, 22)
    end
    return UDim2.new(0.5, 0, 1, -100), UDim2.fromOffset(330, 36)
end

-- Bottom touch actions leave a 96px native inventory band clear. Narrower
-- equipment buttons also keep the minimum landscape thumbstick region clear.
local function pickupPosition(touch: boolean, origin: Vector2?, inset: Vector2?): UDim2
    local offset, safeInset = origin or Vector2.zero, inset or Vector2.zero
    return if touch
        then UDim2.new(0.5, -offset.X - safeInset.X, 1, -104 - offset.Y - safeInset.Y)
        else UDim2.new(0.5, 0, 1, -160)
end

local function launcherStatusPosition(touch: boolean, origin: Vector2?): UDim2
    local offset = origin or Vector2.zero
    return if touch then UDim2.fromOffset(132 - offset.X, 92 - offset.Y) else UDim2.new(0.5, 0, 1, -204)
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
            local lastTouch = touchEnabled()
            label.Position, label.Size = GroundCombatController.statusLayout(lastTouch)
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
            local hitMarker = Instance.new("TextLabel")
            hitMarker.Name = "AircraftHit"
            hitMarker.AnchorPoint = Vector2.new(0.5, 0)
            hitMarker.Size = UDim2.fromOffset(180, 26)
            hitMarker.BackgroundTransparency = 1
            hitMarker.Text = "AIRCRAFT HIT  −5"
            hitMarker.TextSize = 20
            hitMarker.Font = Enum.Font.GothamBold
            hitMarker.TextColor3 = Color3.fromRGB(255, 215, 80)
            hitMarker.TextStrokeTransparency = 0
            hitMarker.Visible = false
            hitMarker.Parent = gui
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
            launcherLabel.Position = launcherStatusPosition(lastTouch)
            launcherLabel.Size =
                UDim2.fromOffset(if lastTouch then 240 else 360, if lastTouch then 22 else 28)
            launcherLabel.TextSize = 14
            launcherLabel.Parent = gui
            local launcherButtons: { [string]: TextButton } = {}
            for index, name in { "M7", "Rocket", "Drop", "Pickup" } do
                local button = Instance.new("TextButton")
                button.Name = name
                button.AnchorPoint = Vector2.new(0.5, 1)
                button.Position = UDim2.new(0.5, if name == "Pickup" then 0 else (index - 2) * 90, 1, -104)
                if name == "Pickup" then
                    button.Position = pickupPosition(lastTouch)
                end
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
            local toolConnections: { RBXScriptConnection } = {}
            local connections: { RBXScriptConnection } = {}
            local held = false
            local fireTouch: InputObject? = nil
            local sequence = 0
            local launcherSequence = 0
            local launcher: LauncherView? = nil
            local launcherEncoded: string? = nil
            local round = -1
            local nextAttempt = 0
            local lastShot: string? = nil
            local hitUntil = 0
            local shotUntil = 0
            local function clearTool()
                held = false
                fireTouch = nil
                for _, connection in toolConnections do
                    connection:Disconnect()
                end
                table.clear(toolConnections)
                selected = nil
            end
            local function remote(name: string): RemoteEvent?
                local aircraftState = ReplicatedStorage:FindFirstChild("AircraftState")
                local item = if aircraftState then aircraftState:FindFirstChild(name) else nil
                return if item and item:IsA("RemoteEvent") then item else nil
            end
            local function sendLauncher(action: string)
                local state = ReplicatedStorage:FindFirstChild("LauncherState")
                local event = if state then state:FindFirstChild(action) else nil
                if not launcher or not event or not event:IsA("RemoteEvent") then
                    return
                end
                launcherSequence += 1
                event:FireServer({
                    roundId = round,
                    sequence = launcherSequence,
                    launcherId = launcher.launcherId,
                })
            end
            local function equip(name: string)
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
                    sendLauncher("Pickup")
                end)
            )
            table.insert(
                connections,
                launcherButtons.Drop.Activated:Connect(function()
                    sendLauncher("Drop")
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
            local function sendReload()
                local event = remote("GroundReload")
                if event and selected and selected.Name == "M-7 rifle" and round > 0 then
                    sequence += 1
                    event:FireServer({ roundId = round, sequence = sequence })
                end
            end
            table.insert(
                connections,
                UserInputService.InputBegan:Connect(function(input, processed)
                    if processed or UserInputService:GetFocusedTextBox() then
                        return
                    end
                    if input.KeyCode == Enum.KeyCode.R and selected then
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
                fireButton.MouseButton1Down:Connect(function()
                    held = true
                end)
            )
            table.insert(
                connections,
                fireButton.MouseButton1Up:Connect(function()
                    held = false
                end)
            )
            table.insert(
                connections,
                fireButton.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.Touch and not fireTouch then
                        fireTouch = input
                        held = true
                    end
                end)
            )
            table.insert(
                connections,
                UserInputService.InputEnded:Connect(function(input)
                    if input == fireTouch then
                        fireTouch = nil
                        held = false
                    end
                end)
            )
            table.insert(connections, reloadButton.Activated:Connect(sendReload))
            table.insert(
                connections,
                UserInputService.WindowFocusReleased:Connect(function()
                    held = false
                    fireTouch = nil
                end)
            )
            table.insert(
                connections,
                RunService.RenderStepped:Connect(function()
                    local touch = touchEnabled()
                    local origin = projectionOrigin.AbsolutePosition
                    local layoutInset = GuiService:GetGuiInset()
                    label.Position, label.Size =
                        GroundCombatController.statusLayout(touch, origin, layoutInset)
                    label.TextSize = if touch then 14 else 16
                    launcherButtons.Pickup.Position = pickupPosition(touch, origin, layoutInset)
                    launcherLabel.Position = launcherStatusPosition(touch, origin)
                    launcherLabel.Size =
                        UDim2.fromOffset(if touch then 240 else 360, if touch then 22 else 28)
                    for index, name in { "M7", "Rocket", "Drop" } do
                        local button = launcherButtons[name]
                        button.Size = UDim2.fromOffset(if touch then 68 else 84, 32)
                        button.Position = if touch
                            then UDim2.new(
                                0.5,
                                (index - 2) * 74 - origin.X - layoutInset.X,
                                1,
                                -104 - origin.Y - layoutInset.Y
                            )
                            else UDim2.new(0.5, (index - 2) * 90, 1, -104)
                    end
                    fireButton.Size = UDim2.fromOffset(if touch then 78 else 90, if touch then 56 else 70)
                    fireButton.Position = if touch
                        then UDim2.new(1, -24 - origin.X - layoutInset.X, 0, 126 - origin.Y)
                        else UDim2.new(1, -24, 1, -130)
                    reloadButton.Size = UDim2.fromOffset(if touch then 54 else 90, if touch then 42 else 54)
                    reloadButton.Position = if touch
                        then UDim2.new(1, -120 - origin.X - layoutInset.X, 0, 128 - origin.Y)
                        else UDim2.new(1, -24, 1, -210)
                    reloadButton.TextSize = if touch then 12 else 16
                    local roundId = roundState:GetAttribute("RoundId")
                    if type(roundId) == "number" and roundId ~= round then
                        round = roundId
                        sequence = 0
                        launcherSequence = 0
                        held = false
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
                        if equipped then
                            table.insert(
                                toolConnections,
                                equipped.Activated:Connect(function()
                                    held = true
                                end)
                            )
                            table.insert(
                                toolConnections,
                                equipped.Deactivated:Connect(function()
                                    held = false
                                end)
                            )
                        end
                    end
                    local visible = player:GetAttribute("Role") == "Ground"
                        and player:GetAttribute("Life") == "Alive"
                        and roundState:GetAttribute("Phase") == "Active"
                    gui.Enabled = visible
                    fireButton.Visible = touch
                    reloadButton.Visible = touch and (selected == nil or selected.Name == "M-7 rifle")
                    reticle.Visible = selected ~= nil
                    local launcherState = ReplicatedStorage:FindFirstChild("LauncherState")
                    local encoded = if launcherState then launcherState:GetAttribute("Snapshot") else nil
                    if type(encoded) == "string" and encoded ~= launcherEncoded then
                        launcherEncoded = encoded
                        local parsed, value = pcall(function()
                            return HttpService:JSONDecode(encoded)
                        end)
                        launcher = if parsed and type(value) == "table"
                            then (value :: unknown) :: LauncherView
                            else nil
                    elseif not launcherState then
                        launcher = nil
                        launcherEncoded = nil
                    end
                    local owns = launcher ~= nil
                        and launcher.roundId == round
                        and launcher.ownerId == player.UserId
                    local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
                    local near = false
                    if launcher and launcher.state == "Available" and root and root:IsA("BasePart") then
                        local spot = launcher.position
                        near = (root.Position - Vector3.new(spot.x, spot.y, spot.z)).Magnitude <= 8
                    end
                    for name, button in launcherButtons do
                        button.Visible = if name == "Pickup" then near else owns and touch
                    end
                    if launcher and launcher.state == "Available" then
                        launcherLabel.Text = if near
                            then "LAUNCHER • E / PICK UP"
                            else "LAUNCHER • available on map"
                    elseif launcher and launcher.ownerId then
                        local carrier = game:GetService("Players"):GetPlayerByUserId(launcher.ownerId)
                        launcherLabel.Text = if owns
                            then "LAUNCHER • yours • G to drop"
                            else "LAUNCHER • " .. (if carrier
                                then string.sub(carrier.DisplayName, 1, 16)
                                else "teammate")
                    else
                        launcherLabel.Text = "LAUNCHER • unavailable"
                    end
                    if not visible then
                        held = false
                        return
                    end
                    local ammo = selected and selected:GetAttribute("Ammo") or 0
                    local reserve = selected and selected:GetAttribute("Reserve") or 0
                    local reloadUntil = selected and selected:GetAttribute("ReloadUntil") or 0
                    local remaining = if type(reloadUntil) == "number"
                        then math.max(0, reloadUntil - workspace:GetServerTimeNow())
                        else 0
                    local rocketSelected = selected ~= nil and selected.Name == "Rocket launcher"
                    label.Text = if rocketSelected
                        then (if remaining > 0
                            then string.format("ROCKET • Reload %.1fs", remaining)
                            else "ROCKET • 1 ready • G drop")
                        elseif not selected then "Equip M-7 / launcher to fire"
                        elseif remaining > 0 then string.format("M-7 • Reload %.1fs", remaining)
                        else string.format(
                            "M-7 • %s / %s • R reload",
                            tostring(ammo),
                            tostring(reserve)
                        )
                    local camera = workspace.CurrentCamera
                    if not camera then
                        return
                    end
                    local point, offset = GroundCombatController.projectAim(
                        camera.ViewportSize,
                        UserInputService:GetMouseLocation(),
                        touch,
                        GuiService:GetGuiInset(),
                        projectionOrigin.AbsolutePosition
                    )
                    reticle.Position = offset
                    hitMarker.Position = offset + UDim2.fromOffset(0, 18)
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
                            if value.aircraftHit == true then
                                hitUntil = now + 1.2
                                hitMarker.Text = "AIRCRAFT HIT  −5"
                            end
                        end
                    end
                    local impact = if launcherState then launcherState:GetAttribute("LastImpact") else nil
                    if type(impact) == "string" and impact ~= gui:GetAttribute("LastRocketImpact") then
                        gui:SetAttribute("LastRocketImpact", impact)
                        local parsed, value = pcall(function()
                            return HttpService:JSONDecode(impact)
                        end)
                        if
                            parsed
                            and type(value) == "table"
                            and value.userId == player.UserId
                            and value.roundId == round
                            and value.aircraftHit == true
                        then
                            hitUntil = now + 1.2
                            hitMarker.Text = "ROCKET HIT"
                        end
                    end
                    hitMarker.Visible = not touch and now < hitUntil
                    if touch and now < hitUntil then
                        label.Text ..= " • HIT"
                    end
                    reticle.TextColor3 = if now < shotUntil
                        then Color3.fromRGB(255, 205, 55)
                        else Color3.new(1, 1, 1)
                    if
                        not selected
                        or not held
                        or now < nextAttempt
                        or UserInputService:GetFocusedTextBox()
                    then
                        return
                    end
                    local rocketRemote = if launcherState then launcherState:FindFirstChild("Fire") else nil
                    local event = if rocketSelected
                        then (if rocketRemote and rocketRemote:IsA("RemoteEvent") then rocketRemote else nil)
                        else remote("GroundFire")
                    if not event then
                        return
                    end
                    nextAttempt = now + (if rocketSelected then 0.25 else 0.15)
                    local ray = camera:ViewportPointToRay(point.X, point.Y)
                    local params = RaycastParams.new()
                    params.FilterType = Enum.RaycastFilterType.Exclude
                    params.FilterDescendantsInstances = if character then { character } else {}
                    local result = workspace:Raycast(ray.Origin, ray.Direction * 950, params)
                    local target = if result then result.Position else ray.Origin + ray.Direction * 950
                    if rocketSelected and launcher then
                        launcherSequence += 1
                        event:FireServer({
                            roundId = round,
                            sequence = launcherSequence,
                            launcherId = launcher.launcherId,
                            x = target.X,
                            y = target.Y,
                            z = target.Z,
                        })
                    elseif not rocketSelected then
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
                end)
            )
            return function()
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
