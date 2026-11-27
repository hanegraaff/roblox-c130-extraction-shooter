--!strict
--[=[
    DestructionRuntime: engine owner for the active level's registered building
    panels, replicated progress, residual collision and physical fragments. Uses
    DestructionService for rules; has no remotes and cannot decide match results.
    CombatRuntime calls sync before a batch, resolve for every accepted outcome,
    then flush only after ALL collision and player damage queries have completed.
    All APIs are nonyielding; stop restores captured panels and owns all cleanup.
]=]
local BalanceSchema = require(game:GetService("ReplicatedStorage").Shared.BalanceSchema)
local DestructionService = require(script.Parent.DestructionService)
local PanelGeometry = require(script.Parent.PanelGeometry)
local BuildingGeometry = require(script.Parent.BuildingGeometry)
local PanelFragments = require(script.Parent.PanelFragments)
local PanelAssetCatalog = require(script.Parent.PanelAssetCatalog)
local MaterialPanelGeometry = require(script.Parent.MaterialPanelGeometry)
local VesperPanelGeometry = require(script.Parent.VesperPanelGeometry)
local SaltFlatsReconstruction = require(script.Parent.SaltFlatsReconstruction)
local SandbreakReconstruction = require(script.Parent.SandbreakReconstruction)
local SeedshipReconstruction = require(script.Parent.SeedshipReconstruction)
local DestructionRuntime = {}
export type Controller = {
    sync: (number) -> (),
    cancel: () -> (),
    identify: (Instance?) -> string?,
    resolve: (DestructionService.Outcome) -> (boolean, string?),
    interrupt: (number?) -> (),
    flush: (number) -> (),
    snapshot: (string) -> DestructionService.Snapshot?,
    resources: () -> { panels: number, fragments: number, pending: number, barriers: number },
    stop: () -> (),
}

-- Starts one map consumer. Registered panel Parts are discovered from each
-- building's explicit *_Panels folder; generic breakable cover/static supports
-- never enter the ledger. Map replacement is detected by Instance identity even
-- when reset retains the same roundId. Optional fragment settings are test tuning.
function DestructionRuntime.start(
    world: Instance,
    settings: PanelFragments.Settings?,
    getBalance: (() -> BalanceSchema.Values)?
): (Controller?, string?)
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
    local vesperVariants: { [string]: VesperPanelGeometry.Variants } = {}
    local materialPanels = false
    local assets = game:GetService("ServerStorage"):FindFirstChild("Assets")
    local panelIds: { [string]: boolean } = {}
    for _, registry in registries do
        for _, panel in registry.panels:GetChildren() do
            if panel.Name == "" or panelIds[panel.Name] or panel:GetAttribute("PanelId") ~= panel.Name then
                return nil, "invalid/duplicate registered panel identity"
            end
            panelIds[panel.Name] = true
            if panel:IsA("Model") and panel:GetAttribute("VesperPanel") == true then
                if registry.buildingId ~= "Warehouse" or panel:GetAttribute("PanelAssetFamily") ~= nil then
                    return nil, "Vesper panel registered outside its building or with a conflicting family"
                end
                local variants, reason = VesperPanelGeometry.load(
                    if assets then assets:FindFirstChild("VesperPanelVariants") else nil,
                    panel
                )
                if not variants then
                    return nil, reason
                end
                vesperVariants[panel.Name] = variants
            elseif panel:IsA("Model") and panel:GetAttribute("SaltFlatsPanel") == true then
                local variants, reason = SaltFlatsReconstruction.panelVariants(
                    if assets then assets:FindFirstChild("SaltFlatsPanelVariants") else nil,
                    panel
                )
                if not variants then
                    return nil, reason
                end
                vesperVariants[panel.Name] = variants
            elseif panel:IsA("Model") and panel:GetAttribute("SandbreakPanel") == true then
                if registry.buildingId ~= "SpawnShelter" or panel:GetAttribute("PanelAssetFamily") ~= nil then
                    return nil, "Sandbreak panel registered outside the shelter or with a conflicting family"
                end
                local variants, reason = SandbreakReconstruction.panelVariants(
                    if assets then assets:FindFirstChild("SandbreakPanelVariants") else nil,
                    panel
                )
                if not variants then
                    return nil, reason
                end
                vesperVariants[panel.Name] = variants
            elseif panel:IsA("Model") and panel:GetAttribute("SeedshipPanel") == true then
                if registry.buildingId ~= "PrismSeedship" then
                    return nil, "Seedship panel registered outside its building"
                end
                local variants, reason = SeedshipReconstruction.panelVariants(
                    if assets then assets:FindFirstChild("PrismPanelVariants") else nil,
                    panel
                )
                if not variants then
                    return nil, reason
                end
                vesperVariants[panel.Name] = variants
            else
                materialPanels = materialPanels or panel:IsA("Model")
            end
        end
    end
    if materialPanels then
        local reason: string?
        catalog, reason =
            PanelAssetCatalog.load(if assets then assets:FindFirstChild("MaterialPanels") else nil)
        if not catalog then
            return nil, reason
        end
        for _, registry in registries do
            for _, panel in registry.panels:GetChildren() do
                if panel:IsA("Model") and not vesperVariants[panel.Name] then
                    local family = panel:GetAttribute("PanelAssetFamily")
                    if type(family) ~= "string" or not catalog[family] then
                        return nil, "unknown material panel family"
                    end
                    local basis, basisReason = MaterialPanelGeometry.basis(panel)
                    if not basis then
                        return nil, basisReason
                    end
                    local authoredSize = panel:GetAttribute("IntactSize")
                    if
                        typeof(authoredSize) ~= "Vector3"
                        or (authoredSize - MaterialPanelGeometry.identitySize(catalog[family], basis)).Magnitude
                            > 0.001
                    then
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
    local supportArtOwners: { [string]: boolean } = {}
    local roundId = -1
    local wreck: Model? = nil
    local pristineWreck: Model? = nil
    local running = true
    local function release(restore: boolean)
        if pristineWreck then
            if restore and wreck and wreck.Parent then
                pristineWreck.Parent = wreck.Parent
                wreck:Destroy()
            else
                pristineWreck:Destroy()
            end
        end
        wreck, pristineWreck = nil, nil
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
        table.clear(supportArtOwners)
    end
    local function capture()
        local candidate = map:FindFirstChild("HerculesWreck", true)
        if candidate and candidate:IsA("Model") and candidate:GetAttribute("DestructibleWreck") == true then
            wreck = candidate
            local copy = candidate:Clone()
            for _, item in copy:GetChildren() do
                local original = candidate:FindFirstChild(item.Name)
                if item:IsA("BasePart") and original and original:IsA("BasePart") then
                    item.CollisionGroup = fragments.previousGroup(original)
                end
            end
            pristineWreck = copy
        end
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
                local panel =
                    PanelGeometry.capture(part :: BasePart | Model, family, vesperVariants[part.Name])
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
                if registry.buildingId == "SpawnShelter" then
                    for _, art in panel.original:GetChildren() do
                        if type(art:GetAttribute("SourceSupportPanels")) == "string" then
                            supportArtOwners[panel.id] = true
                            break
                        end
                    end
                end
            end
        end
    end
    -- Roof equipment can span several panels. Once one support opens, remove
    -- the equipment even if its owning panel is still intact or changes to Light.
    local function clearUnsupportedArt()
        for id in supportArtOwners do
            for _, art in panels[id].model:GetChildren() do
                local supports = art:GetAttribute("SourceSupportPanels")
                if type(supports) == "string" then
                    for support in string.gmatch(supports, "[^,]+") do
                        local state = rules.snapshot(support)
                        if state and state.stage > 0 then
                            art:Destroy()
                            break
                        end
                    end
                end
            end
        end
    end
    local function flush(now: number)
        if not running then
            return
        end
        local changed = rules.changed()
        for _, id in changed do
            local panel = panels[id]
            local state = rules.snapshot(id)
            if id == "HerculesWreck" and wreck and state and state.stage == 2 then
                wreck:ClearAllChildren()
                wreck:SetAttribute("DamageAppearance", "Total")
                fragments.emit(
                    wreck:GetPivot(),
                    Vector3.new(12, 8, 6),
                    Color3.fromRGB(147, 144, 126),
                    now,
                    nil
                )
            elseif panel and state then
                if state.stage ~= panel.stage then
                    -- The entire collision batch has finished before this call.
                    -- Only presentation uses physical fragments; cover is the
                    -- anchored residual geometry installed synchronously here.
                    local previousStage = panel.stage
                    PanelGeometry.setStage(panel, state.stage)
                    fragments.static(panel.model)
                    for _ = previousStage + 1, state.stage do
                        fragments.emit(
                            panel.pivot * (panel.assetBasis or CFrame.identity),
                            panel.size,
                            panel.color,
                            now,
                            if panel.vesper
                                then panel.vesper.fragments
                                elseif panel.family then panel.family.fragments
                                else nil
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
        if #changed > 0 then
            clearUnsupportedArt()
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
                if wreck then
                    table.insert(ids, "HerculesWreck")
                end
                rules.reset(
                    ledgerRound,
                    ids,
                    if wreck then "HerculesWreck" else nil,
                    if getBalance then getBalance() else nil
                )
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
            if wreck and hit.Parent == wreck and wreck:IsDescendantOf(map) then
                return "HerculesWreck"
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
            return {
                panels = resources.panels,
                pending = resources.pending,
                barriers = resources.barriers,
                fragments = fragments.count(),
            }
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
