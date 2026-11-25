--!strict
-- Studio Edit compiler. Clones the genuine Forest Pack mesh and collision data
-- already present in the managed district assembly, then serializes the result.
type Placement = {
    x: number,
    z: number,
    height: number,
    width: number,
    depth: number,
    elevation: number,
    bury: number,
    yaw: number,
    pitch: number,
    roll: number,
    color: { number },
    solid: boolean,
}

return function(district: Model, placements: { Placement }): Model
    local wash = assert(district:FindFirstChild("SandbreakWash"))
    local template: MeshPart? = nil
    for _, model in wash:GetChildren() do
        if string.match(model.Name, "^LargeBoulder_Var01_") then
            template = model:FindFirstChildWhichIsA("MeshPart")
            break
        end
    end
    assert(template and template.MeshId == "rbxassetid://5547037547" and template.MeshSize.Magnitude > 0)
    local root = Instance.new("Model")
    root.Name = "MarsBoulders"
    root:SetAttribute("ThermalBrightness", 0.58)
    for index, spec in placements do
        local part = template:Clone()
        part:ClearAllChildren()
        part.TextureID = ""
        part.Material = Enum.Material.Rock
        part.Color = Color3.fromRGB(spec.color[1], spec.color[2], spec.color[3])
        part.Name = string.format("MarsBoulder%03d", index)
        part.Size = Vector3.new(spec.width, spec.height, spec.depth)
        local rotation =
            CFrame.fromEulerAnglesYXZ(math.rad(spec.pitch), math.rad(spec.yaw), math.rad(spec.roll))
        -- Embed the rotated base while retaining the source collision profile.
        local halfHeight = (
            math.abs(rotation.RightVector.Y) * spec.width
            + math.abs(rotation.UpVector.Y) * spec.height
            + math.abs(rotation.LookVector.Y) * spec.depth
        ) / 2
        part.CFrame = CFrame.new(spec.x, spec.elevation + halfHeight - spec.bury, spec.z) * rotation
        part.Anchored, part.CanTouch = true, false
        part.CanCollide, part.CanQuery = spec.solid, spec.solid
        if not spec.solid then
            part:SetAttribute("ThermalNonCover", true)
        end
        part.Parent = root
    end
    return root
end
