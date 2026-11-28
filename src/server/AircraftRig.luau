--!strict
--[=[
    AircraftRig binds the managed C-130 template to one anchored server root.
    Its authored solids and inset rounded proxies keep native query shapes. Massless, noncolliding
    art follows the root through rigid joints. Rotor motors have no query authority.
]=]
local AircraftRig = {}

-- Build one joint hierarchy on a detached clone. The caller owns the clone
-- and discards it on error. No yields, external side effects or live connections.
function AircraftRig.bind(model: Model, root: BasePart): (boolean, string?)
    local airframe = model:FindFirstChild("Airframe")
    local propellers = model:FindFirstChild("Propellers")
    local roundedQueries = model:FindFirstChild("RoundedQueries")
    if
        not airframe
        or not airframe:IsA("Model")
        or not propellers
        or not propellers:IsA("Folder")
        or not roundedQueries
        or not roundedQueries:IsA("Folder")
    then
        return false, "missing authored aircraft rig"
    end
    local rotors = propellers:GetChildren()
    if #rotors ~= 4 then
        return false, "expected four aircraft rotors"
    end
    local function rigidlyAttach(part: BasePart, owner: BasePart)
        local joint = Instance.new("Weld")
        joint.Name = "FlightWeld"
        joint.Part0 = owner
        joint.Part1 = part
        joint.C0 = owner.CFrame:ToObjectSpace(part.CFrame)
        joint.Parent = part
        part.Massless = true
        part.Anchored = false
    end
    for _, item in airframe:GetChildren() do
        if not item:IsA("BasePart") or item.CanCollide or item.CanTouch then
            return false, "invalid aircraft airframe part"
        end
        rigidlyAttach(item, root)
    end
    for _, item in roundedQueries:GetChildren() do
        if
            not item:IsA("Part")
            or item.Shape ~= Enum.PartType.Cylinder
            or item.CanCollide
            or item.CanTouch
            or not item.CanQuery
            or item.Transparency ~= 1
            or math.abs(item.Size.Y - item.Size.Z) > 0.001
        then
            return false, "invalid aircraft rounded query volume"
        end
        rigidlyAttach(item, root)
    end
    for _, rotor in rotors do
        local hub = rotor:FindFirstChild("Hub")
        local axis = root:FindFirstChild("Rotor" .. rotor.Name)
        if
            not rotor:IsA("Model")
            or not hub
            or not hub:IsA("BasePart")
            or not axis
            or not axis:IsA("Attachment")
            or (hub.Position - axis.WorldPosition).Magnitude > 0.001
        then
            return false, "invalid aircraft rotor axis"
        end
        for _, part in rotor:GetChildren() do
            if not part:IsA("BasePart") or part.CanCollide or part.CanTouch or part.CanQuery then
                return false, "invalid aircraft rotor part"
            end
            if part ~= hub then
                rigidlyAttach(part, hub)
            end
        end
        local motor = Instance.new("Motor6D")
        motor.Name = "FlightMotor"
        motor.Part0 = root
        motor.Part1 = hub
        motor.C0 = axis.CFrame
        motor.Parent = hub
        hub.Massless = true
        hub.Anchored = false
    end
    return true, nil
end

return AircraftRig
