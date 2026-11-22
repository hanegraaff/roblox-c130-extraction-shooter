--!strict
--[=[ Client entrypoint: boot status, session-local options and round presentation owners. ]=]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StatusPanel = require(script.StatusPanel)
local RoundPanel = require(script.RoundPanel)
local GroundCombatController = require(script.GroundCombatController)
local GroundIndoorCamera = require(script.GroundIndoorCamera)
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
local settings = RoundPanel.newSettings()
local rounds: { stop: () -> () }? = nil
local ground: { stop: () -> () }? = nil
local stopIndoor: (() -> ())? = nil
local activeRoundState: Instance? = nil
local function stopRoundOwners()
    activeRoundState = nil
    if stopIndoor then
        stopIndoor()
        stopIndoor = nil
    end
    if rounds then
        rounds.stop()
        rounds = nil
    end
    if ground then
        ground.stop()
        ground = nil
    end
end
local function attach(instance: Instance)
    if instance.Name ~= "RoundState" or instance == activeRoundState then
        return
    end
    stopRoundOwners()
    local controller = GroundCombatController.new(Players.LocalPlayer, playerGui, instance)
    assert(controller.start(), "expected ground controller.start()")
    ground = controller
    local panel = RoundPanel.new(Players.LocalPlayer, playerGui, instance, nil, nil, settings)
    assert(panel.start(), "expected panel.start()")
    rounds = panel
    stopIndoor = GroundIndoorCamera.start(Players.LocalPlayer, instance)
    activeRoundState = instance
end
local added = ReplicatedStorage.ChildAdded:Connect(attach)
local removed = ReplicatedStorage.ChildRemoved:Connect(function(instance)
    if instance == activeRoundState then
        stopRoundOwners()
    end
end)
local current = ReplicatedStorage:FindFirstChild("RoundState")
if current then
    attach(current)
end
script.Destroying:Connect(function()
    added:Disconnect()
    removed:Disconnect()
    stopRoundOwners()
end)
