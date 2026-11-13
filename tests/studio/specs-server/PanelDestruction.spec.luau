--!strict
-- P07 A3/A5/A6: actual residual geometry, rigid bodies and reset ownership.
-- Fixtures clone authored geometry; rule injection here does not prove aircraft
-- firing or multiplayer. Every fixture restores groups/Instances even on failure.
local Server = game:GetService("ServerScriptService").Server
local BuildingGeometry = require(Server.BuildingGeometry)
local DestructionRuntime = require(Server.DestructionRuntime)
local PanelFragments = require(Server.PanelFragments)
local PhysicsService = game:GetService("PhysicsService")
local RunService = game:GetService("RunService")
local CombatRuntime = require(Server.CombatRuntime)
local CombatService = require(Server.CombatService)
local function fixture()
    local world = Instance.new("Folder")
    world.Name = "P07GeometryFixture"
    local map = workspace.World.Battlefield:Clone()
    map.Parent = world
    BuildingGeometry.decorate(map)
    world.Parent = workspace
    local owner, reason = DestructionRuntime.start(world)
    assert(owner, reason)
    owner.sync(1)
    return world, map, owner
end
return function()
    local test = getfenv().it :: (string, () -> ()) -> ()
    test(
        "PanelGeometryStates measures every wall roof interior face and preserves stable structure",
        function()
            local world, map, owner = fixture()
            local ok, failure = pcall(function()
                local panels: { Model } = {}
                local statics: { [BasePart]: CFrame } = {}
                for _, item in map:GetDescendants() do
                    if item:IsA("Model") and item:GetAttribute("PanelId") then
                        table.insert(panels, item)
                    elseif item:IsA("BasePart") and item:GetAttribute("CoverKind") == "StaticSupport" then
                        statics[item] = item.CFrame
                    end
                end
                table.sort(panels, function(a, b)
                    return a.Name < b.Name
                end)
                assert(#panels == 111, "missing authored panel coverage")
                local serial = 0
                local function heavy(id: string)
                    serial += 1
                    assert(
                        owner.resolve({
                            roundId = 1,
                            shotId = serial,
                            weapon = "M102",
                            firedAt = serial * 4,
                            panelId = id,
                        }),
                        'Expected owner.resolve({ roundId = 1, shotId = serial, weapon = "M102", firedAt = serial * 4, panelId = id })'
                    )
                end
                for _, panel in panels do
                    local pivot = panel:GetAttribute("IntactPivot")
                    assert(typeof(pivot) == "CFrame", "missing stable pivot")
                    local solid = panel:FindFirstChild("Solid")
                    assert(solid and solid:IsA("BasePart"), "intact collider missing")
                    local size = solid.Size
                    for _ = 1, 3 do
                        heavy(panel.Name)
                    end
                    -- The explicit batch boundary retains original solid before flush.
                    assert(
                        solid.Parent == panel and panel:GetAttribute("PanelState") == "Intact",
                        "mid-batch mutation"
                    )
                    owner.flush(workspace:GetServerTimeNow())
                    assert(
                        panel:GetAttribute("PanelState") == "Damaged" and #panel:GetChildren() == 2,
                        "damaged state"
                    )
                    assert(
                        panel:GetAttribute("IntactPivot") == pivot and panel:GetPivot() == pivot,
                        "pivot changed"
                    )
                    local normal = if size.Y < 2
                        then Vector3.yAxis
                        elseif size.X < 2 then Vector3.xAxis
                        else Vector3.zAxis
                    local major = if size.X >= size.Z then Vector3.xAxis else Vector3.zAxis
                    local second = if size.Y < 2 then Vector3.zAxis else Vector3.yAxis
                    local width = if size.X >= size.Z then size.X else size.Z
                    local height = if size.Y < 2 then size.Z else size.Y
                    local rays = RaycastParams.new()
                    rays.FilterType = Enum.RaycastFilterType.Include
                    rays.FilterDescendantsInstances = { panel }
                    rays.RespectCanCollide = true
                    local blocked = 0
                    for x = 1, 20 do
                        for y = 1, 20 do
                            local sample = pivot:PointToWorldSpace(
                                major * ((x - 0.5) / 20 - 0.5) * width
                                    + second * ((y - 0.5) / 20 - 0.5) * height
                            )
                            local direction = pivot:VectorToWorldSpace(normal)
                            if workspace:Raycast(sample - direction * 2, direction * 4, rays) then
                                blocked += 1
                            end
                        end
                    end
                    local opening = 1 - blocked / 400
                    assert(opening >= 0.45 and opening <= 0.55, panel.Name .. " opening=" .. opening)
                    if size.Y > 2 then
                        local overlap = OverlapParams.new()
                        overlap.FilterType = Enum.RaycastFilterType.Include
                        overlap.FilterDescendantsInstances = { panel }
                        overlap.RespectCanCollide = true
                        assert(
                            #workspace:GetPartBoundsInBox(pivot, Vector3.new(4, 6, 4), overlap) == 0,
                            "wall passage blocked"
                        )
                    end
                    for _ = 1, 3 do
                        heavy(panel.Name)
                    end
                    owner.flush(workspace:GetServerTimeNow())
                    assert(
                        panel:GetAttribute("PanelState") == "Destroyed" and #panel:GetChildren() == 0,
                        "ghost collider"
                    )
                end
                for part, pose in statics do
                    assert(
                        part.Parent and part.CFrame == pose and part.Anchored and part.CanCollide,
                        "support changed"
                    )
                end
                assert(owner.resources().fragments == 48, "simultaneous transition cap")
                owner.sync(2)
                assert(
                    owner.resources().fragments == 0 and owner.resources().pending == 0,
                    "generation leaked fragments/pending"
                )
                for _, item in map:GetDescendants() do
                    if item:IsA("Model") and item:GetAttribute("PanelId") then
                        assert(
                            item:GetAttribute("PanelState") == "Intact" and #item:GetChildren() == 1,
                            "reset failed"
                        )
                    end
                end
            end)
            owner.stop()
            owner.stop()
            world:Destroy()
            assert(ok, tostring(failure))
        end
    )
    test(
        "PreImpactCoverAndThermal both profiles retain pre-impact solids then expose only actual holes",
        function()
            local world, map, owner = fixture()
            local ok, failure = pcall(function()
                local panel = map.Buildings.Foundry.Foundry_Panels:FindFirstChild("Foundry_S01_North_02")
                assert(panel and panel:IsA("Model"), "wall fixture missing")
                local pivot = panel:GetAttribute("IntactPivot")
                assert(typeof(pivot) == "CFrame", "pivot missing")
                local origin = pivot.Position + Vector3.new(0, 0, -2)
                local protected = pivot.Position + Vector3.new(0, 0, 2)
                local solid = pivot.Position + Vector3.new(-6, 0, 0)
                local params = RaycastParams.new()
                params.FilterType = Enum.RaycastFilterType.Include
                params.FilterDescendantsInstances = { panel }
                params.RespectCanCollide = true
                for _, weapon in { "GAU23", "M102" } do
                    local profile = CombatService.profiles[weapon]
                    assert(
                        CombatRuntime.sweep(origin, profile.collisionRadius, protected - origin, params),
                        weapon .. " intact sweep"
                    )
                    assert(
                        not CombatRuntime.coverAllows(origin, protected, params),
                        weapon .. " intact splash visibility"
                    )
                end
                for id = 1, 3 do
                    assert(
                        owner.resolve({
                            roundId = 1,
                            shotId = id,
                            weapon = "M102",
                            firedAt = id * 4,
                            panelId = panel.Name,
                        }),
                        "direct heavy fixture"
                    )
                end
                -- The whole creating batch still sees the original solid and gives
                -- zero exposure; only flush may change either profile's query result.
                for _, weapon in { "GAU23", "M102" } do
                    assert(
                        not CombatRuntime.coverAllows(origin, protected, params),
                        weapon .. " creating batch leaked"
                    )
                end
                owner.flush(workspace:GetServerTimeNow())
                for _, weapon in { "GAU23", "M102" } do
                    assert(
                        CombatRuntime.coverAllows(origin, protected, params),
                        weapon .. " later hole blocked"
                    )
                    assert(
                        not CombatRuntime.sweep(
                            origin,
                            CombatService.profiles[weapon].collisionRadius,
                            protected - origin,
                            params
                        ),
                        weapon .. " ghost sweep"
                    )
                    assert(
                        not CombatRuntime.coverAllows(
                            solid + Vector3.new(0, 0, -2),
                            solid + Vector3.new(0, 0, 2),
                            params
                        ),
                        weapon .. " residual solid ignored"
                    )
                end
            end)
            owner.stop()
            world:Destroy()
            assert(ok, tostring(failure))
        end
    )
    test(
        "PanelFragmentPhysics falls contacts static scenery excludes characters and expires with bounded cap",
        function()
            local scenery = Instance.new("Folder")
            scenery.Name = "P07PhysicsFixture"
            local floor = Instance.new("Part")
            floor.Anchored = true
            floor.Size = Vector3.new(60, 1, 60)
            floor.CFrame = CFrame.new(0, 120, 0)
            floor.Parent = scenery
            scenery.Parent = workspace
            local owner, reason = PanelFragments.start(scenery)
            assert(owner, reason)
            local player = game:GetService("Players"):GetPlayers()[1]
            local character = player.Character
            local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
            local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
            assert(character and root and root:IsA("BasePart") and humanoid, "actual physics avatar missing")
            local originalPose = character:GetPivot()
            local originalHealth = humanoid.Health
            local originalOwner = root:GetNetworkOwner()
            local automaticOwnership = root:GetNetworkOwnershipAuto()
            root:SetNetworkOwner(nil)
            character:PivotTo(CFrame.new(0, 123.5, 0))
            root.AssemblyLinearVelocity = Vector3.zero
            local ok, failure = pcall(function()
                owner.emit(CFrame.new(0, 130, 0), Vector3.new(16, 8, 1), Color3.new(1, 1, 1), 0)
                local folder = workspace:FindFirstChild("PanelFragments")
                assert(folder and #folder:GetChildren() == 4, "physical fragments absent")
                local fragments: { BasePart } = {}
                for _, item in folder:GetChildren() do
                    assert(
                        item:IsA("BasePart")
                            and not item.Anchored
                            and item.CanCollide
                            and not item.CanQuery
                            and not item.CanTouch,
                        "rigid-body flags"
                    )
                    assert(
                        item.CollisionGroup == "PanelFragments" and item:GetNetworkOwner() == nil,
                        "ownership/group"
                    )
                    assert(
                        item.AssemblyLinearVelocity.Magnitude <= 12.001
                            and item.AssemblyAngularVelocity.Magnitude <= 4.001,
                        "launch impulse bound"
                    )
                    table.insert(fragments, item)
                end
                assert(
                    not PhysicsService:CollisionGroupsAreCollidable("PanelFragments", "Default"),
                    "characters can be pushed"
                )
                assert(
                    not PhysicsService:CollisionGroupsAreCollidable("PanelFragments", "PanelFragments"),
                    "debris collisions"
                )
                assert(
                    PhysicsService:CollisionGroupsAreCollidable("PanelFragments", "PanelStatic"),
                    "no static collision"
                )
                local sample = fragments[1]
                local queryOrigin = sample.Position + Vector3.new(0, 0, -5)
                local queryStep = Vector3.new(0, 0, 10)
                local rays = RaycastParams.new()
                rays.FilterType = Enum.RaycastFilterType.Include
                rays.FilterDescendantsInstances = { sample }
                rays.RespectCanCollide = true
                -- Positive control uses the ONLY group permitted to collide with
                -- fragments, proving this exact ray intersects a real fragment.
                rays.CollisionGroup = "PanelStatic"
                local positive = workspace:Raycast(queryOrigin, queryStep, rays)
                assert(positive and positive.Instance == sample, "fragment query positive control missed")
                rays.CollisionGroup = "Default"
                assert(
                    not workspace:Raycast(queryOrigin, queryStep, rays),
                    "Default combat group queried fragment"
                )
                -- CanQuery alone does not hide a collidable BasePart. With
                -- collision disabled its own query flag takes effect as well.
                rays.CollisionGroup = "PanelStatic"
                rays.RespectCanCollide = false
                sample.CanCollide = false
                assert(
                    not workspace:Raycast(queryOrigin, queryStep, rays),
                    "noncollidable CanQuery=false still queried"
                )
                sample.CanCollide = true
                for _, fragment in fragments do
                    assert(fragment.Mass <= 3.3751, "fragment mass exceeded authored1.5stud cube bound")
                    assert(
                        fragment.Mass * fragment.AssemblyLinearVelocity.Magnitude <= 40.502,
                        "initial linear momentum exceeded bound"
                    )
                end
                -- Drop one owned real rigid body straight through the actual
                -- avatar; query overlap witnesses intersection rather than only
                -- assuming collision-group configuration proved no contact.
                fragments[1].CFrame = CFrame.new(root.Position + Vector3.new(0, 6, 0))
                fragments[1].AssemblyLinearVelocity = Vector3.zero
                local avatarOverlap = OverlapParams.new()
                avatarOverlap.FilterType = Enum.RaycastFilterType.Include
                avatarOverlap.FilterDescendantsInstances = { character }
                local crossedAvatar = false
                local initialHeights: { [BasePart]: number } = {}
                for _, fragment in fragments do
                    initialHeights[fragment] = fragment.Position.Y
                end
                local falling = false
                local fallDeadline = os.clock() + 1
                repeat
                    RunService.Heartbeat:Wait()
                    if #workspace:GetPartsInPart(fragments[1], avatarOverlap) > 0 then
                        crossedAvatar = true
                    end
                    for _, fragment in fragments do
                        if
                            fragment.Position.Y < initialHeights[fragment] - 0.1
                            and fragment.AssemblyLinearVelocity.Y < -0.1
                        then
                            falling = true
                        end
                    end
                until falling or os.clock() >= fallDeadline
                assert(falling, "no early downward displacement and velocity observed before resting contact")
                local deadline = os.clock() + 4
                local contact = false
                repeat
                    RunService.Heartbeat:Wait()
                    if #workspace:GetPartsInPart(fragments[1], avatarOverlap) > 0 then
                        crossedAvatar = true
                    end
                    for _, fragment in fragments do
                        if
                            math.abs(fragment.Position.Y - (120.5 + fragment.Size.Y / 2)) < 0.2
                            and math.abs(fragment.AssemblyLinearVelocity.Y) < 0.5
                        then
                            contact = true
                        end
                    end
                until contact or os.clock() >= deadline
                assert(contact, "no actual static resting contact observed")
                assert(crossedAvatar, "fragment did not actually cross the real avatar")
                assert(
                    Vector2.new(root.Position.X, root.Position.Z).Magnitude < 0.2
                        and humanoid.Health == originalHealth,
                    "physical debris pushed or harmed actual avatar"
                )
                for _ = 1, 20 do
                    owner.emit(CFrame.new(0, 130, 0), Vector3.one, Color3.new(1, 1, 1), 0)
                end
                assert(owner.count() == 48 and #folder:GetChildren() == 48, "overflow cap failed")
                owner.step(7.999)
                assert(owner.count() == 48, "premature lifetime expiry")
                owner.step(8)
                assert(owner.count() == 0 and #folder:GetChildren() == 0, "lifetime boundary leaked")
            end)
            character:PivotTo(originalPose)
            root.AssemblyLinearVelocity = Vector3.zero
            if automaticOwnership then
                root:SetNetworkOwnershipAuto()
            else
                root:SetNetworkOwner(originalOwner)
            end
            owner.stop()
            owner.stop()
            assert(floor.CollisionGroup == "Default", "static group not restored")
            scenery:Destroy()
            assert(ok, tostring(failure))
        end
    )
    test("PanelDestructionReset reacquires a replaced map without stale rounds or group leaks", function()
        local world, map, owner = fixture()
        local ok, failure = pcall(function()
            for round = 1, 3 do
                local panel = map.Buildings.Foundry.Foundry_Panels:GetChildren()[1]
                local id = panel.Name
                assert(
                    owner.resolve({
                        roundId = round,
                        shotId = 1,
                        weapon = "M102",
                        firedAt = round,
                        panelId = id,
                    }),
                    'Expected owner.resolve({ roundId = round, shotId = 1, weapon = "M102", firedAt = round, panelId = id })'
                )
                owner.flush(workspace:GetServerTimeNow())
                local replacement = workspace.World.Battlefield:Clone()
                BuildingGeometry.decorate(replacement)
                map:Destroy()
                replacement.Parent = world
                map = replacement
                owner.sync(round)
                assert(not owner.resolve({
                    roundId = round,
                    shotId = 1,
                    weapon = "M102",
                    firedAt = round + 1,
                    panelId = id,
                }), "same-ID reset admitted old shot")
                owner.sync(round + 1)
                assert(not owner.resolve({
                    roundId = round,
                    shotId = 2,
                    weapon = "M102",
                    firedAt = round + 1,
                    panelId = id,
                }), "old projectile accepted")
                assert(
                    assert(owner.snapshot(id), "panel missing").progress == 0
                        and owner.resources().fragments == 0,
                    "reset progress"
                )
            end
        end)
        owner.stop()
        world:Destroy()
        assert(
            not PhysicsService:IsCollisionGroupRegistered("PanelFragments")
                and not PhysicsService:IsCollisionGroupRegistered("PanelStatic"),
            "owned groups leaked"
        )
        assert(ok, tostring(failure))
    end)
end
