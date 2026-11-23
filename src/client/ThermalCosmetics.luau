--!strict
--[=[
    ThermalCosmetics: client-only operator depth consistency for explicitly marked
    non-cover art. Native Occluded highlights retain all real cover depth. Only
    server-authored ThermalNonCover art is hidden when it neither collides nor
    queries. Explicit PanelFragmentVisual bodies in the PanelFragments collision
    group may collide with static scenery only and are also hidden from thermal
    depth. Real solid cover remains visible; ground keeps all art/fragments.
    Battlefield Parts and textured surfaces use a muted 0.45 brightness base;
    authored Terrain palette uses 0.4. Character colors are not changed.
    Imported Models can also author an immutable ThermalBrightness multiplier
    and optional surface palette for operator-only tinting. Restores owned
    opacity, color, surfaces and listeners on role/map/fragment teardown.
    No remotes, physics writes, authority or yielding.
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local black = Color3.new(0, 0, 0)
local ThermalCosmetics = {}
export type Controller = { stop: () -> (), resources: () -> number }
type Owned = {
    original: number,
    restoreColor: (() -> ())?,
    hidden: boolean,
    fragmentWatches: boolean,
    connections: { RBXScriptConnection },
}

-- Models scope the optional brightness to their present and future descendants.
-- Only finite multipliers between black and the original color are accepted.
local function artScope(part: BasePart, root: Instance): (number, Instance?)
    local world = workspace:FindFirstChild("World")
    local environment = world ~= nil and part:IsDescendantOf(world)
    local base = if environment then 0.45 else 1
    local ancestor = part.Parent
    while ancestor do
        if ancestor:IsA("Model") then
            local multiplier = ancestor:GetAttribute("ThermalBrightness")
            if type(multiplier) == "number" and multiplier >= 0 and multiplier <= 1 then
                return multiplier * base, ancestor
            end
        end
        if ancestor == root then
            break
        end
        ancestor = ancestor.Parent
    end
    return base, if environment then world else nil
end

-- Use a local SurfaceAppearance for mapped pixels on legacy TextureID meshes.
-- The template references the source color map so its detail survives tinting.
local function tint(part: BasePart, root: Instance): (() -> ())?
    if part.Transparency >= 1 then
        return nil
    end
    local multiplier, scope = artScope(part, root)
    if multiplier == 1 or not scope then
        return nil
    end
    local fade = 1 - multiplier
    if part:IsA("MeshPart") then
        local surface = part:FindFirstChildWhichIsA("SurfaceAppearance")
        if surface then
            local original = surface.Color
            surface.Color = original:Lerp(black, fade)
            return function()
                surface.Color = original
            end
        end
        if part.TextureID ~= "" then
            local paletteName = scope:GetAttribute("ThermalSurfacePalette")
            local material = part:GetAttribute("ImportMaterialKey")
            local shared = ReplicatedStorage:FindFirstChild("Shared")
            local palette = if shared and type(paletteName) == "string"
                then shared:FindFirstChild(paletteName)
                else nil
            local template = if palette
                    and palette:IsA("Folder")
                    and type(material) == "string"
                then palette:FindFirstChild(material)
                else nil
            if not template or not template:IsA("SurfaceAppearance") then
                local original = part.Color
                part.Color = original:Lerp(black, fade)
                return function()
                    part.Color = original
                end
            end
            local applied = template:Clone()
            applied.Color = applied.Color:Lerp(black, fade)
            applied.Parent = part
            return function()
                applied:Destroy()
            end
        end
    end
    local original = part.Color
    part.Color = original:Lerp(black, fade)
    return function()
        part.Color = original
    end
end

-- Watches one workspace/fixture subtree. Attribute/property ordering may differ
-- during replication, so late flags and conversion into real cover are handled.
function ThermalCosmetics.start(root: Instance): Controller
    local owned: { [BasePart]: Owned } = {}
    local running = true
    -- Terrain material colors are local rendering state. Darken the authored
    -- battlefield palette without changing voxels, collision or Ground clients.
    local terrainColors: { [Enum.Material]: Color3 } = {}
    if root == workspace then
        for _, material in
            {
                Enum.Material.Sand,
                Enum.Material.Sandstone,
                Enum.Material.Ground,
                Enum.Material.Cobblestone,
                Enum.Material.Grass,
                Enum.Material.LeafyGrass,
                Enum.Material.Asphalt,
                Enum.Material.Pavement,
                Enum.Material.Mud,
            }
        do
            local original = workspace.Terrain:GetMaterialColor(material)
            terrainColors[material] = original
            workspace.Terrain:SetMaterialColor(material, original:Lerp(black, 0.6))
        end
    end
    local function release(part: BasePart)
        local record = owned[part]
        if not record then
            return
        end
        for _, connection in record.connections do
            connection:Disconnect()
        end
        if record.hidden then
            part.LocalTransparencyModifier = record.original
        end
        if record.restoreColor then
            record.restoreColor()
        end
        owned[part] = nil
    end
    local function observe(item: Instance)
        if not item:IsA("BasePart") or owned[item] or not running then
            return
        end
        local part = item
        local record: Owned = {
            original = part.LocalTransparencyModifier,
            restoreColor = nil,
            hidden = false,
            fragmentWatches = false,
            connections = {},
        }
        owned[part] = record
        local function update()
            if not running or owned[part] ~= record then
                return
            end
            local fragmentMarker = part:GetAttribute("PanelFragmentVisual") == true
            if fragmentMarker and not record.fragmentWatches then
                record.fragmentWatches = true
                for _, property in { "CollisionGroup", "Anchored", "CanTouch" } do
                    table.insert(record.connections, part:GetPropertyChangedSignal(property):Connect(update))
                end
            end
            local fragment = fragmentMarker
                and part.CollisionGroup == "PanelFragments"
                and not part.Anchored
                and not part.CanTouch
            local hide = part:GetAttribute("ThermalNonCover") == true
                and not part.CanQuery
                and (not part.CanCollide or fragment)
            if hide and not record.hidden then
                record.original = part.LocalTransparencyModifier
                record.hidden = true
                part.LocalTransparencyModifier = 1
            elseif not hide and record.hidden then
                part.LocalTransparencyModifier = record.original
                record.hidden = false
            end
            if not hide and not record.restoreColor then
                record.restoreColor = tint(part, root)
            end
        end
        table.insert(record.connections, part:GetAttributeChangedSignal("ThermalNonCover"):Connect(update))
        table.insert(
            record.connections,
            part:GetAttributeChangedSignal("PanelFragmentVisual"):Connect(update)
        )
        table.insert(record.connections, part:GetPropertyChangedSignal("CanCollide"):Connect(update))
        table.insert(record.connections, part:GetPropertyChangedSignal("CanQuery"):Connect(update))
        update()
    end
    local added = root.DescendantAdded:Connect(observe)
    local removed = root.DescendantRemoving:Connect(function(item)
        if item:IsA("BasePart") then
            release(item)
        end
    end)
    for _, item in root:GetDescendants() do
        observe(item)
    end
    return {
        resources = function()
            local count = 0
            for _ in owned do
                count += 1
            end
            return count
        end,
        stop = function()
            if not running then
                return
            end
            running = false
            added:Disconnect()
            removed:Disconnect()
            for material, original in terrainColors do
                workspace.Terrain:SetMaterialColor(material, original)
            end
            table.clear(terrainColors)
            for part in owned do
                release(part)
            end
        end,
    }
end

return ThermalCosmetics
