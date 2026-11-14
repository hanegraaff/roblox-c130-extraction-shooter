--!strict
--[=[
    PanelGeometry: server-only primitive/material panel presentation owner. Uses
    original authored Parts/PanelResidual for primitives, or validated private
    PanelAssetCatalog families through MaterialPanelGeometry. Neither path changes
    damage rules. Primitive strips leave exactly 50% open; material proxies retain
    the approved irregular apertures. No invisible full-wall collider survives.
    The caller owns captured originals and cleanup. No yielding/events/cloud loads.
]=]
local ServerStorage = game:GetService("ServerStorage")
local PanelAssetCatalog = require(script.Parent.PanelAssetCatalog)
local MaterialPanelGeometry = require(script.Parent.MaterialPanelGeometry)
local PanelGeometry = {}
export type Panel = {
    id: string,
    pivot: CFrame,
    size: Vector3,
    original: Instance,
    model: Model,
    stage: number,
    visualBucket: string,
    family: PanelAssetCatalog.Family?,
    color: Color3,
}

-- Captures an authored Part or material Model into a persistent identity. Models
-- require a validated family, canonical pivot and local IntactSize. Caller owns
-- the validated subtree; originals remain private until restored/destroyed at stop.
function PanelGeometry.capture(part: BasePart | Model, family: PanelAssetCatalog.Family?): Panel
    if part:IsA("Model") then
        assert(family, "material panel requires a validated family")
        local size = part:GetAttribute("IntactSize")
        assert(typeof(size) == "Vector3", "material panel requires authored IntactSize")
        return {
            id = part.Name,
            pivot = part:GetPivot(),
            size = size,
            original = part:Clone(),
            model = part,
            stage = 0,
            visualBucket = "Pristine",
            family = family,
            color = Color3.new(1, 1, 1),
        }
    end
    local model = Instance.new("Model")
    model.Name = part.Name
    for key, value in part:GetAttributes() do
        model:SetAttribute(key, value)
    end
    model:SetAttribute("PanelId", part.Name)
    model:SetAttribute("IntactPivot", part.CFrame)
    model:SetAttribute("IntactSize", part.Size)
    model.WorldPivot = part.CFrame
    model.Parent = part.Parent
    local original = part:Clone()
    part.Parent = model
    part.Name = "Solid"
    return {
        id = model.Name,
        pivot = part.CFrame,
        size = part.Size,
        original = original,
        model = model,
        stage = 0,
        visualBucket = "",
        family = nil,
        color = part.Color,
    }
end

-- Replaces only owned panel solids. stage 2 leaves the stable identity model with
-- no BaseParts. Structural parents/supports are never touched. The residual source
-- stores normalized X strips; walls/roofs scale them into the panel's largest axis.
function PanelGeometry.setStage(panel: Panel, stage: number)
    if stage == panel.stage then
        return
    end
    panel.model:ClearAllChildren()
    panel.visualBucket = ""
    if panel.family then
        local appearance = if stage == 0 then "Pristine" elseif stage == 1 then "Heavy" else "Total"
        MaterialPanelGeometry.install(panel.model, panel.pivot, panel.family, appearance)
        panel.visualBucket = appearance
        panel.stage = stage
        return
    end
    assert(panel.original:IsA("BasePart"), "primitive original is not a BasePart")
    if stage == 0 then
        local intact = panel.original:Clone()
        intact.Name = "Solid"
        intact.Parent = panel.model
    elseif stage == 1 then
        local template = ServerStorage.Assets:FindFirstChild("PanelResidual")
        assert(template, "missing original residual template")
        local alongX = panel.size.X >= panel.size.Z
        for _, source in template:GetChildren() do
            assert(source:IsA("BasePart"), "residual must contain only primitives")
            local residual = panel.original:Clone()
            residual.Name = source.Name
            local fraction = source.Size.X
            local offset = source.Position.X
            residual.Size = if alongX
                then Vector3.new(panel.size.X * fraction, panel.size.Y, panel.size.Z)
                else Vector3.new(panel.size.X, panel.size.Y, panel.size.Z * fraction)
            residual.CFrame = panel.pivot
                * CFrame.new(
                    if alongX
                        then Vector3.new(panel.size.X * offset, 0, 0)
                        else Vector3.new(0, 0, panel.size.Z * offset)
                )
            residual.Parent = panel.model
        end
    end
    panel.stage = stage
end

-- Original primitive two-face crack recipe, in normalized face coordinates.
-- Marks never represent holes. They have no PanelId, collision, touch or query
-- authority, and are clipped to each remaining solid rather than across a hole.
local crackLines = {
    { -0.34, -0.32, 0.28, 0.24 },
    { -0.20, 0.32, 0.08, -0.28 },
    { 0.05, 0.02, 0.38, -0.20 },
    { -0.32, 0.12, 0.18, 0.34 },
    { 0.16, -0.33, 0.38, 0.10 },
    { -0.38, -0.03, -0.08, 0.15 },
    { 0.25, 0.26, 0.38, 0.38 },
}
local lightTint = Color3.fromRGB(150, 142, 128)
local heavyTint = Color3.fromRGB(76, 68, 58)
local lightCrack = Color3.fromRGB(24, 24, 24)
local heavyCrack = Color3.fromRGB(190, 186, 172)
local crackWidthStuds, crackDepthStuds, faceOffsetStuds = 0.12, 0.03, 0.02

-- The ORIGINAL panel decides its face normal; a narrow Heavy residual must not
-- flip its face to its newly shortest dimension. U/V stay inside each solid.
local function faceAxes(size: Vector3): (Vector3, Vector3, Vector3)
    if size.Y <= math.min(size.X, size.Z) then
        return Vector3.yAxis, Vector3.xAxis, Vector3.zAxis
    end
    if size.X < size.Z then
        return Vector3.xAxis, Vector3.zAxis, Vector3.yAxis
    end
    return Vector3.zAxis, Vector3.xAxis, Vector3.yAxis
end
local function dimension(size: Vector3, axis: Vector3): number
    return math.abs(size:Dot(axis))
end
local function cracks(panel: Panel, appearance: string, count: number)
    local old = panel.model:FindFirstChild("DamageVisuals")
    if old then
        old:Destroy()
    end
    if count == 0 then
        return
    end
    local folder = Instance.new("Folder")
    folder.Name = "DamageVisuals"
    local normal, u, v = faceAxes(panel.size)
    for _, solid in panel.model:GetChildren() do
        if solid:IsA("BasePart") then
            for _, side in { -1, 1 } do
                local worldNormal = solid.CFrame:VectorToWorldSpace(normal) * side
                for index = 1, count do
                    local line = crackLines[index]
                    local depth = normal * (side * (dimension(solid.Size, normal) / 2 + faceOffsetStuds))
                    local a = solid.CFrame:PointToWorldSpace(
                        u * (line[1] * dimension(solid.Size, u))
                            + v * (line[2] * dimension(solid.Size, v))
                            + depth
                    )
                    local b = solid.CFrame:PointToWorldSpace(
                        u * (line[3] * dimension(solid.Size, u))
                            + v * (line[4] * dimension(solid.Size, v))
                            + depth
                    )
                    local right = (b - a).Unit
                    local mark = Instance.new("Part")
                    mark.Name = solid.Name .. "_Crack" .. tostring(side) .. "_" .. tostring(index)
                    mark.Size = Vector3.new((b - a).Magnitude, crackWidthStuds, crackDepthStuds)
                    mark.CFrame = CFrame.fromMatrix((a + b) / 2, right, worldNormal:Cross(right), worldNormal)
                    mark.Anchored = true
                    mark.CanCollide = false
                    mark.CanQuery = false
                    mark.CanTouch = false
                    mark.Color = if appearance == "Heavy" then heavyCrack else lightCrack
                    mark.Material = Enum.Material.Slate
                    mark:SetAttribute("DamageVisual", true)
                    mark.Parent = folder
                end
            end
        end
    end
    folder.Parent = panel.model
    panel.model.WorldPivot = panel.pivot
end

-- Replicates structural state plus persistent Pristine/Light/Heavy/Total tier.
-- Stage-local progress may reset at a boundary; Heavy keeps its own dark base,
-- fracture edges and real opening. Rebuild marks only at appearance/count changes.
function PanelGeometry.publish(
    panel: Panel,
    stage: number,
    progress: number,
    heavySeconds: number,
    sustainedSeconds: number,
    appearance: string
)
    local state = ({ "Intact", "Damaged", "Destroyed" })[stage + 1]
    if panel.family then
        if panel.visualBucket ~= appearance then
            MaterialPanelGeometry.install(panel.model, panel.pivot, panel.family, appearance)
            panel.visualBucket = appearance
        end
        MaterialPanelGeometry.progress(panel.model, progress)
        local descendants = panel.model:GetDescendants()
        table.insert(descendants, panel.model)
        for _, item in descendants do
            item:SetAttribute("PanelState", state)
            item:SetAttribute("DamageAppearance", appearance)
            item:SetAttribute("PanelProgress", progress)
            item:SetAttribute("HeavySeconds", heavySeconds)
            item:SetAttribute("SustainedSeconds", sustainedSeconds)
        end
        return
    end
    assert(panel.original:IsA("BasePart"), "primitive original is not a BasePart")
    local count = if appearance == "Light"
        then math.min(7, 3 + math.floor(progress * 5))
        elseif appearance == "Heavy" then 7
        else 0
    local bucket = appearance .. ":" .. tostring(count)
    if bucket ~= panel.visualBucket then
        cracks(panel, appearance, count)
        panel.visualBucket = bucket
    end
    local items: { Instance } = panel.model:GetChildren()
    table.insert(items, panel.model)
    for _, item in items do
        item:SetAttribute("PanelState", state)
        item:SetAttribute("DamageAppearance", appearance)
        item:SetAttribute("PanelProgress", progress)
        item:SetAttribute("HeavySeconds", heavySeconds)
        item:SetAttribute("SustainedSeconds", sustainedSeconds)
        if item:IsA("BasePart") then
            item.Color = if appearance == "Light"
                then lightTint:Lerp(Color3.fromRGB(110, 102, 90), progress * 0.55)
                elseif appearance == "Heavy" then heavyTint:Lerp(
                    Color3.fromRGB(45, 39, 34),
                    progress * 0.55
                )
                else panel.original.Color
            item.Material = if appearance == "Pristine" then panel.original.Material else Enum.Material.Slate
        end
    end
end
return PanelGeometry
