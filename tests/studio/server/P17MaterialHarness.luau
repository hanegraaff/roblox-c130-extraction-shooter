--!strict
--[=[
    P17MaterialHarness: test-only server acceptance for imported Outpost materials.
    Uses real GameRuntime owners, two actual clients and production fire intents.
    Six-family controlled service outcomes are labeled separately from actual
    weapon impacts. Roof selectors sample real panel geometry and check production
    sweep/view; they never award damage or change aircraft motion.
    run(finish) yields for bounded roster/gameplay waits and calls finish once
    after stopping its transport, impact observer and runtime. Reports retain
    ordinary baselines, client diagnostics, actual hits and replicated geometry.
    The burst selector includes the Heavy residual in its preflight so the same
    real panel remains the target when an earned opening appears in flight.
    This test mapping grants fixture orchestration only; never ship it in release.
]=]
-- Historical executable body below remains byte-bound to the P17 evidence.
-- Reject module loading before that body can allocate listeners/runtime owners.
require(game:GetService("ReplicatedStorage").HarnessCompatibility).assertCurrent("P17")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Server = game:GetService("ServerScriptService").Server
local GameRuntime = require(Server.GameRuntime)
local CombatViewRules = require(Server.CombatViewRules)
local CombatRuntime = require(Server.CombatRuntime)
local CombatService = require(Server.CombatService)
local DestructionService = require(Server.DestructionService)
local MapRules = require(ReplicatedStorage.Shared.MapRules)
local Pan = require(ReplicatedStorage.Shared.AircraftPanRules)
local AircraftRules = require(ReplicatedStorage.Shared.AircraftRules)
-- Only the non-yielding production basis function is used; no client controller
-- is started on this server. Forecasts also respect Burst's stricter 0.7 inset.
local Camera = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.ThermalCameraController)
local AssetMesh = require(ReplicatedStorage.Shared.AssetMesh)
local Harness = {}
local function p17Geometry(model: Model): string
    local records = {}
    for _, child in model:GetChildren() do
        if child:IsA("BasePart") then
            if child:IsA("MeshPart") then
                assert(AssetMesh.validate(child), "stage/reset mesh native payload mismatch")
            end
            local surface = child:FindFirstChildOfClass("SurfaceAppearance")
            table.insert(records, {
                name = child.Name,
                class = child.ClassName,
                pose = { child.CFrame:GetComponents() },
                size = { child.Size.X, child.Size.Y, child.Size.Z },
                color = { child.Color.R, child.Color.G, child.Color.B },
                collide = child.CanCollide,
                query = child.CanQuery,
                touch = child.CanTouch,
                mesh = if child:IsA("MeshPart") then child.MeshId else "",
                compiledColorMap = if surface then surface:GetAttribute("CompiledColorMap") else "",
                compiledNormalMap = if surface then surface:GetAttribute("CompiledNormalMap") else "",
                compiledRoughnessMap = if surface then surface:GetAttribute("CompiledRoughnessMap") else "",
                compiledMetalnessMap = if surface then surface:GetAttribute("CompiledMetalnessMap") else "",
                compiledColorPngSha256 = if surface
                    then surface:GetAttribute("CompiledColorPngSha256")
                    else "",
                materialMetadataVersion = if surface
                    then surface:GetAttribute("MaterialMetadataVersion")
                    else 0,
                materialKey = if surface then surface:GetAttribute("MaterialKey") else "",
            })
        end
    end
    table.sort(records, function(a, b)
        return a.name < b.name
    end)
    return HttpService:JSONEncode(records)
end
local p17Catalog = assert(
    require(game.ServerScriptService.Server.PanelAssetCatalog).load(game.ServerStorage.Assets.MaterialPanels)
)
local function p17MaterialSamples(model: Model, appearance: string): ({ Vector3 }?, Vector3?)
    local id = model:GetAttribute("PanelAssetFamily")
    if type(id) ~= "string" then
        return nil, nil
    end
    local family = assert(p17Catalog[id], "expected approved material family")
    local basis = model:GetAttribute("PanelAssetBasis")
    assert(typeof(basis) == "CFrame", "expected material basis")
    local pivot = model:GetPivot() * basis
    local heavy = family.states.Heavy.rectangles
    local earned: Vector3? = nil
    for _, rectangle in family.states.Pristine.rectangles do
        for _, fx in { 0.2, 0.4, 0.6, 0.8 } do
            for _, fy in { 0.2, 0.4, 0.6, 0.8 } do
                local x = rectangle[1] + (rectangle[3] - rectangle[1]) * fx
                local y = rectangle[2] + (rectangle[4] - rectangle[2]) * fy
                local survives = false
                for _, residual in heavy do
                    if
                        x >= residual[1] - 0.05
                        and x <= residual[3] + 0.05
                        and y >= residual[2] - 0.05
                        and y <= residual[4] + 0.05
                    then
                        survives = true
                    end
                end
                if not survives then
                    earned = pivot:PointToWorldSpace(Vector3.new(x, y, 0))
                    break
                end
            end
            if earned then
                break
            end
        end
        if earned then
            break
        end
    end
    assert(earned, "approved Heavy opening removes no pristine solid sample")
    local points = {}
    for _, rectangle in family.states[appearance].rectangles do
        table.insert(
            points,
            pivot:PointToWorldSpace(
                Vector3.new((rectangle[1] + rectangle[3]) / 2, (rectangle[2] + rectangle[4]) / 2, 0)
            )
        )
    end
    return points, earned
end
-- Same query roots and CanQuery semantics as the production projectile sweep.
local function fireParameters(): RaycastParams
    local roots: { Instance } = { workspace.World.Battlefield, workspace.Terrain }
    for _, player in Players:GetPlayers() do
        if
            player.Character
            and player:GetAttribute("Role") == "Ground"
            and player:GetAttribute("Life") == "Alive"
        then
            table.insert(roots, player.Character)
        end
    end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = roots
    params.RespectCanCollide = false
    return params
end
local function p17FireGeometry(runtime: GameRuntime.Controller, weapon: string, point: Vector3): string
    local muzzle = runtime.aircraft.muzzle(weapon)
    if not muzzle then
        return "muzzle unavailable"
    end
    local delta = point - muzzle
    local hit = if delta.Magnitude > 0
        then CombatRuntime.sweep(
            muzzle,
            CombatService.profiles[weapon].collisionRadius,
            delta.Unit * math.min(delta.Magnitude + 0.25, CombatService.profiles[weapon].range),
            fireParameters()
        )
        else nil
    local frame = workspace.Aircraft:GetPivot()
    return HttpService:JSONEncode({
        time = workspace:GetServerTimeNow(),
        muzzle = { muzzle.X, muzzle.Y, muzzle.Z },
        point = { point.X, point.Y, point.Z },
        distance = delta.Magnitude,
        aircraft = { frame:GetComponents() },
        firstPath = if hit then hit.Instance:GetFullName() else "none",
        firstPanelId = if hit then runtime.destruction.identify(hit.Instance) or "unregistered" else "none",
        hitPosition = if hit then { hit.Position.X, hit.Position.Y, hit.Position.Z } else nil,
        hitLocalEndpoint = if hit and hit.Instance:IsA("BasePart")
            then {
                hit.Instance.CFrame:PointToObjectSpace(point).X,
                hit.Instance.CFrame:PointToObjectSpace(point).Y,
                hit.Instance.CFrame:PointToObjectSpace(point).Z,
            }
            else nil,
        firstSize = if hit and hit.Instance:IsA("BasePart")
            then { hit.Instance.Size.X, hit.Instance.Size.Y, hit.Instance.Size.Z }
            else nil,
    })
end

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
    assetFamily: string?,
    geometryJSON: string?,
    materialSolidPoints: { Vector3 }?,
    earnedOpeningPoint: Vector3?,
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
    serverBaseline: string?,
    clientBaselines: { [string]: string },
    clientDiagnostics: { [string]: string },
}
local function waitFor(predicate: () -> boolean, label: string, seconds: number?)
    local deadline = os.clock() + (seconds or 15)
    while not predicate() and os.clock() < deadline do
        task.wait(0.03)
    end
    assert(predicate(), "P07 timeout: " .. label)
end
-- Manual finish preserves report in the actual server before the human ends the
-- native session. This manual copy requires an explicit completion callback.
function Harness.run(finish: (Report) -> ())
    local cases: { Case } = {}
    local observations: { unknown } = {}
    local clientBaselines: { [string]: string } = {}
    local clientDiagnostics: { [string]: string } = {}
    local preloadRecords: { [number]: string } = {}
    local panelMismatchRecords: { [number]: string } = {}
    local initialIds: { number } = {}
    local initialObservedAt: number? = nil
    local function stage(name: string, detail: unknown?)
        workspace:SetAttribute(
            "P17ManualStage",
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
            suite = "P17-imported-material-multiplayer",
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
            serverBaseline = workspace:GetAttribute("ServerTestReport"),
            clientBaselines = clientBaselines,
            clientDiagnostics = clientDiagnostics,
        }
        stage(if report.failed == 0 then "complete" else "failed", {
            discovered = report.discovered,
            passed = report.passed,
            failed = report.failed,
            skipped = report.skipped,
            clientCount = report.clientCount,
        })
        finish(report)
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
            impactPosition: { number },
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
            selectedWeapon: string,
            roundId: number,
            phase: string,
            pendingProjectiles: number,
            readinessJSON: string,
            fireGeometryJSON: string,
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
                impactPosition = { impact.position.X, impact.position.Y, impact.position.Z },
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
        local receiptGeometry = "invalid/nonfinite target"
        local x, y, z = fields.x, fields.y, fields.z
        if
            type(x) == "number"
            and type(y) == "number"
            and type(z) == "number"
            and x == x
            and y == y
            and z == z
            and math.abs(x) < math.huge
            and math.abs(y) < math.huge
            and math.abs(z) < math.huge
        then
            receiptGeometry = p17FireGeometry(runtime, selected, Vector3.new(x, y, z))
        end
        local roundSnapshot = runtime.rounds.match.snapshot()
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
            selectedWeapon = selected,
            roundId = roundSnapshot.roundId,
            phase = tostring(roundSnapshot.phase),
            pendingProjectiles = runtime.combat.resources().projectiles,
            readinessJSON = if type(readiness) == "string" then readiness else "unavailable",
            fireGeometryJSON = receiptGeometry,
            gauAmmo = if profile then profile.ammo else nil,
            gauNextFire = if profile then profile.nextFire else nil,
        })
    end)
    local burstTiming: { [number]: unknown } = {}
    local transport = Instance.new("RemoteEvent")
    transport.Name = "P17ManualHarness"
    local ready: { [Player]: boolean } = {}
    local replies: { [number]: { player: Player, ok: boolean, message: string } } = {}
    local token, fireSequence, selectSequence = 0, 0, 0
    local listener = transport.OnServerEvent:Connect(
        function(
            player: Player,
            id: unknown,
            ok: unknown,
            message: unknown,
            baseline: unknown,
            diagnostic: unknown
        )
            if id == 0 then
                assert(type(baseline) == "string", "P17 raw client baseline unavailable")
                local decoded = HttpService:JSONDecode(baseline)
                assert(
                    decoded.userId == player.UserId
                        and decoded.discovered > 0
                        and decoded.passed == decoded.discovered
                        and decoded.failed == 0
                        and decoded.skipped == 0
                        and decoded.errors == 0,
                    "P17 baseline failed"
                )
                clientBaselines[tostring(player.UserId)] = baseline
                assert(
                    type(diagnostic) == "string" and #diagnostic < 16000,
                    "bounded startup diagnostic absent"
                )
                clientDiagnostics[tostring(player.UserId)] = diagnostic
                ready[player] = true
                local readyIds: { number } = {}
                for actualPlayer, isReady in ready do
                    if isReady then
                        table.insert(readyIds, actualPlayer.UserId)
                    end
                end
                table.sort(readyIds)
                workspace:SetAttribute(
                    "P17ManualTransportReady",
                    HttpService:JSONEncode({
                        readyUserIds = readyIds,
                        readyCount = #readyIds,
                        actualPlayers = #Players:GetPlayers(),
                        serverTime = workspace:GetServerTimeNow(),
                    })
                )
            elseif
                type(id) == "number"
                and ok == "P17PreloadRecord"
                and type(message) == "string"
                and #message < 800000
            then
                preloadRecords[id] = message
            elseif
                type(id) == "number"
                and ok == "P17PanelMismatch"
                and type(message) == "string"
                and #message < 800000
            then
                panelMismatchRecords[id] = message
            elseif type(id) == "number" and ok == "BurstTiming" and type(message) == "table" then
                burstTiming[id] = message
            elseif type(id) == "number" then
                replies[id] = { player = player, ok = ok == true, message = tostring(message) }
            end
        end
    )
    transport.Parent = ReplicatedStorage
    local function probe(player: Player, kind: string, payload: unknown, captureReply: ((string) -> ())?)
        waitFor(function()
            return ready[player] == true
        end, "client P07 listener", 25)
        token += 1
        local current = token
        transport:FireClient(player, current, kind, payload)
        waitFor(function()
            return replies[current] ~= nil
        end, "probe reply", if kind == "P17Preload" then 120 else 35)
        local reply = replies[current]
        replies[current] = nil

        if kind == "P17Preload" then
            table.insert(observations, {
                kind = "native-mesh-instance-preload-and-surface-streaming-gap",
                userId = player.UserId,
                replyOk = reply.ok,
                detail = preloadRecords[current] or reply.message,
            })
            preloadRecords[current] = nil
        end
        if kind == "Panels" and not reply.ok then
            table.insert(observations, {
                kind = "actual-client-panel-mismatch",
                userId = player.UserId,
                detail = panelMismatchRecords[current] or reply.message,
            })
            panelMismatchRecords[current] = nil
        end
        assert(reply.player == player, "fixture reply sender mismatch")
        if captureReply then
            captureReply(reply.message)
        end
        assert(reply.ok, reply.message)
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
            local materialSolidPoints, earnedOpeningPoint = p17MaterialSamples(model, state.appearance)
            table.insert(result, {
                materialSolidPoints = materialSolidPoints,
                earnedOpeningPoint = earnedOpeningPoint,
                id = id,
                stage = ({ "Intact", "Damaged", "Destroyed" })[state.stage + 1],
                progress = state.progress,
                appearance = state.appearance,
                heavySeconds = state.heavySeconds,
                sustainedSeconds = state.sustainedSeconds,
                parts = #model:GetChildren(),
                geometryJSON = p17Geometry(model),
                pivot = { pose(id):GetComponents() },
                size = size,
                assetFamily = if type(model:GetAttribute("PanelAssetFamily")) == "string"
                    then model:GetAttribute("PanelAssetFamily") :: string
                    else nil,
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
    -- v7 fixture treatment: sample ONLY the target's current registered query
    -- geometry. A moving canonical orbit can hide yesterday's residual point
    -- behind stable beams; this selects a new aim, never a different panel/hit.
    -- At most128 candidates/pass,8s total after normal readiness, <=12 sphere
    -- queries between yields. Forecasts add a0.4s handoff margin; the current
    -- production sweep/view are checked again synchronously before Fire.
    local function remainingRoofAim(id: string, sequence: number): (Vector3, { [string]: unknown })
        awaitReady("M102")
        local model = panel(id)
        local candidates: { Vector3 } = {}
        local parts: { BasePart } = {}
        for _, item in model:GetDescendants() do
            if item:IsA("BasePart") and item.CanQuery and runtime.destruction.identify(item) == id then
                table.insert(parts, item)
            end
        end
        table.sort(parts, function(a, b)
            return a.Name < b.Name
        end)
        local inset = CombatService.profiles.M102.collisionRadius + 0.5
        local minimumInset = inset
        for _, part in parts do
            local axes = { part.CFrame.RightVector, part.CFrame.UpVector, part.CFrame.ZVector }
            local size = { part.Size.X, part.Size.Y, part.Size.Z }
            local vertical = 1
            for axis = 2, 3 do
                if math.abs(axes[axis].Y) > math.abs(axes[vertical].Y) then
                    vertical = axis
                end
            end
            assert(math.abs(axes[vertical].Y) > 0.99, "native roof query face is not horizontal")
            local horizontal = {}
            for axis = 1, 3 do
                if axis ~= vertical then
                    table.insert(horizontal, axis)
                end
            end
            local u, v = horizontal[1], horizontal[2]
            -- Approved Heavy roofs contain32 one-stud jagged proxy bands.
            -- Sample their narrow centers and three positions along the wide
            -- axis:96 Heavy points, not an unbounded/full-face grid.
            local uInset, vInset = math.min(inset, size[u] / 4), math.min(inset, size[v] / 4)
            assert(
                uInset > CombatService.profiles.M102.collisionRadius
                    and vInset > CombatService.profiles.M102.collisionRadius,
                "native roof residual has no safe interior"
            )
            minimumInset = math.min(minimumInset, uInset, vInset)
            local fractionsU: { number } = if size[v] >= 2 * size[u] then { 0.5 } else { 0.5, 0.25, 0.75 }
            local fractionsV: { number } = if size[u] >= 2 * size[v] then { 0.5 } else { 0.5, 0.25, 0.75 }
            for _, fu in fractionsU do
                for _, fv in fractionsV do
                    local localPoint = { 0, 0, 0 }
                    localPoint[vertical] = size[vertical] / 2 * (if axes[vertical].Y > 0 then 1 else -1)
                    localPoint[u] = -size[u] / 2 + uInset + (size[u] - 2 * uInset) * fu
                    localPoint[v] = -size[v] / 2 + vInset + (size[v] - 2 * vInset) * fv
                    table.insert(
                        candidates,
                        part.CFrame:PointToWorldSpace(
                            Vector3.new(localPoint[1], localPoint[2], localPoint[3])
                        )
                    )
                    assert(#candidates <= 128, "native roof aim exceeds explicit candidate bound")
                end
            end
        end
        assert(#candidates > 0, "native roof has no registered residual query geometry")
        local started, tries, queries = os.clock(), 0, 0
        local rejected: { { point: { number }, forecastSeconds: number, firstPath: string, firstPanelId: string? } } =
            {}
        local epoch = ReplicatedStorage.AircraftState:GetAttribute("EpochSeconds")
        assert(type(epoch) == "number", "native roof forecast epoch unavailable")
        repeat
            for _, point in candidates do
                if os.clock() - started >= 8 then
                    break
                end
                tries += 1
                local params = fireParameters()
                local muzzle = assert(runtime.aircraft.muzzle("M102"), "native roof muzzle unavailable")
                local localMuzzle = workspace.Aircraft:GetPivot():PointToObjectSpace(muzzle)
                local now = workspace:GetServerTimeNow()
                local clear = command("M102", point, sequence) ~= nil
                for step = 0, 4 do
                    if not clear then
                        break
                    end
                    local sampleMuzzle = muzzle
                    if step > 0 then
                        local predicted = assert(
                            AircraftRules.pose(
                                MapRules.defaults,
                                AircraftRules.defaults,
                                now - epoch + step * 0.1
                            ),
                            "native roof forecast unavailable"
                        )
                        local camera = Vector3.new(predicted.x, predicted.y, predicted.z)
                        local frame = CFrame.lookAt(
                            camera,
                            camera + Vector3.new(predicted.tangentX, 0, predicted.tangentZ)
                        )
                        sampleMuzzle = frame:PointToWorldSpace(localMuzzle)
                        clear = command("M102", point, sequence, camera) ~= nil
                    end
                    if clear then
                        local first = aimHit("M102", point, sampleMuzzle, params)
                        queries += 1
                        clear = first ~= nil and runtime.destruction.identify(first.Instance) == id
                        if not clear and #rejected < 8 then
                            table.insert(rejected, {
                                point = { point.X, point.Y, point.Z },
                                forecastSeconds = step * 0.1,
                                firstPath = if first then first.Instance:GetFullName() else "none",
                                firstPanelId = if first
                                    then runtime.destruction.identify(first.Instance)
                                    else nil,
                            })
                        end
                    end
                end
                if clear then
                    -- Every yield, forecast and readiness wait precedes this
                    -- final actual-current first-hit/view check. No query result
                    -- is converted into damage or a claimed accepted impact.
                    local currentMuzzle =
                        assert(runtime.aircraft.muzzle("M102"), "native roof muzzle unavailable")
                    local first = aimHit("M102", point, currentMuzzle, fireParameters())
                    queries += 1
                    local payload = command("M102", point, sequence)
                    if payload and first and runtime.destruction.identify(first.Instance) == id then
                        table.insert(observations, {
                            kind = "native-heavy-bounded-aim",
                            panelId = id,
                            sequence = sequence,
                            candidates = #candidates,
                            tried = tries,
                            sphereQueries = queries,
                            elapsedSeconds = os.clock() - started,
                            currentFirstPath = first.Instance:GetFullName(),
                            currentFirstPanelId = id,
                            forecastHorizonSeconds = 0.4,
                            maximumEdgeInsetStuds = inset,
                            minimumAxisInsetStuds = minimumInset,
                            rejected = rejected,
                            point = { point.X, point.Y, point.Z },
                        })
                        return point, payload
                    end
                end
                if tries % 2 == 0 then
                    task.wait()
                end
            end
            task.wait(0.03)
        until os.clock() - started >= 8
        table.insert(observations, {
            kind = "native-heavy-aim-timeout",
            panelId = id,
            candidates = #candidates,
            tried = tries,
            sphereQueries = queries,
            elapsedSeconds = os.clock() - started,
            rejected = rejected,
        })
        error("no current roof residual has production first-hit/view and bounded handoff margin")
    end
    -- The third 21-shot burst can cross into Heavy while rounds are already in
    -- flight. Use the top of a common solid in every approved state, then require
    -- a first hit of that same actual panel along the canonical moving muzzle.
    -- Search uses a bounded eight-second budget and never moves cover or the plane.
    local function materialBurstAim(
        id: string,
        firstSequence: number,
        count: number
    ): (Vector3, number, number)
        awaitReady("GAU23")
        local model = panel(id)
        local familyId = model:GetAttribute("PanelAssetFamily")
        assert(type(familyId) == "string", "burst target requires an approved material family")
        local family = assert(p17Catalog[familyId], "burst material family missing")
        local basis = model:GetAttribute("PanelAssetBasis")
        assert(typeof(basis) == "CFrame", "burst roof basis missing")
        local frame = pose(id) * basis
        local normalY = frame.ZVector.Y
        assert(math.abs(normalY) > 0.99, "burst material query face is not horizontal")
        local top = family.size.Z / 2 * (if normalY > 0 then 1 else -1)
        local inset = CombatService.profiles.GAU23.collisionRadius + 0.1
        local function contains(rectangle: { number }, x: number, y: number): boolean
            return x >= rectangle[1] + inset
                and x <= rectangle[3] - inset
                and y >= rectangle[2] + inset
                and y <= rectangle[4] - inset
        end
        local function insideAppearance(appearance: string, x: number, y: number): boolean
            for _, rectangle in family.states[appearance].rectangles do
                if contains(rectangle, x, y) then
                    return true
                end
            end
            return false
        end
        local points: { Vector3 } = {}
        for _, rectangle in family.states.Heavy.rectangles do
            local y = (rectangle[2] + rectangle[4]) / 2
            for _, fraction in { 0.5, 0.25, 0.75 } do
                local x = rectangle[1] + (rectangle[3] - rectangle[1]) * fraction
                if
                    contains(rectangle, x, y)
                    and insideAppearance("Pristine", x, y)
                    and insideAppearance("Light", x, y)
                then
                    table.insert(points, frame:PointToWorldSpace(Vector3.new(x, y, top)))
                    assert(#points <= 128, "material burst aim exceeds explicit candidate bound")
                end
            end
        end
        assert(#points > 0, "material burst has no common solid across damage states")
        local epoch = ReplicatedStorage.AircraftState:GetAttribute("EpochSeconds")
        assert(type(epoch) == "number", "material burst forecast epoch unavailable")
        local actualMuzzle: Vector3 =
            assert(runtime.aircraft.muzzle("GAU23"), "material burst muzzle unavailable")
        local relativeMuzzle = workspace.Aircraft:GetPivot():PointToObjectSpace(actualMuzzle)
        local handoffSeconds = 0.4
        local horizonSeconds = handoffSeconds + (count - 1) * DestructionService.gapSeconds
        local steps = math.ceil(horizonSeconds / 0.1)
        local started, attempts, queries = os.clock(), 0, 0
        local rejected: { { firstPath: string, reason: string, offsetSeconds: number } } = {}
        repeat
            for _, point in points do
                if os.clock() - started >= 8 then
                    break
                end
                attempts += 1
                local from = workspace:GetServerTimeNow()
                local params = fireParameters()
                local clear = true
                for step = 0, steps do
                    local offset = step * horizonSeconds / steps
                    local predicted = assert(
                        AircraftRules.pose(MapRules.defaults, AircraftRules.defaults, from - epoch + offset),
                        "material burst forecast pose unavailable"
                    )
                    local camera = Vector3.new(predicted.x, predicted.y, predicted.z)
                    local aircraftFrame =
                        CFrame.lookAt(camera, camera + Vector3.new(predicted.tangentX, 0, predicted.tangentZ))
                    local hit =
                        aimHit("GAU23", point, aircraftFrame:PointToWorldSpace(relativeMuzzle), params)
                    queries += 1
                    local direct = hit ~= nil and runtime.destruction.identify(hit.Instance) == id
                    clear = direct and command("GAU23", point, firstSequence, camera, true) ~= nil
                    if queries % 12 == 0 then
                        task.wait()
                    end
                    if not clear then
                        if #rejected < 8 then
                            table.insert(rejected, {
                                firstPath = if hit then hit.Instance:GetFullName() else "none",
                                reason = if direct then "outside fixture view" else "first hit differs",
                                offsetSeconds = offset,
                            })
                        end
                        break
                    end
                end
                if clear and workspace:GetServerTimeNow() - from < handoffSeconds then
                    local muzzle =
                        assert(runtime.aircraft.muzzle("GAU23"), "material burst muzzle unavailable")
                    local current = aimHit("GAU23", point, muzzle, fireParameters())
                    if
                        current
                        and runtime.destruction.identify(current.Instance) == id
                        and command("GAU23", point, firstSequence, nil, true)
                    then
                        table.insert(observations, {
                            kind = "native-material-burst-bounded-aim",
                            panelId = id,
                            firstSequence = firstSequence,
                            candidates = #points,
                            tried = attempts,
                            sphereQueries = queries + 1,
                            forecastStartsAt = from,
                            forecastEndsAt = from + horizonSeconds,
                            forecastSampleSeconds = horizonSeconds / steps,
                            currentFirstPath = current.Instance:GetFullName(),
                            point = { point.X, point.Y, point.Z },
                            rejected = rejected,
                        })
                        return point, from, from + horizonSeconds
                    end
                end
            end
            task.wait(0.03)
        until os.clock() - started >= 8
        table.insert(observations, {
            kind = "native-material-burst-aim-timeout",
            panelId = id,
            candidates = #points,
            tried = attempts,
            sphereQueries = queries,
            rejected = rejected,
        })
        error("no common roof solid has production first-hit/view for the full burst")
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
    local originalPanels: { [string]: { pivot: CFrame, size: Vector3, pristineParts: number } } = {}
    local function allPanelStates(pristine: boolean): { PanelExpectation }
        local count = if workspace.World.Battlefield:GetAttribute("OutpostAssetRevision") == "p16-v1"
            then 188
            else 187
        assert(
            #allIds == count and runtime.destruction.resources().panels == count,
            "all-panel registry changed"
        )
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
                        and entry.parts == original.pristineParts
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
                        originalPanels[item.Name] =
                            { pivot = pose(item.Name), size = size, pristineParts = #item:GetChildren() }
                    end
                end
                table.sort(allIds)
                allPanelStates(true)
                local roofIds: { string } = {}
                for _, item in workspace.World.Battlefield:GetDescendants() do
                    if
                        item:IsA("Model")
                        and string.match(item.Name, "^Outpost_")
                        and string.find(item.Name, "Roof", 1, true)
                    then
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
        check(
            "P17MeshAvailability both actual clients preload actual managed mesh dependencies with explicit SurfaceAppearance streaming gap",
            function()
                local gallery = game:GetService("ServerStorage").Assets.MaterialPanels:Clone()
                gallery.Name = "P17NativeAssetProbe"
                for _, item in gallery:GetDescendants() do
                    if item:IsA("BasePart") then
                        item.CFrame += Vector3.new(1500, 100, 0)
                        item:SetAttribute("ThermalNonCover", true)
                    end
                end
                gallery.Parent = workspace
                local loaded, why = pcall(function()
                    for _, player in initialPlayers do
                        probe(player, "P17Preload", nil)
                    end
                end)
                gallery:Destroy()
                assert(loaded, why)
            end
        )
        check(
            "P17OutpostNavigation actual ground avatar walks internal stairs and exterior stairs balcony into upper floor",
            function()
                local player = assert(ground, "ground player unavailable")
                local character = assert(player.Character, "ground avatar unavailable")
                local humanoid = assert(character:FindFirstChildOfClass("Humanoid"), "humanoid unavailable")
                local root = character:FindFirstChild("HumanoidRootPart")
                assert(root and root:IsA("BasePart"), "root unavailable")
                root:SetNetworkOwner(nil)
                local routes = {}
                local internal = { Vector3.new(-10, 3.125, 19) }
                for index = 1, 16 do
                    table.insert(internal, Vector3.new(-10, 3.125 + index * 0.625, 15 - (index - 1) * 2))
                end
                table.insert(internal, Vector3.new(-10, 13.125, -20))
                table.insert(internal, Vector3.new(-2, 13.125, -20))
                local external = { Vector3.new(19.5, 3.0, 31) }
                for index = 1, 20 do
                    table.insert(external, Vector3.new(19.5, 3.125 + index * 0.5, 29 - index))
                end
                for _, z in { 8, 4, 0, -4, -8, -12, -16 } do
                    table.insert(external, Vector3.new(19.5, 13.125, z))
                end
                table.insert(external, Vector3.new(13.5, 13.125, -16))
                local routePoints: { [string]: { Vector3 } } = { internal = internal, external = external }
                for name, points in routePoints do
                    character:PivotTo(CFrame.new(Vector3.new(144, 0, 164) + points[1]))
                    root.AssemblyLinearVelocity = Vector3.zero
                    root.AssemblyAngularVelocity = Vector3.zero
                    task.wait(0.4)
                    local began = os.clock()
                    for index = 2, #points do
                        local goal = Vector3.new(144, 0, 164) + points[index]
                        humanoid:MoveTo(goal)
                        waitFor(function()
                            return (root.Position - goal).Magnitude < 2
                        end, "P17 " .. name .. " walk waypoint " .. index, 12)
                    end
                    assert(root.Position.Y > 12, "walk never reached upper floor")
                    routes[name] = {
                        waypoints = #points,
                        seconds = os.clock() - began,
                        finalPosition = { root.Position.X, root.Position.Y, root.Position.Z },
                    }
                end
                root:SetNetworkOwnershipAuto()
                table.insert(observations, {
                    kind = "actual-outpost-humanoid-navigation",
                    routes = routes,
                    teleports = "initial route placement only; MoveTo between every waypoint",
                })
            end
        )
        check(
            "P17MaterialPanelStates all six actual families replicate Pristine Light Heavy Total and physical geometry to both actual clients",
            function()
                assert(
                    #impactFacts == 0,
                    "unexpected native fire contaminated controlled service-outcome stage fixture"
                )
                local byFamily: { [string]: string } = {}
                for _, model in workspace.World.Battlefield.Buildings.Outpost.Outpost_Panels:GetChildren() do
                    local family = model:GetAttribute("PanelAssetFamily")
                    if type(family) == "string" and not byFamily[family] then
                        byFamily[family] = model.Name
                    end
                end
                local familyCount = 0
                local shot = 0
                for family, id in byFamily do
                    familyCount += 1
                    local initialSolidPoints, earnedPoint = p17MaterialSamples(panel(id), "Pristine")
                    assert(initialSolidPoints and earnedPoint, "approved independent ray samples absent")
                    for _, player in initialPlayers do
                        probe(player, "Panels", expected({ id }))
                    end
                    table.insert(observations, {
                        kind = "approved-material-stage-ray-replication",
                        family = family,
                        panelId = id,
                        hit = 0,
                        appearance = "Pristine",
                        earnedPoint = { earnedPoint.X, earnedPoint.Y, earnedPoint.Z },
                        solidSamples = #initialSolidPoints,
                        bothActualClients = true,
                    })
                    for hit = 1, 6 do
                        shot += 1
                        assert(
                            runtime.destruction.resolve({
                                roundId = runtime.rounds.match.snapshot().roundId,
                                shotId = shot,
                                weapon = "M102",
                                firedAt = shot * 4,
                                panelId = id,
                            }),
                            "accepted service outcome rejected"
                        )
                        runtime.destruction.flush(workspace:GetServerTimeNow())
                        local appearance = if hit < 3 then "Light" elseif hit < 6 then "Heavy" else "Total"
                        assert(
                            panel(id):GetAttribute("DamageAppearance") == appearance,
                            "material altered threshold"
                        )
                        for _, player in initialPlayers do
                            probe(player, "Panels", expected({ id }))
                        end
                        local residualPoints = p17MaterialSamples(panel(id), appearance)
                        table.insert(observations, {
                            kind = "approved-material-stage-ray-replication",
                            family = family,
                            panelId = id,
                            hit = hit,
                            appearance = appearance,
                            earnedPoint = { earnedPoint.X, earnedPoint.Y, earnedPoint.Z },
                            solidSamples = if residualPoints then #residualPoints else 0,
                            bothActualClients = true,
                        })
                    end
                    table.insert(observations, {
                        kind = "six-family-actual-replication",
                        family = family,
                        panelId = id,
                        hits = 6,
                        source = "controlled accepted service outcomes; native-fired roof is separate",
                    })
                end
                assert(familyCount == 6, "material family absent")
                local round = runtime.rounds.match.snapshot().roundId
                assert(
                    runtime.rounds.match.abort(round, "P17StageFixtureReset"),
                    "fixture reset abort failed"
                )
                waitFor(function()
                    return runtime.rounds.match.snapshot().phase == "Lobby"
                end, "P17 fixture pristine reset", 35)
                assert(runtime.rounds.match.deploy(), "P17 redeploy failed")
                waitFor(function()
                    return runtime.rounds.match.snapshot().phase == "Active"
                end, "P17 redeployed round", 35)
                for _, player in initialPlayers do
                    if player:GetAttribute("Role") == "Gunship" then
                        op = player
                    else
                        ground = player
                    end
                    probe(player, "Panels", allPanelStates(true))
                end
            end
        )
        local operator = assert(op, "fresh operator missing")
        check("A7 actual six direct 105mm hits show progress third-hit hole and sixth-hit removal", function()
            local launches = {}
            table.insert(observations, {
                kind = "native-heavy-diagnostic",
                launches = launches,
                impacts = impactFacts,
                receipts = receipts,
            })
            selectWeapon(operator, "M102")
            local id = testedIds[1]
            local actualTargetHits, lastActualShotId = 0, 0
            for hit = 1, 6 do
                if hit > 1 then
                    task.wait(4.05)
                end
                fireSequence += 1
                local point, firePayload = remainingRoofAim(id, fireSequence)
                local factStart = #impactFacts
                table.insert(launches, {
                    hit = hit,
                    sequence = fireSequence,
                    panelId = id,
                    roundId = runtime.rounds.match.snapshot().roundId,
                    selected = runtime.aircraft.weapon(),
                    readiness = ReplicatedStorage.AircraftState:GetAttribute("Readiness"),
                    geometry = p17FireGeometry(runtime, "M102", point),
                })
                probe(operator, "Fire", firePayload)
                local expectedStage = if hit < 3 then "Intact" elseif hit < 6 then "Damaged" else "Destroyed"
                local expectedProgress = if hit == 6 then 1 else (hit % 3) / 3
                waitFor(function()
                    return panel(id):GetAttribute("PanelState") == expectedStage
                        and math.abs(
                                (panel(id):GetAttribute("PanelProgress") :: number) - expectedProgress
                            )
                            < 1e-5
                end, "heavy hit " .. hit, 8)
                assert(
                    #impactFacts == factStart + 1,
                    "heavy launch did not resolve exactly one actual impact"
                )
                local actualImpact = impactFacts[factStart + 1]
                assert(
                    actualImpact.weapon == "M102"
                        and actualImpact.panelId == id
                        and actualImpact.shotId > lastActualShotId,
                    "heavy launch did not directly hit the selected panel"
                )
                actualTargetHits += 1
                lastActualShotId = actualImpact.shotId
                table.insert(observations, {
                    actualShotId = actualImpact.shotId,
                    actualPanelId = actualImpact.panelId,
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
            assert(actualTargetHits == 6, "six actual target-panel M102 impacts required")
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
                local point, forecastStartsAt, forecastEndsAt = materialBurstAim(id, firstSequence, 21)
                local burstRecord: { [string]: unknown } = { index = burst, firstFactIndex = factStart + 1 }
                table.insert(bursts, burstRecord)
                fireSequence += 21
                local timingToken = probe(operator, "Burst", {
                    point = point,
                    roundId = runtime.rounds.match.snapshot().roundId,
                    firstSequence = firstSequence,
                    count = 21,
                    cadence = 0.18,
                })
                burstRecord.clientSends = burstTiming[timingToken]
                burstTiming[timingToken] = nil
                waitFor(function()
                    return #impactFacts >= factStart + 21 and runtime.combat.resources().projectiles == 0
                end, "21 actual on-panel burst impacts", 8)
                local ordered: { typeof(impactFacts[1]) } = {}
                for index = factStart + 1, #impactFacts do
                    local fact = impactFacts[index]
                    assert(
                        fact.weapon == "GAU23" and fact.panelId == id,
                        string.format(
                            "burst %d shot %d hit %s instead of %s",
                            burst,
                            fact.shotId,
                            fact.panelId or "unregistered geometry",
                            id
                        )
                    )
                    table.insert(ordered, fact)
                    if not transition and fact.stage == 1 then
                        transition = fact
                    end
                end
                assert(#ordered == 21, "bounded burst did not produce 21 actual impacts")
                table.sort(ordered, function(a, b)
                    return a.shotId < b.shotId
                end)
                local first, last = ordered[1], ordered[#ordered]
                burstRecord.firstAcceptedAt = first.firedAt
                burstRecord.lastAcceptedAt = last.firedAt
                assert(
                    first.firedAt >= forecastStartsAt and last.firedAt <= forecastEndsAt,
                    "actual burst was outside the verified fire window"
                )
                assert(first.scoredThroughShotId == first.shotId, "no isolated first-impact scoring snapshot")
                assert(
                    first.earnedSeconds
                        and math.abs(first.earnedSeconds - before.sustainedSeconds) < 1e-7
                        and first.stage == before.stage,
                    "first resumed impact earned paused/off-target time"
                )
                for index, fact in ordered do
                    if index > 1 then
                        local previous = ordered[index - 1]
                        local gap = fact.firedAt - previous.firedAt
                        assert(
                            fact.shotId == previous.shotId + 1
                                and gap + 1e-9 >= CombatService.profiles.GAU23.cadence
                                and gap <= DestructionService.gapSeconds + 1e-7,
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
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            assert(root and root:IsA("BasePart") and humanoid, "Ground avatar assembly missing")
            local canSetOwnership, ownershipReason = root:CanSetNetworkOwnership()
            assert(canSetOwnership, ownershipReason)
            local original = character:GetPivot()
            local originalServerPosition = root.Position
            local originalOwner = root:GetNetworkOwner()
            local originalAutomatic = root:GetNetworkOwnershipAuto()
            local originalLinear = root.AssemblyLinearVelocity
            local originalAngular = root.AssemblyAngularVelocity
            local groundY = wallPoint.Y - 1
            local start = Vector3.new(wallPoint.X, groundY, wallPoint.Z) + normal * 6
            local goal = Vector3.new(wallPoint.X, groundY, wallPoint.Z) - normal * 6
            local function coordinates(point: Vector3): { number }
                return { point.X, point.Y, point.Z }
            end
            local function owner()
                local current = root:GetNetworkOwner()
                return {
                    automatic = root:GetNetworkOwnershipAuto(),
                    userId = if current then current.UserId else nil,
                }
            end
            local walkObservation: { [string]: unknown } = {
                kind = "actual-humanoid-opening",
                panelId = wallId,
                userId = groundPlayer.UserId,
                serverObservationBudgetSeconds = 2,
                originalPositionStuds = coordinates(originalServerPosition),
                originalOwnership = owner(),
                requestedStartPositionStuds = coordinates(start),
                goalPositionStuds = coordinates(goal),
            }
            -- Preserve actual positions even if either the client movement or
            -- bounded server-replication observation fails. Never place at goal.
            table.insert(observations, walkObservation)
            local startedAt = os.clock()
            local observationStartedAt: number? = nil
            local function capture(field: string, message: string)
                local decoded, record = pcall(function()
                    return HttpService:JSONDecode(message)
                end)
                walkObservation[field] = if decoded then record else message
            end
            local walked, walkFailure = pcall(function()
                -- Place the actual avatar under server ownership, then let its
                -- client confirm replication before handing off its assembly.
                root:SetNetworkOwner(nil)
                walkObservation.placementOwnership = owner()
                assert(
                    root:GetNetworkOwner() == nil and not root:GetNetworkOwnershipAuto(),
                    "server placement not owned"
                )
                character:PivotTo(CFrame.new(start))
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
                walkObservation.startServerPositionStuds = coordinates(root.Position)
                assert((root.Position - start).Magnitude < 2, "server Ground start placement differs")
                probe(groundPlayer, "Walk", { start = start }, function(message)
                    capture("clientPlacement", message)
                end)
                walkObservation.acknowledgedServerPositionStuds = coordinates(root.Position)
                assert(
                    (root.Position - start).Magnitude < 2,
                    "server Ground avatar left start before handoff"
                )
                root:SetNetworkOwner(groundPlayer)
                walkObservation.crossingOwnership = owner()
                assert(
                    root:GetNetworkOwner() == groundPlayer and not root:GetNetworkOwnershipAuto(),
                    "Ground client did not acquire crossing ownership"
                )
                probe(groundPlayer, "Walk", { start = start, goal = goal }, function(message)
                    capture("clientCrossing", message)
                end)
                walkObservation.clientReplyAfterSeconds = os.clock() - startedAt
                walkObservation.clientReplyServerPositionStuds = coordinates(root.Position)
                observationStartedAt = os.clock()
                -- Client completion can precede its network-owned avatar's next
                -- server physics update. Require the real server state within a
                -- separate two-second fixture budget; timeout remains a failure.
                waitFor(function()
                    return groundPlayer.Character == character
                        and root:IsDescendantOf(workspace)
                        and root:GetNetworkOwner() == groundPlayer
                        and not root:GetNetworkOwnershipAuto()
                        and (root.Position - goal).Magnitude < 2
                end, "actual server Ground traversal replication", 2)
                return true
            end)
            walkObservation.finalServerPositionStuds = coordinates(root.Position)
            walkObservation.finalServerDistanceStuds = (root.Position - goal).Magnitude
            walkObservation.serverRootPresent = root:IsDescendantOf(workspace)
            local finalOwnerObserved, finalOwner = pcall(owner)
            walkObservation.finalServerOwnership = if finalOwnerObserved then finalOwner else nil
            walkObservation.elapsedSeconds = os.clock() - startedAt
            walkObservation.serverObservationElapsedSeconds = if observationStartedAt
                then os.clock() - observationStartedAt
                else nil
            walkObservation.passed = walked
            walkObservation.failure = if walked then nil else tostring(walkFailure)
            -- Reclaim the assembly before restoring placement and motion. Run
            -- cleanup after every outcome, including either bounded timeout.
            local restored, restoreFailure = pcall(function()
                assert(
                    character:IsDescendantOf(workspace) and root:IsDescendantOf(character),
                    "crossing avatar lost before restoration"
                )
                root:SetNetworkOwner(nil)
                humanoid:Move(Vector3.zero)
                character:PivotTo(original)
                root.AssemblyLinearVelocity = originalLinear
                root.AssemblyAngularVelocity = originalAngular
                walkObservation.restoredServerPositionStuds = coordinates(root.Position)
                if originalAutomatic then
                    root:SetNetworkOwnershipAuto()
                else
                    root:SetNetworkOwner(originalOwner)
                end
                walkObservation.restoredOwnership = owner()
                assert(
                    (root.Position - originalServerPosition).Magnitude < 0.01,
                    "Ground position not restored"
                )
                assert(
                    root:GetNetworkOwnershipAuto() == originalAutomatic,
                    "Ground ownership mode not restored"
                )
                assert(
                    originalAutomatic or root:GetNetworkOwner() == originalOwner,
                    "Ground manual owner not restored"
                )
            end)
            walkObservation.restored = restored
            walkObservation.restoreFailure = if restored then nil else tostring(restoreFailure)
            assert(restored, tostring(restoreFailure))
            assert(walked, tostring(walkFailure))
        end)
        check(
            "A6 current state reaches both initial clients and prior fragments expire before current-state comparisons",
            function()
                -- One real heavy impact leaves a separate accumulating panel.
                selectWeapon(operator, "M102")
                fireSequence += 1
                local id = testedIds[3]
                local _, payload = remainingRoofAim(id, fireSequence)
                local factStart = #impactFacts
                probe(operator, "Fire", payload)
                waitFor(function()
                    return panel(id):GetAttribute("PanelProgress") == 1 / 3
                end, "accumulating panel")
                assert(#impactFacts == factStart + 1, "accumulating panel needs exactly one physical impact")
                local actualImpact = impactFacts[factStart + 1]
                assert(
                    actualImpact.weapon == "M102" and actualImpact.panelId == id,
                    "accumulating shot did not directly hit the selected panel"
                )
                table.insert(observations, {
                    kind = "actual-heavy-accumulating-panel",
                    panelId = id,
                    shotId = actualImpact.shotId,
                    positionStuds = actualImpact.impactPosition,
                })
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
