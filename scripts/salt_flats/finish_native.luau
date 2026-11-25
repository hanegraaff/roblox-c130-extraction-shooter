--!strict
--[=[
    Detached Studio assembly compiler. Joins validated native batches into
    source-managed model roots, adds explicit query/physics surfaces, and
    serializes native engine data. Never parents content to the document.
]=]
local Serializer = game:GetService("SerializationService")
local Encoding = game:GetService("EncodingService")

local function vector(values: { number }): Vector3
    return Vector3.new(values[1], values[2], values[3])
end

local function folder(name: string, parent: Instance?): Folder
    local instance = Instance.new("Folder")
    instance.Name = name
    instance.Parent = parent
    return instance
end

local function model(name: string, pivot: CFrame, parent: Instance?): Model
    local instance = Instance.new("Model")
    instance.Name = name
    instance.WorldPivot = pivot
    instance.Parent = parent
    return instance
end

local function proxy(parent: Instance, name: string, pose: CFrame, size: Vector3, panelId: string?): Part
    local instance = Instance.new("Part")
    instance.Name = name
    instance.Size = size
    instance.CFrame = pose
    instance.Anchored = true
    instance.CanCollide = true
    instance.CanQuery = true
    instance.CanTouch = false
    instance.Transparency = 1
    instance.CastShadow = false
    if panelId then
        instance:SetAttribute("PanelProxy", true)
        instance:SetAttribute("PanelId", panelId)
    end
    instance.Parent = parent
    return instance
end

-- Returns Base64 only to the caller-owned out-of-place transport. All source
-- parts remain genuine Studio-imported native MeshParts, including planar art.
return function(config, batches, output)
    local assembly = model("SaltFlatsHangar", CFrame.identity, nil)
    local structure = folder("Foundry_Static", assembly)
    local art = folder("Foundry_Art", assembly)
    local panels = folder("Foundry_Panels", assembly)
    local wreck = model("HerculesWreck", CFrame.identity, assembly)
    local variants = folder("SaltFlatsPanelVariants", nil)
    local panelStates = {}
    assembly:SetAttribute("PanelLayoutVersion", 4)
    assembly:SetAttribute("BlendSha256", config.blend)
    assembly:SetAttribute("ImportBinding", config.binding)
    variants:SetAttribute("ImportBinding", config.binding)
    wreck:SetAttribute("DestructibleWreck", true)
    local count = 0
    local worked, result = pcall(function()
        for key, row in config.panels do
            local pivot = CFrame.new(vector(row.pivot))
            local id = string.format("Foundry_S%02d_%s", row.story, string.gsub(key, "[ .]", "_"))
            local pristine = model(id, pivot, panels)
            pristine:SetAttribute("SaltFlatsPanel", true)
            pristine:SetAttribute("PanelId", id)
            pristine:SetAttribute("StoryId", string.format("%02d", row.story))
            pristine:SetAttribute(
                "IntactSize",
                if string.match(key, "^Roof")
                    then Vector3.new(53.85, 0.28, 24)
                    elseif string.match(key, "^Gable") then Vector3.new(13, 14, 0.28)
                    else Vector3.new(26, 12, 0.28)
            )
            local library = folder(id, variants)
            local light = model("Light", CFrame.identity, library)
            local heavy = model("Heavy", CFrame.identity, library)
            panelStates[key] = { Pristine = pristine, Light = light, Heavy = heavy, pivot = pivot }
            for state, solids in { Pristine = row.pristine, Light = row.pristine, Heavy = row.heavy } do
                for _, spec in solids do
                    local pose = CFrame.fromMatrix(vector(spec.center), vector(spec.u), vector(spec.v))
                    proxy(
                        panelStates[key][state],
                        id .. "_" .. spec.key,
                        if state == "Pristine" then pose else pivot:ToObjectSpace(pose),
                        vector(spec.size),
                        id
                    )
                end
            end
        end
        for _, data in config.models do
            local batch = assert(batches[data.file], "Uncaptured batch " .. data.file)
            for _, original in batch:GetChildren() do
                assert(original:IsA("MeshPart"), "invalid captured mesh")
                local item = original:Clone()
                local surface = item:FindFirstChildWhichIsA("SurfaceAppearance")
                if surface then
                    surface.Name = item.Name .. "_Surface"
                end
                local role = item:GetAttribute("SaltFlatsRole")
                if role == "panel" then
                    local states =
                        assert(panelStates[item:GetAttribute("SourcePanelId")], "Missing panel identity")
                    local state = item:GetAttribute("SourceAppearance")
                    if state ~= "Pristine" then
                        item.CFrame = states.pivot:ToObjectSpace(item.CFrame)
                    end
                    item.Parent = states[state]
                elseif role == "wreck" then
                    item.Parent = wreck
                else
                    item.Parent = art
                end
                count += 1
            end
        end
        local wreckPose = CFrame.new(vector(config.wreckOrigin))
            * CFrame.Angles(0, math.rad(config.wreckYaw), 0)
        for _, spec in config.walk.hangar do
            local name = if spec.key == "GroundFloor" then "Foundry_GroundFloor" else "Foundry_" .. spec.key
            proxy(structure, name, CFrame.new(vector(spec.center)), vector(spec.size), nil)
        end
        for _, spec in config.walk.wreck do
            proxy(
                wreck,
                spec.key,
                wreckPose * CFrame.new(vector(spec.center)) * CFrame.Angles(math.rad(spec.pitchDegrees), 0, 0),
                vector(spec.size),
                nil
            )
        end
        for _, spec in config.wreckSkin do
            local pose = CFrame.fromMatrix(vector(spec.center), vector(spec.u), vector(spec.v))
            proxy(wreck, spec.key, wreckPose * pose, vector(spec.size), nil)
        end
        local function serialize(root: Instance): number
            local bytes = Serializer:SerializeInstancesAsync({ root })
            local b64 = buffer.tostring(Encoding:Base64Encode(bytes))
            output[root.Name] = b64
            return #b64
        end
        return {
            meshCount = count,
            panels = #panels:GetChildren(),
            sizes = { SaltFlatsHangar = serialize(assembly), SaltFlatsPanelVariants = serialize(variants) },
        }
    end)
    assembly:Destroy()
    variants:Destroy()
    if not worked then
        error(result)
    end
    return result
end
