--!strict
-- P09 A2/A3: real aircraft spherecasts on either side of an injected deadline.
-- A controlled clock exercises exact equality without gambling on Heartbeat timing.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Server = game:GetService("ServerScriptService").Server
local AircraftService = require(Server.AircraftService)
local GroundCombatRuntime = require(Server.GroundCombatRuntime)
local MatchService = require(Server.MatchService)
local AircraftHealth = require(Server.AircraftHealth)

-- Production aircraft/ground adapters run against actual world and a pure match clock.
local function checkImpact(atSeconds: number, expectedReason: string)
    local seconds = 100
    local function now(): number
        return seconds
    end
    local match = MatchService.new({ minimumPlayers = 2, durationSeconds = 10, seed = 1 }, {
        now = now,
        releaseLife = function() end,
    })
    match.join(101)
    match.join(102)
    assert(match.deploy(), "deployment")
    local state = match.snapshot()
    assert(match.ready(101, state.roundId) and match.ready(102, state.roundId) and match.activate(), "active")
    local player = if state.members[101].role == "Ground" then 101 else 102
    local aircraft, aircraftReason = AircraftService.start(match, now, true)
    assert(aircraft, aircraftReason)
    local ground, groundReason = GroundCombatRuntime.start(match, nil, true)
    if not ground then
        aircraft.stop()
        error(tostring(groundReason))
    end
    local ok, problem = pcall(function()
        ground.maintain(now())
        local origin = aircraft.position() + Vector3.yAxis * 50
        local down = -Vector3.yAxis * 60
        local groundCount = 0
        for _, member in state.members do
            if member.role == "Ground" then
                groundCount += 1
            end
        end
        local maximum = assert(AircraftHealth.maximumFor(groundCount), "fixture Ground roster invalid")
        assert(
            ReplicatedStorage.AircraftState:GetAttribute("MaxHealth") == maximum,
            "roster health not initialized"
        )
        local remaining = AircraftHealth.rocketDamage
        local preDamageHits = (maximum - remaining) / AircraftHealth.rocketDamage
        assert(preDamageHits >= 0 and preDamageHits % 1 == 0, "fixture needs an integral fixed-rocket prefix")
        for index = 1, preDamageHits do
            local id = "pre-damage:" .. tostring(index)
            local hit, applied = ground.rocketCast(state.roundId, id, origin, down, player)
            assert(hit and applied, "real rocket collision unavailable")
        end
        assert(
            ReplicatedStorage.AircraftState:GetAttribute("Health") == remaining and remaining == 100,
            "roster-derived direct hits did not leave exactly one fixed 100-unit rocket"
        )
        seconds = atSeconds
        local damageBatchRan = false
        match.step(function()
            damageBatchRan = true
            assert(match.eliminate(player, state.roundId), "same-frame ground death was rejected")
            local hit, applied = ground.rocketCast(state.roundId, "lethal", origin, down, player)
            assert(hit and applied, "pre-deadline lethal rocket failed")
            local _, duplicate = ground.rocketCast(state.roundId, "lethal", origin, down, player)
            assert(not duplicate, "duplicate rocket counted")
        end)
        local ended = match.snapshot()
        local result = assert(ended.result, "expected one terminal result")
        assert(result.reason == expectedReason, "wrong result reason")
        if atSeconds < 110 then
            assert(
                damageBatchRan and result.winner == "Ground" and result.shotId == "lethal",
                "same-step lethal rocket did not win"
            )
            assert(
                result.userId == player and result.weapon == "RocketLauncher",
                "lethal aircraft credit is incorrect"
            )
            assert(
                ReplicatedStorage.AircraftState:GetAttribute("Health") == 0,
                "lethal collision did not destroy the aircraft"
            )
        else
            assert(
                not damageBatchRan and result.winner == "Gunship" and result.shotId == nil,
                "deadline did not block the expired damage batch"
            )
            assert(
                ReplicatedStorage.AircraftState:GetAttribute("Health") == 100,
                "expired rocket changed aircraft health"
            )
        end
        assert(not ground.rocketImpact(state.roundId, "late", true), "terminal rocket accepted")
        assert(match.snapshot().revision == ended.revision, "terminal result changed")
        return true
    end)
    ground.stop()
    aircraft.stop()
    assert(ok, tostring(problem))
end

return function()
    local test = getfenv().it :: (string, () -> ()) -> ()
    test("P09 A2 lethal rocket before deadline beats last-ground death in the same batch", function()
        checkImpact(109.999, "AircraftDestroyed")
    end)
    test("P09 A2 at exact deadline rockets do not award damage", function()
        checkImpact(110, "Timeout")
    end)
    test("P09 A2 after deadline rockets do not award damage", function()
        checkImpact(111, "Timeout")
    end)
end
