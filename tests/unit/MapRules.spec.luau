--!strict
-- P02 A2/R05: actual pure map contract. No engine claims; coordinates are studs.
type Settings = {
    centerX: number,
    centerZ: number,
    groundY: number,
    radiusStuds: number,
    orbitCenterX: number,
    orbitCenterZ: number,
    orbitRadiusStuds: number,
    focusX: number,
    focusY: number,
    focusZ: number,
    altitudeStuds: number,
    killY: number,
}
type API = {
    defaults: Settings,
    validate: (unknown) -> (Settings?, string?),
    inside: (Settings, number, number) -> boolean,
    orbit: (Settings, number) -> (number, number, number),
}
return function(test: (string, () -> ()) -> (), candidate: unknown)
    local MapRules = candidate :: API
    test("ExpandedMapRules defaults decode to independent matching circle and ground focus", function()
        local settings = MapRules.validate(MapRules.defaults)
        assert(
            settings and settings ~= MapRules.defaults,
            "expected settings and settings ~= MapRules.defaults"
        )
        assert(
            settings.radiusStuds == settings.orbitRadiusStuds and settings.radiusStuds * 2 == 720,
            "expected settings.radiusStuds == settings.orbitRadiusStuds"
        )
        assert(settings.focusY == settings.groundY, "expected settings.focusY == settings.groundY")
    end)
    test(
        "ExpandedMapRules config rejects invalid finite values and circle focus mismatches without mutation",
        function()
            for _, key in
                {
                    "radiusStuds",
                    "orbitRadiusStuds",
                    "altitudeStuds",
                    "centerX",
                    "centerZ",
                    "groundY",
                    "focusX",
                    "focusY",
                    "focusZ",
                    "killY",
                }
            do
                for _, bad in { 0 / 0, math.huge, -math.huge } do
                    local value: { [string]: number } =
                        table.clone((MapRules.defaults :: unknown) :: { [string]: number })
                    value[key] = bad
                    assert(not MapRules.validate(value), key)
                    assert(value.orbitCenterX == 0, "expected value.orbitCenterX == 0")
                end
            end
            for _, key in { "radiusStuds", "altitudeStuds" } do
                for _, bad in { 0, -1 } do
                    local value: { [string]: number } =
                        table.clone((MapRules.defaults :: unknown) :: { [string]: number })
                    value[key] = bad
                    assert(not MapRules.validate(value), key)
                end
            end
            for _, key in
                { "orbitCenterX", "orbitCenterZ", "orbitRadiusStuds", "focusX", "focusY", "focusZ", "killY" }
            do
                local value: { [string]: number } =
                    table.clone((MapRules.defaults :: unknown) :: { [string]: number })
                value[key] = value[key] + 1
                if key == "killY" then
                    value[key] = 0
                end
                assert(not MapRules.validate(value), key)
            end
            local below = table.clone(MapRules.defaults)
            below.focusY = -1
            assert(not MapRules.validate(below), "expected not MapRules.validate(below)")
            assert(not MapRules.validate({}), "expected not MapRules.validate({})")
            assert(not MapRules.validate(nil), "expected not MapRules.validate(nil)")
        end
    )
    test("ExpandedMapRules disk includes exact edge but rejects exterior and nonfinite positions", function()
        assert(
            MapRules.inside(MapRules.defaults, 360, 0),
            "expected MapRules.inside(MapRules.defaults, 360, 0)"
        )
        assert(
            MapRules.inside(MapRules.defaults, 0, -360),
            "expected MapRules.inside(MapRules.defaults, 0, -360)"
        )
        assert(
            not MapRules.inside(MapRules.defaults, 360.001, 0),
            "expected not MapRules.inside(MapRules.defaults, 360.001, 0)"
        )
        assert(
            not MapRules.inside(MapRules.defaults, 0 / 0, 0),
            "expected not MapRules.inside(MapRules.defaults, 0 / 0, 0)"
        )
        assert(
            not MapRules.inside(MapRules.defaults, 0, math.huge),
            "expected not MapRules.inside(MapRules.defaults, 0, math.huge)"
        )
    end)
    test("ExpandedMapRules sampled perimeter orbit follows matching perimeter and altitude", function()
        for i = 0, 31 do
            local x, y, z = MapRules.orbit(MapRules.defaults, i * math.pi / 16)
            assert(
                math.abs(math.sqrt(x * x + z * z) - 360) < 1e-9,
                "expected math.abs(math.sqrt(x * x + z * z) - 360) < 1e-9"
            )
            assert(y == 140, "expected y == 140")
        end
    end)
end
