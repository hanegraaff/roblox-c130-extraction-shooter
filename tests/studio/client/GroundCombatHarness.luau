--!strict
-- Test-only P06 client transport. Sends real remotes and checks replicated state.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
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
                        return state:GetAttribute("Health") == expected.health
                            and (expected.destroyed == nil or state:GetAttribute("Destroyed") == expected.destroyed)
                            and (expected.shotSequence == nil or (decoded and decoded.sequence == expected.shotSequence))
                            and (
                                expected.winner == nil
                                or (round and round:GetAttribute("Winner") == expected.winner)
                            )
                    end
                    while not matches() and os.clock() < deadline do
                        task.wait(0.03)
                    end
                    assert(matches(), "aircraft state or result replication mismatch")
                else
                    error("unknown P06 probe")
                end
            end)
            transport:FireServer(token, ok, if ok then "ok" else tostring(reason), Players.LocalPlayer.UserId)
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
