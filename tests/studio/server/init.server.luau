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
-- Native Studio may start player processes well after the server. This budget
-- is separate from the harness's roster and gameplay deadlines.
local clientArrivalBudget = 60
local arrivalStarted = os.clock()
local deadline = arrivalStarted + clientArrivalBudget
local function publishArrival(status: string)
    local observation = {
        status = status,
        elapsedSeconds = os.clock() - arrivalStarted,
        budgetSeconds = clientArrivalBudget,
        clientCount = #Players:GetPlayers(),
    }
    workspace:SetAttribute("ServerTestStartup", HttpService:JSONEncode(observation))
    return observation
end
publishArrival("waiting-for-first-client")
local nextObservation = arrivalStarted + 1
while #Players:GetPlayers() == 0 and os.clock() < deadline do
    task.wait(0.05)
    if os.clock() >= nextObservation then
        publishArrival("waiting-for-first-client")
        nextObservation = os.clock() + 1
    end
end
if #Players:GetPlayers() == 0 then
    local failure = publishArrival("first-client-timeout")
    workspace:SetAttribute(
        "ServerTestReport",
        HttpService:JSONEncode({
            suite = "P01-server",
            environment = "Studio",
            discovered = 0,
            passed = 0,
            failed = 1,
            skipped = 0,
            errors = 1,
            clientCount = failure.clientCount,
            startup = failure,
        })
    )
    error("server smoke requires a real client: " .. HttpService:JSONEncode(failure))
end
publishArrival("first-client-arrived")
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
