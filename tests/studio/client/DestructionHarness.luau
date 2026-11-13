--!strict
-- P07 test-only real-client probes. Sends only production aim/selection intent.
-- Panel assertions inspect replicated current state/rays; they do not award damage.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Pan = require(ReplicatedStorage.Shared.AircraftPanRules)
local Aircraft = require(ReplicatedStorage.Shared.AircraftRules)
local Map = require(ReplicatedStorage.Shared.MapRules)
local Camera = require(Players.LocalPlayer.PlayerScripts.Client.ThermalCameraController)
local Harness = {}
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
    if entry.stage == "Intact" then
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
        local transport = ReplicatedStorage:WaitForChild("P07Harness", 600)
        if not transport or not transport:IsA("RemoteEvent") then
            return
        end
        local listener = transport.OnClientEvent:Connect(
            function(token: number, kind: string, payload: unknown)
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
                    elseif kind == "Panels" then
                        assert(type(payload) == "table", "expected panel observations")
                        local expected = payload :: { PanelExpectation }
                        assert(#expected >= 1 and #expected <= 187, "unbounded panel observation batch")
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
                        assert(matched, "P07 client timeout: " .. mismatch .. " state/credit/pivot/opening")
                    elseif kind == "Walk" then
                        assert(typeof(payload) == "Vector3", "walking goal missing")
                        local character = Players.LocalPlayer.Character
                        local humanoid = if character
                            then character:FindFirstChildOfClass("Humanoid")
                            else nil
                        local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
                        assert(humanoid and root and root:IsA("BasePart"), "actual ground avatar unavailable")
                        humanoid:MoveTo(payload)
                        waitFor(function()
                            return (root.Position - payload).Magnitude < 2
                        end, "actual Humanoid through opening")
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
                transport:FireServer(token, ok, if ok then "ok" else tostring(failure))
            end
        )
        transport.AncestryChanged:Connect(function()
            if not transport:IsDescendantOf(ReplicatedStorage) then
                listener:Disconnect()
            end
        end)
        transport:FireServer(0, true, "ready")
    end)
end
return Harness
