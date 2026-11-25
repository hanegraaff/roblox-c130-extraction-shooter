--!strict
-- R13/P01 A2: structural rejection and finite boundary tests in both runtimes.
return function(
    test: (string, () -> ()) -> (),
    Validation: {
        isFinite: (unknown) -> boolean,
        inRange: (unknown, number, number) -> boolean,
        flatPayload: (unknown, number, number) -> boolean,
    }
)
    test("finite values include zero and numeric boundaries", function()
        for _, value in { 0, -1, 1e30 } do
            assert(Validation.isFinite(value), "expected Validation.isFinite(value)")
        end
        assert(Validation.inRange(6, 6, 10), "expected Validation.inRange(6, 6, 10)")
        assert(Validation.inRange(10, 6, 10), "expected Validation.inRange(10, 6, 10)")
    end)
    test("NaN infinities and nonnumbers reject", function()
        local invalidNumbers: { unknown } = { 0 / 0, math.huge, -math.huge, "1", false, {} }
        for _, value in invalidNumbers do
            assert(not Validation.isFinite(value), "expected not Validation.isFinite(value)")
        end
        assert(not Validation.isFinite(nil), "expected not Validation.isFinite(nil)")
        assert(not Validation.inRange(1, 2, 1), "expected not Validation.inRange(1, 2, 1)")
        assert(not Validation.inRange(1, 0 / 0, 2), "expected not Validation.inRange(1, 0 / 0, 2)")
    end)
    test("payload bound configuration rejects nonfinite negative and fractional values", function()
        for _, invalid in { 0 / 0, math.huge, -1, 1.5 } do
            assert(not Validation.flatPayload({}, invalid, 3), "invalid field bound")
            assert(not Validation.flatPayload({}, 3, invalid), "invalid byte bound")
        end
    end)
    test("flat payload accepts exact field and byte boundaries", function()
        assert(
            Validation.flatPayload({ abc = "abc", x = 0, y = false }, 3, 3),
            'expected Validation.flatPayload({ abc = "abc", x = 0, y = false }, 3, 3)'
        )
        assert(Validation.flatPayload({}, 0, 0), "expected Validation.flatPayload({}, 0, 0)")
    end)
    test("payload rejects oversized nested cyclic metatable and malformed data", function()
        local cyclic = {}
        cyclic.self = cyclic
        local invalidPayloads: { unknown } = {
            { a = "abcd" },
            { abcd = true },
            { a = 0 / 0 },
            { a = math.huge },
            { a = {} },
            cyclic,
            setmetatable({}, {}),
        }
        for _, value in invalidPayloads do
            assert(
                not Validation.flatPayload(value, 3, 3),
                "expected not Validation.flatPayload(value, 3, 3)"
            )
        end
        assert(
            not Validation.flatPayload({ a = 1, b = 2 }, 1, 3),
            "expected not Validation.flatPayload({ a = 1, b = 2 }, 1, 3)"
        )
        assert(
            not Validation.flatPayload({ [1] = 1 }, 3, 3),
            "expected not Validation.flatPayload({ [1] = 1 }, 3, 3)"
        )
        assert(not Validation.flatPayload(nil, 3, 3), "expected not Validation.flatPayload(nil, 3, 3)")
    end)
end
