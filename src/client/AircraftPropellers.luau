--!strict
--[=[
    AircraftPropellers animates four cosmetic motors on each client. It reads
    the canonical server generation and phase, and writes only nonreplicated
    Motor6D.Transform values. No hit geometry, orbit pose or remotes are owned.
]=]
local RunService = game:GetService("RunService")
local AircraftPropellers = {}
local ROTATIONS_PER_SECOND = 5.25
local ROTATION_CLOCK_WRAP_SECONDS = 4

-- Observe the current direct-child aircraft at PreSimulation so Roblox applies
-- motor transforms as a batch. A partially replicated rig is retried the next
-- frame. The returned cleanup is idempotent and restores neutral motor pose.
function AircraftPropellers.start(): () -> ()
    local active: Instance? = nil
    local motors: { Motor6D } = {}
    local function restore()
        for _, motor in motors do
            if motor.Parent then
                motor.Transform = CFrame.identity
            end
        end
        table.clear(motors)
    end
    local connection = RunService.PreSimulation:Connect(function()
        local model = workspace:FindFirstChild("Aircraft")
        if model ~= active then
            restore()
            active = model
        end
        if not model or not model:IsA("Model") then
            return
        end
        if #motors == 0 then
            local propellers = model:FindFirstChild("Propellers")
            if not propellers then
                return
            end
            for _, rotor in propellers:GetChildren() do
                local hub = rotor:FindFirstChild("Hub")
                local motor = if hub then hub:FindFirstChild("FlightMotor") else nil
                if motor and motor:IsA("Motor6D") then
                    table.insert(motors, motor)
                end
            end
            if #motors ~= 4 then
                table.clear(motors)
                return
            end
        end
        local epoch = model:GetAttribute("PropellersEpochSeconds")
        local stopped = model:GetAttribute("PropellersStoppedSeconds")
        if type(epoch) ~= "number" then
            return
        end
        local clock = if type(stopped) == "number" then stopped else workspace:GetServerTimeNow()
        local elapsed = math.max(0, clock - epoch) % ROTATION_CLOCK_WRAP_SECONDS
        local spin = CFrame.Angles(0, 0, -elapsed * (math.pi * 2 * ROTATIONS_PER_SECOND))
        for _, motor in motors do
            motor.Transform = spin
        end
    end)
    return function()
        connection:Disconnect()
        restore()
        active = nil
    end
end

return AircraftPropellers
