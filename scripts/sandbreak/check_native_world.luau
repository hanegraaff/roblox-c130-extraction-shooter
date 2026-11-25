--!strict
--[=[
    Local Studio Edit acceptance for the managed Sandbreak asset. Exercises the
    actual replacement, query geometry and shared damage ledger in a temporary
    map clone. Production placement and cloud documents are not changed.
]=]
local Server = game:GetService("ServerScriptService").Server
local assets = game:GetService("ServerStorage").Assets
local BuildingGeometry = require(Server.BuildingGeometry)
local Damage = require(Server.DestructionRuntime)
local MapRules = require(game:GetService("ReplicatedStorage").Shared.MapRules)
local MapService = require(Server.MapService)
local Sandbreak = require(Server.SandbreakReconstruction)

return function()
    assert(game.PlaceId == 0 and not game:GetService("RunService"):IsRunning(), "Local Edit test only")
    local world = workspace.World:Clone()
    world.Name = "SandbreakIsolatedAcceptance"
    local damage: Damage.Controller? = nil
    local ok, result = pcall(function()
        local map = world.Battlefield
        local legacy = map.SpawnShelterPanels
        assert(#legacy:GetChildren() == 76, "Expected the original shelter before replacement")
        local trial, trialReason = Sandbreak.install(world, assets)
        assert(trial, trialReason)
        assert(legacy.Parent == nil and map.SpawnShelterPanels ~= legacy, "Legacy shelter still present")
        trial.rollback()
        assert(
            map.SpawnShelterPanels == legacy,
            "Failed install rollback did not restore the original shelter"
        )
        local install, reason = Sandbreak.install(world, assets)
        assert(install, reason)
        local bunker = map.SandbreakBunker
        local panels = map.SpawnShelterPanels
        assert(bunker:GetPivot():FuzzyEq(CFrame.new(0, 0, 120), 0.001), "Shelter placement")
        assert(#panels:GetChildren() == 103, "Missing native shelter identities")
        install.commit()
        assert(legacy.Parent == nil and #legacy:GetChildren() == 0, "Legacy panels survived commit")
        local shelterRegistries = 0
        for _, candidate in map:GetChildren() do
            if candidate.Name == "SpawnShelterPanels" then
                shelterRegistries += 1
            end
        end
        assert(shelterRegistries == 1, "Expected exactly one spawn shelter registry")
        world.Parent = workspace
        task.wait()
        local settings = assert(MapRules.validate(MapRules.defaults))
        local passed, message = MapService.validateMap(map, settings)
        assert(passed, message)
        BuildingGeometry.decorate(map)
        local controller, why = Damage.start(world)
        assert(controller, why)
        damage = controller
        controller.sync(1)
        local rays = RaycastParams.new()
        rays.FilterType = Enum.RaycastFilterType.Include
        local function cast(roots: { Instance }, from: Vector3, direction: Vector3): RaycastResult?
            rays.FilterDescendantsInstances = roots
            return workspace:Raycast(from, direction, rays)
        end
        local origin = Vector3.new(0, 0, 120)
        local coverage = 0
        for _, anchor in map.Anchors:GetChildren() do
            if not anchor:IsA("BasePart") or not string.match(anchor.Name, "^Ground%d%d$") then
                continue
            end
            for dx = -2, 2 do
                for dz = -2, 2 do
                    local at = anchor.Position + Vector3.new(dx, 0, dz)
                    local hit = cast({ panels }, at + Vector3.yAxis * 21, -Vector3.yAxis * 22)
                    assert(
                        hit and controller.identify(hit.Instance),
                        "No solid overhead cover at " .. anchor.Name
                    )
                    coverage += 1
                end
            end
        end
        assert(coverage == 225, "Expected 225 covered spawn samples")
        assert(
            not cast({ panels, bunker }, origin + Vector3.new(14.1, 24, -16.4), -Vector3.yAxis * 23),
            "Roof breach is obstructed"
        )
        local approaches = 0
        for _, axis in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
            local across = axis:Cross(Vector3.yAxis)
            for _, offset in { -7.99, -6, -4, -2, 0, 2, 4, 6, 7.99 } do
                for _, y in { 0.16, 1, 3, 5, 6.2, 7, 8.3 } do
                    local start = origin + axis * 17 + across * offset + Vector3.yAxis * y
                    assert(not cast({ panels, bunker }, start, axis * 39), "Blocked native approach")
                    approaches += 1
                end
            end
        end
        local shot = 0
        local function impact(panelId: string)
            shot += 1
            local applied, rejection = controller.resolve({
                roundId = 1,
                shotId = shot,
                weapon = "M102",
                firedAt = shot,
                panelId = panelId,
            })
            assert(applied, rejection)
            controller.flush(shot)
        end
        local checks: { [string]: { closed: number, retained: number, reset: number } } = {}
        for _, sample in { { "SB.W.S.01", Vector3.zAxis }, { "SB.R.07.07", Vector3.yAxis } } do
            local id = sample[1] :: string
            local normal = sample[2] :: Vector3
            local panel = assert(panels:FindFirstChild(id))
            assert(panel:IsA("Model"), "Expected native panel")
            local pivot = panel:GetPivot()
            local function covered(root: Model): number
                local size = root:GetAttribute("IntactSize") :: Vector3
                local tangent = if normal.Y > 0 then Vector3.zAxis else Vector3.yAxis
                local pitch = if normal.Y > 0 then size.Z else size.Y
                local hits = 0
                for x = -9, 9 do
                    for y = -9, 9 do
                        local at = pivot.Position
                            + normal * 20
                            + Vector3.xAxis * (x * size.X / 20)
                            + tangent * (y * pitch / 20)
                        if cast({ root }, at, -normal * 40) then
                            hits += 1
                        end
                    end
                end
                return hits
            end
            local closed = covered(panel)
            assert(closed > 150, "Intact panel did not provide cover")
            impact(id)
            assert(
                panel:GetAttribute("DamageAppearance") == "Light" and covered(panel) == closed,
                "Light changed cover"
            )
            impact(id)
            impact(id)
            local retained = covered(panel)
            assert(
                panel:GetAttribute("DamageAppearance") == "Heavy" and retained > 0 and retained < closed,
                "Heavy lacks an opening or retained cover"
            )
            for _ = 1, 3 do
                impact(id)
            end
            assert(
                panel:GetAttribute("DamageAppearance") == "Total" and #panel:GetChildren() == 0,
                "Total left a panel standing"
            )
            checks[id] = { closed = closed, retained = retained, reset = 0 }
        end
        controller.sync(2)
        for id, check in checks do
            local panel = assert(panels:FindFirstChild(id))
            assert(
                panel:IsA("Model") and panel:GetAttribute("DamageAppearance") == "Pristine",
                "Reset did not restore Pristine"
            )
            local size = panel:GetAttribute("IntactSize") :: Vector3
            assert(size.Magnitude > 0 and #panel:GetChildren() > 1, "Restored panel lacks cover")
            check.reset = #panel:GetChildren()
        end
        return {
            panelCount = 103,
            coveredSpawnColumns = coverage,
            clearApproaches = approaches,
            shelterRegistries = shelterRegistries,
            legacyPanelsRemaining = #legacy:GetChildren(),
            damage = checks,
        }
    end)
    if damage then
        damage.stop()
    end
    world:Destroy()
    assert(ok, result)
    return result
end
