--!strict
--[=[
    Detached Studio Edit compiler step. Validates one approved import against
    its material-split source, then retains genuine native parts in an in-memory
    batch for final assembly. No edits to the cloud document.
]=]
local InsertService = game:GetService("InsertService")
local correction = CFrame.Angles(0, math.pi, 0)

-- The importer bakes GLB node rotations into its vertices and reverses the
-- horizontal axes. Measure after correction so the target stays at 1:1 scale.
local function linearToSrgb(value: number): number
    return if value <= 0.0031308 then value * 12.92 else 1.055 * value ^ (1 / 2.4) - 0.055
end

return function(config, batches)
    assert(not batches[config.file], "batch is already captured")
    local id = assert(tonumber(config.model))
    local version = InsertService:GetLatestAssetVersionAsync(id)
    local incoming = InsertService:LoadAssetVersion(version)
    local bank = Instance.new("Folder")
    local ok, result = pcall(function()
        local records = {}
        for _, row in config.rows do
            records[row[1]] = row
        end
        local maps = {}
        local missing = {}
        local worstExtent, worstCenter = 0, 0
        for _, item in incoming:GetDescendants() do
            assert(not item:IsA("LuaSourceContainer"), "unexpected executable content")
            if not item:IsA("MeshPart") then
                assert(not item:IsA("BasePart"), "Unexpected geometry " .. item.ClassName)
                continue
            end
            local key: string? = nil
            local current: Instance? = item
            while current and not key do
                key = string.match(current.Name, "^(SF_[PAD]%d*_%d%d%d_%d%d)")
                current = current.Parent
            end
            local row = if key then records[key] else nil
            assert(key and row, "Unknown or duplicate imported mesh " .. item:GetFullName())
            records[key] = nil
            local fixed = correction * item.CFrame
            local expectedSize = Vector3.new(table.unpack(row[6]))
            local expectedCenter = Vector3.new(table.unpack(row[5]))
            local extent = (item.MeshSize - expectedSize).Magnitude
            local center = (fixed.Position - expectedCenter).Magnitude
            worstExtent, worstCenter = math.max(worstExtent, extent), math.max(worstCenter, center)
            assert(
                extent < 0.06 and center < 0.06,
                string.format("%s dimensions/center differ by %.4f/%.4f", key, extent, center)
            )
            local clone = item:Clone()
            clone:ClearAllChildren()
            local surface = item:FindFirstChildWhichIsA("SurfaceAppearance")
            if surface then
                surface:Clone().Parent = clone
            end
            local texture = if surface and surface.ColorMap ~= "" then surface.ColorMap else clone.TextureID
            if texture ~= "" then
                maps[texture] = true
            elseif row[8] then
                missing[row[9]] = (missing[row[9]] or 0) + 1
            end
            local color = row[7]
            clone.Color = if row[8]
                then Color3.new(1, 1, 1)
                else Color3.new(linearToSrgb(color[1]), linearToSrgb(color[2]), linearToSrgb(color[3]))
            clone.Transparency = math.clamp(1 - color[4], 0, 1)
            if row[10] then
                clone.Material = Enum.Material.Neon
            end
            clone.Name = key
            clone.CFrame = fixed
            clone.Anchored = true
            clone.CanCollide = false
            clone.CanQuery = false
            clone.CanTouch = false
            clone:SetAttribute("NativeMeshId", clone.MeshId)
            clone:SetAttribute("NativeMeshSize", clone.MeshSize)
            clone:SetAttribute("NativeCollisionFidelity", clone.CollisionFidelity.Name)
            clone:SetAttribute("NativeRenderFidelity", clone.RenderFidelity.Name)
            clone:SetAttribute("ImportMaterialKey", row[9])
            clone:SetAttribute("SaltFlatsRole", row[2])
            if row[3] ~= "" then
                clone:SetAttribute("SourcePanelId", row[3])
                clone:SetAttribute("SourceAppearance", row[4])
            end
            if row[2] == "dressing" then
                clone:AddTag("ThermalNonCover")
            end
            clone.Parent = bank
        end
        local unmatched = next(records)
        assert(not unmatched, "Missing imported mesh " .. tostring(unmatched))
        return {
            asset = tostring(id),
            version = tostring(version),
            count = #bank:GetChildren(),
            maxSizeDelta = worstExtent,
            maxCenterDelta = worstCenter,
            missing = missing,
            colorMaps = maps,
        }
    end)
    incoming:Destroy()
    if not ok then
        bank:Destroy()
        error(result)
    end
    batches[config.file] = bank
    return result
end
