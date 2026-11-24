--!strict
-- Studio Edit only. Checks a hash-bound import batch against the approved
-- lobby's measured geometry and transfers genuine native parts to an unparented
-- bank. The caller owns the bank and the calibration established by the pilot.

local InsertService = game:GetService("InsertService")

type Row = {
    name: string,
    sourceObject: string,
    role: string,
    material: string,
    triangles: number,
    center: { number },
    size: { number },
    orientedCenter: { number },
    intrinsicSize: { number },
    orientedBasis: { { number } },
    linearColor: { number },
    colorSha256: string?,
    portrait: number?,
}

type Configuration = {
    file: string,
    sha256: string,
    sourceSha256: string,
    siteOrigin: { number },
    rows: { [string]: Row },
}

local function componentToSrgb(value: number): number
    return if value <= 0.0031308 then 12.92 * value else 1.055 * value ^ (1 / 2.4) - 0.055
end

local function nativeKey(part: MeshPart, root: Instance): string?
    local current: Instance? = part
    while current and current ~= root do
        local key = current.Name:match("^(P22_[%a%d]+_%d+_%d%d)")
        if key then
            return key
        end
        current = current.Parent
    end
    return nil
end

-- Inspect the native part in corrected lobby axes. The importer may bake the
-- source orientation into the mesh or retain it on the part's CFrame.
local function correctedExtent(pose: CFrame, size: Vector3): Vector3
    local right = pose.RightVector:Abs() * size.X
    local up = pose.UpVector:Abs() * size.Y
    local back = pose.ZVector:Abs() * size.Z
    return right + up + back
end

-- Acceptance covers both native storage choices. Using an oriented part's
-- rectangular bound for its exact rotated vertex bound can overstate a
-- sculpted or irregular mesh, so compare that form in its own local axes.
local function measureDeltas(pose: CFrame, meshSize: Vector3, row: Row): (number, number)
    local bakedCenter = (pose.Position - Vector3.new(table.unpack(row.center))).Magnitude
    local bakedSize = (correctedExtent(pose, meshSize) - Vector3.new(table.unpack(row.size))).Magnitude
    if bakedCenter < 0.06 and bakedSize < 0.06 then
        return bakedCenter, bakedSize
    end
    local basis = row.orientedBasis
    local matchesAxes = pose.RightVector:FuzzyEq(Vector3.new(table.unpack(basis[1])), 0.001)
        and pose.UpVector:FuzzyEq(Vector3.new(table.unpack(basis[2])), 0.001)
        and pose.ZVector:FuzzyEq(Vector3.new(table.unpack(basis[3])), 0.001)
    if matchesAxes then
        return (pose.Position - Vector3.new(table.unpack(row.orientedCenter))).Magnitude,
            (meshSize - Vector3.new(table.unpack(row.intrinsicSize))).Magnitude
    end
    return bakedCenter, bakedSize
end

-- Load the named asset version in Edit mode. Return an unparented Folder and a
-- serializable receipt. A wrong version, transform or incomplete batch rejects
-- before any candidate enters Workspace. The calibrated correction excludes
-- the protected site's translation, which is assigned separately.
return function(config: Configuration, assetId: number, correction: CFrame)
    local version = InsertService:GetLatestAssetVersionAsync(assetId)
    local incoming = InsertService:LoadAssetVersion(version)
    local bank = Instance.new("Folder")
    bank.Name = config.file:gsub("%.glb$", "")
    local success, result = pcall(function()
        local seen: { [string]: boolean } = {}
        local missingColor: { string } = {}
        local parts = {}
        local site = Vector3.new(table.unpack(config.siteOrigin))
        local maxSizeDelta, maxCenterDelta, count = 0, 0, 0
        for _, instance in incoming:GetDescendants() do
            assert(not instance:IsA("LuaSourceContainer"), "Unexpected executable in " .. config.file)
            if not instance:IsA("MeshPart") then
                assert(not instance:IsA("BasePart"), "Unexpected geometry " .. instance.ClassName)
                continue
            end
            local key = assert(nativeKey(instance, incoming), "Unrecognized native mesh " .. instance.Name)
            local row = assert(config.rows[key], "Unknown native key " .. key)
            assert(not seen[key], "Duplicate native key " .. key)
            assert(instance.MeshId ~= "", "Empty native MeshId on " .. key)
            assert((instance.Size - instance.MeshSize).Magnitude < 0.06, "Importer resized " .. key)
            local pose = correction * instance.CFrame
            local centerDelta, sizeDelta = measureDeltas(pose, instance.MeshSize, row)
            assert(
                centerDelta < 0.06 and sizeDelta < 0.06,
                string.format(
                    "%s pose delta %.4f studs, mesh-size delta %.4f studs",
                    key,
                    centerDelta,
                    sizeDelta
                )
            )
            maxCenterDelta = math.max(maxCenterDelta, centerDelta)
            maxSizeDelta = math.max(maxSizeDelta, sizeDelta)

            local mesh = instance:Clone()
            mesh:ClearAllChildren()
            mesh.Name = row.name
            mesh.Anchored, mesh.CanCollide, mesh.CanQuery, mesh.CanTouch = true, false, false, false
            mesh.CFrame = pose + site
            local color = row.linearColor
            local surface = instance:FindFirstChildWhichIsA("SurfaceAppearance")
            if surface then
                local appearance = surface:Clone()
                appearance.Name = row.name .. "_Surface"
                appearance.Parent = mesh
            end
            local colorMap = if surface and surface.ColorMap ~= "" then surface.ColorMap else mesh.TextureID
            if row.colorSha256 and colorMap == "" then
                table.insert(missingColor, row.name)
            end
            if row.colorSha256 then
                mesh.Color = Color3.new(1, 1, 1)
            else
                mesh.Color = Color3.new(
                    componentToSrgb(color[1]),
                    componentToSrgb(color[2]),
                    componentToSrgb(color[3])
                )
            end
            mesh.Transparency = math.clamp(1 - color[4], 0, 1)
            mesh:SetAttribute("LobbyArtSource", row.sourceObject)
            mesh:SetAttribute("LobbyArtRole", row.role)
            mesh:SetAttribute("LobbyPortrait", row.portrait)
            mesh:SetAttribute("LobbyColorSourceSha256", row.colorSha256)
            mesh:SetAttribute("NativeMeshId", mesh.MeshId)
            mesh:SetAttribute("NativeMeshSize", mesh.MeshSize)
            mesh:SetAttribute("NativeCollisionFidelity", mesh.CollisionFidelity.Name)
            mesh:SetAttribute("NativeRenderFidelity", mesh.RenderFidelity.Name)
            mesh.Parent = bank
            parts[row.name] = {
                source = row.sourceObject,
                role = row.role,
                material = row.material,
                portrait = row.portrait,
                meshId = mesh.MeshId,
                meshSize = { mesh.MeshSize.X, mesh.MeshSize.Y, mesh.MeshSize.Z },
                pose = { mesh.CFrame:GetComponents() },
                colorMap = colorMap,
                colorSourceSha256 = row.colorSha256,
            }
            seen[key] = true
            count += 1
        end
        for key in config.rows do
            assert(seen[key], "Missing native part " .. key)
        end
        return {
            assetId = tostring(assetId),
            version = tostring(version),
            batch = config.file,
            batchSha256 = config.sha256,
            approvedExportSha256 = config.sourceSha256,
            count = count,
            maxCenterDelta = maxCenterDelta,
            maxSizeDelta = maxSizeDelta,
            missingColor = missingColor,
            parts = parts,
        }
    end)
    incoming:Destroy()
    if not success then
        bank:Destroy()
        error(result)
    end
    return bank, result
end
