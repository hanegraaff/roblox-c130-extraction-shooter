--!strict
-- Test-only TestEZ entrypoint for human-control engine specs. Called before any manual
-- round owner exists; the spec owns and tears down its real GameRuntime/session fixture.
local Check = {}
type Results = { successCount: number, failureCount: number, skippedCount: number, errors: { unknown } }
type Framework = { TestBootstrap: { run: (unknown, { Instance }) -> Results } }

-- Yields within bounded engine specs and returns actual TestEZ totals.
function Check.run()
    local framework = (require(game.ReplicatedStorage.TestPackages.TestEZ) :: unknown) :: Framework
    local result = framework.TestBootstrap:run({ script.Parent["HumanTestSession.spec"] })
    return {
        suite = "HumanTestControls",
        discovered = result.successCount + result.failureCount + result.skippedCount,
        passed = result.successCount,
        failed = result.failureCount,
        skipped = result.skippedCount,
        errors = #result.errors,
        clientCount = #game.Players:GetPlayers(),
    }
end

return Check
