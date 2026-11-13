--!strict
--[=[
    P07 manual/SDK harness: two actual clients fire production gunship remotes,
    inspect persistent Light/Heavy/Total state and repeat actual round resets.
    The current P07 gate uses two real clients without a late-player checkpoint.
    No fake Players or client-authoritative damage seam. Fixtures/control transport are test-mapped only; stop owns all resources.
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
-- Only the non-yielding production basis function is used; no client controller
-- is started on this server. Forecasts also respect Burst's stricter 0.7 inset.
local Camera = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.ThermalCameraController)
local Harness = {}
type Case = { name: string, passed: boolean, detail: string? }
type PanelExpectation = {
    id: string,
    stage: string,
    progress: number,
    appearance: string,
    heavySeconds: number,
    sustainedSeconds: number,
    parts: number,
    pivot: { number },
    size: Vector3,
}
export type Report = {
    suite: string,
    environment: string,
    clientCount: number,
    initialUserIds: { number },
    initialObservedAtServerSeconds: number?,
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
    local initialObservedAt: number? = nil
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
            initialObservedAtServerSeconds = initialObservedAt,
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
    initialObservedAt = workspace:GetServerTimeNow()
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
            earnedSeconds: number?,
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
                earnedSeconds = if current then current.sustainedSeconds else nil,
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
        predictedCamera: Vector3?,
        burstView: boolean?
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
            local focus = {
                x = targetFocus.x + (home.x - targetFocus.x) * t,
                z = targetFocus.z + (home.z - targetFocus.z) * t,
            }
            payload.focusX = focus.x
            payload.focusZ = focus.z
            if CombatViewRules.validate(payload, map, weapon, camera.X, camera.Z) then
                if not burstView then
                    return payload
                end
                local worldFocus = assert(
                    Pan.worldFocus(map, focus, camera.X, camera.Z),
                    "valid fixture world focus unavailable"
                )
                local frame = assert(
                    Camera.frame(camera, Vector3.new(worldFocus.x, map.groundY, worldFocus.z)),
                    "valid fixture camera basis unavailable"
                )
                local widest = assert(Pan.supportedFov(map, 16 / 9, 40), "fixture lens unavailable")
                local tangent = math.tan(math.rad(math.min(AircraftRules.defaults.fov30mm, widest)) / 2)
                local localPoint = frame:PointToObjectSpace(point)
                local depth = -localPoint.Z
                if
                    depth > 0
                    and math.abs(localPoint.X / (depth * tangent * (16 / 9))) <= 0.7
                    and math.abs(localPoint.Y / (depth * tangent)) <= 0.7
                then
                    return payload
                end
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
    -- Fixed target on a remaining roof strip, using the real authored thickness
    -- and original size (including 2-stud starting-shelter roof tiles).
    local function roofTarget(model: Model): Vector3
        local size = model:GetAttribute("IntactSize")
        assert(typeof(size) == "Vector3", "original panel dimensions unavailable")
        local offset = if size.X >= size.Z
            then Vector3.new(-size.X * 0.375, size.Y / 2, 0)
            else Vector3.new(0, size.Y / 2, -size.Z * 0.375)
        return pose(model.Name):PointToWorldSpace(offset)
    end
    local function expected(ids: { string }): { PanelExpectation }
        local result: { PanelExpectation } = {}
        for _, id in ids do
            local model = panel(id)
            local state = assert(runtime.destruction.snapshot(id), "registered panel ledger unavailable")
            local size = model:GetAttribute("IntactSize")
            assert(typeof(size) == "Vector3", "registered panel size unavailable")
            table.insert(result, {
                id = id,
                stage = ({ "Intact", "Damaged", "Destroyed" })[state.stage + 1],
                progress = state.progress,
                appearance = state.appearance,
                heavySeconds = state.heavySeconds,
                sustainedSeconds = state.sustainedSeconds,
                parts = #model:GetChildren(),
                pivot = { pose(id):GetComponents() },
                size = size,
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
    -- A reset target must remain reachable through all three heavy reload/flight
    -- steps and the following four-shot GAU burst. Prefer roofs near the level
    -- center rather than an orbit-dependent current FOV edge. The point is on a
    -- real residual strip and uses authored roof thickness; no collider is moved.
    local function stableResetRoof(): (string, Vector3, RaycastParams)
        awaitReady("M102")
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Include
        params.FilterDescendantsInstances = { workspace.World.Battlefield, workspace.Terrain }
        params.RespectCanCollide = true
        local candidates: { Model } = {}
        local center = Vector3.new(MapRules.defaults.centerX, 0, MapRules.defaults.centerZ)
        for _, item in workspace.World.Battlefield:GetDescendants() do
            if
                item:IsA("Model")
                and string.find(item.Name, "Roof", 1, true)
                and item:GetAttribute("PanelState") == "Intact"
                and item:GetAttribute("PanelProgress") == 0
            then
                table.insert(candidates, item)
            end
        end
        table.sort(candidates, function(a, b)
            return (pose(a.Name).Position * Vector3.new(1, 0, 1) - center).Magnitude
                < (pose(b.Name).Position * Vector3.new(1, 0, 1) - center).Magnitude
        end)
        local epoch = ReplicatedStorage.AircraftState:GetAttribute("EpochSeconds")
        assert(type(epoch) == "number", "reset forecast epoch unavailable")
        local aircraftFrame = workspace.Aircraft:GetPivot()
        local relativeMuzzles: { [string]: Vector3 } = {}
        for _, weapon in { "M102", "GAU23" } do
            local muzzle = assert(runtime.aircraft.muzzle(weapon), "reset forecast muzzle unavailable")
            relativeMuzzles[weapon] = aircraftFrame:PointToObjectSpace(muzzle)
        end
        for candidateIndex, model in candidates do
            local point = roofTarget(model)
            local startedAt = workspace:GetServerTimeNow()
            local clear = true
            for step = 0, math.ceil(wallWindowSeconds / 0.5) do
                local predicted = assert(
                    AircraftRules.pose(
                        MapRules.defaults,
                        AircraftRules.defaults,
                        startedAt - epoch + step * 0.5
                    ),
                    "reset forecast pose unavailable"
                )
                local camera = Vector3.new(predicted.x, predicted.y, predicted.z)
                local frame =
                    CFrame.lookAt(camera, camera + Vector3.new(predicted.tangentX, 0, predicted.tangentZ))
                for _, weapon in { "M102", "GAU23" } do
                    local first =
                        aimHit(weapon, point, frame:PointToWorldSpace(relativeMuzzles[weapon]), params)
                    if
                        not first
                        or runtime.destruction.identify(first.Instance) ~= model.Name
                        or not command(weapon, point, fireSequence + 1, camera, weapon == "GAU23")
                    then
                        clear = false
                        break
                    end
                end
                if not clear then
                    break
                end
                if step % 8 == 7 then
                    task.wait() -- at most sixteen engine queries per uninterrupted batch
                end
            end
            if clear then
                table.insert(observations, {
                    kind = "reset-roof-forecast",
                    panelId = model.Name,
                    windowSeconds = wallWindowSeconds,
                    sampleIntervalSeconds = 0.5,
                    candidateIndex = candidateIndex,
                    startedAtServerSeconds = startedAt,
                    selectedAtServerSeconds = workspace:GetServerTimeNow(),
                })
                return model.Name, point, params
            end
            task.wait()
        end
        error("no pristine roof has both profile views and first hits across reset reload/flight window")
    end
    -- Readiness may yield; view and actual first-hit checks therefore run AFTER
    -- it, immediately before the next send. Forecasts never authorize a shot.
    local function readyResetTarget(weapon: string, id: string, point: Vector3, params: RaycastParams)
        awaitReady(weapon)
        local payload = assert(
            command(weapon, point, fireSequence + 1, nil, weapon == "GAU23"),
            "reset target outside current " .. weapon .. " fixture view"
        )
        local first =
            aimHit(weapon, point, assert(runtime.aircraft.muzzle(weapon), "reset muzzle missing"), params)
        assert(
            first and runtime.destruction.identify(first.Instance) == id,
            "reset current " .. weapon .. " first hit is not the selected real panel"
        )
        return payload
    end
    local op: Player? = nil
    local ground: Player? = nil
    local testedIds: { string } = {}
    local allIds: { string } = {}
    local originalPanels: { [string]: { pivot: CFrame, size: Vector3 } } = {}
    local function allPanelStates(pristine: boolean): { PanelExpectation }
        assert(#allIds == 187 and runtime.destruction.resources().panels == 187, "all-panel registry changed")
        local entries = expected(allIds)
        for _, entry in entries do
            local model = panel(entry.id)
            local original = assert(originalPanels[entry.id], "original panel identity missing")
            assert(
                model:GetAttribute("PanelState") == entry.stage
                    and model:GetAttribute("PanelProgress") == entry.progress
                    and model:GetAttribute("DamageAppearance") == entry.appearance
                    and model:GetAttribute("HeavySeconds") == entry.heavySeconds
                    and model:GetAttribute("SustainedSeconds") == entry.sustainedSeconds,
                entry.id .. " ledger/publication disagreement"
            )
            assert(
                pose(entry.id) == original.pivot
                    and model:GetPivot() == original.pivot
                    and entry.size == original.size,
                entry.id .. " original pivot/size changed"
            )
            if pristine then
                assert(
                    entry.stage == "Intact"
                        and entry.progress == 0
                        and entry.appearance == "Pristine"
                        and entry.heavySeconds == 0
                        and entry.sustainedSeconds == 0
                        and entry.parts == 1
                        and not model:FindFirstChild("DamageVisuals"),
                    entry.id .. " retained damage after reset"
                )
            end
        end
        return entries
    end
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
                for _, item in workspace.World.Battlefield:GetDescendants() do
                    if item:IsA("Model") and item:GetAttribute("PanelId") == item.Name then
                        local size = item:GetAttribute("IntactSize")
                        assert(typeof(size) == "Vector3", "initial panel dimensions missing")
                        table.insert(allIds, item.Name)
                        originalPanels[item.Name] = { pivot = pose(item.Name), size = size }
                    end
                end
                table.sort(allIds)
                allPanelStates(true)
                local roofIds: { string } = {}
                for _, item in workspace.World.Battlefield:GetDescendants() do
                    if item:IsA("Model") and string.find(item.Name, "Roof", 1, true) then
                        table.insert(roofIds, item.Name)
                    end
                end
                table.sort(roofIds)
                for _, id in roofIds do
                    local point = roofTarget(panel(id))
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
                local point = roofTarget(panel(id))
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
        check("A7 earned 30mm Light damage persists through three bursts before Heavy", function()
            selectWeapon(operator, "GAU23")
            local id = testedIds[2]
            local overallFacts = #impactFacts
            local initialReadiness = ReplicatedStorage.AircraftState:GetAttribute("Readiness")
            assert(type(initialReadiness) == "string", "GAU initial readiness missing")
            local initialAmmo = HttpService:JSONDecode(initialReadiness).GAU23.ammo
            local earnedTotal = 0
            local earnedByShot: { [number]: number } = {}
            local transition: typeof(impactFacts[1])? = nil
            local diagnostic: { [string]: unknown } = {
                kind = "persistent-30mm-bursts",
                panelId = id,
                requested = 63,
                bursts = {},
                impacts = impactFacts,
                receipts = receipts,
                clientTimingByToken = burstTiming,
                firstFactIndex = overallFacts + 1,
            }
            table.insert(observations, diagnostic)
            local bursts: { unknown } = {}
            diagnostic.bursts = bursts
            for burst = 1, 3 do
                local before = assert(runtime.destruction.snapshot(id), "panel missing")
                local factStart = #impactFacts
                local firstSequence = fireSequence + 1
                fireSequence += 21
                local timingToken = probe(operator, "Burst", {
                    point = roofTarget(panel(id)),
                    roundId = runtime.rounds.match.snapshot().roundId,
                    firstSequence = firstSequence,
                    count = 21,
                    cadence = 0.18,
                })
                local burstRecord: { [string]: unknown } =
                    { index = burst, clientSends = burstTiming[timingToken], firstFactIndex = factStart + 1 }
                table.insert(bursts, burstRecord)
                burstTiming[timingToken] = nil
                waitFor(function()
                    return #impactFacts >= factStart + 21 and runtime.combat.resources().projectiles == 0
                end, "21 actual on-panel burst impacts", 8)
                local firstPhysical = impactFacts[factStart + 1]
                assert(
                    firstPhysical.earnedSeconds
                        and math.abs(firstPhysical.earnedSeconds - before.sustainedSeconds) < 1e-7
                        and firstPhysical.stage == before.stage,
                    "first resumed impact earned paused/off-target time"
                )
                local ordered: { typeof(firstPhysical) } = {}
                for index = factStart + 1, #impactFacts do
                    local fact = impactFacts[index]
                    assert(
                        fact.weapon == "GAU23" and fact.panelId == id,
                        "burst outcome missed or hit another panel"
                    )
                    table.insert(ordered, fact)
                    if not transition and fact.stage == 1 then
                        transition = fact
                    end
                end
                assert(#ordered == 21, "bounded burst did not produce21 actual impacts")
                table.sort(ordered, function(a, b)
                    return a.shotId < b.shotId
                end)
                for index, fact in ordered do
                    if index > 1 then
                        local previous = ordered[index - 1]
                        local gap = fact.firedAt - previous.firedAt
                        assert(
                            fact.shotId == previous.shotId + 1
                                and gap + 1e-9 >= CombatService.profiles.GAU23.cadence
                                and gap <= 0.225 + 1e-7,
                            "accepted burst cadence/gap invalid"
                        )
                        earnedTotal += gap
                    end
                    earnedByShot[fact.shotId] = earnedTotal
                end
                local saved = assert(runtime.destruction.snapshot(id), "earned panel missing")
                local savedAppearance = panel(id):GetAttribute("DamageAppearance")
                if burst == 1 then
                    assert(
                        saved.appearance == "Light" and saved.sustainedSeconds > 0,
                        "first real burst lacks Light damage"
                    )
                end
                task.wait(0.5) -- longer than continuity gap, after all actual flights
                local paused = assert(runtime.destruction.snapshot(id), "paused panel missing")
                assert(
                    paused.stage == saved.stage
                        and paused.progress == saved.progress
                        and paused.sustainedSeconds == saved.sustainedSeconds
                        and panel(id):GetAttribute("DamageAppearance") == savedAppearance,
                    "stopping fire erased earned damage/appearance"
                )
                burstRecord.earnedTotalSeconds = earnedTotal
                burstRecord.earnedAfterPause = paused.sustainedSeconds
                burstRecord.appearance = savedAppearance
                for _, player in initialPlayers do
                    probe(player, "Panels", expected({ id }))
                end
            end
            local finalReadiness = ReplicatedStorage.AircraftState:GetAttribute("Readiness")
            assert(type(finalReadiness) == "string", "GAU final readiness missing")
            local spent = initialAmmo - HttpService:JSONDecode(finalReadiness).GAU23.ammo
            assert(
                #impactFacts - overallFacts == 63 and spent == 63,
                "not all 63 real burst requests were accepted impacts"
            )
            assert(
                transition
                    and earnedByShot[transition.scoredThroughShotId]
                    and earnedByShot[transition.scoredThroughShotId] >= 9 - 1e-7,
                "Heavy appeared before nine valid earned seconds"
            )
            assert(
                panel(id):GetAttribute("PanelState") == "Damaged"
                    and panel(id):GetAttribute("DamageAppearance") == "Heavy",
                "persistent valid bursts did not reach Heavy"
            )
            diagnostic.accepted = spent
            diagnostic.earnedTotalSeconds = earnedTotal
            diagnostic.transitionEarnedSeconds = earnedByShot[transition.scoredThroughShotId]
        end)
        check(
            "A7 battlefield starting-shelter roof follows Light Heavy Total through six real M102 hits",
            function()
                selectWeapon(operator, "M102")
                local id = "Shelter_Roof_R01_C02"
                local point = roofTarget(panel(id))
                for hit = 1, 6 do
                    awaitReady("M102")
                    fireSequence += 1
                    probe(
                        operator,
                        "Fire",
                        (assert(command("M102", point, fireSequence), "shelter roof outside current view"))
                    )
                    local wanted = if hit < 3 then "Light" elseif hit < 6 then "Heavy" else "Total"
                    waitFor(function()
                        return panel(id):GetAttribute("DamageAppearance") == wanted
                            and panel(id):GetAttribute("PanelProgress")
                                == (if hit == 6 then 1 else (hit % 3) / 3)
                    end, "actual shelter hit" .. hit, 8)
                    for _, player in initialPlayers do
                        probe(player, "Panels", expected({ id }))
                    end
                end
            end
        )
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
            "A6 current state reaches both initial clients and prior fragments expire before current-state comparisons",
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
                            command("M102", roofTarget(panel(id)), fireSequence),
                            "accumulating panel target"
                        )
                    )
                )
                waitFor(function()
                    return panel(id):GetAttribute("PanelProgress") == 1 / 3
                end, "accumulating panel")
                task.wait(8.2)
                assert(runtime.destruction.resources().fragments == 0, "prior debris still live")
                local entries = allPanelStates(false)
                for _, player in initialPlayers do
                    probe(player, "Panels", expected(testedIds))
                    probe(player, "Panels", entries)
                    probe(player, "NoFragments", nil)
                end
                table.insert(observations, {
                    kind = "all-panel-current-agreement",
                    serverPanels = #entries,
                    actualClients = #initialPlayers,
                    perClientQueriedPanels = #entries,
                })
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
                local targetId, targetPoint, resetParams = stableResetRoof()
                for hit = 1, 3 do
                    local payload = readyResetTarget("M102", targetId, targetPoint, resetParams)
                    fireSequence += 1
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
                readyResetTarget("GAU23", targetId, targetPoint, resetParams)
                local firstSequence = fireSequence + 1
                fireSequence += 4
                probe(currentOperator, "Burst", {
                    point = targetPoint,
                    roundId = runtime.rounds.match.snapshot().roundId,
                    firstSequence = firstSequence,
                    count = 4,
                    cadence = 0.18,
                })
                waitFor(function()
                    local earned = runtime.destruction.snapshot(targetId)
                    return earned ~= nil
                        and earned.sustainedSeconds > 0
                        and runtime.combat.resources().projectiles > 0
                        and runtime.destruction.resources().fragments > 0
                end, "actual partial credit plus pending flight plus fragments", 8)
                table.insert(observations, {
                    kind = "reset-pre-abort-work",
                    iteration = iteration,
                    panelId = targetId,
                    sustainedSeconds = assert(runtime.destruction.snapshot(targetId)).sustainedSeconds,
                    pendingProjectiles = runtime.combat.resources().projectiles,
                    liveFragments = runtime.destruction.resources().fragments,
                })
                local staleRound = runtime.rounds.match.snapshot().roundId
                runtime.rounds.match.abort(runtime.rounds.match.snapshot().roundId, "P07 reset fixture")
                assert(runtime.rounds.match.beginReset(), "reset start")
                waitFor(function()
                    return runtime.rounds.match.snapshot().phase == "Lobby"
                end, "reset lobby")
                waitFor(function()
                    -- Lobby can precede the next Heartbeat's panel capture.
                    -- Authored Parts are a pending state, not a failed Model lookup.
                    local world = workspace:FindFirstChild("World")
                    local map = if world then world:FindFirstChild("Battlefield") else nil
                    if not map then
                        return false
                    end
                    for _, id in allIds do
                        local model = map:FindFirstChild(id, true)
                        if
                            not model
                            or not model:IsA("Model")
                            or model:GetAttribute("PanelState") ~= "Intact"
                            or model:GetAttribute("DamageAppearance") ~= "Pristine"
                            or model:GetAttribute("PanelProgress") ~= 0
                            or model:GetAttribute("HeavySeconds") ~= 0
                            or model:GetAttribute("SustainedSeconds") ~= 0
                        then
                            return false
                        end
                    end
                    return true
                end, "all pristine panel Models reconstructed")
                local resetEntries = allPanelStates(true)
                assert(not runtime.destruction.resolve({
                    roundId = staleRound,
                    shotId = 1,
                    weapon = "M102",
                    firedAt = workspace:GetServerTimeNow(),
                    panelId = targetId,
                }), "stale pre-reset outcome accepted")
                assert(
                    runtime.destruction.resources().fragments == 0
                        and runtime.destruction.resources().pending == 0
                        and runtime.combat.resources().projectiles == 0,
                    "reset work leaked"
                )
                for _, player in Players:GetPlayers() do
                    probe(player, "Panels", expected(testedIds))
                    probe(player, "Panels", resetEntries)
                    probe(player, "NoFragments", nil)
                end
                table.insert(observations, {
                    kind = "all-panel-pristine-reset-agreement",
                    iteration = iteration,
                    serverPanels = #resetEntries,
                    actualClients = #Players:GetPlayers(),
                    perClientQueriedPanels = #resetEntries,
                })
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
    listener:Disconnect()
    receiptListener:Disconnect()
    transport:Destroy()
    observedCombat.stop()
    runtime.stop()
    deliver()
end
return Harness
