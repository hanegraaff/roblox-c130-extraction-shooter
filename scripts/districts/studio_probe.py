"""Print a read-only Studio Play probe for stock geometry and the authored routes.

Paste its output into the Server Command Bar after the integrated battlefield is
ready. In a client context the same query also inspects the replicated geometry.
"""
import json

from layout import TRACKS

PROBE = """
local map = workspace.World.Battlefield
local scenery = map.DistrictScenery
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include
overlap.FilterDescendantsInstances = {map}
overlap.RespectCanCollide = true
local box = Instance.new("Part")
box.Size = Vector3.new(4, 5.8, 4)
box.Anchored = true
box.CanCollide = false
box.CanTouch = false
box.Parent = workspace
local result = {routes = {}, meshes = 0, placements = 0, mars = {rocks = 0, solid = 0, samples = {}}}
local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = {workspace.Terrain}
local function surface(x, z)
    return assert(workspace:Raycast(Vector3.new(x, 32, z), Vector3.new(0, -40, 0), terrainOnly))
end
local ok, failure = pcall(function()
    for name, route in tracks do
        local samples = 0
        for i = 2, #route do
            local a = Vector3.new(route[i-1][1], 3.4, route[i-1][2])
            local b = Vector3.new(route[i][1], 3.4, route[i][2])
            local steps = math.ceil((b-a).Magnitude / 2)
            for j = 0, steps do
                box.Position = a:Lerp(b, j/steps)
                local blocked = workspace:GetPartsInPart(box, overlap)
                assert(#blocked == 0, name .. " blocked at " .. tostring(box.Position))
                local support = surface(box.Position.X, box.Position.Z)
                assert(math.abs(support.Position.Y) < 1, name .. " trail is not at grade")
                samples += 1
            end
        end
        result.routes[name] = samples
    end
    for _, group in scenery:GetChildren() do
        result.placements += #group:GetChildren()
    end
    for _, part in scenery:GetDescendants() do
        assert(not part:IsA("LuaSourceContainer"), "Executable scenery: " .. part.Name)
        if part:IsA("MeshPart") then
            assert(part.MeshId ~= "" and part.MeshSize.Magnitude > 0, "Missing geometry: " .. part.Name)
            result.meshes += 1
        end
        if part:IsA("BasePart") then
            local lo = Vector3.new(1e6, 1e6, 1e6)
            local hi = -lo
            for _, x in {-0.5, 0.5} do
                for _, y in {-0.5, 0.5} do
                    for _, z in {-0.5, 0.5} do
                        local p = part.CFrame * (part.Size * Vector3.new(x,y,z))
                        lo, hi = lo:Min(p), hi:Max(p)
                    end
                end
            end
            assert(hi.X <= -106 or lo.X >= 106 or hi.Z <= 186 or lo.Z >= 332,
                "Scenery inside southern reserve: " .. part.Name)
        end
    end
    assert(result.meshes == 380 and result.placements == 306, "Incomplete stock scenery")
    for _, rock in map.MarsBoulders:GetChildren() do
        assert(rock:IsA("MeshPart") and rock.MeshId == "rbxassetid://5547037547")
        assert(rock.MeshSize.Magnitude > 0 and rock.TextureID == "", "Incorrect native boulder payload")
        assert(rock.Anchored and not rock.CanTouch and rock.CanQuery == rock.CanCollide)
        result.mars.rocks += 1
        if rock.CanCollide then
            result.mars.solid += 1
        else
            assert(rock:GetAttribute("ThermalNonCover") == true)
        end
    end
    assert(result.mars.rocks > 0 and result.mars.solid > 0)
    for name, point in {
        basin = {2, 258, 0, 1, "Mud"},
        craterFloor = {-150, 238, 0, 1, "Mud"},
        westernRim = {-174, 238, 5, 9, "Mud"},
        westernMesa = {-198, 254, 10, 15, "Mud"},
        easternRidge = {130, 278, 8, 14, "Mud"},
        radar = {238, -162, 0, 1, "Grass"},
        depot = {178, 194, 0, 1, "Asphalt"},
        sand = {-258, -138, 0, 1, "Sand"},
    } do
        local hit = surface(point[1], point[2])
        local height = hit.Position.Y
        assert(height >= point[3] - 0.1 and height <= point[4] and hit.Material.Name == point[5], name)
        result.mars.samples[name] = {height = height, material = hit.Material.Name}
    end
end)
box:Destroy()
assert(ok, tostring(failure))
return game:GetService("HttpService"):JSONEncode(result)
"""

if __name__ == "__main__":
    print('local tracks = game:GetService("HttpService"):JSONDecode([==[' + json.dumps(TRACKS) + ']==])')
    print(PROBE)
