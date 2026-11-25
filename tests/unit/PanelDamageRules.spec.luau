--!strict
-- P18 A2: one howitzer / two earned 30mm seconds, retained intermediate visuals.
type API = typeof(require(game:GetService("ServerScriptService").Server.PanelDamageRules))
return function(test: (string, () -> ()) -> (), candidate: unknown)
    local rules = candidate :: API
    test("P18 one direct howitzer destroys pristine or partially damaged panels", function()
        for _, credit in { 0, 0.15, 1, 1.8 } do
            local state = rules.new()
            rules.apply(state, false, credit)
            assert(
                rules.apply(state, true, 0) and state.stage == 2 and rules.appearance(state) == "Total",
                'P18 assertion: rules.apply(state, true, 0) and state.stage == 2 and rules.appearance(state) == "Total"'
            )
            assert(rules.progress(state) == 1 and not rules.apply(state, true, 0), "terminal mutation")
        end
    end)
    test("P18 30mm exact one/two-second boundaries retain cadence surplus", function()
        local state = rules.new()
        assert(
            not rules.apply(state, false, 1 - 1e-5) and state.stage == 0,
            "P18 assertion: not rules.apply(state, false, 1 - 1e-5) and state.stage == 0"
        )
        assert(
            rules.apply(state, false, 1e-5) and state.stage == 1,
            "P18 assertion: rules.apply(state, false, 1e-5) and state.stage == 1"
        )
        assert(
            not rules.apply(state, false, 1 - 1e-5) and state.stage == 1,
            "P18 assertion: not rules.apply(state, false, 1 - 1e-5) and state.stage == 1"
        )
        assert(
            rules.apply(state, false, 1e-5) and state.stage == 2,
            "P18 assertion: rules.apply(state, false, 1e-5) and state.stage == 2"
        )
        local cadence = rules.new()
        for _ = 1, 13 do
            rules.apply(cadence, false, 0.15)
        end
        assert(
            cadence.stage == 1 and math.abs(cadence.sustainedSeconds - 0.95) < 1e-8,
            "P18 assertion: cadence.stage == 1 and math.abs(cadence.sustainedSeconds - 0.95) < 1e-8"
        )
        rules.apply(cadence, false, 0.05)
        assert(cadence.stage == 2, "intermediate transition discarded earned time")
    end)
    test("P18 earned light and heavy visuals persist at zero local stage credit", function()
        local state = rules.new()
        assert(rules.appearance(state) == "Pristine", 'P18 assertion: rules.appearance(state) == "Pristine"')
        rules.apply(state, false, 0)
        assert(rules.appearance(state) == "Pristine", 'P18 assertion: rules.appearance(state) == "Pristine"')
        rules.apply(state, false, 0.15)
        assert(rules.appearance(state) == "Light", 'P18 assertion: rules.appearance(state) == "Light"')
        rules.apply(state, false, 0.85)
        assert(
            state.stage == 1 and rules.progress(state) == 0 and rules.appearance(state) == "Heavy",
            'P18 assertion: state.stage == 1 and rules.progress(state) == 0 and rules.appearance(state) == "Heavy"'
        )
        rules.apply(state, false, 1)
        assert(rules.appearance(state) == "Total", 'P18 assertion: rules.appearance(state) == "Total"')
    end)
    test("P18 invalid elapsed credit rejects and finite oversized credit saturates Total", function()
        local state = rules.new()
        for _, elapsed in { -1, math.huge, -math.huge, 0 / 0 } do
            assert(
                not rules.apply(state, false, elapsed),
                "P18 assertion: not rules.apply(state, false, elapsed)"
            )
        end
        assert(
            state.stage == 0 and rules.progress(state) == 0,
            "P18 assertion: state.stage == 0 and rules.progress(state) == 0"
        )
        assert(
            rules.apply(state, false, 100) and state.stage == 2 and state.sustainedSeconds == 0,
            "P18 assertion: rules.apply(state, false, 100) and state.stage == 2 and state.sustainedSeconds == 0"
        )
    end)
end
