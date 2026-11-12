--!strict
-- P05 A3/A4: bounded view intent, malformed requests and canonical orbit lag.
type API = typeof(require(game:GetService("ServerScriptService").Server.CombatViewRules))
return function(test: (string, () -> ()) -> (), candidate: unknown)
    local view = candidate :: API
    local loadPath = (require :: unknown) :: (string) -> unknown
    local mapRules = (
        if script
            then require(game:GetService("ReplicatedStorage").Shared.MapRules)
            else loadPath("../../src/shared/MapRules")
    ) :: typeof(require(game:GetService("ReplicatedStorage").Shared.MapRules))
    local pan = (
        if script
            then require(game:GetService("ReplicatedStorage").Shared.AircraftPanRules)
            else loadPath("../../src/shared/AircraftPanRules")
    ) :: typeof(require(game:GetService("ReplicatedStorage").Shared.AircraftPanRules))
    local map = mapRules.defaults
    local function request(weapon: string, angle: number, focus: { x: number, z: number })
        local cameraX, cameraZ = 360 * math.cos(angle), 360 * math.sin(angle)
        local target = assert(pan.worldFocus(map, focus, cameraX, cameraZ), "valid world focus")
        return {
            roundId = 1,
            sequence = 1,
            weapon = weapon,
            x = target.x,
            y = 0,
            z = target.z,
            focusX = focus.x,
            focusZ = focus.z,
            aspect = 16 / 9,
            cameraX = cameraX,
            cameraZ = cameraZ,
        }
    end
    test("P05 valid panned views remain legal at both zooms through an entire orbit", function()
        local home = assert(pan.recenter(map, 16 / 9, 40), "home view missing")
        local samples = { home }
        for _, axes in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
            local focus = home
            for _ = 1, 60 do
                focus = assert(pan.step(map, focus, axes[1], axes[2], 0.1, false, 16 / 9, 40), "pan step")
            end
            table.insert(samples, focus)
        end
        for _, weapon in { "GAU23", "M102" } do
            for n = 0, 35 do
                local angle = n * math.pi / 18
                for _, focus in samples do
                    local command = request(weapon, angle, focus)
                    assert(
                        view.validate(command, map, weapon, command.cameraX, command.cameraZ),
                        "valid panned view rejected"
                    )
                end
            end
        end
    end)
    test("P05 forged pose, invalid focus and unreachable reticle reject", function()
        local home = assert(pan.recenter(map, 16 / 9, 40), "home view missing")
        local command = request("GAU23", 0, home)
        command.focusX = 1000
        assert(not view.validate(command, map, "GAU23", 360, 0), "impossible pan accepted")
        command = request("GAU23", 0, home)
        command.x = -300
        command.z = 0
        assert(not view.validate(command, map, "GAU23", 360, 0), "out-of-view target accepted")
        command = request("GAU23", 0, home)
        command.cameraX = 300
        assert(not view.validate(command, map, "GAU23", 360, 0), "forged off-orbit camera accepted")
        command = request("GAU23", 0, home)
        assert(not view.validate(command, map, "M102", 360, 0), "stale selection accepted")
        local forged = (command :: unknown) :: { [string]: unknown }
        forged.extra = 1
        assert(not view.validate(forged, map, "GAU23", 360, 0), "forged payload field accepted")
        assert(
            view.validate(request("GAU23", 0, home), map, "GAU23", 360, 0),
            "valid request failed after rejects"
        )
    end)
    test("P05 finite bounded orbit replication age accepts normal delay and rejects excess", function()
        local home = assert(pan.recenter(map, 16 / 9, 40), "home view missing")
        local command = request("GAU23", 0, home)
        local normalAngle = 2 * math.pi / 90
        assert(
            view.validate(command, map, "GAU23", 360 * math.cos(normalAngle), 360 * math.sin(normalAngle)),
            "one second orbit lag rejected"
        )
        local oldAngle = 2 * math.pi * 1.5 / 90
        assert(
            not view.validate(command, map, "GAU23", 360 * math.cos(oldAngle), 360 * math.sin(oldAngle)),
            "excess orbit lag accepted"
        )
        for _, key in { "x", "y", "z", "focusX", "focusZ", "aspect", "cameraX", "cameraZ" } do
            for _, invalid in { 0 / 0, math.huge, -math.huge } do
                local bad = (request("GAU23", 0, home) :: unknown) :: { [string]: unknown }
                bad[key] = invalid
                assert(not view.validate(bad, map, "GAU23", 360, 0), "nonfinite view value accepted")
            end
        end
    end)
    test("P05 vertical reticle at the legal P14 40-degree limit remains valid", function()
        local pitch = math.rad(75.707)
        local focus = { x = 360 - 140 / math.tan(pitch), z = 0 }
        assert(pan.viewFits(map, focus, 16 / 9, 40), "counterexample must fit camera rules")
        local command = request("M102", 0, focus)
        command.x = 360
        command.z = 0
        assert(view.validate(command, map, "M102", 360, 0), "legal vertical reticle was rejected")
    end)
    test("P05 adaptive ultra-wide FOV cache is exact, reusable and bounded", function()
        local widest = assert(pan.supportedFov(map, 10, 40), "ultra-wide view unsupported")
        local focus = assert(pan.recenter(map, 10, widest), "ultra-wide focus missing")
        local command = request("M102", 0, focus)
        command.aspect = 10
        assert(view.validate(command, map, "M102", 360, 0), "legitimate adaptive ultra-wide view rejected")
        local before = view.cacheStats()
        for _ = 1, 8 do
            assert(view.validate(command, map, "M102", 360, 0), "cached ultra-wide view rejected")
        end
        local after = view.cacheStats()
        assert(
            after.hits >= before.hits + 8 and after.misses == before.misses,
            "repeated aspect recalculated adaptive FOV"
        )
        for i = 1, 70 do
            command.aspect = 7 + i * 0.01
            view.validate(command, map, "M102", 360, 0)
        end
        assert(view.cacheStats().entries <= 64, "view cache grew beyond its configured bound")
    end)
end
