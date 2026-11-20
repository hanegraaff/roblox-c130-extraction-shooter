--!strict
--[=[
    GroundIndoorCamera: local Ground presentation on top of Roblox's Custom
    camera. Reads authored Battlefield room descriptors and local role/character
    state. Never changes the player's zoom settings, FOV, aim authority, or cover.
    One owner binds immediately before and after the stock camera; stop unbinds
    both callbacks and releases the last frame without taking over another camera.
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GroundCameraRules = require(ReplicatedStorage.Shared.GroundCameraRules)
local Validation = require(ReplicatedStorage.Shared.Validation)

local GroundIndoorCamera = {}
local BEFORE_CAMERA = "GroundIndoorCameraRestore"
local AFTER_CAMERA = "GroundIndoorCameraApply"
local CAMERA_PRIORITY = Enum.RenderPriority.Camera.Value
local ownerActive = false

-- A camera-only room descriptor; the frame's positive Y points at its ceiling.
export type Interior = {
    frame: CFrame,
    halfSize: Vector3,
    maxDistanceStuds: number,
}

type ModifiedFrame = { camera: Camera, subject: Humanoid, stock: CFrame, applied: CFrame }

-- Reads the optional room configurations. Malformed or unreplicated entries
-- contribute no distance cap. Results are sorted by name for stable overlap order.
function GroundIndoorCamera.readInteriors(folder: Instance): { Interior }
    local children = folder:GetChildren()
    table.sort(children, function(a, b)
        return a.Name < b.Name
    end)
    local interiors: { Interior } = {}
    for _, child in children do
        local frame = child:GetAttribute("Frame")
        local size = child:GetAttribute("Size")
        local distance = child:GetAttribute("MaxDistanceStuds")
        if
            not child:IsA("Configuration")
            or typeof(frame) ~= "CFrame"
            or typeof(size) ~= "Vector3"
            or not Validation.inRange(size.X, 1, 2048)
            or not Validation.inRange(size.Y, 1, 2048)
            or not Validation.inRange(size.Z, 1, 2048)
            or type(distance) ~= "number"
            or not Validation.inRange(distance, 2.5, 400)
        then
            continue
        end
        local finite = true
        for _, component in { frame:GetComponents() } do
            if not Validation.isFinite(component) then
                finite = false
                break
            end
        end
        if finite then
            table.insert(interiors, { frame = frame, halfSize = size / 2, maxDistanceStuds = distance })
        end
    end
    return interiors
end

-- Returns a frame along the stock focus ray. Preserves focus, orientation,
-- projection and stock collision corrections. A live room also constrains
-- steep upward camera positions below its ceiling plane.
function GroundIndoorCamera.frame(
    stock: CFrame,
    focus: Vector3,
    interior: Interior?,
    maxDistanceStuds: number,
    weight: number
): CFrame
    local offset = stock.Position - focus
    local distance = offset.Magnitude
    if distance <= 0.001 then
        return stock
    end
    local desired = GroundCameraRules.distance(distance, maxDistanceStuds, weight)
    if interior then
        local localFocus = interior.frame:PointToObjectSpace(focus)
        local localCamera = interior.frame:PointToObjectSpace(stock.Position)
        desired = math.min(
            desired,
            GroundCameraRules.ceilingDistance(distance, localFocus.Y, localCamera.Y, interior.halfSize.Y)
        )
    end
    return if desired < distance then stock + offset * (desired / distance - 1) else stock
end

-- Only a living ground player or the labelled, local Studio Ground preview
-- can shorten the player's own camera. Lobby/spectator/operator stay separate.
local function eligible(player: Player, state: Instance): boolean
    local phase = state:GetAttribute("Phase")
    if phase == "Active" then
        return player:GetAttribute("Role") == "Ground" and player:GetAttribute("Life") == "Alive"
    end
    return phase == "Lobby"
        and RunService:IsStudio()
        and player:GetAttribute("LocalMapPreview") == true
        and player:GetAttribute("LocalPreviewRole") == "Ground"
end

-- Starts the camera modifier for an existing round-state owner. Returns an
-- idempotent stop closure. The callbacks do not yield and require the live
-- Custom camera to target this local player's living humanoid.
function GroundIndoorCamera.start(player: Player, state: Instance): () -> ()
    assert(not ownerActive, "ground indoor camera already owned")
    ownerActive = true
    local running = true
    local modified: ModifiedFrame? = nil
    local roomFolder: Instance? = nil
    local folderAdded: RBXScriptConnection? = nil
    local folderRemoved: RBXScriptConnection? = nil
    local roomsDirty = false
    local rooms: { Interior } = {}
    local currentRoom: Interior? = nil
    local previousSubject: Humanoid? = nil
    local previousCamera: Camera? = nil
    local previousRound: unknown = nil
    local weight = 0
    local distanceCap = 0

    local function clearTransition()
        currentRoom = nil
        previousSubject = nil
        previousCamera = nil
        previousRound = nil
        distanceCap = 0
        weight = 0
    end

    local function restoreFrame()
        local previous = modified
        modified = nil
        if
            previous
            and previous.camera.CameraType == Enum.CameraType.Custom
            and previous.camera.CameraSubject == previous.subject
            and previous.camera.CFrame == previous.applied
        then
            previous.camera.CFrame = previous.stock
        end
    end

    local function markRoomsDirty()
        roomsDirty = true
    end

    local function changeRoomFolder(folder: Instance?)
        if folderAdded then
            folderAdded:Disconnect()
            folderAdded = nil
        end
        if folderRemoved then
            folderRemoved:Disconnect()
            folderRemoved = nil
        end
        roomFolder = folder
        roomsDirty = true
        if folder then
            folderAdded = folder.ChildAdded:Connect(markRoomsDirty)
            folderRemoved = folder.ChildRemoved:Connect(markRoomsDirty)
        end
    end

    local function render(deltaSeconds: number)
        local camera = workspace.CurrentCamera
        local character = player.Character
        local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
        local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
        if
            not eligible(player, state)
            or state.Parent == nil
            or not camera
            or not humanoid
            or humanoid.Health <= 0
            or not root
            or not root:IsA("BasePart")
            or camera.CameraType ~= Enum.CameraType.Custom
            or camera.CameraSubject ~= humanoid
        then
            clearTransition()
            return
        end

        local world = workspace:FindFirstChild("World")
        local battlefield = if world then world:FindFirstChild("Battlefield") else nil
        local folder = if battlefield then battlefield:FindFirstChild("GroundCameraInteriors") else nil
        if folder ~= roomFolder then
            changeRoomFolder(folder)
            clearTransition()
        end
        if roomsDirty then
            rooms = if folder then GroundIndoorCamera.readInteriors(folder) else {}
            roomsDirty = false
            currentRoom = nil
        end

        local round = state:GetAttribute("RoundId")
        if camera ~= previousCamera or humanoid ~= previousSubject or round ~= previousRound then
            clearTransition()
            previousCamera, previousSubject, previousRound = camera, humanoid, round
        end
        local room: Interior? = nil
        for _, candidate in rooms do
            local position = candidate.frame:PointToObjectSpace(root.Position)
            local size = candidate.halfSize
            if
                GroundCameraRules.contains(
                    position.X,
                    position.Y,
                    position.Z,
                    size.X,
                    size.Y,
                    size.Z,
                    candidate == currentRoom
                )
                and (not room or candidate.maxDistanceStuds < room.maxDistanceStuds)
            then
                room = candidate
            end
        end
        currentRoom = room
        if room then
            distanceCap = room.maxDistanceStuds
        end
        weight = GroundCameraRules.blend(weight, room ~= nil, deltaSeconds)
        if weight == 0 then
            return
        end

        local stock = camera.CFrame
        local adjusted = GroundIndoorCamera.frame(stock, camera.Focus.Position, room, distanceCap, weight)
        if adjusted ~= stock then
            camera.CFrame = adjusted
            modified = { camera = camera, subject = humanoid, stock = stock, applied = camera.CFrame }
        end
    end

    -- Never feed the shortened render frame back into the next Roblox update.
    -- Its own unmodified controller continues to own the player's selected zoom.
    RunService:BindToRenderStep(BEFORE_CAMERA, CAMERA_PRIORITY - 1, restoreFrame)
    RunService:BindToRenderStep(AFTER_CAMERA, CAMERA_PRIORITY + 1, render)
    return function()
        if running then
            running = false
            ownerActive = false
            RunService:UnbindFromRenderStep(BEFORE_CAMERA)
            RunService:UnbindFromRenderStep(AFTER_CAMERA)
            restoreFrame()
            changeRoomFolder(nil)
        end
    end
end

return GroundIndoorCamera
