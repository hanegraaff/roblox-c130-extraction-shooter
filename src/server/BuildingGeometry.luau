--!strict
--[=[
    BuildingGeometry: server-only loaded geometry validation and public panel registry.
    Depends on BuildingLayout, actual Workspace overlap/raycast queries and authored
    building Parts. Does not yield, own events or create Instances. Static floors,
    supports and stairs never become destructible panels. All lengths are studs.
]=]
local BuildingLayout = require(game:GetService("ReplicatedStorage").Shared.BuildingLayout)
local BuildingGeometry = {}
-- Imported panels retain one stable Model identity and expose only actual
-- rectangle proxies as solids. Primitive registries retain their BasePart API.
local function panelPose(panel: Instance): (CFrame?, Vector3?)
    if panel:IsA("BasePart") then
        if not panel.CanCollide or not panel.CanQuery then
            return nil, nil
        end
        return panel.CFrame, panel.Size
    end
    if panel:IsA("Model") and type(panel:GetAttribute("PanelAssetFamily")) == "string" then
        local size = panel:GetAttribute("IntactSize")
        if typeof(size) ~= "Vector3" then
            return nil, nil
        end
        local solids = 0
        for _, child in panel:GetDescendants() do
            if child:IsA("BasePart") and child.CanCollide and child.CanQuery then
                if child.Parent ~= panel or child:GetAttribute("PanelProxy") ~= true then
                    return nil, nil
                end
                solids += 1
            end
        end
        if solids > 0 then
            return panel:GetPivot(), size
        end
    end
    return nil, nil
end
-- A level-supplied registry root. Formal buildings infer story from stable IDs;
-- ancillary one-floor envelopes use an explicit default story. Damage rules do
-- not depend on the name/count/footprint of any registry.
export type Registry = { buildingId: string, panels: Folder, storyId: string? }

-- Reads the current level's formal building folders and additional StringValue
-- descriptors (name=building ID,value=direct map folder name). Rejects malformed
-- roots/duplicate identities without writes or yielding. No recursive path lookup.
function BuildingGeometry.registries(map: Model): ({ Registry }?, string?)
    local buildings = map:FindFirstChild("Buildings")
    if not buildings then
        return nil, "missing buildings"
    end
    local result: { Registry } = {}
    local ids: { [string]: boolean } = {}
    for _, building in buildings:GetChildren() do
        local panels = building:FindFirstChild(building.Name .. "_Panels")
        if not panels or not panels:IsA("Folder") then
            return nil, "missing formal panel root"
        end
        ids[building.Name] = true
        table.insert(result, { buildingId = building.Name, panels = panels })
    end
    local descriptors = map:FindFirstChild("PanelRegistries")
    if not descriptors then
        return nil, "missing additional panel descriptors"
    end
    for _, descriptor in descriptors:GetChildren() do
        if not descriptor:IsA("StringValue") or descriptor.Value == "" or ids[descriptor.Name] then
            return nil, "invalid additional panel descriptor"
        end
        local root = map:FindFirstChild(descriptor.Value)
        if not root or not root:IsA("Folder") or #root:GetChildren() == 0 then
            return nil, "missing additional panel root"
        end
        ids[descriptor.Name] = true
        table.insert(result, { buildingId = descriptor.Name, panels = root, storyId = "01" })
    end
    return result, nil
end

-- Checks actual floor separation, contiguous stair poses, headroom, avatar-wide entry
-- corridors and unique panel/story/pivot contracts. Rejects without mutation.
function BuildingGeometry.validate(
    map: Model,
    overlap: OverlapParams,
    rays: RaycastParams
): (boolean, string?)
    local buildings = map:FindFirstChild("Buildings")
    if not buildings then
        return false, "missing buildings"
    end
    local layouts: { BuildingLayout.Building } = {}
    for _, building in buildings:GetChildren() do
        local supports = building:FindFirstChild(building.Name .. "_Static")
        local panels = building:FindFirstChild(building.Name .. "_Panels")
        local floor = if supports then supports:FindFirstChild(building.Name .. "_GroundFloor") else nil
        if not floor or not floor:IsA("BasePart") or not supports or not panels then
            return false, "missing building floor/support/panel registry"
        end
        local registry: { BuildingLayout.Panel } = {}
        for _, panel in panels:GetChildren() do
            local pivot = panelPose(panel)
            if not pivot then
                return false, "panel must provide authoritative collision and queries"
            end
            table.insert(registry, {
                id = panel.Name,
                story = tonumber(panel:GetAttribute("StoryId")) or tonumber(
                    string.match(panel.Name, "_S(%d%d)_")
                ) or 0,
                roof = string.find(panel.Name, "_Roof_", 1, true) ~= nil,
                interior = panel:GetAttribute("InteriorPanel") == true
                    or string.find(panel.Name, "_Interior_", 1, true) ~= nil,
                pivot = { pivot:GetComponents() },
            })
        end
        local upper = supports:FindFirstChild(building.Name .. "_UpperMain")
        local landing = supports:FindFirstChild(building.Name .. "_UpperNorthLanding")
        local nav = building:FindFirstChild(building.Name .. "_Navigation")
        if
            not upper
            or not upper:IsA("BasePart")
            or not upper.CanCollide
            or not landing
            or not landing:IsA("BasePart")
            or not landing.CanCollide
            or not nav
            or #nav:GetChildren() ~= 5
        then
            return false, "missing usable upper floor, landing or navigation"
        end
        -- Validate every named marker before casts or route interpolation. Malformed
        -- authoring is an expected rejection, never a missing-Instance exception.
        for index = 1, 5 do
            local marker = nav:FindFirstChild(string.format("%s_Walk%02d", building.Name, index))
            if not marker or not marker:IsA("BasePart") then
                return false, "missing numbered building navigation marker"
            end
        end
        local floorTop = floor.Position.Y + floor.Size.Y / 2
        local upperTop = upper.Position.Y + upper.Size.Y / 2
        if
            math.abs(upperTop - floorTop - 10) > 0.01
            or upper.Size.X < 19
            or upper.Size.Z < 32
            or math.abs(landing.Position.Y + landing.Size.Y / 2 - upperTop) > 0.01
        then
            return false, "invalid floor separation or usable area"
        end
        if floor.Size.X == 64 then
            local rooms = building:FindFirstChild(building.Name .. "_Rooms")
            if not rooms or #rooms:GetChildren() ~= 2 then
                return false, "missing representative room bounds"
            end
            for story = 1, 2 do
                local room = rooms:FindFirstChild(string.format("%s_S%02d_RoomEast", building.Name, story))
                if
                    not room
                    or not room:IsA("BasePart")
                    or room.Size ~= Vector3.new(32, 8, 48)
                    or room.Position ~= Vector3.new(
                        floor.Position.X + 16,
                        floorTop + 4 + (story - 1) * 10,
                        floor.Position.Z
                    )
                    or room.CanCollide
                    or room.CanQuery
                then
                    return false, "representative room must be two panels wide and one tall"
                end
                for index = 1, 2 do
                    local divider = panels:FindFirstChild(
                        string.format("%s_S%02d_Interior_%02d", building.Name, story, index)
                    )
                    if
                        not divider
                        or not divider:IsA("BasePart")
                        or divider.Size ~= Vector3.new(1, 8, 16)
                        or divider.Position
                            ~= Vector3.new(
                                floor.Position.X,
                                floorTop + 4 + (story - 1) * 10,
                                floor.Position.Z + (if index == 1 then -8 else 8)
                            )
                    then
                        return false, "room divider panels do not match room boundaries"
                    end
                end
            end
        end
        local steps = 0
        for _, support in supports:GetChildren() do
            if string.match(support.Name, "_Step%d%d$") then
                steps += 1
            end
        end
        local stepRise, stepRun = 0, 0
        local previous: BasePart? = nil
        for index = 1, steps do
            local step = supports:FindFirstChild(string.format("%s_Step%02d", building.Name, index))
            if not step or not step:IsA("BasePart") or not step.CanCollide then
                return false, "missing connected stair tread"
            end
            local top = step.Position.Y + step.Size.Y / 2
            local rise = top - (if previous then previous.Position.Y + previous.Size.Y / 2 else floorTop)
            if math.abs(rise - 0.625) > 0.01 or step.Size.X < 8 or math.abs(step.Size.Z - 2) > 0.01 then
                return false, "invalid stair rise or tread clearance"
            end
            if previous then
                stepRun = previous.Position.Z - step.Position.Z
                if math.abs(stepRun - 2) > 0.01 or math.abs(step.Position.X - previous.Position.X) > 0.01 then
                    return false, "detached stair run"
                end
            end
            -- The body envelope clears the highest adjacent tread. Stair ascent itself
            -- is verified with a real Humanoid; this query detects overhead obstructions.
            local body = Vector3.new(step.Position.X, top + 4.35, step.Position.Z)
            if #workspace:GetPartBoundsInBox(CFrame.new(body), Vector3.new(4, 6, 4), overlap) > 0 then
                return false, "blocked stair headroom"
            end
            stepRise = rise
            previous = step
        end
        if not previous or math.abs(previous.Position.Y + previous.Size.Y / 2 - upperTop) > 0.01 then
            return false, "stairs do not reach upper floor"
        end
        for _, suffix in { "Walk01", "Walk02", "Walk05" } do
            local marker = nav:FindFirstChild(building.Name .. "_" .. suffix)
            if not marker or not marker:IsA("BasePart") then
                return false, "missing navigation marker"
            end
            if #workspace:GetPartBoundsInBox(marker.CFrame, Vector3.new(4, 6, 4), overlap) > 0 then
                return false, "blocked building entrance or upper floor"
            end
            local support = workspace:Raycast(marker.Position, Vector3.new(0, -5, 0), rays)
            if not support then
                return false, "unsupported building route"
            end
        end
        for segment = 1, 2 do
            local first = nav:FindFirstChild(string.format("%s_Walk%02d", building.Name, segment)) :: BasePart
            local last =
                nav:FindFirstChild(string.format("%s_Walk%02d", building.Name, segment + 1)) :: BasePart
            local samples = math.ceil((last.Position - first.Position).Magnitude)
            for sample = 0, samples do
                local position = first.Position:Lerp(last.Position, sample / samples)
                if #workspace:GetPartBoundsInBox(CFrame.new(position), Vector3.new(4, 6, 4), overlap) > 0 then
                    return false, "blocked building entry route"
                end
                if not workspace:Raycast(position, Vector3.new(0, -5, 0), rays) then
                    return false, "unsupported building entry route"
                end
            end
        end
        table.insert(layouts, {
            id = building.Name,
            width = floor.Size.X,
            depth = floor.Size.Z,
            stories = if upperTop > floorTop then 2 else 1,
            stairSteps = steps,
            stepRise = stepRise,
            stepRun = stepRun,
            panels = registry,
            panelLayoutVersion = if building:GetAttribute("PanelLayoutVersion") == 2 then 2 else nil,
        })
    end
    local valid, reason = BuildingLayout.validate(layouts)
    if not valid then
        return false, reason
    end
    local registries, registryReason = BuildingGeometry.registries(map)
    if not registries then
        return false, registryReason
    end
    for _, registry in registries do
        for _, part in registry.panels:GetChildren() do
            if not panelPose(part) then
                return false, "registered panel must be a real solid"
            end
        end
    end
    return true, nil
end

-- Applies stable replicated identity and Intact variant contracts after validation.
-- Rebuild reuses source IDs and pivots; P07 implements residual variants and fragments.
function BuildingGeometry.decorate(map: Model)
    local registries, reason = BuildingGeometry.registries(map)
    assert(registries, reason)
    for _, registry in registries do
        for _, panel in registry.panels:GetChildren() do
            local pivot, size = panelPose(panel)
            if pivot and size then
                panel:SetAttribute("PanelId", panel.Name)
                panel:SetAttribute("BuildingId", registry.buildingId)
                panel:SetAttribute(
                    "StoryId",
                    registry.storyId or panel:GetAttribute("StoryId") or string.match(panel.Name, "_S(%d%d)_")
                )
                panel:SetAttribute("CoverKind", "BuildingPanel")
                panel:SetAttribute("PanelState", "Intact")
                panel:SetAttribute("DamageAppearance", "Pristine")
                panel:SetAttribute("IntactPivot", pivot)
                panel:SetAttribute("IntactSize", size)
                panel:SetAttribute("VariantContract", "Intact/Damaged/Destroyed:v1")
            end
        end
    end
    local buildings = map:FindFirstChild("Buildings")
    assert(buildings, "validated buildings missing")
    for _, building in buildings:GetChildren() do
        building:SetAttribute("BuildingId", building.Name)
        building:SetAttribute("Stories", 2)
        local supports = building:FindFirstChild(building.Name .. "_Static")
        if supports then
            for _, support in supports:GetChildren() do
                support:SetAttribute("BuildingId", building.Name)
                support:SetAttribute("CoverKind", "StaticSupport")
            end
        end
    end
end
return BuildingGeometry
