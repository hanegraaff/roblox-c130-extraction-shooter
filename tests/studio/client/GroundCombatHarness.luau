--!strict
-- Test-only P06 client transport. Sends real remotes and checks replicated state.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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
                if kind == "Fire" then
                    local remote = state:FindFirstChild("GroundFire")
                    assert(remote and remote:IsA("RemoteEvent"), "ground fire missing")
                    remote:FireServer(payload)
                elseif kind == "Reload" then
                    local remote = state:FindFirstChild("GroundReload")
                    assert(remote and remote:IsA("RemoteEvent"), "ground reload missing")
                    remote:FireServer(payload)
                elseif kind == "Observe" then
                    assert(type(payload) == "number", "health expectation missing")
                    local deadline = os.clock() + 8
                    while state:GetAttribute("Health") ~= payload and os.clock() < deadline do
                        task.wait(0.03)
                    end
                    assert(state:GetAttribute("Health") == payload, "health replication mismatch")
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
