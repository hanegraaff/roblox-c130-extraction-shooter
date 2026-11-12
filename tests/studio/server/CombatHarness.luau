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
            task.wait(0.5)
            assert(HttpService:JSONEncode(snapshot("Readiness")) == before, "rejected fire spent ammunition")
            probe(op, "Observe", nil)
            probe(ground, "Observe", nil)
        end)
        check("A4 swept muzzle path hits thin cover before the visible target", function()
            local op, ground = roles()
            local character = ground.Character
            local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
            local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
            assert(root and root:IsA("BasePart") and humanoid, "ground character missing")
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
        end)
        check("A2 switching preserves heavy reload and A5 lethal hit ends once", function()
            local op, ground = roles()
            local character = ground.Character
            local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
            local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
            assert(root and root:IsA("BasePart") and humanoid, "ground character missing")
            local roundId = runtime.rounds.match.snapshot().roundId
            probe(op, "Select", { roundId = roundId, sequence = 1, weapon = "M102" })
            waitFor(function()
                return snapshot("Selection").weapon == "M102"
            end, "heavy selected")
            local muzzle = runtime.aircraft.muzzle("M102")
            assert(muzzle, "heavy muzzle missing")
            local wall = Instance.new("Part")
            wall.Name = "HeavyCover"
            wall.Anchored = true
            wall.Size = Vector3.new(50, 50, 0.2)
            wall.CFrame = CFrame.lookAt(muzzle:Lerp(root.Position, 0.6), root.Position)
            wall.Parent = fixture
            probe(op, "Fire", payload(3, "M102", root.Position))
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
            probe(op, "Fire", payload(4, "M102", root.Position))
            waitFor(function()
                return runtime.rounds.match.snapshot().phase == "Results"
            end, "elimination result", 8)
            local result = runtime.rounds.match.snapshot().result
            assert(result and result.winner == "Gunship", "ground elimination did not award gunship")
            assert(humanoid.Health <= 0, "lethal heavy hit did not eliminate ground")
            probe(op, "Observe", nil)
            probe(ground, "Observe", nil)
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
    }
    workspace:SetAttribute("P05MultiplayerReport", HttpService:JSONEncode(report))
    StudioTestService:EndTest(report)
end
return CombatHarness
