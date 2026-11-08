--!strict
-- P13 real network-client geometry/terrain/aircraft probes. Test-only; bounded discovery
-- and one listener are torn down with the transport. No source/world mutation occurs.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Harness = {}

-- Canonical rounded signature tolerates only CFrame serialization roundoff, not pose drift.
local function signature(): string
    local map = workspace.World:FindFirstChild("Battlefield")
    if not map then
        return "missing"
    end
    local values: { string } = {}
    for _, item in map:GetDescendants() do
        if item:IsA("BasePart") then
            local components: { string } = { item.Name }
            for _, value in { item.CFrame:GetComponents() } do
                table.insert(components, string.format("%.3f", value))
            end
            for _, value in { item.Size.X, item.Size.Y, item.Size.Z } do
                table.insert(components, string.format("%.3f", value))
            end
            table.insert(values, table.concat(components, ":"))
        end
    end
    table.sort(values)
    return table.concat(values, "|")
end

-- Installs asynchronously in every actual client, including a late join.
function Harness.run()
    task.spawn(function()
        local remote = ReplicatedStorage:WaitForChild("P13Harness", 120)
        if not remote or not remote:IsA("RemoteEvent") then
            return
        end
        local listener: RBXScriptConnection? = nil
        local removal: RBXScriptConnection? = nil
        listener = remote.OnClientEvent:Connect(function(token: number, expected: string)
            local ok, reason = pcall(function()
                local deadline = os.clock() + 12
                while signature() ~= expected and os.clock() < deadline do
                    task.wait(0.05)
                end
                assert(
                    signature() == expected,
                    "actual client map signature mismatch after replication deadline"
                )
                local map = workspace.World.Battlefield
                local buildings = map:FindFirstChild("Buildings")
                assert(buildings and #buildings:GetChildren() == 3, "client building population differs")
                for _, building in buildings:GetChildren() do
                    local panels = building:FindFirstChild(building.Name .. "_Panels") :: Folder
                    for _, panel in panels:GetChildren() do
                        assert(panel:GetAttribute("PanelId") == panel.Name, "client panel identity differs")
                        assert(panel:GetAttribute("PanelState") == "Intact", "client panel state differs")
                    end
                end
                local rays = RaycastParams.new()
                rays.FilterType = Enum.RaycastFilterType.Include
                rays.FilterDescendantsInstances = { workspace.Terrain }
                local recipe = map:FindFirstChild("TerrainRecipe") :: Folder
                for _, hill in recipe:GetChildren() do
                    if hill:IsA("Part") and hill.Name ~= "TerrainBounds" then
                        local hit = workspace:Raycast(
                            Vector3.new(hill.Position.X, 80, hill.Position.Z),
                            Vector3.new(0, -150, 0),
                            rays
                        )
                        assert(
                            hit and hit.Material == hill.Material and math.abs(hit.Position.Y - 16) <= 3,
                            "client terrain elevation/material differs"
                        )
                    end
                end
                local aircraft = workspace:FindFirstChild("Aircraft")
                assert(aircraft and aircraft:IsA("Model"), "client canonical aircraft missing")
                local pose = aircraft:GetPivot()
                assert(
                    math.abs(Vector2.new(pose.X, pose.Z).Magnitude - 360) < 0.02,
                    "client aircraft not on expanded perimeter"
                )
            end)
            remote:FireServer(token, {
                passed = ok,
                detail = if ok then "geometry/terrain/aircraft observed" else tostring(reason),
                baseline = script.Parent:GetAttribute("ClientTestReport"),
            })
        end)
        removal = remote.AncestryChanged:Connect(function()
            if not remote:IsDescendantOf(ReplicatedStorage) then
                if listener then
                    listener:Disconnect()
                end
                if removal then
                    removal:Disconnect()
                end
            end
        end)
        remote:FireServer(0, { passed = true })
    end)
end
return Harness
