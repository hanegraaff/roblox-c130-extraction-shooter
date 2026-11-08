--!strict
--[=[
    Bootstrap: server-only foundation runtime, composed with shared Lifecycle/Config.
    Owns one replicated status Folder and one Heartbeat connection. No remotes or gameplay.
    Test environment label comes from server-only mapped settings, never from client input.
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config)
local Lifecycle = require(ReplicatedStorage.Shared.Lifecycle)
local Bootstrap = {}

-- Builds an independent nonyielding runtime. Caller must stop it before another owner starts.
function Bootstrap.new(environment: string): Lifecycle.Controller
    return Lifecycle.new({
        function()
            local settings, reason = Config.validate(Config.defaults)
            assert(settings, reason)
            assert(not ReplicatedStorage:FindFirstChild("BootstrapStatus"), "bootstrap already owned")
            local status = Instance.new("Folder")
            status.Name = "BootstrapStatus"
            status:SetAttribute("Environment", environment)
            status:SetAttribute("Running", true)
            status:SetAttribute("UptimeSeconds", 0)
            status.Parent = ReplicatedStorage
            local elapsedSeconds = 0
            local heartbeat = RunService.Heartbeat:Connect(function(deltaSeconds: number)
                elapsedSeconds += deltaSeconds
                status:SetAttribute("UptimeSeconds", math.floor(elapsedSeconds))
            end)
            return function()
                heartbeat:Disconnect()
                status:Destroy()
            end
        end,
    })
end
return Bootstrap
