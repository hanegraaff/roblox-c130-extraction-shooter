--!strict
--[=[
    SpectatorCamera: local follow view of living current-round Ground players
    and an inert neutral fallback. RoundPanel yields camera ownership to the
    thermal controller while operating. No transport, teleport or action grants.
    Public calls are nonyielding and cleanup removes the owned fallback subject.
]=]
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage").Shared
local PlayerPresentation = require(Shared.PlayerPresentation)
local MapRules = require(Shared.MapRules)

local SpectatorCamera = {}

export type Controller = {
    update: (string, number, number, number?, number) -> (number?, string?, number),
    stop: () -> (),
}

local function liveHumanoid(player: Player): Humanoid?
    local character = player.Character
    local humanoid = if character and character:IsDescendantOf(workspace)
        then character:FindFirstChildOfClass("Humanoid")
        else nil
    return if humanoid and humanoid.Health > 0 then humanoid else nil
end

-- Returns a new camera owner. update takes the view, round ID, signed cycle
-- request, optional age of aircraft destruction in seconds and [0, 1] shake.
-- The return identifies an actual bound target, its display name and roster size.
function SpectatorCamera.new(player: Player): Controller
    local selected: number? = nil
    local overview: Part? = nil
    local round = -1

    local function clearOverview()
        if overview then
            overview:Destroy()
            overview = nil
        end
    end

    local function overviewFrame(camera: Camera, destructionAge: number?, shake: number)
        local map = MapRules.defaults
        local center = Vector3.new(map.centerX, map.groundY, map.centerZ)
        local position = center + Vector3.new(0, map.radiusStuds * 0.55, map.radiusStuds * 0.7)
        if destructionAge then
            local aircraft = workspace:FindFirstChild("Aircraft")
            local anchor = if aircraft then aircraft:FindFirstChild("Hitbox") else nil
            if anchor and anchor:IsA("BasePart") then
                center = anchor.Position
                local radial = Vector3.new(center.X - map.centerX, 0, center.Z - map.centerZ)
                local outward = if radial.Magnitude > 1 then radial.Unit else Vector3.zAxis
                position = center + outward * 100 + Vector3.new(0, 34, 0)
            end
        end
        local neutral: Part
        if overview then
            neutral = overview
        else
            neutral = Instance.new("Part")
            neutral.Name = "RoundOverviewSubject"
            neutral.Size = Vector3.one
            neutral.Transparency = 1
            neutral.Anchored = true
            neutral.CanCollide = false
            neutral.CanTouch = false
            neutral.CanQuery = false
            overview = neutral
        end
        neutral.Position = center
        neutral.Parent = camera
        camera.CameraType = Enum.CameraType.Scriptable
        camera.CameraSubject = neutral
        camera.Focus = CFrame.new(center)
        local amplitude = if destructionAge then math.max(0, 1 - destructionAge / 0.65) * shake else 0
        local age = destructionAge or 0
        camera.CFrame = CFrame.lookAt(position, center)
            * CFrame.Angles(math.sin(age * 33) * amplitude * 0.008, 0, math.sin(age * 47) * amplitude * 0.013)
    end

    local function update(
        view: string,
        roundId: number,
        direction: number,
        destructionAge: number?,
        shake: number
    ): (number?, string?, number)
        if round ~= roundId or view ~= "Spectator" then
            selected = nil
            round = roundId
        end
        local camera = workspace.CurrentCamera
        if not camera then
            return nil, nil, 0
        end
        if view == "Operator" or view == "OperatorPreview" then
            clearOverview()
            return nil, nil, 0
        end
        if view == "Spectator" then
            local candidates: { number } = {}
            local humanoids: { [number]: Humanoid } = {}
            local names: { [number]: string } = {}
            for _, teammate in Players:GetPlayers() do
                if
                    teammate ~= player
                    and teammate:GetAttribute("RoundId") == roundId
                    and teammate:GetAttribute("Role") == "Ground"
                    and teammate:GetAttribute("Life") == "Alive"
                then
                    local humanoid = liveHumanoid(teammate)
                    if humanoid then
                        local id = teammate.UserId
                        table.insert(candidates, id)
                        humanoids[id] = humanoid
                        names[id] = teammate.DisplayName
                    end
                end
            end
            local targetId = PlayerPresentation.spectatorTarget(candidates, selected, direction)
            selected = targetId
            if targetId then
                camera.CameraSubject = humanoids[targetId]
                camera.CameraType = Enum.CameraType.Custom
                clearOverview()
                return targetId, names[targetId], #candidates
            end
            overviewFrame(camera, nil, 0)
        elseif view == "Results" then
            overviewFrame(camera, destructionAge, shake)
        else
            local humanoid = liveHumanoid(player)
            if humanoid then
                camera.CameraSubject = humanoid
                camera.CameraType = Enum.CameraType.Custom
                clearOverview()
            elseif overview then
                overviewFrame(camera, nil, 0)
            end
        end
        return nil, nil, 0
    end

    return {
        update = update,
        stop = function()
            local camera = workspace.CurrentCamera
            if camera then
                local humanoid = liveHumanoid(player)
                if humanoid then
                    camera.CameraSubject = humanoid
                end
                camera.CameraType = Enum.CameraType.Custom
            end
            clearOverview()
        end,
    }
end

return SpectatorCamera
