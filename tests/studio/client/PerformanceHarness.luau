--!strict
-- Historical pre-P18 staged fixture. Current entry rejects; use RebalanceHarness.
-- P11 client fixture for real Studio players. Observes replicated game state,
-- forwards only named gameplay intents, and measures bounded render/memory data.
-- A single test-only transport owns the listener and render connection.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local Metrics = require(ReplicatedStorage.P11Metrics)
local Harness = {}
local player = Players.LocalPlayer
local graphics = UserSettings():GetService("UserGameSettings")

type Intent = { owner: string, remote: string, body: { [string]: unknown }, repetitions: number? }
type Check = {
    roundId: number,
    phase: string,
    health: number,
    ownerId: number?,
    launcherState: string,
    weapon: string?,
    resultReason: string?,
    winner: string?,
}
type ImpactFrameProbe = { sample: () -> (), report: () -> { [string]: unknown }, stop: () -> () }

-- Records cue receipt to the first PreRender where the matching local burst
-- can render. This measures scheduling, leaving pixel visibility to clip review.
local function impactFrames(): ImpactFrameProbe
    local state = ReplicatedStorage:FindFirstChild("RoundState")
    local event = if state then state:FindFirstChild("WeaponImpact") else nil
    local pending: { [string]: number } = {}
    local histogram: { number } = { 0, 0, 0 } -- first frame, second frame, later
    local frame, missing, peakBursts, peakTrails = 0, 0, 0, 0
    local listener: RBXScriptConnection? = nil
    if event and event:IsA("RemoteEvent") then
        listener = event.OnClientEvent:Connect(function(weapon: string, _: number, id: string, point: Vector3)
            local camera = workspace.CurrentCamera
            if camera then
                local _, onScreen = camera:WorldToViewportPoint(point)
                if onScreen and (point - camera.CFrame.Position).Magnitude < 400 then
                    pending[weapon .. "/" .. id] = frame
                end
            end
        end)
    end
    return {
        sample = function()
            frame += 1
            local folder = workspace:FindFirstChild("LocalWeaponImpacts")
            local bursts, trails = 0, 0
            if folder then
                for _, part in folder:GetChildren() do
                    if part.Name == "ImpactBurst" then
                        bursts += 1
                        local weapon, id = part:GetAttribute("Weapon"), part:GetAttribute("ShotId")
                        if type(weapon) == "string" and type(id) == "string" then
                            local key = weapon .. "/" .. id
                            local received = pending[key]
                            if received then
                                histogram[math.min(frame - received, 3)] += 1
                                pending[key] = nil
                            end
                        end
                    elseif part.Name == "RocketSmoke" then
                        trails += 1
                    end
                end
            end
            for key, received in pending do
                if frame - received > 8 then
                    pending[key] = nil
                    missing += 1
                end
            end
            peakBursts, peakTrails = math.max(peakBursts, bursts), math.max(peakTrails, trails)
        end,
        report = function()
            return {
                available = event ~= nil,
                readyFrameCounts = histogram,
                missingWithinEightFrames = missing,
                peakBursts = peakBursts,
                peakTrails = peakTrails,
            }
        end,
        stop = function()
            if listener then
                listener:Disconnect()
                listener = nil
            end
            table.clear(pending)
        end,
    }
end
local allowed = {
    AircraftState = { FireWeapon = true, SelectWeapon = true, GroundFire = true, GroundReload = true },
    LauncherState = { Pickup = true, Drop = true, Fire = true },
} :: { [string]: { [string]: boolean } }

local function json(state: Instance, attribute: string): { [string]: unknown }?
    local encoded = state:GetAttribute(attribute)
    return if type(encoded) == "string" then HttpService:JSONDecode(encoded) else nil
end

-- Observe the managed model and local holders after replication settles.
local function panelStage(id: string, appearance: string, clear: boolean): { [string]: unknown }
    local deadline = os.clock() + 4
    repeat
        local model = workspace.World.Battlefield:FindFirstChild(id, true)
        local effects = workspace:FindFirstChild("LocalWeaponImpacts")
        local audio = workspace:FindFirstChild("LocalWeaponAudio")
        if
            model
            and model:GetAttribute("DamageAppearance") == appearance
            and (not clear or (not effects and not audio))
        then
            return { id = id, appearance = appearance, cleared = not effects and not audio }
        end
        task.wait()
    until os.clock() >= deadline
    error("panel stage or local effects failed to converge: " .. id .. " " .. appearance)
end

-- Bounded convergence covers replicated data from the production server owners.
local function converge(expected: Check)
    local deadline = os.clock() + 4
    while os.clock() < deadline do
        local round = ReplicatedStorage.RoundState
        local aircraft = ReplicatedStorage.AircraftState
        local launcher = json(ReplicatedStorage.LauncherState, "Snapshot")
        local selection = json(aircraft, "Selection")
        local result = json(round, "Result")
        if
            round:GetAttribute("RoundId") == expected.roundId
            and round:GetAttribute("Phase") == expected.phase
            and aircraft:GetAttribute("Health") == expected.health
            and launcher
            and launcher.ownerId == expected.ownerId
            and launcher.state == expected.launcherState
            and (expected.weapon == nil or (selection and selection.weapon == expected.weapon))
            and (
                if expected.resultReason
                    then result ~= nil
                        and result.reason == expected.resultReason
                        and result.winner == expected.winner
                    else result == nil
            )
        then
            return
        end
        task.wait()
    end
    error("replicated phase, health, owner, selection or result did not converge")
end

local function send(intents: { Intent })
    assert(#intents <= 6, "too many fixture actions")
    for _, intent in intents do
        local names = allowed[intent.owner]
        assert(names and names[intent.remote], "unlisted gameplay remote")
        local owner = assert(ReplicatedStorage:FindFirstChild(intent.owner), "missing gameplay owner")
        local remote = owner:FindFirstChild(intent.remote)
        assert(remote and remote:IsA("RemoteEvent"), "missing gameplay remote")
        local repetitions = intent.repetitions or 1
        assert(
            repetitions >= 1 and repetitions <= 64 and repetitions % 1 == 0,
            "invalid fixture repetition count"
        )
        for _ = 1, repetitions do
            remote:FireServer(intent.body)
        end
    end
end

-- Starts the fixture after real Client TestEZ smoke. No listeners are active in
-- ordinary local Play. Profile sampling never sends per-frame network traffic.
local function listen()
    task.spawn(function()
        local transport = ReplicatedStorage:WaitForChild("P11Harness", 120)
        if not transport or not transport:IsA("RemoteEvent") then
            return
        end
        local frames: Metrics.FrameRecorder? = nil
        local viewportStart: Vector2? = nil
        local viewportEnd: Vector2? = nil
        local viewportChanged = false
        local graphicsStart = ""
        local graphicsChanged = false
        local frameConnection: RBXScriptConnection? = nil
        local impactProbe: ImpactFrameProbe? = nil
        local started = 0
        local profileRole: unknown
        local listener = transport.OnClientEvent:Connect(
            function(token: number, action: string, payload: unknown)
                local ok, result = pcall(function(): unknown
                    if action == "Send" then
                        send(payload :: { Intent })
                    elseif action == "Check" then
                        converge(payload :: Check)
                    elseif action == "PanelStage" then
                        local request = payload :: { id: string, appearance: string, clear: boolean? }
                        return panelStage(request.id, request.appearance, request.clear == true)
                    elseif action == "Memory" then
                        assert(Stats.MemoryTrackingEnabled, "client engine memory tracking disabled")
                        return Stats:GetTotalMemoryUsageMb()
                    elseif action == "ProfileEnvironment" then
                        local camera = workspace.CurrentCamera
                        local size = if camera then camera.ViewportSize else Vector2.zero
                        return { width = size.X, height = size.Y, graphics = graphics.SavedQualityLevel.Name }
                    elseif action == "ProfileStart" then
                        local camera = assert(workspace.CurrentCamera, "profile camera missing")
                        assert(not frameConnection, "client profiling already active")
                        local recorder = Metrics.frames()
                        frames = recorder
                        viewportStart, viewportEnd = camera.ViewportSize, camera.ViewportSize
                        graphicsStart = graphics.SavedQualityLevel.Name
                        assert(
                            viewportStart == Vector2.new(Metrics.profile.width, Metrics.profile.height)
                                and graphicsStart == Metrics.profile.graphics,
                            "profile settings changed after preflight"
                        )
                        viewportChanged, graphicsChanged = false, false
                        profileRole = player:GetAttribute("Role")
                        started = os.clock()
                        local probe = impactFrames()
                        impactProbe = probe
                        frameConnection = RunService.PreRender:Connect(function(seconds)
                            recorder.record(seconds)
                            probe.sample()
                            graphicsChanged = graphicsChanged
                                or graphics.SavedQualityLevel.Name ~= graphicsStart
                            local current = workspace.CurrentCamera
                            if current then
                                viewportEnd = current.ViewportSize
                                viewportChanged = viewportChanged or viewportEnd ~= viewportStart
                            end
                        end)
                    elseif action == "ProfileStop" then
                        assert(
                            frames and frameConnection and viewportStart and viewportEnd,
                            "client profile not running"
                        )
                        frameConnection:Disconnect()
                        frameConnection = nil
                        local probe = assert(impactProbe, "impact frame probe missing")
                        local impactReport = probe.report()
                        probe.stop()
                        impactProbe = nil
                        local report = frames.summary()
                        return {
                            frames = report,
                            impacts = impactReport,
                            seconds = os.clock() - started,
                            role = profileRole,
                            width = viewportStart.X,
                            height = viewportStart.Y,
                            viewportChanged = viewportChanged,
                            graphics = graphicsStart,
                            graphicsChanged = graphicsChanged,
                        }
                    elseif action ~= "Ping" then
                        error("unknown client fixture action: " .. action)
                    end
                    return true
                end)
                if token ~= 0 or not ok then
                    transport:FireServer(token, ok, if ok then result else tostring(result))
                end
            end
        )
        transport.Destroying:Once(function()
            listener:Disconnect()
            if frameConnection then
                frameConnection:Disconnect()
            end
            if impactProbe then
                impactProbe.stop()
            end
        end)
        transport:FireServer(-1, true, script.Parent:GetAttribute("ClientTestReport"))
    end)
end

-- Reject historical clients before subscribing to fixture transport.
function Harness.run()
    require(game:GetService("ReplicatedStorage").HarnessCompatibility).assertCurrent("P11")
    listen()
end

-- Subscribes to the current profile after real client smoke.
Harness.profile = listen

return Harness
