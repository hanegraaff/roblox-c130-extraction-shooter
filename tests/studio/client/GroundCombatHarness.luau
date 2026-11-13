--!strict
-- Test-only P06 client transport. Sends real remotes and checks replicated state.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local StudioTestService = game:GetService("StudioTestService")
local Harness = {}
function Harness.run()
    task.spawn(function()
        local transport = ReplicatedStorage:WaitForChild("P06Harness", 90)
        if not transport or not transport:IsA("RemoteEvent") then
            return
        end
        local listener: RBXScriptConnection
        listener = transport.OnClientEvent:Connect(function(token: number, kind: string, payload: unknown)
            local ok, reason = pcall(function()
                local state = ReplicatedStorage:FindFirstChild("AircraftState")
                assert(state, "aircraft state missing")
                if kind == "Fire" or kind == "Flood" then
                    local remote = state:FindFirstChild("GroundFire")
                    assert(remote and remote:IsA("RemoteEvent"), "ground fire missing")
                    if kind == "Flood" then
                        for _ = 1, 30 do
                            remote:FireServer(payload)
                        end
                    else
                        remote:FireServer(payload)
                    end
                elseif kind == "Reload" then
                    local remote = state:FindFirstChild("GroundReload")
                    assert(remote and remote:IsA("RemoteEvent"), "ground reload missing")
                    remote:FireServer(payload)
                elseif kind == "Observe" then
                    assert(
                        type(payload) == "number" or type(payload) == "table",
                        "health expectation missing"
                    )
                    local expected: { [string]: unknown } = if type(payload) == "table"
                        then payload :: { [string]: unknown }
                        else { health = payload }
                    local deadline = os.clock() + 8
                    local function matches(): boolean
                        local shot = state:GetAttribute("GroundShot")
                        local decoded = if type(shot) == "string" then HttpService:JSONDecode(shot) else nil
                        local round = ReplicatedStorage:FindFirstChild("RoundState")
                        local roundHud = Players.LocalPlayer.PlayerGui:FindFirstChild("RoundHUD")
                        local healthLabel = if roundHud
                            then roundHud:FindFirstChild("AircraftHealth")
                            else nil
                        local hudMatches = expected.hud ~= true
                            or (
                                healthLabel ~= nil
                                and healthLabel:IsA("TextLabel")
                                and healthLabel.Visible
                                and string.find(healthLabel.Text, tostring(expected.health), 1, true)
                                    ~= nil
                            )
                        return state:GetAttribute("Health") == expected.health
                            and hudMatches
                            and (expected.destroyed == nil or state:GetAttribute("Destroyed") == expected.destroyed)
                            and (expected.shotSequence == nil or (decoded and decoded.sequence == expected.shotSequence))
                            and (expected.shotAircraftHit == nil or (decoded and decoded.aircraftHit == expected.shotAircraftHit))
                            and (expected.shotCleared ~= true or shot == nil)
                            and (
                                expected.winner == nil
                                or (round and round:GetAttribute("Winner") == expected.winner)
                            )
                    end
                    while not matches() and os.clock() < deadline do
                        task.wait(0.03)
                    end
                    assert(matches(), "aircraft state or result replication mismatch")
                elseif kind == "Leave" then
                    assert(StudioTestService:CanLeaveTest(), "actual client cannot leave test")
                else
                    error("unknown P06 probe")
                end
            end)
            transport:FireServer(token, ok, if ok then "ok" else tostring(reason), Players.LocalPlayer.UserId)
            if ok and kind == "Leave" then
                task.delay(0.2, function()
                    StudioTestService:LeaveTest()
                end)
            end
        end)
        transport.AncestryChanged:Connect(function()
            if not transport:IsDescendantOf(ReplicatedStorage) then
                listener:Disconnect()
            end
        end)
        transport:FireServer(0, true, "ready", Players.LocalPlayer.UserId)
    end)
end
return Harness
