--!strict
--[=[
    PlayerPresentation: deterministic, client-facing views of authoritative round
    facts. It has no Roblox dependencies or input, transport, time or combat authority.
    All functions are nonyielding. Deadlines and sampled times use server-clock seconds.
]=]
local PlayerPresentation = {}

export type View =
    "Waiting"
    | "Deploying"
    | "GroundScatter"
    | "OperatorArrival"
    | "Ground"
    | "Operator"
    | "Spectator"
    | "RoundLobby"
    | "Results"
    | "Resetting"
    | "GroundPreview"
    | "OperatorPreview"
export type Intensity = "Off" | "Reduced" | "Full"
export type Result = { roundId: number, winner: string, reason: string }
export type Readiness = {
    ammo: number,
    reloadUntil: number,
    nextFire: number?,
    capacity: number?,
    reserve: number?,
}
export type GroundAction = "Pickup" | "Drop" | "Reload"

local winners: { [string]: string } = {
    Ground = "Ground team wins",
    Gunship = "C-130 wins",
    None = "Round ended",
}
local reasons: { [string]: string } = {
    AircraftDestroyed = "The C-130 was destroyed.",
    GroundEliminated = "All ground players were eliminated.",
    GroundDeparted = "The last ground player left the round.",
    Timeout = "The C-130 survived until time ran out.",
    OperatorForfeit = "The C-130 operator left the round.",
    NoParticipants = "Both sides left the round.",
    EmptyServer = "All players left the server.",
    DeploymentTimeout = "The teams could not deploy in time.",
    CharacterLoadFailed = "A team could not deploy.",
    CharacterIncomplete = "A team could not deploy.",
    DeadDeploymentCharacter = "A player was lost during deployment.",
    DeathDuringDeployment = "A player was lost during deployment.",
    CharacterRemovedDuringDeployment = "A player was lost during deployment.",
}

-- Resolves round ownership and Studio preview without granting any action permission.
function PlayerPresentation.view(
    phase: unknown,
    role: unknown,
    life: unknown,
    previewRole: unknown,
    watching: boolean?
): View
    if phase == "Deploying" then
        return "Deploying"
    elseif phase == "Results" then
        return "Results"
    elseif phase == "Resetting" then
        return "Resetting"
    elseif phase == "Lobby" and previewRole == "Gunship" then
        return "OperatorPreview"
    elseif phase == "Lobby" and previewRole == "Ground" then
        return "GroundPreview"
    elseif phase == "Scatter" then
        if life == "Alive" and role == "Ground" then
            return "GroundScatter"
        elseif life == "Alive" and role == "Gunship" then
            return "OperatorArrival"
        end
        return "RoundLobby"
    elseif phase == "Active" then
        if life == "Alive" and role == "Ground" then
            return "Ground"
        elseif life == "Alive" and role == "Gunship" then
            return "Operator"
        end
        return if watching then "Spectator" else "RoundLobby"
    end
    return "Waiting"
end

-- The displayed pair belongs to the same round. Unknown future reasons use a
-- readable cancellation fallback and a delayed prior result is discarded.
function PlayerPresentation.resultText(result: Result?, roundId: number): string
    if not result or result.roundId ~= roundId then
        return "Round ended"
    end
    return (winners[result.winner] or "Round ended")
        .. "\n"
        .. (reasons[result.reason] or "The round was canceled.")
end

-- Returns a whole-second countdown rounded up, or nil for an unavailable
-- deadline. Invalid or nonfinite replication never enters time formatting.
function PlayerPresentation.remaining(deadline: unknown, now: number): number?
    if type(deadline) ~= "number" or deadline ~= deadline or math.abs(deadline) == math.huge then
        return nil
    end
    return math.max(0, math.ceil(deadline - now))
end

-- Reads the shared arrival deadline on the current frame, including a delayed
-- first render. The deadline can be missing while assignment is replicating.
function PlayerPresentation.arrivalText(deadline: unknown, now: number): string
    local seconds = if type(deadline) == "number" and deadline > 0
        then PlayerPresentation.remaining(deadline, now)
        else nil
    return if seconds then string.format("C-130 arrives in %d", seconds) else "Preparing deployment"
end

-- Returns the share of aircraft health in [0, 1] or nil while state is incomplete.
-- A replicated destruction flag is decisive even if health is still arriving.
function PlayerPresentation.aircraftFraction(health: unknown, maximum: unknown, destroyed: boolean): number?
    if destroyed then
        return 0
    end
    if
        type(health) ~= "number"
        or type(maximum) ~= "number"
        or maximum < 1
        or not (maximum < math.huge and health >= 0 and health <= maximum)
    then
        return nil
    end
    return health / maximum
end

-- Keeps numeric health or the terminal label available independently of color.
function PlayerPresentation.aircraftText(health: unknown, maximum: unknown, destroyed: boolean): string?
    local fraction = PlayerPresentation.aircraftFraction(health, maximum, destroyed)
    if fraction == nil then
        return nil
    elseif fraction == 0 then
        return "C-130 DESTROYED"
    end
    return string.format("C-130 HEALTH  %d / %d", health :: number, maximum :: number)
end

-- Chooses only from a caller-filtered set of live teammate IDs. With direction
-- zero it retains a valid choice; otherwise it picks the next ID and wraps.
-- An invalidated choice resumes on its successor, or returns nil if no one lives.
function PlayerPresentation.spectatorTarget(
    candidates: { number },
    current: number?,
    direction: number
): number?
    local backwards = direction < 0
    local edge: number? = nil
    local adjacent: number? = nil
    for _, candidate in candidates do
        if direction == 0 and candidate == current then
            return candidate
        end
        if not edge or (if backwards then candidate > edge else candidate < edge) then
            edge = candidate
        end
        if current and (if backwards then candidate < current else candidate > current) then
            if not adjacent or (if backwards then candidate > adjacent else candidate < adjacent) then
                adjacent = candidate
            end
        end
    end
    return adjacent or edge
end

local titles: { [View]: string } = table.freeze({
    Ground = "GROUND TEAM",
    GroundScatter = "GROUND TEAM",
    Operator = "C-130 OPERATOR",
    OperatorArrival = "C-130 OPERATOR",
    Deploying = "DEPLOYING",
    Results = "ROUND RESULTS",
    Resetting = "RESTORING BATTLEFIELD",
    RoundLobby = "ROUND IN PROGRESS",
    GroundPreview = "STUDIO GROUND PREVIEW",
    OperatorPreview = "STUDIO OPERATOR PREVIEW",
    Waiting = "WAITING FOR PLAYERS",
})

-- Status-only round title. Lobby onboarding is independent of this view.
function PlayerPresentation.title(view: View, eliminated: boolean): string
    if view == "Spectator" then
        return if eliminated then "ELIMINATED • SPECTATING" else "SPECTATING"
    end
    if view == "RoundLobby" and eliminated then
        return "ELIMINATED • BACK IN THE LOBBY"
    end
    return titles[view]
end

-- Required HUD warnings are separate from optional effects. This text
-- translates only presentation-visible launcher state and ownership.
function PlayerPresentation.launcherText(
    state: string?,
    owns: boolean,
    nearby: boolean,
    carrier: string?
): string
    if state == "Available" then
        return if nearby then "LAUNCHER • E / PICK UP" else "LAUNCHER • available on the map"
    elseif state == "Held" then
        return if owns
            then "LAUNCHER • yours • G to drop"
            else "LAUNCHER • carried by " .. (carrier or "teammate")
    elseif state == "Recovering" then
        return "LAUNCHER • returning to the map"
    end
    return "LAUNCHER • unavailable"
end

-- Computes UI-only reasons why pressing a Ground action button cannot
-- currently succeed. Nil leaves the normal authoritative request path intact.
function PlayerPresentation.groundRejection(
    action: GroundAction,
    active: boolean,
    launcherState: string?,
    owns: boolean,
    nearby: boolean,
    rifle: Readiness?,
    now: number
): string?
    if not active then
        return "Actions are available to living Ground players."
    elseif action == "Pickup" then
        if owns then
            return "You already carry the launcher."
        elseif launcherState ~= "Available" then
            return "The launcher is unavailable."
        elseif not nearby then
            return "Move closer to pick up the launcher."
        end
    elseif action == "Drop" and not owns then
        return "You aren't carrying the launcher."
    elseif action == "Reload" then
        if not rifle then
            return "Equip the M-7 to reload."
        elseif rifle.reloadUntil > now then
            return "M-7 reload is already in progress."
        elseif rifle.capacity and rifle.ammo >= rifle.capacity then
            return "The M-7 magazine is full."
        elseif rifle.reserve == 0 then
            return "No M-7 reserve ammunition remains."
        end
    end
    return nil
end

-- Replicated ammunition and per-weapon timers are rendered in text so
-- readiness is available independently of sound or color.
function PlayerPresentation.weaponText(readiness: Readiness?, now: number): string
    if not readiness then
        return "Readiness updating"
    end
    local reload = readiness.reloadUntil - now
    local cooldown = (readiness.nextFire or 0) - now
    local unit = if readiness.ammo == 1 then "round" else "rounds"
    if reload > 0 then
        return string.format("Reload %.1fs", reload)
    elseif cooldown > 0 then
        return string.format("%d %s • Cooldown %.1fs", readiness.ammo, unit, cooldown)
    end
    return string.format("%d %s ready", readiness.ammo, unit)
end

-- Local settings cycle through a bounded set independently. Wave amplitude
-- or volume scale is never consumed by game state, damage or active aim.
function PlayerPresentation.cycleIntensity(current: Intensity, backwards: boolean): Intensity
    if current == "Full" then
        return if backwards then "Reduced" else "Off"
    elseif current == "Reduced" then
        return if backwards then "Off" else "Full"
    end
    return if backwards then "Full" else "Reduced"
end

function PlayerPresentation.intensity(current: Intensity): number
    return if current == "Full" then 1 elseif current == "Reduced" then 0.35 else 0
end

return PlayerPresentation
