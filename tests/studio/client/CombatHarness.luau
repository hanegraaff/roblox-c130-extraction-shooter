--!strict
-- Test-only P05 client transport: sends production requests and observes replication.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local CombatHarness = {}
local function waitFor(predicate: () -> boolean, message: string)
    local deadline = os.clock() + 8
    while not predicate() and os.clock() < deadline do
        task.wait(0.03)
    end
    assert(predicate(), "client P05 timeout: " .. message)
end
function CombatHarness.run()
    task.spawn(function()
        local remote = ReplicatedStorage:WaitForChild("P05Harness", 50)
        if not remote or not remote:IsA("RemoteEvent") then
            return
        end
        local listener: RBXScriptConnection
        listener = remote.OnClientEvent:Connect(function(token: number, kind: string, payload: unknown)
            local ok, reason = pcall(function()
                local state = ReplicatedStorage:WaitForChild("AircraftState", 5)
                assert(state, "aircraft state missing")
                if kind == "Fire" or kind == "Select" or kind == "Flood" then
                    local target =
                        state:FindFirstChild(if kind == "Select" then "SelectWeapon" else "FireWeapon")
                    assert(target and target:IsA("RemoteEvent"), "production combat transport missing")
                    if kind == "Flood" then
                        for _ = 1, 30 do
                            target:FireServer(payload)
                        end
                    else
                        target:FireServer(payload)
                    end
                elseif kind == "OperatorPresentation" then
                    local player = Players.LocalPlayer
                    local gui = player.PlayerGui
                    local roundHud = gui:FindFirstChild("RoundHUD")
                    local banner = gui:FindFirstChild("FoundationStatus")
                    local thermal = gui:FindFirstChild("ThermalHUD")
                    local round = if roundHud then roundHud:FindFirstChild("Round") else nil
                    local profile = if thermal then thermal:FindFirstChild("Profile") else nil
                    assert(
                        round and round:IsA("TextLabel") and profile and profile:IsA("TextLabel"),
                        "operator labels missing"
                    )
                    assert(
                        banner and banner:IsA("ScreenGui") and not banner.Enabled,
                        "operator foundation banner obscures battlefield"
                    )
                    local camera = workspace.CurrentCamera
                    assert(camera, "operator camera missing")
                    local effect = camera:FindFirstChild("OperatorThermal")
                    assert(
                        effect
                            and effect:IsA("ColorCorrectionEffect")
                            and effect.Saturation == -1
                            and effect.Brightness >= 0.18
                            and effect.Contrast <= 0,
                        "thermal settings too dark or not grayscale"
                    )
                    game:GetService("RunService").RenderStepped:Wait()
                    local origin, size = round.AbsolutePosition, round.AbsoluteSize
                    local center = camera.ViewportSize * 0.5
                    assert(
                        not (
                                center.X >= origin.X
                                and center.X <= origin.X + size.X
                                and center.Y >= origin.Y
                                and center.Y <= origin.Y + size.Y
                            ),
                        "round label covers center targeting"
                    )
                    if game:GetService("UserInputService").TouchEnabled then
                        local touchGui = gui:FindFirstChild("TouchGui")
                        assert(
                            not touchGui or (touchGui:IsA("ScreenGui") and not touchGui.Enabled),
                            "operator default movement joystick remains visible"
                        )
                        local controls = gui:FindFirstChild("OperatorTouchControls")
                        assert(
                            controls and controls:FindFirstChild("Fire") and controls:FindFirstChild("PanUp"),
                            "operator touch controls missing"
                        )
                    end
                elseif kind == "Observe" then
                    local round = ReplicatedStorage:FindFirstChild("RoundState")
                    local effects = workspace:FindFirstChild("CombatEffects")
                    assert(
                        round
                            and effects
                            and state:GetAttribute("Selection")
                            and state:GetAttribute("Readiness"),
                        "replicated combat state missing"
                    )
                    if type(payload) == "table" then
                        local expected = payload :: { [string]: unknown }
                        waitFor(function()
                            local selection = state:GetAttribute("Selection")
                            local impact = state:GetAttribute("Impact")
                            local selected = if type(selection) == "string"
                                then HttpService:JSONDecode(selection)
                                else nil
                            local hit = if type(impact) == "string"
                                then HttpService:JSONDecode(impact)
                                else nil
                            local target = if type(expected.targetId) == "number"
                                then Players:GetPlayerByUserId(expected.targetId)
                                else nil
                            local character = if target then target.Character else nil
                            local humanoid = if character
                                then character:FindFirstChildOfClass("Humanoid")
                                else nil
                            return (
                                expected.weapon == nil or (selected and selected.weapon == expected.weapon)
                            )
                                and (expected.shotId == nil or (hit and hit.shotId == expected.shotId))
                                and (expected.health == nil or (humanoid and humanoid.Health == expected.health))
                                and (
                                    expected.winner == nil
                                    or round:GetAttribute("Winner") == expected.winner
                                )
                        end, "matching weapon, impact, health and result")
                    end
                else
                    error("unknown combat probe")
                end
            end)
            remote:FireServer(token, ok, if ok then "ok" else tostring(reason), Players.LocalPlayer.UserId)
        end)
        remote.AncestryChanged:Connect(function()
            if not remote:IsDescendantOf(ReplicatedStorage) then
                listener:Disconnect()
            end
        end)
        remote:FireServer(0, true, "ready", Players.LocalPlayer.UserId)
    end)
end
return CombatHarness
