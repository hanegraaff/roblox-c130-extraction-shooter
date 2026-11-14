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
local BuildingGeometry = require(script.Parent.BuildingGeometry)
local PanelFragments = require(script.Parent.PanelFragments)
local PanelAssetCatalog = require(script.Parent.PanelAssetCatalog)
local MaterialPanelGeometry = require(script.Parent.MaterialPanelGeometry)
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
    local candidateMap = world:FindFirstChild("Battlefield")
    if not candidateMap or not candidateMap:IsA("Model") then
        return nil, "missing active battlefield"
    end
    local map: Model = candidateMap
    local registries, registryReason = BuildingGeometry.registries(map)
    if not registries then
        return nil, registryReason
    end
    local catalog: PanelAssetCatalog.Catalog? = nil
    local materialPanels = false
    local panelIds: { [string]: boolean } = {}
    for _, registry in registries do
        for _, panel in registry.panels:GetChildren() do
            if panel.Name == "" or panelIds[panel.Name] or panel:GetAttribute("PanelId") ~= panel.Name then
                return nil, "invalid/duplicate registered panel identity"
            end
            panelIds[panel.Name] = true
            materialPanels = materialPanels or panel:IsA("Model")
        end
    end
    if materialPanels then
        local assets = game:GetService("ServerStorage"):FindFirstChild("Assets")
        local reason: string?
        catalog, reason =
            PanelAssetCatalog.load(if assets then assets:FindFirstChild("MaterialPanels") else nil)
        if not catalog then
            return nil, reason
        end
        for _, registry in registries do
            for _, panel in registry.panels:GetChildren() do
                if panel:IsA("Model") then
                    local family = panel:GetAttribute("PanelAssetFamily")
                    if type(family) ~= "string" or not catalog[family] then
                        return nil, "unknown material panel family"
                    end
                    if panel:GetAttribute("IntactSize") ~= catalog[family].size then
                        return nil, "material panel size differs from approved family"
                    end
                    local valid, panelReason = MaterialPanelGeometry.validate(panel, catalog[family])
                    if not valid then
                        return nil, panelReason
                    end
                end
            end
        end
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
        local currentRegistries, currentReason = BuildingGeometry.registries(map)
        assert(currentRegistries, currentReason)
        for _, registry in currentRegistries do
            for _, part in registry.panels:GetChildren() do
                assert(
                    (part:IsA("BasePart") or part:IsA("Model"))
                        and type(part:GetAttribute("PanelId")) == "string",
                    "invalid registered panel"
                )
                local familyId = part:GetAttribute("PanelAssetFamily")
                local family = if catalog and type(familyId) == "string" then catalog[familyId] else nil
                local panel = PanelGeometry.capture(part :: BasePart | Model, family)
                if panel.original:IsA("BasePart") and part:IsA("BasePart") then
                    panel.original.CollisionGroup = fragments.previousGroup(part)
                elseif panel.original:IsA("Model") and part:IsA("Model") then
                    for _, original in panel.original:GetChildren() do
                        local source = part:FindFirstChild(original.Name)
                        if original:IsA("BasePart") and source and source:IsA("BasePart") then
                            original.CollisionGroup = fragments.previousGroup(source)
                        end
                    end
                end
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
                        fragments.emit(
                            panel.pivot,
                            panel.size,
                            panel.color,
                            now,
                            if panel.family then panel.family.fragments else nil
                        )
                    end
                end
                PanelGeometry.publish(
                    panel,
                    state.stage,
                    state.progress,
                    state.heavySeconds,
                    state.sustainedSeconds,
                    state.appearance
                )
                fragments.static(panel.model)
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
            assert(active and active:IsA("Model"), "active battlefield disappeared")
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
            if
                not running
                or not hit
                or not hit:IsA("BasePart")
                or not hit.CanCollide
                or not hit.CanQuery
                or hit:GetAttribute("DamageVisual") == true
                or map.Parent ~= world
            then
                return nil
            end
            local id = hit:GetAttribute("PanelId")
            if type(id) ~= "string" then
                return nil
            end
            local panel = panels[id]
            return if panel
                    and panel.model:IsDescendantOf(map)
                    and hit.Parent == panel.model
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
