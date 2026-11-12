--!strict
-- Test-only P06 real-client harness: owned match, M-7, cover, damage and reset.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local StudioTestService = game:GetService("StudioTestService")
local GameRuntime = require(game:GetService("ServerScriptService").Server.GameRuntime)
local Harness = {}
type Case = { name: string, passed: boolean, detail: string? }
local function waitFor(predicate: () -> boolean, label: string, seconds: number?)
    local deadline = os.clock() + (seconds or 15)
    while not predicate() and os.clock() < deadline do
        task.wait(0.03)
    end
    assert(predicate(), "P06 timeout: " .. label)
end
function Harness.run(expectedClients: number?)
    local expected = expectedClients or 2
    waitFor(function()
        return #Players:GetPlayers() == expected
    end, "actual clients", 35)
    local runtime, reason = GameRuntime.start({
        automaticDeployment = false,
        minimumPlayers = 2,
        durationSeconds = 120,
        lobbySeconds = 0,
        deploymentSeconds = 25,
        resultsSeconds = 5,
        seed = 1,
    })
    assert(runtime, reason)
    local transport = Instance.new("RemoteEvent")
    transport.Name = "P06Harness"
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
    local function roles(): (Player, Player)
        local operator: Player? = nil
        local ground: Player? = nil
        for _, player in Players:GetPlayers() do
            if player:GetAttribute("Role") == "Gunship" then
                operator = player
            end
            if player:GetAttribute("Role") == "Ground" then
                ground = player
            end
        end
        assert(operator and ground, "roles missing")
        return operator, ground
    end
    local function health(): number
        local state = ReplicatedStorage:FindFirstChild("AircraftState")
        local value = if state then state:GetAttribute("Health") else nil
        assert(type(value) == "number", "health missing")
        return value
    end
    local function hitbox(): BasePart
        local model = workspace:FindFirstChild("Aircraft")
        local part = if model then model:FindFirstChild("Hitbox") else nil
        assert(part and part:IsA("BasePart"), "aircraft hitbox missing")
        return part
    end
    local fixture = Instance.new("Folder")
    fixture.Name = "P06Fixture"
    fixture.Parent = workspace.World.Battlefield
    local cases: { Case } = {}
    local function check(name: string, callback: () -> ())
        local ok, failure = pcall(function()
            callback()
            return true
        end)
        table.insert(cases, { name = name, passed = ok, detail = if ok then nil else tostring(failure) })
        assert(ok, tostring(failure))
    end
    local ok, failure = pcall(function()
        check("A1 ground receives one rifle and no launcher", function()
            assert(runtime.rounds.match.deploy(), "deployment failed")
            waitFor(function()
                return runtime.rounds.match.snapshot().phase == "Active"
            end, "active", 40)
            local op, ground = roles()
            waitFor(function()
                local bag = ground:FindFirstChildOfClass("Backpack")
                return bag ~= nil and bag:FindFirstChild("M-7 rifle") ~= nil
            end, "rifle loadout")
            for _, player in Players:GetPlayers() do
                if player:GetAttribute("Role") == "Ground" then
                    local bag = assert(player:FindFirstChildOfClass("Backpack"), "backpack missing")
                    waitFor(function()
                        return bag:FindFirstChild("M-7 rifle") ~= nil
                    end, "ground rifle")
                    assert(
                        #bag:GetChildren() == 1 and bag:FindFirstChild("M-7 rifle"),
                        "unexpected ground loadout"
                    )
                end
            end
            local operatorBag = op:FindFirstChildOfClass("Backpack")
            assert(not operatorBag or not operatorBag:FindFirstChild("M-7 rifle"), "operator received rifle")
            assert(health() == 300, "aircraft health not full")
            probe(op, "Observe", 300)
            probe(ground, "Observe", 300)
        end)
        check("A3 forged and wrong-role requests cannot mutate health or ammo", function()
            local op, ground = roles()
            local bag = assert(ground:FindFirstChildOfClass("Backpack"), "backpack missing")
            local tool = bag:FindFirstChild("M-7 rifle")
            assert(tool and tool:IsA("Tool"), "rifle missing")
            local humanoid = if ground.Character
                then ground.Character:FindFirstChildOfClass("Humanoid")
                else nil
            assert(humanoid, "ground humanoid missing")
            humanoid:EquipTool(tool)
            local roundId = runtime.rounds.match.snapshot().roundId
            local target = hitbox().Position
            local forged = {
                roundId = roundId,
                sequence = 1,
                weapon = "M7",
                x = target.X,
                y = target.Y,
                z = target.Z,
                damage = 9999,
            }
            probe(ground, "Fire", forged)
            local valid =
                { roundId = roundId, sequence = 1, weapon = "M7", x = target.X, y = target.Y, z = target.Z }
            probe(op, "Fire", valid)
            probe(ground, "Fire", {
                roundId = roundId - 1,
                sequence = 1,
                weapon = "M7",
                x = target.X,
                y = target.Y,
                z = target.Z,
            })
            probe(
                ground,
                "Fire",
                { roundId = roundId, sequence = 1, weapon = "M7", x = math.huge, y = target.Y, z = target.Z }
            )
            probe(ground, "Flood", forged)
            task.wait(2)
            assert(health() == 300 and tool:GetAttribute("Ammo") == 30, "forged fire mutated state")
        end)
        check("A1 server raycast stops rifle at cover then damages aircraft", function()
            local op, ground = roles()
            local character = ground.Character
            local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
            local tool = if character then character:FindFirstChild("M-7 rifle") else nil
            assert(root and root:IsA("BasePart") and tool and tool:IsA("Tool"), "equipped ground missing")
            root.Anchored = true
            root.CFrame = CFrame.new(hitbox().Position - Vector3.new(0, 25, 0))
            task.wait(0.15)
            local head = character and character:FindFirstChild("Head")
            assert(head and head:IsA("BasePart"), "ground head missing")
            local embedded = Instance.new("Part")
            embedded.Name = "P06EmbeddedCover"
            embedded.Anchored = true
            embedded.Size = Vector3.new(8, 8, 8)
            embedded.Position = head.Position
            embedded.Parent = fixture
            local roundId = runtime.rounds.match.snapshot().roundId
            local target = hitbox().Position
            probe(
                ground,
                "Fire",
                { roundId = roundId, sequence = 1, weapon = "M7", x = target.X, y = target.Y, z = target.Z }
            )
            task.wait(0.3)
            assert(health() == 300 and tool:GetAttribute("Ammo") == 30, "embedded cover allowed fire")
            embedded:Destroy()
            local wall = Instance.new("Part")
            wall.Name = "P06Cover"
            wall.Anchored = true
            wall.Size = Vector3.new(120, 1, 120)
            wall.Position = hitbox().Position - Vector3.new(0, 12, 0)
            wall.Parent = fixture
            target = hitbox().Position
            probe(
                ground,
                "Fire",
                { roundId = roundId, sequence = 1, weapon = "M7", x = target.X, y = target.Y, z = target.Z }
            )
            waitFor(function()
                return tool:GetAttribute("Ammo") == 29
            end, "blocked shot")
            assert(health() == 300, "cover failed to block damage")
            wall:Destroy()
            task.wait(0.2)
            local teammateHumanoid: Humanoid? = nil
            local teammateModel: Model? = nil
            if expected >= 3 then
                for _, player in Players:GetPlayers() do
                    if player ~= ground and player:GetAttribute("Role") == "Ground" then
                        local teammateCharacter = player.Character
                        teammateModel = teammateCharacter
                        local teammateRoot = if teammateCharacter
                            then teammateCharacter:FindFirstChild("HumanoidRootPart")
                            else nil
                        teammateHumanoid = if teammateCharacter
                            then teammateCharacter:FindFirstChildOfClass("Humanoid")
                            else nil
                        assert(
                            teammateRoot and teammateRoot:IsA("BasePart") and teammateHumanoid,
                            "teammate fixture missing"
                        )
                        teammateRoot.Anchored = true
                        teammateRoot.CFrame = CFrame.new(head.Position:Lerp(hitbox().Position, 0.55))
                    end
                end
                assert(teammateHumanoid, "teammate missing")
                task.wait(0.1)
            end
            local teammateHealth = if teammateHumanoid then teammateHumanoid.Health else 0
            target = hitbox().Position
            if teammateModel then
                local filter = RaycastParams.new()
                filter.FilterType = Enum.RaycastFilterType.Include
                filter.FilterDescendantsInstances = { teammateModel }
                assert(
                    workspace:Raycast(head.Position, target - head.Position, filter),
                    "rifle path did not cross teammate"
                )
            end
            probe(
                ground,
                "Fire",
                { roundId = roundId, sequence = 2, weapon = "M7", x = target.X, y = target.Y, z = target.Z }
            )
            waitFor(function()
                return health() == 295
            end, "real rifle hit aircraft", 8)
            if teammateHumanoid then
                assert(teammateHumanoid.Health == teammateHealth, "rifle damaged a ground teammate")
            end
            probe(op, "Observe", { health = 295, shotSequence = 2 })
            probe(ground, "Observe", { health = 295, shotSequence = 2 })
        end)
        check("A2 direct swept rocket fixtures destroy once", function()
            local roundId = runtime.rounds.match.snapshot().roundId
            local _, activeGround = roles()
            local eliminated: Player? = nil
            if expected >= 3 then
                for _, player in Players:GetPlayers() do
                    if player ~= activeGround and player:GetAttribute("Role") == "Ground" then
                        eliminated = player
                    end
                end
                assert(eliminated, "second ground player missing")
                assert(
                    runtime.rounds.match.eliminate(eliminated.UserId, roundId),
                    "teammate elimination failed"
                )
                waitFor(function()
                    return eliminated:GetAttribute("Life") == "Eliminated"
                end, "teammate eliminated")
                assert(runtime.rounds.match.snapshot().phase == "Active", "round ended while teammate alive")
                local target = hitbox().Position
                probe(eliminated, "Fire", {
                    roundId = roundId,
                    sequence = 100,
                    weapon = "M7",
                    x = target.X,
                    y = target.Y,
                    z = target.Z,
                })
                task.wait(0.2)
                assert(health() == 295, "eliminated player damaged aircraft")
            end
            assert(not runtime.groundCombat.rocketImpact(roundId, "miss", false), "near miss caused damage")
            assert(health() == 295, "near miss altered health")
            for n = 1, 3 do
                local part = hitbox()
                local origin = part.Position + Vector3.new(0, 25, 0)
                assert(
                    runtime.groundCombat.rocketSweep(roundId, "rocket" .. n, origin, Vector3.new(0, -50, 0)),
                    "swept rocket missed aircraft"
                )
                if n < 3 then
                    assert(health() == 295 - n * 100, "incorrect rocket damage")
                end
                if n == 1 then
                    assert(
                        not runtime.groundCombat.rocketSweep(
                            roundId,
                            "rocket1",
                            origin,
                            Vector3.new(0, -50, 0)
                        ),
                        "duplicate hit accepted"
                    )
                end
            end
            assert(health() == 0, "health did not clamp")
            waitFor(function()
                return runtime.rounds.match.snapshot().phase == "Results"
            end, "ground victory")
            local result = runtime.rounds.match.snapshot().result
            assert(result and result.winner == "Ground", "wrong winner")
            if eliminated then
                assert(
                    runtime.rounds.match.snapshot().members[eliminated.UserId].life == "Eliminated",
                    "eliminated teammate lost team result"
                )
                probe(eliminated, "Observe", { health = 0, destroyed = true, winner = "Ground" })
            end
            assert(not runtime.groundCombat.rocketImpact(roundId, "late", true), "terminal hit accepted")
            local op, ground = roles()
            probe(op, "Observe", { health = 0, destroyed = true, winner = "Ground" })
            probe(ground, "Observe", { health = 0, destroyed = true, winner = "Ground" })
        end)
        check("A5 reset restores aircraft and no stale equipment", function()
            waitFor(function()
                return runtime.rounds.match.snapshot().phase == "Lobby"
            end, "lobby reset", 25)
            waitFor(function()
                return health() == 300
            end, "pristine health")
            assert(runtime.groundCombat.resources().tools == 0, "rifle leaked into lobby")
            assert(runtime.rounds.match.deploy(), "second deployment failed")
            waitFor(function()
                return runtime.rounds.match.snapshot().phase == "Active"
            end, "new active round", 40)
            local _, ground = roles()
            waitFor(function()
                local bag = ground:FindFirstChildOfClass("Backpack")
                local tool = if bag then bag:FindFirstChild("M-7 rifle") else nil
                return tool ~= nil and tool:GetAttribute("Ammo") == 30
            end, "fresh rifle")
            assert(health() == 300, "fresh round not pristine")
        end)
        if expected == 2 then
            check(
                "A4 last ground elimination then aircraft destruction share one simulation batch",
                function()
                    local _, ground = roles()
                    local roundId = runtime.rounds.match.snapshot().roundId
                    assert(
                        runtime.rounds.match.eliminate(ground.UserId, roundId),
                        "last ground elimination rejected"
                    )
                    for n = 1, 3 do
                        assert(
                            runtime.groundCombat.rocketImpact(roundId, "batchA" .. n, true),
                            "batch rocket rejected"
                        )
                    end
                    waitFor(function()
                        return runtime.rounds.match.snapshot().phase == "Results"
                    end, "batched result")
                    local result = runtime.rounds.match.snapshot().result
                    assert(result and result.winner == "Ground", "last-ground-first batch chose wrong winner")
                end
            )
            check(
                "A4 aircraft destruction then last ground elimination share one simulation batch",
                function()
                    waitFor(function()
                        return runtime.rounds.match.snapshot().phase == "Lobby"
                    end, "batch lobby", 25)
                    assert(runtime.rounds.match.deploy(), "batch deployment failed")
                    waitFor(function()
                        return runtime.rounds.match.snapshot().phase == "Active"
                    end, "batch active", 40)
                    local _, ground = roles()
                    local roundId = runtime.rounds.match.snapshot().roundId
                    waitFor(function()
                        return health() == 300
                    end, "batch pristine health")
                    for n = 1, 3 do
                        assert(
                            runtime.groundCombat.rocketImpact(roundId, "batchB" .. n, true),
                            "batch rocket rejected"
                        )
                    end
                    assert(
                        runtime.rounds.match.eliminate(ground.UserId, roundId),
                        "last ground elimination rejected"
                    )
                    waitFor(function()
                        return runtime.rounds.match.snapshot().phase == "Results"
                    end, "batched result")
                    local result = runtime.rounds.match.snapshot().result
                    assert(result and result.winner == "Ground", "aircraft-first batch chose wrong winner")
                end
            )
        end
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
        suite = "P06-multiplayer",
        environment = "Studio",
        clientCount = expected,
        discovered = #cases,
        passed = passed,
        failed = #cases - passed,
        skipped = 0,
        cases = cases,
    }
    workspace:SetAttribute("P06MultiplayerReport", HttpService:JSONEncode(report))
    StudioTestService:EndTest(report)
end
return Harness
