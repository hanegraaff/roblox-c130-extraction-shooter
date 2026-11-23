--!strict
-- Studio Edit import capture. Verifies the source orientation and scale and
-- retains genuine engine meshes in an out-of-place compiler bank.
local InsertService = game:GetService("InsertService")
local AssetService = game:GetService("AssetService")
local correction = CFrame.Angles(0, math.pi, 0)

local function srgb(value: number): number
    return if value <= 0.0031308 then value * 12.92 else 1.055 * value ^ (1 / 2.4) - 0.055
end

local function shouldCook(role: string, source: string, surface: string): boolean
    if role == "QueryProxy" then
        return true
    end
    if role == "WalkableFloor" or role == "WalkableGallery" then
        return surface:find("^03 ") ~= nil
    end
    if role == "WalkableEntry" then
        return not source:find("^South threshold")
    end
    return false
end

return function(config, captures)
    assert(not captures[config.file], "batch already captured")
    local version = InsertService:GetLatestAssetVersionAsync(assert(tonumber(config.asset)))
    local incoming = InsertService:LoadAssetVersion(version)
    local meshes = Instance.new("Folder")
    local ok, result = pcall(function()
        local maxSizeDelta, maxCenterDelta, cooked, count = 0, 0, 0, 0
        local colorMaps, normalMaps, missing = {}, {}, {}
        local cookFailures = {}
        for _, item in incoming:GetDescendants() do
            assert(not item:IsA("LuaSourceContainer"), "unexpected executable in " .. config.file)
            if not item:IsA("MeshPart") then
                assert(not item:IsA("BasePart"), "unexpected geometry " .. item.ClassName)
                continue
            end
            local key: string? = nil
            local ancestor: Instance? = item
            while ancestor and not key do
                key = ancestor.Name:match("^(PS_[PALH]%d*_%d%d%d_%d%d)")
                ancestor = ancestor.Parent
            end
            local row = assert(key and config.rows[key], "unrecognized mesh " .. item.Name)
            config.rows[key] = nil
            local pose = correction * item.CFrame
            local extent = (item.MeshSize - Vector3.new(table.unpack(row[6]))).Magnitude
            local center = (pose.Position - Vector3.new(table.unpack(row[5]))).Magnitude
            assert(
                extent < 0.06 and center < 0.06,
                string.format("%s extent %.4f / pose %.4f", key, extent, center)
            )
            maxSizeDelta, maxCenterDelta = math.max(maxSizeDelta, extent), math.max(maxCenterDelta, center)
            local mesh = item:Clone()
            mesh:ClearAllChildren()
            local surface = item:FindFirstChildWhichIsA("SurfaceAppearance")
            if surface then
                local appearance = surface:Clone()
                appearance.Name = key .. "_Surface"
                appearance.Parent = mesh
            end
            local texture = if surface and surface.ColorMap ~= "" then surface.ColorMap else mesh.TextureID
            if texture ~= "" then
                colorMaps[texture] = true
            elseif row[8] then
                table.insert(missing, key .. " color " .. row[11])
            end
            if surface and surface.NormalMap ~= "" then
                normalMaps[surface.NormalMap] = true
            elseif row[9] then
                table.insert(missing, key .. " normal " .. row[11])
            end
            if shouldCook(row[2], row[1], row[11]) then
                local created, collider = pcall(function()
                    return AssetService:CreateMeshPartAsync(Content.fromUri(item.MeshId), {
                        CollisionFidelity = Enum.CollisionFidelity.PreciseConvexDecomposition,
                        RenderFidelity = Enum.RenderFidelity.Automatic,
                    })
                end)
                if created and collider and (collider.MeshSize - mesh.MeshSize).Magnitude < 0.001 then
                    mesh:ApplyMesh(collider)
                    collider:Destroy()
                    cooked += 1
                else
                    if created and collider then
                        collider:Destroy()
                    end
                    table.insert(cookFailures, key .. " " .. tostring(collider))
                end
            end
            local color = row[7]
            mesh.Color = if row[8]
                then Color3.new(1, 1, 1)
                else Color3.new(srgb(color[1]), srgb(color[2]), srgb(color[3]))
            mesh.Transparency = math.clamp(1 - color[4], 0, 1)
            if row[10] then
                mesh.Material = Enum.Material.Neon
            end
            mesh.Name = key
            mesh.Size = item.Size
            mesh.CFrame = pose
            mesh.Anchored, mesh.CanCollide, mesh.CanQuery, mesh.CanTouch = true, false, false, false
            mesh:SetAttribute("NativeMeshId", mesh.MeshId)
            mesh:SetAttribute("NativeMeshSize", mesh.MeshSize)
            mesh:SetAttribute("NativeCollisionFidelity", mesh.CollisionFidelity.Name)
            mesh:SetAttribute("NativeRenderFidelity", mesh.RenderFidelity.Name)
            mesh:SetAttribute("SeedshipRole", row[2])
            mesh:SetAttribute("SourceObject", row[1])
            mesh:SetAttribute("SourcePanelId", if row[3] ~= "" then row[3] else nil)
            mesh:SetAttribute("SourceAppearance", if row[4] ~= "" then row[4] else nil)
            mesh:SetAttribute("ThermalNonCover", if row[12] then true else nil)
            mesh.Parent = meshes
            count += 1
        end
        assert(not next(config.rows), "missing imported meshes in " .. config.file)
        return {
            count = count,
            version = tostring(version),
            colorMaps = colorMaps,
            normalMaps = normalMaps,
            maxSizeDelta = maxSizeDelta,
            maxCenterDelta = maxCenterDelta,
            missing = missing,
            cooked = cooked,
            cookFailures = cookFailures,
        }
    end)
    incoming:Destroy()
    if not ok then
        meshes:Destroy()
        error(result)
    end
    captures[config.file] = meshes
    return result
end
