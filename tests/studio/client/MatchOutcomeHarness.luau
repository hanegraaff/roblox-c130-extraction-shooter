--!strict
-- P09 client fixture. Sends production intents and acknowledges actual replicated
-- result text, weapon views, team assignments and camera lifecycle. Test mapping only.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StudioTestService = game:GetService("StudioTestService")
local Harness = {}
local player = Players.LocalPlayer

type Check =
    { roundId: number, winner: string?, reason: string?, credit: number?, text: string?, fov: number? }

local function waitFor(predicate: () -> boolean, message: string)
    local deadline = os.clock() + 8
    while not predicate() and os.clock() < deadline do
        task.wait()
    end
    assert(predicate(), message)
end

local function verify(kind: string, expected: Check)
    local state = ReplicatedStorage:FindFirstChild("RoundState")
    assert(state, "round state missing")
    waitFor(function()
        local camera = workspace.CurrentCamera
        local gui = player:FindFirstChildOfClass("PlayerGui")
        local thermal = if gui then gui:FindFirstChild("ThermalHUD") else nil
        local hud = if gui then gui:FindFirstChild("RoundHUD") else nil
        local label = if hud then hud:FindFirstChild("Round") else nil
        if state:GetAttribute("RoundId") ~= expected.roundId or not camera then
            return false
        end
        if kind == "Result" then
            local encoded = state:GetAttribute("Result")
            if type(encoded) ~= "string" then
                return false
            end
            local result = HttpService:JSONDecode(encoded)
            return state:GetAttribute("Phase") == "Results"
                and result.roundId == expected.roundId
                and result.winner == expected.winner
                and result.reason == expected.reason
                and result.userId == expected.credit
                and state:GetAttribute("Winner") == expected.winner
                and state:GetAttribute("Reason") == expected.reason
                and label ~= nil
                and label:IsA("TextLabel")
                and label.Text == expected.text
                and thermal == nil
        elseif kind == "Lobby" then
            local humanoid = if player.Character
                then player.Character:FindFirstChildOfClass("Humanoid")
                else nil
            return state:GetAttribute("Phase") == "Lobby"
                and state:GetAttribute("Result") == nil
                and player:GetAttribute("Role") == "Waiting"
                and thermal == nil
                and humanoid ~= nil
                and camera.CameraType == Enum.CameraType.Custom
                and camera.CameraSubject == humanoid
        elseif kind == "Operator" then
            return state:GetAttribute("Phase") == "Active"
                and player.Team ~= nil
                and player.Team.Name == "Gunship"
                and thermal ~= nil
                and camera.CameraType == Enum.CameraType.Scriptable
                and expected.fov ~= nil
                and math.abs(camera.FieldOfView - expected.fov) < 0.5
        elseif kind == "Ground" then
            local humanoid = if player.Character
                then player.Character:FindFirstChildOfClass("Humanoid")
                else nil
            return state:GetAttribute("Phase") == "Active"
                and player.Team ~= nil
                and player.Team.Name == "Ground"
                and thermal == nil
                and humanoid ~= nil
                and camera.CameraType == Enum.CameraType.Custom
                and camera.CameraSubject == humanoid
        end
        return false
    end, "client " .. kind .. " did not converge")
end

-- One native client listener scoped to the owned fixture remote.
function Harness.run()
    task.spawn(function()
        local transport = ReplicatedStorage:WaitForChild("P09Harness", 120)
        if not transport or not transport:IsA("RemoteEvent") then
            return
        end
        local listener = transport.OnClientEvent:Connect(
            function(token: number, kind: string, payload: unknown)
                local ok, problem = pcall(function()
                    local ownerName, remoteName = string.match(kind, "^([^/]+)/([^/]+)$")
                    if ownerName and remoteName then
                        local owner = ReplicatedStorage:FindFirstChild(ownerName)
                        local remote = if owner then owner:FindFirstChild(remoteName) else nil
                        assert(remote and remote:IsA("RemoteEvent"), "production remote missing")
                        remote:FireServer(payload)
                    elseif kind == "Leave" then
                        assert(StudioTestService:CanLeaveTest(), "SDK client cannot leave")
                    else
                        verify(kind, payload :: Check)
                    end
                end)
                transport:FireServer(token, ok, if ok then "" else tostring(problem))
                if ok and kind == "Leave" then
                    task.defer(function()
                        StudioTestService:LeaveTest()
                    end)
                end
            end
        )
        transport.Destroying:Once(function()
            listener:Disconnect()
        end)
        -- The client entrypoint publishes this exact TestEZ result and asserts
        -- success before starting the harness listener.
        transport:FireServer(0, true, script.Parent:GetAttribute("ClientTestReport"))
    end)
end

return Harness
