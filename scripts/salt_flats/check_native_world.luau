--!strict
--[=[
    Local Studio Edit acceptance for the Rojo-managed Salt Flats candidate.
    Mounts the production replacement in a temporary world, exercises native
    coverage and the real damage adapter, and then tears down all test Parts.
    No cloud place is changed and no production test override is embedded.
]=]
local ServerStorage = game:GetService("ServerStorage")
local Server = game:GetService("ServerScriptService").Server
local SaltFlats = require(Server.SaltFlatsReconstruction)
local BuildingGeometry = require(Server.BuildingGeometry)
local Damage = require(Server.DestructionRuntime)
local Outpost = require(Server.OutpostReconstruction)
local Vesper = require(Server.VesperReconstruction)

return function()
    assert(game.PlaceId == 0 and not game:GetService("RunService"):IsRunning(), "Local Edit test only")
    local world = workspace.World:Clone()
    world.Name = "SaltFlatsIsolatedAcceptance"
    local damage: Damage.Controller? = nil
    local ok, result = pcall(function()
        local assets = ServerStorage.Assets
        for _, installer in { Outpost.install, Vesper.install, SaltFlats.install } do
            local mounted, reason = installer(world, assets)
            assert(mounted, reason)
            mounted.commit()
        end
        local map = assert(world:FindFirstChild("Battlefield"))
        assert(map:IsA("Model"), "missing Battlefield")
        local building = map.Buildings.Foundry
        local wreck = building.HerculesWreck
        assert(wreck:IsA("Model"), "missing Hercules wreck")
        local site = building:GetPivot()
        local pivot = site
        world.Parent = workspace
        task.wait()
        local rays = RaycastParams.new()
        rays.FilterType = Enum.RaycastFilterType.Include
        rays.RespectCanCollide = true
        local overlaps = OverlapParams.new()
        overlaps.FilterType = Enum.RaycastFilterType.Include
        overlaps.FilterDescendantsInstances = { map }
        overlaps.RespectCanCollide = true
        rays.FilterDescendantsInstances = { map }
        local valid, reason = BuildingGeometry.validate(map, overlaps, rays)
        assert(valid, reason)
        BuildingGeometry.decorate(map)
        local controller, problem = Damage.start(world)
        assert(controller, problem)
        damage = controller
        controller.sync(1)

        local function cast(owner: Instance, from: Vector3, to: Vector3): RaycastResult?
            rays.FilterDescendantsInstances = { owner }
            return workspace:Raycast(from, to - from, rays)
        end

        local hullPivot = pivot * CFrame.new(-108, 0, 135) * CFrame.Angles(0, math.rad(22), 0)
        local function wreckRay(x: number, z: number, fromY: number, toY: number): RaycastResult?
            return cast(
                wreck,
                hullPivot:PointToWorldSpace(Vector3.new(x, fromY, z)),
                hullPivot:PointToWorldSpace(Vector3.new(x, toY, z))
            )
        end

        local ramp = wreckRay(0, 45, 3.8, 0)
        assert(ramp and ramp.Instance.Name == "Ramp", "actual ramp proxy was not hit")
        local cover = wreckRay(0, 20, 26, 5.5)
        assert(
            cover and controller.identify(cover.Instance) == "HerculesWreck",
            "intact wreck did not provide overhead cover"
        )
        local entry = cast(
            wreck,
            hullPivot:PointToWorldSpace(Vector3.new(0, 5.5, 57)),
            hullPivot:PointToWorldSpace(Vector3.new(0, 5.5, 18))
        )
        assert(not entry, "a proxy blocks the real wreck entrance")

        local frame = building.Foundry_Static
        local pier = frame.SaltFlats_PortalPier1
        local pierPose = pier.CFrame
        local panelPoses: { [string]: CFrame } = {}
        local shot = 0
        local function impact(id: string)
            shot += 1
            local passed, rejection = controller.resolve({
                roundId = 1,
                shotId = shot,
                weapon = "M102",
                firedAt = shot,
                panelId = id,
            })
            assert(passed, rejection)
            controller.flush(shot)
        end
        for _, id in { "Foundry_S01_Side_W_02_1", "Foundry_S04_Roof_W_L_01" } do
            local panel = building.Foundry_Panels:FindFirstChild(id)
            assert(panel and panel:IsA("Model"), "missing representative damage panel " .. id)
            local pose = panel:GetPivot()
            panelPoses[id] = pose
            local center = pose.Position
            local vector = if string.find(id, "_Roof_", 1, true) then Vector3.yAxis else pivot.RightVector
            local function centerRay()
                return cast(panel, center + vector * 5, center - vector * 5)
            end
            assert(centerRay(), "Pristine center must be solid")
            impact(id)
            assert(
                panel:GetAttribute("DamageAppearance") == "Light" and centerRay(),
                "Light must preserve solid cover"
            )
            impact(id)
            impact(id)
            assert(
                panel:GetAttribute("DamageAppearance") == "Heavy" and not centerRay(),
                "Heavy must expose a real breach"
            )
            local residualCount = 0
            for _, child in panel:GetChildren() do
                if child:GetAttribute("PanelProxy") == true then
                    residualCount += 1
                end
            end
            assert(residualCount > 0, "Heavy removed all residual cover")
            for _ = 1, 3 do
                impact(id)
            end
            assert(
                panel:GetAttribute("DamageAppearance") == "Total" and #panel:GetChildren() == 0,
                "Total retained geometry"
            )
        end
        impact("HerculesWreck")
        assert(
            #wreck:GetChildren() == 0 and not wreckRay(0, 20, 26, 5.5),
            "wreck collision survived direct hit"
        )
        controller.sync(2)
        local restored = building:FindFirstChild("HerculesWreck")
        assert(restored and #restored:GetChildren() > 200, "reset did not restore native wreck")
        for id, pose in panelPoses do
            local panel = building.Foundry_Panels:FindFirstChild(id)
            assert(panel and panel:IsA("Model") and panel:GetPivot() == pose, "panel reset moved its pivot")
            local vector = if string.find(id, "_Roof_", 1, true) then Vector3.yAxis else pivot.RightVector
            assert(panel:GetAttribute("DamageAppearance") == "Pristine", "panel did not reset")
            assert(
                cast(panel, pose.Position + vector * 5, pose.Position - vector * 5),
                "panel cover did not reset"
            )
        end
        assert(pier.Parent == frame and pier.CFrame == pierPose and pier.CanCollide, "stable pier changed")
        return {
            wallStates = 4,
            roofStates = 4,
            oneHitWreck = true,
            wreckReset = true,
            panelReset = true,
            stableStructure = true,
            panels = 152,
        }
    end)
    if damage then
        damage.stop()
    end
    world:Destroy()
    if not ok then
        error(result)
    end
    return result
end
