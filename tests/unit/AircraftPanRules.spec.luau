--!strict
-- P18 A3: world-square movement, edge sliding and stable orbit-aware directions.
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
    local function near(a: number, b: number, tolerance: number): boolean
        return math.abs(a - b) <= tolerance
    end
    test("P18 reset and every square corner fit both lenses without disk/frustum clipping", function()
        local a = assert(rules.recenter(map, aspect, wide), "first recenter missing")
        local b = assert(rules.recenter(map, aspect, wide), "second recenter missing")
        assert(a ~= b and a.x == 0 and a.z == 0, "P18 assertion: a ~= b and a.x == 0 and a.z == 0")
        for _, x in { -360, 0, 360 } do
            for _, z in { -360, 0, 360 } do
                for _, fov in { 30, 40 } do
                    assert(
                        rules.viewFits(map, { x = x, z = z }, aspect, fov),
                        "P18 assertion: rules.viewFits(map, { x = x, z = z }, aspect, fov)"
                    )
                end
            end
        end
        assert(
            not rules.viewFits(map, { x = 360.01, z = 0 }, aspect, wide),
            "P18 assertion: not rules.viewFits(map, { x = 360.01, z = 0 }, aspect, wide)"
        )
    end)
    test("P18 phase-zero WASD uses labelled screen directions", function()
        for _, axes in { { 1, 0, 0, -12 }, { -1, 0, 0, 12 }, { 0, 1, -12, 0 }, { 0, -1, 12, 0 } } do
            local moved = assert(
                rules.step(map, { x = 0, z = 0 }, axes[1], axes[2], 0.1, false, aspect, wide),
                "P18 assertion: rules.step(map, { x = 0, z = 0 }, axes[1], axes[2], 0.1, false, aspect, wide)"
            )
            assert(
                near(moved.x, axes[3], 1e-8) and near(moved.z, axes[4], 1e-8),
                "P18 assertion: near(moved.x, axes[3], 1e-8) and near(moved.z, axes[4], 1e-8)"
            )
        end
    end)
    test("P18 square edge slides and reversal recovers without hidden accumulated offset", function()
        local focus = { x = 360, z = 0 }
        for _ = 1, 300 do
            focus = assert(
                rules.step(map, focus, 1, -1, 0.1, false, aspect, wide),
                "P18 assertion: rules.step(map, focus, 1, -1, 0.1, false, aspect, wide)"
            )
        end
        assert(focus.x == 360 and focus.z == -360, "P18 assertion: focus.x == 360 and focus.z == -360")
        local reverse = assert(
            rules.step(map, focus, -1, 1, 0.1, false, aspect, wide),
            "P18 assertion: rules.step(map, focus, -1, 1, 0.1, false, aspect, wide)"
        )
        assert(reverse.x < 360 and reverse.z > -360, "corner jammed after reverse input")
        local slide = assert(
            rules.step(map, { x = 360, z = 0 }, 1, -1, 0.1, false, aspect, wide),
            "P18 assertion: rules.step(map, { x = 360, z = 0 }, 1, -1, 0.1, false, aspect, wide)"
        )
        assert(slide.x == 360 and slide.z < 0, "blocked axis trapped free axis")
    end)
    test("P18 full-orbit corners edges and near-overhead focus always move or reverse", function()
        for n = 0, 72 do
            local phase = n * math.pi / 36
            local cx, cz = 360 * math.cos(phase), 360 * math.sin(phase)
            for _, focus in
                {
                    { x = -360, z = -360 },
                    { x = 360, z = 360 },
                    { x = -360, z = 360 },
                    { x = 360, z = -360 },
                    {
                        x = cx,
                        z = cz,
                    },
                }
            do
                local free = 0
                for _, axis in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
                    local result = assert(
                        rules.step(map, focus, axis[1], axis[2], 0.1, false, aspect, wide, cx, cz),
                        "P18 assertion: rules.step(map, focus, axis[1], axis[2], 0.1, false, aspect, wide, cx, cz)"
                    )
                    assert(
                        math.abs(result.x) <= 360 and math.abs(result.z) <= 360,
                        "P18 assertion: math.abs(result.x) <= 360 and math.abs(result.z) <= 360"
                    )
                    if math.abs(result.x - focus.x) + math.abs(result.z - focus.z) > 1e-6 then
                        free += 1
                    end
                end
                assert(free >= 2, "no recovery at orbit phase " .. n)
            end
        end
    end)
    test("P18 held focus remains world-fixed through orbit and zoom", function()
        local focus = { x = 320, z = -350 }
        for n = 0, 72 do
            local point = assert(
                rules.worldFocus(map, focus, 360 * math.cos(n), 360 * math.sin(n)),
                "P18 assertion: rules.worldFocus(map, focus, 360 * math.cos(n), 360 * math.sin(n))"
            )
            assert(
                point.x == focus.x and point.z == focus.z,
                "P18 assertion: point.x == focus.x and point.z == focus.z"
            )
            for _, fov in { 30, 40 } do
                assert(
                    rules.viewFits(map, focus, aspect, fov),
                    "P18 assertion: rules.viewFits(map, focus, aspect, fov)"
                )
            end
        end
    end)
    test("P18 pan speed is frame-rate independent and diagonal/frame-stall bounded", function()
        for _, dt in { 1 / 30, 1 / 60, 1 / 120 } do
            local focus = { x = 0, z = 0 }
            for _ = 1, math.floor(0.2 / dt + 0.5) do
                focus = assert(
                    rules.step(map, focus, 0, 1, dt, false, aspect, wide),
                    "P18 assertion: rules.step(map, focus, 0, 1, dt, false, aspect, wide)"
                )
            end
            assert(near(focus.x, -24, 1e-6), "P18 assertion: near(focus.x, -24, 1e-6)")
        end
        local result = assert(
            rules.step(map, { x = 0, z = 0 }, 1, 1, 1e300, false, aspect, wide),
            "P18 assertion: rules.step(map, { x = 0, z = 0 }, 1, 1, 1e300, false, aspect, wide)"
        )
        assert(
            near(math.sqrt(result.x ^ 2 + result.z ^ 2), 12, 1e-6),
            "P18 assertion: near(math.sqrt(result.x ^ 2 + result.z ^ 2), 12, 1e-6)"
        )
    end)
    test("P18 invalid input rejects without mutation and blocked frames hold focus", function()
        local origin = { x = 0, z = 0 }
        for _, bad in { 0 / 0, math.huge, -math.huge } do
            assert(
                not rules.step(map, origin, bad, 0, 0.1, false, aspect, wide),
                "P18 assertion: not rules.step(map, origin, bad, 0, 0.1, false, aspect, wide)"
            )
            assert(
                not rules.step(map, origin, 0, 0, bad, false, aspect, wide),
                "P18 assertion: not rules.step(map, origin, 0, 0, bad, false, aspect, wide)"
            )
        end
        assert(
            not rules.step(map, origin, 2, 0, 0.1, false, aspect, wide),
            "P18 assertion: not rules.step(map, origin, 2, 0, 0.1, false, aspect, wide)"
        )
        assert(
            not rules.step(map, origin, 0, 0, -1, false, aspect, wide),
            "P18 assertion: not rules.step(map, origin, 0, 0, -1, false, aspect, wide)"
        )
        local held = assert(
            rules.step(map, origin, 1, 1, 0.1, true, aspect, wide),
            "P18 assertion: rules.step(map, origin, 1, 1, 0.1, true, aspect, wide)"
        )
        assert(
            held ~= origin and held.x == 0 and held.z == 0 and origin.x == 0,
            "P18 assertion: held ~= origin and held.x == 0 and held.z == 0 and origin.x == 0"
        )
    end)
    test("P18 translated level uses square offsets without changing canonical orbit", function()
        local other = table.clone(map)
        other.centerX, other.orbitCenterX, other.focusX = 1000, 1000, 1000
        other.centerZ, other.orbitCenterZ, other.focusZ = -500, -500, -500
        local point = assert(
            rules.worldFocus(other, { x = 360, z = -360 }, 1360, -500),
            "P18 assertion: rules.worldFocus(other, { x = 360, z = -360 }, 1360, -500)"
        )
        assert(point.x == 1360 and point.z == -860, "P18 assertion: point.x == 1360 and point.z == -860")
        assert(
            rules.supportedFov(other, 10, 40) == 40,
            "P18 assertion: rules.supportedFov(other, 10, 40) == 40"
        )
    end)
    test("P18 reticle raster remains bounded and consistent at fractional pixels", function()
        local point = assert(
            rules.raster(540.6, 309.6, 1081, 619),
            "P18 assertion: rules.raster(540.6, 309.6, 1081, 619)"
        )
        assert(point.x == 541 and point.y == 310, "P18 assertion: point.x == 541 and point.y == 310")
        local edge = assert(
            rules.raster(-100, 10000, 1280, 720),
            "P18 assertion: rules.raster(-100, 10000, 1280, 720)"
        )
        assert(edge.x == 192 and edge.y == 612, "P18 assertion: edge.x == 192 and edge.y == 612")
        assert(not rules.raster(0 / 0, 0, 1280, 720), "P18 assertion: not rules.raster(0 / 0, 0, 1280, 720)")
    end)
end
