--!strict
-- P19 A1: exercise actual registered-solid sampling and solid Roblox rays.
local Server = game:GetService("ServerScriptService").Server
local Geometry = require(Server.BlastGeometry)
local Combat = require(Server.CombatService)
return function()
    local test = getfenv().it :: (string, () -> ()) -> ()
    test("P19 ground-centered blast reaches exact surface bounds without tunneling through cover", function()
        local root = Instance.new("Folder")
        root.Name = "P19BlastFixture"
        local point = Vector3.new(2000, 2000, 2000)
        local function add(name: string, offset: Vector3, size: Vector3): Part
            local part = Instance.new("Part")
            part.Name, part.Size, part.Position = name, size, point + offset
            part.Anchored = true
            part.Parent = root
            return part
        end
        local registered: { [Instance]: string } = {}
        registered[add("Inner", Vector3.new(22, 0, 0), Vector3.new(2, 4, 4))] = "inner"
        registered[add("Boundary", Vector3.new(0, 0, 37), Vector3.new(2, 4, 2))] = "edge"
        registered[add("Outside", Vector3.new(0, 0, -37.125), Vector3.new(2, 4, 2))] = "outside"
        registered[add("Screen", Vector3.new(-12, 0, 0), Vector3.new(2, 8, 8))] = "screen"
        registered[add("Hidden", Vector3.new(-24, 0, 0), Vector3.new(2, 4, 4))] = "hidden"
        registered[add("SecondInnerPiece", Vector3.new(21, 0, -10), Vector3.new(2, 4, 4))] = "inner"
        add("StaticSupport", Vector3.new(5, 9, 0), Vector3.new(2, 2, 2))
        local floor = add("Road", Vector3.new(0, -1, 0), Vector3.new(100, 2, 100))
        root.Parent = workspace
        local ok, failure = pcall(function()
            local cover = RaycastParams.new()
            cover.FilterType = Enum.RaycastFilterType.Include
            cover.RespectCanCollide = true
            cover.FilterDescendantsInstances = { root }
            local hit = workspace:Raycast(point + Vector3.yAxis * 5, -Vector3.yAxis * 10, cover)
            assert(hit and hit.Instance == floor, "test ray missed ground")
            local function identify(instance: Instance?): string?
                return if instance then registered[instance] else nil
            end
            local hits = Geometry.exposedPanels(
                hit.Position,
                hit.Position + hit.Normal * 0.1,
                Combat.profiles.M102.radius,
                root,
                cover,
                identify,
                nil
            )
            assert(
                table.concat(hits, ",") == "edge,inner,screen",
                "wrong panel set " .. table.concat(hits, ",")
            )
            local nextHits = Geometry.exposedPanels(
                hit.Position,
                hit.Position + hit.Normal * 0.1,
                Combat.profiles.M102.radius,
                root,
                cover,
                identify,
                "screen"
            )
            assert(
                table.concat(nextHits, ",") == "edge,inner",
                "direct panel double counted or cover bounced into hidden panel"
            )
        end)
        root:Destroy()
        assert(ok, tostring(failure))
    end)
end
