--!strict
--[=[
    RoundHarness: test-only client observations for real multi-client P03 acceptance.
    Installs a bounded discovery task and one owned test listener. Production builds
    exclude this module and transport. Reports actual local attributes/camera and sends
    real production commands; it never grants roles, changes game state or fakes clients.
]=]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StudioTestService = game:GetService("StudioTestService")
local RoundHarness = {}

type Probe = {
    kind: string,
    roundId: number?,
    role: string?,
    life: string?,
    phase: string?,
    deadlineSeconds: number?,
    targetId: number?,
    sequence: number?,
}

local function awaitCondition(predicate: () -> boolean, label: string)
    local deadline = os.clock() + 8
    while not predicate() and os.clock() < deadline do
        task.wait(0.05)
    end
    assert(predicate(), "client timeout: " .. label)
end

-- Nonyielding installation. Ordinary local sessions simply time out discovery without
-- creating test transport; automated sessions disconnect this listener on remote removal.
function RoundHarness.run()
    task.spawn(function()
        local remote = ReplicatedStorage:WaitForChild("P03Harness", 120)
        if not remote or not remote:IsA("RemoteEvent") then
            return
        end
        local player = Players.LocalPlayer
        local connection: RBXScriptConnection? = nil
        local removal: RBXScriptConnection? = nil
        connection = remote.OnClientEvent:Connect(function(token: number, request: Probe)
            local ok, detail = pcall(function()
                if request.kind == "Observe" then
                    awaitCondition(function()
                        local status = ReplicatedStorage:FindFirstChild("RoundState")
                        return status ~= nil
                            and status:GetAttribute("RoundId") == request.roundId
                            and status:GetAttribute("Phase") == request.phase
                            and status:GetAttribute("DeadlineSeconds") == request.deadlineSeconds
                            and player:GetAttribute("RoundId") == request.roundId
                            and player:GetAttribute("Role") == request.role
                            and player:GetAttribute("Life") == request.life
                    end, "replicated role/phase/deadline")
                    assert(player.PlayerGui:FindFirstChild("RoundHUD"), "round UI missing")
                    if request.role == "Spectator" then
                        assert(player.Character == nil, "late spectator gained a character")
                    end
                elseif request.kind == "Spectate" then
                    awaitCondition(function()
                        local target = Players:GetPlayerByUserId(request.targetId or 0)
                        local character = if target then target.Character else nil
                        local humanoid = if character
                            then character:FindFirstChildOfClass("Humanoid")
                            else nil
                        local camera = workspace.CurrentCamera
                        return player:GetAttribute("Life") == "Eliminated"
                            and camera ~= nil
                            and humanoid ~= nil
                            and camera.CameraSubject == humanoid
                    end, "living teammate camera subject")
                elseif request.kind == "LobbyCamera" then
                    awaitCondition(function()
                        local character = player.Character
                        local humanoid = if character
                            then character:FindFirstChildOfClass("Humanoid")
                            else nil
                        local camera = workspace.CurrentCamera
                        return player:GetAttribute("Role") == "Waiting"
                            and camera ~= nil
                            and humanoid ~= nil
                            and camera.CameraSubject == humanoid
                            and camera.CameraType == Enum.CameraType.Custom
                    end, "lobby camera restoration")
                elseif request.kind == "SendRejected" or request.kind == "Surrender" then
                    local status = ReplicatedStorage:FindFirstChild("RoundState")
                    assert(status, "round state missing")
                    local command = status:FindFirstChild("Surrender")
                    assert(command and command:IsA("RemoteEvent"), "production surrender remote missing")
                    command:FireServer({
                        roundId = request.roundId,
                        sequence = request.sequence,
                        action = "Surrender",
                    })
                elseif request.kind == "Leave" then
                    assert(StudioTestService:CanLeaveTest(), "actual client cannot leave test")
                else
                    error("unknown harness directive")
                end
            end)
            remote:FireServer(token, { passed = ok, detail = if ok then "observed" else tostring(detail) })
            if ok and request.kind == "Leave" then
                task.delay(0.2, function()
                    StudioTestService:LeaveTest()
                end)
            end
        end)
        remote:FireServer(0, { passed = true })
        removal = remote.AncestryChanged:Connect(function()
            if not remote:IsDescendantOf(ReplicatedStorage) then
                if connection then
                    connection:Disconnect()
                end
                if removal then
                    removal:Disconnect()
                end
            end
        end)
    end)
end

return RoundHarness
