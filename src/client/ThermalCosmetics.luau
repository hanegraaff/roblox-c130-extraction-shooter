--!strict
--[=[
    ThermalCosmetics: client-only operator depth consistency for explicitly marked
    non-cover art. Native Occluded highlights retain all real cover depth. Only
    server-authored ThermalNonCover Parts that neither collide nor query are
    locally hidden; ground players keep the furnished scene. Owns/restores each
    LocalTransparencyModifier and all listeners across role/map/fragment teardown.
    No remotes, physics writes, authority or yielding.
]=]
local ThermalCosmetics = {}
export type Controller = { stop: () -> (), resources: () -> number }
type Owned = { original: number, hidden: boolean, connections: { RBXScriptConnection } }

-- Watches one workspace/fixture subtree. Attribute/property ordering may differ
-- during replication, so late flags and conversion into real cover are handled.
function ThermalCosmetics.start(root: Instance): Controller
    local owned: { [BasePart]: Owned } = {}
    local running = true
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
        owned[part] = nil
    end
    local function observe(item: Instance)
        if not item:IsA("BasePart") or owned[item] or not running then
            return
        end
        local part = item
        local record: Owned = { original = part.LocalTransparencyModifier, hidden = false, connections = {} }
        owned[part] = record
        local function update()
            local hide = part:GetAttribute("ThermalNonCover") == true
                and not part.CanCollide
                and not part.CanQuery
            if hide and not record.hidden then
                record.original = part.LocalTransparencyModifier
                record.hidden = true
                part.LocalTransparencyModifier = 1
            elseif not hide and record.hidden then
                part.LocalTransparencyModifier = record.original
                record.hidden = false
            end
        end
        table.insert(record.connections, part:GetAttributeChangedSignal("ThermalNonCover"):Connect(update))
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
            for part in owned do
                release(part)
            end
        end,
    }
end

return ThermalCosmetics
