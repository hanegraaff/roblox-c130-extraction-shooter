--!strict
-- P18 A1: deployment Ground counts, fixed damage and no same-round resizing.
type API = typeof(require(game:GetService("ServerScriptService").Server.AircraftHealth))
return function(test: (string, () -> ()) -> (), candidate: unknown)
    local rules = candidate :: API
    test("P18 aircraft scales 1000 health across all 1–9 Ground roster sizes", function()
        local owner = rules.new()
        for count = 1, 9 do
            assert(owner.reset(count, count), "valid deployment rejected")
            local state = owner.snapshot()
            assert(
                state.maximum == count * 1000 and state.health == state.maximum and not state.destroyed,
                "P18 assertion: state.maximum == count * 1000 and state.health == state.maximum and not state.destroyed"
            )
            assert(owner.impact(count, "rocket", "RocketLauncher", true) == 150, "rocket damage scaled")
            assert(owner.impact(count, "rifle", "M7", true) == 5, "rifle damage scaled")
            assert(not owner.reset(count, 9), "same-round resize admitted")
            assert(owner.snapshot().health == count * 1000 - 155, "same-round reset healed damage")
        end
    end)
    test("P18 invalid round/count resets reject without health or identity mutation", function()
        local owner = rules.new()
        assert(owner.reset(7, 2), "P18 assertion: owner.reset(7, 2)")
        assert(
            owner.impact(7, "once", "M7", true) == 5,
            'P18 assertion: owner.impact(7, "once", "M7", true) == 5'
        )
        for _, count in { 0, -1, 10, 1.5, 0 / 0, math.huge, -math.huge } do
            assert(not rules.maximumFor(count) and not owner.reset(8, count), "invalid count admitted")
        end
        for _, id in { 0, -1, 6, 7, 7.5, 0 / 0, math.huge, -math.huge, 2147483648 } do
            assert(not owner.reset(id, 1), "invalid generation admitted")
        end
        local snapshot = owner.snapshot()
        assert(
            snapshot.roundId == 7 and snapshot.health == 1995 and snapshot.maximum == 2000,
            "P18 assertion: snapshot.roundId == 7 and snapshot.health == 1995 and snapshot.maximum == 2000"
        )
        assert(not owner.impact(7, "once", "M7", true), "rejected reset lost deduplication")
        assert(not owner.impact(8, "late", "M7", true), "future impact admitted")
        snapshot.health = 0
        assert(owner.snapshot().health == 1995, "snapshot aliases authority")
    end)
    test("P25 A2 six rockets leave 100 health and the seventh destroys once", function()
        local owner = rules.new()
        assert(owner.reset(1, 1), "P18 assertion: owner.reset(1, 1)")
        for i = 1, 7 do
            local amount, lethal = owner.impact(1, tostring(i), "RocketLauncher", true)
            assert(
                amount == (if i == 7 then 100 else 150) and lethal == (i == 7),
                "wrong rocket award or destruction boundary"
            )
            assert(owner.snapshot().health == math.max(0, 1000 - i * 150), "wrong remaining aircraft health")
            assert(not owner.impact(1, tostring(i), "RocketLauncher", true), "duplicate rocket")
        end
        assert(
            owner.snapshot().destroyed and not owner.impact(1, "extra", "M7", true),
            'P18 assertion: owner.snapshot().destroyed and not owner.impact(1, "extra", "M7", true)'
        )
    end)
    test(
        "P25 A2 rocket then rifle, misses, terminal clamps and next roster reset are authoritative",
        function()
            local owner = rules.new()
            assert(owner.reset(7, 1), "P18 assertion: owner.reset(7, 1)")
            assert(
                not owner.impact(7, "miss", "RocketLauncher", false),
                'P18 assertion: not owner.impact(7, "miss", "RocketLauncher", false)'
            )
            assert(
                not owner.impact(8, "stale", "M7", true),
                'P18 assertion: not owner.impact(8, "stale", "M7", true)'
            )
            assert(owner.impact(7, "first rocket", "RocketLauncher", true) == 150, "initial rocket damage")
            assert(owner.snapshot().health == 850, "rocket did not leave 850")
            assert(owner.impact(7, "first rifle", "M7", true) == 5, "rifle damage")
            assert(owner.snapshot().health == 845, "rifle did not leave 845")
            for i = 1, 150 do
                assert(
                    owner.impact(7, tostring(i), "M7", true) == 5,
                    'P18 assertion: owner.impact(7, tostring(i), "M7", true) == 5'
                )
            end
            local amount, lethal = owner.impact(7, "last", "RocketLauncher", true)
            assert(
                amount == 95 and lethal and owner.snapshot().health == 0,
                "P18 assertion: amount == 95 and lethal and owner.snapshot().health == 0"
            )
            assert(owner.reset(8, 3), "P18 assertion: owner.reset(8, 3)")
            assert(
                owner.snapshot().health == 3000 and owner.snapshot().maximum == 3000,
                "P18 assertion: owner.snapshot().health == 3000 and owner.snapshot().maximum == 3000"
            )
            assert(
                owner.impact(8, "last", "RocketLauncher", true) == 150,
                "new generation retained shot identity"
            )
            assert(
                not owner.impact(7, "late", "M7", true),
                'P18 assertion: not owner.impact(7, "late", "M7", true)'
            )
        end
    )
    test("P26 aircraft uses the round's HP per teammate and per-weapon damage", function()
        local tuned = rules.new(160, 8, 80)
        assert(tuned.reset(7, 3) and tuned.snapshot().maximum == 480)
        assert(tuned.impact(7, "r1", "M7", true) == 8)
        assert(tuned.impact(7, "r2", "RocketLauncher", true) == 80)
        assert(not tuned.reset(7, 2) and tuned.snapshot().health == 392)
    end)
end
