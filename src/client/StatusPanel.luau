--!strict
--[=[
    StatusPanel: client-only foundation panel, depending on shared Lifecycle and a server status Folder.
    Owns exactly one GUI and AttributeChanged connection; stop destroys/disconnects both.
    Pure presentation: cannot modify server authority. Construction/start do not yield.
]=]
local Lifecycle = require(game:GetService("ReplicatedStorage").Shared.Lifecycle)
local StatusPanel = {}

-- Creates a panel controller for an existing PlayerGui and replicated BootstrapStatus.
function StatusPanel.new(playerGui: PlayerGui, status: Instance): Lifecycle.Controller
    return Lifecycle.new({
        function()
            assert(not playerGui:FindFirstChild("FoundationStatus"), "status panel already owned")
            local gui = Instance.new("ScreenGui")
            gui.Name = "FoundationStatus"
            gui.ResetOnSpawn = false
            local label = Instance.new("TextLabel")
            label.Name = "Status"
            label.Position = UDim2.fromOffset(16, 16)
            label.Size = UDim2.fromOffset(400, 86)
            label.BackgroundColor3 = Color3.fromRGB(20, 25, 32)
            label.BackgroundTransparency = 0.1
            label.TextColor3 = Color3.fromRGB(240, 245, 250)
            label.TextSize = 18
            label.Font = Enum.Font.Gotham
            label.TextWrapped = true
            label.Parent = gui
            local function update()
                label.Text = string.format(
                    "Players vs C-130 • %s\nBootstrap %s • Gunship weapons available\nGround weapons and launcher are planned.",
                    tostring(status:GetAttribute("Environment")),
                    if status:GetAttribute("Running") then "running" else "stopped"
                )
            end
            local changed = status.AttributeChanged:Connect(update)
            update()
            gui.Parent = playerGui
            return function()
                changed:Disconnect()
                gui:Destroy()
            end
        end,
    })
end
return StatusPanel
