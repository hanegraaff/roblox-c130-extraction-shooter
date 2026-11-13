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
local DestructionRuntime = require(script.Parent.DestructionRuntime)
local LauncherRuntime = require(script.Parent.LauncherRuntime)
local GameRuntime = {}
export type Controller = {
    rounds: MatchRuntime.Controller,
    aircraft: AircraftService.Controller,
    combat: CombatRuntime.Controller,
    destruction: DestructionRuntime.Controller,
    groundCombat: GroundCombatRuntime.Controller,
    launcher: LauncherRuntime.Controller,
    stop: () -> (),
}

-- Starts one map/round runtime or rejects startup without leaked ownership.
function GameRuntime.start(
    settings: MatchRuntime.Settings,
    groundDependencies: GroundCombatRuntime.Dependencies?
): (Controller?, string?)
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
    local destruction, destructionReason = DestructionRuntime.start(workspace.World)
    if not destruction then
        aircraft.stop()
        rounds.stop()
        map.destroy()
        return nil, destructionReason
    end
    destruction.sync(rounds.match.snapshot().roundId)
    local combat, combatReason = CombatRuntime.start(rounds.match, aircraft, nil, nil, nil, destruction)
    if not combat then
        destruction.stop()
        aircraft.stop()
        rounds.stop()
        map.destroy()
        return nil, combatReason
    end
    local groundCombat, groundReason = GroundCombatRuntime.start(rounds.match, groundDependencies)
    if not groundCombat then
        combat.stop()
        destruction.stop()
        aircraft.stop()
        rounds.stop()
        map.destroy()
        return nil, groundReason
    end
    local launcher, launcherReason = LauncherRuntime.start(rounds.match, groundCombat)
    if not launcher then
        groundCombat.stop()
        combat.stop()
        destruction.stop()
        aircraft.stop()
        rounds.stop()
        map.destroy()
        return nil, launcherReason
    end
    onCorrection = function(character)
        local player = Players:GetPlayerFromCharacter(character)
        if player then
            groundCombat.trustCorrection(player)
        end
    end
    return {
        launcher = launcher,
        groundCombat = groundCombat,
        rounds = rounds,
        aircraft = aircraft,
        combat = combat,
        destruction = destruction,
        stop = function()
            onCorrection = nil
            launcher.stop()
            groundCombat.stop()
            combat.stop()
            destruction.stop()
            aircraft.stop()
            rounds.stop()
            map.destroy()
        end,
    },
        nil
end

return GameRuntime
