--!strict
--[=[
    GameRuntime: server composition root for map and round owners. Depends on engine
    Players/Heartbeat plus explicit MatchRuntime settings. Test runner owns a runtime
    after foundation suites without a global registry. stop destroys the map snapshot.
]=]
local Players = game:GetService("Players")
local MapService = require(script.Parent.MapService)
local MatchRuntime = require(script.Parent.MatchRuntime)
local GameRuntime = {}
export type Controller = { rounds: MatchRuntime.Controller, stop: () -> () }

-- Starts one map/round runtime or rejects startup without leaked ownership.
function GameRuntime.start(settings: MatchRuntime.Settings): (Controller?, string?)
    local map, reason = MapService.new(workspace.World, {
        characters = function()
            local characters: { Model } = {}
            for _, player in Players:GetPlayers() do
                if
                    player:GetAttribute("Role") == "Ground"
                    and player:GetAttribute("Life") == "Alive"
                    and player.Character
                then
                    table.insert(characters, player.Character)
                end
            end
            return characters
        end,
        heartbeat = game:GetService("RunService").Heartbeat,
        allowStations = false,
    })
    if not map then
        return nil, reason
    end
    local ok, startReason = map.start()
    if not ok then
        map.destroy()
        return nil, startReason
    end
    local rounds = MatchRuntime.new(map, settings)
    local started, roundReason = rounds.start()
    if not started then
        map.destroy()
        return nil, roundReason
    end
    return {
        rounds = rounds,
        stop = function()
            rounds.stop()
            map.destroy()
        end,
    },
        nil
end

return GameRuntime
