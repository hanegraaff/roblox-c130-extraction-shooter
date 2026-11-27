--!strict
--[=[
    GameRuntime: server composition root for map, round, aircraft and combat owners. Depends
    on engine Players/Heartbeat plus explicit MatchRuntime settings. Test runner owns
    a runtime after foundation suites without a global registry. stop tears down the
    combat, aircraft and round owners, then destroys the map snapshot.
]=]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WeaponSoundRules = require(ReplicatedStorage.Shared.WeaponSoundRules)
local WeaponImpactRules = require(ReplicatedStorage.Shared.WeaponImpactRules)
local RunService = game:GetService("RunService")
local MapService = require(script.Parent.MapService)
local MatchRuntime = require(script.Parent.MatchRuntime)
local AircraftService = require(script.Parent.AircraftService)
local CombatRuntime = require(script.Parent.CombatRuntime)
local GroundCombatRuntime = require(script.Parent.GroundCombatRuntime)
local DestructionRuntime = require(script.Parent.DestructionRuntime)
local LauncherRuntime = require(script.Parent.LauncherRuntime)
local OutpostReconstruction = require(script.Parent.OutpostReconstruction)
local VesperReconstruction = require(script.Parent.VesperReconstruction)
local SaltFlatsReconstruction = require(script.Parent.SaltFlatsReconstruction)
local SandbreakReconstruction = require(script.Parent.SandbreakReconstruction)
local SeedshipReconstruction = require(script.Parent.SeedshipReconstruction)
local BalanceRuntime = require(script.Parent.BalanceRuntime)
local GameRuntime = {}
export type Controller = {
    rounds: MatchRuntime.Controller,
    aircraft: AircraftService.Controller,
    combat: CombatRuntime.Controller,
    destruction: DestructionRuntime.Controller,
    groundCombat: GroundCombatRuntime.Controller,
    launcher: LauncherRuntime.Controller,
    resources: () -> { frameConnections: number },
    stop: () -> (),
}

-- Starts one map/round runtime or rejects startup without leaked ownership.
function GameRuntime.start(
    settings: MatchRuntime.Settings,
    groundDependencies: GroundCombatRuntime.Dependencies?,
    balanceDependencies: BalanceRuntime.Dependencies?
): (Controller?, string?)
    local assets = game:GetService("ServerStorage").Assets
    local installation, installReason = OutpostReconstruction.install(workspace.World, assets)
    if not installation then
        return nil, installReason
    end
    local radar, radarReason = VesperReconstruction.install(workspace.World, assets)
    if not radar then
        installation.rollback()
        return nil, radarReason
    end
    local hangar, hangarReason = SaltFlatsReconstruction.install(workspace.World, assets)
    if not hangar then
        radar.rollback()
        installation.rollback()
        return nil, hangarReason
    end
    local bunker, bunkerReason = SandbreakReconstruction.install(workspace.World, assets)
    if not bunker then
        hangar.rollback()
        radar.rollback()
        installation.rollback()
        return nil, bunkerReason
    end
    local seedship, seedshipReason = SeedshipReconstruction.install(workspace.World, assets)
    if not seedship then
        bunker.rollback()
        hangar.rollback()
        radar.rollback()
        installation.rollback()
        return nil, seedshipReason
    end
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
        heartbeat = RunService.Heartbeat,
        allowStations = false,
        corrected = function(character)
            if onCorrection then
                onCorrection(character)
            end
        end,
    })
    if not map then
        seedship.rollback()
        bunker.rollback()
        hangar.rollback()
        radar.rollback()
        installation.rollback()
        return nil, reason
    end
    seedship.commit()
    bunker.commit()
    hangar.commit()
    radar.commit()
    installation.commit()
    local ok, startReason = map.start()
    if not ok then
        map.destroy()
        return nil, startReason
    end
    local matchRoster: MatchRuntime.Controller? = nil
    local balance, balanceReason = BalanceRuntime.start(balanceDependencies, function()
        if matchRoster then
            local state = matchRoster.match.snapshot()
            if state.phase == "Deploying" or state.phase == "Scatter" or state.phase == "Active" then
                local count = 0
                for _, member in state.members do
                    if member.role == "Ground" then
                        count += 1
                    end
                end
                return count
            end
        end
        return math.clamp(#Players:GetPlayers() - 1, 0, 9)
    end)
    if not balance then
        map.destroy()
        return nil, balanceReason
    end
    local rounds = MatchRuntime.new(map, settings, balance)
    matchRoster = rounds
    local started, roundReason = rounds.start()
    if not started then
        balance.stop()
        map.destroy()
        return nil, roundReason
    end
    local soundEvent: UnreliableRemoteEvent? = nil
    local impactEvent: RemoteEvent? = nil
    local emitSound: WeaponSoundRules.Emit = function(cue, roundId, origin, seconds, shooter, surface)
        if soundEvent then
            soundEvent:FireAllClients(cue, roundId, origin, seconds, shooter, surface)
        end
    end
    local emitImpact: WeaponImpactRules.Emit = function(
        weapon,
        roundId,
        shotId,
        contact,
        normal,
        surface,
        seconds
    )
        if impactEvent then
            impactEvent:FireAllClients(weapon, roundId, shotId, contact, normal, surface, seconds)
        end
    end
    local aircraft, aircraftReason = AircraftService.start(rounds.match, nil, true)
    if not aircraft then
        rounds.stop()
        balance.stop()
        map.destroy()
        return nil, aircraftReason
    end
    local destruction, destructionReason = DestructionRuntime.start(workspace.World, nil, balance.getBalance)
    if not destruction then
        aircraft.stop()
        rounds.stop()
        balance.stop()
        map.destroy()
        return nil, destructionReason
    end
    destruction.sync(rounds.match.snapshot().roundId)
    local combat, combatReason = CombatRuntime.start(
        rounds.match,
        aircraft,
        nil,
        nil,
        nil,
        destruction,
        true,
        emitSound,
        emitImpact,
        balance.getBalance
    )
    if not combat then
        destruction.stop()
        aircraft.stop()
        rounds.stop()
        balance.stop()
        map.destroy()
        return nil, combatReason
    end
    local groundCombat, groundReason =
        GroundCombatRuntime.start(rounds.match, groundDependencies, true, emitSound, balance.getBalance)
    if not groundCombat then
        combat.stop()
        destruction.stop()
        aircraft.stop()
        rounds.stop()
        balance.stop()
        map.destroy()
        return nil, groundReason
    end
    local launcher, launcherReason =
        LauncherRuntime.start(rounds.match, groundCombat, true, emitSound, emitImpact, balance.getBalance)
    if not launcher then
        groundCombat.stop()
        combat.stop()
        destruction.stop()
        aircraft.stop()
        rounds.stop()
        balance.stop()
        map.destroy()
        return nil, launcherReason
    end
    local roundState = assert(ReplicatedStorage:FindFirstChild("RoundState"), "round state missing")
    local transport = Instance.new("UnreliableRemoteEvent")
    transport.Name = "WeaponAudio"
    transport.Parent = roundState
    soundEvent = transport
    local contactTransport = Instance.new("RemoteEvent")
    contactTransport.Name = "WeaponImpact"
    contactTransport.Parent = roundState
    impactEvent = contactTransport
    onCorrection = function(character)
        local player = Players:GetPlayerFromCharacter(character)
        if player then
            groundCombat.trustCorrection(player)
        end
    end
    -- One ordered frame owns match damage and interactions. All casts observe
    -- the same pre-impact cover and deadline. Phase publication and equipment
    -- cleanup follow the result commit, before launcher intent is processed.
    -- The phase callback attaches the aircraft at reveal before clients are
    -- given the Active phase. Activation cannot resolve an earlier fire intent.
    local frame = RunService.Heartbeat:Connect(function(dt)
        local time = workspace:GetServerTimeNow()
        aircraft.step(time)
        rounds.step(time, function(batchSeconds)
            combat.advance(batchSeconds, dt)
            groundCombat.resolveRifles()
            launcher.advance(batchSeconds)
            destruction.flush(batchSeconds)
        end, aircraft.step)
        if rounds.match.snapshot().phase ~= "Active" then
            destruction.flush(time)
        end
        combat.maintain(time)
        groundCombat.maintain(time)
        launcher.interact(time)
    end)
    return {
        launcher = launcher,
        groundCombat = groundCombat,
        rounds = rounds,
        aircraft = aircraft,
        combat = combat,
        destruction = destruction,
        resources = function()
            return { frameConnections = if frame.Connected then 1 else 0 }
        end,
        stop = function()
            frame:Disconnect()
            soundEvent = nil
            transport:Destroy()
            impactEvent = nil
            contactTransport:Destroy()
            onCorrection = nil
            launcher.stop()
            groundCombat.stop()
            combat.stop()
            destruction.stop()
            aircraft.stop()
            rounds.stop()
            balance.stop()
            map.destroy()
        end,
    },
        nil
end

return GameRuntime
