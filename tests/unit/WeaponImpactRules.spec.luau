--!strict
-- P19 A3: bounded, round-owned presentation deduplication.
type API = typeof(require(game.ReplicatedStorage.Shared.WeaponImpactRules))
return function(test: (string, () -> ()) -> (), candidate: unknown)
    local rules = candidate :: API
    test("P19 distinct impacts survive reordering and replay or stale cues are rejected", function()
        local history = rules.history()
        assert(history.admit("M102", "10", 2, 2))
        assert(history.admit("GAU23", "9", 1.9, 2))
        assert(history.admit("Rocket", "10", 2, 2))
        assert(not history.admit("M102", "10", 2, 2.75), "duplicate accepted at inclusive expiry")
        assert(not history.admit("M102", "10", 2, 2.751), "expired delivery accepted")
        assert(not history.admit("M102", "future", 3, 2), "future delivery accepted")
        assert(not history.admit("M102", "", 2, 2), "empty identity accepted")
        assert(not history.admit("M102", "invalid", 0 / 0, 2), "non-finite time accepted")
        history.clear()
        assert(history.admit("M102", "10", 2, 2))
    end)
    test("P19 a saturated replay history rejects new work until identities expire", function()
        local history = rules.history()
        for index = 1, 192 do
            assert(history.admit("GAU23", tostring(index), 5, 5))
        end
        assert(not history.admit("GAU23", "pending", 5, 5), "saturated replay history accepted more work")
        assert(not history.admit("GAU23", "1", 5, 5.6), "existing identity evicted before expiry")
        assert(history.admit("GAU23", "pending", 5.8, 5.8))
    end)
end
