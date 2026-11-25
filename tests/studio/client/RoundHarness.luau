--!strict
--[=[
    RoundHarness: test-only client observations for real multi-client P03 acceptance.
    Installs a bounded discovery task and one owned test listener. Production builds
    exclude this module and transport. Reports actual local attributes/camera and sends
    real production commands; it never grants roles, changes game state or fakes clients.
]=]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StudioTestService = game:GetService("StudioTestService")
local GuiService = game:GetService("GuiService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local RoundHarness = {}

type Probe = {
    kind: string,
    roundId: number?,
    role: string?,
    life: string?,
    phase: string?,
    deadlineSeconds: number?,
    intermissionUntil: number?,
    targetId: number?,
    sequence: number?,
}

local function awaitCondition(predicate: () -> boolean, label: string, seconds: number?)
    local deadline = os.clock() + (seconds or 8)
    while not predicate() and os.clock() < deadline do
        task.wait(0.05)
    end
    assert(predicate(), "client timeout: " .. label)
end

local function theaterPrompt(): ProximityPrompt?
    local screen = workspace.World.Battlefield.LobbyStation.LobbyArt:FindFirstChild("P22_Room04_757_01")
    local prompt = if screen then screen:FindFirstChild("TheaterSpectate") else nil
    if screen and prompt then
        for _, child in screen:GetChildren() do
            assert(child == prompt or child.Name ~= prompt.Name, "duplicate theater prompt")
        end
    end
    return if prompt and prompt:IsA("ProximityPrompt") then prompt else nil
end

local function expectTheaterTarget(player: Player, targetId: number?)
    awaitCondition(function()
        local target = Players:GetPlayerByUserId(targetId or 0)
        local character = if target then target.Character else nil
        local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
        local camera = workspace.CurrentCamera
        return player:GetAttribute("Life") == "Eliminated"
            and camera ~= nil
            and humanoid ~= nil
            and camera.CameraSubject == humanoid
    end, "living teammate camera subject")
end

local function ownCamera(player: Player): boolean
    local character = player.Character
    local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
    local camera = workspace.CurrentCamera
    return humanoid ~= nil
        and camera ~= nil
        and camera.CameraSubject == humanoid
        and camera.CameraType == Enum.CameraType.Custom
end

local function roundHud(player: Player): ScreenGui
    local gui = player.PlayerGui:FindFirstChild("RoundHUD")
    assert(gui and gui:IsA("ScreenGui"), "round HUD missing")
    return gui
end

-- Nonyielding installation. Ordinary local sessions simply time out discovery without
-- creating test transport; automated sessions disconnect this listener on remote removal.
function RoundHarness.run()
    task.spawn(function()
        local remote = ReplicatedStorage:WaitForChild("P03Harness", 120)
        if not remote or not remote:IsA("RemoteEvent") then
            return
        end
        local player = Players.LocalPlayer
        local shown: { [ProximityPrompt]: boolean } = {}
        local promptShown = ProximityPromptService.PromptShown:Connect(function(prompt)
            if prompt.Name == "TheaterSpectate" then
                shown[prompt] = true
            end
        end)
        local promptHidden = ProximityPromptService.PromptHidden:Connect(function(prompt)
            shown[prompt] = nil
        end)
        local connection: RBXScriptConnection? = nil
        local removal: RBXScriptConnection? = nil
        connection = remote.OnClientEvent:Connect(function(token: number, request: Probe)
            local ok, detail = pcall(function()
                if request.kind == "Observe" then
                    awaitCondition(function()
                        local status = ReplicatedStorage:FindFirstChild("RoundState")
                        return status ~= nil
                            and status:GetAttribute("RoundId") == request.roundId
                            and status:GetAttribute("Phase") == request.phase
                            and status:GetAttribute("DeadlineSeconds") == request.deadlineSeconds
                            and (request.intermissionUntil == nil or status:GetAttribute("IntermissionUntil") == request.intermissionUntil)
                            and player:GetAttribute("RoundId") == request.roundId
                            and player:GetAttribute("Role") == request.role
                            and player:GetAttribute("Life") == request.life
                    end, "replicated role/phase/deadline")
                    assert(player.PlayerGui:FindFirstChild("RoundHUD"), "round UI missing")
                elseif request.kind == "NoTheaterPrompt" then
                    assert(theaterPrompt() == nil, "active player has a theater prompt")
                elseif request.kind == "DistantTheater" or request.kind == "EnterTheater" then
                    awaitCondition(function()
                        local prompt = theaterPrompt()
                        return prompt ~= nil and prompt.Enabled
                    end, "eligible theater prompt mounted")
                    local prompt = assert(theaterPrompt())
                    local roundLabel = roundHud(player):FindFirstChild("Round")
                    assert(roundLabel and roundLabel:IsA("TextLabel"), "missing round guidance label")
                    local screen = prompt.Parent
                    assert(
                        screen
                            and screen:IsA("MeshPart")
                            and screen.TextureID == "rbxassetid://97488158099796",
                        "theater image changed"
                    )
                    local input =
                        assert(UserInputService:CreateVirtualInput(), "Studio VirtualInput unavailable")
                    local function pressPromptKey()
                        input:SendKey(true, prompt.KeyboardKeyCode)
                        RunService.RenderStepped:Wait()
                        input:SendKey(false, prompt.KeyboardKeyCode)
                    end
                    if request.kind == "DistantTheater" then
                        assert(not shown[prompt], "theater prompt visible outside its range")
                        assert(roundLabel.Visible, "lobby guidance hidden outside theater interaction range")
                        pressPromptKey()
                        RunService.Heartbeat:Wait()
                        assert(
                            ownCamera(player) and roundHud(player):GetAttribute("View") == "RoundLobby",
                            "out-of-range entry took camera"
                        )
                        return true
                    end
                    local root = assert(
                        player.Character and player.Character:FindFirstChild("HumanoidRootPart"),
                        "missing lobby root"
                    )
                    assert(root:IsA("BasePart"), "expected a lobby root part")
                    awaitCondition(function()
                        return (root.Position - screen.Position).Magnitude < prompt.MaxActivationDistance
                    end, "replicated lobby avatar entered TV prompt range at " .. tostring(
                        root.Position
                    ), 3)
                    local currentCamera = assert(workspace.CurrentCamera, "missing client camera")
                    local binding = "P23TheaterProbe-" .. tostring(token)
                    -- Keep the TV centered for native prompt visibility while the
                    -- stock camera settles after the replicated fixture move.
                    RunService:BindToRenderStep(binding, Enum.RenderPriority.Camera.Value + 1, function()
                        currentCamera.CFrame =
                            CFrame.lookAt(root.Position + Vector3.new(0, 3, 5), screen.Position)
                    end)
                    local triggered = false
                    local promptTrigger = prompt.Triggered:Connect(function(actor)
                        triggered = actor == player
                    end)
                    local entered, problem = pcall(function()
                        awaitCondition(function()
                            return shown[prompt] == true
                        end, "native theater prompt visibility", 3)
                        awaitCondition(function()
                            return not roundLabel.Visible
                        end, "lobby guidance cleared the native theater prompt", 1)
                        pressPromptKey()
                        awaitCondition(function()
                            return triggered
                        end, "native theater prompt activation from keyboard", 2)
                        return true
                    end)
                    promptTrigger:Disconnect()
                    RunService:UnbindFromRenderStep(binding)
                    assert(entered, tostring(problem))
                    awaitCondition(function()
                        return roundHud(player):GetAttribute("View") == "Spectator"
                    end, "theater accepted activation", 2)
                    expectTheaterTarget(player, request.targetId)
                    local movement = assert(
                        player.Character and player.Character:FindFirstChildOfClass("Humanoid"),
                        "missing lobby humanoid"
                    )
                    input:SendKey(true, Enum.KeyCode.W)
                    RunService.RenderStepped:Wait()
                    RunService.RenderStepped:Wait()
                    input:SendKey(false, Enum.KeyCode.W)
                    assert(movement.MoveDirection.Magnitude < 0.01, "lobby avatar moved while spectating")
                elseif request.kind == "FollowTheater" then
                    expectTheaterTarget(player, request.targetId)
                elseif request.kind == "ExitTheater" then
                    local button = roundHud(player):FindFirstChild("ExitSpectating")
                    assert(
                        button and button:IsA("TextButton") and button.Visible,
                        "spectator exit button missing"
                    )
                    local inset = GuiService:GetGuiInset()
                    local mouse = button.AbsolutePosition + button.AbsoluteSize / 2 + inset
                    local input =
                        assert(UserInputService:CreateVirtualInput(), "Studio VirtualInput unavailable")
                    input:SendMouseButton(mouse, Enum.UserInputType.MouseButton1, true)
                    RunService.RenderStepped:Wait()
                    input:SendMouseButton(mouse, Enum.UserInputType.MouseButton1, false)
                    awaitCondition(function()
                        return ownCamera(player) and not button.Visible
                    end, "exit restored the lobby camera")
                    local movement = assert(
                        player.Character and player.Character:FindFirstChildOfClass("Humanoid"),
                        "missing lobby humanoid"
                    )
                    local moved = false
                    input:SendKey(true, Enum.KeyCode.S)
                    for _ = 1, 5 do
                        RunService.RenderStepped:Wait()
                        moved = moved or movement.MoveDirection.Magnitude > 0.01
                    end
                    input:SendKey(false, Enum.KeyCode.S)
                    assert(moved, "spectator exit left lobby movement disabled")
                elseif request.kind == "Intermission" then
                    awaitCondition(function()
                        local state = ReplicatedStorage:FindFirstChild("RoundState")
                        local label = roundHud(player):FindFirstChild("Round")
                        return state ~= nil
                            and state:GetAttribute("IntermissionUntil") == request.intermissionUntil
                            and ownCamera(player)
                            and label ~= nil
                            and label:IsA("TextLabel")
                            and string.find(label.Text, "Intermission", 1, true) ~= nil
                            and string.find(label.Text, "C-130 wins", 1, true) ~= nil
                            and theaterPrompt() == nil
                    end, "lobby result and replicated countdown")
                elseif request.kind == "LobbyCamera" then
                    awaitCondition(function()
                        local character = player.Character
                        local button = roundHud(player):FindFirstChild("ExitSpectating")
                        return character ~= nil
                            and character:FindFirstChild("StationProtection") ~= nil
                            and ownCamera(player)
                            and button ~= nil
                            and button:IsA("TextButton")
                            and not button.Visible
                    end, "lobby camera restoration")
                elseif request.kind == "SendRejected" or request.kind == "Surrender" then
                    local status = ReplicatedStorage:FindFirstChild("RoundState")
                    assert(status, "round state missing")
                    local command = status:FindFirstChild("Surrender")
                    assert(command and command:IsA("RemoteEvent"), "production surrender remote missing")
                    command:FireServer({
                        roundId = request.roundId,
                        sequence = request.sequence,
                        action = "Surrender",
                    })
                elseif request.kind == "Leave" then
                    assert(StudioTestService:CanLeaveTest(), "actual client cannot leave test")
                else
                    error("unknown harness directive")
                end
                return true
            end)
            remote:FireServer(token, { passed = ok, detail = if ok then "observed" else tostring(detail) })
            if ok and request.kind == "Leave" then
                task.delay(0.2, function()
                    StudioTestService:LeaveTest()
                end)
            end
        end)
        remote:FireServer(0, { passed = true })
        removal = remote.AncestryChanged:Connect(function()
            if not remote:IsDescendantOf(ReplicatedStorage) then
                promptShown:Disconnect()
                promptHidden:Disconnect()
                if connection then
                    connection:Disconnect()
                end
                if removal then
                    removal:Disconnect()
                end
            end
        end)
    end)
end

return RoundHarness
