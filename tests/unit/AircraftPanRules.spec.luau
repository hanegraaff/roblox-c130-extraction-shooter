--!strict
-- P14 A1/R05/R06/R17: pure orbit-local view bounds and directional input.
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
    local aspect, wide = 16 / 9, 40
    local function home()
        local focus = rules.recenter(map, aspect, wide)
        assert(focus, "safe reset view unavailable")
        return focus
    end
    local function near(a: number, b: number, tolerance: number): boolean
        return math.abs(a - b) <= tolerance
    end
    test("AircraftPanRules recenter creates an independent safe inward view", function()
        local a, b = home(), home()
        assert(a ~= b and near(a.x, b.x, 1e-9) and a.z == 0, "reset focus shared or unstable")
        assert(rules.viewFits(map, a, aspect, wide), "reset view includes sky or outside level")
        a.z = 10
        assert(b.z == 0, "reset leaked mutable state")
    end)
    test("AircraftPanRules WASD and touch axes move in the orbit-local view", function()
        for _, direction in
            {
                { 1, 0, 0, 12 },
                { -1, 0, 0, -12 },
                { 0, 1, -12, 0 },
                { 0, -1, 12, 0 },
            }
        do
            local start = home()
            local result = rules.step(map, start, direction[1], direction[2], 0.1, false, aspect, wide)
            assert(result, "valid directional step rejected")
            assert(near(result.x - start.x, direction[3], 1e-8), "vertical pan direction disagrees")
            assert(near(result.z - start.z, direction[4], 1e-8), "horizontal pan direction disagrees")
        end
    end)
    test("AircraftPanRules frame-rate independence holds away from view limits", function()
        local start = home()
        for _, hz in { 10, 30, 60, 144 } do
            local focus = home()
            for _ = 1, hz do
                local nextFocus = rules.step(map, focus, 0, 1, 0.2 / hz, false, aspect, wide)
                assert(nextFocus, "valid frame rejected")
                focus = nextFocus
            end
            assert(near(focus.x, start.x - 24, 1e-6), "vertical pan depends on frame rate")
        end
    end)
    test("AircraftPanRules diagonal speed and long-frame delta are bounded", function()
        local start = home()
        local focus = rules.step(map, start, 1, 1, 1e300, false, aspect, wide)
        assert(focus, "bounded diagonal rejected")
        local distance = math.sqrt((focus.x - start.x) ^ 2 + (focus.z - start.z) ^ 2)
        assert(near(distance, 12, 1e-6), "diagonal or stalled frame exceeded speed cap")
    end)
    test("AircraftPanRules held pan reaches each view edge without escaping", function()
        for _, input in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 1, 1 } } do
            local focus = home()
            for _ = 1, 180 do
                local nextFocus = rules.step(map, focus, input[1], input[2], 0.1, false, aspect, wide)
                assert(
                    nextFocus and rules.viewFits(map, nextFocus, aspect, wide),
                    "pan exposed outside ground"
                )
                focus = nextFocus
            end
            local held = rules.step(map, focus, input[1], input[2], 0.1, false, aspect, wide)
            assert(held and rules.viewFits(map, held, aspect, wide), "continued hold escaped edge")
            assert(
                math.sqrt((held.x - focus.x) ^ 2 + (held.z - focus.z) ^ 2) < 0.1,
                "edge hold kept moving through the level boundary"
            )
        end
    end)
    test("AircraftPanRules both zoom profiles fit all screen corners at common layouts", function()
        for _, ratio in { 750 / 382, 1280 / 720, 1920 / 1080 } do
            local focus = rules.recenter(map, ratio, wide)
            assert(focus and rules.viewFits(map, focus, ratio, wide), "wide reset escaped level")
            assert(rules.viewFits(map, focus, ratio, 30), "narrow profile escaped level")
            for _, input in { { 1, 0 }, { 0, 1 }, { -1, -1 } } do
                local nextFocus = rules.step(map, focus, input[1], input[2], 0.1, false, ratio, wide)
                assert(nextFocus and rules.viewFits(map, nextFocus, ratio, wide), "zoom-safe step escaped")
                focus = nextFocus
            end
        end
    end)
    test("AircraftPanRules supported lens preserves normal FOV and adapts ultra-wide", function()
        assert(rules.supportedFov(map, aspect, 40) == 40, "normal wide lens changed")
        assert(rules.supportedFov(map, 750 / 382, 40) == 40, "phone wide lens changed")
        local ultra = rules.supportedFov(map, 4, 40)
        assert(ultra and ultra < 40 and ultra >= 15, "ultra-wide view did not adapt")
        assert(rules.recenter(map, 4, ultra), "adapted ultra-wide view has no safe reset")
    end)
    test("AircraftPanRules held view rotates rigidly with aircraft orbit", function()
        local focus = rules.step(map, home(), 1, 1, 0.1, false, aspect, wide)
        assert(focus, "panned local focus unavailable")
        for i = 0, 360 do
            local phase = i / 360 * 2 * math.pi
            local cx, cz = 360 * math.cos(phase), 360 * math.sin(phase)
            local world = rules.worldFocus(map, focus, cx, cz)
            assert(world, "orbit focus transformation failed")
            local radialX, radialZ = math.cos(phase), math.sin(phase)
            local localX = radialX * world.x + radialZ * world.z
            local localZ = -radialZ * world.x + radialX * world.z
            assert(near(localX, focus.x, 1e-8) and near(localZ, focus.z, 1e-8), "held view drifted or spun")
            assert(world.x ^ 2 + world.z ^ 2 < 360 ^ 2, "view center left level")
        end
    end)
    test("AircraftPanRules blocked and neutral input hold relative view", function()
        local start = home()
        for _, blocked in { true, false } do
            local result = rules.step(map, start, if blocked then 1 else 0, 1, 0.1, blocked, aspect, wide)
            if not blocked then
                assert(result and result.x < start.x, "unblocked input did not pan")
            else
                assert(result and result.x == start.x and result.z == start.z, "blocked input moved")
            end
        end
        local neutral = rules.step(map, start, 0, 0, 0.1, false, aspect, wide)
        assert(neutral and neutral.x == start.x and neutral.z == start.z, "neutral input moved")
    end)
    test("AircraftPanRules rejects nonfinite axes geometry FOV and time", function()
        local start = home()
        for _, bad in { 0 / 0, math.huge, -math.huge } do
            assert(not rules.step(map, start, bad, 0, 0.1, false, aspect, wide), "nonfinite axis accepted")
            assert(not rules.step(map, start, 0, 0, bad, false, aspect, wide), "nonfinite time accepted")
            assert(not rules.viewFits(map, { x = bad, z = 0 }, aspect, wide), "nonfinite focus accepted")
            assert(not rules.worldFocus(map, start, bad, 0), "nonfinite aircraft accepted")
        end
        assert(not rules.step(map, start, 1.001, 0, 0.1, false, aspect, wide), "oversized axis accepted")
        assert(not rules.step(map, start, 0, 0, -1, false, aspect, wide), "negative time accepted")
        assert(not rules.recenter(map, 0, wide), "zero aspect accepted")
        assert(not rules.supportedFov(map, aspect, math.huge), "infinite FOV accepted")
    end)
    test("AircraftPanRules respects a differently sized level and rejects bad orbit", function()
        local smaller = table.clone(map)
        smaller.radiusStuds = 180
        smaller.orbitRadiusStuds = 180
        smaller.altitudeStuds = 70
        local reset = rules.recenter(smaller, aspect, wide)
        assert(reset and rules.viewFits(smaller, reset, aspect, wide), "alternate level unavailable")
        local moved = rules.step(smaller, reset, 1, 0, 0.1, false, aspect, wide)
        assert(moved and rules.viewFits(smaller, moved, aspect, wide), "alternate level pan escaped")
        smaller.orbitRadiusStuds = 179
        assert(not rules.recenter(smaller, aspect, wide), "mismatched orbit accepted")
    end)
    test("AircraftPanRules raster shares rounded integer ray and draw pixels", function()
        local result = rules.raster(540.995, 309.995, 1081, 618)
        assert(result and result.x == 541 and result.y == 310, "fractional XY raster disagrees")
        local center = rules.raster(540.5, 309, 1081, 618)
        assert(center and center.x == 541 and center.y == 309, "odd viewport center disagrees")
    end)
    test("AircraftPanRules raster preserves exact central bounds", function()
        for _, viewport in { { 1081, 618 }, { 1279, 719 }, { 1280, 720 }, { 1920, 1080 } } do
            local width, height = viewport[1], viewport[2]
            for _, point in { { 0, 0 }, { width, height }, { width * 0.15, height * 0.85 } } do
                local result = rules.raster(point[1], point[2], width, height)
                assert(result and result.x % 1 == 0 and result.y % 1 == 0, "noninteger raster")
                assert(
                    result.x >= width * 0.15
                        and result.x <= width * 0.85
                        and result.y >= height * 0.15
                        and result.y <= height * 0.85,
                    "raster escaped central area"
                )
            end
        end
    end)
    test("AircraftPanRules raster rejects invalid pointer and viewport", function()
        for _, bad in { 0 / 0, math.huge, -math.huge } do
            assert(not rules.raster(bad, 1, 1280, 720), "nonfinite pointer accepted")
            assert(not rules.raster(1, bad, 1280, 720), "nonfinite pointer accepted")
            assert(not rules.raster(1, 1, bad, 720), "nonfinite viewport accepted")
        end
        for _, size in { -1, 0, 1 } do
            assert(not rules.raster(1, 1, size, 720), "invalid viewport accepted")
        end
    end)
end
