--!strict
--[=[
    Capture one approved Sandbreak model from Studio Edit into a native RBXM.
    The caller supplies the hash-bound staging rows and the approved asset ID.
    Stores Base64 in a caller-owned local transfer folder for chunked retrieval.
    The detached asset and configured parts are destroyed after serialization.
]=]

local AssetService = game:GetService("AssetService")
local EncodingService = game:GetService("EncodingService")
local InsertService = game:GetService("InsertService")
local SerializationService = game:GetService("SerializationService")

type Row = {
    importName: string,
    sourceObject: string,
    sourceProperties: { [string]: string | number | boolean },
    material: string,
    expectsColorMap: boolean,
    baseColor: { number },
    emissive: boolean,
    posedMinimum: { number },
    posedMaximum: { number },
}

local function vector(values: { number }): Vector3
    return Vector3.new(values[1], values[2], values[3])
end

local function linearToSrgb(value: number): number
    return if value <= 0.0031308 then 12.92 * value else 1.055 * value ^ (1 / 2.4) - 0.055
end

local function getSource(part: MeshPart, source: Instance, rows: { [string]: Row }): Row?
    local ancestor: Instance? = part
    while ancestor and ancestor ~= source do
        local name = string.match(ancestor.Name, "^(SB_[%w_]+_%d%d%d_%d%d)")
        if name and rows[name] then
            return rows[name]
        end
        ancestor = ancestor.Parent
    end
    return nil
end

return function(assetId: number, kind: string, expected: { Row }, output: Folder)
    assert(not output:FindFirstChild(kind), "Existing native capture for " .. kind)
    local version = InsertService:GetLatestAssetVersionAsync(assetId)
    local source = InsertService:LoadAssetVersion(version)
    local bank = Instance.new("Folder")
    bank.Name = kind
    local staged = Instance.new("Folder")
    staged.Name = kind
    local ok, report = pcall(function()
        local rows = {}
        for _, row in expected do
            assert(not rows[row.importName], "Duplicate staged key " .. row.importName)
            rows[row.importName] = row
        end
        local count, extentDelta, centerDelta = 0, 0, 0
        local textureIds: { [string]: boolean } = {}
        local correction = CFrame.Angles(0, math.pi, 0)
        for _, incoming in source:GetDescendants() do
            assert(not incoming:IsA("LuaSourceContainer"), "Unexpected executable in native asset")
            assert(not incoming:IsA("BasePart") or incoming:IsA("MeshPart"), "Unexpected geometry class")
            if not incoming:IsA("MeshPart") then
                continue
            end
            local row = assert(
                getSource(incoming, source, rows),
                "Unexpected or duplicate native mesh " .. incoming.Name
            )
            rows[row.importName] = nil
            local min, max = vector(row.posedMinimum), vector(row.posedMaximum)
            local pose = correction * incoming.CFrame
            local sizeError = (incoming.MeshSize - (max - min)).Magnitude
            local centerError = (pose.Position - (min + max) / 2).Magnitude
            assert(
                sizeError < 0.06 and centerError < 0.06,
                string.format("%s extent/center differs %.4f/%.4f", row.importName, sizeError, centerError)
            )
            extentDelta, centerDelta = math.max(extentDelta, sizeError), math.max(centerDelta, centerError)
            local solid = row.material == "query"
            local part: MeshPart
            if solid then
                part = AssetService:CreateMeshPartAsync(Content.fromUri(incoming.MeshId), {
                    CollisionFidelity = Enum.CollisionFidelity.PreciseConvexDecomposition,
                })
                assert(
                    part.CollisionFidelity == Enum.CollisionFidelity.PreciseConvexDecomposition,
                    "Studio refused exact query profile"
                )
                assert(
                    (part.MeshSize - incoming.MeshSize).Magnitude < 0.01,
                    "Query mesh profile size mismatch"
                )
                part.Transparency = 1
                part.CastShadow = false
            else
                part = incoming:Clone()
                part:ClearAllChildren()
                local surface = incoming:FindFirstChildWhichIsA("SurfaceAppearance")
                if surface then
                    surface:Clone().Parent = part
                end
                local colorMap = if surface and surface.ColorMap ~= ""
                    then surface.ColorMap
                    else part.TextureID
                if row.expectsColorMap then
                    assert(colorMap ~= "", "Missing imported color map for " .. row.importName)
                    textureIds[colorMap] = true
                    part.Color = Color3.new(1, 1, 1)
                else
                    local color = row.baseColor
                    part.Color =
                        Color3.new(linearToSrgb(color[1]), linearToSrgb(color[2]), linearToSrgb(color[3]))
                end
                if row.emissive then
                    part.Material = Enum.Material.Neon
                end
                part.Transparency = math.clamp(1 - row.baseColor[4], 0, 1)
            end
            part.Parent = bank
            part.Name = row.importName
            part.CFrame = pose
            part.PivotOffset = CFrame.identity
            part.Size = incoming.Size
            part.Anchored = true
            part.CanCollide = solid
            part.CanQuery = solid
            part.CanTouch = false
            part:SetAttribute("NativeMeshId", part.MeshId)
            part:SetAttribute("NativeMeshSize", part.MeshSize)
            part:SetAttribute("NativeCollisionFidelity", part.CollisionFidelity.Name)
            part:SetAttribute("NativeRenderFidelity", part.RenderFidelity.Name)
            part:SetAttribute("SandbreakSourceObject", row.sourceObject)
            for _, key in { "PanelId", "Appearance", "SupportPanels", "Surface", "ThermalNonCover" } do
                if row.sourceProperties[key] ~= nil then
                    part:SetAttribute("Source" .. key, row.sourceProperties[key])
                end
            end
            if solid then
                part:SetAttribute("PanelProxy", true)
            end
            count += 1
        end
        local missing = next(rows)
        assert(not missing, "Missing native mesh " .. tostring(missing))
        local serial = SerializationService:SerializeInstancesAsync({ bank })
        local encoded = buffer.tostring(EncodingService:Base64Encode(serial))
        local chunkSize = 48000
        for first = 1, #encoded, chunkSize do
            local chunk = Instance.new("StringValue")
            chunk.Name = string.format("%03d", math.floor((first - 1) / chunkSize) + 1)
            chunk.Value = string.sub(encoded, first, first + chunkSize - 1)
            chunk.Parent = staged
        end
        staged.Parent = output
        local textures = {}
        for texture in textureIds do
            table.insert(textures, texture)
        end
        table.sort(textures)
        return {
            count = count,
            assetId = tostring(assetId),
            versionId = tostring(version),
            base64Length = #encoded,
            maxSizeDeltaStuds = extentDelta,
            maxCenterDeltaStuds = centerDelta,
            colorMaps = textures,
        }
    end)
    bank:Destroy()
    source:Destroy()
    if not ok then
        staged:Destroy()
        error(report)
    end
    return report
end
