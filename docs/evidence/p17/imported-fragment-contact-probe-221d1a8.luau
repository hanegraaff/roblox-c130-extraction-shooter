--!strict
-- P17 Server DataModel fixture. Runs approved material fragments through the
-- production rigid-body owner on an isolated, temporary static floor.
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

assert(
    RunService:IsStudio() and RunService:IsServer() and RunService:IsRunning(),
    "running Studio server required"
)
assert(game.PlaceId == 0 and game.GameId == 0, "local test document required")
local settings = ServerStorage:FindFirstChild("DevelopmentSettings")
assert(settings and settings:IsA("ModuleScript"), "test mapping required")
local commit = "221d1a824529855db110712d61f0b1f8be5f68e8"
assert(settings:GetAttribute("P17HarnessCommit") == commit, "expected frozen candidate selector")
for owner, names in
    {
        [ReplicatedStorage] = {
            "RoundState",
            "AircraftState",
            "LauncherState",
            "StudioTestControls",
            "P05Harness",
            "P07Harness",
            "P08Harness",
            "P14Harness",
            "P17ManualHarness",
            "P17PerformanceTransport",
        },
        [ServerStorage] = { "LocalTestControls", "P17UserPreviewStop" },
        [workspace] = {
            "Aircraft",
            "CombatEffects",
            "GroundCombatEffects",
            "PanelFragments",
            "P17ImportedFragmentFixture",
        },
    }
do
    for _, name in names do
        assert(not owner:FindFirstChild(name), "competing fixture/runtime: " .. name)
    end
end
for _, group in { "PanelStatic", "PanelFragments" } do
    assert(not PhysicsService:IsCollisionGroupRegistered(group), "existing physics group: " .. group)
end

local Catalog = require(ServerScriptService.Server.PanelAssetCatalog)
local Fragments = require(ServerScriptService.Server.PanelFragments)
local AssetMesh = require(ReplicatedStorage.Shared.AssetMesh)
local assets = assert(ServerStorage:FindFirstChild("Assets"), "private asset root missing")
local materialRoot = assert(assets:FindFirstChild("MaterialPanels"), "approved material assets missing")
local catalog, catalogError = Catalog.load(materialRoot)
assert(catalog, catalogError)

local subjects = Players:GetPlayers()
table.sort(subjects, function(left, right)
    return left.UserId < right.UserId
end)
local player: Player? = nil
local character: Model? = nil
local root: BasePart? = nil
local humanoid: Humanoid? = nil
for _, subject in subjects do
    local currentCharacter = subject.Character
    local currentRoot = currentCharacter and currentCharacter:FindFirstChild("HumanoidRootPart")
    local currentHumanoid = currentCharacter and currentCharacter:FindFirstChildOfClass("Humanoid")
    if
        currentCharacter
        and currentRoot
        and currentRoot:IsA("BasePart")
        and currentHumanoid
        and currentHumanoid.Health > 0
    then
        player, character, root, humanoid = subject, currentCharacter, currentRoot, currentHumanoid
        break
    end
end
assert(player and character and root and humanoid, "one actual live avatar with root and Humanoid required")
local avatarUserId = player.UserId
local originalPose = character:GetPivot()
local originalLinearVelocity = root.AssemblyLinearVelocity
local originalAngularVelocity = root.AssemblyAngularVelocity
local originalOwner = root:GetNetworkOwner()
local originalAutoOwnership = root:GetNetworkOwnershipAuto()
local originalTerrainGroup = workspace.Terrain.CollisionGroup
local familyNames = {}
for name in catalog do
    table.insert(familyNames, name)
end
table.sort(familyNames)
assert(#familyNames == 6, "approved catalog requires six families")

type FragmentRecord = {
    name: string,
    family: string,
    templateIndex: number,
    meshId: string,
    launchYStuds: number,
    launchSpeedStudsPerSecond: number,
    launchAngularRadiansPerSecond: number,
    mass: number,
    descentObserved: boolean,
    settledObserved: boolean,
    restGapStuds: number?,
    restVerticalSpeedStudsPerSecond: number?,
}
type ObservedFragment = {
    part: MeshPart,
    record: FragmentRecord,
    restingSince: number?,
}
local fixture = Instance.new("Folder")
fixture.Name = "P17ImportedFragmentFixture"
local floor = Instance.new("Part")
floor.Name = "IsolatedStaticSurface"
floor.Size = Vector3.new(164, 1, 84)
floor.CFrame = CFrame.new(600, 120, 600)
floor.Anchored = true
floor.Parent = fixture
local floorTop = floor.Position.Y + floor.Size.Y / 2
local observed: { ObservedFragment } = {}
local records: { FragmentRecord } = {}
local results: { [string]: unknown } = {
    schemaVersion = 1,
    sourceCommit = commit,
    productionCommit = "ee19deb5fe18090573ce0d9788b0c77555bca333",
    placeId = game.PlaceId,
    gameId = game.GameId,
    avatarUserId = avatarUserId,
    actualClientCount = #subjects,
    assetRevision = materialRoot:GetAttribute("AssetRevision"),
    importReceiptSha256 = materialRoot:GetAttribute("ImportReceiptSha256"),
    coverage = "six approved template families; isolated actual physics floor; one controlled live-avatar crossing",
    fragments = records,
}

local owner: Fragments.Controller? = nil
local avatarMoved = false
local ok, failure = pcall(function()
    local activeCharacter = assert(character)
    local activeRoot = assert(root)
    local activeHumanoid = assert(humanoid)
    fixture.Parent = workspace
    local controller, reason = Fragments.start(fixture)
    assert(controller, reason)
    owner = controller
    local folder = assert(workspace:FindFirstChild("PanelFragments"), "production fragment folder missing")
    assert(floor.CollisionGroup == "PanelStatic", "fixture floor did not enter the actual static group")

    for _, item in activeCharacter:GetDescendants() do
        if item:IsA("BasePart") then
            assert(
                not PhysicsService:CollisionGroupsAreCollidable(item.CollisionGroup, "PanelFragments"),
                "avatar collision group can contact fragments: " .. item.CollisionGroup
            )
        end
    end
    assert(
        PhysicsService:CollisionGroupsAreCollidable("PanelStatic", "PanelFragments")
            and not PhysicsService:CollisionGroupsAreCollidable("PanelFragments", "PanelFragments"),
        "fragment/static collision matrix differs from production contract"
    )

    avatarMoved = true
    activeRoot:SetNetworkOwner(nil)
    activeCharacter:PivotTo(CFrame.new(665, 124, 600))
    activeRoot.AssemblyLinearVelocity = Vector3.zero
    activeRoot.AssemblyAngularVelocity = Vector3.zero
    local avatarSettlesBy = os.clock() + 3
    repeat
        RunService.Heartbeat:Wait()
    until activeHumanoid.FloorMaterial ~= Enum.Material.Air or os.clock() >= avatarSettlesBy
    assert(activeHumanoid.FloorMaterial ~= Enum.Material.Air, "real avatar did not reach the isolated floor")
    local avatarStart = activeRoot.Position
    local avatarHealth = activeHumanoid.Health
    local firstEmission = workspace:GetServerTimeNow()

    for familyIndex, familyName in familyNames do
        local family = catalog[familyName]
        local pivot = CFrame.new(540 + (familyIndex - 1) * 16, floorTop + 7, 600)
        controller.emit(pivot, family.size, Color3.new(1, 1, 1), firstEmission, family.fragments)
        for templateIndex, template in family.fragments do
            local serial = (familyIndex - 1) * 4 + templateIndex
            local name = "Fragment" .. serial
            local part = folder:FindFirstChild(name)
            assert(part and part:IsA("MeshPart"), "production clone missing: " .. name)
            assert(
                AssetMesh.validate(part)
                    and part.MeshId == template.MeshId
                    and part.Size == template.Size
                    and part.CollisionFidelity == Enum.CollisionFidelity.Box
                    and part:GetAttribute("SourceSha256") == template:GetAttribute("SourceSha256"),
                "approved native mesh identity differs: " .. name
            )
            assert(
                not part.Anchored
                    and part.CanCollide
                    and not part.CanQuery
                    and not part.CanTouch
                    and part.CollisionGroup == "PanelFragments"
                    and part:GetNetworkOwner() == nil
                    and not part:GetNetworkOwnershipAuto()
                    and part:GetAttribute("ThermalNonCover") == true,
                "fragment owner, flags or query role differs: " .. name
            )
            local linear = part.AssemblyLinearVelocity.Magnitude
            local angular = part.AssemblyAngularVelocity.Magnitude
            assert(
                part.Mass <= 3.3751 and linear <= 12.001 and angular <= 4.001 and part.Mass * linear <= 40.502,
                "fragment launch mass or velocity bound exceeded: " .. name
            )
            local record: FragmentRecord = {
                name = name,
                family = familyName,
                templateIndex = templateIndex,
                meshId = part.MeshId,
                launchYStuds = part.Position.Y,
                launchSpeedStudsPerSecond = linear,
                launchAngularRadiansPerSecond = angular,
                mass = part.Mass,
                descentObserved = false,
                settledObserved = false,
            }
            table.insert(records, record)
            table.insert(observed, { part = part, record = record })
        end
    end
    assert(controller.count() == 24 and #folder:GetChildren() == 24, "six-family emission count was not 24")

    local sample = observed[1].part
    local rays = RaycastParams.new()
    rays.FilterType = Enum.RaycastFilterType.Include
    rays.FilterDescendantsInstances = { sample, floor }
    rays.RespectCanCollide = true
    local queryOrigin = sample.Position + Vector3.new(0, 2, 0)
    local queryStep = Vector3.new(0, -14, 0)
    rays.CollisionGroup = "PanelStatic"
    local positive = workspace:Raycast(queryOrigin, queryStep, rays)
    assert(positive and positive.Instance == sample, "real query positive control missed approved fragment")
    rays.CollisionGroup = "Default"
    rays.RespectCanCollide = false
    local ray = workspace:Raycast(queryOrigin, queryStep, rays)
    local sweep = workspace:Spherecast(queryOrigin, 0.25, queryStep, rays)
    assert(
        ray and ray.Instance == floor and sweep and sweep.Instance == floor,
        "normal ray/sweep did not pass through debris to static floor"
    )
    results.queryControls = {
        staticGroupHit = positive.Instance.Name,
        defaultRayHit = ray.Instance.Name,
        defaultSweepHit = sweep.Instance.Name,
    }

    -- One controlled drop guarantees overlap with the real avatar. The other 23
    -- fragments retain the production trajectory and certify unforced static contact.
    sample.CFrame += avatarStart + Vector3.new(0, 6, 0) - sample.Position
    sample.AssemblyLinearVelocity = Vector3.zero
    sample.AssemblyAngularVelocity = Vector3.zero
    observed[1].record.launchYStuds = sample.Position.Y
    results.controlledAvatarFragment = sample.Name
    local avatarOverlap = OverlapParams.new()
    avatarOverlap.FilterType = Enum.RaycastFilterType.Include
    avatarOverlap.FilterDescendantsInstances = { activeCharacter }
    local crossedAvatar = false
    local maximumAvatarDrift = 0
    local settledCount = 0
    local deadline = os.clock() + 5
    repeat
        RunService.Heartbeat:Wait()
        assert(
            player.Character == activeCharacter and activeHumanoid.Health > 0,
            "avatar changed while sampling"
        )
        if #workspace:GetPartsInPart(sample, avatarOverlap) > 0 then
            crossedAvatar = true
        end
        local drift = Vector2.new(
            activeRoot.Position.X - avatarStart.X,
            activeRoot.Position.Z - avatarStart.Z
        ).Magnitude
        maximumAvatarDrift = math.max(maximumAvatarDrift, drift)
        local now = os.clock()
        for _, observedFragment in observed do
            local part, record = observedFragment.part, observedFragment.record
            local vertical = part.AssemblyLinearVelocity.Y
            if part.Position.Y < record.launchYStuds - 0.1 and vertical < -0.1 then
                record.descentObserved = true
            end
            if not record.settledObserved then
                -- All approved fragment colliders are Box. Project the actual
                -- rotated half-extents onto Y to find their lowest contact point.
                local pose = part.CFrame
                local lowerExtent = (
                    math.abs(pose.RightVector.Y) * part.Size.X
                    + math.abs(pose.UpVector.Y) * part.Size.Y
                    + math.abs(pose.LookVector.Y) * part.Size.Z
                ) / 2
                local gap = part.Position.Y - lowerExtent - floorTop
                if record.descentObserved and math.abs(gap) < 0.2 and math.abs(vertical) < 0.5 then
                    local since = observedFragment.restingSince or now
                    observedFragment.restingSince = since
                    if now - since >= 0.15 then
                        record.settledObserved = true
                        record.restGapStuds = gap
                        record.restVerticalSpeedStudsPerSecond = math.abs(vertical)
                        settledCount += 1
                    end
                else
                    observedFragment.restingSince = nil
                end
            end
        end
    until (settledCount == 24 and crossedAvatar) or os.clock() >= deadline
    results.settledCount = settledCount
    results.actualAvatarOverlap = crossedAvatar
    results.maximumAvatarHorizontalDriftStuds = maximumAvatarDrift
    results.avatarHealthBefore = avatarHealth
    results.avatarHealthAfter = activeHumanoid.Health
    assert(settledCount == 24, "not every imported fragment fell to stable actual floor contact")
    assert(crossedAvatar, "controlled imported fragment never intersected actual avatar")
    assert(
        maximumAvatarDrift < 0.2 and activeHumanoid.Health == avatarHealth,
        "debris pushed or harmed actual avatar"
    )

    local expiry = firstEmission + Fragments.defaults.lifetimeSeconds
    controller.step(expiry - 0.001)
    assert(controller.count() == 24, "early lifetime expiry")
    results.fragmentsBeforeExpiry = controller.count()
    controller.step(expiry)
    assert(controller.count() == 0 and #folder:GetChildren() == 0, "lifetime boundary failed")
    results.fragmentsAtExpiry = controller.count()

    local firstFamily = catalog[familyNames[1]]
    for _ = 1, 20 do
        controller.emit(
            CFrame.new(600, floorTop + 7, 600),
            firstFamily.size,
            Color3.new(1, 1, 1),
            expiry,
            firstFamily.fragments
        )
    end
    results.cappedFragments = controller.count()
    assert(
        controller.count() == Fragments.defaults.maximum
            and #folder:GetChildren() == Fragments.defaults.maximum,
        "live imported fragment cap failed"
    )
    controller.clear()
    results.fragmentsAfterClear = controller.count()
    assert(controller.count() == 0 and #folder:GetChildren() == 0, "owner clear leaked fragments")
    controller.emit(
        CFrame.new(600, floorTop + 7, 600),
        firstFamily.size,
        Color3.new(1, 1, 1),
        expiry,
        firstFamily.fragments
    )
    assert(controller.count() == 4, "stop requires live approved fragments")
end)

local stopped, stopError = pcall(function()
    if owner then
        owner.stop()
        owner.stop()
    end
end)
local restoredFloor = floor.CollisionGroup == "Default"
fixture:Destroy()
local avatarRestored, avatarRestoreError = pcall(function()
    if avatarMoved then
        assert(
            player.Character == character and root.Parent and character.Parent,
            "original avatar no longer live"
        )
        character:PivotTo(originalPose)
        root.AssemblyLinearVelocity = originalLinearVelocity
        root.AssemblyAngularVelocity = originalAngularVelocity
        if originalAutoOwnership then
            root:SetNetworkOwnershipAuto()
        else
            root:SetNetworkOwner(originalOwner)
        end
        assert(
            (character:GetPivot().Position - originalPose.Position).Magnitude < 0.01,
            "avatar pose did not restore"
        )
    end
end)
local cleanup = {
    stopCompleted = stopped,
    stopError = if stopped then nil else tostring(stopError),
    avatarRestored = avatarRestored,
    avatarRestoreError = if avatarRestored then nil else tostring(avatarRestoreError),
    floorGroupRestored = restoredFloor,
    terrainGroupRestored = workspace.Terrain.CollisionGroup == originalTerrainGroup,
    fragmentFolderAbsent = not workspace:FindFirstChild("PanelFragments"),
    fixtureAbsent = not workspace:FindFirstChild("P17ImportedFragmentFixture"),
    fragmentGroupAbsent = not PhysicsService:IsCollisionGroupRegistered("PanelFragments"),
    staticGroupAbsent = not PhysicsService:IsCollisionGroupRegistered("PanelStatic"),
}
results.cleanup = cleanup
results.passed = ok
    and cleanup.stopCompleted
    and cleanup.avatarRestored
    and cleanup.floorGroupRestored
    and cleanup.terrainGroupRestored
    and cleanup.fragmentFolderAbsent
    and cleanup.fixtureAbsent
    and cleanup.fragmentGroupAbsent
    and cleanup.staticGroupAbsent
results.failure = if ok then nil else tostring(failure)
return results
