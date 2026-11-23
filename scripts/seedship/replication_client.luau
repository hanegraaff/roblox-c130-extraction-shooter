--!strict
-- Runs only when the isolated, two-client Seedship test explicitly requests it.
local test = game:GetService("StudioTestService")
if test:GetTestArgs() ~= "PrismReplication" then
    return
end
local replicated = game:GetService("ReplicatedStorage")
local probe = require(replicated:WaitForChild("PrismReplicationProbe"))
local channel = replicated:WaitForChild("PrismReplicate") :: RemoteEvent
local panels = workspace.World.Battlefield:WaitForChild("PrismPanels")
channel.OnClientEvent:Connect(function(phase, samples, expected)
    local deadline = os.clock() + 30
    local observed = {}
    repeat
        observed = probe(panels, samples)
        local matches = true
        for name, report in expected do
            if observed[name].hits ~= report.hits or observed[name].appearance ~= report.appearance then
                matches = false
                break
            end
        end
        if matches then
            break
        end
        task.wait(0.2)
    until os.clock() > deadline
    channel:FireServer(phase, observed)
end)
channel:FireServer(0)
