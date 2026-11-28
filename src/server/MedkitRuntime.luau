--!strict
--[=[
    MedkitRuntime: server adapter for inert medkit models and native prompts.
    Depends on level-owned anchors, MatchService, the deployed BalanceRuntime
    preset and GroundCombatRuntime's body/movement authority. GameRuntime calls
    interact after damage and results. The adapter never yields, has no respawn
    timer, and destroys all prompts and pending work at result or stop.
]=]
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage").Shared
local BalanceSchema = require(Shared.BalanceSchema)
local MapRules = require(Shared.MapRules)
local RateLimit = require(Shared.RateLimit)
local GroundCombatRuntime = require(script.Parent.GroundCombatRuntime)
local MatchService = require(script.Parent.MatchService)
local MedkitService = require(script.Parent.MedkitService)
local MedkitRuntime = {}

local REACH = 8 -- Distance in studs from the server-observed avatar root.
local TARGET_HEIGHT = 0.9 -- Prompt and sight sample height above stable floor.
local HEAL_FEEDBACK_SECONDS = 2

type Site = { id: string, pose: CFrame }
type Pickup = { model: Model, point: BasePart, connection: RBXScriptConnection }
type Request = { player: Player, character: Model, siteId: string, roundId: number }

export type Controller = {
    -- Resolve admitted requests after the frame's damage and outcome checks.
    interact: (number) -> (),
    -- Releases workspace models, prompt callbacks and pending requests. Idempotent.
    stop: () -> (),
}

-- Only live level solids and Terrain can obstruct use. Other characters,
-- physical fragments and the kit graphics do not take part in this query.
local function solidQuery(battlefield: Model): RaycastParams
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = { battlefield, workspace.Terrain }
    params.RespectCanCollide = true
    params.IgnoreWater = true
    return params
end

-- Authored markers store heading and a point over stable floor. Resolve the
-- floor once before play. The medkit remains at that pose if nearby panels fall.
local function readSites(battlefield: Model): ({ Site }?, string?)
    local markers = battlefield:FindFirstChild("MedkitAnchors")
    if not markers or not markers:IsA("Folder") then
        return nil, "missing MedkitAnchors"
    end
    local sites: { Site } = {}
    local unique: { [string]: boolean } = {}
    local params = solidQuery(battlefield)
    for _, marker in markers:GetChildren() do
        if
            not marker:IsA("BasePart")
            or not marker.Anchored
            or marker.CanCollide
            or marker.CanQuery
            or marker.CanTouch
            or marker.Transparency ~= 1
            or unique[marker.Name]
            or marker.CFrame.UpVector:Dot(Vector3.yAxis) < 0.999
            or not MapRules.inside(MapRules.defaults, marker.Position.X, marker.Position.Z)
        then
            return nil, "invalid medkit anchor: " .. marker.Name
        end
        local floor = workspace:Raycast(marker.Position, -Vector3.yAxis * 6, params)
        if
            not floor
            or floor.Normal.Y < 0.95
            or workspace:Raycast(floor.Position + Vector3.yAxis * 0.03, Vector3.yAxis * 1.8, params)
        then
            return nil, "medkit requires level support and case clearance: " .. marker.Name
        end
        unique[marker.Name] = true
        table.insert(sites, {
            id = marker.Name,
            pose = CFrame.new(floor.Position + Vector3.yAxis * 0.018) * marker.CFrame.Rotation,
        })
    end
    if #sites == 0 then
        return nil, "medkit anchors are empty"
    end
    return sites, nil
end

-- Validates source and level inputs before acquiring workspace ownership. The
-- balance reader returns the immutable current-round preset. No API yields.
function MedkitRuntime.start(
    world: Instance,
    assets: Instance,
    match: MatchService.Controller,
    groundCombat: GroundCombatRuntime.Controller,
    getBalance: () -> BalanceSchema.Values
): (Controller?, string?)
    if workspace:FindFirstChild("Medkits") then
        return nil, "Medkits already owned"
    end
    local template = assets:FindFirstChild("FieldMedkit")
    local battlefield = world:FindFirstChild("Battlefield")
    if not template or not template:IsA("Model") or not battlefield or not battlefield:IsA("Model") then
        return nil, "missing field medkit template or battlefield"
    end
    if not template:GetPivot():FuzzyEq(CFrame.identity, 0.001) then
        return nil, "invalid field medkit floor pivot"
    end
    for _, item in template:GetDescendants() do
        if item:IsA("BasePart") then
            if not item.Anchored or item.CanCollide or item.CanTouch or item.CanQuery then
                return nil, "field medkit geometry must be inert: " .. item.Name
            end
        elseif not item:IsA("DataModelMesh") then
            return nil, "unexpected field medkit descendant: " .. item.Name
        end
    end
    local sites, reason = readSites(battlefield)
    if not sites then
        return nil, reason
    end
    local siteIds: { string } = {}
    for _, site in sites do
        table.insert(siteIds, site.id)
    end

    local folder = Instance.new("Folder")
    folder.Name, folder.Parent = "Medkits", workspace
    local running = true
    local roundId: number? = nil
    local ledger: MedkitService.Controller? = nil
    local pickups: { [string]: Pickup } = {}
    local pending: { Request } = {}
    local queued: { [Player]: boolean } = {}
    local budgets: { [Player]: RateLimit.Bucket } = {}

    local function remove(pickup: Pickup)
        pickup.connection:Disconnect()
        pickup.model:Destroy()
    end

    local function clear()
        for _, pickup in pickups do
            remove(pickup)
        end
        table.clear(pickups)
        table.clear(pending)
        table.clear(queued)
        table.clear(budgets)
        roundId, ledger = nil, nil
    end

    local function spawn(site: Site, generation: number)
        local model = template:Clone()
        model.Name = site.id
        model:SetAttribute("MedkitRoundId", generation)
        model:PivotTo(site.pose)
        for _, item in model:GetDescendants() do
            if item:IsA("BasePart") then
                item:SetAttribute("ThermalNonCover", true)
            end
        end
        local point = Instance.new("Part")
        point.Name, point.Size = "InteractionPoint", Vector3.one * 0.2
        point.Anchored, point.CanCollide, point.CanQuery, point.CanTouch = true, false, false, false
        point.Transparency = 1
        point.Position, point.Parent = site.pose.Position + Vector3.yAxis * TARGET_HEIGHT, model

        local prompt = Instance.new("ProximityPrompt")
        prompt.Name, prompt.ObjectText, prompt.ActionText = "UseMedkit", "Medkit", "Use"
        prompt.KeyboardKeyCode, prompt.MaxActivationDistance = Enum.KeyCode.F, REACH
        prompt.RequiresLineOfSight, prompt.ClickablePrompt = true, true
        prompt.Parent = point
        local connection = prompt.Triggered:Connect(function(player)
            local now = workspace:GetServerTimeNow()
            local current = match.snapshot()
            local character = player.Character
            if
                not running
                or not prompt.Enabled
                or roundId ~= generation
                or current.roundId ~= generation
                or not character
                or queued[player]
                or player.Parent ~= Players
                or not MedkitService.eligible(current, current.members[player.UserId], now)
            then
                return
            end
            local budget = budgets[player]
            if not budget then
                budget = assert(RateLimit.new(3, 2, now), "invalid medkit request budget")
                budgets[player] = budget
            end
            if RateLimit.take(budget, now) then
                queued[player] = true
                table.insert(
                    pending,
                    { player = player, character = character, siteId = site.id, roundId = generation }
                )
            end
        end)
        pickups[site.id] = { model = model, point = point, connection = connection }
        model.Parent = folder
    end

    local function resolve(request: Request, round: MatchService.Snapshot, now: number, params: RaycastParams)
        local active = ledger
        local pickup = pickups[request.siteId]
        local character, player = request.character, request.player
        local member = round.members[player.UserId]
        if
            not active
            or not pickup
            or not active.available(request.siteId)
            or request.roundId ~= round.roundId
            or player.Parent ~= Players
            or player.Character ~= character
            or not MedkitService.eligible(round, member, now)
        then
            return
        end
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local root, head = character:FindFirstChild("HumanoidRootPart"), character:FindFirstChild("Head")
        if not humanoid or not root or not root:IsA("BasePart") or not head or not head:IsA("BasePart") then
            return
        end
        local target = pickup.point.Position
        if (root.Position - target).Magnitude > REACH or not groundCombat.validateGround(player) then
            return
        end
        local offset = target - head.Position
        -- Test both directions because a cast can miss a solid containing its origin.
        local clearSight = offset.Magnitude > 0
            and workspace:Raycast(head.Position, offset, params) == nil
            and workspace:Raycast(target, -offset, params) == nil
        local health = humanoid.Health
        local healed = active.use(round, now, {
            member = member,
            roundId = request.roundId,
            siteId = request.siteId,
            health = health,
            maxHealth = humanoid.MaxHealth,
            withinReach = true,
            clearSight = clearSight,
        })
        if healed then
            humanoid.Health = healed
            humanoid:SetAttribute("MedkitHealAmount", healed - health)
            humanoid:SetAttribute("MedkitHealUntil", now + HEAL_FEEDBACK_SECONDS)
            pickups[request.siteId] = nil
            remove(pickup)
        end
    end

    return {
        interact = function(now)
            if not running then
                return
            end
            local round = match.snapshot()
            if round.phase ~= "Scatter" and round.phase ~= "Active" then
                if roundId then
                    clear()
                end
                return
            end
            if roundId ~= round.roundId then
                clear()
                roundId = round.roundId
                ledger = MedkitService.new(round.roundId, getBalance().medkitHeal, siteIds)
                for _, site in sites do
                    spawn(site, round.roundId)
                end
            end
            if #pending > 0 then
                local currentMap = world:FindFirstChild("Battlefield")
                if currentMap and currentMap:IsA("Model") then
                    local params = solidQuery(currentMap)
                    for _, request in pending do
                        resolve(request, round, now, params)
                    end
                end
                table.clear(pending)
                table.clear(queued)
            end
        end,
        stop = function()
            if running then
                running = false
                clear()
                folder:Destroy()
            end
        end,
    },
        nil
end

return MedkitRuntime
