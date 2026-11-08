--!strict
--[=[
    RoleService: deterministic server-only roster selection; no engine access or yielding.
    Wait counters count completed assignments, not wall-clock time. The previous operator
    is excluded whenever an alternative exists; seeded ties are independent of join order.
]=]
local RoleService = {}

-- A unique connected UserId and the number of rounds since their last operator turn.
export type Candidate = { userId: number, waitedRounds: number }
export type Assignment = { operatorId: number, groundIds: { number } }

-- Returns a fresh assignment or nil/reason. Population bounds and seed are caller-owned.
-- Does not mutate candidates. IDs may be negative in Studio local-server sessions.
function RoleService.assign(
    candidates: { Candidate },
    minimumPlayers: number,
    previousOperatorId: number?,
    seed: number
): (Assignment?, string?)
    if minimumPlayers < 2 or minimumPlayers > 10 or minimumPlayers % 1 ~= 0 then
        return nil, "minimum must be an integer from two to ten"
    end
    if seed ~= seed or seed < 0 or seed > 2147483647 or seed % 1 ~= 0 then
        return nil, "seed must be a safe nonnegative integer"
    end
    if #candidates < minimumPlayers or #candidates > 10 then
        return nil, "population outside configured bounds"
    end
    local seen: { [number]: boolean } = {}
    local sorted = table.clone(candidates)
    for _, candidate in sorted do
        local id, waited = candidate.userId, candidate.waitedRounds
        if id ~= id or math.abs(id) == math.huge or id % 1 ~= 0 or seen[id] then
            return nil, "invalid or duplicate UserId"
        end
        if waited < 0 or waited % 1 ~= 0 or waited == math.huge then
            return nil, "invalid wait counter"
        end
        seen[id] = true
    end
    table.sort(sorted, function(a, b)
        return a.userId < b.userId
    end)
    local longestWait = -1
    local eligible: { number } = {}
    for _, candidate in sorted do
        if candidate.userId ~= previousOperatorId or #sorted == 1 then
            if candidate.waitedRounds > longestWait then
                longestWait = candidate.waitedRounds
                table.clear(eligible)
            end
            if candidate.waitedRounds == longestWait then
                table.insert(eligible, candidate.userId)
            end
        end
    end
    if #eligible == 0 then
        return nil, "no eligible operator"
    end
    -- A small deterministic integer mix; no ambient math.random state is consumed.
    local index = ((seed * 48271) % 2147483647) % #eligible + 1
    local operatorId = eligible[index]
    local groundIds: { number } = {}
    for _, candidate in sorted do
        if candidate.userId ~= operatorId then
            table.insert(groundIds, candidate.userId)
        end
    end
    return { operatorId = operatorId, groundIds = groundIds }, nil
end

return RoleService
