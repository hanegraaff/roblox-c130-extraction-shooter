--!strict
-- P05 A3/A4: compare server view authorization to actual Roblox CFrame rays
-- over panned boundary views, both profiles and a complete canonical orbit.
local Shared = game:GetService("ReplicatedStorage").Shared
local Pan = require(Shared.AircraftPanRules)
local Map = require(Shared.MapRules)
local Aircraft = require(Shared.AircraftRules)
local View = require(game:GetService("ServerScriptService").Server.CombatViewRules)
return function()
    local test = getfenv().it :: (string, () -> ()) -> ()
    test("P05 view intent accepts actual panned CFrame centerline rays around the orbit", function()
        local map = Map.defaults
        local aspect = 16 / 9
        local home = assert(Pan.recenter(map, aspect, 40), "camera home missing")
        local focuses = { home }
        for _, axis in { Vector2.new(1, 0), Vector2.new(-1, 0), Vector2.new(0, 1), Vector2.new(0, -1) } do
            local value = home
            for _ = 1, 60 do
                value = assert(Pan.step(map, value, axis.X, axis.Y, 0.1, false, aspect, 40), "panning failed")
            end
            table.insert(focuses, value)
        end
        local count = 0
        for phase = 0, 11 do
            local angle = phase * math.pi / 6
            local position = Vector3.new(360 * math.cos(angle), 140, 360 * math.sin(angle))
            local radial = Vector3.new(position.X, 0, position.Z).Unit
            local rightAxis = Vector3.new(radial.Z, 0, -radial.X)
            for _, focus in focuses do
                local point =
                    assert(Pan.worldFocus(map, focus, position.X, position.Z), "world focus missing")
                local look = (Vector3.new(point.x, 0, point.z) - position).Unit
                local right = (rightAxis - look * rightAxis:Dot(look)).Unit
                local frame = CFrame.fromMatrix(position, right, right:Cross(look), -look)
                for _, weapon in { "GAU23", "M102" } do
                    local fov = assert(Aircraft.fov(Aircraft.defaults, weapon), "profile FOV missing")
                    local tangent = math.tan(math.rad(fov) / 2)
                    for _, raster in
                        {
                            Vector2.zero,
                            Vector2.new(0.5, 0),
                            Vector2.new(-0.5, 0),
                            Vector2.new(0, 0.5),
                            Vector2.new(0, -0.5),
                        }
                    do
                        local ray = frame.LookVector
                            + frame.RightVector * raster.X * tangent * aspect
                            + frame.UpVector * raster.Y * tangent
                        assert(ray.Y < 0, "P14 centerline unexpectedly points into sky")
                        local target = position + ray * (-position.Y / ray.Y)
                        assert(Map.inside(map, target.X, target.Z), "P14 bounded centerline escaped level")
                        local request = {
                            roundId = 1,
                            sequence = 1,
                            weapon = weapon,
                            x = target.X,
                            y = target.Y,
                            z = target.Z,
                            focusX = focus.x,
                            focusZ = focus.z,
                            aspect = aspect,
                            cameraX = position.X,
                            cameraZ = position.Z,
                        }
                        assert(
                            View.validate(request, map, weapon, position.X, position.Z),
                            "valid actual engine camera ray rejected"
                        )
                        count += 1
                    end
                end
            end
            task.wait()
        end
        assert(count == 600, "view comparison did not exercise all expected rays")
    end)
end
