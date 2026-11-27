--!strict
--[=[
    Server-only preset cache and transaction coordinator. Storage is injected,
    may yield or throw, and must perform atomic conditional updates. Gameplay
    getters and deployment snapshotting never yield. A failed read keeps the
    last good snapshot; a stale read cannot regress the cached revision.
]=]
local loadPath = (require :: unknown) :: (string) -> unknown
local Record = (
    if script then require(script.Parent.BalanceRecord) else loadPath("./BalanceRecord")
) :: typeof(require(script.Parent.BalanceRecord))
local BalanceService = {}
type RecordValue = typeof(Record.initial())
type Request = typeof(assert((Record.request(nil)), "validated request type"))
-- read returns nil for a missing key. update must cancel when the callback returns nil.
export type Storage = { read: () -> unknown, update: ((unknown) -> unknown) -> unknown }
export type Controller = {
    latest: () -> RecordValue,
    round: () -> RecordValue,
    status: () -> string,
    capture: () -> (),
    refresh: () -> boolean,
    write: (Request, number, number?, () -> boolean) -> (boolean, string?),
    stop: () -> (),
}

-- Owns immutable-by-contract revisions. Callers may copy them into remote responses.
-- stop invalidates ongoing work including transactions retried by storage.
function BalanceService.new(storage: Storage): Controller
    local latest = Record.initial()
    local round = latest
    local status = "Loading"
    local running = true
    local function accept(raw: unknown): boolean
        if not running then
            return false
        end
        local decoded = Record.decode(raw)
        if not decoded then
            status = "Stored settings invalid"
            return false
        end
        if decoded.revision >= latest.revision then
            latest = decoded
        end
        status = "Connected"
        return true
    end
    return {
        latest = function()
            return latest
        end,
        round = function()
            return round
        end,
        status = function()
            return status
        end,
        capture = function()
            round = latest
        end,
        refresh = function()
            if not running then
                return false
            end
            local ok, value = pcall(storage.read)
            if not ok then
                if running then
                    status = "Storage unavailable"
                end
                return false
            end
            return accept(value)
        end,
        write = function(request, actor, ownerId, connected)
            if not running or not connected() then
                return false, "Session ended."
            end
            if not Record.allowed(latest, actor, ownerId) then
                return false, "Admin access denied."
            end
            local reason: string? = nil
            local ok, result = pcall(storage.update, function(raw: unknown): unknown
                if not running or not connected() then
                    reason = "Session ended."
                    return nil
                end
                local current, invalid = Record.decode(raw)
                if not current then
                    reason = invalid
                    return nil
                end
                local nextRecord, rejection = Record.apply(current, request, actor, ownerId)
                reason = rejection
                return nextRecord
            end)
            if not ok then
                status = "Storage unavailable"
                return false, "Save could not be confirmed. Refresh to check the revision."
            end
            if reason or result == nil then
                return false, reason or "Save was canceled."
            end
            if not accept(result) then
                return false, "Save could not be confirmed."
            end
            return true, nil
        end,
        stop = function()
            running = false
        end,
    }
end
return BalanceService
