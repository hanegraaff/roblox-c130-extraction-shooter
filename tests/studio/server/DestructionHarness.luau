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
local CombatRuntime = require(Server.CombatRuntime)
local CombatService = require(Server.CombatService)
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
    -- Observe the existing production impact seam on a fresh owner BEFORE any
    -- deployment/fire. This records actual accepted firedAt values and rule
    -- snapshots without authorizing a hit or changing production source.
    local impactFacts: {
        {
            shotId: number,
            weapon: string,
            panelId: string?,
            firedAt: number,
            impactAt: number,
            scoredThroughShotId: number,
            scoredThroughFiredAt: number?,
            stage: number?,
            progress: number?,
        }
    } =
        {}
    local receipts: {
        {
            sequence: number?,
            receivedAt: number,
            viewValid: boolean,
            viewReason: string?,
            gauAmmo: number?,
            gauNextFire: number?,
        }
    } =
        {}
    local resolvedTimes: { [number]: number } = {}
    local observedRound, contiguousShotId = -1, 0
    runtime.combat.stop()
    local observedCombat, observerReason = CombatRuntime.start(
        runtime.rounds.match,
        runtime.aircraft,
        function(impact)
            if #impactFacts >= 192 then
                return
            end
            if impact.roundId ~= observedRound then
                observedRound, contiguousShotId = impact.roundId, 0
                table.clear(resolvedTimes)
            end
            resolvedTimes[impact.shotId] = impact.firedAt
            while resolvedTimes[contiguousShotId + 1] do
                contiguousShotId += 1
            end
            local current = if impact.panelId then runtime.destruction.snapshot(impact.panelId) else nil
            table.insert(impactFacts, {
                shotId = impact.shotId,
                weapon = impact.weapon,
                panelId = impact.panelId,
                firedAt = impact.firedAt,
                impactAt = impact.time,
                scoredThroughShotId = contiguousShotId,
                scoredThroughFiredAt = resolvedTimes[contiguousShotId],
                stage = if current then current.stage else nil,
                progress = if current then current.progress else nil,
            })
        end,
        nil,
        nil,
        runtime.destruction
    )
    if not observedCombat then
        runtime.stop()
        table.insert(cases, { name = "Impact observer startup", passed = false, detail = observerReason })
        deliver()
        return
    end
    runtime.combat = observedCombat
    local fireRemote = ReplicatedStorage.AircraftState:FindFirstChild("FireWeapon")
    assert(fireRemote and fireRemote:IsA("RemoteEvent"), "observed production remote unavailable")
    local receiptListener = fireRemote.OnServerEvent:Connect(function(player: Player, payload: unknown)
        if #receipts >= 192 then
            return
        end
        local camera = runtime.aircraft.position()
        local selected = runtime.aircraft.weapon()
        local valid, why = CombatViewRules.validate(payload, MapRules.defaults, selected, camera.X, camera.Z)
        local fields: { [string]: unknown } = if type(payload) == "table"
            then payload :: { [string]: unknown }
            else {}
        local sequence = fields.sequence
        local readiness = ReplicatedStorage.AircraftState:GetAttribute("Readiness")
        local profile = if type(readiness) == "string" then HttpService:JSONDecode(readiness).GAU23 else nil
        table.insert(receipts, {
            sequence = if type(sequence) == "number"
                    and sequence == sequence
                    and math.abs(sequence) < math.huge
                then sequence
                else nil,
            receivedAt = workspace:GetServerTimeNow(),
            viewValid = valid ~= nil and player:GetAttribute("Role") == "Gunship",
            viewReason = why,
            gauAmmo = if profile then profile.ammo else nil,
            gauNextFire = if profile then profile.nextFire else nil,
        })
    end)
    local burstTiming: { [number]: unknown } = {}
    local transport = Instance.new("RemoteEvent")
    transport.Name = "P07Harness"
    local ready: { [Player]: boolean } = {}
    local replies: { [number]: { player: Player, ok: boolean, message: string } } = {}
    local token, fireSequence, selectSequence = 0, 0, 0
    local listener = transport.OnServerEvent:Connect(
        function(player: Player, id: unknown, ok: unknown, message: unknown)
            if id == 0 then
                ready[player] = true
            elseif type(id) == "number" and ok == "BurstTiming" and type(message) == "table" then
                burstTiming[id] = message
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
        return current
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
    -- Read current authoritative readiness; fixture setup cannot bypass the
    -- M102 reload merely because a prior movement/probe happened to be fast.
    local function awaitReady(weapon: string)
        waitFor(function()
            local encoded = ReplicatedStorage.AircraftState:GetAttribute("Readiness")
            if type(encoded) ~= "string" then
                return false
            end
            local decoded = HttpService:JSONDecode(encoded)
            local profile = decoded[weapon]
            local now = workspace:GetServerTimeNow()
            return profile ~= nil
                and profile.ammo > 0
                and profile.reloadUntil == 0
                and now + 1e-9 >= profile.nextFire
        end, "authoritative " .. weapon .. " readiness", 8)
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
    -- Three ready M102 launches need two 4s reloads plus at most 4s final
    -- flight. A 4s fixture scheduling margin makes a 16s observation window;
    -- no extra blind waits inflate that budget. Forecasts only choose a fixture:
    -- every actual shot still needs a fresh real first-hit and view guard.
    local wallWindowSeconds = 2 * CombatService.profiles.M102.reload
        + CombatService.profiles.M102.lifetime
        + 4
    local function aimHit(
        weapon: string,
        point: Vector3,
        muzzle: Vector3,
        params: RaycastParams
    ): RaycastResult?
        local delta = point - muzzle
        return CombatRuntime.sweep(
            muzzle,
            CombatService.profiles[weapon].collisionRadius,
            delta.Unit * math.min(delta.Magnitude + 0.25, CombatService.profiles[weapon].range),
            params
        )
    end
    local function stableExteriorWall(): (string, Vector3, Vector3)
        awaitReady("M102")
        local actualMuzzle = assert(runtime.aircraft.muzzle("M102"), "heavy muzzle unavailable")
        local relativeMuzzle = workspace.Aircraft:GetPivot():PointToObjectSpace(actualMuzzle)
        local epoch = ReplicatedStorage.AircraftState:GetAttribute("EpochSeconds")
        assert(type(epoch) == "number", "wall forecast epoch unavailable")
        local startedAt = workspace:GetServerTimeNow()
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Include
        params.FilterDescendantsInstances = { workspace.World.Battlefield, workspace.Terrain }
        params.RespectCanCollide = true
        local selected: string? = nil
        local selectedPoint = Vector3.zero
        local selectedNormal = Vector3.zero
        local bestExposure = -math.huge
        for _, building in workspace.World.Battlefield.Buildings:GetChildren() do
            local supports = building:FindFirstChild(building.Name .. "_Static")
            local floor = if supports then supports:FindFirstChild(building.Name .. "_GroundFloor") else nil
            local registry = building:FindFirstChild(building.Name .. "_Panels")
            assert(floor and floor:IsA("BasePart") and registry, "wall building contract unavailable")
            for _, model in registry:GetChildren() do
                if
                    model:IsA("Model")
                    and model:GetAttribute("PanelState") == "Intact"
                    and model:GetAttribute("StoryId") == "01"
                    and not string.find(model.Name, "Interior", 1, true)
                    and not string.find(model.Name, "Roof", 1, true)
                then
                    local solid = model:FindFirstChild("Solid")
                    if solid and solid:IsA("BasePart") then
                        local axis = solid.CFrame:VectorToWorldSpace(
                            if solid.Size.X < solid.Size.Z then Vector3.xAxis else Vector3.zAxis
                        )
                        -- The building floor determines true exterior. Choosing
                        -- the side facing today's camera can select an interior
                        -- sight line temporarily admitted by an earlier roof hole.
                        local normal = axis
                            * (if (solid.Position - floor.Position):Dot(axis) > 0 then 1 else -1)
                        local point = solid.Position + normal * math.min(solid.Size.X, solid.Size.Z) / 2
                        local exposure = 1
                        local clear = true
                        for step = 0, math.ceil(wallWindowSeconds / 0.5) do
                            local offset = step * 0.5
                            local poseValue = assert(
                                AircraftRules.pose(
                                    MapRules.defaults,
                                    AircraftRules.defaults,
                                    startedAt - epoch + offset
                                ),
                                "wall forecast pose unavailable"
                            )
                            local camera = Vector3.new(poseValue.x, poseValue.y, poseValue.z)
                            local frame = CFrame.lookAt(
                                camera,
                                camera + Vector3.new(poseValue.tangentX, 0, poseValue.tangentZ)
                            )
                            local muzzle = frame:PointToWorldSpace(relativeMuzzle)
                            local facing = (muzzle - point).Unit:Dot(normal)
                            local hit = aimHit("M102", point, muzzle, params)
                            if
                                facing <= 0.15
                                or not hit
                                or runtime.destruction.identify(hit.Instance) ~= model.Name
                                or (step % 8 == 0 and not command("M102", point, fireSequence + 1, camera))
                            then
                                clear = false
                                break
                            end
                            exposure = math.min(exposure, facing)
                        end
                        if clear and exposure > bestExposure then
                            selected, selectedPoint, selectedNormal, bestExposure =
                                model.Name, point, normal, exposure
                        end
                    end
                end
            end
            task.wait() -- bounded per-building fixture-query batches
        end
        assert(selected, "no exterior ground-story wall clear for bounded reload/flight window")
        table.insert(observations, {
            kind = "wall-forecast",
            panelId = selected,
            windowSeconds = wallWindowSeconds,
            minimumExteriorExposure = bestExposure,
        })
        return selected, selectedPoint, selectedNormal
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
            local firstSequence = fireSequence + 1
            local factsBefore = #impactFacts
            local receiptBefore = #receipts
            local beforeReadiness = ReplicatedStorage.AircraftState:GetAttribute("Readiness")
            assert(type(beforeReadiness) == "string", "GAU initial readiness unavailable")
            local initialAmmo = HttpService:JSONDecode(beforeReadiness).GAU23.ammo
            local diagnostic: { [string]: unknown } = {
                kind = "actual-30mm",
                panelId = id,
                requested = 61,
                sendIntervalSeconds = 0.18,
                serverCadenceSeconds = CombatService.profiles.GAU23.cadence,
                gapSeconds = 0.225,
                impacts = impactFacts,
                receipts = receipts,
                clientTimingByToken = burstTiming,
                firstFactIndex = factsBefore + 1,
                firstReceiptIndex = receiptBefore + 1,
            }
            -- Insert BEFORE sending so any failure retains bounded actual facts.
            table.insert(observations, diagnostic)
            fireSequence += 61
            local timingToken = probe(operator, "Burst", {
                point = pose(id).Position + Vector3.new(-6, 0.5, 0),
                roundId = runtime.rounds.match.snapshot().roundId,
                firstSequence = firstSequence,
                count = 61,
                cadence = 0.18,
            })
            diagnostic.clientSends = burstTiming[timingToken]
            burstTiming[timingToken] = nil
            waitFor(function()
                return #impactFacts >= factsBefore + 61 and runtime.combat.resources().projectiles == 0
            end, "61 actual sustained-fire impacts", 8)
            diagnostic.lastFactIndex = #impactFacts
            diagnostic.lastReceiptIndex = #receipts
            local firstPhysical = impactFacts[factsBefore + 1]
            assert(
                firstPhysical
                    and firstPhysical.weapon == "GAU23"
                    and firstPhysical.panelId == id
                    and firstPhysical.progress == 0,
                "first real on-panel impact earned pre-first-impact credit"
            )
            local ordered: { typeof(firstPhysical) } = {}
            local transition: typeof(firstPhysical)? = nil
            for index = factsBefore + 1, #impactFacts do
                local fact = impactFacts[index]
                assert(
                    fact.weapon == "GAU23" and fact.panelId == id,
                    "sustained outcome missed or hit a different panel"
                )
                table.insert(ordered, fact)
                if not transition and fact.stage == 1 then
                    transition = fact
                end
            end
            table.sort(ordered, function(a, b)
                return a.shotId < b.shotId
            end)
            local first = ordered[1]
            local previous = first
            for index = 2, #ordered do
                local fact = ordered[index]
                local gap = fact.firedAt - previous.firedAt
                assert(
                    fact.shotId == previous.shotId + 1
                        and gap + 1e-9 >= CombatService.profiles.GAU23.cadence
                        and gap <= 0.225 + 1e-7,
                    "actual accepted interval outside cadence/continuity bounds"
                )
                previous = fact
            end
            local finalReadiness = ReplicatedStorage.AircraftState:GetAttribute("Readiness")
            assert(type(finalReadiness) == "string", "GAU final readiness unavailable")
            local spent = initialAmmo - HttpService:JSONDecode(finalReadiness).GAU23.ammo
            diagnostic.accepted = spent
            diagnostic.actualSpanSeconds = previous.firedAt - first.firedAt
            assert(
                #impactFacts - factsBefore == 61 and spent == 61,
                "not all 61 bounded requests became real accepted impacts"
            )
            assert(
                transition
                    and transition.scoredThroughFiredAt
                    and transition.scoredThroughFiredAt - first.firedAt >= 9 - 1e-7,
                "stage advanced before nine actual accepted on-panel seconds"
            )
            diagnostic.transitionSpanSeconds = (transition.scoredThroughFiredAt :: number) - first.firedAt
            assert(
                panel(id):GetAttribute("PanelState") == "Damaged",
                "nine valid actual seconds did not damage panel"
            )
            -- Preserve transition facts above, then wait for the ordinary idle
            -- barrier to clear incomplete second-stage credit before freezing a
            -- progress snapshot for sequential real-client replication probes.
            waitFor(function()
                return runtime.combat.resources().projectiles == 0
                    and panel(id):GetAttribute("SustainedSeconds") == 0
            end, "sustained tail and idle-barrier settlement", 8)
            for _, player in initialPlayers do
                probe(player, "Panels", expected({ id }))
            end
        end)
        check("A3 actual ground Humanoid walks through an authored damaged wall opening", function()
            selectWeapon(operator, "M102")
            local wallId, wallPoint, normal = stableExteriorWall()
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Include
            params.FilterDescendantsInstances = { workspace.World.Battlefield, workspace.Terrain }
            params.RespectCanCollide = true
            for hit = 1, 3 do
                awaitReady("M102")
                local muzzle = assert(runtime.aircraft.muzzle("M102"), "current wall muzzle unavailable")
                local first = aimHit("M102", wallPoint, muzzle, params)
                assert(
                    first and runtime.destruction.identify(first.Instance) == wallId,
                    "current real muzzle path no longer first-hits chosen exterior wall"
                )
                fireSequence += 1
                local payload =
                    assert(command("M102", wallPoint, fireSequence), "wall left permitted current view")
                probe(operator, "Fire", payload)
                waitFor(function()
                    return panel(wallId):GetAttribute("PanelState")
                            == (if hit == 3 then "Damaged" else "Intact")
                        and panel(wallId):GetAttribute("PanelProgress") :: number
                            == (if hit == 3 then 0 else hit / 3)
                end, "wall heavy progress")
            end
            local groundPlayer = ground
            assert(groundPlayer and groundPlayer.Character, "actual Ground character missing")
            local character = groundPlayer.Character
            local root = character:FindFirstChild("HumanoidRootPart")
            assert(root and root:IsA("BasePart"), "Ground root missing")
            local original = character:GetPivot()
            local originalServerPosition = root.Position
            local groundY = wallPoint.Y - 1
            local start = Vector3.new(wallPoint.X, groundY, wallPoint.Z) + normal * 6
            local goal = Vector3.new(wallPoint.X, groundY, wallPoint.Z) - normal * 6
            character:PivotTo(CFrame.new(start))
            root.AssemblyLinearVelocity = Vector3.zero
            local function coordinates(point: Vector3): { number }
                return { point.X, point.Y, point.Z }
            end
            local walkObservation: { [string]: unknown } = {
                kind = "actual-humanoid-opening",
                panelId = wallId,
                userId = groundPlayer.UserId,
                serverObservationBudgetSeconds = 2,
                originalPositionStuds = coordinates(originalServerPosition),
                requestedStartPositionStuds = coordinates(start),
                startServerPositionStuds = coordinates(root.Position),
                goalPositionStuds = coordinates(goal),
            }
            -- Preserve actual positions even if either the client movement or
            -- bounded server-replication observation fails. Never place at goal.
            table.insert(observations, walkObservation)
            local startedAt = os.clock()
            local observationStartedAt: number? = nil
            local walked, walkFailure = pcall(function()
                probe(groundPlayer, "Walk", goal)
                walkObservation.clientReplyAfterSeconds = os.clock() - startedAt
                walkObservation.clientReplyServerPositionStuds = coordinates(root.Position)
                observationStartedAt = os.clock()
                -- Client completion can precede its network-owned avatar's next
                -- server physics update. Require the real server state within a
                -- separate two-second fixture budget; timeout remains a failure.
                waitFor(function()
                    return root:IsDescendantOf(workspace) and (root.Position - goal).Magnitude < 2
                end, "actual server Ground traversal replication", 2)
                return true
            end)
            walkObservation.finalServerPositionStuds = coordinates(root.Position)
            walkObservation.finalServerDistanceStuds = (root.Position - goal).Magnitude
            walkObservation.serverRootPresent = root:IsDescendantOf(workspace)
            walkObservation.elapsedSeconds = os.clock() - startedAt
            walkObservation.serverObservationElapsedSeconds = if observationStartedAt
                then os.clock() - observationStartedAt
                else nil
            walkObservation.passed = walked
            walkObservation.failure = if walked then nil else tostring(walkFailure)
            -- Restore only after collecting the final actual observation, for
            -- both success and failure. Cleanup cannot make traversal pass.
            if character.Parent and root.Parent then
                character:PivotTo(original)
                root.AssemblyLinearVelocity = Vector3.zero
            end
            assert(walked, tostring(walkFailure))
        end)
        check(
            "A6 current state reaches both initial clients and prior fragments expire before late join",
            function()
                -- One real heavy impact leaves a separate accumulating panel.
                selectWeapon(operator, "M102")
                awaitReady("M102")
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
    receiptListener:Disconnect()
    transport:Destroy()
    observedCombat.stop()
    runtime.stop()
    deliver()
end
return Harness
