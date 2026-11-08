--!strict
--[=[
    RoundRules: pure server-only phase and outcome policy. No engine dependencies/yields.
    Deadline wins at equality; aircraft destruction wins a pre-deadline mutual kill.
    Membership/departures are evaluated by MatchService and supplied as facts here.
]=]
local RoundRules = {}
export type Phase = "Lobby" | "Deploying" | "Active" | "Results" | "Resetting"
export type Result = { winner: string, reason: string }
export type Facts = {
    nowSeconds: number,
    deadlineSeconds: number,
    aircraftDestroyed: boolean,
    groundAlive: number,
    operatorConnected: boolean,
    connectedCount: number,
}

-- Reports legal lifecycle edges without mutation. Cancellation is Deploying -> Lobby.
function RoundRules.canTransition(from: Phase, to: Phase): boolean
    return (from == "Lobby" and to == "Deploying")
        or (from == "Deploying" and (to == "Active" or to == "Lobby" or to == "Results"))
        or (from == "Active" and to == "Results")
        or (from == "Results" and to == "Resetting")
        or (from == "Resetting" and to == "Lobby")
end

-- Returns a terminal proposal, or nil while play continues. Caller commits it once.
function RoundRules.outcome(facts: Facts): Result?
    if facts.nowSeconds >= facts.deadlineSeconds then
        return { winner = "Gunship", reason = "Timeout" }
    end
    if facts.aircraftDestroyed then
        return { winner = "Ground", reason = "AircraftDestroyed" }
    end
    if facts.connectedCount == 0 then
        return { winner = "None", reason = "EmptyServer" }
    end
    if facts.groundAlive == 0 then
        if not facts.operatorConnected then
            return { winner = "None", reason = "NoParticipants" }
        end
        return { winner = "Gunship", reason = "GroundEliminated" }
    end
    if not facts.operatorConnected then
        return { winner = "Ground", reason = "OperatorForfeit" }
    end
    return nil
end

return RoundRules
