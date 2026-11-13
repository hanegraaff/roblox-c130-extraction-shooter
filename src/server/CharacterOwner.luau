--!strict
--[=[
    CharacterOwner: server-only explicit character loading for one Player. Depends on
    MatchService, authored anchor poses and Roblox avatar loading. Serializes yielding
    loads, tags callbacks with a generation and leases in-flight loads on the Player.
    New runtimes must wait for old load leases to drain before acquiring characters.
    Death or external removal consumes an owned ground life once; internal cleanup
    disconnects first. Operator loss requests a replacement protected placeholder.
    All public calls are nonyielding; stop is idempotent and invalidates queued work.
]=]
local MatchService = require(script.Parent.MatchService)
local HttpService = game:GetService("HttpService")
local CharacterOwner = {}
export type Controller = {
    request: (string, string, number) -> (),
    clear: () -> (),
    stop: () -> (),
    resources: () -> { connections: number, spawnTasks: number },
}
type Request = { token: number, roundId: number, anchor: string, role: string }

-- Creates an owner with no character/listeners. Call stop before releasing the Player.
-- The caller has already checked there is no previous RoundCharacterLoad lease.
function CharacterOwner.new(player: Player, match: MatchService.Controller): Controller
    local running = true
    local token = 0
    local queued: Request? = nil
    local loading = false
    local connections: { RBXScriptConnection } = {}
    local lease = HttpService:GenerateGUID(false)
    local owner: Controller
    local function clearExisting()
        for _, connection in connections do
            connection:Disconnect()
        end
        table.clear(connections)
        if player.Character then
            player.Character:Destroy()
            player.Character = nil
        end
    end
    local function clear()
        token += 1
        queued = nil
        clearExisting()
    end
    owner = {
        clear = clear,
        request = function(anchor, role, roundId)
            if not running then
                return
            end
            token += 1
            queued = { token = token, roundId = roundId, anchor = anchor, role = role }
            if loading then
                return
            end
            loading = true
            task.spawn(function()
                -- Only one LoadCharacterAsync may be in flight for this Player. New
                -- requests replace queued intent while the old load finishes safely.
                while running and queued do
                    local request = queued
                    queued = nil
                    clearExisting()
                    player:SetAttribute("RoundCharacterLoad", lease)
                    local ok, reason = pcall(function()
                        player:LoadCharacterAsync()
                    end)
                    local ownsLoad = player:GetAttribute("RoundCharacterLoad") == lease
                    if ownsLoad then
                        player:SetAttribute("RoundCharacterLoad", nil)
                    end
                    if not running then
                        if ownsLoad then
                            clearExisting()
                        end
                        break
                    end
                    if request.token ~= token then
                        clearExisting()
                        continue
                    end
                    if not ok then
                        warn("Character deployment failed: " .. tostring(reason))
                        match.abort(request.roundId, "CharacterLoadFailed")
                        break
                    end
                    local character = player.Character
                    local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
                    local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
                    local anchorPart = workspace.World.Battlefield.Anchors:FindFirstChild(request.anchor)
                    if
                        not character
                        or not humanoid
                        or not root
                        or not root:IsA("BasePart")
                        or not anchorPart
                        or not anchorPart:IsA("BasePart")
                    then
                        match.abort(request.roundId, "CharacterIncomplete")
                        break
                    end
                    if humanoid.Health <= 0 then
                        match.abort(request.roundId, "DeadDeploymentCharacter")
                        break
                    end
                    character:PivotTo(anchorPart.CFrame)
                    root.AssemblyLinearVelocity = Vector3.zero
                    local function collision(item: Instance)
                        if item:IsA("BasePart") then
                            item.CollisionGroup = "RoundCharacters"
                        end
                    end
                    for _, item in character:GetDescendants() do
                        collision(item)
                    end
                    table.insert(connections, character.DescendantAdded:Connect(collision))
                    if request.role ~= "Ground" then
                        -- Waiting players can walk around the protected lobby. Only
                        -- the assigned operator is fixed at the placeholder station.
                        root.Anchored = request.role == "Gunship"
                        local protection = Instance.new("ForceField")
                        protection.Name = "StationProtection"
                        protection.Visible = false
                        protection.Parent = character
                    end
                    -- A character can disappear without Humanoid.Died (for
                    -- example an explicit reset/removal). Both signals consume
                    -- this owned generation's life once. Internal clear/request
                    -- disconnects both before destroying its old character.
                    local characterLost = false
                    local function loseCharacter(deploymentReason: string)
                        if not running or token ~= request.token or characterLost then
                            return
                        end
                        local state = match.snapshot()
                        if state.roundId ~= request.roundId then
                            return
                        end
                        characterLost = true
                        if state.phase == "Deploying" then
                            match.abort(request.roundId, deploymentReason)
                        elseif request.role == "Ground" then
                            match.eliminate(player.UserId, request.roundId)
                        elseif state.phase == "Lobby" or state.phase == "Active" then
                            -- Operator reset rebuilds only the protected placeholder body.
                            owner.request(request.anchor, request.role, request.roundId)
                        end
                    end
                    table.insert(
                        connections,
                        humanoid.Died:Connect(function()
                            loseCharacter("DeathDuringDeployment")
                        end)
                    )
                    table.insert(
                        connections,
                        player.CharacterRemoving:Connect(function(removed)
                            if removed == character then
                                loseCharacter("CharacterRemovedDuringDeployment")
                            end
                        end)
                    )
                    match.ready(player.UserId, request.roundId)
                end
                loading = false
            end)
        end,
        stop = function()
            if running then
                running = false
                clear()
            end
        end,
        resources = function()
            return { connections = #connections, spawnTasks = if loading then 1 else 0 }
        end,
    }
    return owner
end

return CharacterOwner
