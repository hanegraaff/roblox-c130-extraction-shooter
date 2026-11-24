--!strict
--[=[
    P17MaterialHarness: test-only actual-client observer and intent sender.
    run() nonyieldingly schedules a bounded wait for the owned P17 transport.
    Commands use production remotes; observations inspect real replicated panels,
    rays, native MeshSize/fidelities and compiled material metadata. PreloadAsync
    proves callback availability only; SurfaceAppearance streaming/rendering is
    explicitly separate. The listener disconnects when its transport is removed.
    Opening traversal observes the placed Ground avatar before issuing MoveTo.
    No client response authorizes gameplay damage or ownership.
]=]
-- Historical executable body below remains byte-bound to the P17 evidence.
-- Reject module loading before that body can allocate listeners/runtime owners.
require(game:GetService("ReplicatedStorage").HarnessCompatibility).assertCurrent("P17")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Pan = require(ReplicatedStorage.Shared.AircraftPanRules)
local Aircraft = require(ReplicatedStorage.Shared.AircraftRules)
local Map = require(ReplicatedStorage.Shared.MapRules)
local Camera = require(Players.LocalPlayer.PlayerScripts.Client.ThermalCameraController)
local HttpService = game:GetService("HttpService")
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
local function p17GeometryMatches(model: Model, encoded: string): boolean
    local expected = HttpService:JSONDecode(encoded)
    local parts = {}
    local count = 0
    for _, child in model:GetChildren() do
        if child:IsA("BasePart") then
            parts[child.Name] = child
            count += 1
        end
    end
    if count ~= #expected then
        return false
    end
    for _, entry in expected do
        local part = parts[entry.name]
        if
            not part
            or part.ClassName ~= entry.class
            or part.CanCollide ~= entry.collide
            or part.CanQuery ~= entry.query
            or part.CanTouch ~= entry.touch
        then
            return false
        end
        if (if part:IsA("MeshPart") then part.MeshId else "") ~= entry.mesh then
            return false
        end
        if part:IsA("MeshPart") and not AssetMesh.validate(part) then
            return false
        end
        local appearance = part:FindFirstChildOfClass("SurfaceAppearance")
        for _, name in { "ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap", "ColorPngSha256" } do
            local value = if appearance then appearance:GetAttribute("Compiled" .. name) else ""
            if value ~= entry["compiled" .. name] then
                return false
            end
        end
        if
            (if appearance then appearance:GetAttribute("MaterialMetadataVersion") else 0)
            ~= entry.materialMetadataVersion
        then
            return false
        end
        if (if appearance then appearance:GetAttribute("MaterialKey") else "") ~= entry.materialKey then
            return false
        end
        for index, value in { part.CFrame:GetComponents() } do
            if math.abs(value - entry.pose[index]) > 0.001 then
                return false
            end
        end
        for index, value in { part.Size.X, part.Size.Y, part.Size.Z } do
            if math.abs(value - entry.size[index]) > 0.001 then
                return false
            end
        end
        for index, value in { part.Color.R, part.Color.G, part.Color.B } do
            if math.abs(value - entry.color[index]) > 0.0001 then
                return false
            end
        end
    end
    return true
end

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

-- Own-panel filters isolate its real opening from other legitimate map cover.
-- Original thin-axis normals handle roofs and either wall orientation; Light
-- remains solid, Heavy has a center hole and remaining strip, Total is empty.
local function panelMatches(entry: PanelExpectation): boolean
    local model = workspace.World.Battlefield:FindFirstChild(entry.id, true)
    if not model or not model:IsA("Model") then
        return false
    end
    local credits: { [string]: number } = {
        PanelProgress = entry.progress,
        HeavySeconds = entry.heavySeconds,
        SustainedSeconds = entry.sustainedSeconds,
    }
    for attribute, value in credits do
        local actual = model:GetAttribute(attribute)
        if type(actual) ~= "number" or math.abs(actual - value) > 1e-5 then
            return false
        end
    end
    if
        model:GetAttribute("PanelId") ~= entry.id
        or model:GetAttribute("PanelState") ~= entry.stage
        or model:GetAttribute("DamageAppearance") ~= entry.appearance
        or #model:GetChildren() ~= entry.parts
        or (entry.appearance == "Pristine" and model:FindFirstChild("DamageVisuals") ~= nil)
    then
        return false
    end
    if entry.geometryJSON and not p17GeometryMatches(model, entry.geometryJSON) then
        return false
    end
    local pivot = CFrame.new(unpack(entry.pivot))
    local originalPivot = model:GetAttribute("IntactPivot")
    local size = model:GetAttribute("IntactSize")
    if typeof(originalPivot) ~= "CFrame" or typeof(size) ~= "Vector3" or size ~= entry.size then
        return false
    end
    for _, actualPivot in { originalPivot, model:GetPivot() } do
        for index, component in { actualPivot:GetComponents() } do
            if math.abs(component - entry.pivot[index]) > 0.01 then
                return false
            end
        end
    end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = { model }
    params.RespectCanCollide = true
    local normal = if size.Y <= math.min(size.X, size.Z)
        then pivot.UpVector
        elseif size.X < size.Z then pivot.RightVector
        else -pivot.LookVector
    local thickness = math.min(size.X, size.Y, size.Z)
    local function faceHit(point: Vector3): RaycastResult?
        return workspace:Raycast(point - normal * (thickness / 2 + 1), normal * (thickness + 2), params)
    end
    local centerHit = faceHit(pivot.Position)
    if entry.assetFamily then
        if
            model:GetAttribute("PanelAssetFamily") ~= entry.assetFamily
            or not entry.materialSolidPoints
            or not entry.earnedOpeningPoint
        then
            return false
        end
        -- These points come from approved catalog rectangles, transformed in the
        -- server identity/basis. The earned point was solid before damage and is
        -- absent in Heavy, even when the pristine center was already an aperture.
        local earnedHit = faceHit(entry.earnedOpeningPoint)
        if (earnedHit ~= nil) ~= (entry.stage == "Intact") then
            return false
        end
        for _, point in entry.materialSolidPoints do
            if not faceHit(point) then
                return false
            end
        end
        if entry.stage == "Intact" then
            local aperture = entry.assetFamily == "corrugated_window"
                or entry.assetFamily == "corrugated_door"
                or entry.assetFamily == "corrugated_garage"
            return #entry.materialSolidPoints > 0 and ((centerHit == nil) == aperture)
        end
        if centerHit then
            return false
        end
        return if entry.stage == "Damaged"
            then #entry.materialSolidPoints > 0
            else entry.stage == "Destroyed" and #entry.materialSolidPoints == 0
    end
    if entry.stage == "Intact" then
        if entry.assetFamily then
            if model:GetAttribute("PanelAssetFamily") ~= entry.assetFamily then
                return false
            end
            local aperture = entry.assetFamily == "corrugated_window"
                or entry.assetFamily == "corrugated_door"
                or entry.assetFamily == "corrugated_garage"
            if (centerHit == nil) ~= aperture then
                return false
            end
            for _, solid in model:GetChildren() do
                if solid:IsA("BasePart") and solid.CanQuery and solid.CanCollide then
                    return faceHit(solid.Position) ~= nil
                end
            end
            return false
        end
        return centerHit ~= nil
    elseif centerHit then
        return false
    elseif entry.stage == "Damaged" then
        local strip = if size.X >= size.Z
            then pivot.RightVector * size.X * 0.375
            else -pivot.LookVector * size.Z * 0.375
        return faceHit(pivot.Position + strip) ~= nil
    end
    return entry.stage == "Destroyed"
end

-- Constructs bounded intent from the CURRENT canonical pose and production
-- camera basis. This is request generation only: the server still validates
-- view, role, cadence, ammunition, collision and structural credit independently.
local function currentIntent(point: Vector3, roundId: number, sequence: number): { [string]: unknown }
    local state = ReplicatedStorage:FindFirstChild("AircraftState")
    local epoch = if state then state:GetAttribute("EpochSeconds") else nil
    assert(type(epoch) == "number", "current canonical epoch unavailable")
    local map = Map.defaults
    local pose = assert(
        Aircraft.pose(map, Aircraft.defaults, workspace:GetServerTimeNow() - epoch),
        "current canonical pose unavailable"
    )
    local camera = Vector3.new(pose.x, pose.y, pose.z)
    local radial = Vector2.new(camera.X - map.centerX, camera.Z - map.centerZ).Unit
    local projected = camera + (point - camera) * (map.altitudeStuds / (camera.Y - point.Y))
    local offset = Vector2.new(projected.X - map.centerX, projected.Z - map.centerZ)
    local desired = {
        x = offset.X * radial.X + offset.Y * radial.Y,
        z = -offset.X * radial.Y + offset.Y * radial.X,
    }
    local aspect = 16 / 9
    local widest = assert(
        Pan.supportedFov(map, aspect, Aircraft.defaults.fov105mm),
        "supported fixture lens unavailable"
    )
    local home = assert(Pan.recenter(map, aspect, widest), "current fixture home unavailable")
    local tangent = math.tan(math.rad(math.min(Aircraft.defaults.fov30mm, widest)) / 2)
    for sample = 0, 100 do
        local t = sample / 100
        local focus = { x = desired.x + (home.x - desired.x) * t, z = desired.z + (home.z - desired.z) * t }
        if Pan.viewFits(map, focus, aspect, widest) then
            local world =
                assert(Pan.worldFocus(map, focus, camera.X, camera.Z), "valid focus projection unavailable")
            local frame = assert(
                Camera.frame(camera, Vector3.new(world.x, map.groundY, world.z)),
                "production camera basis unavailable"
            )
            local localPoint = frame:PointToObjectSpace(point)
            local depth = -localPoint.Z
            if
                depth > 0
                and math.abs(localPoint.X / (depth * tangent * aspect)) <= 0.7
                and math.abs(localPoint.Y / (depth * tangent)) <= 0.7
            then
                return {
                    roundId = roundId,
                    sequence = sequence,
                    weapon = "GAU23",
                    x = point.X,
                    y = point.Y,
                    z = point.Z,
                    focusX = focus.x,
                    focusZ = focus.z,
                    aspect = aspect,
                    cameraX = camera.X,
                    cameraZ = camera.Z,
                }
            end
        end
    end
    error("current sustained target outside permitted fixture view")
end
local function waitFor(predicate: () -> boolean, label: string)
    local deadline = os.clock() + 8
    while not predicate() and os.clock() < deadline do
        task.wait(0.03)
    end
    assert(predicate(), "P07 client timeout: " .. label)
end
function Harness.run()
    task.spawn(function()
        local transport = ReplicatedStorage:WaitForChild("P17ManualHarness", 600)
        if not transport or not transport:IsA("RemoteEvent") then
            return
        end
        local listener = transport.OnClientEvent:Connect(
            function(token: number, kind: string, payload: unknown)
                local detail = "ok"
                local ok, failure = pcall(function()
                    if kind == "Fire" or kind == "Select" or kind == "Flood" then
                        local state = ReplicatedStorage:WaitForChild("AircraftState", 5)
                        assert(state, "aircraft state missing")
                        local remote =
                            state:FindFirstChild(if kind == "Select" then "SelectWeapon" else "FireWeapon")
                        assert(remote and remote:IsA("RemoteEvent"), "production remote missing")
                        if kind == "Flood" then
                            for _ = 1, 40 do
                                remote:FireServer(payload)
                            end
                        else
                            remote:FireServer(payload)
                        end
                    elseif kind == "Burst" then
                        assert(type(payload) == "table", "burst fixture missing")
                        local burst = payload :: {
                            point: Vector3,
                            roundId: number,
                            firstSequence: number,
                            count: number,
                            cadence: number,
                        }
                        assert(
                            typeof(burst.point) == "Vector3"
                                and burst.count >= 1
                                and burst.count <= 61
                                and burst.count % 1 == 0
                                and burst.cadence == 0.18,
                            "unbounded burst fixture"
                        )
                        local state = ReplicatedStorage:WaitForChild("AircraftState", 5)
                        local remote = if state then state:FindFirstChild("FireWeapon") else nil
                        assert(remote and remote:IsA("RemoteEvent"), "production fire remote missing")
                        local sent: { { sequence: number, sentAt: number } } = {}
                        local nextAt = workspace:GetServerTimeNow()
                        local burstOk, burstFailure = pcall(function()
                            for index = 1, burst.count do
                                while workspace:GetServerTimeNow() < nextAt do
                                    game:GetService("RunService").Heartbeat:Wait()
                                end
                                local sequence = burst.firstSequence + index - 1
                                local command = currentIntent(burst.point, burst.roundId, sequence)
                                local sentAt = workspace:GetServerTimeNow()
                                table.insert(sent, { sequence = sequence, sentAt = sentAt })
                                remote:FireServer(command)
                                -- A 30ms test send margin protects the 0.15s server
                                -- cadence without changing that rule or 0.225s gap.
                                nextAt = sentAt + burst.cadence
                            end
                            return true
                        end)
                        transport:FireServer(token, "BurstTiming", sent)
                        assert(burstOk, tostring(burstFailure))
                    elseif kind == "P17Preload" then
                        local provider = game:GetService("ContentProvider")
                        local gallery = workspace:FindFirstChild("P17NativeAssetProbe")
                        local outpost = workspace.World.Battlefield.Buildings.Outpost
                        assert(gallery, "actual asset gallery missing")
                        local ids = {}
                        local materialIds = {}
                        local meshes = 0
                        for _, root in { gallery, outpost } do
                            local rootMeshes = 0
                            for _, item in root:GetDescendants() do
                                if item:IsA("MeshPart") then
                                    rootMeshes += 1
                                    meshes += 1
                                    assert(
                                        AssetMesh.validate(item),
                                        "replicated native mesh constructor/fidelity mismatch"
                                    )
                                    ids[item.MeshId] = true
                                end
                                if item:IsA("SurfaceAppearance") then
                                    assert(
                                        item:GetAttribute("MaterialMetadataVersion") == 1,
                                        "compiled material metadata missing"
                                    )
                                    for _, name in { "ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap" } do
                                        local id = item:GetAttribute("Compiled" .. name)
                                        assert(type(id) == "string", "compiled material reference missing")
                                        if id ~= "" then
                                            materialIds[id] = true
                                        end
                                    end
                                end
                            end
                            assert(
                                rootMeshes == (if root == gallery then 76 else 2256),
                                "managed library or complete furnished Outpost mesh population differs"
                            )
                        end
                        local callbacks = 0
                        local callbackRecords = {}
                        local callbackFailures = {}
                        local callbackById = {}
                        provider:PreloadAsync(
                            { gallery, outpost },
                            function(id: string, state: Enum.AssetFetchStatus)
                                callbacks += 1
                                table.insert(callbackRecords, { id = id, state = state.Name })
                                callbackById[id] = state
                                if state ~= Enum.AssetFetchStatus.Success then
                                    table.insert(callbackFailures, { id = id, state = state.Name })
                                end
                            end
                        )
                        local failures = {}
                        local missingMeshCallbacks = {}
                        local count = 0
                        for id in ids do
                            count += 1
                            local state = provider:GetAssetFetchStatus(id)
                            if state ~= Enum.AssetFetchStatus.Success then
                                table.insert(failures, { id = id, state = state.Name })
                            end
                            if callbackById[id] ~= Enum.AssetFetchStatus.Success then
                                table.insert(missingMeshCallbacks, id)
                            end
                        end
                        local surfaceStatus = {}
                        for id in materialIds do
                            table.insert(
                                surfaceStatus,
                                { id = id, state = provider:GetAssetFetchStatus(id).Name }
                            )
                        end
                        detail = HttpService:JSONEncode({
                            meshInstances = meshes,
                            nativeConstructorChecks = meshes,
                            nativeConstructorAPI = "AssetMesh.validate: actual public MeshSize/fidelities versus compiled5metadata",
                            uniqueMeshIds = count,
                            preloadCallbacks = callbacks,
                            callbackRecords = callbackRecords,
                            callbackFailures = callbackFailures,
                            missingExpectedMeshSuccessCallbacks = missingMeshCallbacks,
                            postPreloadMeshStatusNonSuccess = failures,
                            surfaceCompiledIdStatus = surfaceStatus,
                            instanceMeshPreload = true,
                            surfaceAvailability = "UNVERIFIED: SurfaceAppearance texture packs are unsupported by PreloadAsync; rendered streaming must be checked separately",
                            materialComparison = "readable compiled metadata; actual protected SA slots independently verified in Edit",
                            apiSource = "https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/ContentProvider.yaml",
                        })
                        script:SetAttribute("P17ManualPreloadReport", detail)
                        transport:FireServer(token, "P17PreloadRecord", detail)
                        assert(
                            count > 0 and callbacks == meshes and #callbackFailures == 0,
                            "actual mesh preload missing or failed; full report sent separately"
                        )
                    elseif kind == "Panels" then
                        assert(type(payload) == "table", "expected panel observations")
                        local expected = payload :: { PanelExpectation }
                        assert(#expected >= 1 and #expected <= 188, "unbounded panel observation batch")
                        local mismatch = "unknown panel"
                        local function matches(): boolean
                            for index, entry in expected do
                                if not panelMatches(entry) then
                                    mismatch = entry.id
                                    return false
                                end
                                if index % 16 == 0 then
                                    task.wait() -- bounded real-query batches, one shared retry deadline
                                end
                            end
                            return true
                        end
                        local deadline = os.clock() + 8
                        local matched = matches()
                        while not matched and os.clock() < deadline do
                            task.wait(0.03)
                            matched = matches()
                        end
                        if not matched then
                            local actual = workspace.World.Battlefield:FindFirstChild(mismatch, true)
                            local target = nil
                            for _, entry in expected do
                                if entry.id == mismatch then
                                    target = entry
                                end
                            end
                            local values = {}
                            if actual then
                                for _, name in
                                    {
                                        "PanelId",
                                        "PanelAssetFamily",
                                        "PanelState",
                                        "PanelProgress",
                                        "DamageAppearance",
                                        "HeavySeconds",
                                        "SustainedSeconds",
                                        "IntactSize",
                                        "IntactPivot",
                                        "PanelAssetBasis",
                                    }
                                do
                                    values[name] = tostring(actual:GetAttribute(name))
                                end
                            end
                            local record = {
                                id = mismatch,
                                expected = if target
                                    then {
                                        stage = target.stage,
                                        appearance = target.appearance,
                                        progress = target.progress,
                                        heavySeconds = target.heavySeconds,
                                        sustainedSeconds = target.sustainedSeconds,
                                        parts = target.parts,
                                        pivot = target.pivot,
                                        size = { target.size.X, target.size.Y, target.size.Z },
                                        assetFamily = target.assetFamily,
                                        geometryJSON = target.geometryJSON,
                                    }
                                    else nil,
                                actualAttributes = values,
                                actualParts = if actual then #actual:GetChildren() else 0,
                                actualGeometryJSON = if actual and actual:IsA("Model")
                                    then p17Geometry(actual)
                                    else nil,
                                actualPivot = if actual and actual:IsA("Model")
                                    then { actual:GetPivot():GetComponents() }
                                    else nil,
                            }
                            local encoded = HttpService:JSONEncode(record)
                            script:SetAttribute("P17ManualPanelMismatch", encoded)
                            transport:FireServer(token, "P17PanelMismatch", encoded)
                        end
                        assert(matched, "P07 client timeout: " .. mismatch .. " state/credit/pivot/opening")
                    elseif kind == "Walk" then
                        assert(type(payload) == "table", "walking fixture missing")
                        local walk = payload :: { start: Vector3, goal: Vector3? }
                        local start, goal = walk.start, walk.goal
                        assert(typeof(start) == "Vector3", "walking start missing")
                        assert(goal == nil or typeof(goal) == "Vector3", "invalid walking goal")
                        local player = Players.LocalPlayer
                        local character = player.Character
                        local humanoid = if character
                            then character:FindFirstChildOfClass("Humanoid")
                            else nil
                        local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
                        assert(
                            character and humanoid and root and root:IsA("BasePart"),
                            "actual ground avatar unavailable"
                        )
                        local function live(): boolean
                            return player.Character == character
                                and root:IsDescendantOf(character)
                                and character:IsDescendantOf(workspace)
                                and player:GetAttribute("Role") == "Ground"
                                and humanoid.Health > 0
                        end
                        local function coordinates(point: Vector3): { number }
                            return { point.X, point.Y, point.Z }
                        end
                        local startedAt = os.clock()
                        local record: { [string]: unknown } = {
                            userId = player.UserId,
                            phase = if goal then "walk" else "placement",
                            initialPositionStuds = coordinates(root.Position),
                        }
                        local walked, walkFailure = pcall(function()
                            waitFor(function()
                                return live() and (root.Position - start).Magnitude < 2
                            end, "actual Ground start placement")
                            local observedStart = root.Position
                            record.startPositionStuds = coordinates(observedStart)
                            record.startDistanceStuds = (observedStart - start).Magnitude
                            if goal then
                                humanoid:MoveTo(goal)
                                waitFor(function()
                                    return live() and (root.Position - goal).Magnitude < 2
                                end, "actual Humanoid through opening")
                                local displacement = (root.Position - observedStart).Magnitude
                                record.displacementStuds = displacement
                                assert(displacement > (goal - start).Magnitude - 4, "avatar did not cross")
                            end
                        end)
                        record.finalPositionStuds = coordinates(root.Position)
                        record.finalDistanceStuds = (root.Position - (goal or start)).Magnitude
                        record.elapsedSeconds = os.clock() - startedAt
                        record.passed = walked
                        record.failure = if walked then nil else tostring(walkFailure)
                        detail = HttpService:JSONEncode(record)
                        if not walked then
                            error(detail, 0)
                        end
                    elseif kind == "NoFragments" then
                        waitFor(function()
                            local folder = workspace:FindFirstChild("PanelFragments")
                            return folder ~= nil and #folder:GetChildren() == 0
                        end, "expired debris/no historical burst")
                    elseif kind == "Spectator" then
                        local player = Players.LocalPlayer
                        waitFor(function()
                            return player:GetAttribute("Role") == "Spectator"
                                and player:GetAttribute("Life") == "Spectating"
                        end, "late spectator")
                        local backpack = player:FindFirstChildOfClass("Backpack")
                        assert(not backpack or #backpack:GetChildren() == 0, "spectator has equipment")
                    else
                        error("unknown P07 probe")
                    end
                end)
                transport:FireServer(token, ok, if ok then detail else tostring(failure))
            end
        )
        transport.AncestryChanged:Connect(function()
            if not transport:IsDescendantOf(ReplicatedStorage) then
                listener:Disconnect()
            end
        end)
        transport:FireServer(
            0,
            true,
            "ready",
            script.Parent:GetAttribute("ClientTestReport"),
            HttpService:JSONEncode({
                aimTelemetry = ReplicatedStorage.ClientSpecs["GroundAimGui.spec"]:GetAttribute(
                    "P06AimProjectionTelemetry"
                ),
                errors = script.Parent:GetAttribute("P17ManualTestErrors"),
                readyAtServerSeconds = workspace:GetServerTimeNow(),
            })
        )
    end)
end
return Harness
