--!strict
-- P06 and P25 A3: rifle cadence, unlimited reserve, reload and request boundaries.
type API = typeof(require(game:GetService("ServerScriptService").Server.GroundCombatService))
return function(test: (string, () -> ()) -> (), candidate: unknown)
    local rules = candidate :: API
    local function shot(n: number)
        return { roundId = 1, sequence = n, weapon = "M7", x = 0, y = 140, z = 0 }
    end
    test("P25 A3 empty magazine and exact rifle cadence and reload boundaries", function()
        local owner = rules.new()
        owner.reset(1)
        assert(owner.fire(1, shot(1), true, 0, 0, 0, 0), "P06 invariant")
        assert(not owner.fire(1, shot(2), true, 0.149, 0, 0, 0), "P06 invariant")
        for n = 2, 30 do
            assert(owner.fire(1, shot(n), true, (n - 1) * 0.151, 0, 0, 0), "P06 invariant")
        end
        assert(owner.readiness(1, 5).ammo == 0, "P06 invariant")
        assert(not owner.fire(1, shot(31), true, 5, 0, 0, 0), "P06 invariant")
        assert(owner.reload(1, { roundId = 1, sequence = 31 }, true, 5), "P06 invariant")
        assert(not owner.fire(1, shot(32), true, 6.999, 0, 0, 0), "P06 invariant")
        assert(owner.readiness(1, 7).ammo == 30, "P06 invariant")
        assert(owner.fire(1, shot(32), true, 7, 0, 0, 0), "P06 invariant")
    end)
    test("forged invalid stale or unowned requests do not spend ammunition", function()
        local owner = rules.new()
        owner.reset(1)
        assert(not owner.fire(1, shot(1), false, 0, 0, 0, 0), "P06 invariant")
        assert(
            not owner.fire(
                1,
                { roundId = 1, sequence = 1, weapon = "M7", x = 0, y = 140, z = 0, damage = 999 },
                true,
                0,
                0,
                0,
                0
            ),
            "P06 invariant"
        )
        assert(
            not owner.fire(
                1,
                { roundId = 1, sequence = 1, weapon = "M7", x = math.huge, y = 0, z = 0 },
                true,
                0,
                0,
                0,
                0
            ),
            "P06 invariant"
        )
        assert(
            not owner.fire(
                1,
                { roundId = 1, sequence = 1, weapon = "M7", x = 1201, y = 0, z = 0 },
                true,
                0,
                0,
                0,
                0
            ),
            "P06 invariant"
        )
        assert(owner.readiness(1, 0).ammo == 30, "P06 invariant")
        assert(owner.fire(1, shot(1), true, 0, 0, 0, 0), "P06 invariant")
        assert(not owner.fire(1, shot(1), true, 1, 0, 0, 0), "P06 invariant")
        assert(owner.readiness(1, 1).ammo == 29, "P06 invariant")
        owner.reset(2)
        assert(not owner.fire(1, shot(2), true, 2, 0, 0, 0), "P06 invariant")
        assert(owner.readiness(1, 2).ammo == 30, "P06 invariant")
    end)
    test("P25 A3 repeated legal reloads permit more than 150 shots from an independent magazine", function()
        local owner = rules.new()
        owner.reset(1)
        local nextSequence = 0
        local time = 0
        for _ = 1, 6 do
            for _ = 1, 30 do
                nextSequence += 1
                assert(owner.fire(1, shot(nextSequence), true, time, 0, 0, 0), "shot should be ready")
                time += 0.151
            end
            assert(owner.readiness(1, time).ammo == 0, "empty magazine expected")
            assert(not owner.fire(1, shot(nextSequence + 1), true, time, 0, 0, 0), "empty magazine fired")
            nextSequence += 1
            assert(owner.reload(1, { roundId = 1, sequence = nextSequence }, true, time), "reload rejected")
            time += 2
            assert(owner.readiness(1, time).ammo == 30, "reload failed to refill magazine")
        end
        assert(owner.readiness(2, time).ammo == 30, "another player changed")
    end)
    test(
        "P25 A3 partial reload fills only at deadline and retirement cancels without replay credit",
        function()
            local owner = rules.new()
            owner.reset(1)
            assert(owner.fire(1, shot(1), true, 0, 0, 0, 0), "first shot")
            assert(owner.reload(1, { roundId = 1, sequence = 2 }, true, 1), "partial reload")
            assert(owner.readiness(1, 2.999).ammo == 29, "partial reload credited early")
            assert(not owner.fire(1, shot(3), true, 2.999, 0, 0, 0), "partial magazine fired during reload")
            assert(owner.readiness(1, 3).ammo == 30, "partial magazine failed to refill")
            assert(owner.fire(1, shot(3), true, 3, 0, 0, 0), "fire rejected when reload completed")
            assert(owner.reload(1, { roundId = 1, sequence = 4 }, true, 4), "second partial reload")
            owner.cancelReload(1)
            assert(not owner.fire(1, shot(5), false, 6, 0, 0, 0), "eliminated player fired")
            assert(not owner.reload(1, { roundId = 1, sequence = 5 }, false, 6), "eliminated player reloaded")
            assert(not owner.fire(1, shot(4), true, 6, 0, 0, 0), "cancellation discarded replay guard")
            local retired = owner.readiness(1, 6)
            assert(retired.ammo == 29 and retired.reloadUntil == 0, "retirement completed a canceled reload")
            assert(owner.reload(2, { roundId = 1, sequence = 2 }, true, 7) == false, "full magazine reloaded")
            assert(owner.fire(2, shot(1), true, 7, 0, 0, 0), "another player could not fire")
            assert(owner.reload(2, { roundId = 1, sequence = 2 }, true, 8), "previous-round reload setup")
            owner.reset(2)
            assert(not owner.reload(2, { roundId = 1, sequence = 3 }, true, 9), "stale reload on new round")
            assert(not owner.fire(2, shot(3), true, 10, 0, 0, 0), "stale fire on new round")
            local fresh = owner.readiness(2, 10)
            assert(
                fresh.ammo == 30 and fresh.reloadUntil == 0 and fresh.nextFire == 0,
                "new round inherited reload"
            )
        end
    )
    test("preflight rejects bad or cooldown requests without spending readiness or sequence", function()
        local owner = rules.new()
        owner.reset(1)
        assert(not owner.preflight(1, {}, true, 0, 0, 0, 0), "malformed preflight accepted")
        assert(owner.preflight(1, shot(1), true, 0, 0, 0, 0), "valid preflight rejected")
        assert(owner.readiness(1, 0).ammo == 30, "preflight spent ammunition")
        assert(owner.fire(1, shot(1), true, 0, 0, 0, 0), "valid fire rejected after preflight")
        assert(not owner.preflight(1, shot(2), true, 0.1, 0, 0, 0), "cooldown preflight accepted")
        assert(owner.preflight(1, shot(2), true, 0.15, 0, 0, 0), "ready preflight rejected")
        assert(owner.readiness(1, 0.15).ammo == 29, "rejected preflight spent ammunition")
    end)
end
