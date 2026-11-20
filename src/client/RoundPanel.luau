--!strict
--[=[
    RoundPanel: client-owned match HUD, desktop help/settings and spectator input.
    Reads RoundState, aircraft public state and player attributes. Only the
    existing eligible surrender intent is sent to the server. Local options
    affect feedback and the Results overview. start/stop never yield and own
    one GUI, subscriptions, camera and transient effects for this state Folder.
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Lifecycle = require(ReplicatedStorage.Shared.Lifecycle)
local PlayerPresentation = require(ReplicatedStorage.Shared.PlayerPresentation)
local ThermalCameraController = require(script.Parent.ThermalCameraController)
local PresentationEffects = require(script.Parent.PresentationEffects)
local SpectatorCamera = require(script.Parent.SpectatorCamera)

local RoundPanel = {}
type View = PlayerPresentation.View
type Intensity = PlayerPresentation.Intensity
export type Settings = { effects: Intensity, shake: Intensity }
type Menu = "Help" | "Settings"
type Setting = "Effects" | "CameraShake"

local background = Color3.fromRGB(17, 25, 31)
local surface = Color3.fromRGB(37, 51, 58)
local selectedSurface = Color3.fromRGB(55, 78, 81)
local textColor = Color3.fromRGB(242, 249, 247)
local attention = Color3.fromRGB(255, 218, 155)

local help: { [View]: string } = {
    Waiting = "A team round needs one operator and a Ground team.\n\nGround wins by destroying the plane. The operator wins by eliminating Ground or lasting until the timer expires.\n\nH closes this guide. P opens local settings.",
    Deploying = "The teams are deploying. Watch for your role and objective.\n\nH closes this guide. P opens local settings.",
    Ground = "WASD to move. Mouse to aim. Hold left click to fire.\n\nEquip the M-7 or launcher with the numbered Roblox inventory slots. R reloads the M-7.\n\nE picks up the launcher when close. G drops it. The launcher reloads automatically. Three direct rockets destroy a healthy aircraft. Rifle fire also reduces its health.\n\nUse solid cover and leave damaged panels before they open. One life per round. Surrender gives up your life and enters spectating.",
    Operator = "WASD pans the thermal camera. Mouse aims the reticle. Hold left click to fire. R recenters.\n\n1 selects the 30mm GAU-23/A Chain Gun (closer view). 2 selects the 105mm M102 Howitzer (wider view). Each weapon keeps its own ammo and recovery timer.\n\nSolid cover blocks exposed-player highlights and protects Ground. Light damage leaves scars. Heavy damage opens about half the panel. Total damage removes the panel. Three direct 105mm hits create a Heavy opening and three more remove it. Sustained 30mm fire also damages panels.",
    Spectator = "[ and ] switch between living Ground players. You can also use the Previous and Next buttons.\n\nYou cannot fire, pick up equipment or respawn during this round. Without a living teammate, the camera shows the battlefield overview.\n\nThe next round returns you to play.",
    Results = "The banner explains which team won and how. Ground shares its win, even if you were eliminated earlier.\n\nThe battlefield, equipment and roles reset before the next round.",
    Resetting = "The battlefield, equipment and cameras are resetting. Your next role is assigned at deployment.",
    GroundPreview = "WASD to move, Space to jump and the mouse to look. Explore the two-story Outpost.\n\nThis local preview has no live battle or player results.",
    OperatorPreview = "WASD to pan, mouse to aim and R to recenter. Press 1 for the 30mm close view and 2 for the 105mm wide view.\n\nThis local preview has no live battle or player results.",
}

local function style(item: GuiObject)
    item.BackgroundColor3 = background
    item.BorderSizePixel = 0
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 5)
    corner.Parent = item
end

local function makeLabel(parent: Instance, name: string, position: UDim2, size: UDim2): TextLabel
    local item = Instance.new("TextLabel")
    item.Name = name
    item.Position = position
    item.Size = size
    style(item)
    item.TextColor3 = textColor
    item.TextSize = 16
    item.Font = Enum.Font.GothamMedium
    item.TextWrapped = true
    item.Parent = parent
    return item
end

local function makeButton(
    parent: Instance,
    name: string,
    caption: string,
    position: UDim2,
    size: UDim2
): TextButton
    local item = Instance.new("TextButton")
    item.Name = name
    item.Text = caption
    item.Position = position
    item.Size = size
    style(item)
    item.TextColor3 = textColor
    item.TextSize = 16
    item.Font = Enum.Font.GothamMedium
    item.TextWrapped = true
    item.BackgroundColor3 = surface
    item.Parent = parent
    return item
end

local function makeMenu(parent: Instance, name: string, height: number): Frame
    local frame = Instance.new("Frame")
    frame.Name = name
    frame.AnchorPoint = Vector2.new(1, 0)
    frame.Position = UDim2.new(1, -12, 0, 94)
    frame.Size = UDim2.fromOffset(405, height)
    frame.BackgroundColor3 = background
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Visible = false
    frame.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 5)
    corner.Parent = frame
    return frame
end

local function readResult(encoded: string): PlayerPresentation.Result?
    if #encoded > 512 then
        return nil
    end
    local success, value = pcall(function()
        return HttpService:JSONDecode(encoded)
    end)
    if
        not success
        or type(value) ~= "table"
        or type(value.roundId) ~= "number"
        or type(value.winner) ~= "string"
        or type(value.reason) ~= "string"
    then
        return nil
    end
    return { roundId = value.roundId, winner = value.winner, reason = value.reason }
end

-- Returns fresh session-local defaults. The entrypoint retains the record when
-- server RoundState is replaced. There is no persistence or server setting.
function RoundPanel.newSettings(): Settings
    return { effects = "Full", shake = "Reduced" }
end

-- Creates idempotent round presentation. Optional input/touch providers support
-- existing responsive layout fixtures. The settings record is local and mutable.
function RoundPanel.new(
    player: Player,
    playerGui: PlayerGui,
    state: Instance,
    inputProvider: ThermalCameraController.InputProvider?,
    touchProvider: (() -> boolean)?,
    settings: Settings?
): Lifecycle.Controller
    local options = settings or RoundPanel.newSettings()
    return Lifecycle.new({
        function()
            assert(not playerGui:FindFirstChild("RoundHUD"), "round HUD already owned")
            local gui = Instance.new("ScreenGui")
            gui.Name = "RoundHUD"
            gui.ResetOnSpawn = false
            gui.DisplayOrder = 1
            local label = makeLabel(gui, "Round", UDim2.fromOffset(12, 8), UDim2.fromOffset(300, 38))
            local health =
                makeLabel(gui, "AircraftHealth", UDim2.fromOffset(12, 55), UDim2.fromOffset(250, 34))
            health.TextColor3 = attention
            local guide = makeLabel(gui, "Guide", UDim2.fromOffset(12, 97), UDim2.fromOffset(300, 64))
            guide.TextSize = 14
            local cue = makeLabel(gui, "Cue", UDim2.new(0.5, 0, 0, 8), UDim2.fromOffset(252, 34))
            cue.AnchorPoint = Vector2.new(0.5, 0)
            cue.TextColor3 = attention
            cue.Visible = false
            local surrender = makeButton(
                gui,
                "Surrender",
                "Surrender / spectate",
                UDim2.new(1, -12, 0, 8),
                UDim2.fromOffset(150, 36)
            )
            surrender.AnchorPoint = Vector2.new(1, 0)
            surrender.TextSize = 13
            local helpButton =
                makeButton(gui, "Help", "H  Help", UDim2.new(1, -127, 0, 52), UDim2.fromOffset(100, 34))
            helpButton.AnchorPoint = Vector2.new(1, 0)
            local settingsButton = makeButton(
                gui,
                "Settings",
                "P  Settings",
                UDim2.new(1, -12, 0, 52),
                UDim2.fromOffset(108, 34)
            )
            settingsButton.AnchorPoint = Vector2.new(1, 0)

            local spectatorLabel =
                makeLabel(gui, "SpectatorStatus", UDim2.new(0.5, 0, 1, -82), UDim2.fromOffset(364, 42))
            spectatorLabel.AnchorPoint = Vector2.new(0.5, 1)
            local previous = makeButton(
                gui,
                "PreviousTarget",
                "[  Previous",
                UDim2.new(0.5, -112, 1, -42),
                UDim2.fromOffset(138, 34)
            )
            local nextTarget = makeButton(
                gui,
                "NextTarget",
                "]  Next",
                UDim2.new(0.5, 112, 1, -42),
                UDim2.fromOffset(138, 34)
            )
            previous.AnchorPoint = Vector2.new(0.5, 1)
            nextTarget.AnchorPoint = Vector2.new(0.5, 1)

            local helpContent = makeMenu(gui, "HelpContent", 365)
            local helpHeader =
                makeLabel(helpContent, "Heading", UDim2.fromOffset(12, 6), UDim2.fromOffset(380, 32))
            helpHeader.Font = Enum.Font.GothamBold
            local helpBody =
                makeLabel(helpContent, "Instructions", UDim2.fromOffset(18, 43), UDim2.fromOffset(369, 306))
            helpBody.TextXAlignment = Enum.TextXAlignment.Left
            helpBody.TextYAlignment = Enum.TextYAlignment.Top
            helpBody.TextSize = 15

            local settingsContent = makeMenu(gui, "SettingsContent", 223)
            local settingsHeader =
                makeLabel(settingsContent, "Heading", UDim2.fromOffset(12, 6), UDim2.fromOffset(380, 32))
            settingsHeader.Text = "PRESENTATION SETTINGS"
            settingsHeader.Font = Enum.Font.GothamBold
            local effectSetting = makeButton(
                settingsContent,
                "Effects",
                "",
                UDim2.fromOffset(16, 44),
                UDim2.fromOffset(373, 38)
            )
            local shakeSetting = makeButton(
                settingsContent,
                "CameraShake",
                "",
                UDim2.fromOffset(16, 89),
                UDim2.fromOffset(373, 38)
            )
            local settingsHint = makeLabel(
                settingsContent,
                "Instructions",
                UDim2.fromOffset(16, 137),
                UDim2.fromOffset(373, 71)
            )
            settingsHint.TextSize = 14
            settingsHint.Text =
                "↑ ↓ select  •  ← → change  •  P close\n\nEffects change cue motion and sound. Shake applies only after aircraft destruction."

            local thermal = ThermalCameraController.new(player, playerGui, state, inputProvider)
            local spectator = SpectatorCamera.new(player)
            local effects = PresentationEffects.new(player)
            local connections: { RBXScriptConnection } = {}
            local sequence, oldRoundId = 0, -1
            local seenResult: string? = nil
            local result: PlayerPresentation.Result? = nil
            local view: View = "Waiting"
            local direction = 0
            local canCycle = false
            local menu: Menu? = nil
            local setting: Setting = "Effects"

            local function touchEnabled(): boolean
                return if touchProvider then touchProvider() else UserInputService.TouchEnabled
            end

            local function updateMenu()
                helpContent.Visible = menu == "Help"
                settingsContent.Visible = menu == "Settings"
                gui:SetAttribute("InputOverlayOpen", menu ~= nil)
                gui:SetAttribute("Effects", options.effects)
                gui:SetAttribute("CameraShake", options.shake)
                gui:SetAttribute("SettingsSelection", setting)
                effectSetting.BackgroundColor3 = if setting == "Effects" then selectedSurface else surface
                shakeSetting.BackgroundColor3 = if setting == "CameraShake" then selectedSurface else surface
                effectSetting.Text = (if setting == "Effects" then "›  " else "")
                    .. "Effects  ·  "
                    .. options.effects
                shakeSetting.Text = (if setting == "CameraShake" then "›  " else "")
                    .. "Camera shake  ·  "
                    .. options.shake
            end

            local function toggle(value: Menu)
                if touchEnabled() then
                    return
                end
                menu = if menu == value then nil else value
                if menu == "Settings" then
                    setting = "Effects"
                end
                updateMenu()
            end

            local function changeSetting(name: Setting, backwards: boolean)
                setting = name
                if name == "Effects" then
                    options.effects = PlayerPresentation.cycleIntensity(options.effects, backwards)
                else
                    options.shake = PlayerPresentation.cycleIntensity(options.shake, backwards)
                end
                updateMenu()
            end

            local function cycle(targetDirection: number)
                if view == "Spectator" and canCycle and menu == nil then
                    direction = targetDirection
                end
            end

            local function update()
                local phase = state:GetAttribute("Phase")
                local role = player:GetAttribute("Role")
                local life = player:GetAttribute("Life")
                local preview = if player:GetAttribute("LocalMapPreview") == true
                    then player:GetAttribute("LocalPreviewRole")
                    else nil
                local nextView: View = PlayerPresentation.view(phase, role, life, preview)
                local round = state:GetAttribute("RoundId")
                local roundId = if type(round) == "number" then round else -1
                local touch = touchEnabled()
                if roundId ~= oldRoundId then
                    oldRoundId = roundId
                    sequence = 0
                end
                if view ~= nextView or (touch and menu ~= nil) then
                    menu = nil
                    direction = 0
                    updateMenu()
                end
                view = nextView
                gui:SetAttribute("View", view)
                helpButton.Visible, settingsButton.Visible = not touch, not touch
                local title, purpose = PlayerPresentation.guide(view, life == "Eliminated")
                helpHeader.Text = title
                helpBody.Text = help[view]

                local active = phase == "Active"
                local compact = touch and view == "Ground"
                local activeDetail = ""
                if active then
                    local seconds = PlayerPresentation.remaining(
                        state:GetAttribute("DeadlineSeconds"),
                        workspace:GetServerTimeNow()
                    )
                    local count = state:GetAttribute("GroundAlive")
                    local timer = if seconds
                        then string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
                        else "—"
                    activeDetail = timer
                        .. " remaining • "
                        .. (if type(count) == "number" then tostring(count) else "—")
                        .. " Ground alive"
                end
                local aircraftState = ReplicatedStorage:FindFirstChild("AircraftState")
                local aircraftText: string? = nil
                if active and aircraftState then
                    aircraftText = PlayerPresentation.aircraftText(
                        aircraftState:GetAttribute("Health"),
                        aircraftState:GetAttribute("MaxHealth"),
                        aircraftState:GetAttribute("Destroyed") == true
                    )
                end
                health.Visible = aircraftText ~= nil
                health.Text = aircraftText or ""
                health.Position = UDim2.fromOffset(12, if compact then 44 else 55)
                health.Size = UDim2.fromOffset(if compact then 240 else 250, if compact then 22 else 34)
                health.TextSize = if compact then 14 else 17

                if active or thermal.ownsCamera() then
                    label.AnchorPoint = Vector2.zero
                    label.Position = UDim2.fromOffset(12, 8)
                    label.Size = if compact then UDim2.new(1, -180, 0, 22) else UDim2.fromOffset(300, 38)
                    label.TextSize = 14
                    label.Text = if compact
                        then activeDetail
                        elseif active then title .. "\n" .. activeDetail
                        else title
                    guide.AnchorPoint = Vector2.zero
                    guide.Position = UDim2.fromOffset(12, if health.Visible then 97 else 55)
                    guide.Size = UDim2.fromOffset(300, 64)
                else
                    label.AnchorPoint = Vector2.new(0.5, 0)
                    label.Position = UDim2.new(0.5, 0, 0, 112)
                    label.Size = UDim2.new(0.5, 0, 0, 76)
                    label.TextSize = 19
                    label.Text = if view == "Waiting"
                        then title .. "\nWaiting for " .. tostring(
                            state:GetAttribute("MinimumPlayers") or "enough"
                        ) .. " players"
                        else title
                    guide.AnchorPoint = Vector2.new(0.5, 0)
                    guide.Position = UDim2.new(0.5, 0, 0, 196)
                    guide.Size = UDim2.new(0.5, 0, 0, 50)
                end
                guide.Text = purpose
                guide.Visible = not touch or not active
                surrender.Visible = view == "Ground"
                surrender.Size = UDim2.fromOffset(150, if compact then 32 else 36)

                local reason: string? = nil
                if view == "Results" then
                    local value = state:GetAttribute("Result")
                    local encoded = if type(value) == "string" then value else nil
                    if encoded ~= seenResult then
                        seenResult = encoded
                        result = if encoded then readResult(encoded) else nil
                    end
                    if result and result.roundId == roundId then
                        reason = result.reason
                    end
                    label.Text = PlayerPresentation.resultText(result, roundId)
                else
                    seenResult, result = nil, nil
                end

                local frame = effects.update(
                    view,
                    roundId,
                    reason,
                    os.clock(),
                    PlayerPresentation.intensity(options.effects)
                )
                cue.Text = frame.text or ""
                cue.Visible = frame.text ~= nil
                cue.BackgroundTransparency = 0.19 - frame.pulse * 0.13
                gui:SetAttribute("CuePulse", frame.pulse)
                local targetId, targetName, count = spectator.update(
                    view,
                    roundId,
                    direction,
                    frame.destructionAge,
                    PlayerPresentation.intensity(options.shake)
                )
                direction = 0
                canCycle = count > 1
                gui:SetAttribute("SpectatorUserId", targetId)
                spectatorLabel.Visible = view == "Spectator"
                spectatorLabel.Text = if targetName
                    then "WATCHING  " .. targetName
                    else "No living Ground players • Battlefield overview"
                previous.Visible, nextTarget.Visible = not touch and canCycle, not touch and canCycle
            end

            table.insert(
                connections,
                helpButton.Activated:Connect(function()
                    toggle("Help")
                end)
            )
            table.insert(
                connections,
                settingsButton.Activated:Connect(function()
                    toggle("Settings")
                end)
            )
            table.insert(
                connections,
                effectSetting.Activated:Connect(function()
                    changeSetting("Effects", false)
                end)
            )
            table.insert(
                connections,
                shakeSetting.Activated:Connect(function()
                    changeSetting("CameraShake", false)
                end)
            )
            table.insert(
                connections,
                previous.Activated:Connect(function()
                    cycle(-1)
                end)
            )
            table.insert(
                connections,
                nextTarget.Activated:Connect(function()
                    cycle(1)
                end)
            )
            table.insert(
                connections,
                surrender.Activated:Connect(function()
                    local remote = state:FindFirstChild("Surrender")
                    if view == "Ground" and not menu and remote and remote:IsA("RemoteEvent") then
                        sequence += 1
                        remote:FireServer({ roundId = oldRoundId, sequence = sequence, action = "Surrender" })
                    end
                end)
            )
            table.insert(
                connections,
                UserInputService.InputBegan:Connect(function(input, processed)
                    if touchEnabled() or UserInputService:GetFocusedTextBox() then
                        return
                    end
                    local key = input.KeyCode
                    if menu == "Settings" then
                        if key == Enum.KeyCode.Up or key == Enum.KeyCode.Down then
                            setting = if key == Enum.KeyCode.Up then "Effects" else "CameraShake"
                            updateMenu()
                            return
                        elseif key == Enum.KeyCode.Left or key == Enum.KeyCode.Right then
                            changeSetting(setting, key == Enum.KeyCode.Left)
                            return
                        end
                    end
                    if processed then
                        return
                    end
                    if key == Enum.KeyCode.H then
                        toggle("Help")
                    elseif key == Enum.KeyCode.P then
                        toggle("Settings")
                    elseif key == Enum.KeyCode.LeftBracket then
                        cycle(-1)
                    elseif key == Enum.KeyCode.RightBracket then
                        cycle(1)
                    end
                end)
            )
            table.insert(
                connections,
                state.Destroying:Connect(function()
                    gui.Enabled = false
                end)
            )
            table.insert(connections, RunService.Heartbeat:Connect(update))
            updateMenu()
            update()
            gui.Parent = playerGui
            return function()
                for _, connection in connections do
                    connection:Disconnect()
                end
                effects.stop()
                thermal.stop()
                spectator.stop()
                gui:Destroy()
            end
        end,
    })
end

return RoundPanel
