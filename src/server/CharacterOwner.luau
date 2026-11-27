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
local BalanceSchema = require(game:GetService("ReplicatedStorage").Shared.BalanceSchema)
local MatchService = require(script.Parent.MatchService)
local HttpService = game:GetService("HttpService")
local CharacterOwner = {}
export type Controller = {
    -- Requests anchor/role/round placement, coalescing repeated placement for the same generation.
    request: (string, string, number) -> (),
    -- Releases the current Ground body after the roster is ready.
    releaseGround: (number) -> (),
    clear: () -> (),
    stop: () -> (),
    resources: () -> { connections: number, spawnTasks: number },
}
type Request = { token: number, roundId: number, anchor: string, role: string }

-- Creates an owner with no character/listeners. Call stop before releasing the Player.
-- The caller has already checked there is no previous RoundCharacterLoad lease.
function CharacterOwner.new(
    player: Player,
    match: MatchService.Controller,
    getBalance: (() -> BalanceSchema.Values)?
): Controller
    local running = true
    local token = 0
    local queued: Request? = nil
    local desired: Request? = nil
    local lobbyRetryAt = 0
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
        desired = nil
        clearExisting()
    end
    owner = {
        clear = clear,
        releaseGround = function(roundId)
            local request = desired
            if not running or not request or request.roundId ~= roundId or request.role ~= "Ground" then
                return
            end
            local character = player.Character
            local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
            if root and root:IsA("BasePart") then
                root.Anchored = false
            end
        end,
        request = function(anchor, role, roundId)
            if not running then
                return
            end
            if
                desired
                and desired.anchor == anchor
                and desired.role == role
                and desired.roundId == roundId
            then
                return
            end
            if role == "Waiting" and workspace:GetServerTimeNow() < lobbyRetryAt then
                return
            end
            token += 1
            local placement: Request = { token = token, roundId = roundId, anchor = anchor, role = role }
            desired = placement
            queued = desired
            if loading then
                return
            end
            loading = true
            -- Defer engine loads until the current frame finishes releasing the
            -- life and recovering any carried launcher from its battlefield pose.
            task.defer(function()
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
                        desired = nil
                        if request.role ~= "Waiting" then
                            match.abort(request.roundId, "CharacterLoadFailed")
                        else
                            lobbyRetryAt = workspace:GetServerTimeNow() + 2
                        end
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
                        desired = nil
                        if request.role ~= "Waiting" then
                            match.abort(request.roundId, "CharacterIncomplete")
                        else
                            lobbyRetryAt = workspace:GetServerTimeNow() + 2
                        end
                        break
                    end
                    if humanoid.Health <= 0 then
                        desired = nil
                        if request.role ~= "Waiting" then
                            match.abort(request.roundId, "DeadDeploymentCharacter")
                        else
                            lobbyRetryAt = workspace:GetServerTimeNow() + 2
                        end
                        break
                    end
                    if request.role == "Ground" and getBalance then
                        humanoid.MaxHealth = getBalance().groundHealth
                        humanoid.Health = humanoid.MaxHealth
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
                    root.Anchored = request.role == "Gunship"
                        or (request.role == "Ground" and match.snapshot().phase == "Deploying")
                    if request.role ~= "Ground" then
                        -- Waiting players can walk around the protected lobby.
                        local protection = Instance.new("ForceField")
                        protection.Name = "StationProtection"
                        protection.Visible = false
                        protection.Parent = character
                    end
                    -- A character can disappear without Humanoid.Died (for
                    -- example an explicit reset/removal or a departure). A
                    -- ground model loss immediately revokes life; MatchService
                    -- distinguishes it from a confirmed death during the batch.
                    -- Internal clear/request disconnects the old generation first.
                    local characterLost = false
                    local function loseCharacter(deploymentReason: string, died: boolean)
                        if not running or token ~= request.token then
                            return
                        end
                        local state = match.snapshot()
                        if state.roundId ~= request.roundId then
                            return
                        end
                        local inPlay = state.phase == "Scatter" or state.phase == "Active"
                        if inPlay and request.role == "Ground" then
                            if died then
                                match.eliminate(player.UserId, request.roundId)
                            else
                                match.characterRemoved(player.UserId, request.roundId)
                            end
                            return
                        end
                        if characterLost then
                            return
                        end
                        characterLost = true
                        if request.role == "Waiting" or (request.role == "Gunship" and inPlay) then
                            -- Protected body replacement preserves the current round life state.
                            desired = nil
                            owner.request(request.anchor, request.role, request.roundId)
                        elseif state.phase == "Deploying" then
                            if died then
                                match.abort(request.roundId, deploymentReason)
                            else
                                match.characterRemoved(player.UserId, request.roundId)
                                -- A deferred death signal may supply a definite
                                -- reason while the roster is still deploying.
                                characterLost = false
                            end
                        end
                    end
                    table.insert(
                        connections,
                        humanoid.Died:Connect(function()
                            loseCharacter("DeathDuringDeployment", true)
                        end)
                    )
                    table.insert(
                        connections,
                        player.CharacterRemoving:Connect(function(removed)
                            if removed == character then
                                loseCharacter("CharacterRemovedDuringDeployment", false)
                            end
                        end)
                    )
                    -- Destroy() can leave Player.Character pointing at the now
                    -- unparented model without CharacterRemoving. Observe the
                    -- owned model directly as well as the Player property.
                    table.insert(
                        connections,
                        character.Destroying:Connect(function()
                            loseCharacter("CharacterRemovedDuringDeployment", false)
                        end)
                    )
                    if request.role ~= "Waiting" then
                        match.ready(player.UserId, request.roundId)
                    end
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
