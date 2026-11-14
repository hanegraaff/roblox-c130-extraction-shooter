--!strict
--[=[
    LauncherGeometry: server-only primitive launcher presentation and recovery queries.
    Depends on the active level's Battlefield/MapRules settings and Workspace queries.
    Models are noncolliding/nonqueryable cosmetics; ownership belongs to LauncherService.
    All calls are nonyielding. Callers destroy returned representations on transfer/reset.
]=]
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
local function tube(parent: Instance, anchored: boolean): BasePart
    local handle = Instance.new("Part")
    handle.Name = "Handle"
    handle.Size = Vector3.new(0.75, 0.75, 4)
    handle.Color = Color3.fromRGB(100, 111, 53)
    handle.Material = Enum.Material.Metal
    handle.Anchored = anchored
    handle.CanCollide, handle.CanQuery, handle.CanTouch = false, false, false
    handle.Massless = true
    handle.Parent = parent
    for _, offset in { -1.65, 1.65 } do
        local band = handle:Clone()
        band.Name = "TubeBand"
        band.Size = Vector3.new(0.95, 0.95, 0.25)
        band.Color = Color3.fromRGB(226, 165, 55)
        band.CFrame = handle.CFrame * CFrame.new(0, 0, offset)
        band.Parent = parent
        if not anchored then
            local weld = Instance.new("WeldConstraint")
            weld.Part0, weld.Part1, weld.Parent = handle, band, band
        end
    end
    return handle
end
-- Creates exactly one held Tool. Backpack parenting/equipping is the caller's
-- responsibility. Native backspace dropping is disabled in favor of server intent.
function LauncherGeometry.tool(launcherId: string): Tool
    local tool = Instance.new("Tool")
    tool.Name, tool.ToolTip = "Rocket launcher", "Direct hits damage the C-130 • G drops for a teammate"
    tool.RequiresHandle, tool.CanBeDropped = true, false
    tool:SetAttribute("LauncherId", launcherId)
    tube(tool, false)
    return tool
end
-- Creates one visible pickup with a stable ID. It cannot obstruct either route.
function LauncherGeometry.pickup(launcherId: string, position: Vector3): Model
    local model = Instance.new("Model")
    model.Name = "MapRocketLauncher"
    model:SetAttribute("LauncherId", launcherId)
    local handle = tube(model, true)
    model.PrimaryPart = handle
    model:PivotTo(CFrame.new(position))
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
