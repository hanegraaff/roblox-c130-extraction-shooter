--!strict
--[=[
    P07 manual/SDK harness: two actual clients fire production gunship remotes,
    inspect current panel replication, then hold AFTER damage for a genuinely new
    third player. No fake Players or client-authoritative damage seam. The late-join
    checkpoint is bounded to 240 seconds and published for a coordinated native UI
    join. Fixtures/control transport are test-mapped only; stop owns all resources.
]=]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local StudioTestService = game:GetService("StudioTestService")
local Server = game:GetService("ServerScriptService").Server
local GameRuntime = require(Server.GameRuntime)
local CombatViewRules = require(Server.CombatViewRules)
local MapRules = require(ReplicatedStorage.Shared.MapRules)
local Pan = require(ReplicatedStorage.Shared.AircraftPanRules)
local AircraftRules = require(ReplicatedStorage.Shared.AircraftRules)
local Harness = {}
type Case = { name: string, passed: boolean, detail: string? }
export type Report = {
    suite: string,
    environment: string,
    clientCount: number,
    initialUserIds: { number },
    lateUserId: number?,
    discovered: number,
    passed: number,
    failed: number,
    skipped: number,
    cases: { Case },
    observations: { unknown },
}
local function waitFor(predicate: () -> boolean, label: string, seconds: number?)
    local deadline = os.clock() + (seconds or 15)
    while not predicate() and os.clock() < deadline do
        task.wait(0.03)
    end
    assert(predicate(), "P07 timeout: " .. label)
end
-- Manual finish preserves report in the actual server before the human ends the
-- native session. SDK EndTest is used only for a truly SDK-owned invocation.
function Harness.run(finish: ((Report) -> ())?)
    local cases: { Case } = {}
    local observations: { unknown } = {}
    local initialIds: { number } = {}
    local lateUserId: number? = nil
    local function stage(name: string, detail: unknown?)
        workspace:SetAttribute(
            "P07Stage",
            HttpService:JSONEncode({
                stage = name,
                detail = detail,
                serverTime = workspace:GetServerTimeNow(),
                clientCount = #Players:GetPlayers(),
            })
        )
    end
    local function deliver()
        local passed = 0
        for _, case in cases do
            if case.passed then
                passed += 1
            end
        end
        local report: Report = {
            suite = "P07-multiplayer",
            environment = "Studio",
            clientCount = #Players:GetPlayers(),
            initialUserIds = initialIds,
            lateUserId = lateUserId,
            discovered = #cases,
            passed = passed,
            failed = #cases - passed,
            skipped = 0,
            cases = cases,
            observations = observations,
        }
        workspace:SetAttribute("P07MultiplayerReport", HttpService:JSONEncode(report))
        stage(if report.failed == 0 then "complete" else "failed", report)
        if finish then
            finish(report)
        else
            StudioTestService:EndTest(report)
        end
    end
    local function check(name: string, callback: () -> ())
        stage(name)
        local ok, failure = pcall(function()
            callback()
            return true
        end)
        table.insert(cases, { name = name, passed = ok, detail = if ok then nil else tostring(failure) })
        assert(ok, tostring(failure))
    end
    stage("waiting-for-initial-two-clients")
    local joined, joinFailure = pcall(function()
        waitFor(function()
            return #Players:GetPlayers() == 2
        end, "initial actual two clients", 35)
    end)
    if not joined then
        table.insert(cases, { name = "Harness startup", passed = false, detail = tostring(joinFailure) })
        deliver()
        return
    end
    local initialPlayers = Players:GetPlayers()
    for _, player in initialPlayers do
        table.insert(initialIds, player.UserId)
    end
    local runtime, reason = GameRuntime.start({
        automaticDeployment = false,
        minimumPlayers = 2,
        durationSeconds = 600,
        lobbySeconds = 0,
        deploymentSeconds = 25,
        resultsSeconds = 10,
        seed = 1,
    })
    if not runtime then
        table.insert(cases, { name = "Runtime startup", passed = false, detail = reason })
        deliver()
        return
    end
    local transport = Instance.new("RemoteEvent")
    transport.Name = "P07Harness"
    local ready: { [Player]: boolean } = {}
    local replies: { [number]: { player: Player, ok: boolean, message: string } } = {}
    local token, fireSequence, selectSequence = 0, 0, 0
    local listener = transport.OnServerEvent:Connect(
        function(player: Player, id: unknown, ok: unknown, message: unknown)
            if id == 0 then
                ready[player] = true
            elseif type(id) == "number" then
                replies[id] = { player = player, ok = ok == true, message = tostring(message) }
            end
        end
    )
    transport.Parent = ReplicatedStorage
    local function probe(player: Player, kind: string, payload: unknown)
        waitFor(function()
            return ready[player] == true
        end, "client P07 listener", 25)
        token += 1
        local current = token
        transport:FireClient(player, current, kind, payload)
        waitFor(function()
            return replies[current] ~= nil
        end, "probe reply")
        local reply = replies[current]
        replies[current] = nil
        assert(reply.player == player and reply.ok, reply.message)
    end
    local function command(
        weapon: string,
        point: Vector3,
        sequence: number,
        predictedCamera: Vector3?
    ): { [string]: unknown }?
        local map = MapRules.defaults
        local camera = predictedCamera or runtime.aircraft.position()
        local radial = Vector2.new(camera.X, camera.Z).Unit
        local ground = camera + (point - camera) * (map.altitudeStuds / (camera.Y - point.Y))
        local targetFocus =
            { x = ground.X * radial.X + ground.Z * radial.Y, z = -ground.X * radial.Y + ground.Z * radial.X }
        local home = assert(Pan.recenter(map, 16 / 9, 40), "camera home missing")
        local payload: { [string]: unknown } = {
            roundId = runtime.rounds.match.snapshot().roundId,
            sequence = sequence,
            weapon = weapon,
            x = point.X,
            y = point.Y,
            z = point.Z,
            focusX = home.x,
            focusZ = home.z,
            aspect = 16 / 9,
            cameraX = camera.X,
            cameraZ = camera.Z,
        }
        for sample = 0, 100 do
            local t = sample / 100
            payload.focusX = targetFocus.x + (home.x - targetFocus.x) * t
            payload.focusZ = targetFocus.z + (home.z - targetFocus.z) * t
            if CombatViewRules.validate(payload, map, weapon, camera.X, camera.Z) then
                return payload
            end
        end
        return nil
    end
    local function panel(id: string): Model
        local result = workspace.World.Battlefield:FindFirstChild(id, true)
        assert(result and result:IsA("Model"), "panel unavailable: " .. id)
        return result
    end
    local function pose(id: string): CFrame
        local value = panel(id):GetAttribute("IntactPivot")
        assert(typeof(value) == "CFrame", "panel pivot unavailable")
        return value
    end
    local function expected(ids: { string })
        local result = {}
        for _, id in ids do
            local model = panel(id)
            table.insert(result, {
                id = id,
                stage = model:GetAttribute("PanelState"),
                progress = model:GetAttribute("PanelProgress"),
                parts = #model:GetChildren(),
                pivot = { pose(id):GetComponents() },
            })
        end
        return result
    end
    local function selectWeapon(player: Player, weapon: string)
        selectSequence += 1
        probe(
            player,
            "Select",
            { roundId = runtime.rounds.match.snapshot().roundId, sequence = selectSequence, weapon = weapon }
        )
        waitFor(function()
            return runtime.aircraft.weapon() == weapon
        end, "weapon selection")
    end
    local op: Player? = nil
    local ground: Player? = nil
    local testedIds: { string } = {}
    local latePlayer: Player? = nil
    local checkpoint = false
    local added = Players.PlayerAdded:Connect(function(player)
        if checkpoint and not table.find(initialIds, player.UserId) then
            latePlayer = player
            lateUserId = player.UserId
        end
    end)
    local ok, failure = pcall(function()
        check(
            "A6 two actual clients deploy and reject malformed wrong-role stale flooded fire without cover mutation",
            function()
                assert(runtime.rounds.match.deploy(), "deploy failed")
                waitFor(function()
                    return runtime.rounds.match.snapshot().phase == "Active"
                end, "active round", 35)
                for _, player in initialPlayers do
                    if player:GetAttribute("Role") == "Gunship" then
                        op = player
                    else
                        ground = player
                    end
                end
                assert(op and ground, "roles missing")
                local roofIds: { string } = {}
                for _, item in workspace.World.Battlefield:GetDescendants() do
                    if item:IsA("Model") and string.find(item.Name, "Roof", 1, true) then
                        table.insert(roofIds, item.Name)
                    end
                end
                table.sort(roofIds)
                for _, id in roofIds do
                    local point = pose(id).Position + Vector3.new(-6, 0.5, 0)
                    if command("M102", point, 1) and command("GAU23", point, 1) then
                        table.insert(testedIds, id)
                        if #testedIds == 3 then
                            break
                        end
                    end
                end
                assert(#testedIds == 3, "three reachable roof panels unavailable")
                local point = pose(testedIds[1]).Position
                local bad = assert(command("GAU23", point, 1), "valid view fixture")
                local before = HttpService:JSONEncode(expected(testedIds))
                bad.damage = 9999
                probe(op, "Flood", bad)
                bad.damage = nil
                probe(ground, "Fire", bad)
                bad.roundId = 0
                probe(op, "Fire", bad)
                task.wait(0.5)
                assert(
                    HttpService:JSONEncode(expected(testedIds)) == before,
                    "rejected request altered panels"
                )
                task.wait(1.5)
            end
        )
        assert(op and ground, "active roles missing")
        local operator = op
        check("A7 actual six direct 105mm hits show progress third-hit hole and sixth-hit removal", function()
            selectWeapon(operator, "M102")
            local id = testedIds[1]
            for hit = 1, 6 do
                if hit > 1 then
                    task.wait(4.05)
                end
                fireSequence += 1
                local point = pose(id).Position + Vector3.new(-6, 0.5, 0)
                probe(
                    operator,
                    "Fire",
                    (assert(command("M102", point, fireSequence), "heavy target left view"))
                )
                local expectedStage = if hit < 3 then "Intact" elseif hit < 6 then "Damaged" else "Destroyed"
                local expectedProgress = if hit == 6 then 1 else (hit % 3) / 3
                waitFor(function()
                    return panel(id):GetAttribute("PanelState") == expectedStage
                        and math.abs(
                                (panel(id):GetAttribute("PanelProgress") :: number) - expectedProgress
                            )
                            < 1e-5
                end, "heavy hit " .. hit, 8)
                table.insert(observations, {
                    kind = "actual-heavy",
                    hit = hit,
                    panelId = id,
                    stage = expectedStage,
                    progress = expectedProgress,
                })
                for _, player in initialPlayers do
                    probe(player, "Panels", expected({ id }))
                end
            end
        end)
        check("A7 actual same-panel 30mm reaches nine valid seconds without first-hit time credit", function()
            selectWeapon(operator, "GAU23")
            local id = testedIds[2]
            local firstFire = workspace:GetServerTimeNow()
            local epoch = ReplicatedStorage.AircraftState:GetAttribute("EpochSeconds")
            assert(type(epoch) == "number", "canonical orbit epoch missing")
            local commands: { { [string]: unknown } } = {}
            for impact = 1, 61 do
                local predicted = assert(
                    AircraftRules.pose(
                        MapRules.defaults,
                        AircraftRules.defaults,
                        firstFire - epoch + (impact - 1) * 0.151
                    ),
                    "predicted orbit unavailable"
                )
                fireSequence += 1
                local point = pose(id).Position + Vector3.new(-6, 0.5, 0)
                local payload = assert(
                    command("GAU23", point, fireSequence, Vector3.new(predicted.x, predicted.y, predicted.z)),
                    "sustained target leaves permitted view"
                )
                table.insert(commands, payload)
            end
            -- One bounded client burst avoids a per-shot server/client RPC wait
            -- becoming an artificial interruption of otherwise valid cadence.
            probe(operator, "Burst", { commands = commands, cadence = 0.151 })
            waitFor(function()
                return panel(id):GetAttribute("PanelState") == "Damaged"
            end, "nine seconds of actual 30mm", 8)
            assert(workspace:GetServerTimeNow() - firstFire >= 9, "nine-second threshold early")
            for _, player in initialPlayers do
                probe(player, "Panels", expected({ id }))
            end
            table.insert(observations, {
                kind = "actual-30mm",
                panelId = id,
                elapsedSeconds = workspace:GetServerTimeNow() - firstFire,
                final = expected({ id }),
            })
        end)
        check("A3 actual ground Humanoid walks through an authored damaged wall opening", function()
            selectWeapon(operator, "M102")
            -- A fresh wall is selected by an actual muzzle ray, not by accepting
            -- a client panel ID. Primitive roofs/terrain may protect other walls.
            local wallId: string? = nil
            local wallPoint = Vector3.zero
            local normal = Vector3.zero
            local muzzle = runtime.aircraft.muzzle("M102")
            assert(muzzle, "heavy muzzle missing")
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Include
            params.FilterDescendantsInstances = { workspace.World.Battlefield, workspace.Terrain }
            params.RespectCanCollide = true
            for _, item in workspace.World.Battlefield:GetDescendants() do
                if
                    item:IsA("Model")
                    and item:GetAttribute("PanelState") == "Intact"
                    and item:GetAttribute("PanelId")
                    and not string.find(item.Name, "Roof", 1, true)
                    and string.find(item.Name, "_S01_", 1, true)
                    and not string.find(item.Name, "Interior", 1, true)
                then
                    local solid = item:FindFirstChild("Solid")
                    if solid and solid:IsA("BasePart") then
                        local axis = if solid.Size.X < 2 then Vector3.xAxis else Vector3.zAxis
                        local outward = axis * (if (muzzle - solid.Position):Dot(axis) > 0 then 1 else -1)
                        local target = solid.Position + outward * 0.5
                        local hit = workspace:Raycast(
                            muzzle,
                            (target - muzzle).Unit * ((target - muzzle).Magnitude + 0.2),
                            params
                        )
                        if hit and hit.Instance == solid and command("M102", target, fireSequence + 1) then
                            wallId, wallPoint, normal = item.Name, target, outward
                            break
                        end
                    end
                end
            end
            assert(wallId, "no exposed reachable ground-story wall")
            for hit = 1, 3 do
                task.wait(4.05)
                fireSequence += 1
                local payload = assert(command("M102", wallPoint, fireSequence), "wall left permitted view")
                probe(operator, "Fire", payload)
                waitFor(function()
                    return panel(wallId :: string):GetAttribute("PanelState")
                            == (if hit == 3 then "Damaged" else "Intact")
                        and panel(wallId :: string):GetAttribute("PanelProgress") :: number
                            == (if hit == 3 then 0 else hit / 3)
                end, "wall heavy progress")
            end
            local groundPlayer = ground
            assert(groundPlayer and groundPlayer.Character, "actual Ground character missing")
            local character = groundPlayer.Character
            local root = character:FindFirstChild("HumanoidRootPart")
            assert(root and root:IsA("BasePart"), "Ground root missing")
            local original = character:GetPivot()
            local groundY = wallPoint.Y - 1
            local start = Vector3.new(wallPoint.X, groundY, wallPoint.Z) + normal * 6
            local goal = Vector3.new(wallPoint.X, groundY, wallPoint.Z) - normal * 6
            character:PivotTo(CFrame.new(start))
            root.AssemblyLinearVelocity = Vector3.zero
            local walked, walkFailure = pcall(function()
                probe(groundPlayer, "Walk", goal)
                assert((root.Position - goal).Magnitude < 2, "server did not observe traversal")
                return true
            end)
            character:PivotTo(original)
            root.AssemblyLinearVelocity = Vector3.zero
            assert(walked, tostring(walkFailure))
            table.insert(
                observations,
                { kind = "actual-humanoid-opening", panelId = wallId, userId = groundPlayer.UserId }
            )
        end)
        check(
            "A6 current state reaches both initial clients and prior fragments expire before late join",
            function()
                -- One real heavy impact leaves a separate accumulating panel.
                selectWeapon(operator, "M102")
                fireSequence += 1
                local id = testedIds[3]
                probe(
                    operator,
                    "Fire",
                    (
                        assert(
                            command("M102", pose(id).Position + Vector3.new(-6, 0.5, 0), fireSequence),
                            "accumulating panel target"
                        )
                    )
                )
                waitFor(function()
                    return panel(id):GetAttribute("PanelProgress") == 1 / 3
                end, "accumulating panel")
                task.wait(8.2)
                assert(runtime.destruction.resources().fragments == 0, "prior debris still live")
                for _, player in initialPlayers do
                    probe(player, "Panels", expected(testedIds))
                    probe(player, "NoFragments", nil)
                end
            end
        )
        check(
            "A6 genuinely late third client spectates current round and reconstructs without prior debris",
            function()
                checkpoint = true
                local checkpointRound = runtime.rounds.match.snapshot().roundId
                stage("AwaitingLateJoin", {
                    initialUserIds = initialIds,
                    roundId = checkpointRound,
                    timeoutSeconds = 240,
                    panels = expected(testedIds),
                    instruction = "Add one actual client to this existing native Server & Clients session",
                })
                waitFor(function()
                    return latePlayer ~= nil
                end, "actual new third PlayerAdded AFTER checkpoint", 240)
                checkpoint = false
                local spectator = latePlayer
                assert(spectator and #Players:GetPlayers() == 3, "actual third player absent")
                assert(
                    runtime.rounds.match.snapshot().roundId == checkpointRound
                        and runtime.rounds.match.snapshot().phase == "Active",
                    "late join crossed round"
                )
                probe(spectator, "Spectator", nil)
                for _, player in Players:GetPlayers() do
                    probe(player, "Panels", expected(testedIds))
                    probe(player, "NoFragments", nil)
                end
                local intent = assert(command("M102", pose(testedIds[3]).Position, 9999), "spectator target")
                local before = HttpService:JSONEncode(expected(testedIds))
                probe(spectator, "Flood", intent)
                task.wait(0.3)
                assert(HttpService:JSONEncode(expected(testedIds)) == before, "spectator altered cover")
            end
        )
        check("A6 reset during fragmentation and pending work restores panels through two rounds", function()
            for iteration = 1, 2 do
                local currentOperator: Player? = nil
                for _, player in Players:GetPlayers() do
                    if player:GetAttribute("Role") == "Gunship" then
                        currentOperator = player
                    end
                end
                assert(currentOperator, "reset fixture has no active operator")
                selectWeapon(currentOperator, "M102")
                local freshId: string? = nil
                for _, item in workspace.World.Battlefield:GetDescendants() do
                    if
                        item:IsA("Model")
                        and string.find(item.Name, "Roof", 1, true)
                        and item:GetAttribute("PanelState") == "Intact"
                        and item:GetAttribute("PanelProgress") == 0
                    then
                        local point = pose(item.Name).Position + Vector3.new(-6, 0.5, 0)
                        if
                            command("M102", point, fireSequence + 1)
                            and command("GAU23", point, fireSequence + 1)
                        then
                            freshId = item.Name
                            break
                        end
                    end
                end
                assert(freshId, "fresh reachable reset panel unavailable")
                local targetId = freshId
                for hit = 1, 3 do
                    task.wait(4.05)
                    fireSequence += 1
                    local payload = assert(
                        command("M102", pose(targetId).Position + Vector3.new(-6, 0.5, 0), fireSequence),
                        "reset panel left view"
                    )
                    probe(currentOperator, "Fire", payload)
                    waitFor(function()
                        return panel(targetId):GetAttribute("PanelState")
                                == (if hit == 3 then "Damaged" else "Intact")
                            and panel(targetId):GetAttribute("PanelProgress") :: number
                                == (if hit == 3 then 0 else hit / 3)
                    end, "reset heavy progress")
                end
                assert(runtime.destruction.resources().fragments > 0, "reset did not overlap live fragments")
                selectWeapon(currentOperator, "GAU23")
                fireSequence += 1
                local pending = assert(
                    command("GAU23", pose(targetId).Position + Vector3.new(-6, 0.5, 0), fireSequence),
                    "reset pending target"
                )
                probe(currentOperator, "Fire", pending)
                assert(
                    runtime.combat.resources().projectiles > 0,
                    "reset did not overlap actual in-flight shot"
                )
                local staleRound = runtime.rounds.match.snapshot().roundId
                runtime.rounds.match.abort(runtime.rounds.match.snapshot().roundId, "P07 reset fixture")
                assert(runtime.rounds.match.beginReset(), "reset start")
                waitFor(function()
                    return runtime.rounds.match.snapshot().phase == "Lobby"
                end, "reset lobby")
                waitFor(function()
                    return panel(testedIds[1]):GetAttribute("PanelState") == "Intact"
                end, "pristine panels")
                assert(not runtime.destruction.resolve({
                    roundId = staleRound,
                    shotId = 1,
                    weapon = "M102",
                    firedAt = workspace:GetServerTimeNow(),
                    panelId = targetId,
                }), "stale pre-reset outcome accepted")
                assert(
                    runtime.destruction.resources().fragments == 0
                        and runtime.destruction.resources().pending == 0,
                    "reset work leaked"
                )
                for _, player in Players:GetPlayers() do
                    probe(player, "Panels", expected(testedIds))
                    probe(player, "NoFragments", nil)
                end
                if iteration == 1 then
                    assert(runtime.rounds.match.deploy(), "second deployment")
                    waitFor(function()
                        return runtime.rounds.match.snapshot().phase == "Active"
                    end, "second active", 35)
                end
            end
        end)
    end)
    if not ok and (#cases == 0 or cases[#cases].passed) then
        table.insert(cases, { name = "Harness completion", passed = false, detail = tostring(failure) })
    end
    checkpoint = false
    added:Disconnect()
    listener:Disconnect()
    transport:Destroy()
    runtime.stop()
    deliver()
end
return Harness
