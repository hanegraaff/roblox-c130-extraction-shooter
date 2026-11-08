--!strict
--[=[ Server entrypoint: owns one foundation Bootstrap. Test settings are absent in release builds. ]=]
local ServerStorage = game:GetService("ServerStorage")
local Bootstrap = require(script.Bootstrap)
local environment = if ServerStorage:FindFirstChild("DevelopmentSettings") then "Test" else "Development"
local runtime = Bootstrap.new(environment)
local ok, reason = runtime.start()
assert(ok, reason)
game:BindToClose(runtime.stop)
