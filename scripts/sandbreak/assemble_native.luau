--!strict
--[=[
    Host-only compiler for Sandbreak native batch captures. It retains genuine
    Studio mesh data, assigns stable panel identities and relocates the damage
    templates to panel-local coordinates. No asset access or network calls.
]=]
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local Instance = roblox.Instance
local CFrame = roblox.CFrame
local Vector3 = roblox.Vector3

local directory = assert(process.args[1], "Expected native capture directory")
local index = serde.decode("json", fs.readFile(directory .. "/import-index.json"))
local native = serde.decode("json", fs.readFile(directory .. "/native-index.json"))
local capture = serde.decode("json", fs.readFile(directory .. "/native-capture.json"))
local binding = capture.binding

local function folder(name, parent)
    local result = Instance.new("Folder")
    result.Name, result.Parent = name, parent
    return result
end

local function model(name, pose, parent)
    local result = Instance.new("Model")
    result.Name, result.WorldPivotData, result.Parent = name, pose, parent
    return result
end

local function vector(value)
    return Vector3.new(value[1], value[2], value[3])
end

local function nativeProxy(part, panel, state)
    part.Name = part.Name .. "_Proxy"
    part:SetAttribute("PanelProxy", true)
    part:SetAttribute("PanelId", panel.id)
    if state ~= "Pristine" then
        part.CFrame = panel.pivot:ToObjectSpace(part.CFrame)
    end
    part.Parent = panel[state]
end

-- The Blender floor surface lies at Y=0, the same plane as GroundDisk.
-- Lift only the visual floor finish and its markings to avoid z-fighting.
local function liftFloorFinish(part)
    local object = part:GetAttribute("SandbreakSourceObject")
    if
        type(object) == "string"
        and (
            string.match(object, "^Expansion%-jointed floor")
            or string.match(object, "^Floor ")
            or string.match(object, "^Screed")
            or string.find(object, "trench grate and threshold paint", 1, true)
        )
    then
        part.CFrame = part.CFrame + Vector3.new(0, 0.0625, 0)
    end
end

local function addStable(parent)
    -- Solid boundaries follow the inner jamb faces. The center of each 16-stud
    -- portal and the open ceiling trusses remain unobstructed.
    for _, side in
        {
            { "South", 0, 25, 0 },
            { "North", 0, -25, 180 },
            { "East", 31.25, 0, 90 },
            { "West", -31.25, 0, -90 },
        }
    do
        local frame = CFrame.new(side[2], 0, side[3]) * CFrame.Angles(0, math.rad(side[4]), 0)
        for _, sign in { -1, 1 } do
            local proxy = Instance.new("Part")
            proxy.Name = side[1] .. "Jamb" .. if sign > 0 then "A" else "B"
            proxy.Size = Vector3.new(0.84, 8.80, 3.25)
            proxy.CFrame = frame * CFrame.new(8.48 * sign, 4.40, -0.72)
            proxy.Transparency = 1
            proxy.Anchored = true
            proxy.CanTouch = false
            proxy.CastShadow = false
            proxy.Parent = parent
        end
    end
end

local assembly = model("SandbreakBunker", CFrame.identity, nil)
local panels = folder("SpawnShelterPanels", assembly)
local static = folder("SandbreakStatic", assembly)
local variants = folder("SandbreakPanelVariants", nil)
assembly:SetAttribute("BlendSha256", native.sourceSha256)
assembly:SetAttribute("ImportBinding", binding)
variants:SetAttribute("ImportBinding", binding)
addStable(static)

local states = {}
for id, appearances in index.panels do
    local source = index.objects[appearances.Solid]
    local pivot = CFrame.new(vector(source.pivot))
    local pristine = model(id, pivot, panels)
    pristine:SetAttribute("SandbreakPanel", true)
    pristine:SetAttribute("PanelId", id)
    pristine:SetAttribute("PanelSurface", source.Surface)
    pristine:SetAttribute("IntactSize", vector(source.bounds[2]) - vector(source.bounds[1]))
    local entry = folder(id, variants)
    states[id] = {
        id = id,
        pivot = pivot,
        Pristine = pristine,
        Light = model("Light", CFrame.identity, entry),
        Heavy = model("Heavy", CFrame.identity, entry),
    }
end

local capturedCount = 0
for _, batch in native.batches do
    local filename = batch.file
    if filename == "sandbreak-native-pilot.glb" then
        continue
    end
    local entry = assert(capture.batches[filename], "Missing native capture: " .. filename)
    assert(
        entry.sha256 == batch.sha256 and entry.count == batch.expectedMeshParts,
        "Mismatched batch: " .. filename
    )
    local key = string.match(filename, "^sandbreak%-native%-(.+)%.glb$")
    assert(key, "Bad filename " .. filename)
    local roots = roblox.deserializeModel(fs.readFile(directory .. "/capture-" .. key .. ".rbxm"))
    assert(#roots == 1 and roots[1]:IsA("Folder"), "Invalid native batch root: " .. filename)
    local root = roots[1]
    assert(#root:GetChildren() == entry.count, "Missing captured batch parts")
    for _, part in root:GetChildren() do
        assert(part:IsA("MeshPart"), "Unexpected captured geometry")
        local panelId = part:GetAttribute("SourcePanelId")
        local panel = if panelId then assert(states[panelId], "Unknown panel " .. panelId) else nil
        local appearance = part:GetAttribute("SourceAppearance")
        if appearance == "Solid" then
            local light = part:Clone()
            nativeProxy(part, panel, "Pristine")
            nativeProxy(light, panel, "Light")
        elseif appearance == "Residual" then
            nativeProxy(part, panel, "Heavy")
        elseif panel then
            if part:GetAttribute("SourceThermalNonCover") then
                part:SetAttribute("ThermalNonCover", true)
            end
            if appearance == "Heavy" or appearance == "Light" then
                part.CFrame = panel.pivot:ToObjectSpace(part.CFrame)
                part.Parent = panel[appearance]
            else
                part.Parent = panel.Pristine
                if not appearance then
                    local light = part:Clone()
                    light.CFrame = panel.pivot:ToObjectSpace(part.CFrame)
                    light.Parent = panel.Light
                end
            end
        else
            if not string.match(key, "^structure%-") then
                part:SetAttribute("ThermalNonCover", true)
            end
            liftFloorFinish(part)
            part.Parent = static
        end
        capturedCount += 1
    end
    root:Destroy()
end

local function checkState(panel)
    local solids, visuals = 0, 0
    for _, part in panel:GetChildren() do
        if part:GetAttribute("PanelProxy") then
            solids += 1
        else
            visuals += 1
        end
    end
    assert(solids == 1 and visuals >= 1, "Missing native geometry for " .. panel.Name)
end

for _, panel in states do
    checkState(panel.Pristine)
    checkState(panel.Light)
    checkState(panel.Heavy)
end
assert(#panels:GetChildren() == 103, "Expected 103 Sandbreak panels")
fs.writeFile(directory .. "/SandbreakBunker.rbxm", roblox.serializeModel({ assembly }))
fs.writeFile(directory .. "/SandbreakPanelVariants.rbxm", roblox.serializeModel({ variants }))
print(string.format("Compiled Sandbreak • %d meshes and %d panels", capturedCount, #panels:GetChildren()))
