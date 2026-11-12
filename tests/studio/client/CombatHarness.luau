--!strict
-- Test-only P05 client transport: sends production requests and observes replication.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local CombatHarness = {}
local function waitFor(predicate: () -> boolean, message: string)
    local deadline = os.clock() + 8
    while not predicate() and os.clock() < deadline do
        task.wait(0.03)
    end
    assert(predicate(), "client P05 timeout: " .. message)
end
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
                if kind == "Fire" or kind == "Select" or kind == "Flood" then
                    local target =
                        state:FindFirstChild(if kind == "Select" then "SelectWeapon" else "FireWeapon")
                    assert(target and target:IsA("RemoteEvent"), "production combat transport missing")
                    if kind == "Flood" then
                        for _ = 1, 30 do
                            target:FireServer(payload)
                        end
                    else
                        target:FireServer(payload)
                    end
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
                    if type(payload) == "table" then
                        local expected = payload :: { [string]: unknown }
                        waitFor(function()
                            local selection = state:GetAttribute("Selection")
                            local impact = state:GetAttribute("Impact")
                            local selected = if type(selection) == "string"
                                then HttpService:JSONDecode(selection)
                                else nil
                            local hit = if type(impact) == "string"
                                then HttpService:JSONDecode(impact)
                                else nil
                            local target = if type(expected.targetId) == "number"
                                then Players:GetPlayerByUserId(expected.targetId)
                                else nil
                            local character = if target then target.Character else nil
                            local humanoid = if character
                                then character:FindFirstChildOfClass("Humanoid")
                                else nil
                            return (
                                expected.weapon == nil or (selected and selected.weapon == expected.weapon)
                            )
                                and (expected.shotId == nil or (hit and hit.shotId == expected.shotId))
                                and (expected.health == nil or (humanoid and humanoid.Health == expected.health))
                                and (
                                    expected.winner == nil
                                    or round:GetAttribute("Winner") == expected.winner
                                )
                        end, "matching weapon, impact, health and result")
                    end
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
