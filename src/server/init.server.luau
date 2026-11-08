--!strict
--[=[
    Server entrypoint: composes foundation and authoritative map/round lifetimes.
    Release settings use production defaults. The separate test runner owns gameplay
    startup after foundation suites finish; it never changes the production minimum.
]=]
local ServerStorage = game:GetService("ServerStorage")
local Bootstrap = require(script.Bootstrap)
local GameRuntime = require(script.GameRuntime)
local MatchRuntime = require(script.MatchRuntime)
local environment = if ServerStorage:FindFirstChild("DevelopmentSettings") then "Test" else "Development"
local runtime = Bootstrap.new(environment)
local ok, reason = runtime.start()
assert(ok, reason)
game:BindToClose(runtime.stop)
if not ServerStorage:FindFirstChild("DevelopmentSettings") then
    local gameRuntime, startReason = GameRuntime.start(MatchRuntime.defaults)
    assert(gameRuntime, startReason)
    game:BindToClose(gameRuntime.stop)
end
