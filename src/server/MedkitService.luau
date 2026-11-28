--!strict
--[=[
    MedkitService: deterministic server ledger for one round's healing sites.
    Reads the MatchService snapshot and trusted health/reach observations. Owns
    single-use availability until the runtime replaces the ledger at deployment.
    All operations are synchronous. The adapter applies the returned HP in the
    same server step without yielding or invoking other gameplay work.
]=]
local loadPath = (require :: unknown) :: (string) -> unknown
local Validation = (
    if script
        then require(game:GetService("ReplicatedStorage").Shared.Validation)
        else loadPath("../shared/Validation")
) :: typeof(require(game:GetService("ReplicatedStorage").Shared.Validation))
local MedkitService = {}

type Round = {
    roundId: number,
    phase: "Lobby" | "Deploying" | "Scatter" | "Active" | "Results" | "Resetting",
    deadlineSeconds: number,
}
type Member = { connected: boolean, role: string, life: string }

-- The transport supplies a server-owned round and site identity. Position and
-- health are observed at resolution, after the frame's damage and outcome work.
export type Attempt = {
    roundId: number,
    siteId: string,
    member: Member?,
    health: number,
    maxHealth: number,
    withinReach: boolean,
    clearSight: boolean,
}

export type Controller = {
    available: (string) -> boolean,
    -- Consumes one available site on success and returns the healed HP. Rejections
    -- return nil and leave the site available for the next eligible attempt.
    use: (Round, number, Attempt) -> number?,
}

-- Checks the authoritative participant and phase, using server clock seconds.
function MedkitService.eligible(round: Round, member: Member?, now: number): boolean
    return (round.phase == "Scatter" or (round.phase == "Active" and now < round.deadlineSeconds))
        and member ~= nil
        and member.connected
        and member.role == "Ground"
        and member.life == "Alive"
end

-- Snapshots trusted deployment settings. Amount and all health values are in HP.
function MedkitService.new(roundId: number, healAmount: number, siteIds: { string }): Controller
    assert(Validation.isFinite(healAmount) and healAmount > 0, "invalid medkit heal amount")
    local available: { [string]: boolean } = {}
    for _, id in siteIds do
        available[id] = true
    end
    return {
        available = function(siteId)
            return available[siteId] == true
        end,
        use = function(round, now, attempt)
            if
                round.roundId ~= roundId
                or attempt.roundId ~= roundId
                or not available[attempt.siteId]
                or not MedkitService.eligible(round, attempt.member, now)
                or not attempt.withinReach
                or not attempt.clearSight
                or not Validation.isFinite(attempt.health)
                or not Validation.isFinite(attempt.maxHealth)
                or attempt.health <= 0
                or attempt.health >= attempt.maxHealth
            then
                return nil
            end
            available[attempt.siteId] = nil
            return math.min(attempt.health + healAmount, attempt.maxHealth)
        end,
    }
end

return MedkitService
