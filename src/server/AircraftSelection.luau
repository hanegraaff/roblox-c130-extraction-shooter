--!strict
--[=[
    AircraftSelection: server-only deterministic profile selection authority. No
    dependencies. Caller supplies current round/role/life/deadline eligibility;
    engine adapter separately rate-limits. No ammunition/cooldown state is created or
    reset by selection. Commands are nonyielding and reject without state mutation.
]=]
local AircraftSelection = {}
export type Snapshot = { roundId: number, revision: number, weapon: string }
export type Controller = {
    reset: (number, boolean?) -> (),
    command: (number, unknown, boolean) -> (boolean, string?),
    snapshot: () -> Snapshot,
}

-- Owns one round's selection and per-user accepted sequence. reset clears sequences
-- when round identity changes or force=true begins a fresh Lobby. A copied snapshot
-- cannot alter server authority. Repeating reset with the same ID is otherwise a no-op.
function AircraftSelection.new(): Controller
    local state = { roundId = 0, revision = 0, weapon = "GAU23" }
    local sequences: { [number]: number } = {}
    return {
        reset = function(roundId, force)
            if state.roundId == roundId and not force then
                return
            end
            state = { roundId = roundId, revision = state.revision + 1, weapon = "GAU23" }
            table.clear(sequences)
        end,
        snapshot = function()
            return table.clone(state)
        end,
        command = function(userId, payload, eligible)
            if not eligible then
                return false, "operator must be alive in an active round"
            end
            if type(payload) ~= "table" then
                return false, "invalid selection shape"
            end
            local fields = payload :: { [string]: unknown }
            local count = 0
            for key in fields do
                if key ~= "roundId" and key ~= "sequence" and key ~= "weapon" then
                    return false, "unknown selection field"
                end
                count += 1
            end
            local sequence = fields.sequence
            if count ~= 3 or fields.roundId ~= state.roundId or state.roundId <= 0 then
                return false, "stale round"
            end
            if
                type(sequence) ~= "number"
                or sequence ~= sequence
                or math.abs(sequence) == math.huge
                or sequence % 1 ~= 0
                or sequence < 1
                or sequence > 2147483647
                or sequence <= (sequences[userId] or 0)
            then
                return false, "invalid or repeated sequence"
            end
            if fields.weapon ~= "GAU23" and fields.weapon ~= "M102" then
                return false, "unknown aircraft weapon"
            end
            sequences[userId] = sequence
            state.weapon = fields.weapon
            state.revision += 1
            return true, nil
        end,
    }
end
return AircraftSelection
