--!strict
--[=[ Client entrypoint: waits at most ten seconds for server status, then owns one status panel. ]=]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StatusPanel = require(script.StatusPanel)
local RoundPanel = require(script.RoundPanel)
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui", 10)
local status = ReplicatedStorage:WaitForChild("BootstrapStatus", 10)
assert(playerGui and playerGui:IsA("PlayerGui"), "PlayerGui unavailable")
assert(status, "server bootstrap unavailable")
local runtime = StatusPanel.new(playerGui, status)
local ok, reason = runtime.start()
assert(ok, reason)
script.Destroying:Connect(runtime.stop)
-- The test mapping starts rounds after its foundation suites. Reattach when the
-- explicit server owner is replaced rather than retaining a stale status Folder.
local rounds: { stop: () -> () }? = nil
local function attach(instance: Instance)
    if instance.Name ~= "RoundState" then
        return
    end
    if rounds then
        rounds.stop()
    end
    local panel = RoundPanel.new(Players.LocalPlayer, playerGui, instance)
    assert(panel.start(), "expected panel.start()")
    rounds = panel
end
local added = ReplicatedStorage.ChildAdded:Connect(attach)
local removed = ReplicatedStorage.ChildRemoved:Connect(function(instance)
    if instance.Name == "RoundState" and rounds then
        rounds.stop()
        rounds = nil
    end
end)
local current = ReplicatedStorage:FindFirstChild("RoundState")
if current then
    attach(current)
end
script.Destroying:Connect(function()
    added:Disconnect()
    removed:Disconnect()
    if rounds then
        rounds.stop()
    end
end)
