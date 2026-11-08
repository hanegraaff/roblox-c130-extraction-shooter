--!strict
--[=[
    P03 A6 regression: stop while real LoadCharacterAsync calls are in flight.
    Runs after multiplayer round teardown, with at least one actual client. Exercises
    actual GameRuntime owners, leases, accounting, acquisition rejection and drain.
    No fake avatar loader or timing adapter can satisfy these engine assertions.
]=]
local Players = game:GetService("Players")
local GameRuntime = require(game:GetService("ServerScriptService").Server.GameRuntime)
local CharacterCleanup = {}

-- Yields for real avatar-load drain, bounded to thirty seconds; failure remains visible.
local function awaitDrain(runtime: GameRuntime.Controller)
    local deadline = os.clock() + 30
    while runtime.rounds.resources().spawnTasks > 0 and os.clock() < deadline do
        task.wait(0.05)
    end
    assert(runtime.rounds.resources().spawnTasks == 0, "actual character load teardown timed out")
end

-- Runs a two-owner acquisition regression and leaves no character/runtime ownership.
function CharacterCleanup.run()
    assert(#Players:GetPlayers() > 0, "pending-load regression requires an actual client")
    local oldAutoLoads = Players.CharacterAutoLoads
    local settings = {
        minimumPlayers = 6,
        durationSeconds = 600,
        lobbySeconds = 60,
        deploymentSeconds = 25,
        resultsSeconds = 3,
        seed = 1,
    }
    local runtime, reason = GameRuntime.start(settings)
    assert(runtime, reason)
    local pending = runtime.rounds.resources().spawnTasks
    runtime.stop()
    assert(pending > 0, "fixture did not exercise pending actual LoadCharacterAsync")
    assert(runtime.rounds.resources().spawnTasks > 0, "stopped owner falsely reported zero pending loads")
    assert(not Players.CharacterAutoLoads, "automatic spawning restored before old loads drained")
    local premature, rejection = GameRuntime.start(settings)
    if premature then
        premature.stop()
    end
    assert(
        not premature and rejection == "previous character loads are still draining",
        "new owner acquired characters before old loads drained"
    )
    awaitDrain(runtime)
    assert(Players.CharacterAutoLoads == oldAutoLoads, "automatic spawning was not restored after drain")
    local restarted, restartReason = GameRuntime.start(settings)
    assert(restarted, restartReason)
    restarted.stop()
    awaitDrain(restarted)
    assert(restarted.rounds.resources().connections == 0, "restarted owner leaked connections")
    assert(Players.CharacterAutoLoads == oldAutoLoads, "second teardown did not restore automatic spawning")
end

return CharacterCleanup
