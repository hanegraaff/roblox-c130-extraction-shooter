--!strict
-- P26 client observer in the test mapping. Relays bounded fixture operations over
-- the real admin and weapon remotes. Every observation is sampled on this client.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Harness = {}

-- Interact with the production editor from the local test client.
local function editLobbyPreset(gui: Instance)
    local function click(name: string)
        local button = gui:FindFirstChild(name, true)
        assert(
            button and button:IsA("GuiButton") and button.Visible and button.Active,
            name .. " is unavailable"
        )
        local position = button.AbsolutePosition + button.AbsoluteSize / 2 + GuiService:GetGuiInset()
        local input = assert(UserInputService:CreateVirtualInput(), "Studio VirtualInput unavailable")
        input:SendMouseButton(position, Enum.UserInputType.MouseButton1, true)
        RunService.RenderStepped:Wait()
        input:SendMouseButton(position, Enum.UserInputType.MouseButton1, false)
        RunService.RenderStepped:Wait()
    end
    local function edit(name: string, value: string)
        local box = gui:FindFirstChild(name, true)
        assert(box and box:IsA("TextBox"), name .. " field missing")
        box:CaptureFocus()
        box.Text = value
        box:ReleaseFocus(true)
        RunService.RenderStepped:Wait()
    end
    click("OpenBalance")
    local apply = gui:FindFirstChild("ApplyPreset", true)
    assert(apply and apply:IsA("TextButton"), "apply button missing")
    local deadline = os.clock() + 5
    while not apply.Active do
        assert(os.clock() < deadline, "editor did not load current preset")
        task.wait()
    end
    click("ChooseCategory")
    click("Category4")
    edit("minimumPlayers", "2")
    edit("roundDuration", "35")
    assert(apply.Text == "Save & apply", "edited preset cannot be applied directly")
    click("ApplyPreset")
end

-- Start after client smoke. The server destroys the temporary transport at teardown.
function Harness.run()
    local player = Players.LocalPlayer
    local bridge = ReplicatedStorage:WaitForChild("P26Harness", 120)
    assert(bridge and bridge:IsA("RemoteEvent"), "P26 test transport missing")
    local function probe(kind: string, payload: { [string]: unknown }): unknown
        if kind == "Request" then
            local admin = ReplicatedStorage:FindFirstChild("BalanceAdmin")
            assert(admin and admin:IsA("RemoteFunction"), "production admin remote missing")
            return admin:InvokeServer(payload)
        end
        local state = assert(ReplicatedStorage:FindFirstChild("RoundState"), "round state missing")
        local aircraft = assert(ReplicatedStorage:FindFirstChild("AircraftState"), "aircraft state missing")
        local character = player.Character
        local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
        if kind == "Weapon" then
            local name = payload.remote
            local launcher = name == "Pickup" or name == "Fire"
            assert(
                launcher
                    or name == "SelectWeapon"
                    or name == "FireWeapon"
                    or name == "GroundFire"
                    or name == "GroundReload",
                "unrecognized test weapon remote"
            )
            local parent = if launcher then ReplicatedStorage.LauncherState else aircraft
            local event = parent:FindFirstChild(name :: string)
            assert(event and event:IsA("RemoteEvent"), "weapon remote missing")
            event:FireServer(payload.body)
            return true
        end
        if kind == "Panel" then
            local name = payload.name
            assert(type(name) == "string", "panel name missing")
            local panel = workspace.World.Battlefield.Buildings.Outpost.Outpost_Panels:FindFirstChild(name)
            return if panel then panel:GetAttribute("DamageAppearance") else nil
        end
        if kind == "EditLobbyPreset" then
            local gui = assert(player.PlayerGui:FindFirstChild("BalancePanel"), "balance panel missing")
            editLobbyPreset(gui)
            return true
        end
        if kind == "RemoveBalanceGui" then
            assert(player.PlayerGui:FindFirstChild("BalancePanel"), "balance panel missing"):Destroy()
            return true
        end
        assert(kind == "Observe", "unknown client operation")
        local gui = player.PlayerGui:FindFirstChild("BalancePanel")
        local button = if gui then gui:FindFirstChild("OpenBalance") else nil
        local hud = player.PlayerGui:FindFirstChild("RoundHUD")
        local hpLabel = if hud then hud:FindFirstChild("AircraftHealth") else nil
        return {
            aircraftHUD = if hpLabel
                    and hpLabel:IsA("TextLabel")
                    and hpLabel.Visible
                then hpLabel.Text
                else nil,
            phase = state:GetAttribute("Phase"),
            minimum = state:GetAttribute("MinimumPlayers"),
            roundId = state:GetAttribute("RoundId"),
            revision = state:GetAttribute("BalanceRoundRevision"),
            intermission = state:GetAttribute("IntermissionUntil"),
            role = player:GetAttribute("Role"),
            groundHP = if humanoid then humanoid.MaxHealth else nil,
            aircraftHP = aircraft:GetAttribute("MaxHealth"),
            aircraftCurrent = aircraft:GetAttribute("Health"),
            panelVisible = gui ~= nil
                and gui:IsA("ScreenGui")
                and gui.Enabled
                and button ~= nil
                and button:IsA("GuiButton")
                and button.Visible,
        }
    end
    bridge.OnClientEvent:Connect(function(token: number, kind: string, payload: { [string]: unknown })
        local ok, value = pcall(probe, kind, payload)
        bridge:FireServer(token, ok, value)
    end)
    bridge:FireServer(0, true)
end
return Harness
