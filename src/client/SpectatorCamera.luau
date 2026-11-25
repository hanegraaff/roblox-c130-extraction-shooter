--!strict
--[=[
    SpectatorCamera: local follow view of living current-round Ground players
    and an inert neutral fallback. RoundPanel yields camera ownership to the
    thermal controller while operating. No transport, teleport or action grants.
    Public calls are nonyielding and cleanup removes the owned fallback subject.
]=]
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
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
    local following = false
    local shakeBinding = "RoundResultShake-" .. HttpService:GenerateGUID(false)
    local shaking = false
    local shockAge, shockStrength = 0, 0

    local function releaseShake()
        if shaking then
            shaking = false
            RunService:UnbindFromRenderStep(shakeBinding)
        end
    end

    local function shakeLobbyCamera(age: number?, strength: number)
        if not age or age >= 0.65 or strength <= 0 then
            releaseShake()
            return
        end
        shockAge, shockStrength = age, strength
        if not shaking then
            shaking = true
            RunService:BindToRenderStep(shakeBinding, Enum.RenderPriority.Camera.Value + 1, function()
                local camera = workspace.CurrentCamera
                if
                    camera
                    and camera.CameraType == Enum.CameraType.Custom
                    and camera.CameraSubject == liveHumanoid(player)
                then
                    local amplitude = (1 - shockAge / 0.65) * shockStrength
                    camera.CFrame *= CFrame.Angles(
                        math.sin(shockAge * 33) * amplitude * 0.008,
                        0,
                        math.sin(shockAge * 47) * amplitude * 0.013
                    )
                end
            end)
        end
    end

    local function clearOverview()
        if overview then
            overview:Destroy()
            overview = nil
        end
    end

    local function restoreLocalCamera(camera: Camera, releaseForeignSubject: boolean)
        local subject: (Humanoid | BasePart)? = liveHumanoid(player)
        if not subject and releaseForeignSubject then
            -- The protected lobby anchor remains a local point of reference
            -- during the native avatar-loading gap after a reset or round end.
            local world = workspace:FindFirstChild("World")
            local battlefield = if world then world:FindFirstChild("Battlefield") else nil
            local anchors = if battlefield then battlefield:FindFirstChild("Anchors") else nil
            local lobby = if anchors then anchors:FindFirstChild("Lobby") else nil
            if lobby and lobby:IsA("BasePart") then
                subject = lobby
            end
        end
        if subject then
            camera.CameraSubject = subject
            camera.CameraType = Enum.CameraType.Custom
        elseif releaseForeignSubject then
            camera.CameraType = Enum.CameraType.Scriptable
        end
        clearOverview()
    end

    local function overviewFrame(camera: Camera)
        local map = MapRules.defaults
        local center = Vector3.new(map.centerX, map.groundY, map.centerZ)
        local position = center + Vector3.new(0, map.radiusStuds * 0.55, map.radiusStuds * 0.7)
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
        camera.CFrame = CFrame.lookAt(position, center)
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
        local leavingSpectator = following and view ~= "Spectator"
        following = view == "Spectator"
        shakeLobbyCamera(if view == "Results" then destructionAge else nil, shake)
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
            overviewFrame(camera)
        else
            restoreLocalCamera(camera, leavingSpectator or overview ~= nil or view == "Results")
        end
        return nil, nil, 0
    end

    return {
        update = update,
        stop = function()
            releaseShake()
            local camera = workspace.CurrentCamera
            if camera then
                restoreLocalCamera(camera, following or overview ~= nil)
            end
            following = false
            clearOverview()
        end,
    }
end

return SpectatorCamera
