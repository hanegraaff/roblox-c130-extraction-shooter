--!strict
--[=[ Client entrypoint: waits at most ten seconds for server status, then owns one status panel. ]=]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StatusPanel = require(script.StatusPanel)
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui", 10)
local status = ReplicatedStorage:WaitForChild("BootstrapStatus", 10)
assert(playerGui and playerGui:IsA("PlayerGui"), "PlayerGui unavailable")
assert(status, "server bootstrap unavailable")
local runtime = StatusPanel.new(playerGui, status)
local ok, reason = runtime.start()
assert(ok, reason)
script.Destroying:Connect(runtime.stop)
