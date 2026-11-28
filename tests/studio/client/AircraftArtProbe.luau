--!strict
--[=[
    AircraftArtProbe runs P28-only observations in a real Studio client.
    It checks replicated rig/masks and moving hub geometry. The optional Ground
    capture view tracks the aircraft from the current avatar's eye height.
]=]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local AircraftArtProbe = {}
type Request = { [string]: unknown }

function AircraftArtProbe.start(): ((Request) -> unknown, () -> ())
    local player = Players.LocalPlayer
    local tracking: Camera? = nil
    local originalType: Enum.CameraType? = nil
    local binding = "P28GroundAircraftCapture"
    local function release()
        RunService:UnbindFromRenderStep(binding)
        if tracking and originalType and tracking == workspace.CurrentCamera then
            tracking.CameraType = originalType
        end
        tracking, originalType = nil, nil
    end
    local function track(camera: Camera)
        if tracking == camera then
            return
        end
        release()
        tracking, originalType = camera, camera.CameraType
        camera.CameraType = Enum.CameraType.Scriptable
        RunService:BindToRenderStep(binding, Enum.RenderPriority.Camera.Value + 1, function()
            local aircraft = workspace:FindFirstChild("Aircraft")
            local head = if player.Character then player.Character:FindFirstChild("Head") else nil
            if aircraft and aircraft:IsA("Model") and head and head:IsA("BasePart") then
                camera.CFrame = CFrame.lookAt(head.Position, aircraft:GetPivot().Position)
            end
        end)
    end
    local function probe(request: Request): unknown
        local deadline = os.clock() + 5
        repeat
            local model = workspace:FindFirstChild("Aircraft")
            local hitbox = if model then model:FindFirstChild("Hitbox") else nil
            local propellers = if model then model:FindFirstChild("Propellers") else nil
            local camera = workspace.CurrentCamera
            if
                model
                and model:IsA("Model")
                and hitbox
                and hitbox:IsA("BasePart")
                and propellers
                and camera
                and model:GetAttribute("RoundId") == request.roundId
                and player:GetAttribute("Role") == request.role
            then
                local operator = request.role == "Gunship"
                local correctView = not operator or camera.FieldOfView == request.fov
                local visible = 0
                local maskErrors = 0
                for _, item in model:GetDescendants() do
                    if item:IsA("BasePart") and item.Transparency < 1 then
                        visible += 1
                        if item.LocalTransparencyModifier ~= (if operator then 1 else 0) then
                            maskErrors += 1
                        end
                    end
                end
                local hubs: { BasePart } = {}
                for _, rotor in propellers:GetChildren() do
                    local hub = rotor:FindFirstChild("Hub")
                    if hub and hub:IsA("BasePart") then
                        table.insert(hubs, hub)
                    end
                end
                if correctView and visible >= 180 and maskErrors == 0 and #hubs == 4 then
                    if request.track == true and not operator then
                        track(camera)
                    end
                    local previous: { Vector3 } = {}
                    for index, hub in hubs do
                        previous[index] = hitbox.CFrame:VectorToObjectSpace(hub.CFrame.RightVector)
                    end
                    local moving: { [number]: boolean } = {}
                    for _ = 1, 8 do
                        RunService.RenderStepped:Wait()
                        for index, hub in hubs do
                            local direction = hitbox.CFrame:VectorToObjectSpace(hub.CFrame.RightVector)
                            if previous[index]:Dot(direction) < 0.98 then
                                moving[index] = true
                            end
                        end
                    end
                    local rotating = 0
                    for _ in moving do
                        rotating += 1
                    end
                    assert(rotating == 4, "not all four native rotor hubs move")
                    local replicas = 0
                    for _, item in workspace:GetChildren() do
                        if item.Name == "Aircraft" then
                            replicas += 1
                        end
                    end
                    assert(replicas == 1, "client did not observe exactly one aircraft replica")
                    local pose = model:GetPivot()
                    return {
                        role = request.role,
                        roundId = request.roundId,
                        fov = camera.FieldOfView,
                        elapsedSeconds = workspace:GetServerTimeNow()
                            - model:GetAttribute("PropellersEpochSeconds") :: number,
                        position = { pose.X, pose.Y, pose.Z },
                        heading = { pose.LookVector.X, pose.LookVector.Y, pose.LookVector.Z },
                        visiblePieces = visible,
                        maskErrors = maskErrors,
                        rotating = rotating,
                        aircraftReplicas = replicas,
                    }
                end
            end
            RunService.RenderStepped:Wait()
        until os.clock() > deadline
        error("P28 timed out waiting for replicated artwork, role mask and zoom")
    end
    return probe, release
end

return AircraftArtProbe
