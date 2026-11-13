--!strict
--[=[
    DestructionRuntime: engine owner for the active level's registered building
    panels, replicated progress, residual collision and physical fragments. Uses
    DestructionService for rules; has no remotes and cannot decide match results.
    CombatRuntime calls sync before a batch, resolve for every accepted outcome,
    then flush only after ALL collision and player damage queries have completed.
    All APIs are nonyielding; stop restores captured panels and owns all cleanup.
]=]
local DestructionService = require(script.Parent.DestructionService)
local PanelGeometry = require(script.Parent.PanelGeometry)
local PanelFragments = require(script.Parent.PanelFragments)
local DestructionRuntime = {}
export type Controller = {
    sync: (number) -> (),
    cancel: () -> (),
    identify: (Instance?) -> string?,
    resolve: (DestructionService.Outcome) -> (boolean, string?),
    interrupt: (number?) -> (),
    flush: (number) -> (),
    snapshot: (string) -> DestructionService.Snapshot?,
    resources: () -> { panels: number, fragments: number, pending: number },
    stop: () -> (),
}

-- Starts one map consumer. Registered panel Parts are discovered from each
-- building's explicit *_Panels folder; generic breakable cover/static supports
-- never enter the ledger. Map replacement is detected by Instance identity even
-- when reset retains the same roundId. Optional fragment settings are test tuning.
function DestructionRuntime.start(world: Instance, settings: PanelFragments.Settings?): (Controller?, string?)
    local map = world:FindFirstChild("Battlefield")
    if not map then
        return nil, "missing active battlefield"
    end
    local fragments, reason = PanelFragments.start(map, settings)
    if not fragments then
        return nil, reason
    end
    local rules = DestructionService.new()
    local panels: { [string]: PanelGeometry.Panel } = {}
    local roundId = -1
    local running = true
    local function release(restore: boolean)
        for _, panel in panels do
            if restore and panel.model.Parent then
                local parent = panel.model.Parent
                panel.original.Name = panel.id
                panel.original.Parent = parent
                panel.model:Destroy()
            else
                panel.original:Destroy()
            end
        end
        table.clear(panels)
    end
    local function capture()
        local buildings = map:FindFirstChild("Buildings")
        assert(buildings, "active level requires building registry")
        for _, building in buildings:GetChildren() do
            local registry = building:FindFirstChild(building.Name .. "_Panels")
            assert(registry, "missing active panel registry")
            for _, part in registry:GetChildren() do
                assert(
                    part:IsA("BasePart") and type(part:GetAttribute("PanelId")) == "string",
                    "invalid registered panel"
                )
                local panel = PanelGeometry.capture(part)
                panel.original.CollisionGroup = fragments.previousGroup(part)
                assert(panels[panel.id] == nil, "duplicate active panel ID")
                panels[panel.id] = panel
            end
        end
    end
    local function flush(now: number)
        if not running then
            return
        end
        for _, id in rules.changed() do
            local panel = panels[id]
            local state = rules.snapshot(id)
            if panel and state then
                if state.stage ~= panel.stage then
                    -- The entire collision batch has finished before this call.
                    -- Only presentation uses physical fragments; cover is the
                    -- anchored residual geometry installed synchronously here.
                    local previousStage = panel.stage
                    PanelGeometry.setStage(panel, state.stage)
                    fragments.static(panel.model)
                    for _ = previousStage + 1, state.stage do
                        fragments.emit(panel.pivot, panel.size, panel.original.Color, now)
                    end
                end
                PanelGeometry.publish(
                    panel,
                    state.stage,
                    state.progress,
                    state.heavySeconds,
                    state.sustainedSeconds
                )
            end
        end
        fragments.step(now)
    end
    return {
        sync = function(id)
            if not running then
                return
            end
            local active = world:FindFirstChild("Battlefield")
            assert(active, "active battlefield disappeared")
            if active ~= map or id ~= roundId then
                -- A map reset can retain the completed roundId while entering
                -- Lobby. Keep its fresh panels closed to all old outcomes until
                -- a genuinely new round generation arrives.
                local ledgerRound = if active ~= map and id == roundId then 0 else id
                release(active == map)
                map, roundId = active, id
                fragments.clear()
                capture()
                fragments.static(map)
                local ids: { string } = {}
                for panelId in panels do
                    table.insert(ids, panelId)
                end
                rules.reset(ledgerRound, ids)
                flush(workspace:GetServerTimeNow())
            end
        end,
        -- Returns identity only for an actual currently registered solid. A
        -- forged tag/copy, support, detached old map or model root is not a hit.
        cancel = rules.cancel,
        identify = function(hit)
            if not running or not hit or not hit:IsA("BasePart") or map.Parent ~= world then
                return nil
            end
            local id = hit:GetAttribute("PanelId")
            if type(id) ~= "string" then
                return nil
            end
            local panel = panels[id]
            return if panel
                    and panel.model:IsDescendantOf(map)
                    and hit:IsDescendantOf(panel.model)
                then id
                else nil
        end,
        resolve = rules.resolve,
        interrupt = rules.interrupt,
        flush = flush,
        snapshot = rules.snapshot,
        resources = function()
            local resources = rules.resources()
            return { panels = resources.panels, pending = resources.pending, fragments = fragments.count() }
        end,
        stop = function()
            if not running then
                return
            end
            running = false
            release(true)
            fragments.stop()
            rules.reset(0, {})
        end,
    },
        nil
end
return DestructionRuntime
