--!strict
-- P03 A2/R03: phase edges, exact deadline and pre-deadline outcome ordering.
type Facts = {
    nowSeconds: number,
    deadlineSeconds: number?,
    aircraftDestroyed: boolean,
    groundAlive: number,
    groundEliminated: boolean,
    operatorConnected: boolean,
    connectedCount: number,
}
type API = {
    canTransition: (string, string) -> boolean,
    outcome: (Facts) -> { winner: string, reason: string }?,
}
return function(test: (string, () -> ()) -> (), candidate: unknown)
    local Rules = candidate :: API
    test("only documented phase edges and deployment cancellation are legal", function()
        local legal = {
            ["Lobby>Deploying"] = true,
            ["Deploying>Scatter"] = true,
            ["Deploying>Active"] = true,
            ["Deploying>Lobby"] = true,
            ["Deploying>Results"] = true,
            ["Scatter>Active"] = true,
            ["Scatter>Results"] = true,
            ["Active>Results"] = true,
            ["Results>Resetting"] = true,
            ["Resetting>Lobby"] = true,
        }
        local phases = { "Lobby", "Deploying", "Scatter", "Active", "Results", "Resetting" }
        for _, from in phases do
            for _, to in phases do
                assert(
                    Rules.canTransition(from, to) == (legal[from .. ">" .. to] == true),
                    'expected Rules.canTransition(from, to) == (legal[from .. ">" .. to] == true)'
                )
            end
        end
    end)
    test("P24 Scatter has no combat timeout and still recognizes a lost side", function()
        local facts: Facts = {
            nowSeconds = 20,
            deadlineSeconds = nil,
            aircraftDestroyed = false,
            groundAlive = 1,
            groundEliminated = false,
            operatorConnected = true,
            connectedCount = 2,
        }
        assert(not Rules.outcome(facts), "arrival was interpreted as combat expiry")
        facts.operatorConnected = false
        facts.connectedCount = 1
        local result = Rules.outcome(facts)
        assert(result and result.reason == "OperatorForfeit", "Scatter did not recognize forfeit")
    end)
    test("deadline equality beats destruction and last ground elimination", function()
        local result = Rules.outcome({
            nowSeconds = 10,
            deadlineSeconds = 10,
            aircraftDestroyed = true,
            groundAlive = 0,
            groundEliminated = true,
            operatorConnected = true,
            connectedCount = 2,
        })
        assert(
            result and result.winner == "Gunship" and result.reason == "Timeout",
            'expected result and result.winner == "Gunship" and result.reason == "Timeout"'
        )
    end)
    test("pre-deadline aircraft destruction beats mutual ground elimination", function()
        local result = Rules.outcome({
            nowSeconds = 9,
            deadlineSeconds = 10,
            aircraftDestroyed = true,
            groundAlive = 0,
            groundEliminated = true,
            operatorConnected = true,
            connectedCount = 2,
        })
        assert(result and result.winner == "Ground", 'expected result and result.winner == "Ground"')
    end)
    test("empty server and no participants never award a competitive winner", function()
        for _, count in { 0, 1 } do
            local result = Rules.outcome({
                nowSeconds = 9,
                deadlineSeconds = 10,
                aircraftDestroyed = false,
                groundAlive = 0,
                groundEliminated = false,
                operatorConnected = false,
                connectedCount = count,
            })
            assert(result and result.winner == "None", 'expected result and result.winner == "None"')
        end
    end)
    test("last ground departure and physical ground elimination have distinct reasons", function()
        local facts = {
            nowSeconds = 9,
            deadlineSeconds = 10,
            aircraftDestroyed = false,
            groundAlive = 0,
            groundEliminated = false,
            operatorConnected = true,
            connectedCount = 1,
        }
        local departed = Rules.outcome(facts)
        assert(
            departed and departed.winner == "Gunship" and departed.reason == "GroundDeparted",
            "ground departure did not award the surviving gunship"
        )
        facts.groundEliminated = true
        facts.operatorConnected = false
        facts.connectedCount = 0
        local eliminated = Rules.outcome(facts)
        assert(
            eliminated and eliminated.winner == "Gunship" and eliminated.reason == "GroundEliminated",
            "ground elimination did not precede the operator departure"
        )
    end)
end
