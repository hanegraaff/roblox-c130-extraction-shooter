--!strict
--[=[
    LauncherGeometry: server-only depot launcher presentation and recovery queries.
    Depends on the active level's Battlefield/MapRules settings and Workspace queries.
    Models are noncolliding/nonqueryable cosmetics; ownership belongs to LauncherService.
    All calls are nonyielding. Callers destroy returned representations on transfer/reset.
]=]
local ServerStorage = game:GetService("ServerStorage")
local MapRules = require(game:GetService("ReplicatedStorage").Shared.MapRules)
local LauncherGeometry = {}
local function finite(vector: Vector3): boolean
    return vector.Magnitude == vector.Magnitude and vector.Magnitude < math.huge
end
-- Only current level solids participate: characters, fragments, held weapons
-- and cosmetic effects cannot become support or block pickup reach.
function LauncherGeometry.parameters(battlefield: Instance): RaycastParams
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = { battlefield, workspace.Terrain }
    params.RespectCanCollide = true
    params.IgnoreWater = true
    return params
end
-- Selects a supported upright avatar-sized recovery spot below a last trusted
-- root. Vertical probes are bounded to 12 studs; missing/steep/blocked support
-- returns nil so the adapter can use the authored, validated launcher anchor.
function LauncherGeometry.supported(
    battlefield: Instance,
    settings: MapRules.Settings,
    root: Vector3
): Vector3?
    if
        not finite(root)
        or not MapRules.inside(settings, root.X, root.Z)
        or root.Y < settings.killY
        or root.Y > settings.altitudeStuds
    then
        return nil
    end
    local params = LauncherGeometry.parameters(battlefield)
    local floor = workspace:Raycast(root + Vector3.yAxis, -Vector3.yAxis * 12, params)
    if not floor or floor.Normal.Y < 0.6 then
        return nil
    end
    local position = floor.Position + Vector3.yAxis * 1.1
    local overlap = OverlapParams.new()
    overlap.FilterType = Enum.RaycastFilterType.Include
    overlap.FilterDescendantsInstances = { battlefield }
    overlap.RespectCanCollide = true
    overlap.MaxParts = 1
    if
        #workspace:GetPartBoundsInBox(
            CFrame.new(floor.Position + Vector3.yAxis * 3.1),
            Vector3.new(4, 6, 4),
            overlap
        ) > 0
    then
        return nil
    end
    return position
end
-- Reach combines the server root's distance and a solid-world sight line.
function LauncherGeometry.reachable(
    battlefield: Instance,
    root: BasePart,
    head: BasePart,
    target: Vector3,
    reach: number
): boolean
    if not finite(target) or (root.Position - target).Magnitude > reach then
        return false
    end
    local delta = target - head.Position
    return delta.Magnitude > 0
        and workspace:Raycast(head.Position, delta, LauncherGeometry.parameters(battlefield)) == nil
end
-- Every representation clones the same source-managed, inert assembly. The handle
-- is a hidden pivot with CarryGrip, Muzzle and GroundContact attachment frames.
local function assembly(): (Model, BasePart)
    local assets = ServerStorage:FindFirstChild("Assets")
    local template = if assets then assets:FindFirstChild("DepotLauncher") else nil
    assert(template and template:IsA("Model"), "managed DepotLauncher template is missing")
    local model = template:Clone()
    local handle = model:FindFirstChild("Handle")
    assert(handle and handle:IsA("BasePart"), "DepotLauncher requires Handle")
    model.PrimaryPart = handle
    for _, part in model:GetChildren() do
        if part:IsA("BasePart") then
            part:SetAttribute("ThermalNonCover", true)
        end
    end
    return model, handle
end
local function attachment(handle: BasePart, name: string): Attachment
    local item = handle:FindFirstChild(name)
    assert(item and item:IsA("Attachment"), "DepotLauncher requires " .. name)
    return item
end
-- Creates one Tool with its native right-hand joint aligned to CarryGrip. The
-- caller owns backpack parenting and equip; manual native drop stays disabled.
function LauncherGeometry.tool(launcherId: string): Tool
    local model, handle = assembly()
    local tool = Instance.new("Tool")
    tool.Name, tool.ToolTip = "Rocket launcher", "Direct hits damage the C-130 • G drops for a teammate"
    tool.RequiresHandle, tool.CanBeDropped = true, false
    tool.Grip = attachment(handle, "CarryGrip").CFrame
    tool:SetAttribute("LauncherId", launcherId)
    for _, part in model:GetChildren() do
        if part:IsA("BasePart") then
            part.Anchored, part.Parent = false, tool
            if part ~= handle then
                local weld = Instance.new("WeldConstraint")
                weld.Part0, weld.Part1, weld.Parent = handle, part, part
            end
        end
    end
    model:Destroy()
    return tool
end
-- Finds the launch presentation point on an equipped model. The character's
-- validated head remains the sweep and aim origin. Hide the muzzle offset when
-- the hand moved too far, or solid level geometry blocks either the connection
-- to the head or the visible rocket's path to the server sweep.
function LauncherGeometry.visualOrigin(
    battlefield: Instance,
    tool: Tool,
    head: Vector3,
    sweepConvergence: Vector3
): Vector3
    local handle = tool:FindFirstChild("Handle")
    if not handle or not handle:IsA("BasePart") then
        return head
    end
    local muzzle = attachment(handle, "Muzzle").WorldPosition
    local offset = muzzle - head
    if not finite(offset) or offset.Magnitude > 4 or offset.Magnitude < 0.01 then
        return head
    end
    local params = LauncherGeometry.parameters(battlefield)
    if
        workspace:Raycast(head, offset, params)
        or workspace:Raycast(muzzle, -offset, params)
        or workspace:Spherecast(muzzle, 0.2, sweepConvergence - muzzle, params)
    then
        return head
    end
    return muzzle
end
-- Places the authored side against the current support floor. The public
-- model pivot remains the gameplay anchor used by reach and round recovery.
function LauncherGeometry.pickup(launcherId: string, position: Vector3, battlefield: Instance): Model
    local model, handle = assembly()
    model.Name = "MapRocketLauncher"
    model:SetAttribute("LauncherId", launcherId)
    local floor = workspace:Raycast(
        position + Vector3.yAxis * 0.1,
        -Vector3.yAxis * 6,
        LauncherGeometry.parameters(battlefield)
    )
    local support = CFrame.new(position - Vector3.yAxis * 1.1)
    if floor and floor.Normal.Y >= 0.6 then
        local right = floor.Normal:Cross(Vector3.zAxis).Unit
        support = CFrame.fromMatrix(floor.Position + floor.Normal * 0.012, right, floor.Normal)
    end
    model:PivotTo(support * attachment(handle, "GroundContact").CFrame:Inverse())
    handle.PivotOffset = handle.CFrame:ToObjectSpace(CFrame.new(position))
    local sign = Instance.new("BillboardGui")
    sign.Name, sign.Adornee = "PickupLabel", handle
    sign.Size = UDim2.fromOffset(180, 44)
    sign.StudsOffsetWorldSpace = Vector3.new(0, 2.5, 0)
    sign.MaxDistance = 70
    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundColor3 = Color3.fromRGB(25, 28, 20)
    label.BackgroundTransparency = 0.15
    label.TextColor3 = Color3.fromRGB(255, 220, 110)
    label.Text, label.TextSize = "ROCKET LAUNCHER\nE / PICK UP", 16
    label.Parent, sign.Parent = sign, model
    return model
end
return LauncherGeometry
