--!strict
--[=[
    GameRuntime: server composition root for map, round, aircraft and combat owners. Depends
    on engine Players/Heartbeat plus explicit MatchRuntime settings. Test runner owns
    a runtime after foundation suites without a global registry. stop tears down the
    combat, aircraft and round owners, then destroys the map snapshot.
]=]
local Players = game:GetService("Players")
local MapService = require(script.Parent.MapService)
local MatchRuntime = require(script.Parent.MatchRuntime)
local AircraftService = require(script.Parent.AircraftService)
local CombatRuntime = require(script.Parent.CombatRuntime)
local GroundCombatRuntime = require(script.Parent.GroundCombatRuntime)
local GameRuntime = {}
export type Controller = {
    rounds: MatchRuntime.Controller,
    aircraft: AircraftService.Controller,
    combat: CombatRuntime.Controller,
    groundCombat: GroundCombatRuntime.Controller,
    stop: () -> (),
}

-- Starts one map/round runtime or rejects startup without leaked ownership.
function GameRuntime.start(settings: MatchRuntime.Settings): (Controller?, string?)
    local onCorrection: ((Model) -> ())? = nil
    local map, reason = MapService.new(workspace.World, {
        characters = function()
            local characters: { Model } = {}
            for _, player in Players:GetPlayers() do
                if
                    player:GetAttribute("Role") == "Ground"
                    and player:GetAttribute("Life") == "Alive"
                    and player.Character
                then
                    table.insert(characters, player.Character)
                end
            end
            return characters
        end,
        heartbeat = game:GetService("RunService").Heartbeat,
        allowStations = false,
        corrected = function(character)
            if onCorrection then
                onCorrection(character)
            end
        end,
    })
    if not map then
        return nil, reason
    end
    local ok, startReason = map.start()
    if not ok then
        map.destroy()
        return nil, startReason
    end
    local rounds = MatchRuntime.new(map, settings)
    local started, roundReason = rounds.start()
    if not started then
        map.destroy()
        return nil, roundReason
    end
    local aircraft, aircraftReason = AircraftService.start(rounds.match)
    if not aircraft then
        rounds.stop()
        map.destroy()
        return nil, aircraftReason
    end
    local combat, combatReason = CombatRuntime.start(rounds.match, aircraft)
    if not combat then
        aircraft.stop()
        rounds.stop()
        map.destroy()
        return nil, combatReason
    end
    local groundCombat, groundReason = GroundCombatRuntime.start(rounds.match)
    if not groundCombat then
        combat.stop()
        aircraft.stop()
        rounds.stop()
        map.destroy()
        return nil, groundReason
    end
    onCorrection = function(character)
        local player = Players:GetPlayerFromCharacter(character)
        if player then
            groundCombat.trustCorrection(player)
        end
    end
    return {
        groundCombat = groundCombat,
        rounds = rounds,
        aircraft = aircraft,
        combat = combat,
        stop = function()
            onCorrection = nil
            groundCombat.stop()
            combat.stop()
            aircraft.stop()
            rounds.stop()
            map.destroy()
        end,
    },
        nil
end

return GameRuntime
