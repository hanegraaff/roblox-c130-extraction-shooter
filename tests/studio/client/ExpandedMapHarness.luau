--!strict
-- P13 real network-client geometry/terrain/aircraft probes. Test-only; bounded discovery
-- and one listener are torn down with the transport. No source/world mutation occurs.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Harness = {}
local HttpService = game:GetService("HttpService")
type Observation = {
    path: string,
    className: string,
    shape: string,
    pose: { number },
    size: { number },
    anchored: boolean,
    collide: boolean,
    query: boolean,
    touch: boolean,
}

-- Paths are relative to the specific Battlefield generation. Escape separators
-- inside a name so distinct parent segments cannot alias the same part identity.
local function partPath(map: Instance, part: BasePart): string
    local segments: { string } = {}
    local item: Instance? = part
    while item and item ~= map do
        local escaped = item.Name:gsub("~", "~0"):gsub("/", "~1")
        table.insert(segments, 1, escaped)
        item = item.Parent
    end
    assert(item == map, "part does not descend from the fixture root")
    return "/" .. table.concat(segments, "/")
end

-- Numeric component comparison accepts signed zero and float serialization differences
-- within 0.001 studs/components, without rounding-boundary false mismatches. Identity,
-- population, class, shape and collision/query/touch ownership must match exactly.
local function geometryMatches(expected: { Observation }, fixture: Instance?): (boolean, string?)
    local map = fixture or workspace.World:FindFirstChild("Battlefield")
    if not map then
        return false, "Battlefield missing"
    end
    local parts: { [string]: BasePart } = {}
    local count = 0
    for _, item in map:GetDescendants() do
        if item:IsA("BasePart") then
            local path = partPath(map, item)
            if parts[path] then
                return false, "duplicate actual part path " .. path
            end
            parts[path] = item
            count += 1
        end
    end
    if count ~= #expected then
        return false, "part count differs"
    end
    local seenExpected: { [string]: boolean } = {}
    for _, entry in expected do
        if seenExpected[entry.path] then
            return false, "duplicate expected part path " .. entry.path
        end
        seenExpected[entry.path] = true
        local actual = parts[entry.path]
        if not actual then
            return false, "part missing: " .. entry.path
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
            return false, "class/shape/flags differ: " .. entry.path
        end
        local pose = { actual.CFrame:GetComponents() }
        for index, value in entry.pose do
            local component = pose[index]
            if
                component ~= component
                or math.abs(component) == math.huge
                or math.abs(component - value) > 0.001
            then
                return false, "CFrame component differs: " .. entry.path .. ":" .. tostring(index)
            end
        end
        for index, component in { actual.Size.X, actual.Size.Y, actual.Size.Z } do
            if
                component ~= component
                or math.abs(component) == math.huge
                or math.abs(component - entry.size[index]) > 0.001
            then
                return false, "size differs: " .. entry.path .. ":" .. tostring(index)
            end
        end
    end
    return true, nil
end

-- Exercise the same path index on private Instances. Equal leaf names and
-- separator-like name segments must work, while a sibling with the same name
-- or a duplicate expected path of equal cardinality must fail.
local function verifyPathFixture()
    local fixture = Instance.new("Folder")
    local function panel(name: string, position: Vector3): BasePart
        local parent = Instance.new("Folder")
        parent.Name = name
        parent.Parent = fixture
        local solid = Instance.new("Part")
        solid.Name = "Solid"
        solid.Anchored = true
        solid.Position = position
        solid.Parent = parent
        return solid
    end
    local function expected(part: BasePart, path: string): Observation
        return {
            path = path,
            className = "Part",
            shape = "Block",
            pose = { part.CFrame:GetComponents() },
            size = { part.Size.X, part.Size.Y, part.Size.Z },
            anchored = true,
            collide = part.CanCollide,
            query = part.CanQuery,
            touch = part.CanTouch,
        }
    end
    local ok, problem = pcall(function()
        local first = panel("Panel/A", Vector3.zero)
        local second = panel("Panel~1A", Vector3.xAxis * 12)
        local one = expected(first, "/Panel~1A/Solid")
        local two = expected(second, "/Panel~01A/Solid")
        local matched, mismatch = geometryMatches({ one, two }, fixture)
        assert(matched, "distinct part paths rejected: " .. tostring(mismatch))
        matched, mismatch = geometryMatches({ one, one }, fixture)
        assert(
            not matched and mismatch == "duplicate expected part path " .. one.path,
            "duplicate expectation accepted"
        )
        local duplicate = first:Clone()
        duplicate.Parent = first.Parent
        matched, mismatch = geometryMatches({ one, two }, fixture)
        assert(
            not matched and mismatch == "duplicate actual part path " .. one.path,
            "duplicate actual path accepted"
        )
    end)
    fixture:Destroy()
    assert(ok, tostring(problem))
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
        local pathFixtureVerified = false
        listener = remote.OnClientEvent:Connect(function(token: number, expected: string)
            local ok, reason = pcall(function()
                if not pathFixtureVerified then
                    verifyPathFixture()
                    pathFixtureVerified = true
                end
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
                local originalPath = entry.path
                entry.path = "/P13MissingObservationPart"
                assert(not geometryMatches(observations), "missing part identity accepted")
                entry.path = originalPath
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
                for _, sample in
                    {
                        { point = Vector3.new(-258, 0, -138), material = Enum.Material.Sand },
                        { point = Vector3.new(238, 0, -162), material = Enum.Material.Grass },
                        { point = Vector3.new(162, 0, -146), material = Enum.Material.LeafyGrass },
                        { point = Vector3.new(178, 0, 194), material = Enum.Material.Asphalt },
                        { point = Vector3.new(2, 0, 258), material = Enum.Material.Sand },
                    }
                do
                    local hit =
                        workspace:Raycast(sample.point + Vector3.yAxis * 32, -Vector3.yAxis * 40, rays)
                    assert(
                        hit and hit.Material == sample.material and math.abs(hit.Position.Y) < 1,
                        "client district surface differs"
                    )
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
