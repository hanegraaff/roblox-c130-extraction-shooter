--!strict
--[=[
    AircraftArrival: client-owned full-viewport operator blackout. Depends on
    the replicated assignment marker, RoundState and the local thermal
    projection. It hides the world on assignment, derives the countdown from
    server time, and releases the cover only after a matching render commits.
    start, updates and cleanup are nonyielding and send no gameplay intent.
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PlayerPresentation = require(ReplicatedStorage.Shared.PlayerPresentation)
local AircraftArrival = {}
local renderOwnerCount = 0

export type Controller = {
    -- True while this screen obscures the game and its controls.
    blocking: () -> boolean,
    -- Idempotently removes the owned screen, listeners and render binding.
    stop: () -> (),
}

-- Attach before first HUD paint. thermalReady reports a completed frame for
-- the given round ID; a phase or model update alone cannot uncover the view.
function AircraftArrival.start(
    player: Player,
    playerGui: PlayerGui,
    state: Instance,
    thermalReady: (number) -> boolean
): Controller
    local gui = Instance.new("ScreenGui")
    gui.Name = "AircraftArrival"
    gui.Enabled = false
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 100
    gui.ScreenInsets = Enum.ScreenInsets.None
    gui.ClipToDeviceSafeArea = false

    local cover = Instance.new("Frame")
    cover.Name = "Blackout"
    cover.Size = UDim2.fromScale(1, 1)
    cover.BackgroundColor3 = Color3.new(0, 0, 0)
    cover.BorderSizePixel = 0
    cover.Active = true
    cover.Parent = gui

    local countdown = Instance.new("TextLabel")
    countdown.Name = "Countdown"
    countdown.AnchorPoint = Vector2.new(0.5, 0.5)
    countdown.Position = UDim2.fromScale(0.5, 0.5)
    countdown.Size = UDim2.new(0.76, 0, 0, 52)
    countdown.BackgroundTransparency = 1
    countdown.Font = Enum.Font.GothamMedium
    countdown.TextColor3 = Color3.new(1, 1, 1)
    countdown.TextScaled = true
    countdown.Parent = cover
    local textSize = Instance.new("UITextSizeConstraint")
    textSize.MinTextSize = 14
    textSize.MaxTextSize = 34
    textSize.Parent = countdown

    local function update()
        local assignedRound = player:GetAttribute("OperatorArrivalRoundId")
        if type(assignedRound) ~= "number" or thermalReady(assignedRound) then
            gui.Enabled = false
            return
        end
        local phase = if state:GetAttribute("RoundId") == assignedRound
            then state:GetAttribute("Phase")
            else nil
        countdown.Text = if phase == "Active"
            then "C-130 arrives in 0"
            else PlayerPresentation.arrivalText(
                if phase == "Scatter" then state:GetAttribute("DeadlineSeconds") else nil,
                workspace:GetServerTimeNow()
            )
        gui.Enabled = true
    end

    local assignment = player:GetAttributeChangedSignal("OperatorArrivalRoundId"):Connect(update)
    -- A replacement HUD can overlap the previous owner during local fixture
    -- teardown. Each owner must unbind only the callback it registered.
    renderOwnerCount += 1
    local binding = "AircraftArrivalCover:" .. tostring(renderOwnerCount)
    RunService:BindToRenderStep(binding, Enum.RenderPriority.Last.Value, update)
    update()
    gui.Parent = playerGui
    local running = true
    return {
        blocking = function()
            return running and gui.Enabled
        end,
        stop = function()
            if not running then
                return
            end
            running = false
            assignment:Disconnect()
            RunService:UnbindFromRenderStep(binding)
            gui:Destroy()
        end,
    }
end

return AircraftArrival
