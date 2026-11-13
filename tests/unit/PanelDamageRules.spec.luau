--!strict
-- P07 A1/A2: pure heavy 0..6 boundaries, monotonicity and mixed stage budgets.
type API = typeof(require(game:GetService("ServerScriptService").Server.PanelDamageRules))
return function(test: (string, () -> ()) -> (), candidate: unknown)
    local Rules = candidate :: API
    test("PanelDamageRules heavy hits zero through six preserve exact stage boundaries", function()
        local state = Rules.new()
        for hit = 0, 6 do
            assert(state.stage == math.min(2, math.floor(hit / 3)), "wrong stage at heavy hit " .. hit)
            assert(
                math.abs(Rules.progress(state) - (if hit == 6 then 1 else (hit % 3) / 3)) < 1e-8,
                "missing per-hit progress"
            )
            if hit < 6 then
                Rules.apply(state, true, 0)
            end
        end
        assert(not Rules.apply(state, true, 0) and state.stage == 2, "destroyed was not idempotent")
    end)
    test(
        "PanelDamageRules nine seconds never advance early and apply epsilon only at rounding boundary",
        function()
            local state = Rules.new()
            assert(not Rules.apply(state, false, 9 - 1e-5) and state.stage == 0, "early transition")
            assert(Rules.apply(state, false, 1e-5) and state.stage == 1, "exact nine seconds")
            assert(Rules.apply(state, false, 9 + 1e-5) and state.stage == 2, "above nine seconds")
            local rounded = Rules.new()
            for _ = 1, 60 do
                Rules.apply(rounded, false, 0.15)
            end
            assert(rounded.stage == 1, "cadence rounding did not reach nine")
        end
    )
    test("PanelDamageRules mixed heavy credit persists while interrupted 30mm clears", function()
        local state = Rules.new()
        Rules.apply(state, true, 0)
        Rules.apply(state, false, 5.9)
        Rules.interrupt(state)
        assert(
            state.heavySeconds == 3 and state.sustainedSeconds == 0 and state.stage == 0,
            "Expected state.heavySeconds == 3 and state.sustainedSeconds == 0 and state.stage == 0"
        )
        assert(Rules.apply(state, false, 6) and state.stage == 1, "one heavy did not equal three seconds")
        Rules.apply(state, true, 0)
        Rules.apply(state, true, 0)
        assert(Rules.apply(state, false, 3) and state.stage == 2, "second-stage mixed threshold")
    end)
    test(
        "PanelDamageRules invalid seconds reject without mutation and overflow never skips stages",
        function()
            local state = Rules.new()
            for _, seconds in { -1, math.huge, 0 / 0 } do
                assert(
                    not Rules.apply(state, false, seconds),
                    "Expected not Rules.apply(state, false, seconds)"
                )
            end
            assert(
                state.stage == 0 and Rules.progress(state) == 0,
                "Expected state.stage == 0 and Rules.progress(state) == 0"
            )
            assert(
                Rules.apply(state, false, 100) and state.stage == 1 and state.sustainedSeconds == 0,
                "Expected Rules.apply(state, false, 100) and state.stage == 1 and state.sustainedSeconds == 0"
            )
        end
    )
end
