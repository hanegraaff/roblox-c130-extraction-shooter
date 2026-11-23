--!strict
--[=[
    Studio Edit-only compiler for the verified Vesper batches. Uses unparented
    imports and genuine engine MeshPart constructors. Produces two detached
    roots for serialization and native package checks. The current document
    supplies asset access; neither root is inserted into the document here.
]=]
local Insert = game:GetService("InsertService")
local Assets = game:GetService("AssetService")
local Serializer = game:GetService("SerializationService")

type Row = {
    key: string,
    meshName: string,
    sourceObject: string,
    role: string,
    panelId: string?,
    appearance: string?,
    material: string,
    center: { number },
    size: { number },
}
type PanelRecord = {
    id: string,
    pivot: { number },
    pristineSource: string,
    heavySource: string,
    lightSource: string,
    intactProxy: string,
    heavyProxy: string,
}
type Config = {
    models: { number },
    rows: { Row },
    panels: { PanelRecord },
    fragments: { [string]: { string } },
    colors: { [string]: { number } },
    receipt: string,
    source: string,
}
local correction = CFrame.Angles(0, math.pi, 0)
local tolerance = 0.025

local function vector(row: { number }): Vector3
    return Vector3.new(row[1], row[2], row[3])
end

local function nativeContent(part: MeshPart)
    assert(
        part.MeshId ~= "" and part.MeshSize.X > 0 and part.MeshSize.Y > 0 and part.MeshSize.Z > 0,
        part.Name
    )
    part:SetAttribute("NativeGeometryVersion", 1)
    part:SetAttribute("NativeMeshId", part.MeshId)
    part:SetAttribute("NativeMeshSize", part.MeshSize)
    part:SetAttribute("NativeCollisionFidelity", part.CollisionFidelity.Name)
    part:SetAttribute("NativeRenderFidelity", part.RenderFidelity.Name)
end

local function correctColor(linear: number): number
    return if linear <= 0.0031308 then linear * 12.92 else 1.055 * linear ^ (1 / 2.4) - 0.055
end

local function createFolder(parent: Instance, name: string): Folder
    local folder = Instance.new("Folder")
    folder.Name = name
    folder.Parent = parent
    return folder
end

local function chooseRow(part: MeshPart, candidates: { Row }, used: { [string]: boolean }): Row
    local center = correction:PointToWorldSpace(part.Position)
    local best: Row? = nil
    local distance = math.huge
    for _, row in candidates do
        if not used[row.key] then
            local measured = (vector(row.center) - center).Magnitude
            if measured < distance then
                best, distance = row, measured
            end
        end
    end
    assert(
        best and distance < tolerance,
        "native Vesper center mismatch: " .. part:GetFullName() .. " " .. distance
    )
    return best
end

return function(config: Config, status: { [string]: unknown })
    local assembly = Instance.new("Model")
    assembly.Name = "VesperArray"
    assembly.WorldPivot = CFrame.identity
    assembly:SetAttribute("ImportReceiptSha256", config.receipt)
    assembly:SetAttribute("BlendSha256", config.source)
    assembly:SetAttribute("PanelLayoutVersion", 3)
    local structure = createFolder(assembly, "Warehouse_Static")
    local panels = createFolder(assembly, "Warehouse_Panels")
    local furnishing = createFolder(assembly, "Warehouse_Furnishing")
    local variants = Instance.new("Folder")
    variants.Name = "VesperPanelVariants"
    variants:SetAttribute("ImportReceiptSha256", config.receipt)
    local wallFragments = createFolder(variants, "WallFragments")
    local roofFragments = createFolder(variants, "RoofFragments")
    local captured: { Instance } = { assembly, variants }

    local worked, result = xpcall(function()
        local expected: { [string]: { Row } } = {}
        local used: { [string]: boolean } = {}
        local byObject: { [string]: { MeshPart } } = {}
        local textures: { [string]: string } = {}
        local missingMaps: { [string]: boolean } = {}
        local solidProfiles: { [string]: MeshPart } = {}
        local pieces = 0
        for _, row in config.rows do
            local matches = expected[row.meshName] or {}
            table.insert(matches, row)
            expected[row.meshName] = matches
        end
        local latest: { string } = {}
        for _, id in config.models do
            local versionId = Insert:GetLatestAssetVersionAsync(id)
            table.insert(latest, tostring(versionId))
            local incoming = Insert:LoadAssetVersion(versionId)
            table.insert(captured, incoming)
            for _, item in incoming:GetDescendants() do
                assert(not item:IsA("LuaSourceContainer"), "unexpected imported executable content")
                if item:IsA("MeshPart") then
                    local names = expected[item.Name]
                    assert(names, "unexpected Vesper mesh: " .. item:GetFullName())
                    local row = chooseRow(item, names, used)
                    local wanted = vector(row.size)
                    local size = item.Size
                    local errorStuds = math.max(
                        math.abs(size.X - wanted.X),
                        math.abs(size.Y - wanted.Y),
                        math.abs(size.Z - wanted.Z)
                    )
                    assert(
                        errorStuds < tolerance,
                        "native Vesper extent mismatch: " .. row.key .. " " .. errorStuds
                    )
                    used[row.key] = true
                    local solid = row.role == "walkable"
                        or row.role == "support"
                        or row.role == "mechanism-proxy"
                        or row.role == "collision-query"
                    local part: MeshPart
                    if solid then
                        local profile = solidProfiles[item.MeshId]
                        if not profile then
                            local created = Assets:CreateMeshPartAsync(Content.fromUri(item.MeshId), {
                                CollisionFidelity = Enum.CollisionFidelity.PreciseConvexDecomposition,
                                RenderFidelity = Enum.RenderFidelity.Automatic,
                            })
                            profile = created
                            solidProfiles[item.MeshId] = created
                            table.insert(captured, created)
                        end
                        part = profile:Clone()
                    else
                        part = item:Clone()
                    end
                    part:ClearAllChildren()
                    part.Name = row.key
                    part.Size = item.Size
                    part.CFrame = correction * item.CFrame
                    part.Anchored = true
                    part.CanCollide = solid
                    part.CanQuery = solid
                    part.CanTouch = false
                    nativeContent(part)
                    local texture = item.TextureID
                    local surface = item:FindFirstChildWhichIsA("SurfaceAppearance")
                    if texture == "" and surface then
                        texture = surface.ColorMap
                    end
                    if texture ~= "" then
                        assert(
                            string.match(texture, "^rbxassetid://%d+$"),
                            "unexpected Vesper texture reference"
                        )
                        textures[row.material] = texture
                    end
                    local color = config.colors[row.material]
                    if color then
                        part.Color =
                            Color3.new(correctColor(color[1]), correctColor(color[2]), correctColor(color[3]))
                    else
                        part.Color = Color3.new(1, 1, 1)
                        if texture == "" then
                            missingMaps[row.material] = true
                        end
                    end
                    part.TextureID = texture
                    if row.material == "ember" or row.material == "teal" then
                        part.Material = Enum.Material.Neon
                    end
                    local isProxy = row.role == "collision-query" or row.role == "mechanism-proxy"
                    if isProxy then
                        part.Transparency = 1
                        part.CastShadow = false
                        part.TextureID = ""
                        part:SetAttribute("PanelProxy", if row.role == "collision-query" then true else nil)
                    elseif not solid then
                        part:SetAttribute("ThermalNonCover", true)
                    end
                    local object = byObject[row.sourceObject] or {}
                    table.insert(object, part)
                    byObject[row.sourceObject] = object
                    part:SetAttribute("ImportMaterialKey", row.material)
                    table.insert(captured, part)
                    pieces += 1
                    if pieces % 40 == 0 then
                        status.pieces = pieces
                        task.wait()
                    end
                end
            end
            incoming:Destroy()
        end
        assert(pieces == #config.rows, "Vesper batch lost imported pieces")
        for key in missingMaps do
            assert(textures[key], "no native Vesper texture for " .. key)
        end
        local function objectParts(name: string): { MeshPart }
            local parts = byObject[name]
            assert(parts, "missing Vesper source object " .. name)
            byObject[name] = nil
            return parts
        end
        local function fitVisual(part: MeshPart)
            local key = part:GetAttribute("ImportMaterialKey")
            if type(key) == "string" and part.TextureID == "" and textures[key] and part.Transparency < 1 then
                part.TextureID = textures[key]
            end
        end
        local function place(parts: { MeshPart }, parent: Instance, frame: CFrame)
            for _, part in parts do
                fitVisual(part)
                part.CFrame = frame:ToObjectSpace(part.CFrame)
                part.Parent = parent
            end
        end
        for _, record in config.panels do
            local panel = Instance.new("Model")
            panel.Name = record.id
            local pivot = CFrame.new(vector(record.pivot))
            panel.WorldPivot = pivot
            panel:SetAttribute("VesperPanel", true)
            local visuals = objectParts(record.pristineSource)
            local intact = objectParts(record.intactProxy)
            for _, part in intact do
                part:SetAttribute("PanelId", record.id)
            end
            panel.Parent = panels
            place(visuals, panel, CFrame.identity)
            place(intact, panel, CFrame.identity)
            local _, size = panel:GetBoundingBox()
            panel:SetAttribute("IntactSize", size)
            local settings = createFolder(variants, record.id)
            for _, state in { "Light", "Heavy" } do
                local model = Instance.new("Model")
                model.Name = state
                model.WorldPivot = CFrame.identity
                model.Parent = settings
                local geometry = if state == "Light" then record.lightSource else record.heavySource
                place(objectParts(geometry), model, pivot)
                if state == "Light" then
                    local cloned: { MeshPart } = {}
                    for _, original in intact do
                        table.insert(cloned, original:Clone())
                    end
                    place(cloned, model, pivot)
                else
                    place(objectParts(record.heavyProxy), model, pivot)
                end
            end
        end
        for family, names in config.fragments do
            local parent = if family == "Wall" then wallFragments else roofFragments
            for index, sourceName in names do
                local shapes = objectParts(sourceName)
                table.sort(shapes, function(a, b)
                    return a.Size.X * a.Size.Y * a.Size.Z > b.Size.X * b.Size.Y * b.Size.Z
                end)
                local fragment = shapes[1]
                fitVisual(fragment)
                fragment.Size *= math.min(
                    1,
                    1.48 / math.max(fragment.Size.X, fragment.Size.Y, fragment.Size.Z)
                )
                fragment.Name = tostring(index)
                fragment.CFrame = CFrame.identity
                fragment.Parent = parent
                for shapeIndex = 2, #shapes do
                    shapes[shapeIndex]:Destroy()
                end
            end
        end
        for sourceName, parts in byObject do
            local parent: Instance = if parts[1].CanCollide then structure else furnishing
            if sourceName == "Foundation • 64 x 48" then
                assert(#parts == 1, "foundation no longer maps to one native part")
                parts[1].Name = "Warehouse_GroundFloor"
                parts[1].Size = Vector3.new(64, parts[1].Size.Y, 48)
            end
            place(parts, parent, CFrame.identity)
        end
        local roots: { Instance } = { assembly, variants }
        local package = Serializer:SerializeInstancesAsync(roots)
        return { data = package, meshCount = pieces, versions = latest, colors = textures }
    end, debug.traceback)
    for _, item in captured do
        item:Destroy()
    end
    assert(worked, result)
    return result
end
