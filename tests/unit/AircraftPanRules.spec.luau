--!strict
-- P14 A1/R05/R06/R17: production directional pan rules; no engine claims.
type API = typeof(require(game:GetService("ReplicatedStorage").Shared.AircraftPanRules))
return function(test: (string, () -> ()) -> (), candidate: unknown)
    local rules = candidate :: API
    local map = {
        centerX = 0,
        centerZ = 0,
        groundY = 0,
        radiusStuds = 360,
        orbitCenterX = 0,
        orbitCenterZ = 0,
        orbitRadiusStuds = 360,
        focusX = 0,
        focusY = 0,
        focusZ = 0,
        altitudeStuds = 140,
        killY = -30,
    }
    test("AircraftPanRules neutral directional input holds world focus", function()
        local focus = rules.step(map, { x = 21, z = -17 }, 360, 0, 0, 0, 0.1, false)
        assert(focus and focus.x == 21 and focus.z == -17, "neutral direction moved focus")
    end)
    test("AircraftPanRules WASD and touch pad axes pan in camera coordinates", function()
        local directions = {
            { 1, 0, 0, -12 },
            { -1, 0, 0, 12 },
            { 0, 1, -12, 0 },
            { 0, -1, 12, 0 },
        }
        for _, direction in directions do
            local focus = rules.step(map, { x = 0, z = 0 }, 360, 0, direction[1], direction[2], 0.1, false)
            assert(
                focus and math.abs(focus.x - direction[3]) < 1e-9 and math.abs(focus.z - direction[4]) < 1e-9,
                "directional pan axis disagrees"
            )
        end
    end)
    test("AircraftPanRules integration is frame-rate independent at 10 30 60 and 144Hz", function()
        for _, hz in { 10, 30, 60, 144 } do
            local focus = { x = 0, z = 0 }
            for _ = 1, hz do
                local nextFocus = rules.step(map, focus, 360, 0, 1, 0, 1 / hz, false)
                assert(nextFocus, "valid step rejected")
                focus = nextFocus
            end
            assert(math.abs(focus.z + 120) < 1e-7 and math.abs(focus.x) < 1e-7, "frame-rate-dependent pan")
        end
    end)
    test("AircraftPanRules diagonal speed is bounded and huge delta time is capped", function()
        local focus = rules.step(map, { x = 0, z = 0 }, 360, 0, 1, 1, 1e300, false)
        assert(
            focus and math.abs(math.sqrt(focus.x ^ 2 + focus.z ^ 2) - 12) < 1e-8,
            "unbounded catch-up or diagonal"
        )
    end)
    test("AircraftPanRules exact cardinal and diagonal disk edges remain within bounds", function()
        for _, point in { { 360, 0 }, { 0, -360 }, { 10000, 10000 }, { -1e300, 1e300 } } do
            local focus = rules.clamp(map, point[1], point[2])
            assert(focus and focus.x ^ 2 + focus.z ^ 2 <= 360 ^ 2, "clamp escaped disk")
            assert(
                math.abs(math.sqrt(focus.x ^ 2 + focus.z ^ 2) - 360) < 1e-8,
                "clamp unnecessarily shrank disk"
            )
        end
    end)
    test("AircraftPanRules sustained pan reaches each level edge and stops there", function()
        local smaller = table.clone(map)
        smaller.radiusStuds = 180
        smaller.orbitRadiusStuds = 180
        for _, input in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 1, 1 } } do
            local focus = rules.recenter(smaller)
            for _ = 1, 180 do
                local nextFocus = rules.step(smaller, focus, 180, 0, input[1], input[2], 0.1, false)
                assert(nextFocus, "level-bounded directional input rejected")
                focus = nextFocus
            end
            assert(math.abs(math.sqrt(focus.x ^ 2 + focus.z ^ 2) - 180) < 1e-6, "level edge not reached")
            local held = rules.step(smaller, focus, 180, 0, input[1], input[2], 0.1, false)
            assert(held and math.sqrt(held.x ^ 2 + held.z ^ 2) <= 180.000001, "level edge escaped")
        end
    end)
    test("AircraftPanRules blocked UI text and window input never changes focus", function()
        local original = { x = 36, z = -21 }
        local focus = rules.step(map, original, 360, 0, 1, 1, 0.1, true)
        assert(focus and focus.x == original.x and focus.z == original.z, "blocked input moved focus")
        assert(original.x == 36 and original.z == -21, "input mutated")
    end)
    test(
        "AircraftPanRules rejects out-of-range direction negative-time and nonfinite input without mutation",
        function()
            local original = { x = 4, z = 7 }
            for _, bad in { 0 / 0, math.huge, -math.huge } do
                assert(not rules.step(map, original, 360, 0, bad, 0, 0.1, false), "nonfinite axis accepted")
                assert(not rules.step(map, original, bad, 0, 0, 0, 0.1, false), "nonfinite aircraft accepted")
                assert(not rules.step(map, original, 360, 0, 0, 0, bad, false), "nonfinite time accepted")
                assert(not rules.clamp(map, bad, 0), "nonfinite focus accepted")
            end
            assert(
                not rules.step(map, original, 360, 0, -1.001, 0, 0.1, false),
                "out-of-range direction accepted"
            )
            assert(
                not rules.step(map, original, 360, 0, 0, 1.001, 0.1, false),
                "out-of-range direction accepted"
            )
            assert(not rules.step(map, original, 360, 0, 0, 0, -1, false), "negative time accepted")
            assert(original.x == 4 and original.z == 7, "rejection mutated focus")
        end
    )
    test("AircraftPanRules holds world-space focus under orbit motion and inward disk constraints", function()
        for i = 0, 64 do
            local angle = i / 64 * 2 * math.pi
            local x, z = 360 * math.cos(angle), 360 * math.sin(angle)
            local focus = rules.step(map, { x = 360, z = 0 }, x, z, 0, 0, 0.1, false)
            assert(focus and focus.x == 360 and focus.z == 0, "orbit recentered focus")
            assert((focus.x - x) * -x + (focus.z - z) * -z >= -1e-6, "look points outside inward half-space")
        end
    end)
    test("AircraftPanRules recenter returns independent center state", function()
        local a, b = rules.recenter(map), rules.recenter(map)
        assert(a.x == 0 and a.z == 0 and a ~= b, "recenter state shared")
        a.x = 10
        assert(b.x == 0, "recenter leaked mutation")
    end)
    test("AircraftPanRules rejects invalid map and degenerate aircraft basis", function()
        local invalid = table.clone(map)
        invalid.orbitRadiusStuds = 359
        assert(not rules.clamp(invalid, 0, 0), "invalid map accepted")
        assert(not rules.step(map, { x = 0, z = 0 }, 0, 0, 1, 0, 0.1, false), "degenerate pan basis accepted")
    end)
    test(
        "AircraftPanRules raster shares round-nearest integer ray and draw pixels for fractional XY",
        function()
            local result = rules.raster(540.995, 309.995, 1081, 618)
            assert(result and result.x == 541 and result.y == 310, "fractional XY raster disagrees")
            local center = rules.raster(540.5, 309, 1081, 618)
            assert(center and center.x == 541 and center.y == 309, "odd-viewport center raster disagrees")
        end
    )
    test("AircraftPanRules raster preserves exact central bounds at odd viewports and edges", function()
        for _, viewport in { { 1081, 618 }, { 1279, 719 }, { 1280, 720 }, { 1920, 1080 } } do
            local width, height = viewport[1], viewport[2]
            for _, point in
                {
                    { 0, 0 },
                    { width, height },
                    { width * 0.15, height * 0.85 },
                    { width * 0.85, height * 0.15 },
                }
            do
                local result = rules.raster(point[1], point[2], width, height)
                assert(result, "valid raster rejected")
                assert(result.x % 1 == 0 and result.y % 1 == 0, "reticle is not integer-rasterized")
                assert(
                    result.x >= width * 0.15
                        and result.x <= width * 0.85
                        and result.y >= height * 0.15
                        and result.y <= height * 0.85,
                    "raster escaped central bounds"
                )
            end
        end
    end)
    test("AircraftPanRules raster rejects nonfinite pointer and invalid viewport without mutation", function()
        for _, bad in { 0 / 0, math.huge, -math.huge } do
            assert(not rules.raster(bad, 1, 1280, 720), "nonfinite X accepted")
            assert(not rules.raster(1, bad, 1280, 720), "nonfinite Y accepted")
            assert(not rules.raster(1, 1, bad, 720), "nonfinite viewport accepted")
        end
        for _, size in { -1, 0, 1 } do
            assert(not rules.raster(1, 1, size, 720), "invalid viewport accepted")
        end
    end)
end
