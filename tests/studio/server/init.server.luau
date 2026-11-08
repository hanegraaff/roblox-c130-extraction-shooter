--!strict
-- Test-only server entrypoint. Waits for real bootstrap, runs TestEZ, publishes bounded JSON report.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")
-- Vendor TestEZ is untyped. Narrow its public API once instead of disabling analysis.
type TestResults = { successCount: number, failureCount: number, skippedCount: number, errors: { unknown } }
type TestFramework = { TestBootstrap: { run: (unknown, { Instance }) -> TestResults } }
local TestEZ = (require(ReplicatedStorage.TestPackages.TestEZ) :: unknown) :: TestFramework
assert(ReplicatedStorage:WaitForChild("BootstrapStatus", 10), "server bootstrap timeout")
local Players = game:GetService("Players")
local deadline = os.clock() + 10
while #Players:GetPlayers() == 0 and os.clock() < deadline do
    task.wait()
end
assert(#Players:GetPlayers() > 0, "server smoke requires a real client within 10 seconds")
local results = TestEZ.TestBootstrap:run({ ServerStorage.Tests.Studio })
local count = results.successCount + results.failureCount + results.skippedCount
local report = {
    suite = "P01-server",
    discovered = count,
    passed = results.successCount,
    failed = results.failureCount,
    skipped = results.skippedCount,
    errors = #results.errors,
    environment = "Studio",
    seed = 1,
    clientCount = #game:GetService("Players"):GetPlayers(),
}
workspace:SetAttribute("ServerTestReport", HttpService:JSONEncode(report))
assert(
    count > 0 and report.failed == 0 and report.skipped == 0 and report.errors == 0,
    "server suite failed or empty"
)
-- Explicit ownership avoids round map rebuilds racing the foundational map suites.
require(script.RoundHarness).run()
