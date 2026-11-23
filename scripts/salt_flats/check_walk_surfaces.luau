--!strict
--[=[
    Salt Flats isolated Studio geometry probe. Receives the generated proxy
    recipe and evaluates actual engine ray hits at each tread and across the
    complete C-130 ramp. Creates a temporary elevated folder in the local test place
    and tears it down regardless of outcome. It does not exercise an avatar.
]=]
type Recipe = { key: string, center: { number }, size: { number }, pitchDegrees: number }
type Surfaces = { hangar: { Recipe }, wreck: { Recipe } }

local function vector(values: { number }): Vector3
    return Vector3.new(values[1], values[2], values[3])
end

-- The local terrain-free probe measures walking-face elevation in source studs.
return function(surfaces: Surfaces)
    assert(game.PlaceId == 0, "run walking-surface probes only in the isolated local test place")
    local region = Instance.new("Folder")
    region.Name = "SaltFlatsWalkProbe"
    local origin = Vector3.new(0, 300, 0)
    local parts: { [string]: Part } = {}
    local function build(recipe: Recipe)
        local surface = Instance.new("Part")
        surface.Name = recipe.key
        surface.Anchored = true
        surface.CanTouch = false
        surface.Size = vector(recipe.size)
        surface.CFrame = CFrame.new(origin + vector(recipe.center))
            * CFrame.Angles(math.rad(recipe.pitchDegrees), 0, 0)
        surface.Parent = region
        parts[surface.Name] = surface
    end
    local ok, result = pcall(function()
        for _, recipe in surfaces.hangar do
            build(recipe)
        end
        for _, recipe in surfaces.wreck do
            build(recipe)
        end
        region.Parent = workspace
        task.wait()
        local rayParams = RaycastParams.new()
        rayParams.FilterType = Enum.RaycastFilterType.Include
        rayParams.RespectCanCollide = true
        local function expect(part: Part, x: number, z: number, height: number)
            rayParams.FilterDescendantsInstances = { part }
            local hit = workspace:Raycast(
                origin + Vector3.new(x, height + 0.55, z),
                Vector3.new(0, -1.1, 0),
                rayParams
            )
            assert(hit and hit.Instance == part, "no support at " .. part.Name)
            assert(
                math.abs(hit.Position.Y - origin.Y - height) < 0.01,
                "misaligned walking face at " .. part.Name
            )
        end
        local treads = 0
        for _, recipe in surfaces.hangar do
            if string.find(recipe.key, "_Tread", 1, true) then
                local part = parts[recipe.key]
                expect(part, part.Position.X, part.Position.Z, recipe.center[2] + 0.18)
                treads += 1
            end
        end
        local ramp = parts.Ramp
        local rampSamples = 0
        for _, x in { -4, 0, 4 } do
            for z = 39, 55 do
                local rise = 0.09 + (55.2 - z) * 3.07 / 16.65
                expect(ramp, x, z, rise)
                rampSamples += 1
            end
        end
        local cargo = parts.CargoDeck
        expect(cargo, 0, 12, 3.23)
        assert(treads == 120, "expected two sets of three switchback stairs")
        return { treads = treads, rampSamples = rampSamples, deckY = 3.23 }
    end)
    region:Destroy()
    if not ok then
        error(result)
    end
    return result
end
