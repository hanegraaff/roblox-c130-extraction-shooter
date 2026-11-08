--!strict
--[=[ Server entrypoint: owns one foundation Bootstrap. Test settings are absent in release builds. ]=]
local ServerStorage = game:GetService("ServerStorage")
local Bootstrap = require(script.Bootstrap)
local MapService = require(script.MapService)
local Players = game:GetService("Players")
local map, mapReason = MapService.new(workspace.World, {
    characters = function()
        local characters: { Model } = {}
        for _, player in Players:GetPlayers() do
            if player.Character then
                table.insert(characters, player.Character)
            end
        end
        return characters
    end,
    heartbeat = game:GetService("RunService").Heartbeat,
})
assert(map, mapReason)
local mapStarted, startReason = map.start()
assert(mapStarted, startReason)
game:BindToClose(map.destroy)
local environment = if ServerStorage:FindFirstChild("DevelopmentSettings") then "Test" else "Development"
local runtime = Bootstrap.new(environment)
local ok, reason = runtime.start()
assert(ok, reason)
game:BindToClose(runtime.stop)
