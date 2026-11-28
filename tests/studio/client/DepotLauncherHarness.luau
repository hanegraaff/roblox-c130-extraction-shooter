--!strict
-- P29 actual-client witness for model replication and ordinary launcher intent.
-- Production controllers own gameplay, equipment, cameras and the main HUD.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Harness = {}

type Record = { [string]: unknown }
local function waitFor(predicate: () -> boolean, label: string)
    local deadline = os.clock() + 8
    while not predicate() and os.clock() < deadline do
        task.wait()
    end
    assert(predicate(), "P29 client timeout: " .. label)
end

-- Counts only visible world/character representations. Backpack ownership is
-- measured separately by the server because other inventories are private.
local function replicas(id: string): (number, Tool?, Model?)
    local count, equipped, pickup = 0, nil, nil
    local effects = workspace:FindFirstChild("LauncherEffects")
    if effects then
        for _, item in effects:GetChildren() do
            if item:IsA("Model") and item:GetAttribute("LauncherId") == id then
                count += 1
                pickup = item
            end
        end
    end
    for _, player in Players:GetPlayers() do
        local tool = player.Character and player.Character:FindFirstChild("Rocket launcher")
        if tool and tool:IsA("Tool") and tool:GetAttribute("LauncherId") == id then
            count += 1
            equipped = tool
        end
    end
    return count, equipped, pickup
end

-- Attach once after client smoke. The transport is mapped only in the test
-- place and expires with the server fixture; no client grants ownership.
function Harness.run()
    local transport = ReplicatedStorage:WaitForChild("P29Harness", 100)
    assert(transport and transport:IsA("RemoteEvent"), "P29 transport missing")
    local player = Players.LocalPlayer
    transport.OnClientEvent:Connect(function(token: number, action: string, fields: Record)
        local ok, value = pcall(function(): unknown
            if action == "Intent" then
                local owner =
                    assert(ReplicatedStorage:FindFirstChild("LauncherState"), "LauncherState missing")
                local remote = owner:FindFirstChild(tostring(fields.remote))
                assert(remote and remote:IsA("RemoteEvent"), "ordinary LauncherState remote missing")
                remote:FireServer(fields.payload)
            elseif action == "Equip" then
                local avatar = assert(player.Character, "local avatar missing")
                local body = assert(avatar:FindFirstChildOfClass("Humanoid"), "local Humanoid missing")
                local backpack = assert(player:FindFirstChildOfClass("Backpack"), "local inventory missing")
                waitFor(function()
                    return backpack:FindFirstChild("Rocket launcher") ~= nil
                end, "equippable launcher")
                local tool = backpack:FindFirstChild("Rocket launcher")
                assert(tool and tool:IsA("Tool"), "local owned Tool missing")
                body:EquipTool(tool)
                waitFor(function()
                    return tool.Parent == avatar
                end, "native equip")
            elseif action == "Observe" then
                local id = tostring(fields.id)
                waitFor(function()
                    local count, held, dropped = replicas(id)
                    if fields.owner == 0 then
                        return count == 1 and dropped ~= nil and dropped:FindFirstChild("Handle") ~= nil
                    elseif fields.owner == nil then
                        return count == 0
                    end
                    local holder = if held and held.Parent
                        then Players:GetPlayerFromCharacter(held.Parent)
                        else nil
                    return count == 1
                        and holder ~= nil
                        and holder.UserId == fields.owner
                        and held ~= nil
                        and held:FindFirstChild("Handle") ~= nil
                end, "visible representation " .. id)
                local count, held, dropped = replicas(id)
                local shown = held or dropped
                if not shown then
                    return { count = count }
                end
                local visible = 0
                for _, piece in shown:GetChildren() do
                    if piece:IsA("BasePart") and piece.Transparency == 0 then
                        assert(piece.LocalTransparencyModifier == 0, "Ground's art was masked")
                        visible += 1
                    end
                end
                assert(visible >= 100, "depot prop was missing visible detail")
                local view = assert(workspace.CurrentCamera, "camera missing").ViewportSize
                return { count = count, visibleParts = visible, viewport = { view.X, view.Y } }
            else
                error("unknown P29 client probe " .. action)
            end
            return true
        end)
        transport:FireServer(token, ok, if ok then HttpService:JSONEncode(value) else tostring(value))
    end)
    transport:FireServer(0, true, script.Parent:GetAttribute("ClientTestReport"))
end

return Harness
