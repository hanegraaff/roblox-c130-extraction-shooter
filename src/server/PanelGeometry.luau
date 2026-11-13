--!strict
--[=[
    PanelGeometry: server-only reconstruction of primitive panel variants. Depends
    on the original authored Part and server-only normalized PanelResidual template.
    Geometry is original project authoring, scaled along the longest face axis.
    Two 25%-wide residual strips leave exactly 50% open area, including full-height
    wall passage. No full-size invisible collider survives. No yielding/events.
]=]
local ServerStorage = game:GetService("ServerStorage")
local PanelGeometry = {}
export type Panel = {
    id: string,
    pivot: CFrame,
    size: Vector3,
    original: BasePart,
    model: Model,
    stage: number,
}

-- Captures an authored panel into a persistent identity model. Caller must own the
-- validated map subtree. Identity/pivot survive all swaps; original is retained
-- unparented for reconstruction and must be destroyed by the owner on teardown.
function PanelGeometry.capture(part: BasePart): Panel
    local model = Instance.new("Model")
    model.Name = part.Name
    for key, value in part:GetAttributes() do
        model:SetAttribute(key, value)
    end
    model:SetAttribute("PanelId", part.Name)
    model:SetAttribute("IntactPivot", part.CFrame)
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

-- Replicates a complete current snapshot. Color darkening is an interim per-hit /
-- sustained-fire cue; stage changes are represented by actual removed geometry.
function PanelGeometry.publish(
    panel: Panel,
    stage: number,
    progress: number,
    heavySeconds: number,
    sustainedSeconds: number
)
    local state = ({ "Intact", "Damaged", "Destroyed" })[stage + 1]
    local items: { Instance } = panel.model:GetChildren()
    table.insert(items, panel.model)
    for _, item in items do
        item:SetAttribute("PanelState", state)
        item:SetAttribute("PanelProgress", progress)
        item:SetAttribute("HeavySeconds", heavySeconds)
        item:SetAttribute("SustainedSeconds", sustainedSeconds)
        if item:IsA("BasePart") then
            item.Color = panel.original.Color:Lerp(Color3.fromRGB(65, 38, 25), progress * 0.8)
            item.Material = if progress > 0 then Enum.Material.CrackedLava else panel.original.Material
        end
    end
end
return PanelGeometry
