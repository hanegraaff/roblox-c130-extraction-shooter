--!strict
-- P13 real network-client geometry/terrain/aircraft probes. Test-only; bounded discovery
-- and one listener are torn down with the transport. No source/world mutation occurs.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Harness = {}
local HttpService = game:GetService("HttpService")
type Observation = {
    name: string,
    className: string,
    shape: string,
    pose: { number },
    size: { number },
    anchored: boolean,
    collide: boolean,
    query: boolean,
    touch: boolean,
}

-- Numeric component comparison accepts signed zero and float serialization differences
-- within 0.001 studs/components, without rounding-boundary false mismatches. Identity,
-- population, class, shape and collision/query/touch ownership must match exactly.
local function geometryMatches(expected: { Observation }): (boolean, string?)
    local map = workspace.World:FindFirstChild("Battlefield")
    if not map then
        return false, "Battlefield missing"
    end
    local parts: { [string]: BasePart } = {}
    local count = 0
    for _, item in map:GetDescendants() do
        if item:IsA("BasePart") then
            if parts[item.Name] then
                return false, "duplicate part " .. item.Name
            end
            parts[item.Name] = item
            count += 1
        end
    end
    if count ~= #expected then
        return false, "part count differs"
    end
    for _, entry in expected do
        local actual = parts[entry.name]
        if not actual then
            return false, "part missing: " .. entry.name
        end
        local shape = if actual:IsA("Part") then actual.Shape.Name else actual.ClassName
        if
            actual.ClassName ~= entry.className
            or shape ~= entry.shape
            or actual.Anchored ~= entry.anchored
            or actual.CanCollide ~= entry.collide
            or actual.CanQuery ~= entry.query
            or actual.CanTouch ~= entry.touch
        then
            return false, "class/shape/flags differ: " .. entry.name
        end
        local pose = { actual.CFrame:GetComponents() }
        for index, value in entry.pose do
            local component = pose[index]
            if
                component ~= component
                or math.abs(component) == math.huge
                or math.abs(component - value) > 0.001
            then
                return false, "CFrame component differs: " .. entry.name .. ":" .. tostring(index)
            end
        end
        for index, component in { actual.Size.X, actual.Size.Y, actual.Size.Z } do
            if
                component ~= component
                or math.abs(component) == math.huge
                or math.abs(component - entry.size[index]) > 0.001
            then
                return false, "size differs: " .. entry.name .. ":" .. tostring(index)
            end
        end
    end
    return true, nil
end

-- Installs asynchronously in every actual client, including a late join.
function Harness.run()
    task.spawn(function()
        local remote = ReplicatedStorage:WaitForChild("P13Harness", 120)
        if not remote or not remote:IsA("RemoteEvent") then
            return
        end
        local listener: RBXScriptConnection? = nil
        local removal: RBXScriptConnection? = nil
        listener = remote.OnClientEvent:Connect(function(token: number, expected: string)
            local ok, reason = pcall(function()
                local observations = HttpService:JSONDecode(expected) :: { Observation }
                local deadline = os.clock() + 12
                while not geometryMatches(observations) and os.clock() < deadline do
                    task.wait(0.05)
                end
                local matched, mismatch = geometryMatches(observations)
                assert(
                    matched,
                    "actual client geometry differs after replication deadline: " .. tostring(mismatch)
                )
                -- Regression probes mutate only the expected observation. The actual
                -- map remains untouched: signed zero and sub-tolerance differences
                -- pass, while larger drift, missing identity and changed flags reject.
                local entry = observations[1]
                local originalX = entry.pose[1]
                entry.pose[1] = originalX + 0.0009
                assert(geometryMatches(observations), "sub-tolerance geometry rejected")
                entry.pose[1] = originalX + 0.0011
                assert(not geometryMatches(observations), "beyond-tolerance geometry accepted")
                entry.pose[1] = originalX
                local originalName = entry.name
                entry.name = "P13MissingObservationPart"
                assert(not geometryMatches(observations), "missing part identity accepted")
                entry.name = originalName
                entry.collide = not entry.collide
                assert(not geometryMatches(observations), "changed collision flag accepted")
                entry.collide = not entry.collide
                for index, value in entry.pose do
                    if value == 0 then
                        entry.pose[index] = -0.0
                        assert(geometryMatches(observations), "signed-zero geometry rejected")
                        entry.pose[index] = value
                        break
                    end
                end
                local map = workspace.World.Battlefield
                local buildings = map:FindFirstChild("Buildings")
                assert(buildings and #buildings:GetChildren() == 3, "client building population differs")
                for _, building in buildings:GetChildren() do
                    local panels = building:FindFirstChild(building.Name .. "_Panels") :: Folder
                    for _, panel in panels:GetChildren() do
                        assert(panel:GetAttribute("PanelId") == panel.Name, "client panel identity differs")
                        assert(panel:GetAttribute("PanelState") == "Intact", "client panel state differs")
                    end
                end
                local rays = RaycastParams.new()
                rays.FilterType = Enum.RaycastFilterType.Include
                rays.FilterDescendantsInstances = { workspace.Terrain }
                local recipe = map:FindFirstChild("TerrainRecipe") :: Folder
                for _, hill in recipe:GetChildren() do
                    if hill:IsA("Part") and hill.Name ~= "TerrainBounds" then
                        local hit = workspace:Raycast(
                            Vector3.new(hill.Position.X, 80, hill.Position.Z),
                            Vector3.new(0, -150, 0),
                            rays
                        )
                        assert(
                            hit and hit.Material == hill.Material and math.abs(hit.Position.Y - 16) <= 3,
                            "client terrain elevation/material differs"
                        )
                    end
                end
                local aircraft = workspace:FindFirstChild("Aircraft")
                assert(aircraft and aircraft:IsA("Model"), "client canonical aircraft missing")
                local pose = aircraft:GetPivot()
                assert(
                    math.abs(Vector2.new(pose.X, pose.Z).Magnitude - 360) < 0.02,
                    "client aircraft not on expanded perimeter"
                )
            end)
            remote:FireServer(token, {
                passed = ok,
                detail = if ok then "geometry/terrain/aircraft observed" else tostring(reason),
                baseline = script.Parent:GetAttribute("ClientTestReport"),
            })
        end)
        removal = remote.AncestryChanged:Connect(function()
            if not remote:IsDescendantOf(ReplicatedStorage) then
                if listener then
                    listener:Disconnect()
                end
                if removal then
                    removal:Disconnect()
                end
            end
        end)
        remote:FireServer(0, { passed = true })
    end)
end
return Harness
