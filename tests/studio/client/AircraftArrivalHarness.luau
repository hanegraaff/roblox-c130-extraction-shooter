--!strict
--[=[
    AircraftArrivalHarness: P24 observations on an actual Studio client.
    Uses the normal round HUD, camera, character and production RemoteEvents.
    The test-only server asks for bounded observations and real local movement.
    Render sampling covers the assignment/reveal gaps between explicit probes.
]=]
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local AircraftArtProbe = require(script.Parent.AircraftArtProbe)
local AircraftArrivalHarness = {}

type Request = { [string]: unknown }
type Trace = { frames: number, leaks: number, thermalFrames: number, aircraftFrames: number }
type PoseFrame = { projectionFrame: number, originErrorStuds: number, replicaErrorStuds: number }
type RevealTrace = {
    deadline: number,
    preDeadlineFrames: number,
    preDeadlineAircraftFrames: number,
    preDeadlineVisibleFrames: number,
    preDeadlineQueryableFrames: number,
    stalePhaseAircraftFrames: number,
    firstAircraftDelaySeconds: number?,
    firstActiveDelaySeconds: number?,
}

local function waitFor(predicate: () -> boolean, label: string)
    local deadline = os.clock() + 5
    while not predicate() and os.clock() < deadline do
        task.wait()
    end
    assert(predicate(), "P24 client timeout: " .. label)
end

-- Starts the actual-client listener after baseline smoke. It owns temporary
-- movement and trace bindings only; production controllers stay running.
function AircraftArrivalHarness.run()
    local transport = ReplicatedStorage:WaitForChild("P24Harness", 90)
    assert(transport and transport:IsA("RemoteEvent"), "P24 harness transport missing")
    local state = ReplicatedStorage:WaitForChild("RoundState", 15)
    assert(state, "round state missing")
    local player = Players.LocalPlayer
    local playerGui = player.PlayerGui
    local traces: { [number]: Trace } = {}
    local poses: { [number]: PoseFrame } = {}
    local revealTraces: { [number]: RevealTrace } = {}
    local function screen(name: string): ScreenGui?
        local item = playerGui:FindFirstChild(name)
        return if item and item:IsA("ScreenGui") then item else nil
    end
    local function frameAndText(): (Frame?, TextLabel?)
        local arrival = screen("AircraftArrival")
        local cover = if arrival and arrival.Enabled then arrival:FindFirstChild("Blackout") else nil
        local text = if cover then cover:FindFirstChild("Countdown") else nil
        return if cover and cover:IsA("Frame") then cover else nil,
            if text and text:IsA("TextLabel") then text else nil
    end
    local function opaque(cover: Frame?): boolean
        local camera = workspace.CurrentCamera
        if not cover or not camera then
            return false
        end
        -- AbsolutePosition uses GUI-content coordinates even for a full-bleed
        -- ScreenGui. Translate its measured rectangle into viewport pixels.
        local origin = cover.AbsolutePosition + GuiService:GetGuiInset()
        local far = origin + cover.AbsoluteSize
        return cover.Visible
            and cover.BackgroundTransparency == 0
            and cover.BackgroundColor3 == Color3.new(0, 0, 0)
            and origin.X <= 1
            and origin.Y <= 1
            and far.X >= camera.ViewportSize.X - 1
            and far.Y >= camera.ViewportSize.Y - 1
    end
    local function sampleReveal()
        local roundId = state:GetAttribute("RoundId")
        local phase = state:GetAttribute("Phase")
        local trace = if type(roundId) == "number" then revealTraces[roundId] else nil
        if not trace or (phase ~= "Scatter" and phase ~= "Active") then
            return
        end
        if trace.firstAircraftDelaySeconds and trace.firstActiveDelaySeconds then
            return
        end
        -- The server commits one deadline. Instance replication and Phase
        -- attributes can arrive in different packets after that deadline.
        local delay = workspace:GetServerTimeNow() - trace.deadline
        local model = workspace:FindFirstChild("Aircraft")
        if delay < 0 then
            trace.preDeadlineFrames += 1
            if model then
                trace.preDeadlineAircraftFrames += 1
                local visible, queryable = false, false
                for _, item in model:GetDescendants() do
                    if item:IsA("BasePart") then
                        visible = visible or (item.Transparency < 1 and item.LocalTransparencyModifier < 1)
                        queryable = queryable or item.CanQuery
                    end
                end
                if visible then
                    trace.preDeadlineVisibleFrames += 1
                end
                if queryable then
                    trace.preDeadlineQueryableFrames += 1
                end
            end
        elseif model and phase == "Scatter" then
            trace.stalePhaseAircraftFrames += 1
        end
        if model and model:GetAttribute("RoundId") == roundId and not trace.firstAircraftDelaySeconds then
            trace.firstAircraftDelaySeconds = delay
        end
        if phase == "Active" and not trace.firstActiveDelaySeconds then
            trace.firstActiveDelaySeconds = delay
        end
    end
    local traceBinding = "P24ArrivalTrace"
    RunService:BindToRenderStep(traceBinding, Enum.RenderPriority.Last.Value + 1, function()
        sampleReveal()
        local assignedRound = player:GetAttribute("OperatorArrivalRoundId")
        if type(assignedRound) ~= "number" then
            return
        end
        local phase = if state:GetAttribute("RoundId") == assignedRound
            then state:GetAttribute("Phase")
            else nil
        if phase == "Active" then
            -- Pair the current Hitbox with the camera on a committed thermal
            -- render frame. A remote probe can arrive between pose and render.
            local thermal = screen("ThermalHUD")
            local frame = if thermal then thermal:GetAttribute("ProjectionFrame") else nil
            local view = if thermal then thermal:GetAttribute("ProjectionCamera") else nil
            local origin = if thermal then thermal:GetAttribute("ProjectionAircraftPosition") else nil
            local camera = workspace.CurrentCamera
            local aircraft = workspace:FindFirstChild("Aircraft")
            local hitbox = if aircraft then aircraft:FindFirstChild("Hitbox") else nil
            local previous = poses[assignedRound]
            if
                type(frame) == "number"
                and (not previous or previous.projectionFrame ~= frame)
                and typeof(view) == "CFrame"
                and typeof(origin) == "Vector3"
                and camera
                and camera.CFrame == view
                and hitbox
                and hitbox:IsA("BasePart")
            then
                poses[assignedRound] = {
                    projectionFrame = frame,
                    originErrorStuds = (camera.CFrame.Position - origin).Magnitude,
                    replicaErrorStuds = (camera.CFrame.Position - hitbox.Position).Magnitude,
                }
            end
            return
        end
        if phase == "Results" or phase == "Resetting" then
            return
        end
        local trace = traces[assignedRound]
        if not trace then
            trace = { frames = 0, leaks = 0, thermalFrames = 0, aircraftFrames = 0 }
            traces[assignedRound] = trace
        end
        trace.frames += 1
        local cover = frameAndText()
        if not opaque(cover) then
            trace.leaks += 1
        end
        local camera = workspace.CurrentCamera
        if screen("ThermalHUD") or (camera and camera:FindFirstChild("OperatorThermal")) then
            trace.thermalFrames += 1
        end
        local reveal = revealTraces[assignedRound]
        if
            reveal
            and phase == "Scatter"
            and workspace:GetServerTimeNow() < reveal.deadline
            and workspace:FindFirstChild("Aircraft")
        then
            trace.aircraftFrames += 1
        end
    end)
    local aircraftArt, releaseArt = AircraftArtProbe.start()
    local movementBinding = "P24ArrivalMovement"
    local function move(direction: Vector3)
        local character = assert(player.Character, "Ground character missing")
        local humanoid = assert(character:FindFirstChildOfClass("Humanoid"), "Ground humanoid missing")
        local root = humanoid.RootPart
        assert(root and not root.Anchored, "Ground body cannot move during Scatter")
        local origin = root.Position
        RunService:BindToRenderStep(movementBinding, Enum.RenderPriority.Input.Value + 1, function()
            humanoid:Move(direction, false)
        end)
        task.wait(0.65)
        RunService:UnbindFromRenderStep(movementBinding)
        humanoid:Move(Vector3.zero, false)
        return (root.Position - origin).Magnitude
    end
    local function scatter(request: Request)
        local role = request.role
        local roundId = request.roundId
        assert(type(roundId) == "number", "missing Scatter round ID")
        local label: TextLabel? = nil
        waitFor(function()
            if
                state:GetAttribute("Phase") ~= "Scatter"
                or state:GetAttribute("RoundId") ~= roundId
                or player:GetAttribute("Role") ~= role
            then
                return false
            end
            if role == "Gunship" then
                local cover, text = frameAndText()
                label = text
                return opaque(cover) and text ~= nil and tonumber(text.Text:match("(%d+)$")) ~= nil
            end
            local hud = screen("RoundHUD")
            local text = if hud then hud:FindFirstChild("Round") else nil
            label = if text and text:IsA("TextLabel") then text else nil
            return hud ~= nil and hud:GetAttribute("View") == "GroundScatter"
        end, "replicated scatter layout")
        local camera = assert(workspace.CurrentCamera, "camera missing")
        local text = assert(label, "countdown label missing")
        local seconds = assert(tonumber(text.Text:match("^C%-130 arrives in (%d+)$")), "bad countdown text")
        local deadline = state:GetAttribute("DeadlineSeconds")
        assert(type(deadline) == "number" and deadline == request.deadline, "client deadline diverged")
        revealTraces[roundId] = {
            deadline = deadline,
            preDeadlineFrames = 0,
            preDeadlineAircraftFrames = 0,
            preDeadlineVisibleFrames = 0,
            preDeadlineQueryableFrames = 0,
            stalePhaseAircraftFrames = 0,
        }
        local remaining = math.max(0, math.ceil(deadline - workspace:GetServerTimeNow()))
        assert(math.abs(seconds - remaining) <= 1, "countdown did not use synchronized server time")
        assert(text.Visible and text.TextFits, "countdown text clipped")
        assert(not workspace:FindFirstChild("Aircraft"), "client saw aircraft before reveal")
        local nearStart = Vector3.new(360, 140, 0)
        assert(
            not workspace:Raycast(nearStart + Vector3.yAxis * 24, -Vector3.yAxis * 48),
            "client ray hit an early aircraft surface"
        )
        assert(
            not screen("ThermalHUD") and not camera:FindFirstChild("OperatorThermal"),
            "operator thermal presentation began during Scatter"
        )
        if role == "Ground" then
            local arrival = screen("AircraftArrival")
            assert(not arrival or not arrival.Enabled, "Ground saw an operator blackout")
            assert(camera.CameraType == Enum.CameraType.Custom, "Ground lost normal camera")
            assert(
                text.Position.X.Scale == 0.5 and text.AnchorPoint.X == 0.5,
                "countdown moved into the native chat lane"
            )
            local hud = assert(screen("RoundHUD"), "round HUD missing")
            assert(not hud:FindFirstChild("Surrender"), "Ground HUD still shows Surrender")
            local ground = assert(screen("GroundCombatHUD"), "Ground HUD missing")
            local fire = ground:FindFirstChild("Fire")
            local reload = ground:FindFirstChild("Reload")
            local reticle = ground:FindFirstChild("Reticle")
            assert(fire and fire:IsA("GuiObject") and not fire.Visible, "pre-arrival touch fire visible")
            assert(reload and reload:IsA("GuiObject") and not reload.Visible, "pre-arrival reload visible")
            assert(
                reticle and reticle:IsA("GuiObject") and not reticle.Visible,
                "pre-arrival aim reticle visible"
            )
        end
        return {
            seconds = seconds,
            deadline = deadline,
            viewport = { camera.ViewportSize.X, camera.ViewportSize.Y },
            touch = UserInputService.TouchEnabled,
        }
    end
    local function active(request: Request): unknown
        local roundId = request.roundId
        assert(type(roundId) == "number", "missing round ID")
        local role = request.role
        waitFor(function()
            local hud = screen("RoundHUD")
            local thermal = screen("ThermalHUD")
            local arrival = screen("AircraftArrival")
            local aircraft = workspace:FindFirstChild("Aircraft")
            return state:GetAttribute("Phase") == "Active"
                and hud ~= nil
                and hud:GetAttribute("View") == (if role == "Gunship" then "Operator" else "Ground")
                and aircraft ~= nil
                and aircraft:GetAttribute("RoundId") == roundId
                and (not arrival or not arrival.Enabled)
                and (role ~= "Gunship" or (thermal ~= nil and poses[roundId] ~= nil))
        end, "matching aircraft, view and released blackout")
        local camera = assert(workspace.CurrentCamera, "camera absent at arrival")
        sampleReveal()
        local reveal = assert(revealTraces[roundId], "client has no observed Scatter deadline")
        local aircraftDelay =
            assert(reveal.firstAircraftDelaySeconds, "client did not observe matching aircraft")
        local activeDelay = assert(reveal.firstActiveDelaySeconds, "client did not observe Active phase")
        assert(
            reveal.preDeadlineFrames > 1
                and reveal.preDeadlineAircraftFrames == 0
                and reveal.preDeadlineVisibleFrames == 0
                and reveal.preDeadlineQueryableFrames == 0
                and aircraftDelay >= 0
                and activeDelay >= 0,
            "aircraft or Active phase arrived before the committed server deadline: "
                .. game:GetService("HttpService"):JSONEncode(reveal)
        )
        if role == "Gunship" then
            assert(camera.CameraType == Enum.CameraType.Scriptable, "operator did not acquire thermal camera")
            local pose = assert(poses[roundId], "matching camera and Hitbox frame missing")
            assert(
                pose.originErrorStuds <= 2 and pose.replicaErrorStuds <= 2,
                string.format(
                    "operator camera deviated %.3f studs from its sampled origin and %.3f studs from the current replica in frame %d",
                    pose.originErrorStuds,
                    pose.replicaErrorStuds,
                    pose.projectionFrame
                )
            )
            assert(camera:FindFirstChild("OperatorThermal"), "thermal correction missing after arrival")
            local trace = assert(traces[roundId], "operator had no pre-arrival render trace")
            assert(
                trace.frames > 1
                    and trace.leaks == 0
                    and trace.thermalFrames == 0
                    and trace.aircraftFrames == 0,
                string.format(
                    "assignment trace had %d frames, %d view leaks, %d early thermal frames, %d early aircraft frames",
                    trace.frames,
                    trace.leaks,
                    trace.thermalFrames,
                    trace.aircraftFrames
                )
            )
            return { blackout = trace, projection = pose, aircraftReveal = reveal }
        end
        assert(camera.CameraType == Enum.CameraType.Custom, "Ground camera changed at reveal")
        assert(not screen("ThermalHUD"), "Ground retained former operator thermal presentation")
        return { ground = true, aircraftReveal = reveal }
    end
    local listener = transport.OnClientEvent:Connect(function(token: number, kind: string, payload: unknown)
        local ok, result = pcall(function(): unknown
            assert(type(payload) == "table", "missing harness request")
            local request = payload :: Request
            if kind == "Scatter" then
                return scatter(request)
            elseif kind == "Active" then
                return active(request)
            elseif kind == "Move" then
                local direction = request.direction
                assert(typeof(direction) == "Vector3", "movement direction missing")
                return move(direction)
            elseif kind == "AircraftArt" then
                return aircraftArt(request)
            elseif kind == "ReleaseAircraftArt" then
                releaseArt()
                return true
            elseif kind == "Intent" then
                local parent = request.parent
                local name = request.remote
                assert(type(parent) == "string" and type(name) == "string", "intent target missing")
                local owner = assert(ReplicatedStorage:FindFirstChild(parent), "missing remote owner")
                local remote = owner:FindFirstChild(name)
                assert(remote and remote:IsA("RemoteEvent"), "production intent remote missing")
                remote:FireServer(request.payload)
                return true
            end
            error("unknown P24 probe: " .. kind)
        end)
        transport:FireServer(token, ok, if ok then result else tostring(result))
    end)
    transport.Destroying:Once(function()
        RunService:UnbindFromRenderStep(traceBinding)
        RunService:UnbindFromRenderStep(movementBinding)
        listener:Disconnect()
        releaseArt()
    end)
    waitFor(function()
        return screen("RoundHUD") ~= nil and screen("AircraftArrival") ~= nil
    end, "round presentation ready")
    transport:FireServer(0, true, script.Parent:GetAttribute("ClientTestReport"))
end

return AircraftArrivalHarness
