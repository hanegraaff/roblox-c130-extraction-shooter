--!strict
--[=[
    TheaterSpectating: local-only theater prompt and avatar control lock.
    Depends on the P22 television and the standard PlayerModule movement owner.
    RoundPanel supplies eligibility and owns the spectator camera. There is no
    transport and a successful interaction grants no gameplay privilege.
]=]
local TheaterSpectating = {}

type Controls = { Disable: (Controls) -> (), Enable: (Controls) -> () }
type PlayerModule = { GetControls: (PlayerModule) -> Controls }
export type Controller = {
    -- Refreshes eligibility and returns true while watching the supplied round.
    update: (number, boolean) -> boolean,
    -- Releases the movement lock, without replacing or moving the lobby avatar.
    exit: () -> (),
    -- Idempotently releases controls, prompt, listener and pending initialization.
    stop: () -> (),
}

local televisionName = "P22_Room04_757_01"
local activationDistance = 10
local loadModule = (require :: unknown) :: (ModuleScript) -> PlayerModule

local function findTelevision(): BasePart?
    local world = workspace:FindFirstChild("World")
    local battlefield = if world then world:FindFirstChild("Battlefield") else nil
    local lobby = if battlefield then battlefield:FindFirstChild("LobbyStation") else nil
    local art = if lobby then lobby:FindFirstChild("LobbyArt") else nil
    local screen = if art then art:FindFirstChild(televisionName) else nil
    return if screen and screen:IsA("BasePart") then screen else nil
end

local function lobbyRoot(player: Player): BasePart?
    local character = player.Character
    if not character or not character:IsDescendantOf(workspace) then
        return nil
    end
    local root = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if
        root
        and root:IsA("BasePart")
        and not root.Anchored
        and humanoid
        and humanoid.Health > 0
        and character:FindFirstChild("StationProtection")
    then
        return root
    end
    return nil
end

-- Creates a nonyielding owner. A bounded task acquires Roblox's stock desktop
-- and touch controls so entry can disable avatar movement in either layout.
function TheaterSpectating.new(player: Player): Controller
    local running = true
    local controls: Controls? = nil
    local watchingRoot: BasePart? = nil
    local television: BasePart? = nil
    local roundId = -1
    local eligible = false
    local prompt: ProximityPrompt? = nil
    local trigger: RBXScriptConnection? = nil
    local setup = task.defer(function()
        local scripts = player:WaitForChild("PlayerScripts", 10)
        local module = if scripts then scripts:WaitForChild("PlayerModule", 10) else nil
        if running and module and module:IsA("ModuleScript") then
            controls = loadModule(module):GetControls()
        end
    end)

    local function exit()
        if watchingRoot then
            watchingRoot = nil
            if controls then
                controls:Enable()
            end
        end
    end

    local function clearPrompt()
        if trigger then
            trigger:Disconnect()
            trigger = nil
        end
        if prompt then
            prompt:Destroy()
            prompt = nil
        end
        television = nil
    end

    return {
        update = function(nextRound, nextEligible)
            if not running then
                return false
            end
            local root = lobbyRoot(player)
            local screen = if nextEligible then findTelevision() else nil
            if roundId ~= nextRound or screen ~= television or root ~= watchingRoot then
                exit()
            end
            roundId, eligible = nextRound, nextEligible
            if screen ~= television then
                clearPrompt()
                if screen then
                    local action = Instance.new("ProximityPrompt")
                    action.Name = "TheaterSpectate"
                    action.ActionText = "Spectate"
                    action.ObjectText = "Theater TV"
                    action.MaxActivationDistance = activationDistance
                    action.Enabled = false
                    action.Parent = screen
                    television, prompt = screen, action
                    trigger = action.Triggered:Connect(function(byPlayer)
                        local currentRoot = lobbyRoot(player)
                        if
                            byPlayer == player
                            and eligible
                            and controls
                            and not watchingRoot
                            and currentRoot
                            and (currentRoot.Position - screen.Position).Magnitude <= activationDistance
                        then
                            watchingRoot = currentRoot
                            controls:Disable()
                            action.Enabled = false
                        end
                    end)
                end
            end
            if prompt then
                prompt.Enabled = running and root ~= nil and watchingRoot == nil and controls ~= nil
            end
            return watchingRoot ~= nil
        end,
        exit = exit,
        stop = function()
            if running then
                running = false
                if coroutine.status(setup) == "suspended" then
                    task.cancel(setup)
                end
                exit()
                clearPrompt()
            end
        end,
    }
end

return TheaterSpectating
