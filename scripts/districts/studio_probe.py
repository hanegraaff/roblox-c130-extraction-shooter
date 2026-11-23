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
local result = {routes = {}, meshes = 0, placements = 0}
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
end)
box:Destroy()
assert(ok, tostring(failure))
print(game:GetService("HttpService"):JSONEncode(result))
"""

if __name__ == "__main__":
    print('local tracks = game:GetService("HttpService"):JSONDecode([==[' + json.dumps(TRACKS) + ']==])')
    print(PROBE)
