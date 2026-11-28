--!strict
--[=[
    GroundInput: client-side desktop pointer capture and upright avatar facing.
    Roblox's Custom camera and controls keep mouse/touch rotation, movement,
    zoom and occlusion. GroundIndoorCamera may shorten the displayed stock ray
    without changing its direction. Facing uses the locally simulated avatar;
    no aim remote or server damage authority is introduced.
]=]
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GroundCameraRules = require(ReplicatedStorage.Shared.GroundCameraRules)

local GroundInput = {}
local nextOwner = 0

type Rotation = { humanoid: Humanoid, autoRotate: boolean }
type Pointer = {
    behavior: Enum.MouseBehavior,
    icon: boolean,
    applied: Enum.MouseBehavior,
    appliedIcon: boolean,
}

-- Checks menus with input ownership, including a native textbox or escape menu.
-- The game panels expose local attributes. This check never yields.
function GroundInput.menuOpen(playerGui: PlayerGui): boolean
    if GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox() then
        return true
    end
    for _, name in { "RoundHUD", "BalancePanel" } do
        local panel = playerGui:FindFirstChild(name)
        if
            panel
            and panel:IsA("ScreenGui")
            and panel.Enabled
            and panel:GetAttribute("InputOverlayOpen") == true
        then
            return true
        end
    end
    return false
end

-- Holding Left Alt lets a Ground player interact with native and game HUD
-- controls. Firing is suspended while the pointer is available for clicks.
function GroundInput.pointerRequested(): boolean
    return not UserInputService.TouchEnabled and UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt)
end

local function groundLife(player: Player, state: Instance): boolean
    local phase = state:GetAttribute("Phase")
    if phase == "Lobby" and RunService:IsStudio() then
        return player:GetAttribute("LocalMapPreview") == true
            and player:GetAttribute("LocalPreviewRole") == "Ground"
    end
    local roundId = state:GetAttribute("RoundId")
    return (phase == "Scatter" or phase == "Active")
        and type(roundId) == "number"
        and player:GetAttribute("RoundId") == roundId
        and player:GetAttribute("Role") == "Ground"
        and player:GetAttribute("Life") == "Alive"
end

-- Projects the displayed look onto X/Z. Preserve root position and remove
-- pitch and roll, using the previous facing if the projection is degenerate.
function GroundInput.facingFrame(root: CFrame, look: Vector3): CFrame
    local yaw = GroundCameraRules.yaw(look.X, look.Z)
    return if yaw then CFrame.new(root.Position) * CFrame.Angles(0, yaw, 0) else root
end

-- Starts a nonyielding local owner. It never changes CameraType, CameraSubject,
-- saved zoom or native movement bindings. The idempotent stop releases only
-- the pointer and humanoid settings still owned by this controller.
function GroundInput.start(player: Player, playerGui: PlayerGui, roundState: Instance): () -> ()
    nextOwner += 1
    local binding = "GroundInput:" .. tostring(nextOwner)
    local rotation: Rotation? = nil
    local pointer: Pointer? = nil
    local focused, running = true, true

    local function releaseRotation()
        local previous = rotation
        rotation = nil
        if previous and previous.humanoid.Parent and not previous.humanoid.AutoRotate then
            previous.humanoid.AutoRotate = previous.autoRotate
        end
    end

    local function releasePointer()
        local previous = pointer
        pointer = nil
        if not previous then
            return
        end
        if UserInputService.MouseBehavior == previous.applied then
            UserInputService.MouseBehavior = previous.behavior
        end
        if UserInputService.MouseIconEnabled == previous.appliedIcon then
            UserInputService.MouseIconEnabled = previous.icon
        end
    end

    local function applyPointer(blocked: boolean)
        local behavior = if blocked then Enum.MouseBehavior.Default else Enum.MouseBehavior.LockCenter
        local applied = pointer
        if applied then
            applied.applied = behavior
            applied.appliedIcon = blocked
        else
            pointer = {
                behavior = UserInputService.MouseBehavior,
                icon = UserInputService.MouseIconEnabled,
                applied = behavior,
                appliedIcon = blocked,
            }
        end
        UserInputService.MouseBehavior = behavior
        UserInputService.MouseIconEnabled = blocked
    end

    local connections = {
        UserInputService.WindowFocusReleased:Connect(function()
            focused = false
            releasePointer()
            releaseRotation()
        end),
        UserInputService.WindowFocused:Connect(function()
            focused = true
        end),
        UserInputService.TouchStarted:Connect(function()
            focused = true
        end),
    }

    -- Apply after Roblox's own camera mouse decision. Stock Custom still
    -- handles the displacement, including sensitivity and pitch limits.
    RunService:BindToRenderStep(binding, Enum.RenderPriority.Camera.Value + 1, function()
        local character = player.Character
        local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
        local camera = workspace.CurrentCamera
        local modal = GroundInput.menuOpen(playerGui)
        -- Stop this frame's native movement while a menu is open. No persistent
        -- controller lock competes with theater spectating or respawn.
        if modal and humanoid and humanoid.Health > 0 then
            humanoid:Move(Vector3.zero, false)
            humanoid.Jump = false
        end
        local root = if humanoid then humanoid.RootPart else nil
        if
            not focused
            or roundState.Parent == nil
            or not groundLife(player, roundState)
            or not camera
            or camera.CameraType ~= Enum.CameraType.Custom
            or not humanoid
            or camera.CameraSubject ~= humanoid
            or humanoid.Health <= 0
            or humanoid.SeatPart ~= nil
            or not root
            or root.Anchored
        then
            releasePointer()
            releaseRotation()
            return
        end
        local blocked = modal or GroundInput.pointerRequested()
        if UserInputService.MouseEnabled and not UserInputService.TouchEnabled then
            applyPointer(blocked)
        else
            releasePointer()
        end
        if blocked then
            releaseRotation()
            return
        end
        if not rotation or rotation.humanoid ~= humanoid then
            releaseRotation()
            rotation = { humanoid = humanoid, autoRotate = humanoid.AutoRotate }
        end
        humanoid.AutoRotate = false
        local current = root.CFrame
        local facing = GroundInput.facingFrame(current, camera.CFrame.LookVector)
        if current.LookVector:Dot(facing.LookVector) < 0.999999 or current.UpVector.Y < 0.999999 then
            root.CFrame = facing
        end
    end)

    return function()
        if not running then
            return
        end
        running = false
        RunService:UnbindFromRenderStep(binding)
        for _, connection in connections do
            connection:Disconnect()
        end
        releasePointer()
        releaseRotation()
    end
end

return GroundInput
