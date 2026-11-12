--!strict
-- Test-only P05 real-client harness. Owns its runtime, fixture and remote; reports
-- actual role assignment, network requests and authoritative combat observations.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StudioTestService = game:GetService("StudioTestService")
local HttpService = game:GetService("HttpService")
local GameRuntime = require(game:GetService("ServerScriptService").Server.GameRuntime)
local CombatHarness = {}
type Case = { name: string, passed: boolean, detail: string? }
local function waitFor(predicate: () -> boolean, message: string, timeout: number?)
    local deadline = os.clock() + (timeout or 15)
    while not predicate() and os.clock() < deadline do
        task.wait(0.03)
    end
    assert(predicate(), "P05 timeout: " .. message)
end
function CombatHarness.run()
    waitFor(function()
        return #Players:GetPlayers() == 2
    end, "two actual clients", 35)
    local runtime, reason = GameRuntime.start({
        automaticDeployment = false,
        minimumPlayers = 2,
        durationSeconds = 120,
        lobbySeconds = 0,
        deploymentSeconds = 25,
        resultsSeconds = 10,
        seed = 1,
    })
    assert(runtime, reason)
    local transport = Instance.new("RemoteEvent")
    transport.Name = "P05Harness"
    local ready: { [Player]: boolean } = {}
    local replies: { [number]: { ok: boolean, message: string } } = {}
    local sequence = 0
    local listener = transport.OnServerEvent:Connect(
        function(player: Player, token: unknown, ok: unknown, message: unknown)
            if token == 0 then
                ready[player] = true
            elseif type(token) == "number" then
                replies[token] = { ok = ok == true, message = tostring(message) }
            end
        end
    )
    transport.Parent = ReplicatedStorage
    local cases: { Case } = {}
    local observations: { unknown } = {}
    local function check(name: string, callback: () -> ())
        local ok, failure = pcall(function()
            callback()
            return true
        end)
        table.insert(cases, { name = name, passed = ok, detail = if ok then nil else tostring(failure) })
        assert(ok, tostring(failure))
    end
    local function probe(player: Player, kind: string, payload: unknown)
        waitFor(function()
            return ready[player] == true
        end, "client ready")
        sequence += 1
        local token = sequence
        transport:FireClient(player, token, kind, payload)
        waitFor(function()
            return replies[token] ~= nil
        end, "client reply")
        local reply = replies[token]
        replies[token] = nil
        assert(reply.ok, reply.message)
    end
    local function snapshot(name: string): { [string]: unknown }
        local encoded = ReplicatedStorage.AircraftState:GetAttribute(name)
        assert(type(encoded) == "string", "missing replicated " .. name)
        return HttpService:JSONDecode(encoded)
    end
    local function roles(): (Player, Player)
        local op: Player? = nil
        local ground: Player? = nil
        for _, player in Players:GetPlayers() do
            if player:GetAttribute("Role") == "Gunship" then
                op = player
            end
            if player:GetAttribute("Role") == "Ground" then
                ground = player
            end
        end
        assert(op and ground, "roles missing")
        return op, ground
    end
    local function payload(id: number, weapon: string, target: Vector3): { [string]: unknown }
        return {
            roundId = runtime.rounds.match.snapshot().roundId,
            sequence = id,
            weapon = weapon,
            x = target.X,
            y = target.Y,
            z = target.Z,
        }
    end
    local function ammo(weapon: string): number?
        local readiness = snapshot("Readiness")[weapon]
        if type(readiness) == "table" then
            local fields = readiness :: { [string]: unknown }
            if type(fields.ammo) == "number" then
                return fields.ammo
            end
        end
        return nil
    end
    local fixture = Instance.new("Folder")
    fixture.Name = "P05Fixture"
    fixture.Parent = workspace.World.Battlefield
    local ok, failure = pcall(function()
        check("A3 rejected client traffic leaves readiness intact", function()
            assert(runtime.rounds.match.deploy(), "deployment failed")
            waitFor(function()
                return runtime.rounds.match.snapshot().phase == "Active"
            end, "active", 35)
            local op, ground = roles()
            local pos = Vector3.new(0, 30, 0)
            local before = HttpService:JSONEncode(snapshot("Readiness"))
            local forged = payload(1, "GAU23", pos)
            forged.damage = 10000
            probe(op, "Fire", forged)
            probe(ground, "Fire", payload(1, "GAU23", pos))
            local outside = payload(1, "GAU23", Vector3.new(500, 0, 0))
            probe(op, "Fire", outside)
            local oldRound = payload(1, "GAU23", pos)
            oldRound.roundId = runtime.rounds.match.snapshot().roundId - 1
            probe(op, "Fire", oldRound)
            local nan = payload(1, "GAU23", pos)
            nan.x = 0 / 0
            probe(op, "Fire", nan)
            local infinite = payload(1, "GAU23", pos)
            infinite.y = math.huge
            probe(op, "Fire", infinite)
            probe(op, "Flood", forged)
            task.wait(0.5)
            assert(HttpService:JSONEncode(snapshot("Readiness")) == before, "rejected fire spent ammunition")
            probe(op, "Observe", nil)
            probe(ground, "Observe", nil)
            task.wait(1.5) -- restore the finite server rate budget before valid traffic
        end)
        check("A4 swept muzzle path hits thin cover before the visible target", function()
            local op, ground = roles()
            local character = ground.Character
            local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
            local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
            assert(root and root:IsA("BasePart") and humanoid, "ground character missing")
            local regeneration = character and character:FindFirstChild("Health")
            assert(
                regeneration and regeneration:IsA("BaseScript"),
                "test character regeneration script missing"
            )
            regeneration.Disabled = true -- Test-only: stabilize the previously wounded fixture.
            root.Anchored = true
            root.CFrame = CFrame.new(0, 30, 0)
            local target = root.Position
            local muzzle = runtime.aircraft.muzzle("GAU23")
            assert(muzzle, "muzzle missing")
            local wall = Instance.new("Part")
            wall.Name = "ThinWall"
            wall.Anchored = true
            wall.Size = Vector3.new(30, 30, 0.2)
            wall.CFrame = CFrame.lookAt(muzzle:Lerp(target, 0.65), target)
            wall.Parent = fixture
            local before = humanoid.Health
            probe(op, "Fire", payload(1, "GAU23", target))
            waitFor(function()
                return ammo("GAU23") == 99
            end, "blocked shot accepted")
            waitFor(function()
                return #workspace.CombatEffects:GetChildren() == 0
            end, "projectile resolution", 6)
            task.wait(0.3)
            assert(humanoid.Health == before, "thin cover failed to protect player")
            wall:Destroy()
            probe(op, "Fire", payload(2, "GAU23", target))
            waitFor(function()
                return humanoid.Health < before
            end, "exposed player damage", 6)
            assert(humanoid.Health == before - 25, "unexpected or duplicate chain-gun damage")
            local observed = { weapon = "GAU23", shotId = 2, targetId = ground.UserId, health = before - 25 }
            probe(op, "Observe", observed)
            probe(ground, "Observe", observed)
        end)
        check("A3 forged airborne endpoint cannot create damage or an impact", function()
            local op, ground = roles()
            local character = ground.Character
            local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
            local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
            assert(character and root and root:IsA("BasePart") and humanoid, "ground character missing")
            local roundId = runtime.rounds.match.snapshot().roundId
            probe(op, "Select", { roundId = roundId, sequence = 1, weapon = "M102" })
            waitFor(function()
                return snapshot("Selection").weapon == "M102"
            end, "heavy selected")
            local muzzle = runtime.aircraft.muzzle("M102")
            assert(muzzle, "heavy muzzle missing")
            local radial = Vector3.new(root.Position.X - muzzle.X, 0, root.Position.Z - muzzle.Z).Unit
            local target = root.Position + Vector3.new(-radial.Z, 0, radial.X) * 10
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Include
            params.FilterDescendantsInstances = { workspace.World.Battlefield, workspace.Terrain, character }
            assert(
                not workspace:Raycast(muzzle, target - muzzle, params),
                "airburst fixture path is obstructed"
            )
            local beforeHealth = humanoid.Health
            local beforeImpact = ReplicatedStorage.AircraftState:GetAttribute("Impact")
            probe(op, "Fire", payload(3, "M102", target))
            waitFor(function()
                return ammo("M102") == 0
            end, "airburst request accepted")
            waitFor(function()
                return #workspace.CombatEffects:GetChildren() == 0
            end, "airburst flight ended", 6)
            local afterHealth = humanoid.Health
            local afterImpact = ReplicatedStorage.AircraftState:GetAttribute("Impact")
            local observation = {
                fixtureMuzzle = { muzzle.X, muzzle.Y, muzzle.Z },
                endpoint = { target.X, target.Y, target.Z },
                targetRoot = { root.Position.X, root.Position.Y, root.Position.Z },
                preflightRayHit = false,
                beforeHealth = beforeHealth,
                afterHealth = afterHealth,
                beforeImpact = beforeImpact,
                afterImpact = afterImpact,
            }
            table.insert(observations, observation)
            assert(
                afterHealth == beforeHealth,
                "airburst health changed: " .. HttpService:JSONEncode(observation)
            )
            assert(
                afterImpact == beforeImpact,
                "airburst published an impact: " .. HttpService:JSONEncode(observation)
            )
            waitFor(function()
                return ammo("M102") == 1
            end, "heavy reload after airburst", 8)
        end)
        check("A2 switching preserves heavy reload and A5 lethal hit ends once", function()
            local op, ground = roles()
            local character = ground.Character
            local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
            local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
            assert(root and root:IsA("BasePart") and humanoid, "ground character missing")
            local roundId = runtime.rounds.match.snapshot().roundId
            local muzzle = runtime.aircraft.muzzle("M102")
            assert(muzzle, "heavy muzzle missing")
            local wall = Instance.new("Part")
            wall.Name = "HeavyCover"
            wall.Anchored = true
            wall.Size = Vector3.new(50, 50, 0.2)
            wall.CFrame = CFrame.lookAt(muzzle:Lerp(root.Position, 0.6), root.Position)
            wall.Parent = fixture
            probe(op, "Fire", payload(4, "M102", root.Position))
            waitFor(function()
                return ammo("M102") == 0
            end, "heavy reload started")
            probe(op, "Select", { roundId = roundId, sequence = 2, weapon = "GAU23" })
            waitFor(function()
                return snapshot("Selection").weapon == "GAU23"
            end, "chain gun selected")
            probe(op, "Select", { roundId = roundId, sequence = 3, weapon = "M102" })
            waitFor(function()
                return snapshot("Selection").weapon == "M102"
            end, "heavy reselected")
            assert(ammo("M102") == 0, "switch refilled reloading heavy weapon")
            waitFor(function()
                return ammo("M102") == 1
            end, "heavy reload completion", 8)
            wall:Destroy()
            probe(op, "Fire", payload(5, "M102", root.Position))
            waitFor(function()
                return runtime.rounds.match.snapshot().phase == "Results"
            end, "elimination result", 8)
            local result = runtime.rounds.match.snapshot().result
            assert(result and result.winner == "Gunship", "ground elimination did not award gunship")
            assert(humanoid.Health <= 0, "lethal heavy hit did not eliminate ground")
            local revision = runtime.rounds.match.snapshot().revision
            local observed = { weapon = "M102", shotId = 5, winner = "Gunship" }
            probe(op, "Observe", observed)
            probe(ground, "Observe", observed)
            task.wait(0.5)
            assert(runtime.rounds.match.snapshot().revision == revision, "result committed more than once")
            assert(
                ground.Character == nil or ground.Character == character,
                "eliminated ground respawned during results"
            )
        end)
        check("A5 terminal and next-round cleanup invalidate outstanding and stale shots", function()
            waitFor(function()
                return runtime.rounds.match.snapshot().phase == "Lobby"
            end, "first reset to lobby", 20)
            assert(runtime.rounds.match.deploy(), "second deployment failed")
            waitFor(function()
                return runtime.rounds.match.snapshot().phase == "Active"
            end, "second active round", 35)
            local op = roles()
            local previousRound = runtime.rounds.match.snapshot().roundId
            probe(op, "Select", { roundId = previousRound, sequence = 1, weapon = "M102" })
            waitFor(function()
                return snapshot("Selection").weapon == "M102"
            end, "second heavy selection")
            local muzzle = runtime.aircraft.muzzle("M102")
            assert(muzzle, "second heavy muzzle missing")
            local radial = Vector3.new(muzzle.X, 0, muzzle.Z).Unit
            local target = -radial * 300 + Vector3.new(0, 30, 0)
            probe(op, "Fire", payload(1, "M102", target))
            waitFor(function()
                return runtime.combat.resources().projectiles > 0
            end, "old-round projectile in flight", 5)
            assert(runtime.rounds.match.abort(previousRound, "P05ResetProbe"), "second round abort failed")
            waitFor(function()
                return runtime.combat.resources().projectiles == 0
                    and #workspace.CombatEffects:GetChildren() == 0
            end, "terminal projectile cleanup")
            waitFor(function()
                return runtime.rounds.match.snapshot().phase == "Lobby"
            end, "second reset to lobby", 20)
            assert(runtime.rounds.match.deploy(), "third deployment failed")
            waitFor(function()
                return runtime.rounds.match.snapshot().phase == "Active"
            end, "third active round", 35)
            local nextOp, nextGround = roles()
            local nextCharacter = nextGround.Character
            local nextHumanoid = if nextCharacter
                then nextCharacter:FindFirstChildOfClass("Humanoid")
                else nil
            assert(nextHumanoid, "new-round ground life missing")
            local beforeHealth = nextHumanoid.Health
            local beforeAmmo = ammo("GAU23")
            local stale = payload(1, "GAU23", target)
            stale.roundId = previousRound
            probe(nextOp, "Fire", stale)
            task.wait(0.5)
            assert(
                nextHumanoid.Health == beforeHealth and ammo("GAU23") == beforeAmmo,
                "old-round shot mutated new round"
            )
            assert(runtime.combat.resources().projectiles == 0, "old projectile survived round reset")
        end)
        check("A4 both profiles strike real terrain slopes and authored second-story panels", function()
            local op, ground = roles()
            local character = ground.Character
            local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
            assert(root and root:IsA("BasePart"), "third-round ground root missing")
            root.Anchored = true
            root.CFrame = CFrame.new(0, 30, 0)
            local roundId = runtime.rounds.match.snapshot().roundId
            local shotSequence = 0
            local function rayParams(): RaycastParams
                local params = RaycastParams.new()
                params.FilterType = Enum.RaycastFilterType.Include
                params.FilterDescendantsInstances = { workspace.World.Battlefield, workspace.Terrain }
                params.RespectCanCollide = true
                return params
            end
            local function slope(weapon: string): Vector3
                local muzzle = runtime.aircraft.muzzle(weapon)
                assert(muzzle, "slope muzzle missing")
                for _, location in { Vector2.new(-240, -140), Vector2.new(135, 260) } do
                    for dx = -24, 24, 4 do
                        for dz = -24, 24, 4 do
                            local surface = workspace:Raycast(
                                Vector3.new(location.X + dx, 80, location.Y + dz),
                                Vector3.new(0, -100, 0),
                                rayParams()
                            )
                            if
                                surface
                                and surface.Instance == workspace.Terrain
                                and surface.Normal.Y > 0.2
                                and surface.Normal.Y < 0.94
                                and runtime.aircraft.aimAllowed(surface.Position)
                            then
                                local visible = workspace:Raycast(
                                    muzzle,
                                    (surface.Position - muzzle) * 1.001,
                                    rayParams()
                                )
                                if
                                    visible
                                    and visible.Instance == workspace.Terrain
                                    and (visible.Position - surface.Position).Magnitude < 1
                                then
                                    return visible.Position
                                end
                            end
                        end
                    end
                end
                error("no visible authored sloped terrain within aim envelope")
            end
            local function upper(weapon: string): (Vector3, string)
                local muzzle = runtime.aircraft.muzzle(weapon)
                assert(muzzle, "upper-floor muzzle missing")
                for _, building in workspace.World.Battlefield.Buildings:GetChildren() do
                    local panels = building:FindFirstChild(building.Name .. "_Panels")
                    if panels then
                        for _, panel in panels:GetChildren() do
                            if
                                panel:IsA("BasePart")
                                and panel:GetAttribute("StoryId") == "02"
                                and not string.find(panel.Name, "Roof", 1, true)
                            then
                                local visible =
                                    workspace:Raycast(muzzle, panel.Position - muzzle, rayParams())
                                local id = panel:GetAttribute("PanelId")
                                if
                                    visible
                                    and visible.Instance == panel
                                    and type(id) == "string"
                                    and runtime.aircraft.aimAllowed(visible.Position)
                                then
                                    return visible.Position, id
                                end
                            end
                        end
                    end
                end
                error("no visible authored upper-story panel within aim envelope")
            end
            local function fireAndObserve(weapon: string, target: Vector3, panelId: string?)
                shotSequence += 1
                local previous = ReplicatedStorage.AircraftState:GetAttribute("Impact")
                probe(op, "Fire", payload(shotSequence, weapon, target))
                waitFor(function()
                    local value = ReplicatedStorage.AircraftState:GetAttribute("Impact")
                    return type(value) == "string" and value ~= previous
                end, "terrain or upper-floor actual impact", 8)
                local hit = snapshot("Impact")
                assert(
                    hit.weapon == weapon and hit.shotId == shotSequence,
                    "impact identity/profile disagrees"
                )
                if panelId then
                    assert(hit.panelId == panelId, "upper-floor shot hit a different panel")
                end
                local actual = Vector3.new(hit.x :: number, hit.y :: number, hit.z :: number)
                assert((actual - target).Magnitude < 5, "impact missed sampled terrain/panel")
                table.insert(observations, {
                    kind = if panelId then "upper-panel" else "terrain-slope",
                    weapon = weapon,
                    panelId = panelId,
                    target = { target.X, target.Y, target.Z },
                    impact = { actual.X, actual.Y, actual.Z },
                })
            end
            fireAndObserve("GAU23", slope("GAU23"), nil)
            local point, panelId = upper("GAU23")
            fireAndObserve("GAU23", point, panelId)
            probe(op, "Select", { roundId = roundId, sequence = 1, weapon = "M102" })
            waitFor(function()
                return snapshot("Selection").weapon == "M102"
            end, "third-round heavy selected")
            fireAndObserve("M102", slope("M102"), nil)
            waitFor(function()
                return ammo("M102") == 1
            end, "heavy geometry reload", 8)
            point, panelId = upper("M102")
            fireAndObserve("M102", point, panelId)
        end)
    end)
    if not ok then
        table.insert(cases, { name = "Harness completion", passed = false, detail = tostring(failure) })
    end
    fixture:Destroy()
    runtime.stop()
    listener:Disconnect()
    transport:Destroy()
    local passed = 0
    for _, case in cases do
        if case.passed then
            passed += 1
        end
    end
    local report = {
        suite = "P05-multiplayer",
        environment = "Studio",
        clientCount = 2,
        discovered = #cases,
        passed = passed,
        failed = #cases - passed,
        skipped = 0,
        cases = cases,
        observations = observations,
    }
    workspace:SetAttribute("P05MultiplayerReport", HttpService:JSONEncode(report))
    StudioTestService:EndTest(report)
end
return CombatHarness
