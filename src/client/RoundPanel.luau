--!strict
--[=[
    RoundPanel: client presentation for authoritative round attributes. Owns one HUD,
    surrender button, heartbeat and teammate spectator camera. No combat authority.
    Depends on Players/RunService and RoundState. stop restores the local camera.
    Times use synchronized server-clock seconds. Public calls never yield.
]=]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lifecycle = require(game:GetService("ReplicatedStorage").Shared.Lifecycle)
local RoundPanel = {}
local ThermalCameraController = require(script.Parent.ThermalCameraController)

-- Creates a controller for existing player/status owners; start/stop are idempotent.
function RoundPanel.new(player: Player, playerGui: PlayerGui, state: Instance): Lifecycle.Controller
    return Lifecycle.new({
        function()
            assert(not playerGui:FindFirstChild("RoundHUD"), "round HUD already owned")
            local gui = Instance.new("ScreenGui")
            gui.Name = "RoundHUD"
            gui.ResetOnSpawn = false
            local label = Instance.new("TextLabel")
            label.Name = "Round"
            label.AnchorPoint = Vector2.new(0.5, 0)
            label.Position = UDim2.new(0.5, 0, 0, 112)
            label.Size = UDim2.fromOffset(540, 102)
            label.BackgroundColor3 = Color3.fromRGB(16, 23, 31)
            label.BackgroundTransparency = 0.1
            label.TextColor3 = Color3.fromRGB(240, 245, 250)
            label.TextSize = 18
            label.Font = Enum.Font.Gotham
            label.TextWrapped = true
            label.Parent = gui
            local surrender = Instance.new("TextButton")
            surrender.Name = "Surrender"
            surrender.AnchorPoint = Vector2.new(0.5, 0)
            surrender.Position = UDim2.new(0.5, 0, 0, 220)
            surrender.Size = UDim2.fromOffset(250, 36)
            surrender.Text = "Surrender / spectate"
            surrender.TextSize = 18
            surrender.BackgroundColor3 = Color3.fromRGB(35, 44, 55)
            surrender.TextColor3 = Color3.new(1, 1, 1)
            surrender.Parent = gui
            local sequence = 0
            local oldRoundId = -1
            local thermal = ThermalCameraController.new(player, playerGui, state)
            local function update()
                local roundId = state:GetAttribute("RoundId")
                local phase = tostring(state:GetAttribute("Phase"))
                local role = tostring(player:GetAttribute("Role") or "Waiting")
                local life = tostring(player:GetAttribute("Life") or "Waiting")
                if type(roundId) == "number" and roundId ~= oldRoundId then
                    oldRoundId = roundId
                    sequence = 0
                end
                local deadline = state:GetAttribute("DeadlineSeconds")
                local seconds = if type(deadline) == "number"
                    then math.max(0, math.ceil(deadline - workspace:GetServerTimeNow()))
                    else 0
                local detail = "Waiting for " .. tostring(state:GetAttribute("MinimumPlayers")) .. " players"
                if phase == "Active" then
                    detail = string.format(
                        "%d:%02d remaining • %s ground alive",
                        math.floor(seconds / 60),
                        seconds % 60,
                        tostring(state:GetAttribute("GroundAlive"))
                    )
                elseif phase == "Results" then
                    detail = tostring(state:GetAttribute("Winner"))
                        .. " • "
                        .. tostring(state:GetAttribute("Reason"))
                elseif phase == "Deploying" then
                    detail = "Preparing characters…"
                elseif phase == "Resetting" then
                    detail = "Restoring battlefield…"
                elseif phase == "Lobby" and player:GetAttribute("LocalMapPreview") == true then
                    detail = if player:GetAttribute("LocalPreviewRole") == "Gunship"
                        then "Studio Operator preview • Inward thermal aircraft view"
                        else "Studio Ground preview • Use WASD to explore"
                end
                local heading = phase .. " • " .. role .. " / " .. life
                if phase == "Lobby" and player:GetAttribute("LocalMapPreview") == true then
                    heading = "Studio preview • "
                        .. (
                            if player:GetAttribute("LocalPreviewRole") == "Gunship"
                                then "Operator"
                                else "Ground"
                        )
                end
                label.Text = string.format(
                    "%s\n%s\n%s",
                    heading,
                    detail,
                    if role == "Gunship"
                        then "Inward thermal view • 1 / 2 selects weapon zoom • Firing is planned"
                        else "Round prototype • Combat and launcher are planned"
                )
                surrender.Visible = phase == "Active" and role == "Ground" and life == "Alive"
                local camera = workspace.CurrentCamera
                if camera and not thermal.ownsCamera() then
                    camera.CameraType = Enum.CameraType.Custom
                    local target: Humanoid? = nil
                    if phase == "Active" and (life == "Eliminated" or role == "Spectator") then
                        local candidates = Players:GetPlayers()
                        table.sort(candidates, function(a, b)
                            return a.UserId < b.UserId
                        end)
                        for _, teammate in candidates do
                            if
                                teammate:GetAttribute("Role") == "Ground"
                                and teammate:GetAttribute("Life") == "Alive"
                                and teammate.Character
                            then
                                local humanoid = teammate.Character:FindFirstChildOfClass("Humanoid")
                                if humanoid and humanoid.Health > 0 then
                                    target = humanoid
                                    break
                                end
                            end
                        end
                    elseif player.Character then
                        target = player.Character:FindFirstChildOfClass("Humanoid")
                    end
                    if target then
                        camera.CameraSubject = target
                    elseif phase == "Active" and life ~= "Alive" then
                        camera.CameraType = Enum.CameraType.Scriptable
                        camera.CFrame = CFrame.lookAt(Vector3.new(0, 150, 140), Vector3.zero)
                    end
                end
            end
            local click = surrender.Activated:Connect(function()
                local remote = state:FindFirstChild("Surrender")
                if remote and remote:IsA("RemoteEvent") then
                    sequence += 1
                    remote:FireServer({
                        roundId = state:GetAttribute("RoundId"),
                        sequence = sequence,
                        action = "Surrender",
                    })
                end
            end)
            local heartbeat = RunService.Heartbeat:Connect(update)
            local destroyed = state.Destroying:Connect(function()
                gui.Enabled = false
            end)
            update()
            gui.Parent = playerGui
            return function()
                heartbeat:Disconnect()
                click:Disconnect()
                destroyed:Disconnect()
                thermal.stop()
                gui:Destroy()
                local camera = workspace.CurrentCamera
                if camera then
                    camera.CameraType = Enum.CameraType.Custom
                    if player.Character then
                        camera.CameraSubject = player.Character:FindFirstChildOfClass("Humanoid")
                    end
                end
            end
        end,
    })
end

return RoundPanel
