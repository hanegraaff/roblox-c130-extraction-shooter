--!strict
--[=[
    HumanTestPanel: test-mapping-only human controls for role preview and real test rounds.
    Sends bounded intent to the server-owned session; never assigns roles or deadlines.
    Owns one discovery task, GUI, heartbeat and button listeners. Session removal or
    entrypoint destruction removes every owned resource. No production mapping loads it.
]=]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Panel = {}

-- Installs nonyielding discovery with a thirty-second bound. Returns idempotent cleanup.
function Panel.start(): () -> ()
    local stopped = false
    local connections: { RBXScriptConnection } = {}
    local gui: ScreenGui? = nil
    local worker: thread? = nil
    local function stop()
        if stopped then
            return
        end
        stopped = true
        if worker and worker ~= coroutine.running() and coroutine.status(worker) ~= "dead" then
            task.cancel(worker)
        end
        for _, connection in connections do
            connection:Disconnect()
        end
        table.clear(connections)
        if gui then
            gui:Destroy()
        end
    end
    worker = task.spawn(function()
        local state = ReplicatedStorage:WaitForChild("StudioTestControls", 30)
        if not state or stopped then
            return
        end
        local request = state:FindFirstChild("Request")
        assert(request and request:IsA("RemoteEvent"), "test request transport unavailable")
        local player = Players.LocalPlayer
        local playerGui = player:WaitForChild("PlayerGui", 10)
        assert(playerGui, "test player GUI unavailable")
        local screen = Instance.new("ScreenGui")
        screen.Name = "StudioTestPanel"
        screen.ResetOnSpawn = false
        gui = screen
        local frame = Instance.new("Frame")
        frame.AnchorPoint = Vector2.new(1, 1)
        frame.Position = UDim2.new(1, -12, 1, -12)
        frame.Size = UDim2.fromOffset(286, 260)
        frame.BackgroundColor3 = Color3.fromRGB(20, 30, 40)
        frame.Parent = screen
        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, 0, 0, 28)
        title.BackgroundTransparency = 1
        title.TextColor3 = Color3.fromRGB(240, 245, 250)
        title.Text = "STUDIO TESTING"
        title.TextSize = 16
        title.Parent = frame
        local sequence = 0
        local function send(action: string, value: (string | number)?)
            sequence += 1
            request:FireServer({
                action = action,
                value = value,
                sequence = sequence,
                generation = state:GetAttribute("Generation"),
            })
        end
        local function button(name: string, text: string, y: number, callback: () -> ()): TextButton
            local item = Instance.new("TextButton")
            item.Name = name
            item.Position = UDim2.fromOffset(8, y)
            item.Size = UDim2.fromOffset(270, 28)
            item.BackgroundColor3 = Color3.fromRGB(45, 60, 75)
            item.TextColor3 = Color3.new(1, 1, 1)
            item.TextSize = 14
            item.Text = text
            item.Parent = frame
            table.insert(connections, item.Activated:Connect(callback))
            return item
        end
        local roles = { "Auto", "Ground", "Gunship" }
        local role = button("Role", "Role: Auto", 32, function()
            local selected = tostring(player:GetAttribute("LocalTestRoleChoice") or "Auto")
            local index = table.find(roles, selected) or 1
            send("Role", roles[index % #roles + 1])
        end)
        local durations = { 30, 60, 180, 600 }
        local duration = button("Duration", "Next round: 60s", 64, function()
            local index = table.find(durations, state:GetAttribute("RoundSeconds")) or 2
            send("Duration", durations[index % #durations + 1])
        end)
        local start = button("Start", "Start round now (2+ clients)", 96, function()
            send("Start")
        end)
        button("Reset", "Reset test / apply settings", 128, function()
            send("Reset")
        end)
        local location = button("Location", "Return to lobby", 160, function()
            send(if player:GetAttribute("LocalMapPreview") then "Lobby" else "Explore")
        end)
        local message = Instance.new("TextLabel")
        message.Position = UDim2.fromOffset(8, 194)
        message.Size = UDim2.fromOffset(270, 60)
        message.BackgroundTransparency = 1
        message.TextColor3 = Color3.fromRGB(210, 225, 235)
        message.TextWrapped = true
        message.TextSize = 13
        message.Parent = frame
        table.insert(
            connections,
            RunService.Heartbeat:Connect(function()
                local choice = tostring(player:GetAttribute("LocalTestRoleChoice") or "Auto")
                role.Text = "Role: "
                    .. (if choice == "Gunship" then "Operator" else choice)
                    .. " (click to change)"
                duration.Text = "Next round: " .. tostring(state:GetAttribute("RoundSeconds")) .. " seconds"
                start.Text = if state:GetAttribute("Busy")
                    then "Restarting test…"
                    else "Start round now (2+ clients)"
                location.Text = if player:GetAttribute("LocalMapPreview")
                    then "Return to lobby"
                    else "Explore map (solo)"
                message.Text = tostring(
                    player:GetAttribute("LocalTestFeedback")
                        or "Choose a role for preview or your next round."
                )
            end)
        )
        table.insert(
            connections,
            state.AncestryChanged:Connect(function()
                if not state:IsDescendantOf(ReplicatedStorage) then
                    stop()
                end
            end)
        )
        screen.Parent = playerGui
        worker = nil
    end)
    return stop
end

return Panel
