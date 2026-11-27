--!strict
-- P26 client observer in the test mapping. Relays bounded fixture operations over
-- the real admin and weapon remotes. Every observation is sampled on this client.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Harness = {}

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
