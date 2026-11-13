--!strict
--[=[
    PanelFragments: server-only bounded rigid-body presentation owner. Depends on
    PhysicsService, actual Workspace physics and injected seconds. Fragments have
    server network ownership, cannot query/touch combat, and collide only with
    explicitly anchored static scenery. No character group or damage callback is
    owned here. step expires fragments without tasks; clear/stop are idempotent.
]=]
local PhysicsService = game:GetService("PhysicsService")
local PanelFragments = {}
export type Settings = {
    perStage: number,
    maximum: number,
    lifetimeSeconds: number,
    speedStudsPerSecond: number,
    angularRadiansPerSecond: number,
}
PanelFragments.defaults = table.freeze({
    perStage = 4,
    maximum = 48,
    lifetimeSeconds = 8,
    speedStudsPerSecond = 12,
    angularRadiansPerSecond = 4,
})
export type Controller = {
    emit: (CFrame, Vector3, Color3, number) -> (),
    step: (number) -> (),
    clear: () -> (),
    stop: () -> (),
    count: () -> number,
    static: (Instance) -> (),
    previousGroup: (BasePart) -> string,
}
type Fragment = { part: Part, expires: number }

-- Rejects nonfinite/out-of-budget tuning before touching collision groups. These
-- local caps bound presentation independently of gameplay progression.
function PanelFragments.validate(value: Settings): boolean
    for _, number in
        {
            value.perStage,
            value.maximum,
            value.lifetimeSeconds,
            value.speedStudsPerSecond,
            value.angularRadiansPerSecond,
        }
    do
        if type(number) ~= "number" or number ~= number or number == math.huge or number < 0 then
            return false
        end
    end
    return value.perStage % 1 == 0
        and value.perStage >= 1
        and value.perStage <= 8
        and value.maximum % 1 == 0
        and value.maximum >= value.perStage
        and value.maximum <= 96
        and value.lifetimeSeconds > 0
        and value.lifetimeSeconds <= 10
        and value.speedStudsPerSecond <= 12
        and value.angularRadiansPerSecond <= 4
end

-- Starts one exclusive group owner. Static input must contain only owned scenery;
-- only anchored parts are assigned. Terrain is explicitly static. Original group
-- properties are restored on stop, and groups owned here are unregistered.
function PanelFragments.start(root: Instance, settings: Settings?): (Controller?, string?)
    local config = settings or PanelFragments.defaults
    if not PanelFragments.validate(config) then
        return nil, "invalid fragment settings"
    end
    if
        PhysicsService:IsCollisionGroupRegistered("PanelFragments")
        or PhysicsService:IsCollisionGroupRegistered("PanelStatic")
    then
        return nil, "fragment groups already owned"
    end
    config = table.clone(config)
    PhysicsService:RegisterCollisionGroup("PanelFragments")
    PhysicsService:RegisterCollisionGroup("PanelStatic")
    for _, group in PhysicsService:GetRegisteredCollisionGroups() do
        PhysicsService:CollisionGroupSetCollidable("PanelFragments", group.name, group.name == "PanelStatic")
    end
    local oldGroups: { [BasePart]: string } = {}
    local function static(instance: Instance)
        for part in oldGroups do
            if not part.Parent then
                oldGroups[part] = nil
            end
        end
        local items = instance:GetDescendants()
        table.insert(items, instance)
        for _, item in items do
            if item:IsA("BasePart") and item.Anchored then
                if oldGroups[item] == nil then
                    oldGroups[item] = item.CollisionGroup
                end
                item.CollisionGroup = "PanelStatic"
            end
        end
    end
    static(root)
    local terrainGroup = workspace.Terrain.CollisionGroup
    workspace.Terrain.CollisionGroup = "PanelStatic"
    local folder = Instance.new("Folder")
    folder.Name = "PanelFragments"
    folder.Parent = workspace
    local fragments: { Fragment } = {}
    local running = true
    local serial = 0
    local function retire(index: number)
        fragments[index].part:Destroy()
        table.remove(fragments, index)
    end
    local function clear()
        for index = #fragments, 1, -1 do
            retire(index)
        end
    end
    return {
        static = static,
        previousGroup = function(part)
            return oldGroups[part] or part.CollisionGroup
        end,
        count = function()
            return #fragments
        end,
        clear = clear,
        step = function(now)
            for index = #fragments, 1, -1 do
                if now >= fragments[index].expires then
                    retire(index)
                end
            end
        end,
        emit = function(pivot, size, color, now)
            if not running then
                return
            end
            for index = 1, config.perStage do
                while #fragments >= config.maximum do
                    retire(1)
                end
                serial += 1
                local part = Instance.new("Part")
                part.Name = "Fragment" .. tostring(serial)
                part.Size = Vector3.new(math.min(size.X, 1.5), math.min(size.Y, 1.5), math.min(size.Z, 1.5))
                part.Color = color
                part.Material = Enum.Material.Concrete
                -- Deterministic symmetric offsets and bounded velocity; no forces
                -- or constraints keep fragments aloft or attach them to structure.
                local direction =
                    Vector3.new(if index % 2 == 0 then 1 else -1, 0.5, if index <= 2 then 1 else -1).Unit
                part.CFrame = pivot + Vector3.new(direction.X * 2, 0, direction.Z * 2)
                part.CanCollide = true
                part.CanQuery = false
                part.CanTouch = false
                part.CollisionGroup = "PanelFragments"
                part.CustomPhysicalProperties = PhysicalProperties.new(1, 0.7, 0, 100, 100)
                part.Parent = folder
                part:SetNetworkOwner(nil)
                part.AssemblyLinearVelocity = direction * config.speedStudsPerSecond
                part.AssemblyAngularVelocity = Vector3.yAxis * config.angularRadiansPerSecond
                table.insert(fragments, { part = part, expires = now + config.lifetimeSeconds })
            end
        end,
        stop = function()
            if not running then
                return
            end
            running = false
            clear()
            folder:Destroy()
            for part, group in oldGroups do
                if part.Parent then
                    part.CollisionGroup = group
                end
            end
            table.clear(oldGroups)
            workspace.Terrain.CollisionGroup = terrainGroup
            PhysicsService:UnregisterCollisionGroup("PanelFragments")
            PhysicsService:UnregisterCollisionGroup("PanelStatic")
        end,
    },
        nil
end
return PanelFragments
