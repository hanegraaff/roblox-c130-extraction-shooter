--!strict
-- P07 test-only real-client probes. Sends only production aim/selection intent.
-- Panel assertions inspect replicated current state/rays; they do not award damage.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Harness = {}
local function waitFor(predicate: () -> boolean, label: string)
    local deadline = os.clock() + 8
    while not predicate() and os.clock() < deadline do
        task.wait(0.03)
    end
    assert(predicate(), "P07 client timeout: " .. label)
end
function Harness.run()
    task.spawn(function()
        local transport = ReplicatedStorage:WaitForChild("P07Harness", 600)
        if not transport or not transport:IsA("RemoteEvent") then
            return
        end
        local listener = transport.OnClientEvent:Connect(
            function(token: number, kind: string, payload: unknown)
                local ok, failure = pcall(function()
                    if kind == "Fire" or kind == "Select" or kind == "Flood" then
                        local state = ReplicatedStorage:WaitForChild("AircraftState", 5)
                        assert(state, "aircraft state missing")
                        local remote =
                            state:FindFirstChild(if kind == "Select" then "SelectWeapon" else "FireWeapon")
                        assert(remote and remote:IsA("RemoteEvent"), "production remote missing")
                        if kind == "Flood" then
                            for _ = 1, 40 do
                                remote:FireServer(payload)
                            end
                        else
                            remote:FireServer(payload)
                        end
                    elseif kind == "Burst" then
                        assert(type(payload) == "table", "burst fixture missing")
                        local burst = payload :: { commands: { { [string]: unknown } }, cadence: number }
                        assert(#burst.commands == 61 and burst.cadence == 0.151, "unbounded burst fixture")
                        local state = ReplicatedStorage:WaitForChild("AircraftState", 5)
                        local remote = if state then state:FindFirstChild("FireWeapon") else nil
                        assert(remote and remote:IsA("RemoteEvent"), "production fire remote missing")
                        local nextAt = workspace:GetServerTimeNow()
                        for _, command in burst.commands do
                            while workspace:GetServerTimeNow() < nextAt do
                                game:GetService("RunService").Heartbeat:Wait()
                            end
                            remote:FireServer(command)
                            nextAt = workspace:GetServerTimeNow() + burst.cadence
                        end
                    elseif kind == "Panels" then
                        assert(type(payload) == "table", "expected panel observations")
                        local expected = payload :: {
                            {
                                id: string,
                                stage: string,
                                progress: number,
                                parts: number,
                                pivot: { number },
                            }
                        }
                        for _, entry in expected do
                            waitFor(function()
                                local model = workspace.World.Battlefield:FindFirstChild(entry.id, true)
                                if not model or not model:IsA("Model") then
                                    return false
                                end
                                local progress = model:GetAttribute("PanelProgress")
                                if
                                    model:GetAttribute("PanelState") ~= entry.stage
                                    or type(progress) ~= "number"
                                    or math.abs(progress - entry.progress) > 1e-5
                                    or #model:GetChildren() ~= entry.parts
                                then
                                    return false
                                end
                                local pivot = CFrame.new(unpack(entry.pivot))
                                if (model:GetPivot().Position - pivot.Position).Magnitude > 0.01 then
                                    return false
                                end
                                local params = RaycastParams.new()
                                params.FilterType = Enum.RaycastFilterType.Include
                                params.FilterDescendantsInstances = { model }
                                local normal = if string.find(entry.id, "Roof", 1, true)
                                    then Vector3.yAxis
                                    else Vector3.zAxis
                                local hit = workspace:Raycast(pivot.Position - normal * 2, normal * 4, params)
                                return (entry.stage == "Intact" and hit ~= nil)
                                    or (entry.stage ~= "Intact" and hit == nil)
                            end, entry.id .. " state/progress/opening")
                        end
                    elseif kind == "Walk" then
                        assert(typeof(payload) == "Vector3", "walking goal missing")
                        local character = Players.LocalPlayer.Character
                        local humanoid = if character
                            then character:FindFirstChildOfClass("Humanoid")
                            else nil
                        local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
                        assert(humanoid and root and root:IsA("BasePart"), "actual ground avatar unavailable")
                        humanoid:MoveTo(payload)
                        waitFor(function()
                            return (root.Position - payload).Magnitude < 2
                        end, "actual Humanoid through opening")
                    elseif kind == "NoFragments" then
                        waitFor(function()
                            local folder = workspace:FindFirstChild("PanelFragments")
                            return folder ~= nil and #folder:GetChildren() == 0
                        end, "expired debris/no historical burst")
                    elseif kind == "Spectator" then
                        local player = Players.LocalPlayer
                        waitFor(function()
                            return player:GetAttribute("Role") == "Spectator"
                                and player:GetAttribute("Life") == "Spectating"
                        end, "late spectator")
                        local backpack = player:FindFirstChildOfClass("Backpack")
                        assert(not backpack or #backpack:GetChildren() == 0, "spectator has equipment")
                    else
                        error("unknown P07 probe")
                    end
                end)
                transport:FireServer(token, ok, if ok then "ok" else tostring(failure))
            end
        )
        transport.AncestryChanged:Connect(function()
            if not transport:IsDescendantOf(ReplicatedStorage) then
                listener:Disconnect()
            end
        end)
        transport:FireServer(0, true, "ready")
    end)
end
return Harness
