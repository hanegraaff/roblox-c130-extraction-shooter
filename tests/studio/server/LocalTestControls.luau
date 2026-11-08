--!strict
--[=[
    LocalTestControls: test-mapping-only solo preview and Command Bar shortcuts. Owns two
    BindableFunctions under ServerStorage and one preview-containment listener.
    Depends on the actual MatchRuntime and authored map. No client remote or fake
    roster exists. Solo exploration leaves role/life/phase unchanged; real round
    starts still enforce the runtime's population and character readiness rules.
]=]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local MatchRuntime = require(game:GetService("ServerScriptService").Server.MatchRuntime)
local MapRules = require(game:GetService("ReplicatedStorage").Shared.MapRules)
local LocalTestControls = {}

-- Installs server-only shortcuts after foundational tests. Returns idempotent cleanup.
-- Calls do not yield; missing bodies, wrong phases or insufficient rosters reject.
-- The caller stops these controls before stopping their supplied round owner.
function LocalTestControls.start(rounds: MatchRuntime.Controller): () -> ()
    assert(RunService:IsStudio(), "local controls require Studio")
    assert(ServerStorage:FindFirstChild("DevelopmentSettings"), "local controls require test mapping")
    assert(not ServerStorage:FindFirstChild("LocalTestControls"), "local controls already owned")
    local folder = Instance.new("Folder")
    folder.Name = "LocalTestControls"
    local preview: Player? = nil
    local explored = false
    local running = true
    local function move(player: Player, anchor: string): (boolean, string?)
        local character = player.Character
        local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
        local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
        local target = workspace.World.Battlefield.Anchors:FindFirstChild(anchor)
        if not character or not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
            return false, "character is not ready; retry after it spawns"
        end
        if not target or not target:IsA("BasePart") then
            return false, "map anchor unavailable"
        end
        character:PivotTo(target.CFrame)
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        return true, nil
    end
    local function bind(name: string, callback: () -> (boolean, string?))
        local control = Instance.new("BindableFunction")
        control.Name = name
        control.OnInvoke = callback
        control.Parent = folder
    end
    bind("ExploreMap", function()
        if not running or rounds.match.snapshot().phase ~= "Lobby" then
            return false, "solo exploration requires Lobby"
        end
        local players = Players:GetPlayers()
        if #players ~= 1 then
            return false, "solo exploration requires one client"
        end
        local ok, reason = move(players[1], "Ground05")
        if ok then
            preview = players[1]
            players[1]:SetAttribute("LocalMapPreview", true)
            explored = true
        end
        return ok, reason
    end)
    bind("ReturnToLobby", function()
        if not running or not preview or rounds.match.snapshot().phase ~= "Lobby" then
            return false, "no solo lobby preview is active"
        end
        local player = preview
        local ok, reason = move(player, "Lobby")
        if ok then
            player:SetAttribute("LocalMapPreview", nil)
            preview = nil
        end
        return ok, reason
    end)
    folder.Parent = ServerStorage
    local connection = RunService.Heartbeat:Connect(function()
        if not explored and not preview and #Players:GetPlayers() == 1 then
            local explore = folder:FindFirstChild("ExploreMap")
            if explore and explore:IsA("BindableFunction") then
                explore:Invoke()
            end
        end
        local player = preview
        if not player then
            return
        end
        if player.Parent ~= Players or rounds.match.snapshot().phase ~= "Lobby" then
            player:SetAttribute("LocalMapPreview", nil)
            preview = nil
            return
        end
        local character = player.Character
        local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
        if root and root:IsA("BasePart") then
            local position = root.Position
            if
                not MapRules.inside(MapRules.defaults, position.X, position.Z)
                or position.Y < MapRules.defaults.killY
            then
                move(player, "Ground05")
            end
        end
    end)
    return function()
        if not running then
            return
        end
        running = false
        connection:Disconnect()
        if preview then
            preview:SetAttribute("LocalMapPreview", nil)
            preview = nil
        end
        folder:Destroy()
    end
end

return LocalTestControls
