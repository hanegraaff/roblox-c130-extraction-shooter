--!strict
-- Test-only client entrypoint. Executes actual LocalPlayer/GUI specs and keeps report on PlayerScripts.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
-- Vendor TestEZ is untyped. Narrow its public API once instead of disabling analysis.
type TestResults = { successCount: number, failureCount: number, skippedCount: number, errors: { unknown } }
type TestFramework = { TestBootstrap: { run: (unknown, { Instance }) -> TestResults } }
local TestEZ = (require(ReplicatedStorage.TestPackages.TestEZ) :: unknown) :: TestFramework
local results = TestEZ.TestBootstrap:run({ ReplicatedStorage.ClientSpecs })
local count = results.successCount + results.failureCount + results.skippedCount
local report = {
    suite = "P01-client",
    discovered = count,
    passed = results.successCount,
    failed = results.failureCount,
    skipped = results.skippedCount,
    errors = #results.errors,
    environment = "Studio",
    seed = 1,
    userId = game:GetService("Players").LocalPlayer.UserId,
}
script:SetAttribute("ClientTestReport", HttpService:JSONEncode(report))
assert(
    count > 0 and report.failed == 0 and report.skipped == 0 and report.errors == 0,
    "client suite failed or empty"
)
require(script.RoundHarness).run()
require(script.AircraftHarness).run()
require(script.AircraftPanHarness).run()
require(script.ExpandedMapHarness).run()
local stopTestPanel = require(script.HumanTestPanel).start()
script.Destroying:Connect(stopTestPanel)
