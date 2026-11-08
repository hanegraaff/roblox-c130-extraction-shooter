--!strict
-- P04 A4/R06/R13: real server selection service, injected round/role eligibility.
type API = typeof(require(game:GetService("ServerScriptService").Server.AircraftSelection))
return function(test: (string, () -> ()) -> (), candidate: unknown)
    local selection = candidate :: API
    local function fixture()
        local owner = selection.new()
        owner.reset(7)
        return owner
    end
    test("accepted aircraft profile switches atomically and reset restores initial profile", function()
        local owner = fixture()
        assert(
            owner.command(1, { roundId = 7, sequence = 1, weapon = "M102" }, true),
            'expected owner.command(1, { roundId = 7, sequence = 1, weapon = "M102" }, true)'
        )
        local snapshot = owner.snapshot()
        assert(
            snapshot.weapon == "M102" and snapshot.roundId == 7 and snapshot.revision == 2,
            'expected snapshot.weapon == "M102" and snapshot.roundId == 7 and snapshot.revision == 2'
        )
        snapshot.weapon = "M7"
        assert(owner.snapshot().weapon == "M102", 'expected owner.snapshot().weapon == "M102"')
        owner.reset(7)
        assert(owner.snapshot().weapon == "M102", 'expected owner.snapshot().weapon == "M102"')
        owner.reset(7, true)
        assert(owner.snapshot().weapon == "GAU23", "explicit Lobby reset restores initial profile")
        owner.reset(8)
        assert(owner.snapshot().weapon == "GAU23", 'expected owner.snapshot().weapon == "GAU23"')
        assert(
            owner.command(1, { roundId = 8, sequence = 1, weapon = "M102" }, true),
            'expected owner.command(1, { roundId = 8, sequence = 1, weapon = "M102" }, true)'
        )
    end)
    test("wrong role, life, phase and deadline eligibility reject without mutation", function()
        local owner = fixture()
        local before = owner.snapshot()
        assert(
            not owner.command(1, { roundId = 7, sequence = 1, weapon = "M102" }, false),
            'expected not owner.command(1, { roundId = 7, sequence = 1, weapon = "M102" }, false)'
        )
        assert(
            owner.snapshot().revision == before.revision and owner.snapshot().weapon == before.weapon,
            "expected owner.snapshot().revision == before.revision and owner.snapshot().weapon == before.weapon"
        )
        assert(
            owner.command(1, { roundId = 7, sequence = 1, weapon = "M102" }, true),
            'expected owner.command(1, { roundId = 7, sequence = 1, weapon = "M102" }, true)'
        )
    end)
    test(
        "malformed, oversized, stale and unknown profile payloads reject without sequence consumption",
        function()
            local owner = fixture()
            local bad: { unknown } = {
                false,
                "M102",
                {},
                { roundId = 6, sequence = 1, weapon = "M102" },
                { roundId = 7, sequence = 1, weapon = "M7" },
                { roundId = 7, sequence = 1, weapon = "M102", extra = 1 },
                { roundId = 7, sequence = 1, weapon = string.rep("x", 256) },
                { roundId = 7, sequence = 1, weapon = {} },
            }
            for _, payload in bad do
                local before = owner.snapshot()
                assert(not owner.command(1, payload, true), "expected not owner.command(1, payload, true)")
                assert(
                    owner.snapshot().revision == before.revision and owner.snapshot().weapon == before.weapon,
                    "expected owner.snapshot().revision == before.revision and owner.snapshot().weapon == before.weapon"
                )
            end
            assert(not owner.command(1, nil, true), "expected not owner.command(1, nil, true)")
            assert(
                owner.command(1, { roundId = 7, sequence = 1, weapon = "M102" }, true),
                'expected owner.command(1, { roundId = 7, sequence = 1, weapon = "M102" }, true)'
            )
        end
    )
    test("duplicate, fractional and nonfinite selection sequences reject without mutation", function()
        local owner = fixture()
        assert(
            owner.command(1, { roundId = 7, sequence = 5, weapon = "M102" }, true),
            'expected owner.command(1, { roundId = 7, sequence = 5, weapon = "M102" }, true)'
        )
        for _, sequence in { 5, 4, 0, -1, 6.5, 0 / 0, math.huge, -math.huge, 2147483648 } do
            local revision = owner.snapshot().revision
            assert(
                not owner.command(1, { roundId = 7, sequence = sequence, weapon = "GAU23" }, true),
                'expected not owner.command(1, { roundId = 7, sequence = sequence, weapon = "GAU23" }, true)'
            )
            assert(
                owner.snapshot().weapon == "M102" and owner.snapshot().revision == revision,
                'expected owner.snapshot().weapon == "M102" and owner.snapshot().revision == revision'
            )
        end
        assert(
            owner.command(1, { roundId = 7, sequence = 6, weapon = "GAU23" }, true),
            'expected owner.command(1, { roundId = 7, sequence = 6, weapon = "GAU23" }, true)'
        )
    end)
end
