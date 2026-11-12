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
local PanRules = require(ReplicatedStorage.Shared.AircraftPanRules)
local AircraftRules = require(ReplicatedStorage.Shared.AircraftRules)
local Harness = {}
type Request = {
    kind: string,
    point: Vector3?,
    building: string?,
    category: string?,
    weapon: string?,
    position: Vector3?,
    payload: unknown?,
    startTime: number?,
    duration: number?,
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
        local aimRequest: Request? = nil
        local pointingFrameBefore: number? = nil
        local pointingPixels: Vector2? = nil
        local pointingSearch: { [string]: unknown } = {}
        local arrivalErrorStuds = 0
        local function visible(point: Vector3): boolean
            local camera = workspace.CurrentCamera
            if not camera then
                return false
            end
            local projection = camera:WorldToViewportPoint(point)
            local viewport = camera.ViewportSize
            return projection.Z > 0
                and projection.X >= viewport.X * 0.17
                and projection.X <= viewport.X * 0.83
                and projection.Y >= viewport.Y * 0.17
                and projection.Y <= viewport.Y * 0.83
        end
        local pendingWeapon: string? = nil
        local recenter = false
        local forcedBlocked = false
        local forcedPan: Vector2? = nil
        local physical = false
        local outside = false
        local function hud(): ScreenGui?
            local result = playerGui:FindFirstChild("ThermalHUD")
            return if result and result:IsA("ScreenGui") then result else nil
        end
        local function provider(viewport: Vector2)
            local pointer = viewport * 0.5
            local pan = forcedPan or Vector2.zero
            local current = hud()
            if physical then
                pointer = Input:GetMouseLocation()
            elseif outside then
                pointer = Vector2.new(viewport.X + 100, viewport.Y * 0.5)
            elseif goal and current then
                local focus = current:GetAttribute("PanLocalFocus")
                local aircraft = workspace:FindFirstChild("Aircraft")
                local root = if aircraft then aircraft:FindFirstChild("Hitbox") else nil
                if typeof(focus) == "Vector2" and root and root:IsA("BasePart") then
                    if not visible(goal) then
                        local radial = Vector2.new(root.Position.X, root.Position.Z).Unit
                        local localX = radial.X * goal.X + radial.Y * goal.Z
                        local localZ = -radial.Y * goal.X + radial.X * goal.Z
                        pan = Vector2.new(
                            math.clamp((focus.Y - localZ) / 6, -1, 1),
                            math.clamp((focus.X - localX) / 6, -1, 1)
                        )
                    end
                end
            elseif aimPoint and current and workspace.CurrentCamera then
                -- The pointer is sampled before the production controller commits
                -- this render's camera. Predict target pixels from the current
                -- canonical origin and held focus, rather than the previous frame's
                -- camera (which can be several studs old on a slow Studio client).
                local aircraft = workspace:FindFirstChild("Aircraft")
                local root = if aircraft then aircraft:FindFirstChild("Hitbox") else nil
                local heldFocus = current:GetAttribute("PanLocalFocus")
                assert(
                    root and root:IsA("BasePart") and typeof(heldFocus) == "Vector2",
                    "pointing geometry missing"
                )
                local worldFocus = PanRules.worldFocus(
                    MapRules.defaults,
                    { x = heldFocus.X, z = heldFocus.Y },
                    root.Position.X,
                    root.Position.Z
                )
                assert(worldFocus, "pointing orbit focus rejected")
                local nextFrame = CameraController.frame(
                    root.Position,
                    Vector3.new(worldFocus.x, MapRules.defaults.groundY, worldFocus.z)
                )
                assert(nextFrame, "pointing camera basis rejected")
                local relative = nextFrame:PointToObjectSpace(aimPoint)
                assert(relative.Z < 0, "pointing target is behind the camera")
                local vertical = math.tan(math.rad(workspace.CurrentCamera.FieldOfView) / 2)
                local scale = viewport.Y / (-2 * relative.Z * vertical)
                pointer =
                    Vector2.new(viewport.X * 0.5 + relative.X * scale, viewport.Y * 0.5 - relative.Y * scale)
                -- The exact projected point may fall between pixels at the
                -- silhouette of a voxel slope or panel. Search a small, bounded
                -- integer neighborhood using the predicted next camera. Only a
                -- real first hit on the required surface within the unchanged
                -- three-stud target tolerance is eligible; the production
                -- controller still performs its own rasterization and raycast.
                local raster = PanRules.raster(pointer.X, pointer.Y, viewport.X, viewport.Y)
                local parameters = RaycastParams.new()
                parameters.FilterType = Enum.RaycastFilterType.Include
                parameters.FilterDescendantsInstances = { workspace.World.Battlefield, workspace.Terrain }
                parameters.RespectCanCollide = true
                local selected: Vector2? = nil
                local tested = 0
                local identityHits = 0
                local nearestDistance = math.huge
                local lastHit = "no hit"
                if raster then
                    for radius = 0, 3 do
                        for dx = -radius, radius do
                            for dy = -radius, radius do
                                if math.max(math.abs(dx), math.abs(dy)) == radius then
                                    local px, py = raster.x + dx, raster.y + dy
                                    local bounded = PanRules.raster(px, py, viewport.X, viewport.Y)
                                    if bounded and bounded.x == px and bounded.y == py then
                                        local horizontal = (2 * px / viewport.X - 1)
                                            * (viewport.X / viewport.Y)
                                            * vertical
                                        local height = (1 - 2 * py / viewport.Y) * vertical
                                        local direction = (
                                            nextFrame.LookVector
                                            + nextFrame.RightVector * horizontal
                                            + nextFrame.UpVector * height
                                        ).Unit
                                        local hit = workspace:Raycast(
                                            nextFrame.Position,
                                            direction * 1500,
                                            parameters
                                        )
                                        tested += 1
                                        if hit then
                                            lastHit = hit.Instance:GetFullName()
                                            local correct = true
                                            if aimRequest and aimRequest.category == "TerrainSlope" then
                                                correct = hit.Instance == workspace.Terrain
                                                    and hit.Position.Y > 0.5
                                                    and hit.Normal.Y < 0.999
                                            elseif aimRequest and aimRequest.building then
                                                local building =
                                                    workspace.World.Battlefield.Buildings:FindFirstChild(
                                                        aimRequest.building
                                                    )
                                                correct = building ~= nil
                                                    and hit.Instance:IsDescendantOf(building)
                                                    and hit.Instance:GetAttribute("StoryId") == "02"
                                                    and type(hit.Instance:GetAttribute("PanelId"))
                                                        == "string"
                                            end
                                            if correct then
                                                identityHits += 1
                                                local distance = (hit.Position - aimPoint).Magnitude
                                                nearestDistance = math.min(nearestDistance, distance)
                                                if distance < 2.9 then
                                                    selected = Vector2.new(px, py)
                                                    break
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                            if selected then
                                break
                            end
                        end
                        if selected then
                            break
                        end
                    end
                end
                pointingSearch = {
                    predicted = { pointer.X, pointer.Y },
                    tested = tested,
                    identityHits = identityHits,
                    nearestStuds = if nearestDistance < math.huge then nearestDistance else "none",
                    lastHit = lastHit,
                    selected = if selected then { selected.X, selected.Y } else "none",
                }
                local previousFrame = current:GetAttribute("ProjectionFrame")
                pointingFrameBefore = if selected and type(previousFrame) == "number"
                    then previousFrame
                    else nil
                pointingPixels = selected
                if selected then
                    pointer = selected
                end
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
        local function localFocus(): Vector2
            local current = hud()
            local value = if current then current:GetAttribute("PanLocalFocus") else nil
            assert(typeof(value) == "Vector2", "orbit-local pan focus missing")
            return value
        end
        local function resetFocus(): Vector2
            local camera = workspace.CurrentCamera
            assert(camera, "camera unavailable for reset view")
            local aspect = camera.ViewportSize.X / camera.ViewportSize.Y
            local widest = PanRules.supportedFov(MapRules.defaults, aspect, AircraftRules.defaults.fov105mm)
            assert(widest, "reset lens unavailable")
            local home = PanRules.recenter(MapRules.defaults, aspect, widest)
            assert(home, "reset view unavailable")
            return Vector2.new(home.x, home.z)
        end
        -- Shared server time lets the two independent clients prove their
        -- movement windows overlapped. Every request is bounded and test-only.
        local function movementWindow(request: Request): (number, number)
            local starts, duration = request.startTime, request.duration
            assert(
                type(starts) == "number"
                    and starts == starts
                    and math.abs(starts) < math.huge
                    and type(duration) == "number"
                    and duration >= 1
                    and duration <= 5,
                "invalid movement probe window"
            )
            local now = workspace:GetServerTimeNow()
            assert(starts - now <= 10 and starts + duration > now, "movement probe window expired")
            return starts, starts + duration
        end
        -- Arrival is one consistent input-driven neighborhood. Enter a separate
        -- pointing stage once reached: continuing directional steering after arrival races
        -- the target assertion, especially below 30Hz. No focus is assigned here.
        local function moveTo(point: Vector3, request: Request)
            aimPoint = nil
            aimRequest = nil
            pointingFrameBefore = nil
            pointingPixels = nil
            local destination = Vector3.new(point.X, 0, point.Z)
            goal = point
            waitFor(function()
                return visible(point)
            end, "input-driven target visibility", 12)
            arrivalErrorStuds = (focus() - destination).Magnitude
            local current = hud()
            assert(current, "arrival HUD disappeared")
            local transitionFrame = current:GetAttribute("ProjectionFrame")
            assert(type(transitionFrame) == "number", "arrival frame missing")
            goal = nil -- Stop steering; subsequent input is target pointing only.
            aimPoint = point
            aimRequest = request
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
            end, "committed pointing frame with nearby required surface", 18)
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
            result.localFocus = packed(current:GetAttribute("PanLocalFocus"))
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
            local cornerGround: { unknown } = {}
            for _, corner in
                {
                    Vector2.new(0, 0),
                    Vector2.new(viewport.X, 0),
                    Vector2.new(0, viewport.Y),
                    viewport,
                }
            do
                local cornerRay = camera:ViewportPointToRay(corner.X, corner.Y)
                assert(cornerRay.Direction.Y < -1e-9, "camera corner includes sky")
                local distance = (MapRules.defaults.groundY - cornerRay.Origin.Y) / cornerRay.Direction.Y
                local groundHit = cornerRay.Origin + cornerRay.Direction * distance
                local radius = Vector2.new(
                    groundHit.X - MapRules.defaults.centerX,
                    groundHit.Z - MapRules.defaults.centerZ
                ).Magnitude
                table.insert(cornerGround, { corner.X, corner.Y, radius })
            end
            result.cornerGround = cornerGround
            local innerGround: { unknown } = {}
            for _, point in
                {
                    Vector2.new(viewport.X * 0.25, viewport.Y * 0.5),
                    Vector2.new(viewport.X * 0.75, viewport.Y * 0.5),
                    Vector2.new(viewport.X * 0.5, viewport.Y * 0.25),
                    Vector2.new(viewport.X * 0.5, viewport.Y * 0.75),
                }
            do
                local ray = camera:ViewportPointToRay(point.X, point.Y)
                assert(ray.Direction.Y < -1e-9, "inner view ray includes sky")
                local distance = (MapRules.defaults.groundY - ray.Origin.Y) / ray.Direction.Y
                local groundHit = ray.Origin + ray.Direction * distance
                local radius = Vector2.new(
                    groundHit.X - MapRules.defaults.centerX,
                    groundHit.Z - MapRules.defaults.centerZ
                ).Magnitude
                table.insert(innerGround, { point.X, point.Y, radius })
                assert(radius <= MapRules.defaults.radiusStuds - 1, "inner view escaped level")
            end
            result.innerGround = innerGround
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
                    for _, direction in { { 0, 0 }, { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
                        local held =
                            PanRules.recenter(MapRules.defaults, 16 / 9, AircraftRules.defaults.fov105mm)
                        assert(held, "safe orbit view unavailable")
                        for _ = 1, 180 do
                            held = PanRules.step(
                                MapRules.defaults,
                                held,
                                direction[1],
                                direction[2],
                                0.1,
                                false,
                                16 / 9,
                                AircraftRules.defaults.fov105mm
                            ) or held
                        end
                        local baselineLook: Vector3? = nil
                        local baselineRight: Vector3? = nil
                        for i = 0, 64 do
                            local phase = i / 64 * 2 * math.pi
                            local x, y, z = MapRules.orbit(MapRules.defaults, phase)
                            local origin = Vector3.new(x, y, z)
                            local point = PanRules.worldFocus(MapRules.defaults, held, x, z)
                            assert(point, "orbit-local focus transformation rejected")
                            local target = Vector3.new(point.x, MapRules.defaults.groundY, point.z)
                            local frame = CameraController.frame(origin, target)
                            assert(frame, "bounded orbit view frame rejected")
                            for _, value in { frame:GetComponents() } do
                                assert(
                                    value == value and math.abs(value) < math.huge,
                                    "nonfinite camera frame"
                                )
                            end
                            assert(
                                (frame.Position - origin).Magnitude < 0.001,
                                "camera origin moved from aircraft"
                            )
                            assert(
                                frame.LookVector:Dot((target - origin).Unit) > 0.99999,
                                "held view rotated"
                            )
                            if direction[1] == 0 and direction[2] == 0 then
                                -- Actual engine camera-right, not a copied sign
                                -- convention, decides what left/right means.
                                for _, horizontalInput in { -1, 1 } do
                                    local moved = PanRules.step(
                                        MapRules.defaults,
                                        held,
                                        horizontalInput,
                                        0,
                                        0.1,
                                        false,
                                        16 / 9,
                                        AircraftRules.defaults.fov105mm
                                    )
                                    assert(moved, "horizontal direction rejected")
                                    local movedPoint = PanRules.worldFocus(MapRules.defaults, moved, x, z)
                                    assert(movedPoint, "horizontal orbit focus rejected")
                                    local movement =
                                        Vector3.new(movedPoint.x - point.x, 0, movedPoint.z - point.z)
                                    assert(
                                        movement:Dot(frame.RightVector) * horizontalInput > 0,
                                        "horizontal direction opposes actual camera right"
                                    )
                                end
                            end
                            local radial = Vector3.new(math.cos(phase), 0, math.sin(phase))
                            local tangent = Vector3.new(-math.sin(phase), 0, math.cos(phase))
                            local localLook = Vector3.new(
                                frame.LookVector:Dot(radial),
                                frame.LookVector.Y,
                                frame.LookVector:Dot(tangent)
                            )
                            local localRight = Vector3.new(
                                frame.RightVector:Dot(radial),
                                frame.RightVector.Y,
                                frame.RightVector:Dot(tangent)
                            )
                            if baselineLook and baselineRight then
                                assert(
                                    (localLook - baselineLook).Magnitude < 1e-5,
                                    "orbit altered held look angle"
                                )
                                assert(
                                    (localRight - baselineRight).Magnitude < 1e-5,
                                    "orbit rolled held view"
                                )
                            else
                                baselineLook = localLook
                                baselineRight = localRight
                            end
                            checked += 1
                        end
                    end
                    observations = { engineFrames = checked, viewInsideLevel = true }
                elseif request.kind == "Projection" then
                    assert(request.point, "projection point missing")
                    if request.weapon then
                        pendingWeapon = request.weapon
                        waitFor(function()
                            local current = hud()
                            return current ~= nil and current:GetAttribute("Weapon") == request.weapon
                        end, "weapon acknowledgement")
                    end
                    moveTo(request.point, request)
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
                elseif request.kind == "PanHold" then
                    local starts, ends = movementWindow(request)
                    goal = nil
                    aimPoint = nil
                    physical = false
                    outside = false
                    forcedBlocked = false
                    recenter = true
                    local okPan, failurePan = pcall(function()
                        waitFor(function()
                            return (localFocus() - resetFocus()).Magnitude < 0.01
                        end, "pan probe recenter", 3)
                        waitFor(function()
                            return workspace:GetServerTimeNow() >= starts
                        end, "pan probe start", 10)
                        local before = localFocus()
                        local started = workspace:GetServerTimeNow()
                        local startHud = hud()
                        assert(startHud, "pan probe HUD disappeared before start")
                        local firstFrame = startHud:GetAttribute("ProjectionFrame")
                        forcedPan = Vector2.new(1, 0)
                        waitFor(function()
                            return workspace:GetServerTimeNow() >= ends
                        end, "pan probe end", 6)
                        forcedPan = nil
                        local stopped = workspace:GetServerTimeNow()
                        local after = localFocus()
                        local current = hud()
                        assert(current, "pan probe HUD disappeared")
                        local lastFrame = current:GetAttribute("ProjectionFrame")
                        local rightMotion = before.Y - after.Y
                        observations = {
                            startTime = started,
                            endTime = stopped,
                            startFocus = { before.X, before.Y },
                            endFocus = { after.X, after.Y },
                            rightMotionStuds = rightMotion,
                            startFrame = firstFrame,
                            endFrame = lastFrame,
                        }
                        assert(rightMotion > 1, "operator did not pan right during the movement window")
                        assert(
                            type(firstFrame) == "number"
                                and type(lastFrame) == "number"
                                and lastFrame > firstFrame,
                            "operator projection did not advance"
                        )
                    end)
                    forcedPan = nil
                    if not okPan then
                        error(failurePan)
                    end
                elseif request.kind == "GroundMove" then
                    local starts, ends = movementWindow(request)
                    assert(not hud(), "ground movement probe received operator HUD")
                    local camera = workspace.CurrentCamera
                    local character = player.Character
                    local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
                    local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
                    assert(
                        camera
                            and camera.CameraType == Enum.CameraType.Custom
                            and humanoid
                            and camera.CameraSubject == humanoid
                            and root
                            and root:IsA("BasePart"),
                        "ground movement probe lacks its own live character camera"
                    )
                    local parameters = RaycastParams.new()
                    parameters.FilterType = Enum.RaycastFilterType.Include
                    parameters.FilterDescendantsInstances = { workspace.World.Battlefield, workspace.Terrain }
                    parameters.RespectCanCollide = true
                    local direction = Vector3.zero
                    local clearance = 0
                    for _, candidate in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
                        local hit = workspace:Raycast(root.Position, candidate * 30, parameters)
                        local free = if hit then hit.Distance else 30
                        if free > clearance then
                            direction, clearance = candidate, free
                        end
                    end
                    assert(clearance > 4, "no clear direction for ground movement")
                    local binding = "P14GroundMove_" .. tostring(player.UserId)
                    local frames, cameraChanged = 0, false
                    local okMove, failureMove = pcall(function()
                        waitFor(function()
                            return workspace:GetServerTimeNow() >= starts
                        end, "ground movement probe start", 10)
                        local before = root.Position
                        local started = workspace:GetServerTimeNow()
                        RunService:BindToRenderStep(binding, Enum.RenderPriority.Input.Value + 1, function()
                            humanoid:Move(direction, false)
                            frames += 1
                            if
                                camera.CameraType ~= Enum.CameraType.Custom
                                or camera.CameraSubject ~= humanoid
                            then
                                cameraChanged = true
                            end
                        end)
                        waitFor(function()
                            return workspace:GetServerTimeNow() >= ends
                        end, "ground movement probe end", 6)
                        RunService:UnbindFromRenderStep(binding)
                        humanoid:Move(Vector3.zero, false)
                        local stopped = workspace:GetServerTimeNow()
                        local after = root.Position
                        local distance = (Vector3.new(after.X, 0, after.Z) - Vector3.new(
                            before.X,
                            0,
                            before.Z
                        )).Magnitude
                        local progress = (after - before):Dot(direction)
                        observations = {
                            startTime = started,
                            endTime = stopped,
                            startPosition = { before.X, before.Y, before.Z },
                            endPosition = { after.X, after.Y, after.Z },
                            direction = { direction.X, direction.Y, direction.Z },
                            clearanceStuds = clearance,
                            displacementStuds = distance,
                            forwardStuds = progress,
                            frames = frames,
                            cameraType = camera.CameraType.Name,
                            cameraSubjectMatches = camera.CameraSubject == humanoid,
                            cameraChanged = cameraChanged,
                        }
                        assert(frames > 0 and distance > 2 and progress > 1, "ground humanoid did not move")
                        assert(
                            not cameraChanged
                                and camera.CameraType == Enum.CameraType.Custom
                                and camera.CameraSubject == humanoid,
                            "operator pan changed ground camera ownership"
                        )
                    end)
                    RunService:UnbindFromRenderStep(binding)
                    humanoid:Move(Vector3.zero, false)
                    if not okMove then
                        error(failureMove)
                    end
                elseif request.kind == "Coherence" then
                    goal = nil
                    aimPoint = nil
                    local previous = localFocus()
                    pendingWeapon = request.weapon
                    waitFor(function()
                        local current = hud()
                        return current ~= nil and current:GetAttribute("Weapon") == request.weapon
                    end, "zoom without recenter")
                    assert((localFocus() - previous).Magnitude < 0.01, "zoom reset pan focus")
                    observations = sample(nil, observations)
                elseif request.kind == "Reject" then
                    goal = nil
                    aimPoint = nil
                    local previous = localFocus()
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
                    assert((localFocus() - previous).Magnitude < 0.01, "rejected selection reset pan")
                    observations = sample(nil, observations)
                elseif request.kind == "Blocked" then
                    local previous = localFocus()
                    aimPoint = nil
                    goal = Vector3.new(300, 0, 300)
                    forcedBlocked = true
                    task.wait(0.25)
                    assert((localFocus() - previous).Magnitude < 0.01, "UI blocked input moved focus")
                    forcedBlocked = false
                    goal = nil
                    outside = true
                    task.wait(0.25)
                    assert((localFocus() - previous).Magnitude < 0.01, "neutral direction moved focus")
                    outside = false
                    recenter = true
                    waitFor(function()
                        return (localFocus() - resetFocus()).Magnitude < 0.01
                    end, "recenter")
                    observations = sample(nil, observations)
                elseif request.kind == "ResetInput" then
                    goal = nil
                    aimPoint = nil
                    recenter = true
                    waitFor(function()
                        return (localFocus() - resetFocus()).Magnitude < 0.01
                    end, "default focus")
                    observations = sample(nil, observations)
                elseif request.kind == "Normal" then
                    waitFor(function()
                        return hud() == nil
                    end, "role-loss view cleanup")
                    local camera = workspace.CurrentCamera
                    assert(camera and camera.CameraType == Enum.CameraType.Custom, "camera remained trapped")
                    assert(not camera:FindFirstChild("OperatorThermal"), "thermal effect leaked")
                    assert(not camera:FindFirstChild("OperatorGroundBackdrop"), "operator backdrop leaked")
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
            if request.kind == "Projection" then
                observations.pointingSearch = pointingSearch
            end
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
