--!strict
-- P30 A1 integrates actual match ordering with the deterministic pickup ledger.
type API = typeof(require(game:GetService("ServerScriptService").Server.MedkitService))
type MatchApi = typeof(require(game:GetService("ServerScriptService").Server.MatchService))
local load = (require :: unknown) :: (string) -> unknown
local Match = (
    if script
        then require(game:GetService("ServerScriptService").Server.MatchService)
        else load("../../src/server/MatchService")
) :: MatchApi

return function(test: (string, () -> ()) -> (), candidate: unknown)
    local medkit = candidate :: API
    test("P30 A1 lethal damage and committed outcomes take precedence over queued medkit uses", function()
        local time = 0
        local match = Match.new({ minimumPlayers = 3, durationSeconds = 120, seed = 1 }, {
            now = function()
                return time
            end,
            releaseLife = function() end,
        })
        match.join(1)
        match.join(2)
        match.join(3)
        assert(match.deploy())
        for id in match.snapshot().members do
            assert(match.ready(id, 1))
        end
        assert(match.activate())
        local living: { number } = {}
        for id, member in match.snapshot().members do
            if member.role == "Ground" then
                table.insert(living, id)
            end
        end
        assert(#living == 2, "fixture needs two living Ground players")
        local kit = medkit.new(1, 25, { "Bunker" })
        local function attempt(id: number, health: number): number?
            local latest = match.snapshot()
            return kit.use(latest, time, {
                roundId = 1,
                siteId = "Bunker",
                member = latest.members[id],
                health = health,
                maxHealth = 100,
                withinReach = true,
                clearSight = true,
            })
        end
        time = 1
        local doomedHealth = 30
        match.step(function()
            doomedHealth = 0
            assert(match.eliminate(living[1], 1))
        end, time)
        assert(match.snapshot().phase == "Active", "the other Ground participant is still alive")
        assert(
            attempt(living[1], doomedHealth) == nil and kit.available("Bunker"),
            "lethal damage allowed healing or spent the kit"
        )
        time = 2
        match.step(function()
            assert(match.proposeAircraftDestroyed(1))
        end, time)
        assert(match.snapshot().phase == "Results", "the damage batch must commit the result")
        assert(
            attempt(living[2], 30) == nil and kit.available("Bunker"),
            "committed result allowed healing or spent the kit"
        )
    end)
end
