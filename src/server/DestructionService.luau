--!strict
--[=[
    DestructionService: pure server-only ordered structural-impact ledger. Depends
    on PanelDamageRules and injected server-resolved shot outcomes. No Instances,
    client transport or yielding. Outcomes may resolve out of order; scoring waits
    for earlier accepted shots, including misses, so travel does not invent gaps.
    Interruptions are ordered barriers after accepted shot IDs, so valid in-flight
    tails finish before continuity breaks. Earned damage persists per panel across
    every interruption; reset alone clears it and invalidates all old outcomes.
]=]
local loadPath = (require :: unknown) :: (string) -> unknown
local Rules = (
    if script then require(script.Parent.PanelDamageRules) else loadPath("./PanelDamageRules")
) :: typeof(require(script.Parent.PanelDamageRules))
type PanelState = typeof(Rules.new())
type DamageAppearance = typeof(Rules.appearance(Rules.new()))
local Combat = (
    if script then require(script.Parent.CombatService) else loadPath("./CombatService")
) :: typeof(require(script.Parent.CombatService))
local DestructionService = {}
DestructionService.gapSeconds = Combat.profiles.GAU23.cadence * 1.5
-- Outcome identity and firedAt come exclusively from an accepted CombatService
-- shot. A nil panelId means miss, obstruction, expiry or an unregistered solid.
export type Outcome = { roundId: number, shotId: number, weapon: string, firedAt: number, panelId: string? }
export type Snapshot = {
    stage: number,
    heavySeconds: number,
    sustainedSeconds: number,
    progress: number,
    appearance: DamageAppearance,
}
export type Controller = {
    reset: (number, { string }) -> (),
    cancel: () -> (),
    resolve: (Outcome) -> (boolean, string?),
    interrupt: (number?) -> (),
    snapshot: (string) -> Snapshot?,
    changed: () -> { string },
    resources: () -> { pending: number, panels: number, barriers: number },
}

-- Creates an independent ledger. gapSeconds is finite >= actual GAU cadence;
-- the default tolerates 1.5 cadences. Malformed outcomes reject without mutation.
-- Completed IDs are deduplicated by the ordered frontier, keeping memory bounded
-- by active flights rather than all shots in a long match. No pre-first-hit credit.
-- interrupt(afterShotId?) queues a bounded accepted-shot barrier; nil breaks continuity now
-- for synchronous rule adapters. Neither API yields. Reset clears queued barriers.
function DestructionService.new(gapSeconds: number?): Controller
    local gap = gapSeconds or DestructionService.gapSeconds
    assert(gap == gap and gap >= Combat.profiles.GAU23.cadence and gap <= 1, "invalid sustained-fire gap")
    local roundId, frontier = 0, 1
    local panels: { [string]: PanelState } = {}
    local pending: { [number]: Outcome } = {}
    local changes: { [string]: boolean } = {}
    local target: string? = nil
    local lastFire: number? = nil
    local barriers: { [number]: boolean } = {}
    local lastBarrier = -1
    local function breakContinuity()
        -- Credit belongs to each panel. Only the last-hit anchor is transient;
        -- a resumed/retargeted first impact cannot charge paused/off-target time.
        target, lastFire = nil, nil
    end
    -- A boundary after N accepted shots is applied only after all outcomes1..N
    -- resolve, including misses/expiry. All earned credit survives; elapsed time
    -- cannot bridge into outcome N+1. Repeated/stale boundary IDs are idempotent.
    local function applyBarrier()
        local boundary = frontier - 1
        if barriers[boundary] then
            barriers[boundary] = nil
            lastBarrier = math.max(lastBarrier, boundary)
            breakContinuity()
        end
    end
    local function interrupt(afterShotId: number?)
        if afterShotId == nil then
            breakContinuity()
            return
        end
        assert(
            afterShotId == afterShotId
                and afterShotId % 1 == 0
                and afterShotId >= 0
                and afterShotId <= frontier + 512,
            "invalid accepted-shot interruption boundary"
        )
        if afterShotId <= lastBarrier or afterShotId < frontier - 1 then
            return
        end
        if afterShotId < frontier then
            lastBarrier = afterShotId
            breakContinuity()
        else
            barriers[afterShotId] = true
        end
    end
    local function score(outcome: Outcome)
        local id = outcome.panelId
        local panel = if id then panels[id] else nil
        if outcome.weapon ~= "GAU23" or id ~= target or not panel then
            breakContinuity()
        end
        if not id or not panel or panel.stage == 2 then
            return
        end
        if outcome.weapon == "M102" then
            Rules.apply(panel, true, 0)
        else
            local previous = lastFire
            local elapsed = if previous then outcome.firedAt - previous else 0
            if elapsed < 0 or elapsed > gap + Rules.epsilonSeconds then
                breakContinuity()
                elapsed = 0
            end
            Rules.apply(panel, false, elapsed)
            target, lastFire = id, outcome.firedAt
        end
        changes[id] = true
    end
    return {
        reset = function(id, ids)
            assert(id >= 0 and id % 1 == 0, "invalid round generation")
            roundId, frontier = id, 1
            target, lastFire = nil, nil
            lastBarrier = -1
            table.clear(barriers)
            table.clear(panels)
            table.clear(pending)
            table.clear(changes)
            for _, panelId in ids do
                assert(panelId ~= "" and panels[panelId] == nil, "duplicate/empty panel ID")
                panels[panelId] = Rules.new()
                changes[panelId] = true
            end
        end,
        -- Terminal phase cancellation closes this generation without rebuilding
        -- earned cover damage. No old flight can score after close; reset reopens a
        -- new authoritative generation and clears all queued work.
        cancel = function()
            breakContinuity()
            roundId = 0
            table.clear(pending)
            table.clear(barriers)
        end,
        interrupt = interrupt,
        resolve = function(outcome)
            if type(outcome) ~= "table" then
                return false, "invalid outcome"
            end
            if outcome.roundId ~= roundId or roundId <= 0 then
                return false, "stale round"
            end
            if
                type(outcome.shotId) ~= "number"
                or outcome.shotId ~= outcome.shotId
                or outcome.shotId % 1 ~= 0
                or outcome.shotId < frontier
                or outcome.shotId > frontier + 512
                or pending[outcome.shotId]
            then
                return false, "stale, duplicate or unbounded shot"
            end
            if
                (outcome.weapon ~= "GAU23" and outcome.weapon ~= "M102")
                or type(outcome.firedAt) ~= "number"
                or outcome.firedAt ~= outcome.firedAt
                or math.abs(outcome.firedAt) == math.huge
                or (
                    outcome.panelId ~= nil
                    and (type(outcome.panelId) ~= "string" or not panels[outcome.panelId])
                )
            then
                return false, "invalid profile, time or panel"
            end
            pending[outcome.shotId] = table.clone(outcome)
            while pending[frontier] do
                applyBarrier()
                local nextOutcome = pending[frontier]
                pending[frontier] = nil
                frontier += 1
                score(nextOutcome)
            end
            applyBarrier()
            return true, nil
        end,
        snapshot = function(id)
            local state = panels[id]
            return if state
                then {
                    stage = state.stage,
                    heavySeconds = state.heavySeconds,
                    sustainedSeconds = state.sustainedSeconds,
                    progress = Rules.progress(state),
                    appearance = Rules.appearance(state),
                }
                else nil
        end,
        changed = function()
            local ids: { string } = {}
            for id in changes do
                table.insert(ids, id)
            end
            table.sort(ids)
            table.clear(changes)
            return ids
        end,
        resources = function()
            local queued, count = 0, 0
            for _ in pending do
                queued += 1
            end
            for _ in panels do
                count += 1
            end
            local interruptions = 0
            for _ in barriers do
                interruptions += 1
            end
            return { pending = queued, panels = count, barriers = interruptions }
        end,
    }
end
return DestructionService
