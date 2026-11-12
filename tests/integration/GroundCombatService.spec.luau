--!strict
-- P06 A1/A3: rifle cadence, reload, ammo and adversarial request boundaries.
type API = typeof(require(game:GetService("ServerScriptService").Server.GroundCombatService))
return function(test: (string, () -> ()) -> (), candidate: unknown)
    local rules = candidate :: API
    local function shot(n: number)
        return { roundId = 1, sequence = n, weapon = "M7", x = 0, y = 140, z = 0 }
    end
    test("rifle cadence magazine reserve and reload boundaries", function()
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
        assert(owner.readiness(1, 7).ammo == 30 and owner.readiness(1, 7).reserve == 90, "P06 invariant")
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
    test("finite reserve exhausts without affecting another ground player", function()
        local owner = rules.new()
        owner.reset(1)
        local nextSequence = 0
        local time = 0
        for magazine = 1, 5 do
            for _ = 1, 30 do
                nextSequence += 1
                assert(owner.fire(1, shot(nextSequence), true, time, 0, 0, 0), "shot should be ready")
                time += 0.151
            end
            if magazine < 5 then
                nextSequence += 1
                assert(
                    owner.reload(1, { roundId = 1, sequence = nextSequence }, true, time),
                    "reload should begin"
                )
                time += 2
            end
        end
        local exhausted = owner.readiness(1, time)
        assert(exhausted.ammo == 0 and exhausted.reserve == 0, "reserve should be exhausted")
        assert(
            not owner.reload(1, { roundId = 1, sequence = nextSequence + 1 }, true, time),
            "empty reserve reloaded"
        )
        assert(
            owner.readiness(2, time).ammo == 30 and owner.readiness(2, time).reserve == 120,
            "another player changed"
        )
    end)
end
