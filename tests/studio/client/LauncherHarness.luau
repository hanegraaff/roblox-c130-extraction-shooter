--!strict
-- P08 test-only real-client transport. Production remotes perform every action;
-- observations wait for actual replicated ownership, readiness, tools and health.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local StudioTestService = game:GetService("StudioTestService")
local Harness = {}
function Harness.run()
    task.spawn(function()
        local transport = ReplicatedStorage:WaitForChild("P08Harness", 90)
        if not transport or not transport:IsA("RemoteEvent") then
            return
        end
        local listener = transport.OnClientEvent:Connect(
            function(token: number, kind: string, payload: unknown)
                local ok, failure = pcall(function()
                    local state = ReplicatedStorage:FindFirstChild("LauncherState")
                    assert(state, "launcher state unavailable")
                    if kind == "Observe" then
                        assert(type(payload) == "table", "observation missing")
                        local expected = payload :: { [string]: unknown }
                        local deadline = os.clock() + 10
                        local function matches(): boolean
                            local encoded = state:GetAttribute("Snapshot")
                            local snapshot = if type(encoded) == "string"
                                then HttpService:JSONDecode(encoded)
                                else nil
                            local aircraft = ReplicatedStorage:FindFirstChild("AircraftState")
                            local player = Players.LocalPlayer
                            if
                                not snapshot
                                or snapshot.roundId ~= expected.roundId
                                or snapshot.state ~= expected.state
                                or snapshot.ownerId ~= expected.ownerId
                                or snapshot.readyAt ~= expected.readyAt
                            then
                                return false
                            end
                            if
                                expected.health ~= nil
                                and (not aircraft or aircraft:GetAttribute("Health") ~= expected.health)
                            then
                                return false
                            end
                            if snapshot.ownerId == player.UserId then
                                local backpack, character =
                                    player:FindFirstChildOfClass("Backpack"), player.Character
                                local tool = (
                                    if backpack then backpack:FindFirstChild("Rocket launcher") else nil
                                )
                                    or (
                                        if character then character:FindFirstChild("Rocket launcher") else nil
                                    )
                                if
                                    not tool
                                    or tool:GetAttribute("LauncherId") ~= snapshot.launcherId
                                    or tool:GetAttribute("ReloadUntil") ~= expected.readyAt
                                then
                                    return false
                                end
                            end
                            return true
                        end
                        while not matches() and os.clock() < deadline do
                            task.wait(0.03)
                        end
                        assert(matches(), "ownership/readiness/health replication disagreed")
                    elseif kind == "Leave" then
                        assert(StudioTestService:CanLeaveTest(), "actual client cannot leave this test mode")
                    else
                        local aircraft = ReplicatedStorage:FindFirstChild("AircraftState")
                        local owner = if kind == "Rifle" then aircraft else state
                        local name = if kind == "Rifle"
                            then "GroundFire"
                            elseif kind == "Flood" then "Pickup"
                            else kind
                        local remote = if owner then owner:FindFirstChild(name) else nil
                        assert(remote and remote:IsA("RemoteEvent"), "intent remote missing")
                        for _ = 1, if kind == "Flood" then 30 else 1 do
                            remote:FireServer(payload)
                        end
                    end
                end)
                transport:FireServer(token, ok, if ok then "ok" else tostring(failure))
                if ok and kind == "Leave" then
                    task.delay(0.2, function()
                        StudioTestService:LeaveTest()
                    end)
                end
            end
        )
        local ancestry: RBXScriptConnection
        ancestry = transport.AncestryChanged:Connect(function()
            if not transport:IsDescendantOf(ReplicatedStorage) then
                listener:Disconnect()
                ancestry:Disconnect()
            end
        end)
        transport:FireServer(0, true, "ready")
    end)
end
return Harness
