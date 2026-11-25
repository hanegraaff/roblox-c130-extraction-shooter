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
script:SetAttribute("P17ManualTestErrors", HttpService:JSONEncode(results.errors))
assert(
    count > 0 and report.failed == 0 and report.skipped == 0 and report.errors == 0,
    "client suite failed or empty"
)
-- One trusted server string commits readiness and selection together. Waiters
-- for later stages must not attach before their coordinator explicitly runs them.
local manualReadyDeadline = os.clock() + 10
while ReplicatedStorage:GetAttribute("ManualClientHarness") == nil and os.clock() < manualReadyDeadline do
    task.wait()
end
local manualMode = ReplicatedStorage:GetAttribute("ManualClientHarness")
assert(type(manualMode) == "string", "server manual-client dispatch readiness timeout")
if manualMode == "P24" then
    require(script.AircraftArrivalHarness).run()
    return
elseif manualMode == "P18" then
    require(script.RebalanceHarness).run()
    return
elseif manualMode == "P08" then
    require(script.LauncherHarness).run()
    return
elseif manualMode == "P09" then
    require(script.MatchOutcomeHarness).run()
    return
elseif manualMode == "P10" then
    require(script.PlayerExperienceHarness).run()
    return
elseif manualMode == "P19Profile" then
    require(script.PerformanceHarness).profile()
    return
elseif manualMode == "P11" then
    require(script.PerformanceHarness).run()
    return
elseif manualMode == "P17" then
    require(script.P17MaterialHarness).run()
    return
elseif manualMode == "P07" or manualMode == "Sandbreak" then
    require(script.DestructionHarness).run()
    return
elseif manualMode == "P05" then
    require(script.CombatHarness).run()
    return
elseif manualMode == "P14" then
    require(script.AircraftPanHarness).run()
    return
end
-- Current ordinary exploration keeps compatible lifecycle/map observers only.
-- Historical balance/camera waiters are no longer started on current source.
require(script.CombatHarness).run()
require(script.RoundHarness).run()
require(script.AircraftHarness).run()
require(script.ExpandedMapHarness).run()
local stopTestPanel = require(script.HumanTestPanel).start()
script.Destroying:Connect(stopTestPanel)
