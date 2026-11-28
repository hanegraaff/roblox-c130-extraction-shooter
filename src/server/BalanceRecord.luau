--!strict
--[=[
    Pure server reducer for the single persisted balance key. UpdateAsync may run
    the reducer repeatedly. Each attempt rechecks permission and expected revision
    against the supplied record, and produces a fresh value or a rejection.
]=]
local loadPath = (require :: unknown) :: (string) -> unknown
local Schema = (
    if script
        then require(game:GetService("ReplicatedStorage").Shared.BalanceSchema)
        else loadPath("../shared/BalanceSchema")
) :: typeof(require(game:GetService("ReplicatedStorage").Shared.BalanceSchema))
local BalanceRecord = {}
type Values = typeof(Schema.defaults)
type Bag = { [unknown]: unknown }
-- Active and previous values are independent of names that a tester may overwrite.
export type Record = {
    version: number,
    revision: number,
    activeRevision: number,
    activeName: string,
    settings: Values,
    previousName: string?,
    previousSettings: Values?,
    savedBy: number,
    presets: { [string]: Values },
    trusted: { number },
}
export type Request = { action: string, revision: number?, name: string?, settings: Values?, userId: number? }
local maxRevision = 2147483647
local maxUserId = 9007199254740991
local maxPresets, maxTrusted = 24, 32

local function integer(value: unknown, low: number, high: number): boolean
    return type(value) == "number" and value >= low and value <= high and value % 1 == 0
end
local function validName(value: unknown): boolean
    return Schema.validPresetName(value)
end

-- Initial state for an absent key. A corrupt existing key must never be overwritten with these defaults.
function BalanceRecord.initial(): Record
    return {
        version = 1,
        revision = 0,
        activeRevision = 0,
        activeName = "Shipped",
        settings = Schema.defaults,
        previousName = nil,
        previousSettings = nil,
        savedBy = 0,
        presets = { Shipped = Schema.defaults },
        trusted = {},
    }
end

-- Decode the authoritative storage boundary. Bounds apply even to corrupt nested records.
function BalanceRecord.decode(raw: unknown): (Record?, string?)
    if raw == nil then
        return BalanceRecord.initial(), nil
    end
    if type(raw) ~= "table" then
        return nil, "Invalid stored settings."
    end
    local t = raw :: Bag
    if
        t.version ~= 1
        or not integer(t.revision, 0, maxRevision)
        or not integer(t.activeRevision, 0, t.revision :: number)
        or not validName(t.activeName)
        or not integer(t.savedBy, 0, maxUserId)
        or type(t.presets) ~= "table"
        or type(t.trusted) ~= "table"
    then
        return nil, "Invalid stored revision."
    end
    local values, err = Schema.decodeStored(t.settings)
    if not values then
        return nil, err
    end
    local previous: Values? = nil
    if t.previousName ~= nil or t.previousSettings ~= nil then
        if not validName(t.previousName) then
            return nil, "Invalid rollback name."
        end
        previous = Schema.decodeStored(t.previousSettings)
        if not previous then
            return nil, "Invalid rollback values."
        end
    end
    local presets: { [string]: Values } = {}
    local count = 0
    for name, value in t.presets :: Bag do
        count += 1
        if count > maxPresets or not validName(name) then
            return nil, "Invalid stored preset list."
        end
        local preset = Schema.decodeStored(value)
        if not preset then
            return nil, "Invalid stored preset."
        end
        presets[name :: string] = preset
    end
    if not presets.Shipped then
        return nil, "Missing built-in preset."
    end
    local trusted: { number } = {}
    local seen: { [number]: boolean } = {}
    local largest = 0
    count = 0
    for index, id in t.trusted :: Bag do
        count += 1
        if
            count > maxTrusted
            or not integer(index, 1, maxTrusted)
            or not integer(id, 1, maxUserId)
            or seen[id :: number]
        then
            return nil, "Invalid stored tester list."
        end
        largest = math.max(largest, index :: number)
        seen[id :: number] = true
        trusted[index :: number] = id :: number
    end
    if count ~= largest then
        return nil, "Invalid tester list order."
    end
    return {
        version = 1,
        revision = t.revision :: number,
        activeRevision = t.activeRevision :: number,
        activeName = t.activeName :: string,
        settings = values,
        previousName = t.previousName :: string?,
        previousSettings = previous,
        savedBy = t.savedBy :: number,
        presets = presets,
        trusted = trusted,
    },
        nil
end

-- Roblox supplies the actor ID at the transport boundary. Ownership is resolved independently of the stored ACL.
function BalanceRecord.allowed(record: Record, userId: number, ownerId: number?): boolean
    return userId == ownerId or table.find(record.trusted, userId) ~= nil
end

-- Validates exactly the fields admitted for one action; no user identifiers are accepted as the actor.
function BalanceRecord.request(raw: unknown): (Request?, string?)
    if type(raw) ~= "table" then
        return nil, "Invalid admin request."
    end
    local t = raw :: Bag
    local action = t.action
    if
        action ~= "read"
        and action ~= "save"
        and action ~= "saveAndApply"
        and action ~= "apply"
        and action ~= "delete"
        and action ~= "restore"
        and action ~= "grant"
        and action ~= "revoke"
    then
        return nil, "Unknown admin action."
    end
    local req: Request = { action = action :: string }
    local expected = 1
    if action ~= "read" then
        if not integer(t.revision, 0, maxRevision) then
            return nil, "Invalid revision."
        end
        req.revision = t.revision :: number
        expected += 1
    end
    local savesPreset = action == "save" or action == "saveAndApply"
    if savesPreset or action == "apply" or action == "delete" then
        if not validName(t.name) then
            return nil, "Use 1–32 letters, numbers, spaces, hyphens or underscores for the name."
        end
        req.name = t.name :: string
        expected += 1
    end
    if savesPreset then
        local values, err = Schema.validate(t.settings)
        if not values then
            return nil, err
        end
        req.settings = values
        expected += 1
    elseif action == "grant" or action == "revoke" then
        if not integer(t.userId, 1, maxUserId) then
            return nil, "Enter a positive Roblox user ID."
        end
        req.userId = t.userId :: number
        expected += 1
    end
    local count = 0
    for _ in t do
        count += 1
        if count > expected then
            return nil, "Unexpected admin request field."
        end
    end
    return req, nil
end

-- A validated write either advances one global revision or returns no replacement.
-- Cloning nested collections protects snapshots and retry inputs.
function BalanceRecord.apply(
    current: Record,
    req: Request,
    actor: number,
    ownerId: number?
): (Record?, string?)
    if not BalanceRecord.allowed(current, actor, ownerId) then
        return nil, "Admin access denied."
    end
    if req.revision ~= current.revision then
        return nil, "Settings changed. Refresh and try again."
    end
    if current.revision >= maxRevision then
        return nil, "Revision limit reached."
    end
    local nextRecord = table.clone(current)
    local action = req.action
    if action == "grant" or action == "revoke" then
        if actor ~= ownerId then
            return nil, "Only the owner can manage testers."
        end
        local target = req.userId :: number
        if target == ownerId then
            return nil, "The owner always has access."
        end
        local list = table.clone(current.trusted)
        local index = table.find(list, target)
        if action == "grant" then
            if index or #list >= maxTrusted then
                return nil, "Tester already listed or list is full."
            end
            table.insert(list, target)
        else
            if not index then
                return nil, "Tester is not listed."
            end
            table.remove(list, index)
        end
        nextRecord.trusted = list
    elseif action == "save" or action == "saveAndApply" then
        local name = req.name :: string
        if name == Schema.builtinPresetKey or name == Schema.builtinPresetName then
            return nil, "Change the preset name to save a copy of Default."
        end
        local presets = table.clone(current.presets)
        local count = 0
        for _ in presets do
            count += 1
        end
        if not presets[name] and count >= maxPresets then
            return nil, "Preset list is full. Overwrite an existing preset."
        end
        presets[name] = req.settings :: Values
        nextRecord.presets = presets
    elseif action == "delete" then
        local name = req.name :: string
        if name == "Shipped" then
            return nil, "Default is the built-in preset."
        end
        if not current.presets[name] then
            return nil, "Preset unavailable."
        end
        local presets = table.clone(current.presets)
        presets[name] = nil
        nextRecord.presets = presets
        -- Live settings and rollback are independent snapshots. Deleting a name
        -- removes it from the library while preserving the confirmed live rules.
    elseif action ~= "apply" and action ~= "restore" then
        return nil, "Expected a write action."
    end
    -- Saving and applying an edit uses the replacement preset in this same
    -- transaction. Rollback still points to the prior live snapshot.
    if action == "apply" or action == "restore" or action == "saveAndApply" then
        local name = if action == "restore" then current.previousName else req.name
        local values = if action == "restore"
            then current.previousSettings
            else nextRecord.presets[req.name :: string]
        if not name or not values then
            return nil, "Preset unavailable."
        end
        nextRecord.previousName = current.activeName
        nextRecord.previousSettings = current.settings
        nextRecord.activeName = name
        nextRecord.settings = values
        nextRecord.activeRevision = current.revision + 1
    end
    nextRecord.revision = current.revision + 1
    nextRecord.savedBy = actor
    return nextRecord, nil
end
return BalanceRecord
