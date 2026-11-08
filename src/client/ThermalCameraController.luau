--!strict
--[=[
    ThermalCameraController: local inward operator view, profile HUD and occluded
    thermal presentation. Depends on replicated AircraftState, canonical Aircraft,
    player role/round attributes and Roblox camera/input. It has no hit authority.
    Selection sends bounded intent and only renders acknowledged production profiles;
    labelled Studio solo preview can choose cosmetic profiles without a real role.
    new/ownsCamera/stop never yield. stop restores captured camera/input state and
    destroys all owned GUI/effects/highlights/listeners, including after role loss.
]=]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")
local AircraftRules = require(ReplicatedStorage.Shared.AircraftRules)
local MapRules = require(ReplicatedStorage.Shared.MapRules)
local ThermalCameraController = {}
export type Controller = { ownsCamera: () -> boolean, stop: () -> () }
type SavedCamera = {
    camera: Camera,
    kind: Enum.CameraType,
    frame: CFrame,
    fov: number,
    mouse: Enum.MouseBehavior,
    icon: boolean,
}

-- Role gate is presentation only. The production server independently authorizes
-- selection. RoundPanel calls ownsCamera before writing any spectator/character view.
function ThermalCameraController.new(player: Player, playerGui: PlayerGui, roundState: Instance): Controller
    local running = true
    local active = false
    local saved: SavedCamera? = nil
    local gui: ScreenGui? = nil
    local label: TextLabel? = nil
    local reticle: TextLabel? = nil
    local correction: ColorCorrectionEffect? = nil
    local highlights: { [Model]: Highlight } = {}
    local buttons: { RBXScriptConnection } = {}
    local sequence = 0
    local lastRound = -1
    local previewWeapon = "GAU23"
    local function eligible(): boolean
        return running
            and (
                (
                    roundState:GetAttribute("Phase") == "Active"
                    and player:GetAttribute("Role") == "Gunship"
                    and player:GetAttribute("Life") == "Alive"
                )
                or (
                    roundState:GetAttribute("Phase") == "Lobby"
                    and player:GetAttribute("LocalMapPreview") == true
                    and player:GetAttribute("LocalPreviewRole") == "Gunship"
                )
            )
    end
    local function leave()
        if not active then
            return
        end
        active = false
        for _, connection in buttons do
            connection:Disconnect()
        end
        table.clear(buttons)
        for model, highlight in highlights do
            highlight:Destroy()
            highlights[model] = nil
        end
        if correction then
            correction:Destroy()
            correction = nil
        end
        if gui then
            gui:Destroy()
            gui = nil
        end
        label = nil
        reticle = nil
        local previous = saved
        if previous then
            previous.camera.CameraType = previous.kind
            previous.camera.CFrame = previous.frame
            previous.camera.FieldOfView = previous.fov
            UserInputService.MouseBehavior = previous.mouse
            UserInputService.MouseIconEnabled = previous.icon
        end
        saved = nil
    end
    local function selectWeapon(weapon: string)
        if not eligible() then
            return
        end
        if player:GetAttribute("LocalMapPreview") == true and roundState:GetAttribute("Phase") == "Lobby" then
            previewWeapon = weapon
            return
        end
        local state = ReplicatedStorage:FindFirstChild("AircraftState")
        local remote = if state then state:FindFirstChild("SelectWeapon") else nil
        if remote and remote:IsA("RemoteEvent") then
            sequence += 1
            remote:FireServer({
                roundId = roundState:GetAttribute("RoundId"),
                sequence = sequence,
                weapon = weapon,
            })
        end
    end
    local function enter(camera: Camera)
        active = true
        previewWeapon = "GAU23"
        saved = {
            camera = camera,
            kind = camera.CameraType,
            frame = camera.CFrame,
            fov = camera.FieldOfView,
            mouse = UserInputService.MouseBehavior,
            icon = UserInputService.MouseIconEnabled,
        }
        local screen = Instance.new("ScreenGui")
        screen.Name = "ThermalHUD"
        screen.IgnoreGuiInset = true
        screen.ResetOnSpawn = false
        local caption = Instance.new("TextLabel")
        caption.Name = "Profile"
        caption.AnchorPoint = Vector2.new(0.5, 1)
        caption.Position = UDim2.new(0.5, 0, 1, -72)
        caption.Size = UDim2.fromOffset(580, 60)
        caption.BackgroundColor3 = Color3.fromRGB(12, 15, 16)
        caption.BackgroundTransparency = 0.15
        caption.TextColor3 = Color3.new(1, 1, 1)
        caption.TextSize = 17
        caption.TextWrapped = true
        caption.Font = Enum.Font.Gotham
        caption.Parent = screen
        label = caption
        for index, weapon in { "GAU23", "M102" } do
            local button = Instance.new("TextButton")
            button.Name = weapon
            button.AnchorPoint = Vector2.new(0.5, 1)
            button.Position = UDim2.new(0.5, (index - 1.5) * 290, 1, -28)
            button.Size = UDim2.fromOffset(280, 36)
            button.Text = tostring(index) .. " • " .. AircraftRules.names[weapon]
            button.Font = Enum.Font.Gotham
            button.TextSize = 16
            button.BackgroundColor3 = Color3.fromRGB(30, 38, 42)
            button.TextColor3 = Color3.new(1, 1, 1)
            button.Parent = screen
            table.insert(
                buttons,
                button.Activated:Connect(function()
                    selectWeapon(weapon)
                end)
            )
        end
        local cross = Instance.new("TextLabel")
        cross.Name = "Reticle"
        cross.Size = UDim2.fromOffset(34, 34)
        cross.AnchorPoint = Vector2.new(0.5, 0.5)
        cross.BackgroundTransparency = 1
        cross.Text = "+"
        cross.TextSize = 36
        cross.Font = Enum.Font.Code
        cross.TextColor3 = Color3.new(1, 1, 1)
        cross.Parent = screen
        reticle = cross
        screen.Parent = playerGui
        gui = screen
        table.insert(
            buttons,
            UserInputService.InputBegan:Connect(function(event, processed)
                if not processed and eligible() then
                    if event.KeyCode == Enum.KeyCode.One then
                        selectWeapon("GAU23")
                    elseif event.KeyCode == Enum.KeyCode.Two then
                        selectWeapon("M102")
                    end
                end
            end)
        )
        local effect = Instance.new("ColorCorrectionEffect")
        effect.Name = "OperatorThermal"
        effect.Saturation = -1
        effect.Contrast = 0.35
        effect.Brightness = 0.04
        effect.Parent = camera
        correction = effect
    end
    local function render()
        local state = ReplicatedStorage:FindFirstChild("AircraftState")
        local aircraft = workspace:FindFirstChild("Aircraft")
        local hitbox = if aircraft then aircraft:FindFirstChild("Hitbox") else nil
        local camera = workspace.CurrentCamera
        if not eligible() or not state or not hitbox or not hitbox:IsA("BasePart") or not camera then
            leave()
            return
        end
        if saved and saved.camera ~= camera then
            leave()
        end
        if not active then
            enter(camera)
        end
        local roundId = roundState:GetAttribute("RoundId")
        if type(roundId) == "number" and roundId ~= lastRound then
            sequence = 0
            lastRound = roundId
        end
        local preview = roundState:GetAttribute("Phase") == "Lobby"
        local weapon = previewWeapon
        if not preview then
            local encoded = state:GetAttribute("Selection")
            if type(encoded) ~= "string" then
                return
            end
            local ok, decoded = pcall(function()
                return HttpService:JSONDecode(encoded)
            end)
            if
                not ok
                or type(decoded) ~= "table"
                or decoded.roundId ~= roundId
                or (decoded.weapon ~= "GAU23" and decoded.weapon ~= "M102")
            then
                return
            end
            weapon = decoded.weapon
        end
        local fov = AircraftRules.fov(AircraftRules.defaults, weapon)
        assert(fov, "acknowledged aircraft profile")
        local map = MapRules.defaults
        camera.CameraType = Enum.CameraType.Scriptable
        camera.CFrame = CFrame.lookAt(hitbox.Position, Vector3.new(map.focusX, map.focusY, map.focusZ))
        camera.FieldOfView = fov
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        UserInputService.MouseIconEnabled = false
        local viewport = camera.ViewportSize
        local mouse = UserInputService:GetMouseLocation()
        -- The view never rotates. Reticle remains within the central 70% of viewport.
        local x = math.clamp(mouse.X, viewport.X * 0.15, viewport.X * 0.85)
        local y = math.clamp(mouse.Y, viewport.Y * 0.15, viewport.Y * 0.85)
        local ray = camera:ViewportPointToRay(x, y)
        local distance = if ray.Direction.Y < -1e-6
            then (map.groundY - ray.Origin.Y) / ray.Direction.Y
            else -1
        local endpoint = ray.Origin + ray.Direction * math.max(0, distance)
        local validAim = distance > 0 and AircraftRules.aimAllowed(map, endpoint.X, endpoint.Y, endpoint.Z)
        local cross = reticle
        local caption = label
        local screen = gui
        if cross and caption and screen then
            cross.Position = UDim2.fromOffset(x, y)
            cross.TextColor3 = if validAim then Color3.new(1, 1, 1) else Color3.fromRGB(255, 140, 90)
            caption.Text = (if preview then "Studio preview • " else "")
                .. AircraftRules.names[weapon]
                .. string.format(
                    " • %d° FOV\nMove mouse to aim • 1 / 2 select • Firing arrives in P05",
                    fov
                )
            -- Observable projection commit used by engine tests and accessibility tooling.
            screen:SetAttribute("Weapon", weapon)
            screen:SetAttribute("FOV", fov)
            screen:SetAttribute("AimAllowed", validAim)
            screen:SetAttribute("AimEndpoint", endpoint)
            screen:SetAttribute("ReticlePixels", Vector2.new(x, y))
        end
        local targets: { [Model]: boolean } = {}
        for _, other in Players:GetPlayers() do
            if
                other:GetAttribute("Role") == "Ground"
                and other:GetAttribute("Life") == "Alive"
                and other.Character
            then
                targets[other.Character] = true
            end
        end
        -- Server-authored tagged thermal fixtures/targets; no per-client visibility state.
        for _, target in CollectionService:GetTagged("ThermalTarget") do
            if target:IsA("Model") and target:IsDescendantOf(workspace) then
                targets[target] = true
            end
        end
        for target in targets do
            if not highlights[target] then
                local highlight = Instance.new("Highlight")
                highlight.Name = "OperatorThermalTarget"
                highlight.Adornee = target
                highlight.DepthMode = Enum.HighlightDepthMode.Occluded
                highlight.FillColor = Color3.new(1, 1, 1)
                highlight.FillTransparency = 0.15
                highlight.OutlineTransparency = 1
                highlight.Parent = camera
                highlights[target] = highlight
            end
        end
        for target, highlight in highlights do
            if not targets[target] then
                highlight:Destroy()
                highlights[target] = nil
            end
        end
    end
    -- Runs after Roblox's camera update. RoundPanel's Heartbeat owns only other roles.
    local connection = RunService.RenderStepped:Connect(render)
    render()
    return {
        ownsCamera = eligible,
        stop = function()
            if not running then
                return
            end
            running = false
            connection:Disconnect()
            leave()
        end,
    }
end
return ThermalCameraController
