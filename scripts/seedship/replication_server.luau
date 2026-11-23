--!strict
-- Test-only StudioTestService server. Run in a local document with the ordinary
-- composition root and smoke runner disabled for this isolated damage test.
local test = game:GetService("StudioTestService")
local Players = game:GetService("Players")
local replicated = game:GetService("ReplicatedStorage")
local world = workspace.World
local server = game:GetService("ServerScriptService").Server
local assets = game:GetService("ServerStorage").Assets
local Seedship = require(server.SeedshipReconstruction)
local BuildingGeometry = require(server.BuildingGeometry)
local Damage = require(server.DestructionRuntime)
local probe = require(replicated:WaitForChild("PrismReplicationProbe"))

if test:GetTestArgs() ~= "PrismReplication" then
    return
end
local ok, result = pcall(function()
    local installation, reason = Seedship.install(world, assets)
    assert(installation, reason)
    installation.commit()
    local map = world.Battlefield
    BuildingGeometry.decorate(map)
    local owner, problem = Damage.start(world)
    assert(owner, problem)
    owner.sync(1)
    local samples = {}
    local panels = map.PrismPanels
    for _, name in { "Prism_Skirt_01", "Prism_Roof_01" } do
        local panel = panels:FindFirstChild(name)
        assert(panel, name)
        for _, child in panel:GetChildren() do
            if child:IsA("MeshPart") and child:GetAttribute("PanelProxy") then
                table.insert(
                    samples,
                    {
                        name = name,
                        center = child.Position,
                        half = child.Size / 2,
                        roof = name:find("Roof") ~= nil,
                    }
                )
            end
        end
    end
    assert(#samples == 2)
    local channel = Instance.new("RemoteEvent")
    channel.Name = "PrismReplicate"
    local expectedPhase = 0
    local records = {}
    local ready = {}
    local acknowledgements = {}
    channel.OnServerEvent:Connect(function(player, phase, report)
        if phase == 0 then
            ready[player] = true
        elseif phase == expectedPhase and type(report) == "table" then
            acknowledgements[player] = report
        end
    end)
    channel.Parent = replicated
    local function await(condition: () -> boolean, message: string)
        local deadline = os.clock() + 40
        repeat
            if condition() then
                return
            end
            task.wait(0.15)
        until os.clock() > deadline
        error(message)
    end
    await(function()
        local people = Players:GetPlayers()
        return #people == 2 and ready[people[1]] and ready[people[2]]
    end, "two Studio clients did not connect")
    local function observe(label: string)
        expectedPhase += 1
        table.clear(acknowledgements)
        local authoritative = probe(panels, samples)
        for name, report in authoritative do
            assert(report.appearance == (if label == "Reset" then "Pristine" else label), name)
        end
        channel:FireAllClients(expectedPhase, samples, authoritative)
        await(function()
            local people = Players:GetPlayers()
            return #people == 2 and acknowledgements[people[1]] ~= nil and acknowledgements[people[2]] ~= nil
        end, "two client observations missing for " .. label)
        for player, observation in acknowledgements do
            for name, report in authoritative do
                assert(
                    observation[name]
                        and observation[name].hits == report.hits
                        and observation[name].appearance == report.appearance,
                    player.Name .. " disagreed with " .. name .. " at " .. label
                )
            end
        end
        records[label] = authoritative
    end
    local shot = 0
    local function impact(steps: number)
        for _, item in samples do
            for _ = 1, steps do
                shot += 1
                assert(
                    owner.resolve({
                        roundId = 1,
                        shotId = shot,
                        weapon = "M102",
                        firedAt = shot,
                        panelId = item.name,
                    })
                )
                owner.flush(shot)
            end
        end
    end
    observe("Pristine")
    impact(1)
    observe("Light")
    impact(2)
    observe("Heavy")
    impact(3)
    observe("Total")
    owner.sync(2)
    observe("Reset")
    for _, sample in samples do
        local name = sample.name
        local full = records.Pristine[name].hits
        local partial = records.Heavy[name].hits
        assert(full > 0 and partial > 0 and partial < full)
        assert(
            records.Light[name].hits == full
                and records.Total[name].hits == 0
                and records.Reset[name].hits == full
        )
    end
    owner.stop()
    return { clients = #Players:GetPlayers(), stages = records, hitsSubmitted = shot }
end)
test:EndTest(if ok then result else { error = tostring(result) })
