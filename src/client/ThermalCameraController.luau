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
local GuiService = game:GetService("GuiService")
local AircraftRules = require(ReplicatedStorage.Shared.AircraftRules)
local AircraftPanRules = require(ReplicatedStorage.Shared.AircraftPanRules)
local MapRules = require(ReplicatedStorage.Shared.MapRules)
local Validation = require(ReplicatedStorage.Shared.Validation)
local ThermalCameraController = {}
export type Controller = { ownsCamera: () -> boolean, stop: () -> () }
-- Optional deterministic input boundary for accessibility/adapters and engine fixtures.
-- Position is raw viewport pixels. Providers must not yield; invalid values hold focus.
export type InputFrame = { position: Vector2, blocked: boolean, recenter: boolean?, weapon: string? }
export type InputProvider = (Vector2) -> InputFrame
type SavedCamera = {
    camera: Camera,
    kind: Enum.CameraType,
    frame: CFrame,
    fov: number,
    mouse: Enum.MouseBehavior,
    icon: boolean,
}

-- Constructs the inward camera basis without a world-up singularity. Canonical
-- orbit-right is projected onto the look plane, preserving finite orientation even
-- when focus lies exactly below the aircraft. Invalid geometry returns nil.
function ThermalCameraController.frame(position: Vector3, focus: Vector3): CFrame?
    for _, value in { position.X, position.Y, position.Z, focus.X, focus.Y, focus.Z } do
        if not Validation.isFinite(value) then
            return nil
        end
    end
    local map = MapRules.defaults
    if Vector2.new(focus.X - map.centerX, focus.Z - map.centerZ).Magnitude > map.radiusStuds + 0.001 then
        return nil
    end
    local radial = Vector3.new(position.X - map.centerX, 0, position.Z - map.centerZ)
    local direction = focus - position
    if radial.Magnitude < 1e-6 or direction.Magnitude < 1e-6 then
        return nil
    end
    local look = direction.Unit
    radial = radial.Unit
    if look:Dot(-radial) < -1e-6 then
        return nil
    end
    local canonicalRight = Vector3.new(radial.Z, 0, -radial.X)
    local right = canonicalRight - look * canonicalRight:Dot(look)
    if right.Magnitude < 1e-6 then
        return nil
    end
    right = right.Unit
    return CFrame.fromMatrix(position, right, right:Cross(look), -look)
end

-- Samples the production pointer/UI boundary without yielding. pointer is the raw
-- GetMouseLocation viewport position; windowFocused comes from the owned focus
-- listeners. Only GetGuiObjectsAtPosition uses GUI-content coordinates, so subtract
-- the current top-left GuiInset for that query alone. Returned pointer pixels are
-- unchanged for edge pan, reticle drawing and camera rays. Invalid pixels fail closed.
function ThermalCameraController.input(
    playerGui: PlayerGui,
    pointer: Vector2,
    windowFocused: boolean
): InputFrame
    local blocked = not windowFocused or UserInputService:GetFocusedTextBox() ~= nil
    if not Validation.isFinite(pointer.X) or not Validation.isFinite(pointer.Y) then
        return { position = pointer, blocked = true }
    end
    local inset = GuiService:GetGuiInset()
    local query = pointer - inset
    for _, object in playerGui:GetGuiObjectsAtPosition(math.floor(query.X), math.floor(query.Y)) do
        if object:IsA("GuiButton") or object:IsA("TextBox") or object.Active then
            blocked = true
            break
        end
    end
    return { position = pointer, blocked = blocked }
end

-- Role gate is presentation only. The production server independently authorizes
-- selection. RoundPanel calls ownsCamera before writing any spectator/character view.
function ThermalCameraController.new(
    player: Player,
    playerGui: PlayerGui,
    roundState: Instance,
    inputProvider: InputProvider?
): Controller
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
    local map = MapRules.defaults
    local focus = AircraftPanRules.recenter(map)
    local recenterRequested = false
    local frameNumber = 0
    local windowFocused = true
    local function sampleInput(_viewport: Vector2): InputFrame
        return ThermalCameraController.input(playerGui, UserInputService:GetMouseLocation(), windowFocused)
    end
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
        if (weapon ~= "GAU23" and weapon ~= "M102") or not eligible() then
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
        focus = AircraftPanRules.recenter(map)
        recenterRequested = false
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
        screen.ScreenInsets = Enum.ScreenInsets.None
        screen.ClipToDeviceSafeArea = false
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
        local recenter = Instance.new("TextButton")
        recenter.Name = "Recenter"
        recenter.AnchorPoint = Vector2.new(1, 0)
        recenter.Position = UDim2.new(1, -16, 0, 16)
        recenter.Size = UDim2.fromOffset(150, 32)
        recenter.Text = "R • Recenter"
        recenter.Font = Enum.Font.Gotham
        recenter.TextSize = 16
        recenter.BackgroundColor3 = Color3.fromRGB(30, 38, 42)
        recenter.TextColor3 = Color3.new(1, 1, 1)
        recenter.Parent = screen
        table.insert(
            buttons,
            recenter.Activated:Connect(function()
                recenterRequested = true
            end)
        )
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
                    elseif event.KeyCode == Enum.KeyCode.R then
                        recenterRequested = true
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
    local function render(deltaSeconds: number)
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
            focus = AircraftPanRules.recenter(map)
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
        local viewport = camera.ViewportSize
        if viewport.X <= 1 or viewport.Y <= 1 then
            return -- Wait for an actual render viewport before committing projection.
        end
        local input: InputFrame
        if inputProvider then
            input = inputProvider(viewport)
        else
            input = sampleInput(viewport)
        end
        if input.weapon then
            selectWeapon(input.weapon)
        end
        local pointerValid = Validation.isFinite(input.position.X)
            and Validation.isFinite(input.position.Y)
            and input.position.X >= 0
            and input.position.X <= viewport.X
            and input.position.Y >= 0
            and input.position.Y <= viewport.Y
        local pointer = if pointerValid then input.position else viewport * 0.5
        local blocked = input.blocked or not pointerValid
        if recenterRequested or input.recenter == true then
            focus = AircraftPanRules.recenter(map)
            recenterRequested = false
        else
            focus = AircraftPanRules.step(
                map,
                focus,
                hitbox.Position.X,
                hitbox.Position.Z,
                pointer.X / viewport.X,
                pointer.Y / viewport.Y,
                deltaSeconds,
                blocked
            ) or focus
        end
        local cameraFocus = Vector3.new(focus.x, map.groundY, focus.z)
        local cameraFrame = ThermalCameraController.frame(hitbox.Position, cameraFocus)
        assert(cameraFrame, "canonical aircraft and bounded focus must define a finite inward basis")
        camera.CameraType = Enum.CameraType.Scriptable
        camera.CFrame = cameraFrame
        camera.FieldOfView = fov
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        UserInputService.MouseIconEnabled = false
        local mouse = pointer
        -- Raw edge input drives focus; only the displayed reticle is central-70%.
        local pixels = AircraftPanRules.raster(mouse.X, mouse.Y, viewport.X, viewport.Y)
        assert(pixels, "finite viewport and pointer must define raster reticle pixels")
        local x, y = pixels.x, pixels.y
        local ray = camera:ViewportPointToRay(x, y)
        local parameters = RaycastParams.new()
        parameters.FilterType = Enum.RaycastFilterType.Include
        parameters.RespectCanCollide = true
        local world = workspace:FindFirstChild("World")
        local battlefield = if world then world:FindFirstChild("Battlefield") else nil
        parameters.FilterDescendantsInstances = if battlefield
            then { battlefield, workspace.Terrain }
            else { workspace.Terrain }
        local hit = workspace:Raycast(ray.Origin, ray.Direction * 1500, parameters)
        local endpoint = if hit then hit.Position else ray.Origin + ray.Direction * 1500
        local minimum = state:GetAttribute("AimMinimumY")
        local maximum = state:GetAttribute("AimMaximumY")
        local validAim = hit ~= nil
            and AircraftRules.aimAllowed(
                map,
                endpoint.X,
                endpoint.Y,
                endpoint.Z,
                if type(minimum) == "number" then minimum else nil,
                if type(maximum) == "number" then maximum else nil
            )
        frameNumber += 1
        local cross = reticle
        local caption = label
        local screen = gui
        if cross and caption and screen then
            cross.Position = UDim2.fromOffset(x, y)
            cross.TextColor3 = if validAim then Color3.new(1, 1, 1) else Color3.fromRGB(255, 140, 90)
            caption.Text = (if preview then "Studio preview • " else "")
                .. AircraftRules.names[weapon]
                .. string.format(
                    " • %d° FOV\nMouse edges pan • R recenter • 1 / 2 select • Firing is planned",
                    fov
                )
            -- Observable projection commit used by engine tests and accessibility tooling.
            screen:SetAttribute("Weapon", weapon)
            screen:SetAttribute("FOV", fov)
            screen:SetAttribute("AimAllowed", validAim)
            screen:SetAttribute("AimEndpoint", endpoint)
            screen:SetAttribute("ReticlePixels", Vector2.new(x, y))
            screen:SetAttribute("PanFocus", cameraFocus)
            screen:SetAttribute("RawPointer", mouse)
            screen:SetAttribute("InputBlocked", blocked)
            screen:SetAttribute("ProjectionViewport", viewport)
            screen:SetAttribute("ProjectionFrame", frameNumber)
            screen:SetAttribute("ProjectionTime", os.clock())
            screen:SetAttribute("ProjectionCamera", camera.CFrame)
            screen:SetAttribute("ProjectionHit", if hit then hit.Instance:GetFullName() else "")
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
    local focused = UserInputService.WindowFocused:Connect(function()
        windowFocused = true
    end)
    local unfocused = UserInputService.WindowFocusReleased:Connect(function()
        windowFocused = false
    end)
    render(0)
    return {
        ownsCamera = eligible,
        stop = function()
            if not running then
                return
            end
            running = false
            connection:Disconnect()
            focused:Disconnect()
            unfocused:Disconnect()
            leave()
        end,
    }
end
return ThermalCameraController
