--!strict
--[=[
    P14 actual-client fixtures. Replaces the ordinary local entrypoint only inside
    this test session, after invoking its owned teardown, then starts the same
    production RoundPanel with a deterministic pointer/directional-intent boundary.
    No focus setter or replicated camera authority exists. Geometry/camera/rays are
    actual engine queries. Actual MCP mouse/button review is separate wiring evidence.
]=]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Input = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Harness = {}
type Request = {
    kind: string,
    point: Vector3?,
    building: string?,
    category: string?,
    weapon: string?,
    position: Vector3?,
    payload: unknown?,
}
local function waitFor(predicate: () -> boolean, label: string, seconds: number?)
    local deadline = os.clock() + (seconds or 15)
    while not predicate() and os.clock() < deadline do
        task.wait()
    end
    assert(predicate(), "P14 client timeout: " .. label)
end
function Harness.run()
    task.spawn(function()
        local remote = ReplicatedStorage:WaitForChild("P14Harness", 120)
        if not remote or not remote:IsA("RemoteEvent") then
            return
        end
        local player = Players.LocalPlayer
        local playerGui = player.PlayerGui
        local entry = player.PlayerScripts:FindFirstChild("Client")
        assert(entry, "normal client entrypoint missing")
        local Panel = require(game:GetService("Players").LocalPlayer.PlayerScripts.Client.RoundPanel)
        local CameraController =
            require(game:GetService("Players").LocalPlayer.PlayerScripts.Client.ThermalCameraController)
        local MapRules = require(ReplicatedStorage.Shared.MapRules)
        entry:Destroy() -- Existing Destroying cleanup restores state before fixture ownership.
        local goal: Vector3? = nil
        local aimPoint: Vector3? = nil
        local pointingFrameBefore: number? = nil
        local pointingPixels: Vector2? = nil
        local arrivalErrorStuds = 0
        local function arrived(current: Vector3, destination: Vector3): boolean
            return Vector2.new(current.X - destination.X, current.Z - destination.Z).Magnitude <= 0.25
        end
        local pendingWeapon: string? = nil
        local recenter = false
        local forcedBlocked = false
        local physical = false
        local outside = false
        local function hud(): ScreenGui?
            local result = playerGui:FindFirstChild("ThermalHUD")
            return if result and result:IsA("ScreenGui") then result else nil
        end
        local function provider(viewport: Vector2)
            local pointer = viewport * 0.5
            local pan = Vector2.zero
            local current = hud()
            if physical then
                pointer = Input:GetMouseLocation()
            elseif outside then
                pointer = Vector2.new(viewport.X + 100, viewport.Y * 0.5)
            elseif goal and current then
                local focus = current:GetAttribute("PanFocus")
                local aircraft = workspace:FindFirstChild("Aircraft")
                local root = if aircraft then aircraft:FindFirstChild("Hitbox") else nil
                if typeof(focus) == "Vector3" and root and root:IsA("BasePart") then
                    local difference = goal - focus
                    if not arrived(focus, goal) then
                        local radial = Vector2.new(root.Position.X, root.Position.Z).Unit
                        local right = difference.X * radial.Y - difference.Z * radial.X
                        local up = -difference.X * radial.X - difference.Z * radial.Y
                        pan = Vector2.new(math.clamp(right / 6, -1, 1), math.clamp(up / 6, -1, 1))
                    end
                end
            elseif aimPoint and current and workspace.CurrentCamera then
                -- The pointer is sampled before the production controller commits
                -- this render's camera. Predict target pixels from the current
                -- canonical origin and held focus, rather than the previous frame's
                -- camera (which can be several studs old on a slow Studio client).
                local aircraft = workspace:FindFirstChild("Aircraft")
                local root = if aircraft then aircraft:FindFirstChild("Hitbox") else nil
                local heldFocus = current:GetAttribute("PanFocus")
                assert(
                    root and root:IsA("BasePart") and typeof(heldFocus) == "Vector3",
                    "pointing geometry missing"
                )
                local nextFrame = CameraController.frame(root.Position, heldFocus)
                assert(nextFrame, "pointing camera basis rejected")
                local relative = nextFrame:PointToObjectSpace(aimPoint)
                assert(relative.Z < 0, "pointing target is behind the camera")
                local scale = viewport.Y
                    / (-2 * relative.Z * math.tan(math.rad(workspace.CurrentCamera.FieldOfView) / 2))
                pointer =
                    Vector2.new(viewport.X * 0.5 + relative.X * scale, viewport.Y * 0.5 - relative.Y * scale)
                local previousFrame = current:GetAttribute("ProjectionFrame")
                pointingFrameBefore = if type(previousFrame) == "number" then previousFrame else nil
                pointingPixels = pointer
            end
            local weapon = pendingWeapon
            pendingWeapon = nil
            local shouldRecenter = recenter
            recenter = false
            return {
                position = pointer,
                blocked = forcedBlocked,
                panRight = pan.X,
                panUp = pan.Y,
                recenter = shouldRecenter,
                weapon = weapon,
            }
        end
        local panel: { start: () -> (boolean, string?), stop: () -> () }? = nil
        local function attach(state: Instance)
            if state.Name ~= "RoundState" then
                return
            end
            if panel then
                panel.stop()
            end
            local nextPanel = Panel.new(player, playerGui, state, provider)
            assert(nextPanel.start(), "P14 fixture panel failed")
            panel = nextPanel
        end
        local added = ReplicatedStorage.ChildAdded:Connect(attach)
        local removed = ReplicatedStorage.ChildRemoved:Connect(function(state)
            if state.Name == "RoundState" and panel then
                panel.stop()
                panel = nil
            end
        end)
        local state = ReplicatedStorage:FindFirstChild("RoundState")
        if state then
            attach(state)
        end
        local function focus(): Vector3
            local current = hud()
            local value = if current then current:GetAttribute("PanFocus") else nil
            assert(typeof(value) == "Vector3", "panned focus missing")
            return value
        end
        -- Arrival is one consistent input-driven neighborhood. Enter a separate
        -- pointing stage once reached: continuing directional steering after arrival races
        -- the target assertion, especially below 30Hz. No focus is assigned here.
        local function moveTo(point: Vector3)
            aimPoint = nil
            pointingFrameBefore = nil
            pointingPixels = nil
            local destination = Vector3.new(point.X, 0, point.Z)
            goal = destination
            waitFor(function()
                return arrived(focus(), destination)
            end, "input-driven focus", 12)
            arrivalErrorStuds = (focus() - destination).Magnitude
            local current = hud()
            assert(current, "arrival HUD disappeared")
            local transitionFrame = current:GetAttribute("ProjectionFrame")
            assert(type(transitionFrame) == "number", "arrival frame missing")
            goal = nil -- Stop steering; subsequent input is target pointing only.
            aimPoint = point
            waitFor(function()
                local rendered = hud()
                local frame = if rendered then rendered:GetAttribute("ProjectionFrame") else nil
                local raw = if rendered then rendered:GetAttribute("RawPointer") else nil
                return type(frame) == "number"
                    and pointingFrameBefore ~= nil
                    and pointingFrameBefore > transitionFrame
                    and frame > pointingFrameBefore
                    and pointingPixels ~= nil
                    and typeof(raw) == "Vector2"
                    and (raw - pointingPixels).Magnitude < 0.01
            end, "committed pointing frame", 4)
        end
        -- Mutate the caller-owned diagnostics before assertions. Failed samples
        -- must retain actual drawn/content/ray coordinates rather than losing the
        -- snapshot when the function throws before returning.
        local function sample(expected: Request?, diagnostics: { [string]: unknown }?): { [string]: unknown }
            local result: { [string]: unknown } = diagnostics or {}
            local function packed(value: unknown): unknown
                if typeof(value) == "Vector2" then
                    return { value.X, value.Y }
                elseif typeof(value) == "Vector3" then
                    return { value.X, value.Y, value.Z }
                elseif typeof(value) == "CFrame" then
                    return { value:GetComponents() }
                end
                return tostring(value)
            end
            local current = hud()
            local camera = workspace.CurrentCamera
            result.sampleSeconds = os.clock()
            result.hudPresent = current ~= nil
            result.cameraPresent = camera ~= nil
            assert(current and camera, "operator view missing")
            local viewport = current:GetAttribute("ProjectionViewport")
            local pixels = current:GetAttribute("ReticlePixels")
            local endpoint = current:GetAttribute("AimEndpoint")
            local frame = current:GetAttribute("ProjectionCamera")
            result.viewport = packed(viewport)
            result.cameraViewport = packed(camera.ViewportSize)
            result.pixels = packed(pixels)
            result.endpoint = packed(endpoint)
            result.rawPointer = packed(current:GetAttribute("RawPointer"))
            result.focus = packed(current:GetAttribute("PanFocus"))
            result.frame = current:GetAttribute("ProjectionFrame")
            result.projectionTime = current:GetAttribute("ProjectionTime")
            result.projectionCamera = packed(frame)
            result.cameraFrame = packed(camera.CFrame)
            result.guiPosition = packed(current.AbsolutePosition)
            result.guiSize = packed(current.AbsoluteSize)
            result.fov = camera.FieldOfView
            result.weapon = current:GetAttribute("Weapon")
            result.expectedPoint = if expected then packed(expected.point) else "none"
            result.arrivalErrorStuds = arrivalErrorStuds
            result.pointingInputFrame = pointingFrameBefore
            result.pointingCommitted = goal == nil and aimPoint ~= nil
            result.inputBoundary = "injected directional pan and raw aim pointer; production camera/raycast"
            assert(
                typeof(viewport) == "Vector2"
                    and typeof(pixels) == "Vector2"
                    and typeof(endpoint) == "Vector3"
                    and typeof(frame) == "CFrame",
                "projection metadata missing"
            )
            assert((camera.ViewportSize - viewport).Magnitude < 0.01, "viewport changed during sample")
            local cross = current:FindFirstChild("Reticle")
            result.reticlePresent = cross ~= nil
            assert(cross and cross:IsA("TextLabel"), "drawn reticle missing")
            local inset = GuiService:GetGuiInset()
            local contentCenter = cross.AbsolutePosition + cross.AbsoluteSize * 0.5
            local drawnCenter = contentCenter + inset
            local drawnPixelError = (drawnCenter - pixels).Magnitude
            local projected = camera:WorldToViewportPoint(endpoint)
            local pixelError = (Vector2.new(projected.X, projected.Y) - pixels).Magnitude
            result.guiInset = packed(inset)
            result.reticleAbsolutePosition = packed(cross.AbsolutePosition)
            result.reticleAbsoluteSize = packed(cross.AbsoluteSize)
            result.reticleOffset = { cross.Position.X.Offset, cross.Position.Y.Offset }
            result.reticleScale = { cross.Position.X.Scale, cross.Position.Y.Scale }
            result.contentCenter = packed(contentCenter)
            result.drawnCenter = packed(drawnCenter)
            result.drawnPixelError = drawnPixelError
            result.projectedEndpoint = packed(projected)
            result.pixelError = pixelError
            result.targetSurfaceErrorStuds = if expected and expected.point
                then (endpoint - expected.point).Magnitude
                else nil
            local ray = camera:ViewportPointToRay(pixels.X, pixels.Y)
            local parameters = RaycastParams.new()
            parameters.FilterType = Enum.RaycastFilterType.Include
            parameters.FilterDescendantsInstances = { workspace.World.Battlefield, workspace.Terrain }
            parameters.RespectCanCollide = true
            local hit = workspace:Raycast(ray.Origin, ray.Direction * 1500, parameters)
            local worldError = if hit then (hit.Position - endpoint).Magnitude else nil
            result.hit = if hit then hit.Instance:GetFullName() else "no hit"
            result.normal = if hit then packed(hit.Normal) else "no hit"
            result.raySurfaceErrorStuds = worldError
            result.rayOrigin = packed(ray.Origin)
            result.rayDirection = packed(ray.Direction)
            -- Retain all diagnostics above even when any strict comparison fails.
            assert(drawnPixelError <= 1, "drawn reticle centre disagrees with ray pixels")
            assert(pixelError <= 1, "reticle/world pixel error exceeds one pixel")
            assert(hit and worldError and worldError <= 0.5, "geometry ray disagreement")
            if expected and expected.category == "TerrainSlope" then
                assert(
                    hit.Instance == workspace.Terrain and hit.Position.Y > 0.5 and hit.Normal.Y < 0.999,
                    "required terrain slope was not reached"
                )
            end
            if expected and expected.building then
                assert(
                    hit.Instance:GetAttribute("StoryId") == "02"
                        and type(hit.Instance:GetAttribute("PanelId")) == "string",
                    "required upper-floor panel was not reached"
                )
                assert(
                    hit.Instance:IsDescendantOf(workspace.World.Battlefield.Buildings[expected.building]),
                    "projection reached the wrong building"
                )
            end
            local center = focus()
            assert(Vector2.new(center.X, center.Z).Magnitude <= 360.001, "focus escaped disk")
            local radial = Vector3.new(-frame.X, 0, -frame.Z)
            assert(frame.LookVector:Dot(radial) >= -1e-6, "camera looked out of inward half-space")
            local aircraft = workspace.Aircraft:GetPivot()
            result.cameraPosition = packed(frame.Position)
            result.time = os.clock()
            assert(
                (frame.Position - aircraft.Position).Magnitude <= 2,
                "camera moved from canonical aircraft"
            )
            local hudCount, effects = 0, 0
            for _, item in playerGui:GetChildren() do
                if item.Name == "ThermalHUD" then
                    hudCount += 1
                end
            end
            for _, item in camera:GetChildren() do
                if item.Name == "OperatorThermal" then
                    effects += 1
                end
            end
            assert(hudCount == 1 and effects == 1, "duplicate controller effects/HUD")
            return result
        end
        local orbitStats: {
            [string]: {
                first: number,
                last: number,
                frames: number,
                bins: { [number]: boolean },
                minimumInward: number,
                maximumOriginError: number,
            },
        } =
            {}
        local renderStats = RunService.RenderStepped:Connect(function()
            local current = hud()
            local camera = workspace.CurrentCamera
            local aircraft = workspace:FindFirstChild("Aircraft")
            if not current or not camera or not aircraft or not aircraft:IsA("Model") then
                return
            end
            local weapon = current:GetAttribute("Weapon")
            if type(weapon) ~= "string" then
                return
            end
            local now = os.clock()
            local stats = orbitStats[weapon]
            if not stats then
                stats = {
                    first = now,
                    last = now,
                    frames = 0,
                    bins = {},
                    minimumInward = 1,
                    maximumOriginError = 0,
                }
                orbitStats[weapon] = stats
            end
            stats.last = now
            stats.frames += 1
            local position = aircraft:GetPivot().Position
            local angle = math.atan2(position.Z, position.X) % (2 * math.pi)
            stats.bins[math.floor(angle / (2 * math.pi) * 16)] = true
            stats.minimumInward = math.min(
                stats.minimumInward,
                camera.CFrame.LookVector:Dot(Vector3.new(-position.X, 0, -position.Z).Unit)
            )
            stats.maximumOriginError =
                math.max(stats.maximumOriginError, (camera.CFrame.Position - position).Magnitude)
        end)
        local listener = remote.OnClientEvent:Connect(function(token: number, request: Request)
            local observations: { [string]: unknown } = {}
            local ok, failure = pcall(function()
                if request.kind == "EdgeFrames" then
                    local checked = 0
                    for i = 0, 64 do
                        local x, y, z = MapRules.orbit(MapRules.defaults, i / 64 * 2 * math.pi)
                        local origin = Vector3.new(x, y, z)
                        for j = 0, 8 do
                            local angle = j / 8 * 2 * math.pi
                            local target = if j == 8
                                then Vector3.zero
                                else Vector3.new(math.cos(angle) * 360, 0, math.sin(angle) * 360)
                            local frame = CameraController.frame(origin, target)
                            assert(frame, "exact disk-edge frame rejected")
                            for _, value in { frame:GetComponents() } do
                                assert(
                                    value == value and math.abs(value) < math.huge,
                                    "nonfinite edge camera"
                                )
                            end
                            assert((frame.Position - origin).Magnitude < 0.001, "edge camera origin moved")
                            assert(
                                frame.LookVector:Dot((target - origin).Unit) > 0.99999,
                                "edge camera focus changed"
                            )
                            checked += 1
                        end
                    end
                    observations = { engineFrames = checked, exactDiskEdge = true }
                elseif request.kind == "Projection" then
                    assert(request.point, "projection point missing")
                    if request.weapon then
                        pendingWeapon = request.weapon
                        waitFor(function()
                            local current = hud()
                            return current ~= nil and current:GetAttribute("Weapon") == request.weapon
                        end, "weapon acknowledgement")
                    end
                    moveTo(request.point)
                    observations = sample(request, observations)
                    assert(
                        goal == nil and aimPoint ~= nil,
                        "projection sampled while directional steering remained active"
                    )
                    local current = hud()
                    assert(
                        current and current:GetAttribute("AimAllowed") == true,
                        "required combat surface not aimable"
                    )
                    local endpoint = current:GetAttribute("AimEndpoint")
                    assert(
                        typeof(endpoint) == "Vector3" and (endpoint - request.point).Magnitude < 3,
                        "target hidden or reticle clamped away"
                    )
                elseif request.kind == "OrbitSummary" then
                    assert(request.weapon, "orbit weapon missing")
                    local stats = orbitStats[request.weapon]
                    assert(stats, "orbit never observed")
                    local bins = 0
                    for _ in stats.bins do
                        bins += 1
                    end
                    assert(
                        stats.last - stats.first >= 89.5 and bins == 16,
                        "full orbit at selected FOV not observed"
                    )
                    assert(
                        stats.minimumInward >= -1e-6 and stats.maximumOriginError <= 2,
                        "orbit camera drift/inward violation"
                    )
                    observations = {
                        weapon = request.weapon,
                        seconds = stats.last - stats.first,
                        frames = stats.frames,
                        phaseBins = bins,
                        minimumInward = stats.minimumInward,
                        maximumOriginError = stats.maximumOriginError,
                    }
                elseif request.kind == "Thermal" then
                    local camera = workspace.CurrentCamera
                    assert(camera, "camera absent")
                    local targets = workspace.World.Battlefield:FindFirstChild("P14ThermalFixtures")
                    assert(targets, "thermal fixtures missing")
                    local count = 0
                    for _, highlight in camera:GetChildren() do
                        if
                            highlight:IsA("Highlight")
                            and highlight.Adornee
                            and highlight.Adornee:IsDescendantOf(targets)
                        then
                            assert(
                                highlight.DepthMode == Enum.HighlightDepthMode.Occluded,
                                "highlight ignores solid cover"
                            )
                            count += 1
                        end
                    end
                    assert(count == 2, "slope/upper-floor thermal highlights missing")
                    observations = { occludedHighlights = count }
                elseif request.kind == "Ground" then
                    assert(not hud(), "ground client received operator HUD")
                    local camera = workspace.CurrentCamera
                    assert(
                        camera and camera.CameraType == Enum.CameraType.Custom,
                        "operator pan changed ground camera"
                    )
                    local character = player.Character
                    assert(
                        character and camera.CameraSubject == character:FindFirstChildOfClass("Humanoid"),
                        "ground camera subject changed"
                    )
                    observations = {
                        cameraType = camera.CameraType.Name,
                        role = player:GetAttribute("Role"),
                        baseline = script.Parent:GetAttribute("ClientTestReport"),
                    }
                elseif request.kind == "Coherence" then
                    goal = nil
                    aimPoint = nil
                    local previous = focus()
                    pendingWeapon = request.weapon
                    waitFor(function()
                        local current = hud()
                        return current ~= nil and current:GetAttribute("Weapon") == request.weapon
                    end, "zoom without recenter")
                    assert((focus() - previous).Magnitude < 0.01, "zoom reset pan focus")
                    observations = sample(nil, observations)
                elseif request.kind == "Reject" then
                    goal = nil
                    aimPoint = nil
                    local previous = focus()
                    local selection = ReplicatedStorage.AircraftState:GetAttribute("Selection")
                    local remoteSelection =
                        ReplicatedStorage.AircraftState:FindFirstChild("SelectWeapon") :: RemoteEvent
                    remoteSelection:FireServer({
                        roundId = ReplicatedStorage.RoundState:GetAttribute("RoundId"),
                        sequence = -1,
                        weapon = "Unknown",
                    })
                    task.wait(0.25)
                    assert(
                        ReplicatedStorage.AircraftState:GetAttribute("Selection") == selection,
                        "invalid selection changed commit"
                    )
                    assert((focus() - previous).Magnitude < 0.01, "rejected selection reset pan")
                    observations = sample(nil, observations)
                elseif request.kind == "Blocked" then
                    local previous = focus()
                    aimPoint = nil
                    goal = Vector3.new(300, 0, 300)
                    forcedBlocked = true
                    task.wait(0.25)
                    assert((focus() - previous).Magnitude < 0.01, "UI blocked input moved focus")
                    forcedBlocked = false
                    goal = nil
                    outside = true
                    task.wait(0.25)
                    assert((focus() - previous).Magnitude < 0.01, "neutral direction moved focus")
                    outside = false
                    recenter = true
                    waitFor(function()
                        return focus().Magnitude < 0.01
                    end, "recenter")
                    observations = sample(nil, observations)
                elseif request.kind == "ResetInput" then
                    goal = nil
                    aimPoint = nil
                    recenter = true
                    waitFor(function()
                        return focus().Magnitude < 0.01
                    end, "default focus")
                    observations = sample(nil, observations)
                elseif request.kind == "Normal" then
                    waitFor(function()
                        return hud() == nil
                    end, "role-loss view cleanup")
                    local camera = workspace.CurrentCamera
                    assert(camera and camera.CameraType == Enum.CameraType.Custom, "camera remained trapped")
                    assert(not camera:FindFirstChild("OperatorThermal"), "thermal effect leaked")
                    observations = {
                        cameraType = camera.CameraType.Name,
                        mouse = Input.MouseBehavior.Name,
                        icon = Input.MouseIconEnabled,
                    }
                elseif request.kind == "Physical" then
                    goal = nil
                    aimPoint = nil
                    physical = true
                    observations = { physicalInput = true }
                elseif request.kind == "Snapshot" then
                    observations = sample(nil, observations)
                else
                    error("unknown P14 client probe")
                end
            end)
            remote:FireServer(token, {
                passed = ok,
                detail = if ok then "observed" else tostring(failure),
                observations = observations,
            })
        end)
        local ancestry: RBXScriptConnection? = nil
        ancestry = remote.AncestryChanged:Connect(function(_, parent)
            if parent == nil then
                listener:Disconnect()
                added:Disconnect()
                removed:Disconnect()
                renderStats:Disconnect()
                if ancestry then
                    ancestry:Disconnect()
                end
                if panel then
                    panel.stop()
                    panel = nil
                end
            end
        end)
        remote:FireServer(0, { baseline = script.Parent:GetAttribute("ClientTestReport") })
    end)
end
return Harness
