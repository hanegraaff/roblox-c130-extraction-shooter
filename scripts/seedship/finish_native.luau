--!strict
-- Studio Edit compiler. Groups captured native art and query shapes, adds
-- discrete stair treads, and serializes the managed assembly and damage bank.
local serializer = game:GetService("SerializationService")
local encoding = game:GetService("EncodingService")

local function folder(name: string, parent: Instance?): Folder
    local instance = Instance.new("Folder")
    instance.Name, instance.Parent = name, parent
    return instance
end

local function model(name: string, pose: CFrame, parent: Instance?): Model
    local instance = Instance.new("Model")
    instance.Name, instance.WorldPivot, instance.Parent = name, pose, parent
    return instance
end

local function solid(parent: Instance, name: string, position: Vector3, size: Vector3)
    local part = Instance.new("Part")
    part.Name = name
    part.Size, part.Position = size, position
    part.Transparency, part.CastShadow = 1, false
    part.Anchored, part.CanTouch = true, false
    part.Parent = parent
    return part
end

local function stairs(frame: Folder)
    for _, sign in { -1, 1 } do
        local side = if sign == -1 then "Port" else "Starboard"
        for step = 1, 24 do
            solid(
                frame,
                string.format("Prism%sTread%02d", side, step),
                Vector3.new(sign * 56, 16 * step / 24 - 0.425, 39.5 - step),
                Vector3.new(10, 0.85, 1)
            )
        end
        for index, x in { 50.83, 61.17 } do
            local a, b = Vector3.new(sign * x, 1.43, 39), Vector3.new(sign * x, 17.45, 15)
            local rail = solid(
                frame,
                string.format("Prism%sStairRail%d", side, index),
                (a + b) / 2,
                Vector3.new(0.4, 2.7, (a - b).Magnitude)
            )
            rail.CFrame = CFrame.lookAt((a + b) / 2, b)
        end
        for index, pair in
            {
                { 42, -15, 50.8, -15 },
                { 42, -15, 42, 25 },
                { 61.2, -15, 61.2, -39 },
                { 61.2, -39, 64, -39 },
                { 64, -39, 73, -25 },
                { 73, -25, 77, -9 },
                { 77, -9, 77, 13 },
                { 77, 13, 66, 32 },
                { 66, 32, 54, 40 },
                { 54, 40, 42, 40 },
            }
        do
            local a, b =
                Vector3.new(sign * pair[1], 17.45, -pair[2]), Vector3.new(sign * pair[3], 17.45, -pair[4])
            local rail = solid(
                frame,
                string.format("Prism%sGalleryRail%02d", side, index),
                (a + b) / 2,
                Vector3.new(0.36, 2.9, (b - a).Magnitude)
            )
            rail.CFrame = CFrame.lookAt((a + b) / 2, b)
        end
        for index, center in { { 46, -9 }, { 70, -19 }, { 47, 17 }, { 68, 17 }, { 50, 34 } } do
            solid(
                frame,
                string.format("Prism%sPier%02d", side, index),
                Vector3.new(sign * center[1], 4, -center[2]),
                Vector3.new(2.6, 8, 2.6)
            )
        end
    end
    for step = 1, 6 do
        local top = -2.4 + 0.4 * step
        solid(
            frame,
            string.format("PrismThreshold%02d", step),
            Vector3.new(0, (top - 2.44) / 2, 73 - 2 * step),
            Vector3.new(34 + 0.72 * (step - 1), 2.44 + top, 2)
        )
    end
    for _, z in { -25, -40 } do
        solid(
            frame,
            "PrismCrossoverRail" .. tostring(-z),
            Vector3.new(0, 17.45, z),
            Vector3.new(84, 2.9, 0.36)
        )
    end
end

local function makeSolid(mesh: MeshPart)
    assert(mesh.CollisionFidelity == Enum.CollisionFidelity.PreciseConvexDecomposition, mesh.Name)
    mesh.CanCollide, mesh.CanQuery, mesh.CanTouch = true, true, false
end

return function(config, captures, output)
    local assembly = model("PrismSeedship", CFrame.identity, nil)
    local frame = folder("PrismStable", assembly)
    local skins = folder("PrismArt", assembly)
    local panels = folder("PrismPanels", assembly)
    local variants = folder("PrismPanelVariants", nil)
    local fragments = folder("PrismFragments", variants)
    local states = {}
    local pristineProxies = {}
    local count = 0
    assembly:SetAttribute("BlendSha256", config.blend)
    assembly:SetAttribute("ImportBinding", config.binding)
    assembly:SetAttribute("Stories", 2)
    assembly:SetAttribute("ThermalBrightness", 0.63)
    variants:SetAttribute("ImportBinding", config.binding)
    local ok, result = pcall(function()
        for _, record in config.panels do
            local x, y, z = table.unpack(record.pivot)
            local pose = CFrame.new(x, z, -y)
            local panel = model(record.id, pose, panels)
            panel:SetAttribute("PanelId", record.id)
            panel:SetAttribute("SeedshipPanel", true)
            panel:SetAttribute("StoryId", record.story)
            panel:SetAttribute("PanelPlacement", record.placement)
            local bank = folder(record.id, variants)
            states[record.id] = {
                Pristine = panel,
                Light = model("Light", CFrame.identity, bank),
                Heavy = model("Heavy", CFrame.identity, bank),
                pivot = pose,
            }
        end
        for _, file in config.batches do
            local captured = assert(captures[file], "batch missing: " .. file)
            for _, original in captured:GetChildren() do
                assert(original:IsA("MeshPart"), original.Name)
                local role = original:GetAttribute("SeedshipRole")
                local item = original:Clone()
                if role == "HullSkin" or role == "QueryProxy" then
                    local identity = item:GetAttribute("SourcePanelId")
                    local state = item:GetAttribute("SourceAppearance")
                    local owner = assert(states[identity], item.Name)
                    if state ~= "Pristine" then
                        item.CFrame = owner.pivot:ToObjectSpace(item.CFrame)
                    end
                    if role == "QueryProxy" then
                        item:ClearAllChildren()
                        item.TextureID = ""
                        item.Transparency, item.CastShadow = 1, false
                        item:SetAttribute("PanelProxy", true)
                        item:SetAttribute("PanelId", identity)
                        makeSolid(item)
                        if state == "Pristine" then
                            assert(not pristineProxies[identity], item.Name)
                            pristineProxies[identity] = item
                            owner.Pristine:SetAttribute("IntactSize", item.Size)
                            local lightProxy = item:Clone()
                            lightProxy.CFrame = owner.pivot:ToObjectSpace(lightProxy.CFrame)
                            lightProxy.Parent = owner.Light
                        end
                    end
                    item.Parent = owner[state]
                elseif role == "Fragment" then
                    item.Parent = fragments
                elseif
                    item.CollisionFidelity == Enum.CollisionFidelity.PreciseConvexDecomposition
                    and (role == "WalkableFloor" or role == "WalkableGallery" or role == "WalkableEntry")
                then
                    makeSolid(item)
                    item.Parent = frame
                else
                    item.Parent = skins
                end
                count += 1
            end
            task.wait()
        end
        for key, state in states do
            assert(
                pristineProxies[key] and #state.Heavy:GetChildren() >= 2 and #state.Light:GetChildren() >= 2,
                key
            )
        end
        stairs(frame)
        local function write(root: Instance): number
            local bytes = serializer:SerializeInstancesAsync({ root })
            local encoded = buffer.tostring(encoding:Base64Encode(bytes))
            output[root.Name] = encoded
            return #encoded
        end
        return {
            meshes = count,
            panels = #panels:GetChildren(),
            sizes = { PrismSeedship = write(assembly), PrismPanelVariants = write(variants) },
        }
    end)
    assembly:Destroy()
    variants:Destroy()
    assert(ok, result)
    return result
end
