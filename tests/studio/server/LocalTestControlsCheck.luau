--!strict
-- Explicit TestEZ engine gate for server-only local shortcuts, after GameRuntime starts.
-- Uses one or two real clients; reports actual discovery/failure counts to its caller.
local Check = {}
type Results = { successCount: number, failureCount: number, skippedCount: number, errors: { unknown } }
type Framework = { TestBootstrap: { run: (unknown, { Instance }) -> Results } }

-- Yields only within bounded specs. The caller owns runtime and test-session cleanup.
function Check.run()
    local framework = (require(game.ReplicatedStorage.TestPackages.TestEZ) :: unknown) :: Framework
    local results = framework.TestBootstrap:run({ script.Parent["LocalTestControls.spec"] })
    return {
        suite = "LobbyControls",
        discovered = results.successCount + results.failureCount + results.skippedCount,
        passed = results.successCount,
        failed = results.failureCount,
        skipped = results.skippedCount,
        errors = #results.errors,
        clientCount = #game.Players:GetPlayers(),
    }
end

return Check
