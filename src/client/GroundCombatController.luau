--!strict
--[=[
    GroundCombatController: local presentation and M-7 intent for an equipped rifle.
    Depends on PlayerGui, UserInputService, current camera and server-owned remotes.
    The server validates ownership, target, timing, cover and damage. start/stop are
    idempotent and disconnect all listeners, release held fire and destroy the HUD.
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Lifecycle = require(ReplicatedStorage.Shared.Lifecycle)
local GroundCombatController = {}

-- Converts desktop screen-space mouse coordinates to viewport pixels. Touch aim
-- remains centered in the viewport. The same rounded pixel drives the ray and
-- the reticle; origin is the measured GUI-content position, in pixels.
-- Pure and nonyielding; all arguments are sampled by the caller each frame.
function GroundCombatController.projectAim(
    viewport: Vector2,
    mouse: Vector2,
    touch: boolean,
    inset: Vector2,
    origin: Vector2
): (Vector2, UDim2)
    local input = if touch then viewport * 0.5 else mouse - inset
    local pixels = Vector2.new(math.floor(input.X + 0.5), math.floor(input.Y + 0.5))
    return pixels,
        UDim2.fromOffset(math.floor(pixels.X - origin.X + 0.5), math.floor(pixels.Y - origin.Y + 0.5))
end

-- Returns the rifle status position and size without yielding. Touch layouts
-- keep the bottom-center ammunition display clear of the centered reticle.
function GroundCombatController.statusLayout(touch: boolean): (UDim2, UDim2)
    if touch then
        return UDim2.new(0.5, 0, 1, -20), UDim2.fromOffset(260, 36)
    end
    return UDim2.new(0.5, 0, 1, -100), UDim2.fromOffset(330, 36)
end

-- Owns UI/input for one round-state lifetime. No yielding or combat authority.
function GroundCombatController.new(
    player: Player,
    playerGui: PlayerGui,
    roundState: Instance
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
            label.Position, label.Size = GroundCombatController.statusLayout(UserInputService.TouchEnabled)
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
            gui.Parent = playerGui
            local selected: Tool? = nil
            local toolConnections: { RBXScriptConnection } = {}
            local connections: { RBXScriptConnection } = {}
            local held = false
            local fireTouch: InputObject? = nil
            local sequence = 0
            local round = -1
            local nextAttempt = 0
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
            local function sendReload()
                local event = remote("GroundReload")
                if event and selected and round > 0 then
                    sequence += 1
                    event:FireServer({ roundId = round, sequence = sequence })
                end
            end
            table.insert(
                connections,
                UserInputService.InputBegan:Connect(function(input, processed)
                    if not processed and input.KeyCode == Enum.KeyCode.R and selected then
                        sendReload()
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
                    local roundId = roundState:GetAttribute("RoundId")
                    if type(roundId) == "number" and roundId ~= round then
                        round = roundId
                        sequence = 0
                        held = false
                    end
                    local character = player.Character
                    local tool = if character then character:FindFirstChild("M-7 rifle") else nil
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
                    local visible = selected ~= nil
                        and player:GetAttribute("Role") == "Ground"
                        and player:GetAttribute("Life") == "Alive"
                        and roundState:GetAttribute("Phase") == "Active"
                    gui.Enabled = visible
                    fireButton.Visible = UserInputService.TouchEnabled
                    reloadButton.Visible = UserInputService.TouchEnabled
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
                    label.Text = if remaining > 0
                        then string.format("M-7 • Reload %.1fs", remaining)
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
                        UserInputService.TouchEnabled,
                        GuiService:GetGuiInset(),
                        projectionOrigin.AbsolutePosition
                    )
                    reticle.Position = offset
                    local now = os.clock()
                    if not held or now < nextAttempt then
                        return
                    end
                    local event = remote("GroundFire")
                    if not event then
                        return
                    end
                    nextAttempt = now + 0.15
                    local ray = camera:ViewportPointToRay(point.X, point.Y)
                    local params = RaycastParams.new()
                    params.FilterType = Enum.RaycastFilterType.Exclude
                    params.FilterDescendantsInstances = if character then { character } else {}
                    local result = workspace:Raycast(ray.Origin, ray.Direction * 950, params)
                    local target = if result then result.Position else ray.Origin + ray.Direction * 950
                    sequence += 1
                    event:FireServer({
                        roundId = round,
                        sequence = sequence,
                        weapon = "M7",
                        x = target.X,
                        y = target.Y,
                        z = target.Z,
                    })
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
