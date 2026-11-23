--!strict
--[=[
    Read-only Studio Edit inspection for the material-split Sandbreak pilot.
    The caller supplies the detached import root and records from native-index.json.
    Returns real mesh dimensions and material channels for scale and axis calibration.
    Does not yield or modify the imported instances.
]=]

type MeshExpectation = {
    importName: string,
    expectsColorMap: boolean,
}

type NativeMesh = {
    path: string,
    meshId: string,
    meshSize: { number },
    size: { number },
    cframe: { number },
    pivot: { number },
    colorMap: string,
    normalMap: string,
    roughnessMap: string,
    metalnessMap: string,
    textureId: string,
    color: { number },
    collisionFidelity: string,
    renderFidelity: string,
    anchored: boolean,
}

local function vector(value: Vector3): { number }
    return { value.X, value.Y, value.Z }
end

local function findName(part: MeshPart, root: Instance, expected: { [string]: boolean }): string?
    local current: Instance? = part
    while current and current ~= root do
        local name = string.match(current.Name, "^(SB_panel_pristine_%d%d%d_%d%d)")
        if name and expected[name] ~= nil then
            return name
        end
        current = current.Parent
    end
    return nil
end

return function(root: Instance, expectations: { MeshExpectation }): ({ [string]: NativeMesh }, { string })
    local expected: { [string]: boolean } = {}
    for _, entry in expectations do
        assert(expected[entry.importName] == nil, "Duplicate pilot input " .. entry.importName)
        expected[entry.importName] = entry.expectsColorMap
    end
    local found: { [string]: NativeMesh } = {}
    local missingColor: { string } = {}
    for _, item in root:GetDescendants() do
        assert(not item:IsA("LuaSourceContainer"), "Unexpected executable in native pilot")
        assert(not item:IsA("BasePart") or item:IsA("MeshPart"), "Unexpected native part class")
        if not item:IsA("MeshPart") then
            continue
        end
        local name = findName(item, root, expected)
        assert(name and not found[name], "Unknown or duplicated pilot part " .. item:GetFullName())
        local surface = item:FindFirstChildWhichIsA("SurfaceAppearance")
        local colorMap = if surface then surface.ColorMap else ""
        if expected[name] and colorMap == "" and item.TextureID == "" then
            table.insert(missingColor, name)
        end
        found[name] = {
            path = item:GetFullName(),
            meshId = item.MeshId,
            meshSize = vector(item.MeshSize),
            size = vector(item.Size),
            cframe = { item.CFrame:GetComponents() },
            pivot = { item:GetPivot():GetComponents() },
            colorMap = colorMap,
            normalMap = if surface then surface.NormalMap else "",
            roughnessMap = if surface then surface.RoughnessMap else "",
            metalnessMap = if surface then surface.MetalnessMap else "",
            textureId = item.TextureID,
            color = { item.Color.R, item.Color.G, item.Color.B },
            collisionFidelity = item.CollisionFidelity.Name,
            renderFidelity = item.RenderFidelity.Name,
            anchored = item.Anchored,
        }
    end
    for name in expected do
        assert(found[name], "Missing native pilot part " .. name)
    end
    table.sort(missingColor)
    return found, missingColor
end
