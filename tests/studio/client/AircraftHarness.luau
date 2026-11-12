--!strict
--[=[
    AircraftHarness: test-only real-client P04 probes. Observes replicated canonical
    aircraft, camera, HUD, effects and real server remote responses. No fake roles or
    authoritative mutations. Listener/discovery is bounded and removed with transport.
]=]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MapRules = require(ReplicatedStorage.Shared.MapRules)
local AircraftRules = require(ReplicatedStorage.Shared.AircraftRules)
local Validation = require(ReplicatedStorage.Shared.Validation)
local AircraftHarness = {}
local RunService = game:GetService("RunService")
type Request = {
    kind: string,
    position: Vector3?,
    snapshotServerTime: number?,
    periodSeconds: number?,
    weapon: string?,
    sequence: number?,
    roundId: number?,
    role: string?,
    payload: unknown?,
}
local function awaitCondition(predicate: () -> boolean, message: string)
    local untilTime = os.clock() + 8
    while not predicate() and os.clock() < untilTime do
        task.wait(0.03)
    end
    assert(predicate(), "client P04 timeout: " .. message)
end

-- Projects one captured server pivot to a synchronized client time. This is
-- test-only: validate the snapshot and bounded age rather than trusting a stale
-- transport payload or changing the real replicated aircraft. The 0.25-second
-- future allowance accommodates small server-clock synchronization differences.
local function predictSnapshot(
    position: unknown,
    snapshotTime: unknown,
    sampleTime: unknown,
    period: unknown
): (Vector3?, number?, string?)
    if typeof(position) ~= "Vector3" then
        return nil, nil, "snapshot position missing"
    end
    for _, value in { position.X, position.Y, position.Z } do
        if not Validation.isFinite(value) then
            return nil, nil, "nonfinite snapshot position"
        end
    end
    if
        type(snapshotTime) ~= "number"
        or not Validation.isFinite(snapshotTime)
        or type(sampleTime) ~= "number"
        or not Validation.isFinite(sampleTime)
        or type(period) ~= "number"
        or not Validation.isFinite(period)
        or period ~= AircraftRules.defaults.periodSeconds
    then
        return nil, nil, "invalid snapshot time or period"
    end
    local age = sampleTime - snapshotTime
    if not Validation.isFinite(age) or age < -0.25 or age > 20 then
        return nil, nil, "snapshot age outside bounded test window"
    end
    local map = MapRules.defaults
    local dx, dz = position.X - map.centerX, position.Z - map.centerZ
    local radius = math.sqrt(dx * dx + dz * dz)
    if
        not Validation.isFinite(radius)
        or math.abs(radius - map.radiusStuds) >= 0.02
        or math.abs(position.Y - (map.groundY + map.altitudeStuds)) >= 0.02
    then
        return nil, nil, "snapshot is not on the canonical orbit"
    end
    local phase = (math.atan2(dz, dx) + age * (2 * math.pi / period)) % (2 * math.pi)
    if not Validation.isFinite(phase) then
        return nil, nil, "nonfinite projected phase"
    end
    return Vector3.new(
        map.centerX + radius * math.cos(phase),
        position.Y,
        map.centerZ + radius * math.sin(phase)
    ),
        phase,
        nil
end

-- Test the time-alignment arithmetic independently of network arrivals.
local function checkSnapshotPrediction()
    local map = MapRules.defaults
    local initial = Vector3.new(map.centerX + map.radiusStuds, map.groundY + map.altitudeStuds, map.centerZ)
    local same, initialPhase = predictSnapshot(initial, 10, 10, 90)
    assert(same and (same - initial).Magnitude < 1e-4 and initialPhase == 0, "initial snapshot changed")
    local angle = math.rad(359)
    local beforeWrap = Vector3.new(
        map.centerX + map.radiusStuds * math.cos(angle),
        map.groundY + map.altitudeStuds,
        map.centerZ + map.radiusStuds * math.sin(angle)
    )
    local wrapped, phase = predictSnapshot(beforeWrap, 10, 11, 90)
    assert(wrapped and phase and math.abs(phase - math.rad(3)) < 1e-6, "snapshot phase did not wrap")
    assert(not predictSnapshot(initial, 0 / 0, 0, 90), "NaN snapshot time accepted")
    assert(not predictSnapshot(initial, 0, math.huge, 90), "infinite sample time accepted")
    assert(not predictSnapshot(initial, 0, 1, math.huge), "infinite period accepted")
    assert(not predictSnapshot(initial, 0, 1, 0), "zero period accepted")
    assert(not predictSnapshot(Vector3.new(math.huge, 140, 0), 0, 1, 90), "nonfinite position accepted")
    assert(not predictSnapshot(Vector3.new(1, 140, 0), 0, 1, 90), "off-orbit snapshot accepted")
    assert(not predictSnapshot(Vector3.new(360, 141, 0), 0, 1, 90), "wrong-altitude snapshot accepted")
    assert(not predictSnapshot(initial, 0, -1, 90), "future snapshot accepted")
    assert(not predictSnapshot(initial, 0, 21, 90), "expired snapshot accepted")
end
-- Installs one owned test listener; returns immediately in ordinary human sessions.
function AircraftHarness.run()
    local initialInput = game:GetService("UserInputService")
    local initialBehavior = initialInput.MouseBehavior
    local initialIcon = initialInput.MouseIconEnabled
    local initialFov = if workspace.CurrentCamera then workspace.CurrentCamera.FieldOfView else 70
    task.spawn(function()
        local transport = ReplicatedStorage:WaitForChild("P04Harness", 120)
        if not transport or not transport:IsA("RemoteEvent") then
            return
        end
        -- Count only while this diagnostic harness owns its real transport.
        local renderedFrames = 0
        local lastRenderSeconds = 0
        local frames = RunService.RenderStepped:Connect(function()
            renderedFrames += 1
            lastRenderSeconds = os.clock()
        end)
        script.Destroying:Once(function()
            frames:Disconnect()
        end)
        local player = Players.LocalPlayer
        local listener: RBXScriptConnection? = nil
        local removal: RBXScriptConnection? = nil
        listener = transport.OnClientEvent:Connect(function(token: number, request: Request)
            local details: { [string]: unknown } = {}
            local ok, failure = pcall(function()
                if request.kind == "Pose" then
                    local snapshot = request.position
                    local snapshotTime = request.snapshotServerTime
                    local period = request.periodSeconds
                    local roundId = request.roundId
                    local validSnapshot = snapshot ~= nil
                        and Validation.isFinite(snapshot.X)
                        and Validation.isFinite(snapshot.Y)
                        and Validation.isFinite(snapshot.Z)
                    details.snapshotPosition = if validSnapshot and snapshot
                        then { snapshot.X, snapshot.Y, snapshot.Z }
                        else tostring(snapshot)
                    details.snapshotServerTime = if type(snapshotTime) == "number"
                            and Validation.isFinite(snapshotTime)
                        then snapshotTime
                        else tostring(snapshotTime)
                    details.periodSeconds = if type(period) == "number" and Validation.isFinite(period)
                        then period
                        else tostring(period)
                    details.expectedRoundId = if type(roundId) == "number"
                            and Validation.isFinite(roundId)
                        then roundId
                        else tostring(roundId)
                    details.expectedRole = request.role or "missing"
                    if validSnapshot and snapshot then
                        details.snapshotPhaseRadians = math.atan2(
                            snapshot.Z - MapRules.defaults.centerZ,
                            snapshot.X - MapRules.defaults.centerX
                        ) % (2 * math.pi)
                    end
                    checkSnapshotPrediction()
                    details.predictionSelfTest = "passed"
                    assert(
                        type(roundId) == "number"
                            and Validation.isFinite(roundId)
                            and roundId >= 0
                            and roundId % 1 == 0,
                        "invalid snapshot round"
                    )
                    local samples = 0
                    local closest = math.huge
                    local capturedPose: CFrame? = nil
                    awaitCondition(function()
                        samples += 1
                        local sampleTime = workspace:GetServerTimeNow()
                        local predicted, phase, reason =
                            predictSnapshot(snapshot, snapshotTime, sampleTime, period)
                        details.sampleCount = samples
                        details.sampleServerTime = sampleTime
                        details.snapshotAgeSeconds = if type(snapshotTime) == "number"
                                and Validation.isFinite(snapshotTime)
                            then sampleTime - snapshotTime
                            else "missing"
                        details.predictionError = reason or "none"
                        assert(
                            predicted and phase,
                            "invalid timestamped orbit snapshot: " .. tostring(reason)
                        )
                        details.predictedPhaseRadians = phase
                        details.predictedPosition = { predicted.X, predicted.Y, predicted.Z }
                        local round = ReplicatedStorage:FindFirstChild("RoundState")
                        local actualRound = if round then round:GetAttribute("RoundId") else nil
                        local actualPhase = if round then round:GetAttribute("Phase") else nil
                        local actualRole = player:GetAttribute("Role")
                        details.actualRoundId = actualRound or "missing"
                        details.actualPhase = actualPhase or "missing"
                        details.actualRole = actualRole or "missing"
                        local model = workspace:FindFirstChild("Aircraft")
                        if not model or not model:IsA("Model") then
                            details.modelPresent = false
                            return false
                        end
                        details.modelPresent = true
                        local actual = model:GetPivot()
                        local position = actual.Position
                        details.position = { position.X, position.Y, position.Z }
                        if
                            not Validation.isFinite(position.X)
                            or not Validation.isFinite(position.Y)
                            or not Validation.isFinite(position.Z)
                        then
                            details.predictionError = "nonfinite replicated position"
                            return false
                        end
                        local distance = (position - predicted).Magnitude
                        closest = math.min(closest, distance)
                        details.poseErrorStuds = distance
                        details.closestPoseErrorStuds = closest
                        capturedPose = actual
                        return actualRound == roundId
                            and actualPhase == "Active"
                            and actualRole == request.role
                            and distance <= 8
                    end, "canonical pose convergence within 8 studs")
                    local model = workspace:FindFirstChild("Aircraft")
                    assert(model and model:IsA("Model"), "replicated aircraft missing")
                    local pose = capturedPose
                    assert(pose, "paired replicated pose missing")
                    assert(
                        math.abs(Vector2.new(pose.X, pose.Z).Magnitude - 360) < 0.02
                            and math.abs(pose.Y - 140) < 0.02,
                        "client perimeter/altitude mismatch"
                    )
                    local tangent = Vector3.new(-pose.Z, 0, pose.X).Unit
                    assert(pose.LookVector:Dot(tangent) > 0.99999, "replicated heading not tangent")
                    assert(
                        workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Battlefield"),
                        "battlefield absent"
                    )
                    if request.role == "Gunship" then
                        local camera = workspace.CurrentCamera
                        assert(
                            camera and camera.CameraType == Enum.CameraType.Scriptable,
                            "operator camera not Scriptable"
                        )
                        assert(
                            camera.CFrame.LookVector:Dot(
                                (
                                    (player.PlayerGui.ThermalHUD:GetAttribute("PanFocus") :: Vector3)
                                    - camera.CFrame.Position
                                ).Unit
                            ) > 0.99999,
                            "camera does not track its bounded panned focus"
                        )
                        assert(
                            (camera.CFrame.Position - pose.Position).Magnitude < 2,
                            "camera origin detached from canonical aircraft"
                        )
                    else
                        assert(
                            not player.PlayerGui:FindFirstChild("ThermalHUD"),
                            "ground received thermal HUD"
                        )
                    end
                    details.position = { pose.X, pose.Y, pose.Z }
                elseif request.kind == "Profile" then
                    local weapon = request.weapon
                    local fov = if weapon == "GAU23" then 30 else 40
                    awaitCondition(function()
                        local gui = player.PlayerGui:FindFirstChild("ThermalHUD")
                        local camera = workspace.CurrentCamera
                        return gui ~= nil
                            and gui:GetAttribute("Weapon") == weapon
                            and gui:GetAttribute("FOV") == fov
                            and camera ~= nil
                            and math.abs(camera.FieldOfView - fov) < 0.01
                    end, "profile/HUD/projection acknowledgement")
                    local gui = player.PlayerGui:FindFirstChild("ThermalHUD")
                    local camera = workspace.CurrentCamera
                    assert(gui and camera, "profile view missing")
                    local hudCount = 0
                    local effectCount = 0
                    for _, child in player.PlayerGui:GetChildren() do
                        if child.Name == "ThermalHUD" then
                            hudCount += 1
                        end
                    end
                    for _, child in camera:GetChildren() do
                        if child.Name == "OperatorThermal" then
                            effectCount += 1
                        end
                    end
                    assert(hudCount == 1 and effectCount == 1, "duplicate thermal controller ownership")
                    local caption = gui:FindFirstChild("Profile")
                    assert(
                        caption
                            and caption:IsA("TextLabel")
                            and string.find(
                                caption.Text,
                                if weapon == "GAU23" then "GAU-23/A" else "M102",
                                1,
                                true
                            ),
                        "profile label disagrees with selection"
                    )
                    assert(
                        camera.CFrame.LookVector:Dot(
                            ((gui:GetAttribute("PanFocus") :: Vector3) - camera.CFrame.Position).Unit
                        ) > 0.99999,
                        "zoom disagrees with bounded panned camera focus"
                    )
                    local pixels = gui:GetAttribute("ReticlePixels")
                    local cross = gui:FindFirstChild("Reticle")
                    -- Capture failures before assertions; no render wait or bound is
                    -- changed by diagnostics. Missing commit metadata stays explicit.
                    details.weapon = weapon
                    details.fov = camera.FieldOfView
                    details.viewport = { camera.ViewportSize.X, camera.ViewportSize.Y }
                    details.guiAbsoluteSize = { gui.AbsoluteSize.X, gui.AbsoluteSize.Y }
                    details.renderedFrames = renderedFrames
                    details.lastRenderSeconds = lastRenderSeconds
                    details.sampleSeconds = os.clock()
                    local round = ReplicatedStorage:FindFirstChild("RoundState")
                    details.phase = if round then tostring(round:GetAttribute("Phase")) else "absent"
                    details.role = tostring(player:GetAttribute("Role"))
                    details.roundId = player:GetAttribute("RoundId")
                    details.life = player:GetAttribute("Life")
                    details.projectionViewport = tostring(gui:GetAttribute("ProjectionViewport"))
                    details.projectionFrame = tostring(gui:GetAttribute("ProjectionFrame"))
                    details.reticlePixels = if typeof(pixels) == "Vector2"
                        then { pixels.X, pixels.Y }
                        else tostring(pixels)
                    if cross and cross:IsA("TextLabel") then
                        details.crossOffset = { cross.Position.X.Offset, cross.Position.Y.Offset }
                        details.crossAbsolutePosition = { cross.AbsolutePosition.X, cross.AbsolutePosition.Y }
                    end
                    assert(typeof(pixels) == "Vector2", "reticle projection missing")
                    assert(
                        pixels.X >= camera.ViewportSize.X * 0.15 - 1
                            and pixels.X <= camera.ViewportSize.X * 0.85 + 1
                            and pixels.Y >= camera.ViewportSize.Y * 0.15 - 1
                            and pixels.Y <= camera.ViewportSize.Y * 0.85 + 1,
                        "reticle escaped view bounds: " .. game:GetService("HttpService"):JSONEncode(details)
                    )
                    assert(
                        cross
                            and cross:IsA("TextLabel")
                            and (Vector2.new(cross.Position.X.Offset, cross.Position.Y.Offset) - pixels).Magnitude
                                < 1,
                        "reticle coordinates disagree"
                    )
                    assert(cross and cross:IsA("TextLabel"), "drawn profile reticle missing")
                    local inset = game:GetService("GuiService"):GetGuiInset()
                    local drawnCenter = cross.AbsolutePosition + cross.AbsoluteSize * 0.5 + inset
                    local drawnError = (drawnCenter - pixels).Magnitude
                    details.drawnPixelError = drawnError
                    details.guiInset = { inset.X, inset.Y }
                    details.drawnCenter = { drawnCenter.X, drawnCenter.Y }
                    assert(drawnError <= 1, "actual drawn reticle centre disagrees with projection pixels")
                    local effect = camera:FindFirstChild("OperatorThermal")
                    assert(
                        effect and effect:IsA("ColorCorrectionEffect") and effect.Saturation == -1,
                        "thermal grayscale missing"
                    )
                    local backdrop = camera:FindFirstChild("OperatorGroundBackdrop")
                    assert(
                        backdrop
                            and backdrop:IsA("BasePart")
                            and not backdrop.CanCollide
                            and not backdrop.CanTouch
                            and not backdrop.CanQuery
                            and not backdrop.CastShadow,
                        "operator backdrop missing or interactive"
                    )
                    assert(backdrop:FindFirstChildOfClass("SpecialMesh"), "operator backdrop mesh missing")
                    details.weapon = weapon
                    details.fov = camera.FieldOfView
                    details.reticlePixels = { pixels.X, pixels.Y }
                elseif request.kind == "Send" then
                    local state = ReplicatedStorage:FindFirstChild("AircraftState")
                    local remote = if state then state:FindFirstChild("SelectWeapon") else nil
                    assert(remote and remote:IsA("RemoteEvent"), "production selection remote missing")
                    local payload = request.payload
                        or {
                            roundId = request.roundId,
                            sequence = request.sequence,
                            weapon = request.weapon,
                        }
                    remote:FireServer(payload)
                elseif request.kind == "Thermal" then
                    awaitCondition(function()
                        local camera = workspace.CurrentCamera
                        return camera ~= nil and #camera:GetChildren() >= 3
                    end, "thermal target highlights")
                    local camera = workspace.CurrentCamera
                    assert(camera, "camera missing")
                    local exposed = false
                    local covered = false
                    local count = 0
                    local targets: { [Instance]: boolean } = {}
                    for _, child in camera:GetChildren() do
                        if child:IsA("Highlight") then
                            count += 1
                            assert(
                                child.DepthMode == Enum.HighlightDepthMode.Occluded
                                    and child.FillTransparency < 1,
                                "thermal target reveals through cover or is invisible"
                            )
                            local target = child.Adornee
                            if target then
                                assert(not targets[target], "duplicate highlight for one target")
                                targets[target] = true
                                exposed = exposed or target.Name == "P04ExposedTarget"
                                covered = covered or target.Name == "P04CoveredTarget"
                            end
                        end
                    end
                    assert(exposed and covered, "thermal fixtures missing their occluded effects")
                    details.highlights = count
                elseif request.kind == "Restored" then
                    awaitCondition(function()
                        local camera = workspace.CurrentCamera
                        return player:GetAttribute("Role") == "Waiting"
                            and not player.PlayerGui:FindFirstChild("ThermalHUD")
                            and camera ~= nil
                            and camera.CameraType == Enum.CameraType.Custom
                            and not camera:FindFirstChild("OperatorThermal")
                            and not camera:FindFirstChild("OperatorGroundBackdrop")
                    end, "role-loss camera/effect restoration")
                    local camera = workspace.CurrentCamera
                    assert(
                        camera and math.abs(camera.FieldOfView - initialFov) < 0.01,
                        "original FOV not restored"
                    )
                    for _, child in camera:GetChildren() do
                        assert(not child:IsA("Highlight"), "thermal highlights leaked on role loss")
                    end
                    assert(
                        initialInput.MouseIconEnabled == initialIcon
                            and initialInput.MouseBehavior == initialBehavior,
                        "mouse icon/behavior not restored"
                    )
                elseif request.kind == "Leave" then
                    assert(
                        game:GetService("StudioTestService"):CanLeaveTest(),
                        "cannot disconnect actual test client"
                    )
                else
                    error("unknown P04 client directive")
                end
            end)
            transport:FireServer(
                token,
                { passed = ok, detail = if ok then "observed" else tostring(failure), observations = details }
            )
            if ok and request.kind == "Leave" then
                task.delay(0.2, function()
                    game:GetService("StudioTestService"):LeaveTest()
                end)
            end
        end)
        removal = transport.AncestryChanged:Connect(function()
            if not transport:IsDescendantOf(ReplicatedStorage) then
                frames:Disconnect()
                if listener then
                    listener:Disconnect()
                end
                if removal then
                    removal:Disconnect()
                end
            end
        end)
        transport:FireServer(0, { passed = true, baseline = script.Parent:GetAttribute("ClientTestReport") })
    end)
end
return AircraftHarness
