--!strict
-- Test-only P05 client transport: sends production requests and observes replication.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CombatHarness = {}
function CombatHarness.run()
    task.spawn(function()
        local remote = ReplicatedStorage:WaitForChild("P05Harness", 50)
        if not remote or not remote:IsA("RemoteEvent") then
            return
        end
        local listener: RBXScriptConnection
        listener = remote.OnClientEvent:Connect(function(token: number, kind: string, payload: unknown)
            local ok, reason = pcall(function()
                local state = ReplicatedStorage:WaitForChild("AircraftState", 5)
                assert(state, "aircraft state missing")
                if kind == "Fire" or kind == "Select" then
                    local target =
                        state:FindFirstChild(if kind == "Fire" then "FireWeapon" else "SelectWeapon")
                    assert(target and target:IsA("RemoteEvent"), "production combat transport missing")
                    target:FireServer(payload)
                elseif kind == "Observe" then
                    local round = ReplicatedStorage:FindFirstChild("RoundState")
                    local effects = workspace:FindFirstChild("CombatEffects")
                    assert(
                        round
                            and effects
                            and state:GetAttribute("Selection")
                            and state:GetAttribute("Readiness"),
                        "replicated combat state missing"
                    )
                else
                    error("unknown combat probe")
                end
            end)
            remote:FireServer(token, ok, if ok then "ok" else tostring(reason), Players.LocalPlayer.UserId)
        end)
        remote.AncestryChanged:Connect(function()
            if not remote:IsDescendantOf(ReplicatedStorage) then
                listener:Disconnect()
            end
        end)
        remote:FireServer(0, true, "ready", Players.LocalPlayer.UserId)
    end)
end
return CombatHarness
