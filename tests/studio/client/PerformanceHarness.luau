--!strict
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
local allowed = {
    AircraftState = { FireWeapon = true, SelectWeapon = true, GroundFire = true, GroundReload = true },
    LauncherState = { Pickup = true, Drop = true, Fire = true },
} :: { [string]: { [string]: boolean } }

local function json(state: Instance, attribute: string): { [string]: unknown }?
    local encoded = state:GetAttribute(attribute)
    return if type(encoded) == "string" then HttpService:JSONDecode(encoded) else nil
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
function Harness.run()
    task.spawn(function()
        local transport = ReplicatedStorage:WaitForChild("P11Harness", 120)
        if not transport or not transport:IsA("RemoteEvent") then
            return
        end
        local frames: Metrics.FrameRecorder? = nil
        local viewportStart: Vector2? = nil
        local viewportEnd: Vector2? = nil
        local viewportChanged = false
        local frameConnection: RBXScriptConnection? = nil
        local started = 0
        local profileRole: unknown
        local listener = transport.OnClientEvent:Connect(
            function(token: number, action: string, payload: unknown)
                local ok, result = pcall(function(): unknown
                    if action == "Send" then
                        send(payload :: { Intent })
                    elseif action == "Check" then
                        converge(payload :: Check)
                    elseif action == "Memory" then
                        assert(Stats.MemoryTrackingEnabled, "client engine memory tracking disabled")
                        return Stats:GetTotalMemoryUsageMb()
                    elseif action == "ProfileStart" then
                        local camera = assert(workspace.CurrentCamera, "profile camera missing")
                        assert(not frameConnection, "client profiling already active")
                        local recorder = Metrics.frames()
                        frames = recorder
                        viewportStart, viewportEnd = camera.ViewportSize, camera.ViewportSize
                        viewportChanged = false
                        profileRole = player:GetAttribute("Role")
                        started = os.clock()
                        frameConnection = RunService.PreRender:Connect(function(seconds)
                            recorder.record(seconds)
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
                        local report = frames.summary()
                        return {
                            frames = report,
                            seconds = os.clock() - started,
                            role = profileRole,
                            width = viewportStart.X,
                            height = viewportStart.Y,
                            viewportChanged = viewportChanged,
                            graphics = UserSettings():GetService("UserGameSettings").SavedQualityLevel.Name,
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
        end)
        transport:FireServer(-1, true, script.Parent:GetAttribute("ClientTestReport"))
    end)
end

return Harness
