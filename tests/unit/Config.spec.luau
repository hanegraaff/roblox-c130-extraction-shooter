--!strict
-- R01/R13/P01 A2: config decoding rejects nonfinite and population boundary violations.
return function(
    test: (string, () -> ()) -> (),
    Config: {
        defaults: { minPlayers: number, maxPlayers: number, roundDurationSeconds: number },
        validate: (
            unknown
        ) -> ({ minPlayers: number, maxPlayers: number, roundDurationSeconds: number }?, string?),
    }
)
    test("default and valid endpoints decode without aliasing", function()
        local value = { minPlayers = 6, maxPlayers = 10, roundDurationSeconds = 1 }
        local settings, reason = Config.validate(value)
        assert(
            settings and not reason and settings ~= value,
            "expected settings and not reason and settings ~= value"
        )
        assert(Config.validate(Config.defaults), "expected Config.validate(Config.defaults)")
        assert(
            Config.validate({ minPlayers = 10, maxPlayers = 10, roundDurationSeconds = 3600 }),
            "expected Config.validate({ minPlayers = 10, maxPlayers = 10, roundDurationSeconds = 3600 })"
        )
    end)
    test("malformed and nonfinite config reject without mutation", function()
        for _, bad in { 0 / 0, math.huge, -math.huge, 0, 5, 6.5, 11 } do
            local value = { minPlayers = bad, maxPlayers = 10, roundDurationSeconds = 600 }
            local settings, reason = Config.validate(value)
            assert(not settings and reason, "expected not settings and reason")
            assert(value.maxPlayers == 10, "expected value.maxPlayers == 10")
        end
        assert(not Config.validate(nil), "expected not Config.validate(nil)")
        assert(not Config.validate({}), "expected not Config.validate({})")
        assert(
            not Config.validate({ minPlayers = 8, maxPlayers = 7, roundDurationSeconds = 600 }),
            "expected not Config.validate({ minPlayers = 8, maxPlayers = 7, roundDurationSeconds = 600 })"
        )
        assert(
            not Config.validate({ minPlayers = 6, maxPlayers = 10, roundDurationSeconds = math.huge }),
            "expected not Config.validate({ minPlayers = 6, maxPlayers = 10, roundDurationSeconds = math.huge })"
        )
        assert(
            not Config.validate({ minPlayers = 6, maxPlayers = 10, roundDurationSeconds = 0 }),
            "expected not Config.validate({ minPlayers = 6, maxPlayers = 10, roundDurationSeconds = 0 })"
        )
    end)
end
