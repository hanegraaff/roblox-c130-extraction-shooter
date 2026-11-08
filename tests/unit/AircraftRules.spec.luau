--!strict
-- P04 A1/A4/A5, R05/R06: pure geometry/zoom contract; no engine claims.
type API = typeof(require(game:GetService("ReplicatedStorage").Shared.AircraftRules))
local mapDefaults = {
    centerX = 0,
    centerZ = 0,
    groundY = 0,
    radiusStuds = 180,
    orbitCenterX = 0,
    orbitCenterZ = 0,
    orbitRadiusStuds = 180,
    focusX = 0,
    focusY = 0,
    focusZ = 0,
    altitudeStuds = 140,
    killY = -30,
}
return function(test: (string, () -> ()) -> (), candidate: unknown)
    local rules = candidate :: API
    test("orbit is periodic with negative/positive phase wrap and exact altitude", function()
        local settings = rules.defaults
        for i = -32, 32 do
            local time = i * settings.periodSeconds / 32
            local first = rules.pose(mapDefaults, settings, time)
            local nextPose = rules.pose(mapDefaults, settings, time + 5 * settings.periodSeconds)
            assert(first and nextPose, "expected first and nextPose")
            assert(
                math.abs(first.x - nextPose.x) < 1e-6 and math.abs(first.z - nextPose.z) < 1e-6,
                "expected math.abs(first.x - nextPose.x) < 1e-6 and math.abs(first.z - nextPose.z) < 1e-6"
            )
            assert(
                first.y == 140 and first.phase >= 0 and first.phase < 2 * math.pi,
                "expected first.y == 140 and first.phase >= 0 and first.phase < 2 * math.pi"
            )
        end
    end)
    test("all sampled poses have map perimeter radius and unit perpendicular tangent", function()
        for i = 0, 128 do
            local pose = rules.pose(mapDefaults, rules.defaults, i * rules.defaults.periodSeconds / 128)
            assert(pose, "expected pose")
            assert(
                math.abs(math.sqrt(pose.x ^ 2 + pose.z ^ 2) - mapDefaults.radiusStuds) < 1e-6,
                "expected math.abs(math.sqrt(pose.x ^ 2 + pose.z ^ 2) - mapDefaults.radiusStuds) < 1e-6"
            )
            assert(
                math.abs(pose.tangentX ^ 2 + pose.tangentZ ^ 2 - 1) < 1e-9,
                "expected math.abs(pose.tangentX ^ 2 + pose.tangentZ ^ 2 - 1) < 1e-9"
            )
            assert(
                math.abs(pose.x * pose.tangentX + pose.z * pose.tangentZ) < 1e-6,
                "expected math.abs(pose.x * pose.tangentX + pose.z * pose.tangentZ) < 1e-6"
            )
        end
    end)
    test("orbit rejects nonfinite time, invalid map and derived overflow", function()
        for _, time in { 0 / 0, math.huge, -math.huge } do
            assert(
                not rules.pose(mapDefaults, rules.defaults, time),
                "expected not rules.pose(mapDefaults, rules.defaults, time)"
            )
        end
        local map = table.clone(mapDefaults)
        map.orbitRadiusStuds += 1
        assert(not rules.pose(map, rules.defaults, 0), "expected not rules.pose(map, rules.defaults, 0)")
        map = table.clone(mapDefaults)
        map.centerX = 1e308
        map.orbitCenterX = 1e308
        map.focusX = 1e308
        map.radiusStuds = 1e308
        map.orbitRadiusStuds = 1e308
        assert(not rules.pose(map, rules.defaults, 0), "expected not rules.pose(map, rules.defaults, 0)")
    end)
    test("zoom config decodes finite distinct ordered profiles without mutating input", function()
        local config = rules.validate(rules.defaults)
        assert(config and config ~= rules.defaults, "expected config and config ~= rules.defaults")
        local narrow = rules.fov(config, "GAU23")
        local wide = rules.fov(config, "M102")
        assert(
            narrow and wide and narrow < wide and narrow == 35 and wide == 60,
            "expected narrow and wide and narrow < wide and narrow == 35 and wide == 60"
        )
        assert(rules.fov(config, "M7") == nil, 'expected rules.fov(config, "M7") == nil')
    end)
    test("zoom and orbit config reject nonfinite, equal, inverted and unbounded tuning", function()
        for _, key in { "periodSeconds", "fov30mm", "fov105mm" } do
            for _, value in { 0 / 0, math.huge, -math.huge, 0, -1 } do
                local config = table.clone(rules.defaults)
                config[key] = value
                assert(not rules.validate(config), key)
            end
        end
        for _, pair in { { 60, 60 }, { 61, 60 }, { 35, 121 }, { 0.5, 60 } } do
            local config = table.clone(rules.defaults)
            config.fov30mm = pair[1]
            config.fov105mm = pair[2]
            assert(not rules.validate(config), "expected not rules.validate(config)")
        end
        local config = table.clone(rules.defaults)
        config.periodSeconds = 3601
        assert(not rules.validate(config), "expected not rules.validate(config)")
        assert(not rules.validate({}), "expected not rules.validate({})")
        assert(not rules.validate(nil), "expected not rules.validate(nil)")
    end)
    test("aim accepts disk center and edge but rejects exterior, height and nonfinite endpoints", function()
        local map = mapDefaults
        assert(rules.aimAllowed(map, 0, 0, 0), "expected rules.aimAllowed(map, 0, 0, 0)")
        assert(rules.aimAllowed(map, 180, 0, 0), "expected rules.aimAllowed(map, 180, 0, 0)")
        for _, point in
            {
                { 180.001, 0, 0 },
                { 0, -2, 0 },
                { 0, 141, 0 },
                { 0, 0, 181 },
                { 0 / 0, 0, 0 },
                { 0, math.huge, 0 },
                {
                    0,
                    0,
                    -math.huge,
                },
            }
        do
            assert(
                not rules.aimAllowed(map, point[1], point[2], point[3]),
                "expected not rules.aimAllowed(map, point[1], point[2], point[3])"
            )
        end
    end)
end
