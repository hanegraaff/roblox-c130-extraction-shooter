--!strict
-- Isolated local Studio acceptance for the mounted Seedship and live panel
-- damage owner. Uses genuine Workspace collision and always removes the clone.
local server = game:GetService("ServerScriptService").Server
local assets = game:GetService("ServerStorage").Assets
local Seedship = require(server.SeedshipReconstruction)
local BuildingGeometry = require(server.BuildingGeometry)
local Damage = require(server.DestructionRuntime)

return function()
    assert(game.PlaceId == 0 and not game:GetService("RunService"):IsRunning(), "local Edit only")
    local world = Instance.new("Folder")
    world.Name = "PrismNativeAcceptance"
    local map = workspace.World.Battlefield:Clone()
    map.Parent = world
    local destruction: Damage.Controller? = nil
    local ok, result = pcall(function()
        local installed, reason = Seedship.install(world, assets)
        assert(installed, reason)
        installed.commit()
        local ship = map:FindFirstChild("PrismSeedshipHull")
        assert(ship and ship:IsA("Model"))
        local root = ship:GetPivot()
        local panels = assert(map:FindFirstChild("PrismPanels"))
        assert(#panels:GetChildren() == 102)
        world.Parent = workspace
        task.wait()
        BuildingGeometry.decorate(map)
        local owner, problem = Damage.start(world)
        assert(owner, problem)
        destruction = owner
        owner.sync(1)
        local query = RaycastParams.new()
        query.FilterType = Enum.RaycastFilterType.Include
        query.RespectCanCollide = true
        local function cast(include: { Instance }, a: Vector3, b: Vector3): RaycastResult?
            query.FilterDescendantsInstances = include
            return workspace:Raycast(a, b - a, query)
        end
        local function at(x: number, y: number, z: number): Vector3
            return root:PointToWorldSpace(Vector3.new(x, y, z))
        end
        local openings = 0
        for _, line in
            {
                { at(0, 3.2, 77), at(0, 3.2, 53) },
                { at(109, 3.2, 0), at(87, 3.2, 0) },
                { at(-109, 3.2, 0), at(-87, 3.2, 0) },
                { at(62, 3.4, 62), at(62, 3.4, 44) },
            }
        do
            local block = cast({ ship, panels }, line[1], line[2])
            assert(not block, "blocked entrance: " .. (if block then block.Instance.Name else ""))
            openings += 1
        end
        local treads = 0
        for step = 1, 24 do
            local z = 39.5 - step
            local y = step * 16 / 24
            for _, x in { -60, -56, -52, 52, 56, 60 } do
                local hit = cast({ ship }, at(x, y + 0.3, z), at(x, y - 0.3, z))
                assert(hit and math.abs(hit.Position.Y - (root.Y + y)) < 0.03, "incorrect tread height")
                treads += 1
            end
        end
        local decks = 0
        for _, point in
            { { 0, 0, 50 }, { 55, 0, -12 }, { 0, 0, 13 }, { -54, 16, -6 }, { 54, 16, -6 }, { 0, 16, -33 } }
        do
            local x, y, z = point[1], point[2], point[3]
            local hit = cast({ ship }, at(x, y + 0.25, z), at(x, y - 0.25, z))
            assert(
                hit and math.abs(hit.Position.Y - (root.Y + y)) < 0.20,
                "unsupported deck point " .. tostring(at(x, y, z))
            )
            decks += 1
        end

        local witnesses = {}
        local shot = 0
        local function impact(panelId: string)
            shot += 1
            local accepted, rejection = owner.resolve({
                roundId = 1,
                shotId = shot,
                weapon = "M102",
                firedAt = shot,
                panelId = panelId,
            })
            assert(accepted, rejection)
            owner.flush(shot)
            task.wait()
        end
        for _, name in { "Prism_Skirt_01", "Prism_Roof_01" } do
            local panel = panels:FindFirstChild(name)
            assert(panel and panel:IsA("Model"), name)
            local pivot = panel:GetPivot()
            local proxy: BasePart? = nil
            for _, child in panel:GetChildren() do
                if child:IsA("BasePart") and child:GetAttribute("PanelProxy") then
                    proxy = child
                end
            end
            assert(proxy)
            local half = proxy.Size / 2
            local center = proxy.Position
            local roof = name:find("Roof") ~= nil
            local verticalRange = if roof then half.Z else half.Y
            local function countRays(): number
                local hits = 0
                for i = -9, 9 do
                    for j = -9, 9 do
                        local offset = Vector3.new(half.X * i / 10, 0, 0)
                            + (if roof then Vector3.zAxis else Vector3.yAxis) * (verticalRange * j / 10)
                        local axis = (if roof then Vector3.yAxis else Vector3.zAxis) * 28
                        local ray = cast({ panel }, center + offset + axis, center + offset - axis)
                        if ray then
                            assert(owner.identify(ray.Instance) == name, "non-authoritative hull surface")
                            hits += 1
                        end
                    end
                end
                return hits
            end
            local pristine = countRays()
            assert(pristine > 30, name .. " lacks full native cover")
            impact(name)
            assert(
                panel:GetAttribute("DamageAppearance") == "Light" and countRays() == pristine,
                name .. " Light"
            )
            impact(name)
            impact(name)
            local heavy = countRays()
            assert(
                panel:GetAttribute("DamageAppearance") == "Heavy" and heavy > 0 and heavy < pristine * 0.70,
                name .. " Heavy"
            )
            for _ = 1, 3 do
                impact(name)
            end
            assert(
                panel:GetAttribute("DamageAppearance") == "Total"
                    and countRays() == 0
                    and panel:GetPivot() == pivot,
                name .. " Total"
            )
            witnesses[name] = {
                pristine = pristine,
                light = pristine,
                heavy = heavy,
                total = 0,
                pivot = {
                    pivot:GetComponents(),
                },
            }
        end
        owner.sync(2)
        for name, report in witnesses do
            local panel = panels:FindFirstChild(name)
            assert(
                panel
                    and panel:IsA("Model")
                    and panel:GetAttribute("DamageAppearance") == "Pristine"
                    and panel:GetPivot() == CFrame.new(table.unpack(report.pivot)),
                name .. " reset"
            )
        end
        return {
            openings = openings,
            treads = treads,
            deckPoints = decks,
            panels = #panels:GetChildren(),
            damage = witnesses,
        }
    end)
    if destruction then
        destruction.stop()
    end
    world:Destroy()
    assert(ok, result)
    return result
end
