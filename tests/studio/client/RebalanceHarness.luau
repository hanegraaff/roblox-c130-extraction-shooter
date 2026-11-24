--!strict
-- P18 actual-client observations and ordinary launcher intents. The test mapping
-- alone supplies this transport. Camera probes replace one production owner
-- through its teardown and reuse its public input boundary; native input and
-- rendered contrast review are recorded separately from injected-axis checks.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Harness = {}
type Record = { [string]: unknown }
type AircraftFacts = {
    opacity: number,
    canQuery: boolean,
    canCollide: boolean,
    canTouch: boolean,
    anchored: boolean,
}
local function waitFor(predicate: () -> boolean, label: string, seconds: number?)
    local untilTime = os.clock() + (seconds or 15)
    repeat
        if predicate() then
            return
        end
        task.wait()
    until os.clock() >= untilTime
    error("P18 client timeout: " .. label)
end
-- Starts one asynchronous actual-client listener after smoke tests. It yields
-- only in the spawned bounded readiness/probe tasks. The existing client owner
-- is torn down before the production RoundPanel is replaced for this session.
-- Cleanup stops that panel and disconnects the listener; failed probes reply
-- with their error text, never an invented success or swallowed assertion.
function Harness.run()
    task.spawn(function()
        local remote = ReplicatedStorage:WaitForChild("P18Harness", 120)
        assert(remote and remote:IsA("RemoteEvent"), "P18 transport missing")
        local player = Players.LocalPlayer
        local entry = player.PlayerScripts:FindFirstChild("Client")
        assert(entry, "production client missing")
        local Panel = require(player.PlayerScripts.Client.RoundPanel)
        local Camera = require(player.PlayerScripts.Client.ThermalCameraController)
        local Map = require(ReplicatedStorage.Shared.MapRules)
        local Pan = require(ReplicatedStorage.Shared.AircraftPanRules)
        entry:Destroy()
        local round = ReplicatedStorage:WaitForChild("RoundState", 30)
        assert(round, "round state missing")
        local initialAircraft = workspace:WaitForChild("Aircraft", 15)
        assert(
            initialAircraft and initialAircraft:IsA("Model"),
            "canonical aircraft missing before deployment"
        )
        local aircraftBaseline: { [BasePart]: AircraftFacts } = {}
        for _, part in initialAircraft:GetDescendants() do
            if part:IsA("BasePart") then
                aircraftBaseline[part] = {
                    opacity = part.LocalTransparencyModifier,
                    canQuery = part.CanQuery,
                    canCollide = part.CanCollide,
                    canTouch = part.CanTouch,
                    anchored = part.Anchored,
                }
            end
        end
        local function aircraftMask(hidden: boolean): number
            local current = workspace:FindFirstChild("Aircraft")
            assert(current and current:IsA("Model"), "canonical aircraft missing during opacity probe")
            local visibleParts = 0
            for _, part in current:GetDescendants() do
                if part:IsA("BasePart") then
                    local baseline = aircraftBaseline[part]
                    local original = if baseline then baseline.opacity else 0
                    assert(
                        part.LocalTransparencyModifier == (if hidden then 1 else original),
                        "operator/Ground aircraft opacity mismatch"
                    )
                    if baseline then
                        assert(
                            part.CanQuery == baseline.canQuery
                                and part.CanCollide == baseline.canCollide
                                and part.CanTouch == baseline.canTouch
                                and part.Anchored == baseline.anchored,
                            "local aircraft mask changed collision/query/physics authority"
                        )
                    end
                    if part.Transparency < 1 then
                        visibleParts += 1
                    end
                end
            end
            assert(visibleParts > 0, "aircraft opacity probe found no rendered parts")
            return visibleParts
        end
        local axes = Vector2.zero
        local recenter = false
        local function provider(viewport: Vector2): Camera.InputFrame
            local reset = recenter
            recenter = false
            return {
                position = viewport * 0.5,
                blocked = false,
                panRight = axes.X,
                panUp = axes.Y,
                recenter = reset,
            }
        end
        local panel = Panel.new(player, player.PlayerGui, round, provider)
        assert(panel.start(), "P18 assertion: panel.start()")
        local function hud(): ScreenGui?
            local item = player.PlayerGui:FindFirstChild("ThermalHUD")
            return if item and item:IsA("ScreenGui") then item else nil
        end
        local function focus(): Vector2
            local gui = hud()
            local value = if gui then gui:GetAttribute("PanLocalFocus") else nil
            assert(typeof(value) == "Vector2", "thermal focus missing")
            return value
        end
        local function number(fields: Record, key: string): number
            local value = fields[key]
            assert(type(value) == "number", "missing numeric field " .. key)
            return value
        end
        local listener: RBXScriptConnection? = nil
        listener = remote.OnClientEvent:Connect(function(token: number, action: string, payload: unknown)
            local fields = (payload or {}) :: Record
            local detail: Record = {}
            local ok, problem = pcall(function()
                if action == "Observe" then
                    local health, maximum = number(fields, "health"), number(fields, "maximum")
                    waitFor(function()
                        local state = ReplicatedStorage:FindFirstChild("AircraftState")
                        return state ~= nil
                            and state:GetAttribute("Health") == health
                            and state:GetAttribute("MaxHealth") == maximum
                    end, "health replication")
                    detail.health, detail.maximum = health, maximum
                elseif action == "Launcher" then
                    local state = ReplicatedStorage:WaitForChild("LauncherState", 10)
                    assert(state, "launcher state missing")
                    local target = state:FindFirstChild(tostring(fields.action))
                    assert(target and target:IsA("RemoteEvent"), "launcher remote missing")
                    target:FireServer(fields.payload)
                elseif action == "Select" then
                    local state = ReplicatedStorage:WaitForChild("AircraftState", 10)
                    assert(state, "aircraft state missing")
                    local selectionRemote = state:FindFirstChild("SelectWeapon")
                    assert(selectionRemote and selectionRemote:IsA("RemoteEvent"), "selection remote missing")
                    selectionRemote:FireServer(fields)
                    waitFor(function()
                        local encoded = state:GetAttribute("Selection")
                        if type(encoded) ~= "string" then
                            return false
                        end
                        local selected = HttpService:JSONDecode(encoded)
                        return selected.weapon == fields.weapon
                    end, "acknowledged selection")
                elseif action == "EquipLauncher" then
                    local backpack = player:FindFirstChildOfClass("Backpack")
                    local tool = if backpack then backpack:FindFirstChild("Rocket launcher") else nil
                    if not tool and player.Character then
                        tool = player.Character:FindFirstChild("Rocket launcher")
                    end
                    assert(tool and tool:IsA("Tool"), "rocket tool missing")
                    local body = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
                    assert(body, "body missing")
                    body:EquipTool(tool)
                    waitFor(function()
                        return tool.Parent == player.Character
                    end, "launcher equip")
                elseif action == "Panel" then
                    local id, expected = tostring(fields.id), tostring(fields.appearance)
                    waitFor(function()
                        local model = workspace.World.Battlefield:FindFirstChild(id, true)
                        return model ~= nil and model:GetAttribute("DamageAppearance") == expected
                    end, "panel replication " .. id)
                    local model = assert(
                        workspace.World.Battlefield:FindFirstChild(id, true),
                        "P18 assertion: workspace.World.Battlefield:FindFirstChild(id, true)"
                    )
                    if expected == "Total" then
                        for _, part in model:GetDescendants() do
                            assert(
                                not (part:IsA("BasePart") and part.CanCollide),
                                "Total replicated residual collider"
                            )
                        end
                    end
                    detail.id, detail.appearance = id, expected
                elseif action == "Camera" then
                    waitFor(function()
                        return hud() ~= nil
                    end, "operator camera")
                    recenter = true
                    RunService.RenderStepped:Wait()
                    RunService.RenderStepped:Wait()
                    local start = focus()
                    axes = Vector2.new(number(fields, "right"), number(fields, "up"))
                    local began = os.clock()
                    repeat
                        RunService.RenderStepped:Wait()
                    until os.clock() - began >= number(fields, "seconds")
                    axes = Vector2.zero
                    local finish = focus()
                    assert((finish - start).Magnitude > 1, "camera directional hold did not move")
                    assert(math.abs(finish.X) <= 360 and math.abs(finish.Y) <= 360, "camera left square")
                    detail.start = { start.X, start.Y }
                    detail.finish = { finish.X, finish.Y }
                    detail.fov =
                        assert(workspace.CurrentCamera, "P18 assertion: workspace.CurrentCamera").FieldOfView
                elseif action == "SquareFrames" then
                    local samples = 0
                    local lowestUp = 1
                    for phase = 0, 72 do
                        local x, y, z = Map.orbit(Map.defaults, phase * math.pi / 36)
                        local position = Vector3.new(x, y, z)
                        for _, point in
                            {
                                Vector3.new(-360, 0, -360),
                                Vector3.new(360, 0, 360),
                                Vector3.new(-360, 0, 360),
                                Vector3.new(360, 0, -360),
                                Vector3.new(x, 0, z),
                                Vector3.new(0, 0, 360),
                                Vector3.new(-360, 0, 300),
                                Vector3.new(-359, 0, 360),
                                Vector3.new(360, 0, 0),
                                Vector3.new(0, 0, -360),
                            }
                        do
                            local frame =
                                assert(Camera.frame(position, point), "square/overhead frame rejected")
                            local components = { frame:GetComponents() }
                            for _, value in components do
                                assert(value == value and math.abs(value) < math.huge, "nonfinite camera")
                            end
                            assert(
                                (frame.Position - position).Magnitude < 1e-5,
                                "camera changed aircraft origin"
                            )
                            local world = assert(
                                Pan.worldFocus(Map.defaults, { x = point.X, z = point.Z }, x, z),
                                "P18 assertion: Pan.worldFocus(Map.defaults, { x = point.X, z = point.Z }, x, z)"
                            )
                            assert(world.x == point.X and world.z == point.Z, "held focus rotated")
                            for _, axis in
                                {
                                    Vector2.new(-1, 0),
                                    Vector2.new(1, 0),
                                    Vector2.new(0, -1),
                                    Vector2.new(0, 1),
                                }
                            do
                                local nextFocus = assert(
                                    Pan.step(
                                        Map.defaults,
                                        { x = point.X, z = point.Z },
                                        axis.X,
                                        axis.Y,
                                        0.1,
                                        false,
                                        16 / 9,
                                        40,
                                        x,
                                        z
                                    ),
                                    "native edge step rejected"
                                )
                                local movement = Vector3.new(nextFocus.x - point.X, 0, nextFocus.z - point.Z)
                                local signed = movement:Dot(frame.RightVector) * axis.X
                                    + movement:Dot(frame.UpVector) * axis.Y
                                assert(signed >= -1e-5, "native projected key direction reversed")
                                assert(movement.Magnitude <= 12.0001, "native edge step exceeded speed cap")
                            end
                            lowestUp = math.min(lowestUp, frame.UpVector.Y)
                            samples += 1
                        end
                        if phase % 12 == 0 then
                            task.wait()
                        end
                    end
                    detail.samples, detail.minimumUpY = samples, lowestUp
                elseif action == "AircraftMask" then
                    assert(type(fields.hidden) == "boolean", "aircraft opacity expectation missing")
                    local hidden = fields.hidden
                    waitFor(function()
                        return (hud() ~= nil) == hidden
                    end, "role camera opacity readiness")
                    detail.aircraftParts = aircraftMask(hidden)
                    detail.hidden = hidden
                elseif action == "Thermal" then
                    waitFor(function()
                        return hud() ~= nil
                    end, "thermal view")
                    local camera = assert(workspace.CurrentCamera, "P18 assertion: workspace.CurrentCamera")
                    local effect = camera:FindFirstChild("OperatorThermal")
                    assert(
                        effect
                            and effect:IsA("ColorCorrectionEffect")
                            and effect.Saturation == -1
                            and effect.Brightness < 0,
                        "white-hot view lacks dark monochrome grading"
                    )
                    local count = 0
                    for _, item in camera:GetChildren() do
                        if item:IsA("Highlight") and item.Name == "OperatorThermalTarget" then
                            assert(
                                item.FillColor == Color3.new(1, 1, 1)
                                    and item.OutlineColor == Color3.new(1, 1, 1)
                                    and item.FillTransparency <= 0.1,
                                "target is not white-hot against the dark monochrome view"
                            )
                            assert(
                                item.DepthMode == Enum.HighlightDepthMode.Occluded,
                                "highlight bypasses cover"
                            )
                            count += 1
                        end
                    end
                    assert(count == 2, "expected two live Ground highlights")
                    local background = camera:FindFirstChild("OperatorGroundBackdrop")
                    assert(background and background:IsA("BasePart"), "operator ground backdrop missing")
                    assert(
                        math.max(background.Color.R, background.Color.G, background.Color.B) < 0.25,
                        "outside-level ground backdrop remained bright"
                    )
                    assert(
                        not background.CanCollide and not background.CanQuery and not background.CanTouch,
                        "operator ground backdrop changed combat geometry"
                    )
                    local sand = workspace.Terrain:GetMaterialColor(Enum.Material.Sand)
                    assert(math.max(sand.R, sand.G, sand.B) < 0.45, "terrain remained bright")
                    detail.targets = count
                    detail.palette = "white-hot"
                    detail.grading = {
                        saturation = effect.Saturation,
                        brightness = effect.Brightness,
                        contrast = effect.Contrast,
                    }
                    detail.backdrop = { background.Color.R, background.Color.G, background.Color.B }
                    detail.sand = { sand.R, sand.G, sand.B }
                    detail.hiddenAircraftParts = aircraftMask(true)
                    local controls = player.PlayerGui:FindFirstChild("OperatorTouchControls")
                    if controls then
                        local recenterButton = controls:FindFirstChild("Recenter")
                        assert(recenterButton and recenterButton:IsA("TextButton"), "touch Recenter missing")
                        local point = recenterButton.AbsolutePosition + recenterButton.AbsoluteSize * 0.5
                        local top: GuiObject? = nil
                        for _, object in
                            player.PlayerGui:GetGuiObjectsAtPosition(math.floor(point.X), math.floor(point.Y))
                        do
                            if object:IsA("GuiButton") or object:IsA("TextBox") or object.Active then
                                top = object
                                break
                            end
                        end
                        assert(
                            point.X >= 0 and point.Y >= 0 and top == recenterButton,
                            "actual operator Recenter center is unreachable or covered by another GUI"
                        )
                        local inset = game:GetService("GuiService"):GetGuiInset()
                        local position, size = recenterButton.AbsolutePosition, recenterButton.AbsoluteSize
                        assert(
                            position.X >= 0
                                and position.Y >= 0
                                and position.X + size.X + math.max(0, inset.X) <= camera.ViewportSize.X
                                and position.Y + size.Y + math.max(0, inset.Y) <= camera.ViewportSize.Y,
                            "actual operator Recenter is clipped"
                        )
                        detail.recenter = {
                            x = position.X,
                            y = position.Y,
                            width = size.X,
                            height = size.Y,
                            centerReachable = true,
                        }
                    end
                elseif action == "Cleanup" then
                    axes = Vector2.zero
                    panel.stop()
                    panel.stop()
                    assert(not hud(), "thermal GUI leaked")
                    local camera = workspace.CurrentCamera
                    assert(
                        not camera or not camera:FindFirstChild("OperatorThermal"),
                        "thermal effect leaked"
                    )
                    assert(
                        not camera or not camera:FindFirstChild("OperatorGroundBackdrop"),
                        "operator backdrop leaked"
                    )
                    detail.restoredAircraftParts = aircraftMask(false)
                    if listener then
                        listener:Disconnect()
                    end
                    detail.cleanup = true
                else
                    error("unknown P18 command " .. action)
                end
            end)
            remote:FireServer(token, ok, if ok then HttpService:JSONEncode(detail) else tostring(problem))
        end)
        local smoke = script.Parent:GetAttribute("ClientTestReport")
        remote:FireServer(0, true, smoke)
    end)
end
return Harness
