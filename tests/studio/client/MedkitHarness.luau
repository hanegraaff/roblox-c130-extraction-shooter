--!strict
-- P30 test-only actual client. Observes the replicated medkit and HUD, moves
-- the ordinary character locally, and activates the native ProximityPrompt.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local BalanceHarness = require(script.Parent.BalanceHarness)
local Harness = {}

type Fields = { [string]: unknown }

local function waitFor(ready: () -> boolean, description: string, seconds: number?)
    local deadline = os.clock() + (seconds or 8)
    repeat
        if ready() then
            return
        end
        task.wait()
    until os.clock() >= deadline
    error("P30 client did not observe " .. description)
end

-- The test server starts after the normal smoke suite. Each reply describes
-- this client's own DataModel and uses only the test-only request bridge.
function Harness.run()
    local player = Players.LocalPlayer
    local transport = ReplicatedStorage:WaitForChild("P30Harness", 120)
    assert(transport and transport:IsA("RemoteEvent"), "P30 bridge missing")
    local gui = player:WaitForChild("PlayerGui")
    local visiblePrompts: { [ProximityPrompt]: Enum.ProximityPromptInputType } = {}
    local seenOnTouch: { [string]: boolean } = {}
    local shown = ProximityPromptService.PromptShown:Connect(function(prompt, input)
        if prompt.Name == "UseMedkit" then
            visiblePrompts[prompt] = input
            local model = prompt:FindFirstAncestorOfClass("Model")
            if input == Enum.ProximityPromptInputType.Touch and model then
                seenOnTouch[model.Name] = true
            end
        end
    end)
    local hidden = ProximityPromptService.PromptHidden:Connect(function(prompt)
        visiblePrompts[prompt] = nil
    end)
    local function find(site: string): Instance?
        local folder = workspace:FindFirstChild("Medkits")
        return if folder then folder:FindFirstChild(site) else nil
    end
    local function awaitPickup(site: string): Model
        waitFor(function()
            local model = find(site)
            return model ~= nil and model:FindFirstChild("UseMedkit", true) ~= nil
        end, site)
        local model = find(site)
        assert(model and model:IsA("Model"), "pickup model missing")
        return model
    end
    local function body(): (Humanoid, BasePart)
        local character = assert(player.Character, "client character unavailable")
        local humanoid = assert(character:FindFirstChildOfClass("Humanoid"), "client Humanoid unavailable")
        local root = character:FindFirstChild("HumanoidRootPart")
        assert(root and root:IsA("BasePart"), "client root unavailable")
        return humanoid, root
    end
    local function probe(action: string, data: Fields): unknown
        if action == "EditHeal" then
            local value = data.value
            assert(type(value) == "number", "P30 healing input missing")
            waitFor(function()
                local panel = gui:FindFirstChild("BalancePanel")
                local open = if panel then panel:FindFirstChild("OpenBalance") else nil
                local hud = gui:FindFirstChild("RoundHUD")
                -- The balance gate can update before Ground's render step
                -- releases mouse lock while returning to the lobby.
                return panel ~= nil
                    and panel:IsA("ScreenGui")
                    and panel.Enabled
                    and open ~= nil
                    and open:IsA("GuiButton")
                    and open.Visible
                    and open.Active
                    and hud ~= nil
                    and hud:GetAttribute("View") == "RoundLobby"
                    and UserInputService.MouseBehavior == Enum.MouseBehavior.Default
            end, "eliminated owner's ready lobby balance button")
            RunService.RenderStepped:Wait()
            local panel = assert(gui:FindFirstChild("BalancePanel"))
            BalanceHarness.editLobbyPreset(panel, 1, { medkitHeal = tostring(value) })
            return true
        end
        if action == "Walk" then
            local start, goal = data.start, data.goal
            assert(typeof(start) == "Vector3" and typeof(goal) == "Vector3", "P30 walk points invalid")
            waitFor(function()
                local _, root = body()
                return (root.Position - start).Magnitude <= 1.75
            end, "start of actual walk")
            local humanoid, root = body()
            local origin = root.Position
            local binding = "P30MedkitWalk"
            local frames, closest = 0, (root.Position - goal).Magnitude
            -- The stock ControlModule writes movement every frame. Submit the
            -- fixture's walk just after it so the live avatar still moves and
            -- collides under ordinary character physics.
            RunService:BindToRenderStep(binding, Enum.RenderPriority.Input.Value + 1, function()
                local offset = goal - root.Position
                local horizontal = Vector3.new(offset.X, 0, offset.Z)
                humanoid:Move(if horizontal.Magnitude > 0.8 then horizontal.Unit else Vector3.zero, false)
                frames += 1
                closest = math.min(closest, offset.Magnitude)
            end)
            local ok, reason = pcall(function()
                waitFor(function()
                    return (root.Position - goal).Magnitude <= 1.75
                end, "end of actual walk")
                return true
            end)
            RunService:UnbindFromRenderStep(binding)
            humanoid:Move(Vector3.zero, false)
            assert(
                ok,
                string.format(
                    "%s (start %s, goal %s, final %s, closest %.2f studs, %d frames, anchored %s)",
                    tostring(reason),
                    tostring(origin),
                    tostring(goal),
                    tostring(root.Position),
                    closest,
                    frames,
                    tostring(root.Anchored)
                )
            )
            local walked = (root.Position - origin).Magnitude
            assert(walked >= 3.5, "avatar did not walk to the medkit")
            return walked
        end
        local site = data.site
        assert(type(site) == "string", "P30 site missing")
        if action == "Replica" then
            if data.present == true then
                local model = awaitPickup(site)
                return model:GetAttribute("MedkitRoundId")
            end
            waitFor(function()
                return find(site) == nil
            end, "spent " .. site)
            local humanoid = if player.Character
                then player.Character:FindFirstChildOfClass("Humanoid")
                else nil
            local hud = gui:FindFirstChild("GroundHealth", true)
            local expected, feedbackUntil = data.expectedHeal, data.feedbackUntil
            if expected ~= nil then
                assert(type(expected) == "number" and type(feedbackUntil) == "number", "invalid heal sample")
                local suffix = string.format("  +%g HP", math.round(expected * 10) / 10)
                waitFor(function()
                    hud = gui:FindFirstChild("GroundHealth", true)
                    return humanoid ~= nil
                        and humanoid:GetAttribute("MedkitHealUntil") == feedbackUntil
                        and humanoid:GetAttribute("MedkitHealAmount") == expected
                        and hud ~= nil
                        and hud:IsA("TextLabel")
                        and hud.Visible
                        and string.sub(hud.Text, -#suffix) == suffix
                end, "medkit health feedback for " .. site .. suffix, 2)
            end
            return {
                present = false,
                heal = if humanoid then humanoid:GetAttribute("MedkitHealAmount") else nil,
                health = if humanoid then humanoid.Health else nil,
                feedback = if hud and hud:IsA("TextLabel") and hud.Visible then hud.Text else nil,
                touch = seenOnTouch[site] == true and UserInputService.TouchEnabled,
            }
        end
        assert(action == "Activate", "unexpected P30 probe: " .. action)
        local model = awaitPickup(site)
        local prompt = model:FindFirstChild("UseMedkit", true)
        assert(prompt and prompt:IsA("ProximityPrompt"), "native prompt unavailable")
        local function activate(): boolean
            if data.stamp then
                local stamp = data.stamp
                assert(type(stamp) == "number", "activation stamp missing")
                waitFor(function()
                    return workspace:GetServerTimeNow() >= stamp
                end, "paired native prompt activation time")
            end
            local visible = visiblePrompts[prompt] ~= nil
            -- Activate the actual Roblox prompt through its custom-UI API.
            -- No test remote requests a heal or supplies health or position to gameplay.
            prompt:InputHoldBegin()
            RunService.RenderStepped:Wait()
            prompt:InputHoldEnd()
            return visible
        end
        if data.requireShown ~= true then
            return activate()
        end
        local camera = assert(workspace.CurrentCamera, "activation camera missing")
        local character = assert(player.Character, "activation character missing")
        local head = character:FindFirstChild("Head")
        local target = prompt.Parent
        assert(
            head and head:IsA("BasePart") and target and target:IsA("BasePart"),
            "activation points missing"
        )
        local priorType, priorPose, priorFocus = camera.CameraType, camera.CFrame, camera.Focus
        -- Look from the live avatar's eyes so the ordinary prompt sees the same
        -- clear approach a player can use by turning or zooming the camera.
        camera.CameraType = Enum.CameraType.Scriptable
        camera.CFrame = CFrame.lookAt(head.Position, target.Position)
        camera.Focus = target.CFrame
        local ok, result = pcall(function()
            waitFor(function()
                return visiblePrompts[prompt] ~= nil
            end, "shown native prompt at " .. site, 4)
            return activate()
        end)
        camera.CFrame, camera.Focus, camera.CameraType = priorPose, priorFocus, priorType
        assert(ok, tostring(result))
        return result
    end
    local listener = transport.OnClientEvent:Connect(function(token: number, action: string, data: Fields)
        local ok, result = pcall(probe, action, data)
        transport:FireServer(token, ok, if ok then HttpService:JSONEncode(result) else tostring(result))
    end)
    transport.Destroying:Connect(function()
        shown:Disconnect()
        hidden:Disconnect()
        listener:Disconnect()
    end)
    transport:FireServer(0, true, script.Parent:GetAttribute("ClientTestReport"))
end

return Harness
