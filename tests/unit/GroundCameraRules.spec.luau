--!strict
-- P17: deterministic interior thresholds, preview transition timing and stock zoom bounds.
type API = typeof(require(game:GetService("ReplicatedStorage").Shared.GroundCameraRules))

return function(test: (string, () -> ()) -> (), candidate: unknown)
    local rules = candidate :: API

    test("Ground camera uses the avatar root and applies doorway hysteresis", function()
        assert(rules.contains(0, 0, 4.79, 4, 3, 5, false), "root inside the room was excluded")
        assert(not rules.contains(0, 0, 4.9, 4, 3, 5, false), "entered too close to the threshold")
        assert(rules.contains(0, 0, 5.2, 4, 3, 5, true), "threshold movement hid the active room")
        assert(not rules.contains(0, 0, 5.3, 4, 3, 5, true), "room followed the avatar outside")
    end)

    test("Ground camera keeps the upper and lower story bounds separate", function()
        assert(rules.contains(0, 2.79, 0, 6, 3, 6, false), "inside story was excluded")
        assert(not rules.contains(0, 3.3, 0, 6, 3, 6, true), "room still selected above its ceiling")
        assert(not rules.contains(0, -3.3, 0, 6, 3, 6, true), "room selected below its floor")
    end)

    test("Ground camera eases in and fully returns to stock on exit", function()
        local first = rules.blend(0, true, 0.03)
        assert(first > 0 and first < 1, "entering jumped directly to the cap")
        local indoorWeight = first
        for _ = 1, 60 do
            indoorWeight = rules.blend(indoorWeight, true, 1 / 60)
        end
        assert(rules.distance(14, 5, indoorWeight) == 5, "indoor did not settle around the authored cap")
        local exitWeight = rules.blend(indoorWeight, false, 0.03)
        assert(exitWeight > 0 and exitWeight < 1, "leaving jumped directly to outdoor zoom")
        for _ = 1, 60 do
            exitWeight = rules.blend(exitWeight, false, 1 / 60)
        end
        assert(rules.distance(14, 5, exitWeight) == 14, "outdoor did not return to the same stock zoom")
    end)

    test("Ground camera transition uses elapsed time and bounds stalled frames", function()
        local slow, fast = 0, 0
        for _ = 1, 6 do
            slow = rules.blend(slow, true, 1 / 24)
        end
        for _ = 1, 15 do
            fast = rules.blend(fast, true, 1 / 60)
        end
        assert(math.abs(slow - fast) < 1e-9, "transition depended on frame count")
        assert(rules.blend(0, true, 1) == rules.blend(0, true, 0.1), "stalled frame skipped easing")
    end)

    test("Ground camera preserves a closer chosen or stock-occluded distance", function()
        for _, stockDistance in { 0, 0.5, 2, 5 } do
            assert(rules.distance(stockDistance, 5, 1) == stockDistance, "modifier pushed the camera back")
        end
        assert(rules.distance(12, 18, 1) == 12, "a generous indoor cap displaced a fitting view")
    end)

    test("Ground camera stays below a ceiling on an upward stock ray", function()
        local limit = rules.ceilingDistance(16, 0, 8, 3)
        assert(math.abs(limit - 5.7) < 1e-9, "ceiling clearance did not shorten the stock ray")
        assert(rules.ceilingDistance(16, 0, 2, 3) == 16, "camera with clearance was moved")
        assert(rules.ceilingDistance(16, 4, 6, 3) == 16, "focus above room was projected through the ceiling")
    end)
end
